
Param(
	[string]$Envrionment,
	[string]$sourceProjectName,
	[string]$BuildNumber,
	[string]$ApplicationName,
	[string]$WebHostApplicationName,
	[string]$IISAppType
)

Clear

#default parameters for script Testing
if(!$buildnumber){
	$Envrionment="DCORP"
	$sourceProjectName='Baloise.Backend.BusinessServices'
	$buildnumber='DEV_Backend_20190306.5'
	$ApplicationName="Backend"
	$WebHostApplicationName="BaloiseBackend"
	$IISAppType="WebApplication"
}

$ErrorActionPreference='Stop'

#Loading All modules
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions -Force
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	
if(($WebHostApplicationName -ieq "MyBaloiseBroker") -and ($Envrionment -ine "ICORP") -and ($Envrionment -ine "DCORP") -and ($Envrionment -ine "PCORP")){
	Stop-AppPool -AppPoolName $ApplicationName
}
else{
	Stop-AppPool -AppPoolName $WebHostApplicationName
}

ArtifactDeployer -buildnumber $buildnumber -ApplicationName $ApplicationName -applicationType $IISAppType -Environment $Envrionment -sourceProject $sourceProjectName -SubApplicationName $WebHostApplicationName

if(($WebHostApplicationName -ieq "MyBaloiseBroker") -and ($Envrionment -ine "ICORP") -and ($Envrionment -ine "DCORP") -and ($Envrionment -ine "PCORP")){
	Start-AppPool -AppPoolName $ApplicationName
}
else{
	Start-AppPool -AppPoolName $WebHostApplicationName
}	
