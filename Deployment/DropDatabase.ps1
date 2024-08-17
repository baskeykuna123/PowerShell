param($Environment,$DBnameFilter)

if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	

if(!$Environment){
	$Environment="PCORP"
	$DBnameFilter='MercatorNet_Bob_'
}

$DBServer=GetDBServerInfo -Environment $Environment -ServerType "WEBFRONTDB"
$DBuser=Get-Credentials -Environment $Environment -ParameterName "DataBaseDeploymentUser"
$DBPassword=Get-Credentials -Environment $Environment -ParameterName "DataBaseDeploymentUserPassword"
$DBnameFilter=$DBnameFilter+"%"
$DBname=invoke-sqlcmd  -ServerInstance $DBserver -Username $DBuser -Password $DBPassword -query "select name from sys.databases where name like '$DBnameFilter'"

Write-Host "========================================================================================="
Write-Host "Environment		: " $Environment
Write-Host "DB Server		: " $DBServer
Write-Host "Database		: " $DBname.name
Write-Host "========================================================================================="

 Try 
 {
	if($DBname -ne $null){
		Write-host "The Following DB will be Dropped :" $DBname.name
		$Executionresult=invoke-sqlcmd  -ServerInstance $DBserver -Username $DBuser -Password $DBPassword -query "Drop database $($DBname.name)"
	}
	else {
		Write-Host "Database with name $DBname not found.. Database Drop aborted"
		EXIT 0
	}
 }
 Catch {
 	throw $_
	exit 1
 }