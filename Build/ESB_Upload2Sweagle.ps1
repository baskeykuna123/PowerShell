PARAM(
	[string]$BuildVersion,
	[string]$Environment="dcorp",
    [string]$EsbOrEai="Esb"
	)

#Importing SQL modules for SQL commands to the Version database
Import-Module sqlps -DisableNameChecking
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	


if (!$BuildVersion){
    $BuildVersion="34.4.20201125.190045"
    $Environment="dcorp"
    $EsbOrEai="Esb"
}

clear

if($EsbOrEai -ieq "Esb"){
    $BuildOutputPath="e:\P.ESB"
    $ApplicationName="Esb"
}
else{
    $BuildOutputPath="e:\P.EAI"
    $ApplicationName="Eai"
}

$PackageSource=Join-Path $BuildOutputPath -ChildPath $BuildVersion
$parameterFileResolved=Join-Path $PackageSource -ChildPath "ESBDeploymentParameters_Resolved.xml"
    
Upload2Sweagle -paramFileResolved $parameterFileResolved -Application $ApplicationName -Buildversion $BuildVersion -ScriptDir $ScriptDirectory