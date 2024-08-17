
Param(
	[string]$Envrionment,
	[string]$ApplicationName,
	[string]$WebHostApplicationName,
	[string]$IISAppType
)

Clear

#default parameters for script Testing
if(!$WebHostApplicationName){
	$Envrionment="ICORP"
	$ApplicationName="NINA"
	$WebHostApplicationName="Baloise.Nina.WCF"
	$IISAppType="Websites"
}

#Loading All modules
#Loading All modules
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions -Force
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	

if($ApplicationName -ieq "NINA"){
	if($WebHostApplicationName -ieq "Baloise.Nina.WCF"){
		Write-Host "**NINA post Deployment actions - Dowload XSD to WCF website**"
    	$Deploymentfolder=Get-DeploymentFolder -ApplicationName $WebHostApplicationName -ApplicationType $IISAppType
    	NINADownloadXSDAfterDeployment -Environment $Envrionment -DeploymentFolder $Deploymentfolder
	}
}
else{
    Write-host "No Post Deployment Actions specified"
}
