param([String] $Environment)

Clear-Host

#loading Functions
if(Get-Module -Name LoadFunctions){
	Remove-Module LoadFunctions -Force
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop

if(!$Environment){
	$Environment="dcorp"
}

$ErrorActionPreference='Stop'
$App01RootFolder="\\balgroupit.com\appl_data\bbe\App01"
#$App01RootFolder="F:\temp"

Write-Host "================================================"
Write-Host "Environment:"$Environment
Write-Host "================================================"

Function GetMaintenanceModeUsers ($MaintenanceModeFolder, $UserKey)
{
	if (Test-Path $MaintenanceModeFolder)
	{
		$fileCount = Get-ChildItem -Path $MaintenanceModeFolder | Measure-Object | %{$_.Count}
		if ($fileCount -gt 1){
			$file = Get-ChildItem -Path $MaintenanceModeFolder | Where-Object {$_.Name -notmatch "NOT_IN_*"}
			[xml] $xmlFile = Get-Content $file.FullName
			Write-Host $fileCount "files found in folder " $MaintenanceModeFolder " !!"
			Write-Host "Maintenance Mode Users of file " $file.FullName
		}
		else{
			$file = Get-ChildItem -Path $MaintenanceModeFolder 
			[xml] $xmlFile = Get-Content $file.FullName
		}
		
		$xpath = '//configuration/appSettings/add[@key="' + $UserKey + '"]'
		$users = $xmlFile.SelectSingleNode($xpath).Value
		return $users 		
	}
	else
	{
		Write-Host "Folder not found. Check maintenance mode directory " $MaintenanceModeFolder
	}
}

Write-host "Getting Maintenance Mode users for : " $Environment

#MyBaloiseClassic
$folder=[string]::Format("{0}\{1}\MercatorNet\MaintenanceModeFiles\Internal",$App01RootFolder,$Environment)
$MMUsers = GetMaintenanceModeUsers $folder "MaintenanceUsers"
Write-host "MyBaloiseClassic Internal : " $MMUsers

$folder=[string]::Format("{0}\{1}\MercatorNet\MaintenanceModeFiles\Broker",$App01RootFolder,$Environment)
$MMUsers = GetMaintenanceModeUsers $folder "MaintenanceUsers"
Write-host "MyBaloiseClassic Broker : " $MMUsers

#MyBaloiseWeb
$folder=[string]::Format("{0}\{1}\MercatorWeb\MercatorWebBroker\MaintenanceMode",$App01RootFolder,$Environment)
$MMUsers = GetMaintenanceModeUsers $folder "Users"
Write-host "MyBaloiseWeb Broker : " $MMUsers
