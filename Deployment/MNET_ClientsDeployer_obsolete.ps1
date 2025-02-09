param($Version,$environment)
#Paths and Variables
Clear


#loading Function
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	

if(!$environment){
	$environment="ICORP"
	$Version="33.7.0.0"
}
$confenvironment=$environment
if($environment -match 	"PCORP"){
	$confenvironment="PROD"
}

#$xml = [xml](Get-Content Filesystem::$global:ReleaseManifest )
#$node=$xml.SelectSingleNode("/Release/environment[@Name='$Environment']/Application[@Name='MyBaloiseClassic']")
$ClassicBaseversion=$Version.Split('.')[0] + '.' +$Version.Split('.')[1]

if($environment -match 	"DCORP"){
	$ClientSourcePath=[string]::Format("\\SHW-ME-PDTALK51\F$\Released Deliverables\MN{0}\Software Kits\{1}\Client\",[string]$ClassicBaseversion,[string]$Version)
}
else{
	$ClientSourcePath=[string]::Format("\\SHW-ME-PDTALK51\F$\Released Deliverables\MercatorNet Release {0}\Software Kits\{1}\Client\",[string]$ClassicBaseversion,[string]$Version)
}
$CitrixClientShare=[string]::Format("\\balgroupit.com\Appl_Data\BBE\Transfer\MercatorNet\Citrix_OneClient\MercatorNet\{0}-Current\",$environment)
$CitrixClientDC3Share=[string]::Format("\\balgroupit.com\Appl_Data\BBE\Transfer\MercatorNet\Citrix_OneClient\MercatorNet\{0}-Current-RZ3\",$environment)
$CitrixEXE="MercatorNet Citrix Client Setup.exe"

$FatClientShare=[string]::Format("\\balgroupit.com\Appl_Data\BBE\transfer\DMS\Citrix_OneClient\IPclient\{0}-Current\",$environment)
$FatClientDC3Share=[string]::Format("\\balgroupit.com\Appl_Data\BBE\transfer\DMS\Citrix_OneClient\IPclient\{0}-Current-RZ3\",$environment)
$FatClientEXE="SETUP DMS IPClient B1C.EXE"

$Brandkastshare=[string]::Format("\\balgroupit.com\Appl_Data\BBE\transfer\DMS\Citrix_OneClient\Brandkast2016\{0}_Current",$environment) 
$Brandkastbackup=[string]::Format("\\balgroupit.com\Appl_Data\BBE\transfer\DMS\Citrix_OneClient\Brandkast2016\{0}_Previous_Version\",$environment)
$BrandKastFolder="MulticompanyBrandkast"
if($environment -match 	"DCORP"){
	$BrandkastconfigfilePath=[string]::Format("\\Shw-me-pdtalk51\f$\Released Deliverables\MN{0}\Software Kits\{1}\Client\MulticompanyBrandkast\",[String]$ClassicBaseversion,[string]$Version)
}
else{
	$BrandkastconfigfilePath=[string]::Format("\\Shw-me-pdtalk51\f$\Released Deliverables\MercatorNet Release {0}\Software Kits\{1}\Client\MulticompanyBrandkast\",[String]$ClassicBaseversion,[string]$Version)
}
$Brandkastconfigfile=[string]::Format("{0}BrandkastControl.DLL.config",$confenvironment)

write-host "`n`n***************************************************************"
Write-Host "$environment FatClient Deployment"
write-host "***************************************************************"
write-host "Client EXE Source : "$ClientSourcePath
$clientfile=$CitrixClientShare+$CitrixEXE
$ver=[string]((Get-Item $clientfile).VersionInfo.FileVersion)
write-host "MyBaloiseClassic Client Deployment Version(existing): "$ver
write-host "MyBaloiseClassic Client Deployment Version(new): "$Version
$newfilename=$CitrixEXE -ireplace ".exe",("_"+$ver+(get-date).ToString("_yyyyMMdd-HHmmss")+".exe")
$backupppath=$CitrixClientShare+"Previous Version\"
Move-Item "$CitrixClientShare$CitrixEXE" -Destination $backupppath 
Rename-Item -Path "$backupppath$CitrixEXE" -NewName "$newfilename"
Copy-Item "$ClientSourcePath$CitrixEXE" -Destination $CitrixClientShare -Force
Write-Host "Citrix client movement completed to the following path : `n$CitrixClientShare"
write-host "***************************************************************"
if(test-path $CitrixClientDC3Share){
Copy-Item "$ClientSourcePath$CitrixEXE" -Destination $CitrixClientDC3Share -Force 
Write-Host "Citrix client movement completed to the following path : `n$CitrixClientDC3Share"
}
write-host "***************************************************************"

write-host "`n`n***************************************************************"
Write-Host "$environment FatClient Deployment"

write-host "***************************************************************"
$clientfile=$FatClientShare+$FatClientEXEa
$ver=[string]((Get-Item $clientfile).VersionInfo.FileVersion)
$newfilename=$FatClientEXE -ireplace ".exe",("_"+$ver+(get-date).ToString("_yyyyMMdd-HHmmss")+".exe")
$backupppath=$FatClientShare+"Previous Version\"
$sourcefile=
write-host "MyBaloiseClassic FAT Client Deployment Version (existing): "$ver
$nver=[string]((Get-Item "$ClientSourcePath$FatClientEXE").VersionInfo)
write-host "MyBaloiseClassic FAT Client Deployment Version (new): "$nver
Move-Item "$FatClientShare$FatClientEXE" -Destination $backupppath 
Rename-Item -Path "$backupppath$FatClientEXE" -NewName "$newfilename"
Copy-Item "$ClientSourcePath$FatClientEXE" -Destination $FatClientShare -Force
Write-Host "FatClient movement completed to the following path : `n$FatClientShare"
write-host "***************************************************************"
if(test-path $FatClientDC3Share){
Copy-Item "$ClientSourcePath$FatClientEXE" -Destination $FatClientDC3Share -Force
Write-Host "FatClient movement completed to the following path : `n$FatClientDC3Share"
}
write-host "***************************************************************"


write-host "`n`n***************************************************************"
Write-Host "$environment Brand kast Deployment"
write-host "***************************************************************"
$fname=(get-date).ToString("yyyyMMdd_HHmmss")
New-Item -Path "$Brandkastbackup$fname" -ItemType Directory -Force
Write-host "Bandkast Deployment : "$Version
Write-host "source Location : $ClientSourcePath$BrandKastFolder"
$environmentXmlFile=  Join-Path  $BrandkastconfigfilePath -ChildPath "xml\Environments.xml"
$configfile = Get-ChildItem -Path $BrandkastconfigfilePath -Recurse -Include $Brandkastconfigfile | sort -property LastWriteTime -Descending | select -First 1
Write-host "Config file  : $configfile"
Move-Item "$Brandkastshare\*" -Destination "$Brandkastbackup$fname" -force
If(! $configfile){
    Write-Host "WARNING : Client File not found at source location"
}
copy-item "$ClientSourcePath$BrandKastFolder\*" -Destination $Brandkastshare -force -Recurse
ConfigDeployer -ParameteXMLFile $environmentXmlFile -Environment $environment -DeploymentFolder $Brandkastshare
Write-Host "BrandKast movement completed to the following path : `n$Brandkastshare"
write-host "***************************************************************"

#for PCORP only
$BrandkastPreProd="\\balgroupit.com\Appl_Data\BBE\transfer\DMS\Citrix_OneClient\Brandkast\PreProd\"
$CitrixClientPreProd="\\balgroupit.com\Appl_Data\BBE\Transfer\MercatorNet\Citrix_OneClient\MercatorNet\PreProd\"
$FatClientPreProd="\\balgroupit.com\Appl_Data\BBE\transfer\DMS\Citrix_OneClient\IPclient\PreProd\"


if($environment -ieq "PCORP"){
#MNET Client
Remove-Item "$CitrixClientPreProd*" -Force -Recurse
Copy-Item $ClientSourcePath$CitrixEXE -Destination $CitrixClientPreProd

#FATClient
Remove-Item "$FatClientPreProd*" -Force -Recurse
Copy-Item $ClientSourcePath$FatClientEXE -Destination $FatClientPreProd

#BrandKast
Remove-Item "$BrandkastPreProd*" -Force -Recurse
Copy-Item "$Brandkastshare\*" -Destination $BrandkastPreProd
}
