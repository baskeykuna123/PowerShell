﻿Param($ApplicationName,$Release,$Environment,$BuildVersion,$DeploymentStatus)

#loading Function
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	

Clear-Host 	
if(!$ApplicationName){
	$ApplicationName="MyBaloiseClassic"
	$Environment="dcorp"
	$BuildVersion="35.7.20210527.191707"
	$DeploymentStatus="stopping"
    $Release=35
}

Write-Host $ApplicationName
Write-Host $Environment
Write-Host $BuildVersion
Write-Host $DeploymentStatus
Write-Host $Release

#check if buildversion has the completed state
$BuildVersionIsCompleted=IsBuildVersionCompleted -BuildVersion $BuildVersion
if($BuildVersionIsCompleted.IsCompleted){
    $NewDeployInfo=CreateUpdateDeployVersion -ApplicationName $ApplicationName -Environment $Environment -BuildVersion $BuildVersion -DeploymentStatus $DeploymentStatus -Release $Release
}
else
{
    write-host "$BuildVersion is not in the completed state."
    exit 1
}

$propertiesfilename=[string]::Format("{0}_{1}_DeploymentStatus.properties",$ApplicationName, $Environment)
$deploymentPropertiesfile=join-path $Global:JenkinsPropertiesRootPath -ChildPath $propertiesfilename
setProperties -FilePath $deploymentPropertiesfile -Properties $NewDeployInfo