param (
    [string]$targetApplication,
    [bool]$writeResultToEventLog=$false
)

if (!$targetApplication){
    $targetApplication="Mercator.Framework.Document.Management.Global360"
    $writeResultToEventLog=$true
}

# loading Function
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop

Recycle-ComPlus -targetApplication $targetApplication -writeResultToEventLog $writeResultToEventLog