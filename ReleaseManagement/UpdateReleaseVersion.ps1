Param($Environment,$ApplicationNames,$Action,$ActionType,$Position,$Release)

#loading Function
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	



if(!$Environment){
	$Environment="DCORP"
	$ApplicationNames="MercatorESB"
	$Action="upgrade"
	$ActionType="Global"
	#global,Application
	$Position="Minor"
	$Release='33'
}

clear-host

#update properties Script Path
$UpdatePropertiesScriptfile="$ScriptDirectory\ReleaseManagement\UpdateProperties.ps1"


# the position to be udpated
switch ($Position) 
      { 
        "Base"  { $pos=1}
		"Major" { $pos=2}
		"Minor" { $pos=3}
		"Patch" { $pos=4}  
      }
	  
#Negating the position
if($Action -ieq "Rollback")
{
$pos=-$pos
}

#Getting the Previous environments
switch ($Environment) 
      { 
        "ICORP" { 
					$PreEnv="DCORP"
				}
		"ACORP" { 
					$PreEnv="ICORP"
				}
		"PCORP" {  
					$PreEnv="ACORP"
				}
      }
	  
    $TestInputVerionFile=[String]::Format("\\svw-be-testp002\D$\TestWare\_PreAndPostProcessing_{0}\PreRunProcess\PreRunProcess-release.txt",$Environment)
	
	#global version
	$xml = [xml](Get-Content Filesystem::$global:ReleaseManifest)
	$PreviousGlobalnode=$xml.SelectSingleNode("/Release/environment[@Name='$PreEnv']")
	$CurrentGlobalnode=$xml.SelectSingleNode("/Release/environment[@Name='$Environment']")




if($ActionType -match "Global")
{
		if($Action -match "Upgrade")
		{
			$CurrentGlobalnode.GlobalReleaseVersion=changeVersion $CurrentGlobalnode.GlobalReleaseVersion $pos $Environment
			#$CurrentGlobalnode.MercatorBuildVersion =$($CurrentGlobalnode.MercatorBuildVersion).split('.')[0] +"."+((([int]$($CurrentGlobalnode.MercatorBuildVersion).split('.')[1]))+1)
		}
		elseif($Action -match "promote")
		{
			$CurrentGlobalnode.GlobalReleaseVersion = $PreviousGlobalnode.GlobalReleaseVersion
			$CurrentGlobalnode.MercatorBuildVersion = $PreviousGlobalnode.MercatorBuildVersion
		}
		
		Write-Host "=================Updated Global Version========================================================="
		$CurrentGlobalnode.Attributes | foreach { Write-host "$($_.Name)=$($_.Value)"  }
		Write-Host "=================Updated Global Version========================================================="
		$xml.Save($global:ReleaseManifest)
		
		if($(test-path Filesystem::$TestInputVerionFile) -and ($Environment -ieq 'DCORP')){
			set-content Filesystem::$TestInputVerionFile -Value  $($CurrentGlobalnode.GlobalReleaseVersion)
			$ReadTestInpuFile=$(gc Filesystem::$TestInputVerionFile)
			$ReleaseID=$($($($xml.SelectSingleNode("/Release/environment[@Name='ICORP']")).GlobalReleaseVersion).split(".")[0])
			$ReadTestInpuFile=$ReadTestInpuFile -replace "$($ReadTestInpuFile.split(".")[0])",$ReleaseID
			Set-Content Filesystem::$TestInputVerionFile -Value $ReadTestInpuFile	
		}
}
if($ActionType -match "Application")
{
Write-Host "==================Update Application Version========================================================="
Foreach($ApplicationName in $ApplicationNames.Split(',')){
	#Application Version nodes
	write-host "/Release/environment[@Name='$Environment']/Application[@Name='$ApplicationName']"
	$PreviousApplicationnode=$xml.SelectSingleNode("/Release/environment[@Name='$PreEnv']/Application[@Name='$ApplicationName']")
	$CurrentApplicationnode=$xml.SelectSingleNode("/Release/environment[@Name='$Environment']/Application[@Name='$ApplicationName']")

		if($Action -match "Upgrade")
		{
			$newVersion=ChangeVersion $($CurrentApplicationnode.Version) $pos $Environment
			$CurrentApplicationnode.PreviousVersion = $CurrentApplicationnode.Version
			$CurrentApplicationnode.Version = $newVersion
			
			#updating database Version for ESB and EAI 
			$dbName=[string]::Format("MercatorBuild.{0}",$CurrentGlobalnode.MercatorBuildVersion)
			$selectQuery="select PlatformName,platformVersion from Platforms where PlatformName='$DBAppName'"
			#$select=Invoke-Sqlcmd -Query $selectQuery -ServerInstance $Global:BaloiseBIDBserver -Database $dbName -Username $Global:BaloiseVersionDBuserid -Password $Global:BaloiseVersionDBuserpassword -ErrorVariable $out
			$select=Invoke-Sqlcmd -Query $selectQuery -ServerInstance $Global:BaloiseBIDBserver -Database $dbName -ErrorVariable $out
			if($select -and $Environment -ine "DCORP"){
				$version = ChangeVersion $select.platformVersion $pos $Environment
				$updateQuery="Update Platforms set platformVersion='$version' where PlatformName='$DBAppName'"
				#$update=Invoke-Sqlcmd -Query $updateQuery -ServerInstance $Global:BaloiseBIDBserver -Database $dbName -Username $Global:BaloiseVersionDBuserid -Password $Global:BaloiseVersionDBuserpassword -ErrorVariable $out
				$update=Invoke-Sqlcmd -Query $updateQuery -ServerInstance $Global:BaloiseBIDBserver -Database $dbName -ErrorVariable $out
			}
		}
		
		elseif($Action -match "promote")
		{
			Write-Host "Promoting Versions from $($PreEnv) ===> $($Environment)"
			if($PreviousApplicationnode.Version -ne $CurrentApplicationnode.Version){$CurrentApplicationnode.PreviousVersion = $CurrentApplicationnode.Version }
			$CurrentApplicationnode.Version = $PreviousApplicationnode.Version
		}
			
		
		$CurrentApplicationnode.Attributes | foreach { Write-host "$($_.Name)=$($_.Value)"  }
		
		$xml.Save($global:ReleaseManifest)
		& Filesystem::$UpdatePropertiesScriptfile $Environment $ApplicationName $CurrentApplicationnode $CurrentGlobalnode
		
	}
	Write-Host "==================Update Application Version========================================================="
}

