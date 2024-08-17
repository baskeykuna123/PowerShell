param($Environment)
CLS

# loading Function
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop


$MFTServiceDeploySequenceXML=[String]::Format("{0}Esb\XML\Mercator.Esb.Services.Mft.DeploySequence.xml",$global:ESBRootFolder)
$xml=[XML](gc filesystem::$MFTServiceDeploySequenceXML)
$Services=$xml.'Package.DeploySequence'.ApplicationConfiguration.NTServices.NTService
$MFTServiceName=($Services.NTServiceName).innerText
if($Environment -ieq "PCORP"){
	Start-WindowsService -serviceName $MFTServiceName
}