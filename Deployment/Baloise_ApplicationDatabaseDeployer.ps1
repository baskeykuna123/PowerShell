Param(
	$BuildNumber,
	$Environment,
	$DBProjectName,
	$ApplicationName,
	$DBApplicationName
)

#default Parameters
if(!$BuildNumber){
	$BuildNumber="DEV_DataServices_20210922.2"
	$Environment="DCORP"
	$ApplicationName="DataServices"
	$DBProjectName="Baloise.DataServices.Database"
	$DBApplicationName="BaloiseDataServices"
	}


#loading Functions
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	

$ErrorActionPreference='Stop'

$buildSourcepath=GetPackageSourcePathforTFSBuilds -BuildNumber $BuildNumber -ApplicationName  $ApplicationName

$DACsource= join-path $buildSourcepath -ChildPath $dbprojectName
$DACFilePath=(Get-ChildItem FileSystem::$DACsource  -Filter "*.DACPAC"  | select -First 1).FullName

if(-not(Test-Path filesystem::$buildSourcepath)){
	Write-Host "Build Source not  found. DB Deployment Aborted.."
	Exit 1
}
if(-not(Test-Path filesystem::$DACFilePath)){
	Write-Host "Databae .DACPAC file Not found. DB Deployment Aborted.."
	Exit 1
}


#Load Parameters to get the DB server and Name
$DatabaseInfo=Load-ParametersFromXML -BuildSourcePath $buildSourcepath -Environment $Environment
$DBUser=get-Credentials -Environment $Environment -ParameterName  "DataBaseDeploymentUser"
$DBUserPassword=get-Credentials -Environment $Environment -ParameterName  "DataBaseDeploymentUserPassword"
$DBName=$DatabaseInfo["$($DBApplicationName)DataBaseName"]
$DBServer=$DatabaseInfo["$($DBApplicationName)DataSource"]

Write-Host "`r`n==================================================================================="
Write-Host "'$ApplicationName' DataBase Deployment for BuildVersion : $BuildNumber"
Write-Host "Environment            : " $Environment
Write-Host "Database Name          : " $DBName
Write-Host "Database Server        : " $DBServer
Write-Host "Application            : " $ApplicationName
Write-Host "Build                  : " $BuildNumber
Write-host "DB User                : " $DBUser
Write-Host "========================================================================================`r`n"
                
$DBServer
#Executing the DACPAC using SQLPackage.exe
$SQLPackageExeArgs=@("/action:publish", "/sourcefile:$DACFilePath", "/TargetDatabaseName:$DBName", "/TargetServerName:$DBServer", "/TargetUser:$($DBUser)", "/TargetPassword:$($DBUserPassword)", "/p:BlockOnPossibleDataLoss=false","/p:TreatVerificationErrorsAsWarnings=True", "/p:ScriptDatabaseOptions=False" )
If($ApplicationName -ine "DataServices"){
    &$global:SQLPackageExe $SQLPackageExeArgs
}
Else{
    &$global:SQLPackage2017Exe $SQLPackageExeArgs
}

#Executing the DACPAC using SQLPackage.exe
$SQLPackageExeArgs=@("/action:Script", "/sourcefile:$DACFilePath", "/TargetDatabaseName:$DBName", "/TargetServerName:$DBServer", "/TargetUser:$($DBUser)", "/TargetPassword:$($DBUserPassword)", "/p:BlockOnPossibleDataLoss=false","/p:TreatVerificationErrorsAsWarnings=True", "/p:ScriptDatabaseOptions=False", "/op:""e:\test.sql"" ")
#&$global:SQLPackageExe $SQLPackageExeArgs
