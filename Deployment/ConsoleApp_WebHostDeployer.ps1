
Param(
	[string]$Envrionment,
	[string]$sourceProjectName,
	[string]$BuildNumber,
	[string]$ApplicationName,
	[string]$WebHostApplicationName,
	[string]$AppType
)

Clear

#default parameters for script Testing
if(!$buildnumber){
	$Envrionment="DCORP"
	$sourceProjectName='Baloise.Backend.BusinessServices'
	$buildnumber='DEV_Backend_20190306.5'
	$ApplicationName="Backend"
	$WebHostApplicationName="BaloiseBackend"
	$AppType="ImportMandates"
}

$ErrorActionPreference='Stop'

#Loading All modules
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions -Force
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	

ArtifactDeployer -buildnumber $buildnumber -ApplicationName $ApplicationName -applicationType $AppType -Environment $Envrionment -sourceProject $sourceProjectName -SubApplicationName "ImportMandate"

