param
(
	[String]$Env
)
Clear-Host
#loading Functions
if(Get-Module -Name LoadFunctions){
	Remove-Module LoadFunctions -Force
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	

if(!$Env){
	$Env="DCORP"
}

$ErrorActionPreference='Stop'

write-host "================================================================================"
Write-host "Environment : " $Env
write-host "================================================================================"
	
# Query to be executed for check restore date
	 $Sql = "  SELECT 
   [rs].[destination_database_name], 
   [rs].[restore_date], 
   [bs].[backup_start_date], 
   [bs].[backup_finish_date], 
   [bs].[database_name] as [source_database_name]
FROM msdb..restorehistory rs
INNER JOIN msdb..backupset bs ON [rs].[backup_set_id] = [bs].[backup_set_id]
ORDER BY [rs].[restore_date] DESC "

$DBuser=get-Credentials -Environment $Env -ParameterName  "DataBaseDeploymentUser"
$DBpassword=get-Credentials -Environment $Env -ParameterName  "DataBaseDeploymentUserPassword"

$DBServer=$null
$ServerType="WEBFRONTDB"
$DBServerInfo = GetEnvironmentInfo  -Environment $Env -ServerType $ServerType
$DBServer = $DBServerInfo.Name
#Get restore dates if WEBBACKDB is defined
if ($DBServer){
    Write-Host "Querying Front Databases"
    $details = Invoke-Sqlcmd -Query $Sql -ServerInstance $DBserver -Username $DBUser -Password $DBPassword

    if ([String]::IsNullOrEmpty($details)){
        Write-Host "No restores found on $DBServer."
    }
    else{
        $details
    }
}
else{
    Write-Host "No FrontDatabase defined for $Env."
}

$DBServer=$null
$ServerType="WEBBACKDB"
$DBServerInfo = GetEnvironmentInfo  -Environment $Env -ServerType $ServerType
$DBServer = $DBServerInfo.Name
#Get restore dates if WEBBACKDB is defined
if ($DBServer){
    Write-Host "Querying Back Databases"
    $details = Invoke-Sqlcmd -Query $Sql -ServerInstance $DBserver -Username $DBUser -Password $DBPassword

    if ([String]::IsNullOrEmpty($details)){
        Write-Host "No restores found on $DBServer."
    }
    else{
        $details
    }
}
else{
    Write-Host "No BackDatabase defined for $Env."
}
