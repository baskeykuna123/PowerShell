Param(
	[string]$Environment,
	[string]$sourceProjectName,
	[string]$buildnumber,
	[string]$ApplicationName,
	[string]$ServiceName,
	[string]$ExeName
    )

Clear

#default parameters for script Testing
if(!$buildnumber){
	$Environment="DCORP"
	$sourceProjectName='Baloise.Backend.BatchWindowsService'
	$buildnumber='DEV_Backend_20190306.5'
	$serviceName="BaloiseBackendBatch"
	$ExeName="Baloise.Backend.BatchWindowsService.exe"
	$ApplicationName="Backend"
}
#Loading All modules
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions -Force
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	

$ErrorActionPreference='Stop'

#get the user credentials for the service
$userdata=GetUserCreds -Appname $serviceName -Environment $Environment
$User=$userdata[0]
$Pwd=$userdata[1]
#$userdata=Get-UserCredentials -parameterName $serviceName -Environment $Environment -ApplicationType "NTService"
$existingService = Get-WmiObject -Class Win32_Service -Filter "Name='$serviceName'"
if ($existingService -ine $null) {
	Stop-WindowsService -serviceName $serviceName
}
ArtifactDeployer -buildnumber $buildnumber -SubApplicationName $ServiceName -ApplicationName  $ApplicationName -applicationType "WindowsService" -Environment $Environment -sourceProject $sourceProjectName
InstallWindowsService -serviceName $serviceName -ExeName $ExeName -username $User -password $Pwd -ApplicationType "WindowsService" -Environment $Environment
#if($ApplicationName -ieq "Backend"){
if($Environment -ine "PCORP"){
	Start-WindowsService -serviceName $serviceName
}
else{
	Write-Host "For $ApplicationName $Environment Windows Service automatic Start is Disabled"
}
#}
#else{
#	Start-WindowsService -serviceName $serviceName
#}


