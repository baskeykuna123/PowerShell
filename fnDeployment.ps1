$ScriptDirectory=split-path $MyInvocation.MyCommand.Definition -Parent
#loading Utilities
. "$ScriptDirectory\SetGlobalParameters.ps1"

Function ArtifactDeployer(){
Param($Environment,$ApplicationName,$buildnumber,$sourceProject,$applicationType,$AppDataFolder)
	
	$PackageSource=[string]::Format('{0}\{1}_{2}\{3}\',$global:PackageRoot,$buildnumber.split('_')[0],$buildnumber.split('_')[1],$buildnumber.split('_')[2])
	$ApplicationSource= join-path $PackageSource -ChildPath "$sourceProject\"
	$AppDataFolder=[string]::Format('{0}\{1}\{2}',$global:AppShareRoot,$Environment,$AppDataFolder)
	$paramxmlfilepath=$PackageSource+ $buildnumber.split('_')[1]+"DeploymentParameters_Resolved.xml"
	
	$ArtifactDeploymentFolder=Get-DeploymentFolder -ApplicationName $ApplicationName -ApplicationType $applicationType
	
	$AppdataSource=join-path $ArtifactDeploymentFolder -ChildPath "app_data"
	
	Write-Host "===================================================================="
	Write-Host "Environment       : $Envrionment"
	Write-Host "Build Number      : $buildnumber"
	Write-Host "Deployment Folder : $ArtifactDeploymentFolder"
	Write-Host "Pacakge Source    : $ApplicationSource"
	Write-Host "ParameterXML File : $paramxmlfilepath"
	Write-Host "AppData Folder    : $AppDataFolder"
	Write-Host "===================================================================="
	
	Remove-Item "$ArtifactDeploymentFolder" -Force -Recurse
	New-Item $ArtifactDeploymentFolder -Force -ItemType Directory |Out-Null

	if(-not (Test-Path $paramxmlfilepath)){
		Write-Host "Parameter XML not found Deployment Failed: $ArtifactDeploymentFolder"
		EXIT 1
	}	
	
		
		Copy-Item -Path "$ApplicationSource*" -Destination $ArtifactDeploymentFolder -Force -Recurse

	if (Test-Path $AppdataSource){
			Copy-Item -Path $AppdataSource\*.* -Destination $AppDataFolder -Force -Recurse -Verbose
			Remove-Item  $AppdataSource -Force -Recurse
		}
		else{
			Write-Warning "$($ApplicatioName): AppData folder not found. App Data Deployment was skipped"
		}
	
	Write-Host "Deploying Application Configurations Environment:  $($Environment)"
	ConfigDeployer -ParameteXMLFile $paramxmlfilepath -Environment $Envrionment -DeploymentFolder $ArtifactDeploymentFolder
	
}

Function ConfigDeployer(){
PARAM($ParameteXMLFile,$Environment,$DeploymentFolder)
	
	#removing .Deployment files
	get-childitem $DeploymentFolder -filter "*config.deployment*" -Recurse | Remove-Item -Force

	$params=[xml](get-content $ParameteXMLFile)
	$params.Parameters.EnvironmentParameters.Environment |foreach{
		if($_.name -ieq $environment){
			$filter=$_.name+"*.config"
			Get-ChildItem $DeploymentFolder -Filter $filter  -Recurse | Where-Object { ! $_.PSIsContainer } | foreach { 
				$filepath=Split-Path -Parent $_.FullName
				$newname=$_.Name.replace("$Environment.","")
				$Newfilepath=$filepath+"\"+$newname
				if(Test-Path $Newfilepath){
					Remove-Item $Newfilepath -Force
				}
				Rename-Item $_.FullName -NewName $newname
			}
		}
		else {
			$filter=$_.name+"*.config"
			Get-ChildItem $DeploymentFolder -Filter $filter -Recurse | Where-Object { ! $_.PSIsContainer } | foreach { Remove-Item $_.FullName -Force}
		}
	}
}


Function Get-DeploymentFolder(){
	Param(
		[string]$ApplicationType,
		[string]$ApplicationName
	)	
	switch($ApplicationType){	
		"WindowsService" {
			$folder=[string]::Format("{0}\WindowsService\{1}\",$global:deploymentRootFolder,$ApplicationName)
		}
		"WebApplication" {
			$folder=[string]::Format("{0}\WebApplication\{1}\",$global:deploymentRootFolder,$ApplicationName)
		}
		"Website" {
			$folder=[string]::Format("{0}\Website\{1}\",$global:deploymentRootFolder,$ApplicationName)
		}
		"ConsoleApplication" {
			$folder=[string]::Format("{0}\ConsoleApplication\{1}\",$global:deploymentRootFolder,$ApplicationName)
		}
	}
return $folder
}

Function Recreate-WindowsService(){
PARAM($serviceName,$ExeName,$username,$password,$ApplicationType)
$password = convertto-securestring -String $password -AsPlainText -Force  
$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $username, $password

$ExePath=Join-Path (Get-DeploymentFolder -ApplicationType "WindowsService" -ApplicationName $serviceName) -ChildPath $ExeName
$existingService = Get-WmiObject -Class Win32_Service -Filter "Name='$serviceName'"

if ($existingService) 
{
 Write-host "'$serviceName' exists already. Stopping."
  Stop-Service $serviceName
 Write-host "Waiting 3 seconds to allow existing service to stop."
  Start-Sleep -s 3
    
  $existingService.Delete()
 Write-host "Waiting 5 seconds to allow service to be uninstalled."
  Start-Sleep -s 5  
}


$Displayname="Baloise "+$serviceName

Write-Host "Creating Service......"
Write-host "Name             :"$serviceName
Write-host "Display Name     :"$Displayname
Write-host "Exe Path         :"$ExePath
Write-host "Logon User       :"$username

Write-host "Installing the service............."
New-Service -BinaryPathName $exePath -Name $serviceName -Credential $cred -DisplayName $Displayname -StartupType Automatic -Verbose	
Write-host "Installed the service............"
Write-host "Starting the service.............."
Start-Service $serviceName
"Completed."

}