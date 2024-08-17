Param($ApplicationName,$Release,$Environment,$BuildVersion,$DeploymentStatus,$currentUser)

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
	$BuildVersion="35.7.20210713.14:30"
	$DeploymentStatus="deploying"
    $Release=35
    $currentUser="Renders, Kurt"
}

Write-Host $ApplicationName
Write-Host $Environment
Write-Host $BuildVersion
Write-Host $DeploymentStatus
Write-Host $Release

#check if buildversion has the completed state
try{
    $NewDeployInfo=ManualFixDeployVersion -ApplicationName $ApplicationName -Environment $Environment -BuildVersion $BuildVersion -DeploymentStatus $DeploymentStatus -Release $Release -currentUser $currentUser
}
catch{
    throw $_
}

$propertiesfilename=[string]::Format("{0}_{1}_DeploymentStatus.properties",$ApplicationName, $Environment)
$deploymentPropertiesfile=join-path $Global:JenkinsPropertiesRootPath -ChildPath $propertiesfilename
setProperties -FilePath $deploymentPropertiesfile -Properties $NewDeployInfo