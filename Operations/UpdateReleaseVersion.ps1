Param($Environment,$ApplicationName,$Action,$ActionType,$Position)
#$Environment="DCORP"
#$ApplicationName="MyBaloiseClassic"
#$Action="upgrade"
#$ActionType="application"
##global,Application
#$Position="minor"
clear
#$ManifestFile="\\balgroupit.com\appl_data\BBE\Transfer\Packages\Scripts\InputParameters\GlobalReleaseManifest.xml"
$UpdatePropertiesScriptFilePath=[String]::Format("{0}Operations\UpdateProperties.ps1",$Global:ScriptSourcePath)
$xml = [xml](Get-Content Filesystem::$global:ReleaseManifest)
Write-Host "Maiifest File:" $xml
#Get the application no to be updated
$node=$xml.SelectSingleNode("/Release/environment[@Name='$Environment']/Application[@Name='$ApplicationName']")

# the position to be udpated
switch ($Position) 
      { 
        "Base"  { $pos=1}
		"Major" { $pos=2}
		"Minor" { $pos=3}
		"Patch" { $pos=4}   
      }
#Negating the position
if($Action -eq "Rollback")
{
$pos=-$pos
}

#Getting the Previous environments
switch ($Environment) 
      { 
        "ICORP" { $PreEnv="DCORP"}
		"ACORP" { $PreEnv="ICORP"}
		"PCORP" { $PreEnv="ACORP"}
      }

#Function to update the verions numbers
function ChangeVersion($version,[int]$pos)
{
$Base=$version.Split(".")[0]
$major=$version.Split(".")[1]
$Minor=$version.Split(".")[2]
$patch=$version.Split(".")[3]

	if($Environment -match "DCORP" -and $pos -eq 3)
	{
		$dt = (Get-Date).ToString("yyyMMdd")
		$time = (Get-Date).ToString("HHmmss")
		$newVersion=$Base + '.' + $major + '.' + $dt + '.' + $time
	}
 else
	{
switch ($pos) 
	    { 

	        1 {$newVersion=[string]([int]$Base+1) + '.' + [string]([int]$major*0) + '.' + [string]([int]$Minor*0) + '.' + [string]([int]$patch*0)} 
	        2 {$newVersion=$Base + '.' + [string]([int]$major+1) + '.' + [string]([int]$Minor*0) + '.' + [string]([int]$patch*0)} 
	        3 {$newVersion=$Base + '.' + $major + '.' + [string]([int]$Minor+1) + '.' + [string]([int]$patch*0)} 
	        4 {$newVersion=$Base + '.' + $major + '.' + $Minor + '.' + [string]([int]$patch+1)} 
			-1 {$newVersion=[string]([int]$Base-1) + '.' + $major + '.' + $Minor + '.' + [string]([int]$patch*0)} 
	        -2 {$newVersion=$Base + '.' + [string]([int]$major-1) + '.' + $Minor + '.' + [string]([int]$patch*0)} 
	        -3 {$newVersion=$Base + '.' + $major + '.' + [string]([int]$Minor-1) + '.' + [string]([int]$patch*0)} 
	        -4 {$newVersion=$Base + '.' + $major + '.' + $Minor + '.' + [string]([int]$patch-1)} 
	     }
	 }
return $newVersion
}


Write-Host "============================================================================"
Write-Host "ApplicationName : $ApplicationName"



if($ActionType -match "Global")
{
$Previousnode=$xml.SelectSingleNode("/Release/environment[@Name='$PreEnv']")
$node=$xml.SelectSingleNode("/Release/environment[@Name='$Environment']")
Write-Host "GlobalRelease Version : "$node.GlobalReleaseVersion
if($Action -match "Upgrade")
{
$node.GlobalReleaseVersion=changeVersion $node.GlobalReleaseVersion $pos
}
elseif($Action -match "promote")
{
$node.GlobalReleaseVersion = $Previousnode.GlobalReleaseVersion
}
Write-Host "Updated GlobalRelease Version : "$node.GlobalReleaseVersion
$xml.Save($global:ReleaseManifest)
}


if($ActionType -match "Application")
{
Write-Host "Application Version : "$node.Version

if($Action -match "Upgrade")
{
$ver=$node.Version
$newVersion=ChangeVersion $node.Version $pos
#updating the verion file accordingly
$node.PreviousVersion = $node.Version
$node.Version = $newVersion
}
elseif($Action -match "promote")
{

$ver=$node.Version
$Previousnode=$xml.SelectSingleNode("/Release/environment[@Name='$PreEnv']/Application[@Name='$ApplicationName']")
if($Previousnode.Version -ne $node.Version){$node.PreviousVersion = $node.Version }
$newVersion=$Previousnode.Version
$node.Version = $Previousnode.Version

}
Write-Host "Updated Application Version : "$node.Version
$xml.Save($global:ReleaseManifest)
& $UpdatePropertiesScriptFilePath $Environment $ApplicationName
}
Write-Host "======================================================================="
