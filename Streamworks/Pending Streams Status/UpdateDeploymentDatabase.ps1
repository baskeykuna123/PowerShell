PARAM($version,$Environment,$ApplicationName="CLEVA")

#Test parameters to run the script while debugging
if(!$version){
	$version="33.3.12.0"
	$Environment="PARAM"
	$ApplicationName="Cleva"
}

Clear-Host

#Importing SQL modules for SQL commands to the Version database
Import-Module sqlps -DisableNameChecking


$DBuserid="L001171"
$DBpassword="teCH_Key_PRO"
$dbserver="sql-be-buildp"
$dbName="BaloiseReleaseVersions"

$ErrorActionPreference='Stop'
$exeproccmd="EXEC GetDeployedAppVersionByVersionID @Application='$ApplicationName',@Environment='$Environment',@VersionID='$version'"
$currentVersion=Invoke-Sqlcmd -Query $exeproccmd -ServerInstance $dbserver -Database $dbName -Username $DBuserid -Password $DBpassword -ErrorVariable $out

switch($Environment){
		"PAR" { $Environment="PLAB"}
	    "DEV" { $Environment="DCORP"}
        "INT" { $Environment="ICORP"}
		"ACC" { $Environment="ACORP"}
		"PRED" { $Environment="PRED"}
		"EMRG" { $Environment="EMRG"}
}

#Input Parameters
Write-Host "Updating $version status to Deployed"
Write-Host "Application	:"$ApplicationName
Write-Host "Environment	:"$Environment
Write-Host "Version		:"$version
	  

if($currentVersion){
	Write-Host "$version is already deployed on $($currentVersion[""Timestamp""]) on $Environment"
}
else{
	Write-host "`r`n`r`nDeploying Version $version on $Environment....."
	$exeproccmd="EXEC DeployVersion @Application='$ApplicationName',@Environment='$Environment',@Buildversion='$version'"
	$preversions=Invoke-Sqlcmd -Query $exeproccmd -ServerInstance $dbserver -Database $dbName -Username $DBuserid -Password $DBpassword -ErrorVariable $out
}