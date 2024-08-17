PARAM([string]$Environment,$Version)


#loading Function
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	

if(!$Environment){
$Environment="ICORP"
}


$Setupkitpath = "E:\Program Files\Mercator\Setupkits\"
#$xml = [xml](Get-Content Filesystem::$global:ReleaseManifest )
#$node = $xml.SelectSingleNode("/Release/environment[@Name='$Environment']/Application[@Name='MyBaloiseClassic']")
#$ClassicBaseversion = $node.Version.Split('.')[0] + '.' + $node.Version.Split('.')[1]

$ClassicBaseversion = $Version.Split('.')[0]+'.'+$Version.Split('.')[1]

if ($Environment -match "DCORP") {
	$curentVersion = [string]::Format("{0}.{1}.0",$ClassicBaseversion,(Get-Date -Format "yyyyMMdd"))
	$DocserviceSourcePath = [string]::Format("\\shw-me-pdtalk51\Released Deliverables\MN{0}\Software Kits\{1}\Server\SETUP EAIDOCSERVICE Server.exe",[string]$ClassicBaseversion,$curentVersion)
}
else {
	$DocserviceSourcePath = [string]::Format("\\shw-me-pdtalk51\Released Deliverables\MercatorNet Release {0}\Software Kits\{1}\Server\SETUP EAIDOCSERVICE Server.exe",[string]$ClassicBaseversion,$Version)
}

Copy-Item Filesystem::$DocserviceSourcePath -Destination $Setupkitpath -Force

# Bat file to be executed on Doc Server
$Utilities = "E:\Program Files\Mercator\SetupKits\"
$PreInstaller = "E:\Program Files\Mercator\SetupKits\EAIDOCSERVICE_Stop.bat"
Set-Location $Utilities
& $PreInstaller 

# Run Silent Installer bat file
Write-host "Running $SilentInstaller.."
$SilentInstaller = "E:\Program Files\Mercator\SetupKits\SETUP EAIDOCSERVICE Server.EXE - Shortcut.lnk"
Start-Process $SilentInstaller -Wait -Verbose -WorkingDirectory $Setupkitpath

# Restarting the Doc Service
$Utilities = "E:\Program Files\Mercator\Eai\InstallationUtilities"
$StartDOCservice = Join-Path $Utilities "EAIDOCSERVICE_Start.bat"
Set-Location $Utilities
& $StartDOCservice 