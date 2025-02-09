$ScriptDirectory=split-path $MyInvocation.MyCommand.Definition -Parent
."$ScriptDirectory\fnSetGlobalParameters.ps1"


Function getVersionUpgradePosition(){
PARAM($UpgradeType)
switch ($UpgradeType){ 
		"Major"		{ 
						$pos=3
					 	
					}
		"Patch"		{ 
						$pos=4
					}
		Default		{ 
						Write-Error "Invalid position value "
						Exit 1
					}
	}
Return $pos
}


Function ExecuteSQLonBIVersionDatabase($SqlStatement){
	Write-Host 	"Executing SQL :" $SqlStatement
	$Results=Invoke-Sqlcmd -Query $SqlStatement -ServerInstance $Global:BaloiseBIDBserver -Database $Global:BaloiseReleaseVersionDB -Username $Global:BaloiseVersionDBuserid -Password $Global:BaloiseVersionDBuserpassword -ErrorVariable $out -ErrorAction Stop
	Return $Results
}




Function getPreviousEnvironment(){
PARAM($Environment)
switch ($Environment) 
      { 
	  	"PLAB"  { $PreEnv=""}
	  	"DCORP" { $PreEnv=""}
        "ICORP" { $PreEnv="DCORP"}
		"ACORP" { $PreEnv="ICORP"}
		"PCORP" { $PreEnv="ACORP"}
     }
Return $PreEnv
}

Function GetReleaseID(){
param ($releaseID)
	$Releaseinfo=ExecuteSQLonBIVersionDatabase -SqlStatement "Select * from Release where ReleaseID='$Release'"
	if(-not $Releaseinfo) {
		Write-host "Invalid release Version , new version aborted"
		Exit 1
	}
    return $Releaseinfo
}
Function GetApplicationInfo(){
param($ApplicationName)
	$Appinfo=ExecuteSQLonBIVersionDatabase -SqlStatement "SELECT *  FROM [Applications] where ApplicationName='$ApplicationName' or TFSAliasNames='$ApplicationName'"
	if(-not $Appinfo) {
		Write-host "Application Not found. Applications available for versioning"
		ExecuteSQLonBIVersionDatabase -SqlStatement "SELECT *  FROM [Applications]" | FT -AutoSize
		Exit 1
	}
    return $Appinfo
}
Function GetBuildVersionStatusInfo(){	
param($BuildStatus)
    $BuildVersionStatusInfo=ExecuteSQLonBIVersionDatabase -SqlStatement "SELECT *  FROM [BuildVersionStatus] where BuildVersionStatusDescription='$BuildStatus'"
	if(-not $BuildVersionStatusInfo) {
		Write-host "BuildVersionStatus Not found. BuildVersionStatus''s available for versioning"
		ExecuteSQLonBIVersionDatabase -SqlStatement "SELECT *  FROM [BuildVersionStatus]" | FT -AutoSize
		Exit 1
	}
    return $BuildVersionStatusInfo
}
Function GetDeploymentStatusInfo(){	
param($DeploymentStatus)
    $DeploymentStatusInfo=ExecuteSQLonBIVersionDatabase -SqlStatement "SELECT *  FROM [DeploymentStatus] where DeploymentStatus='$DeploymentStatus'"
	if(-not $DeploymentStatusInfo) {
		Write-host "DeploymentStatus Not found. DeploymentStatus''s available for versioning"
		ExecuteSQLonBIVersionDatabase -SqlStatement "SELECT *  FROM [DeploymentStatus]" | FT -AutoSize
		Exit 1
	}
    return $DeploymentStatusInfo
}

Function CreateNewApplicationVersion(){
PARAM($ApplicationName,$VersionType,$Release,$Branch,$BuildStatus)

	switch ($VersionType) 
	      {       
			"Major" { $pos=3}
			"Patch" { $pos=4}  
	      }
		  
	if($ApplicationName -ilike "Cleva*" -or $ApplicationName -ilike "ErrorMon*" -or $ApplicationName -ilike "InjectR*" -or $ApplicationName -ilike "SASLOADER*"){
		$Storeproc="EXEC CreateNewBuildVersion @Application='$ApplicationName',@position='$pos',@Release='$Release',@Branch='$Branch'"
	}
	else{
		Write-host "Retrieving Releases info...."
		$Releaseinfo=GetReleaseID -releaseID $Release

		Write-host "Retrieving Applicaiton info...."
		$Appinfo=GetApplicationInfo -ApplicationName $ApplicationName
		
		Write-host "Retrieving BuildVersionStatus info...."
		$BuildVersionStatusInfo=GetBuildVersionStatusInfo -BuildStatus $BuildStatus
		

		#creating the new version based on the input
		if($Branch -ilike "Dev*"){
			$Storeproc="EXEC [CreateUpdateDCORPBuildVersion] @Application='$ApplicationName',@Release='$Release',@Branch='$Branch',@BuildVersionStatus='$BuildStatus'"
		}
		else{
			$Storeproc="EXEC [CreateUpdateReleaseBuildVersion] @Application='$ApplicationName',@Release='$Release',@Branch='$Branch',@BuildVersionStatus='$BuildStatus',@Position='$pos'"
		}
	}
	Write-host "Creating a new Version ...."
	$NewVersion=ExecuteSQLonBIVersionDatabase -SqlStatement $Storeproc
	$BaseVersion=($NewVersion.NEWVersion).split('.')[0]+"."+($NewVersion.NEWVersion).split('.')[1]
	$MajorVersion=($NewVersion.NEWVersion).split('.')[2]

    $Versioninfo=@{
	"Release"="$($Releaseinfo.ReleaseID)"
	"BuildDBVersion"="$($Releaseinfo.BuildDBVersion)"
	"Version"="$($NewVersion.NEWVersion)"
	"BaseVersion"="$($BaseVersion)"
	"GlobalReleaseVersion"="$($Releaseinfo.ReleaseID).0.$($MajorVersion).0"
	"Branch"="$($Branch)"
    "RetryCount"="$($NewVersion.RetryCount)"
	}
	Return $Versioninfo
}

Function GetCompletedVersionsList(){
    PARAM($ApplicationName, $Branch)

	Write-host "Retrieving Applicaiton info...."
	$Appinfo=GetApplicationInfo -ApplicationName $ApplicationName

	Write-host "Retrieving BuildVersionStatus info...."
	$BuildVersionStatusInfo=GetBuildVersionStatusInfo -BuildStatus "Completed"

    $ListCompletedVersions=ExecuteSQLonBIVersionDatabase -SqlStatement "SELECT distinct Version,BuildDate FROM [BuildVersions] where (ApplicationID = '$($Appinfo.ApplicationID)') AND (Status = '$($BuildVersionStatusInfo.BuildVersionStatusID)') AND (TFSBranch = '$($Branch)') ORDER BY BuildDate DESC"
    return $ListCompletedVersions
}

Function IsBuildVersionCompleted(){
    param($BuildVersion)
    
    $IsCompleted=ExecuteSQLonBIVersionDatabase "EXEC CheckBuildVersionIsCompleted @BuildVersion='$BuildVersion'"
    return $IsCompleted
}

Function CreateUpdateDeployVersion(){
PARAM($ApplicationName,$Release,$Environment,$BuildVersion,$DeploymentStatus)

	Write-host "Retrieving Releases info...."
	$Releaseinfo=GetReleaseID -releaseID $Release

	Write-host "Retrieving Applicaiton info...."
	$Appinfo=GetApplicationInfo -ApplicationName $ApplicationName

	Write-host "Retrieving BuildVersionStatus info...."
	$DeploymentStatusInfo=GetDeploymentStatusInfo -DeploymentStatus $DeploymentStatus

	#creating the new version based on the input
	$DeploymentInfo=ExecuteSQLonBIVersionDatabase "EXEC CreateUpdateDeployVersion @Application='$ApplicationName',@Environment='$Environment',@BuildVersion='$BuildVersion',@DeploymentStatus='$DeploymentStatus',@ReleaseID='$Release'"

    $Deployment=@{
	    "Version"="$($DeploymentInfo.Version)"
	    "DeploymentStatus"="$($DeploymentInfo.DeploymentStatus)"
	    "EnvironmentName"="$($DeploymentInfo.EnvironmentName)"
	}

    return $Deployment
}

Function ManualFixDeployVersion(){
PARAM($ApplicationName,$Release,$Environment,$BuildVersion,$DeploymentStatus,$currentUser)

	Write-host "Retrieving Releases info...."
	$Releaseinfo=GetReleaseID -releaseID $Release

	Write-host "Retrieving Applicaiton info...."
	$Appinfo=GetApplicationInfo -ApplicationName $ApplicationName

	Write-host "Retrieving BuildVersionStatus info...."
	$DeploymentStatusInfo=GetDeploymentStatusInfo -DeploymentStatus $DeploymentStatus

	#creating the new version based on the input
	$DeploymentInfo=ExecuteSQLonBIVersionDatabase "EXEC SetStatusDeployVersion @Application='$ApplicationName',@Environment='$Environment',@BuildVersion='$BuildVersion',@DeploymentStatus='$DeploymentStatus',@ReleaseID='$Release',@ModifiedBy='$currentUser'"

    $Deployment=@{
	    "Version"="$($DeploymentInfo.Version)"
	    "DeploymentStatus"="$($DeploymentInfo.DeploymentStatus)"
	    "EnvironmentName"="$($DeploymentInfo.EnvironmentName)"
	}

    return $Deployment
}