PARAM($Application,$Environment)


if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions -Force
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	
Clear

if(!$Application){
	$Application="CLEVA"
	$Environment="PLAB"
}

$Action="unreserve"

Write-Host "============================================================="
Write-Host "Environment : " $Environment
Write-Host "Application : " $Application
Write-Host "============================================================="	

#	if($Application -ieq "CLEVA"){
#		$CLEVAEnv=GetClevaEnvironment -Environment $Environment
#		$Deploymentfolder=GetDeploymentPackageFolder -Environment $CLEVAEnv
#		if($Deploymentfolder){
#			Write-Host "`r`n`r`nDeployment Pacakge was found. The Deployment will be triggered`r`n`r`n"
#			ManageJenkinsResources -Environment $Environment -Action $Action -Application $Application
#		}
#		else{
#			Write-host "`r`n`r`nThere are no Deployment packages found for Deployment....Nothing to do!!!!`r`n`r`n"
#		}
#	}
#	else{
		ManageJenkinsResources -Environment $Environment -Action $Action -Application $Application
#	}