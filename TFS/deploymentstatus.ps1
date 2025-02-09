param($ApplicationName,$Environment,$BuildVersion,$DeploymentStatus,$ReleaseID)

clear
#loading Function
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}

$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop

If(!$ReleaseID){
	$ReleaseID=''
}
#$ApplicationName = "NINADB" 
if(($ApplicationName -ieq "NINADB") -and ($Environment -ieq "DCORP")){
	$file_content = Get-Content "$Global:JenkinsPropertiesRootPath\DCORP_AT-NINADeploy.Properties"
	$file_content = $file_content -join [Environment]::NewLine
	$configuration = ConvertFrom-StringData($file_content)
	$mergeid = $configuration.'MergeID'
	$buildnumber = $configuration.'BuildNumber'
	$BuildVersion = $buildnumber + "_" + $mergeid
	#$Environment="DCORP"
	#$DeploymentStatus="Completed"
}

#creating the new version based on the input
#$NewDeployInfo=CreateUpdateDeployVersion -ApplicationName $ApplicationName -Environment $Environment -BuildVersion $BuildVersion -DeploymentStatus $DeploymentStatus -Release $Release

	ExecuteSQLonBIVersionDatabase "EXEC CreateDeploymentStatus @Application='$ApplicationName',@Environment='$Environment',@BuildVersion='$BuildVersion',@DeploymentStatus='$DeploymentStatus',@releaseID='$ReleaseID'"


