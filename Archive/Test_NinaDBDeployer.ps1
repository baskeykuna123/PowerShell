param($Environment,$Workspace)

clear;

$ErrorActionPreference='Stop'

loading Function
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop


if(!$Environment){
    $Environment='ACORP'
}

$Query=@"
SELECT Version, ApplicationName,Environments.EnvironmentName, DeploymentStatus.DeploymentStatus
FROM Deployments
	JOIN Applications
		ON Applications.ApplicationID=Deployments.ApplicationID
	Join Environments
		ON Deployments.Environment=Environments.EnvironmentID
	Join DeploymentStatus
		ON DeploymentStatus.DeploymentStatusID=Deployments.DeploymentStatus
			WHERE ApplicationName='NinaDB' and
				  EnvironmentName='ICORP'  and
				  DeploymentStatusID='5'
ORDER BY DeploymentDate ASC
"@



$GetNinaDBBuildInfo=Invoke-Sqlcmd -ServerInstance $Global:BaloiseBIDBserver -Database $Global:BaloiseReleaseVersionDB -Username $Global:BaloiseVersionDBuserid -Password $Global:BaloiseVersionDBuserpassword -Query $Query
$GetNinaDBICORPVersions=$($GetNinaDBBuildInfo.Version)
write-host `n
Write-Host "Environment:"$Environment
ForEach($version in $GetNinaDBICORPVersions){
    Write-host "Build Version:"$version
    $Query2ExecuteStoredProc="EXEC CheckNinaDBBuildStatus @NinaDBBuildVersion='$version', @Environment='$Environment'"
    $out=Invoke-Sqlcmd -ServerInstance $Global:BaloiseBIDBserver -Database $Global:BaloiseReleaseVersionDB -Username $Global:BaloiseVersionDBuserid -Password $Global:BaloiseVersionDBuserpassword -Query $Query2ExecuteStoredProc
    $GetDeploymentStatus=$out.DeploymentStatus
	if($GetDeploymentStatus -ieq 'Completed'){
		Write-Host "Deployment status for '$version':"$GetDeploymentStatus
		continue;
	}
	Else{
		Write-Host "Deployment status for '$version':"$GetDeploymentStatus
		
		Write-Host "Updating status for this version in DB.."
		& $ScriptDirectory\TFS\deploymentstatus.ps1 -Environment $env:Environment -ApplicationName "NINADB" -DeploymentStatus "Starting" -BuildVersion $env:BuildNumber
		
		Write-Host "Starting deployments on '$Environment' for version:" $version ..
        .\NINA_Database_Deployer.ps1 -BuildNumber $version -Workspace $Workspace -Environment $Environment
		
		Write-Host "Updating status as completed for this version in DB.."
		& $ScriptDirectory\TFS\deploymentstatus.ps1 -Environment $env:Environment -ApplicationName "NINADB" -DeploymentStatus "Completed" -BuildVersion $env:BuildNumber
	}
	Write-Host `n
}

$ScriptDirectory