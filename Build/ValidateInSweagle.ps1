# Enable -Verbose option
[CmdletBinding()]

PARAM(
	[string]$BuildID
	)

if (!$BuildID){
	$BuildID="DEV_Backend_20201125.1"
	$VerbosePreference = "Continue"
	#$VerbosePreference = "SilentlyContinue"
}

#Importing SQL modules for SQL commands to the Version database
Import-Module sqlps -DisableNameChecking
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	

$ApplicationName=$BuildID.Split("_")[1]
ValidateInSweagle -Application $ApplicationName -ScriptDir $ScriptDirectory