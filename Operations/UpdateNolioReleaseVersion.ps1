Param($Environment,$ApplicationName,$Action,$Position)

try{
$ErrorActionPreference="stop"
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


switch ($pos) 
    { 
        1 {$newVersion=[string]([int]$Base+1) + '.' + [string]([int]$major*0) + '.' + [string]([int]$Minor*0) + '.' + [string]([int]$patch*0)} 
        2 {$newVersion=$Base + '.' + [string]([int]$major+1) + '.' + [string]([int]$Minor*0) + '.' + [string]([int]$patch*0)} 
        3 {$newVersion=$Base + '.' + $major + '.' + ([int]$Minor+1) + '.' + [string]([int]$patch*0)} 
        4 {$newVersion=$Base + '.' + $major + '.' + $Minor + '.' + [string]([int]$patch+1)} 
		-1 {$newVersion=[string]([int]$Base-1) + '.' + [string]([int]$major*0) + '.' + [string]([int]$Minor*0) + '.' + [string]([int]$patch*0)} 
        -2 {$newVersion=$Base + '.' + [string]([int]$major-1) + '.' + [string]([int]$Minor*0) + '.' + [string]([int]$patch*0)} 
        -3 {$newVersion=$Base + '.' + $major + '.' + [string]([int]$Minor-1) + '.' + [string]([int]$patch*0)} 
        -4 {$newVersion=$Base + '.' + $major + '.' + $Minor + '.' + [string]([int]$patch-1)} 
     }
return $newVersion
}

$OriginalApplicationName = $ApplicationName 
Write-Host "ApplicationName : $OriginalApplicationName"
Write-Host "====================================================================="

if($ApplicationName -match "MercatorESB2016"){
    $ApplicationName = "MercatorESB"
    Write-Host "ApplicationName set to : $ApplicationName"
    $globalReleaseManifest = 'D:\Nolio\Repository\GlobalReleaseManifest.xml'
    $masterXmlFile = 'D:\Nolio\Repository\MercatorEsb.Master.Manifest.xml'
}
elseif ($ApplicationName -match "MercatorEAI2016"){
    $ApplicationName = "MercatorEAI"
    Write-Host "ApplicationName set to : $ApplicationName"
    $globalReleaseManifest = 'D:\Nolio\Repository\GlobalReleaseManifest.xml'
    $masterXmlFile = 'D:\Nolio\Repository\MercatorEsbEai.Master.Manifest.xml'
}
else{
    $globalReleaseManifest = '\\shw-me-pdnet01\Repository\GlobalReleaseManifest.xml'
    $masterXmlFile = '\\shw-me-pdnet01\Repository\MercatorEsb.Master.Manifest.xml'
    if($ApplicationName -match "MercatorEAI") {
        $masterXmlFile = '\\shw-me-pdnet01\Repository\MercatorEsbEai.Master.Manifest.xml'
    }
}

$Manifestxml = [xml](Get-Content $globalReleaseManifest )
$BackupManifest = [xml](Get-Content $globalReleaseManifest )
$GlobalReleasenode=$Manifestxml.SelectSingleNode("/Release/environment[@Name='$Environment']/Application[@Name='$ApplicationName']")

$date=Get-Date
$xml = [xml](Get-Content $masterXmlFile )
$backupMasterXML=[xml](Get-Content $masterXmlFile )
$node=$xml.SelectSingleNode("/Manifest/Release/environment[@name='$Environment']")

Write-host "Current Nolio Manifest Version : "$node.version
if($Environment -match "DCORP"){
    #Set build version
    $major=$node.version.Split(".")[0]
    $minor=$node.version.Split(".")[1]
    $build=$date.ToString("yyyMMdd")
    $revision=$date.ToString("HHmmss")
    $newVersion=$major + '.' + $minor + '.' + $build + '.' + $revision
}
else{
    if($Action -match "Promote") {
        $PrevEnv=$xml.SelectSingleNode("/Manifest/Release/environment[@name='$PreEnv']")
        $newVersion=$PrevEnv.version
    } 	
    else{
        $newVersion=ChangeVersion $node.version $pos
    }
}

Write-host "Updated Nolio Manifest Version : "$newVersion
Write-Host "======================================================================="
#Set manifest version
write-host "Global Release Manifest Nolio Version : "$GlobalReleasenode.NolioVersion
$node.version = $newVersion
$manifest=$xml.SelectSingleNode("/Manifest")
$manifest0=[int]$manifest.getAttribute("version").Split(".")[0]
$manifest1=[int]$manifest.getAttribute("version").Split(".")[1]
$manifest1++
$newManifestVersion=$manifest0.ToString() + "." + $manifest1.ToString()
$manifest.SetAttribute("version", $newManifestVersion)
#Save changes
$GlobalReleasenode.NolioPreviousVersion = $GlobalReleasenode.NolioVersion
$GlobalReleasenode.NolioVersion = $newVersion
Write-Host "Update Global Release Manifest Nolio Version : "$GlobalReleasenode.NolioVersion

Write-Host "`n======================================================================="
$Manifestxml.Save($globalReleaseManifest)
$xml.Save($masterXmlFile)
&".\Operations\UpdateProperties.ps1" $Environment $OriginalApplicationName
}
catch {
$BackupManifest.Save($globalReleaseManifest)
$backupMasterXML.Save($masterXmlFile)
write-host "There was an error in updating the Manifest:`n" -ForegroundColor Red
write-host "#*#**#*#**##**#*#*#*#**#*#**#*#*#**#*# No All changes have been rolled back #*#**#*#**##**#*#*#*#**#*#**#*#*#**#*# `n" -ForegroundColor Red

throw $Error[0]

}