Clear;

#loading functions
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop

$Date=Get-Date -Format yyyyMMddhhmm
$BackupFolder = $global:SharedScriptsBackup + $Date

if(-not(Test-Path $BackupFolder)){
New-Item $BackupFolder -ItemType Directory -Force -Verbose
Copy-Item $Global:ScriptSourcePath -Destination $BackupFolder -Recurse -Force -Verbose 
}
else
{
Write-Host "Backup Folder exists already."
}

