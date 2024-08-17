Param($Environment,$DeploymentVersions,$ParameterImport)
##

if(!$Environment){
	$Environment='MIG'
	$DeploymentVersions="26.3.28.0"
	$ParameterImport="Y"
}

Clear

$MigEnvironments="MIG","MIG3","MIG4"
$MigVersion=$false

#Importing SQL modules for SQL commands to the Version database
Import-Module sqlps -DisableNameChecking

if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}

$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	

$date=[DateTime]::Now.ToString("yyyy-MM-dd")
#sorting versions in ascending order


#switch ($Environment) 
#      { 
#	    "DCORP" { $Environment="DEV"}
#        "ICORP" { $Environment="INT"}
#		"ACORP" { $Environment="ACC"}
#		"PCORP" { $Environment="PRD"}
#		"MIG"   { $Environment="MIG"}
#		"MIG3"  { $Environment="MIG3"}
#		"MIG4"  { $Environment="MIG4"}
#	  }
	 
$PacakgeBase="D:\ClevaPackages\$Environment\"
$Deliveryfolder="D:\Delivery\Deploy\packages\"
$ClevaDeliveryfolder="D:\Delivery\Deploy\Cleva\"
$templatelocation="D:\BuildTeam\Templates\DeploymentTemplates\*"


$DeploymentVersions=@($DeploymentVersions.Split(','))
$MIGNewVersionfolderName=""
if($MigEnvironments -icontains $Environment){
	$MIGNewVersionfolderName=[string]::Format("{0}{1}",$Environment,$DeploymentVersions[-1])
	$MigVersion=$true
}

$NewVersion=$DeploymentVersions[-1]

#check if each version is packaged for deployment
foreach($version in $DeploymentVersions){
	Write-Host "Checking Version :" $version
	$selectQuery="Select * from ClevaVersions where Cleva_Version='$version'"
	$select=Invoke-Sqlcmd -Query $selectQuery -ServerInstance $Global:BaloiseBIDBserver -Database $Global:BaloiseReleaseVersionDB -Username $Global:BaloiseVersionDBuserid -Password $Global:BaloiseVersionDBuserpassword -ErrorVariable $out
	
	#checking for config dist zip file
	$configzip=$Deliveryfolder+"TechnicalTeam\"+$select.MIDC_Version+"\config-dist.zip"
	if(!(test-path $configzip)){
		$configFolder=$Deliveryfolder+"TechnicalTeam\"+$select.MIDC_Version+"\config-dist"
		Set-Location $configFolder
		cmd /c "zip -rq ..\config-dist.zip *"
	}
	
	$ITNdbpackagesZip=[String]::Format("{0}\ITN\{1}\database\cleva\maj_param_{1}.zip",$Deliveryfolder,$select.ITN_Version)
	#$ClevaDBpackage=[String]::Format("{0}\InitialInstallation\Cleva_{1}\*.zip",$Deliveryfolder,$select.Cleva_Version)
	#checkfing for ITN DB Zip folder
	if(!(test-path $ITNdbpackagesZip)){
		$ITNdbpackagesFolder=[String]::Format("{0}\ITN\{1}\database\cleva\maj_param_{1}",$Deliveryfolder,$select.ITN_Version)
		$zipfilename=[String]::Format("maj_param_{0}.zip",$select.ITN_Version)
		Set-Location $ITNdbpackagesFolder
		cmd /c "zip -rq ..\$zipfilename *"
	}
	
	
	$ClevaDBpackageZip=[String]::Format("{0}\InitialInstallation\Cleva_{1}\CLEVA_{1}.zip",$Deliveryfolder,$select.Cleva_Version)
	#checkfing for ITN DB Zip folder
	if(!(test-path $ClevaDBpackageZip)){
		$ClevaDBpackageFolder=[String]::Format("{0}\InitialInstallation\CLEVA_{1}",$Deliveryfolder,$select.Cleva_Version)
		$zipfilename=[String]::Format("CLEVA_{0}.zip",$select.Cleva_Version)
		Set-Location $ClevaDBpackageFolder
		cmd /c "zip -rq $zipfilename *"
	}
}

#check if Version is Already Deployed
$selectQuery="Select EnvironmentID from Environments where EnvironmentAlias='$Environment'"
$select=Invoke-Sqlcmd -Query $selectQuery -ServerInstance $Global:BaloiseBIDBserver -Database $Global:BaloiseReleaseVersionDB -Username $Global:BaloiseVersionDBuserid -Password $Global:BaloiseVersionDBuserpassword -ErrorVariable $out
$selectQuery="Select *  from [BuildVersionDeployments] where [BuildVersion]='$NewVersion' and EnvironmentID='$($select.EnvironmentID)'"
$select=Invoke-Sqlcmd -Query $selectQuery -ServerInstance $Global:BaloiseBIDBserver -Database $Global:BaloiseReleaseVersionDB -Username $Global:BaloiseVersionDBuserid -Password $Global:BaloiseVersionDBuserpassword -ErrorVariable $out
if($select){
	Write-host "$NewVersion Version is  already Deployed on $Environment . May be from a Jboss Pipeline"
}
	
$propertiesfile=[string]::Format("{0}Patch_ClevaDeploy.Properties",$Global:JenkinsPropertiesRootPath)
$propfile=getproperties -FilePath $propertiesfile
$propfile["Environment"]=$Environment
$propfile["version"]=$NewVersion
$propfile["ParamImportExport"]=$ParameterImport
setproperties -FilePath $propertiesfile -Properties $propfile

$NewVersionfolder=Join-path $PacakgeBase -ChildPath $NewVersion
New-Item -ItemType Directory -Path $NewVersionfolder
Copy-Item $templatelocation -Destination $NewVersionfolder -Force -Recurse

$selectQuery="Select * from ClevaVersions where Cleva_Version='$NewVersion'"
$select=Invoke-Sqlcmd -Query $selectQuery -ServerInstance $Global:BaloiseBIDBserver -Database $Global:BaloiseReleaseVersionDB -Username $Global:BaloiseVersionDBuserid -Password $Global:BaloiseVersionDBuserpassword -ErrorVariable $out

$versionfile=$ClevaDeliveryfolder+"$NewVersion\version"
Copy-Item $versionfile -Destination $NewVersionfolder -Force -Recurse
if($MIGNewVersionfolderName){
	$versionfile=join-path $NewVersionfolder -ChildPath "version"
	$filcontents=Get-Content $versionfile
	$filcontents | %{$_.replace($NewVersion,$MIGNewVersionfolderName)} | Set-Content $versionfile -Force
}

#server
$folder=$NewVersionfolder+"\server\"
#getting ears
$earpath=$Deliveryfolder+"TechnicalTeam\"+$select.MIDC_Version+"\*.ear"
Copy-Item  $earpath -Destination $folder -Force -Recurse

#gettingconfig files
$configzip=$Deliveryfolder+"TechnicalTeam\"+$select.MIDC_Version+"\config-dist.zip"
Copy-Item  $configzip -Destination $folder -Force -Recurse

 
 
$folder=$NewVersionfolder+"\webupdate\"
$UpdateSitepath=$Deliveryfolder+"TechnicalTeam\"+$select.MIDC_Version+"\updatesite*.zip"
Copy-Item  $UpdateSitepath -Destination $folder -Force -Recurse



$folder=$NewVersionfolder+"\prexlib_jar\"
$tarifxml=$Deliveryfolder+"tarification\"+$select.Tariff_Version +"\tarifs.xml"
$tariffs=$Deliveryfolder+"tarification\"+$select.Tariff_Version +"\T9-tarif-*"
Copy-Item  $tarifxml -Destination $folder -Force -Recurse
Copy-Item  $tariffs -Destination $folder -Force -Recurse
   

$batchfolder=$NewVersionfolder+"\batch\"
$envfile=$ClevaDeliveryfolder+$select.Cleva_Version +"\EnvironmentVariable.sh"
Copy-Item  $envfile -Destination $batchfolder -Force -Recurse
if($MIGNewVersionfolderName){
	$envfile=join-path $batchfolder -ChildPath "\EnvironmentVariable.sh"
	$filcontents=Get-Content $envfile
	$filcontents | %{$_.replace($NewVersion,$MIGNewVersionfolderName)} | Set-Content $envfile -Force
}

$paramscriptversion=[String]::Format("{0}\ParameterizationScripts\{1}\*.zip",$Deliveryfolder,$select.Param_Script_Version)
$dbfolder=$NewVersionfolder+"\database\cleva\"
Copy-Item  $paramscriptversion -Destination $dbfolder -Force -Recurse


$paramversion=[String]::Format("{0}\Params\{1}\*.zip",$Deliveryfolder,$select.Param_Version)
Copy-Item  $paramversion -Destination $dbfolder -Force -Recurse

$parfolder=$NewVersionfolder+"\batch"+"\pars\"
$dbscripttxtfile=$dbfolder+"\deployScripts.txt"
	
	
Write-Host "New $Environment Version Info"
Write-Host "================================================================="
Write-Host "Baloise Version      :" $NewVersionfolder
Write-Host "MDIC Version         :" $select.MIDC_Version
Write-Host "ITN  Version         :" $select.ITN_Version
Write-Host "TARIFF Version       :" $select.Tariff_Version
Write-Host "Param Script Version :" $select.Param_Script_Version
Write-Host "Param Version        :" $select.Param_Version
Write-Host "================================================================="


Write-Host "Preparing Database packages"
foreach($version in $DeploymentVersions){
	Write-Host "Checking Version :" $version
	$selectQuery="Select * from ClevaVersions where Cleva_Version='$version'"
	$select=Invoke-Sqlcmd -Query $selectQuery -ServerInstance $Global:BaloiseBIDBserver -Database $Global:BaloiseReleaseVersionDB -Username $Global:BaloiseVersionDBuserid -Password $Global:BaloiseVersionDBuserpassword -ErrorVariable $out
	if($select){
		$scriptpath=[String]::Format("{0}TechnicalTeam\{1}\config-batch\{2}\batch\shell_script\*.sh",$Deliveryfolder,$select.MIDC_Version,$Environment)
		$mparpath=[String]::Format("{0}\TechnicalTeam\{1}\config-batch\{2}\batch\template\*.mpar",$Deliveryfolder,$select.MIDC_Version,$Environment)
		$ITNdbpackages=[String]::Format("{0}\ITN\{1}\database\cleva\maj_*.zip",$Deliveryfolder,$select.ITN_Version)
		$ITNdbpackagePath=[String]::Format("{0}\ITN\{1}\database\cleva\",$Deliveryfolder,$select.ITN_Version)
		$ClevaDBpackage=[String]::Format("{0}\InitialInstallation\Cleva_{1}\*.zip",$Deliveryfolder,$select.Cleva_Version)
		if($select.ITN_Type -match "NEW" -and (Test-Path $ITNdbpackagePath)){
			$filename=Get-ChildItem  $ITNdbpackagePath -Filter *.zip 
			Copy-Item  $ITNdbpackages -Destination $dbfolder -Force -Recurse
			Add-Content $dbscripttxtfile -Value $filename
		}
		$val="CLEVA_"+$select.Cleva_Version+".zip"
		Add-Content $dbscripttxtfile -Value $val
		Copy-Item  $ClevaDBpackage -Destination $dbfolder -Force -Recurse
		if($ParameterImport -ieq "Y" -and $version -eq $NewVersion){
			$pname=$select.Param_Version
			$pname=$pname -replace "tables",""
			$pname=$pname -replace ".exp",""
			$paramtext=[string]::Format("import {0} force",$pname)
			Add-Content $dbscripttxtfile -Value "newparam"
			Add-Content $dbscripttxtfile -Value $paramtext
			
		}
	}
	else{
		Write-Host "Verison $version not found aborting.. packaging.."
		exit 1
	}


}


