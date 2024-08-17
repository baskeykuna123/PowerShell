ClS

#loading functions
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop

$ErrorActionPreference='Stop'
$BIDashboardDeployment_Location = Join-Path $global:FrontWebApplicationRoot -ChildPath "BIDashboard\Files"

Remove-Item "$BIDashboardDeployment_Location\*" -Force -Include "*.htm"

If(-not (Test-Path $BIDashboardDeployment_Location)){
	New-Item $BIDashboardDeployment_Location -ItemType Directory -Force | Out-Null
}
Stop-AppPool -AppPoolName "BIDashboard"
Copy-Item "$global:EnvironmentHTMLReportLocation\*" -Recurse -Destination $BIDashboardDeployment_Location -Verbose -Force
Start-AppPool -AppPoolName "BIDashboard"

