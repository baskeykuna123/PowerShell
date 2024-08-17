param([String] $Environment)
Clear-Host
if(!$Environment){
	$Environment="dcorp"
}
$App01RootFolder="\\balgroupit.com\appl_data\bbe\App01"
#$App01RootFolder="F:\temp"

$ErrorActionPreference='Stop'

Write-Host "============================================"
Write-Host "Environment:"$Environment
Write-Host "============================================"

Function CheckMaintenanceModeFile ($MaintenanceModeFolder)
{
	if (Test-Path $MaintenanceModeFolder)
	{
		$file = Get-ChildItem -Path $MaintenanceModeFolder 
		if ($file.Name.StartsWith("IN_") ){
			return "In maintenance mode"
		}
		else{
			return "Not in maintenance mode"
		}
		
	}
	else
	{
		Write-Host "Folder not found. Check maintenance mode directory " $MaintenanceModeFolder
	}
}

Write-host "Checking Maintenance Mode for : " $Environment

#MyBaloiseClassic
$folder=[string]::Format("{0}\{1}\MercatorNet\MaintenanceModeFiles\Internal",$App01RootFolder,$Environment)
$Mode = CheckMaintenanceModeFile $folder
Write-host "MyBaloiseClassic Internal : " $Mode

$folder=[string]::Format("{0}\{1}\MercatorNet\MaintenanceModeFiles\Broker",$App01RootFolder,$Environment)
$Mode = CheckMaintenanceModeFile $folder
Write-host "MyBaloiseClassic Broker : " $Mode

#MyBaloiseWeb
$folder=[string]::Format("{0}\{1}\MercatorWeb\MercatorWebBroker\MaintenanceMode",$App01RootFolder,$Environment)
$Mode = CheckMaintenanceModeFile $folder
Write-host "MyBaloiseWeb Broker : " $Mode
