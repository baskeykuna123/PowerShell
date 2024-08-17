Param(
	$BuildNumber,
	$Environment,
	$DBProjectName,
	$ApplicationName,
	$DBName
)

#default Parameters
if(!$BuildNumber){
	$BuildNumber="SSISTODSREFERENCEDB_Anabel_20210531.4"
	$Environment="PCORP"
	$ApplicationName="REFERENCE"
	$DBProjectName="TODS_REFERENCE_DB"
    $DBName="TODS_REFERENCE"
	
	}
#loading Functions
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop

Switch($Environment){ 
			"DCORP" {
				$DBUser="L001174" 
           		$DBUserPassword ="teCH_Key_DEV"
			$DBServer="SQL-BE-BIM-SASd.balgroupit.com"
			}
  			 
  			"ICORP" {
				$DBUser="L001173" 
           		$DBUserPassword ="teCH_Key_INT"
			$DBServer="SQL-BE-BIM-SASi.balgroupit.com"
			} 
  			
		        "PCORP" {
				 $DBUser="L001171" 
           			 $DBUserPassword ="teCH_Key_PRO"
				 $DBServer="SQL-BE-BIM-SASp.balgroupit.com"}
	}

#$UserPassword = ConvertTo-SecureString $tempUserPassword -AsPlainText -force
$DBServer	

$ErrorActionPreference='Stop'

$buildSourcepath=GetPackageSourcePathforTFSBuilds -BuildNumber $BuildNumber -ApplicationName  "Anabel"
$buildSourcepath
if($BuildNumber -ilike "SQL*"){
$DACsource= join-path $buildSourcepath -ChildPath $dbprojectName
$DACsource
$DACFilePath=(Get-ChildItem FileSystem::$DACsource  -Filter "$($DBProjectName).DACPAC"  | select -First 1).FullName
$DACFilePath
$SynDACFilePath=(Get-ChildItem FileSystem::$DACsource  -Filter "*SYNONYMS.DACPAC"  | select -First 1).FullName
$SynDACFilePath
}
elseif($BuildNumber -ilike "SSIS*"){
$ISPACSource=join-path $buildSourcepath -ChildPath "Development"
$ISPACFilepath=(Get-ChildItem FileSystem::$ISPACsource  -Filter "*.ISPAC"  | select -First 1).FullName
}
elseif($BuildNumber -ilike "TestSQL*"){
$DACsource= join-path $buildSourcepath -ChildPath $dbprojectName
$DACsource
$DACFilePath=(Get-ChildItem FileSystem::$DACsource  -Filter "$($DBProjectName).DACPAC"  | select -First 1).FullName
$DACFilePath
}
else{
$DACsource= join-path $buildSourcepath -ChildPath $dbprojectName
$DACsource
$DACFilePath=(Get-ChildItem FileSystem::$DACsource  -Filter "$($DBProjectName).DACPAC"  | select -First 1).FullName
$DACFilePath
$DbDACFilePath=(Get-ChildItem FileSystem::$DACsource  -Filter "*_DB.DACPAC"  | select -First 1).FullName
$DbDACFilePath
$StubDACFilePath=(Get-ChildItem FileSystem::$DACsource  -Filter "*_STUB.DACPAC"  | select -First 1).FullName
$StubDACFilePath
$ISPACSource=join-path $buildSourcepath -ChildPath "Development"
$ISPACFilepath=(Get-ChildItem FileSystem::$ISPACsource  -Filter "*.ISPAC"  | select -First 1).FullName
$ISPACSource
$ISPACFilepath
}
if(-not(Test-Path filesystem::$buildSourcepath)){
	Write-Host "Build Source not  found. DB Deployment Aborted.."
	Exit 1
}
if(-not((Test-Path filesystem::$DACFilePath) -or (Test-Path filesystem::$ISPACFilePath))){
	Write-Host "Databae .DACPAC file Not found. DB Deployment Aborted.."
	Exit 1
}



Write-Host "`r`n==================================================================================="
Write-Host "'$ApplicationName' DataBase Deployment for BuildVersion : $BuildNumber"
Write-Host "Environment            : " $Environment
Write-Host "Database Name          : " $DBName
Write-Host "Database Server        : " $DBServer
Write-Host "Application            : " $ApplicationName
Write-Host "Build                  : " $BuildNumber
Write-Host "Project                : " $DBProjectName
Write-Host "========================================================================================`r`n"
$catlogpath="SSISDB\$($DBName)\$($DBName)"
#$DBServer


if($BuildNumber -ilike "SQL*"){
#$SQLPackageExeArgs=@("/action:Script", "/sourcefile:$SynDACFilePath", "/TargetDatabaseName:$DBName", "/TargetServerName:$DBServer", "/TargetUser:$($DBUser)", "/TargetPassword:$($DBUserPassword)", "/p:BlockOnPossibleDataLoss=false","/p:TreatVerificationErrorsAsWarnings=True", "/p:ScriptDatabaseOptions=False", "/p:VerifyDeployment=False" , "/op:e:\test.sql")
#&$global:SQLPackage2017Exe $SQLPackageExeArgs /v:ODS_$($ApplicationName)="ODS_$($ApplicationName)"
#cat e:\test.sql


$SQLPackageExeArgs=@("/action:publish", "/sourcefile:$SynDACFilePath", "/TargetDatabaseName:$DBName", "/TargetServerName:$DBServer", "/TargetUser:$($DBUser)", "/TargetPassword:$($DBUserPassword)", "/p:BlockOnPossibleDataLoss=false","/p:TreatVerificationErrorsAsWarnings=True", "/p:ScriptDatabaseOptions=False", "/p:VerifyDeployment=False" )
&$global:SQLPackage2017Exe $SQLPackageExeArgs  /v:ODS_$($ApplicationName)="ODS_$($ApplicationName)"

$SQLPackageExeArgs=@("/action:publish", "/sourcefile:$DACFilePath", "/TargetDatabaseName:$DBName", "/TargetServerName:$DBServer", "/TargetUser:$($DBUser)", "/TargetPassword:$($DBUserPassword)", "/p:BlockOnPossibleDataLoss=false","/p:TreatVerificationErrorsAsWarnings=True", "/p:ScriptDatabaseOptions=False", "/p:VerifyDeployment=False")
&$global:SQLPackage2017Exe $SQLPackageExeArgs /v:ODS_$($ApplicationName)="ODS_$($ApplicationName)"

#Executing the DACPAC using SQLPackage.exe
#$SQLPackageExeArgs=@("/action:Script", "/sourcefile:$SynDACFilePath", "/TargetDatabaseName:$DBName", "/TargetServerName:$DBServer", "/TargetUser:$($DBUser)", "/TargetPassword:$($DBUserPassword)", "/p:BlockOnPossibleDataLoss=false","/p:TreatVerificationErrorsAsWarnings=True", "/p:ScriptDatabaseOptions=False", "/op:""e:\test.sql"" " )
#&$global:SQLPackage2017Exe $SQLPackageExeArgs

#$SQLPackageExeArgs=@("/action:Script", "/sourcefile:$DACFilePath", "/TargetDatabaseName:$DBName", "/TargetServerName:$DBServer", "/TargetUser:$($DBUser)", "/TargetPassword:$($DBUserPassword)", "/p:BlockOnPossibleDataLoss=false","/p:TreatVerificationErrorsAsWarnings=True", "/p:ScriptDatabaseOptions=False", "/op:""e:\test.sql"" ")
#&$global:SQLPackage2017Exe $SQLPackageExeArgs
}
elseif($BuildNumber -ilike "TestSQL*"){
$SQLPackageExeArgs=@("/action:publish", "/sourcefile:$DACFilePath", "/TargetDatabaseName:$DBName", "/TargetServerName:$DBServer", "/TargetUser:$($DBUser)", "/TargetPassword:$($DBUserPassword)", "/p:BlockOnPossibleDataLoss=false","/p:TreatVerificationErrorsAsWarnings=True", "/p:ScriptDatabaseOptions=False", "/p:VerifyDeployment=False" )
&$global:SQLPackage2017Exe $SQLPackageExeArgs
}
elseif($BuildNumber -ilike "SSIS*"){
& E:\SSISDevopsTools\SSISDeploy.exe -s:$ISPACFilepath -d:"catalog;/SSISDB/$($DBName)/$($DBName);$($DBServer)" -at:"win" -u:"L002867" -p:"Jenk1ns@B@loise"
#$DeploymentArgs=@(/Silent, /ModelType:"Project", /SourcePath:"$ISPACFilePath", /DestinationServer:"$DBServer", /DestinationPath:"$catlogpath")
#&$global:DeploymentwizardExe $DeploymentArgs
}
else{
#Executing the DACPAC using SQLPackage.exe
$StubDACFilePath
$SQLPackageExeArgs=@("/action:publish", "/sourcefile:$StubDACFilePath", "/TargetDatabaseName:TODS_TEST", "/TargetServerName:$DBServer", "/TargetUser:$($DBUser)", "/TargetPassword:$($DBUserPassword)", "/p:BlockOnPossibleDataLoss=false","/p:TreatVerificationErrorsAsWarnings=True", "/p:ScriptDatabaseOptions=False", "/p:VerifyDeployment=False")
&$global:SQLPackage2017Exe $SQLPackageExeArgs /v:ODS_$($ApplicationName)="ODS_$($ApplicationName)"

$DbDACFilePath
$SQLPackageExeArgs=@("/action:publish", "/sourcefile:$DbDACFilePath", "/TargetDatabaseName:TODS_TEST", "/TargetServerName:$DBServer", "/TargetUser:$($DBUser)", "/TargetPassword:$($DBUserPassword)", "/p:BlockOnPossibleDataLoss=false","/p:TreatVerificationErrorsAsWarnings=True", "/p:ScriptDatabaseOptions=False" , "/p:VerifyDeployment=False")
&$global:SQLPackage2017Exe $SQLPackageExeArgs /v:ODS_$($ApplicationName)="ODS_$($ApplicationName)"

$DACFilePath
$SQLPackageExeArgs=@("/action:publish", "/sourcefile:$DACFilePath", "/TargetDatabaseName:TODS_TEST", "/TargetServerName:$DBServer", "/TargetUser:$($DBUser)", "/TargetPassword:$($DBUserPassword)", "/p:BlockOnPossibleDataLoss=false","/p:TreatVerificationErrorsAsWarnings=True", "/p:ScriptDatabaseOptions=False", "/p:VerifyDeployment=False")
&$global:SQLPackage2017Exe $SQLPackageExeArgs /v:ODS_$($ApplicationName)="ODS_$($ApplicationName)"
#Executing the DACPAC using SQLPackage.exe
#$SQLPackageExeArgs=@("/action:Script", "/sourcefile:$StubDACFilePath", "/TargetDatabaseName:TODS_TEST", "/TargetServerName:$DBServer", "/TargetUser:$($DBUser)", "/TargetPassword:$($DBUserPassword)", "/p:BlockOnPossibleDataLoss=false","/p:TreatVerificationErrorsAsWarnings=True", "/p:ScriptDatabaseOptions=False", "/op:""e:\test.sql"" ")
#&$global:SQLPackage2017Exe $SQLPackageExeArgs



#Executing the DACPAC using SQLPackage.exe
#$SQLPackageExeArgs=@("/action:Script", "/sourcefile:$DACFilePath", "/TargetDatabaseName:TODS_TEST", "/TargetServerName:$DBServer", "/TargetUser:$($DBUser)", "/TargetPassword:$($DBUserPassword)", "/p:BlockOnPossibleDataLoss=false","/p:TreatVerificationErrorsAsWarnings=True", "/p:ScriptDatabaseOptions=False", "/op:""e:\test.sql"" ")
#&$global:SQLPackage2017Exe $SQLPackageExeArgs

& E:\SSISDevopsTools\SSISDeploy.exe -s:$ISPACFilepath -d:"catalog;/SSISDB/TODS_TEST/$($DBName);$($DBServer)" -at:"win" -u:"L002867" -p:"Jenk1ns@B@loise"
}