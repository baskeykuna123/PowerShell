param($Environment,$App,$Version)

#loading Function
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	



Clear-Host

if(!$Version){
$Version="32.7.2.0"
$Environment="ICORP"
}

$backlocalSetupkitpath = "E:\Program Files\Mercator\Setupkits\"
$frontlocalSetupkitpath = "E:\Mercator\Setupkits\"
#$xml = [xml](Get-Content Filesystem::$global:ReleaseManifest)
#$node = $xml.SelectSingleNode("/Release/environment[@Name='$Environment']/Application[@Name='MyBaloiseClassic']")
$ClassicBaseversion = $Version.Split('.')[0] + '.' + $Version.Split('.')[1]

if ($Environment -match "DCORP") {
	$curentVersion = [string]::Format("{0}.{1}.0",$ClassicBaseversion,(Get-Date -Format "yyyyMMdd"))
	$FSourcePath = [string]::Format("\\shw-me-pdtalk51\Released Deliverables\MN{0}\Software Kits\{1}\Server\SETUP Mercator FrontWebFarm Server.EXE",[string]$ClassicBaseversion,$curentVersion)
	$BSourcePath = [string]::Format("\\shw-me-pdtalk51\Released Deliverables\MN{0}\Software Kits\{1}\Server\SETUP BackOfficesServerWin2012.EXE",[string]$ClassicBaseversion,$curentVersion)
	$DFSsourcepath = [string]::Format("\\shw-me-pdtalk51\Released Deliverables\MN{0}\Software Kits\{1}\Server\Setup DFS_DataDeployment.exe",[string]$ClassicBaseversion,$curentVersion)
}
else {
	$FSourcePath = [string]::Format("\\shw-me-pdtalk51\Released Deliverables\MercatorNet Release {0}\Software Kits\{1}\Server\SETUP Mercator FrontWebFarm Server.EXE",[string]$ClassicBaseversion,[string]$Version)
	$BSourcePath = [string]::Format("\\shw-me-pdtalk51\Released Deliverables\MercatorNet Release {0}\Software Kits\{1}\Server\SETUP BackOfficesServerWin2012.EXE",[string]$ClassicBaseversion,[string]$Version)
	$DFSsourcepath = [string]::Format("\\shw-me-pdtalk51\Released Deliverables\MercatorNet Release {0}\Software Kits\{1}\Server\Setup DFS_DataDeployment.exe",[string]$ClassicBaseversion,[string]$Version)
}

$DFSsourcepath
$FSourcePath
Write-Host "***************************************************************"
Write-Host "$App Deployment version    : " $Version
Write-Host "$App Global version        : " $node.ParentNode.GlobalReleaseVersion
Write-Host "$App build version         : " $node.ParentNode.MercatorBuildVersion
Write-Host "***************************************************************"
if ($App -match "Front") {
	Write-Host "$App Setup Kit Path : " $FSourcePath
	Copy-Item -Path $FSourcePath -Destination $frontlocalSetupkitpath -Force

	Write-Host "Running Pre Install/uninstall Command"
	Set-Location "E:\Mercator\Deployment\"
	& "E:\Mercator\Deployment\WEBFMServer_PreInstall.bat"

	Write-Host "Restarting IIS for setupkit Installation"
	IISRESET /START


	Write-Host "Running the Setupkit........ E:\Mercator\Setupkits\SETUP Mercator FrontWebFarm Server.EXE"
	Start-Process "E:\Mercator\Setupkits\SETUP Mercator FrontWebFarm Server.EXE - Shortcut.lnk" -Wait

	Set-Location "Batch"
	Write-Host "SYNCING Prog ID......"
	& "E:\Mercator\Deployment\Batch\WEBFM_syncprogid.bat"

}
elseif ($App -match "back")
{
	Write-Host "$App Setup Kit Path : " $BSourcePath
	Write-Host "DFS Setup Kit Path : " $DFSsourcepath
	Copy-Item -Path $BSourcePath -Destination $backlocalSetupkitpath -Force
	Copy-Item -Path $DFSsourcepath -Destination $backlocalSetupkitpath -Force

	Write-Host "Running Pre Install/uninstall Command"
	Set-Location "E:\Program Files\Mercator\Deployment\"
	& "E:\Program Files\Mercator\Deployment\ServicesServer_PreInstall.bat"
	
	Write-Host "Running the DFS Setupkit before iis start........"
	if (Test-Path ("E:\Program Files\mercator\Setupkits\Setup DFS_DataDeployment - Shortcut.lnk")) {
		Start-Process "E:\Program Files\mercator\Setupkits\Setup DFS_DataDeployment - Shortcut.lnk" -Wait
	}
	
	Write-Host "Restarting IIS for setupkit Installation"
	IISRESET /START

	Write-Host "Running the Setupkit........E:\Program Files\mercator\Setupkits\SETUP BackOfficesServerWin2012.EXE"
	Start-Process "E:\Program Files\mercator\Setupkits\SETUP BackOfficesServerWin2012 - Shortcut.lnk" -Wait

	& "e:\Program Files\Mercator\Deployment\Scripts\Set-ServiceStartupType_BackofficeNodes.ps1"

}
Write-Host "***************************************************************"
