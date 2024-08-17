﻿Param($Environment)

if(!$Environment){
	$Environment='PAR'
}

Clear

#Importing SQL modules for SQL commands to the Version database
Import-Module sqlps -DisableNameChecking

if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}

$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	

switch ($Environment){ 
	  	"PAR" { $PreEnv=""}
	  	"DEV" { $PreEnv=""}
        "INT" { $PreEnv="DEV"}
		"ACC" { $PreEnv="INT"}
		"PRD" { $PreEnv="ACC"}
     }

#switch ($Environment) 
#      { 
#	    "DCORP" { $Environment="DEV"}
#        "ICORP" { $Environment="INT"}
#		"ACORP" { $Environment="ACC"}
#		"PCORP" { $Environment="PRD"}
#		"MIG"   { $Environment="MIG"}
#		"MIG3"  { $Environment="MIG3"}
#		"MIG4"  { $Environment="MIG4"}
#	  }
	 
$MigEnvironments="MIG","MIG3","MIG4"
$MigVersion=$false	 
$date=[DateTime]::Now.ToString("yyyy-MM-dd")
$PacakgeBase="D:\ClevaPackages\$Environment\"
$Deliveryfolder="D:\Delivery\Deploy\packages\"
$ClevaDeliveryfolder="D:\Delivery\Deploy\Cleva\"
$templatelocation="D:\BuildTeam\Templates\DeploymentTemplates\*"

 #DB server information
$dbName="BaloiseReleaseVersions"
$SqlConnection = New-Object System.Data.SqlClient.SqlConnection
$SqlCmd = New-Object System.Data.SqlClient.SqlCommand

$exeproccmd="EXEC GetDeployedAppVersion @Application='CLEVA',@Environment='$Environment'"
$currentVersion=Invoke-Sqlcmd -Query $exeproccmd -ServerInstance $Global:BaloiseBIDBserver -Database $dbName -Username $Global:BaloiseVersionDBuserid -Password $Global:BaloiseVersionDBuserpassword -ErrorVariable $out
$currentVersion=$currentVersion.BuildVersion


Write-Host "========================Version Package info===================="
Write-Host "Latest Version on $($Environment) : " $currentVersion
if($PreEnv){
	#getting the latest verison in the previous environment
	$exeproccmd="EXEC GetDeployedAppVersion @Application='CLEVA',@Environment='$PreEnv'"
	$prevenv=Invoke-Sqlcmd -Query $exeproccmd -ServerInstance $Global:BaloiseBIDBserver -Database $dbName -Username $Global:BaloiseVersionDBuserid -Password $Global:BaloiseVersionDBuserpassword -ErrorVariable $out
	$prevenv=$prevenv.BuildVersion
	
	#getting Versions in between
	$exeproccmd="EXEC GetBuildVersionsBetween @Application='CLEVA',@Environment='$Environment',@sourceVersion='$currentVersion',@targetVersion='$prevenv'"
	$preversions=Invoke-Sqlcmd -Query $exeproccmd -ServerInstance $Global:BaloiseBIDBserver -Database $dbName -Username $Global:BaloiseVersionDBuserid -Password $Global:BaloiseVersionDBuserpassword -ErrorVariable $out
	Write-Host "Latest Version on $($PreEnv)      : " $prevenv
	if($currentVersion -ieq $prevenv){
		Write-Host "There are no new versions to be packaged for $($Environment). Error in packaging"
		Exit 1
	}
}
else {
	$exeproccmd="EXEC [GetBuildVersionsAfter] @Application='CLEVA',@Environment='$Environment',@sourceVersion='$currentVersion'"
	$preversions=Invoke-Sqlcmd -Query $exeproccmd -ServerInstance $Global:BaloiseBIDBserver -Database $dbName -Username $Global:BaloiseVersionDBuserid -Password $Global:BaloiseVersionDBuserpassword -ErrorVariable $out
}

if(!$preversions){
	Write-Host "No versions to deploy . Aborting "
	Exit 1
}

Write-Host "Packaging the following Version(s)"
$lastmajorver=""
[system.Data.DataRow]$row=$null
$DeploymentVersions=@()
Foreach($row in $preversions){
	$row.Version
	if(($row.Version).split('.')[3] -eq 0){
		$lastmajorver=$row.Version
	}
	$DeploymentVersions+=([string]$row.Version)
}

$MIGNewVersionfolderName=""
if($MigEnvironments -icontains $Environment){
	$MIGNewVersionfolderName=[string]::Format("{0}{1}",$Environment,$DeploymentVersions[-1])
	$MigVersion=$true
}

#$DeploymentVersions=@("29.3.1.0")
#$lastmajorver="29.3.1.0"
$NewVersion=$DeploymentVersions[-1]

#check if each version is packaged for deployment, checking zips
foreach($version in $DeploymentVersions){
	Write-Host "Checking Version :" $version
	$selectQuery="Select * from ClevaVersions where Cleva_Version='$version'"
	$select=Invoke-Sqlcmd -Query $selectQuery -ServerInstance $Global:BaloiseBIDBserver -Database $Global:BaloiseReleaseVersionDB -Username $Global:BaloiseVersionDBuserid -Password $Global:BaloiseVersionDBuserpassword -ErrorVariable $out
	
	#checkfing for ITN DB Zip folder
	$ITNdbpackagesZip=[String]::Format("{0}ITN\{1}\database\cleva\maj_param_{1}.zip",$Deliveryfolder,$select.ITN_Version)
	if(!(test-path $ITNdbpackagesZip)){
		$ITNdbpackagesFolder=[String]::Format("{0}\ITN\{1}\database\cleva\maj_param_{1}",$Deliveryfolder,$select.ITN_Version)
		$zipfilename=[String]::Format("maj_param_{0}.zip",$select.ITN_Version)
		Set-Location $ITNdbpackagesFolder
		cmd /c "zip -rq ..\$zipfilename *"
	}
	else{
		Write-Host "ZIP file found  :" $ITNdbpackagesZip
	}
	
	$ClevaDBpackageZip=[String]::Format("{0}\InitialInstallation\Cleva_{1}\CLEVA_{1}.zip",$Deliveryfolder,$select.Cleva_Version)
	#checkfing for ITN DB Zip folder
	if(!(test-path $ClevaDBpackageZip)){
		$ClevaDBpackageFolder=[String]::Format("{0}\InitialInstallation\CLEVA_{1}",$Deliveryfolder,$select.Cleva_Version)
		$zipfilename=[String]::Format("CLEVA_{0}.zip",$select.Cleva_Version)
		Set-Location $ClevaDBpackageFolder
		cmd /c "zip -rq $zipfilename *"
	}
	else{
		Write-Host "ZIP file found  :" $ClevaDBpackageZip
	}
}

#check if Version is Already Deployed
$selectQuery="Select EnvironmentID from Environments where EnvironmentAlias='$Environment'"
$select=Invoke-Sqlcmd -Query $selectQuery -ServerInstance $Global:BaloiseBIDBserver -Database $Global:BaloiseReleaseVersionDB -Username $Global:BaloiseVersionDBuserid -Password $Global:BaloiseVersionDBuserpassword -ErrorVariable $out
$selectQuery="Select *  from [BuildVersionDeployments] where [BuildVersion]='$NewVersion' and EnvironmentID='$($select.EnvironmentID)'"
$select=Invoke-Sqlcmd -Query $selectQuery -ServerInstance $Global:BaloiseBIDBserver -Database $Global:BaloiseReleaseVersionDB -Username $Global:BaloiseVersionDBuserid -Password $Global:BaloiseVersionDBuserpassword -ErrorVariable $out
if(!$select){
	Write-host "$NewVersion Version is  not deployed on WEBLOGIC $Environment"
}


$propertiesfile=[string]::Format("{0}{1}_ClevaDeploy.Properties",$Global:JenkinsPropertiesRootPath,$Environment)
$propfile=getproperties -FilePath $propertiesfile
$propfile["Environment"]=$Environment
$propfile["version"]=$NewVersion
$propfile["ReleaseDate"]=$date
setproperties -FilePath $propertiesfile -Properties $propfile


$NewVersionfolder=Join-path $PacakgeBase -ChildPath ("JBOSS_"+$NewVersion)
Remove-Item $NewVersionfolder -Force -Recurse -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $NewVersionfolder | Out-Null
Copy-Item $templatelocation -Destination $NewVersionfolder -Force -Recurse

$selectQuery="Select * from ClevaVersions where Cleva_Version='$NewVersion'"
$select=Invoke-Sqlcmd -Query $selectQuery -ServerInstance $Global:BaloiseBIDBserver -Database $Global:BaloiseReleaseVersionDB -Username $Global:BaloiseVersionDBuserid -Password $Global:BaloiseVersionDBuserpassword -ErrorVariable $out

$MIDCJBossSourcezip=[string]::Format("D:\Delivery\Deploy\packages\TechnicalTeam\{0}\JBoss\JBoss_{0}.zip",$select["MIDC_VERSION"])
$TempExtracted="D:\BuildTeam\temp\zips\"
$unzipcommand=[string]::Format("unzip -oq {0} -d {1}",$MIDCJBossSourcezip,$TempExtracted)
Remove-Item "$($TempExtracted)*" -Force -Recurse 
cmd /c $unzipcommand
	
$versionfile=$ClevaDeliveryfolder+"$NewVersion\version"
Copy-Item $versionfile -Destination $NewVersionfolder -Force -Recurse
if($MIGNewVersionfolderName){
	$versionfile=join-path $NewVersionfolder -ChildPath "version"
	$filcontents=Get-Content $versionfile
	$filcontents | %{$_.replace($NewVersion,$MIGNewVersionfolderName)} | Set-Content $versionfile -Force
}

#server - jboss
$folder=$NewVersionfolder+"\server\"
#getting ears
$earpath=join-path $TempExtracted -ChildPath "\T9-Assurance.ear"
Copy-Item  $earpath -Destination $folder -Force -Recurse

#gettingconfig files
$configzip=join-path $TempExtracted -ChildPath "\config-dist.zip"
Copy-Item  $configzip -Destination $folder -Force -Recurse

$folder=$NewVersionfolder+"\webupdate\"
$UpdateSitepath=join-path $TempExtracted -ChildPath "\updatesite-dev-specifique.zip"
Copy-Item  $UpdateSitepath -Destination $folder -Force -Recurse

$folder=$NewVersionfolder+"\prexlib_jar\"
$tarifxml=$Deliveryfolder+"tarification\"+$select.Tariff_Version +"\tarifs.xml"
$tariffs=$Deliveryfolder+"tarification\"+$select.Tariff_Version +"\T9-tarif-*"
Copy-Item  $tarifxml -Destination $folder -Force -Recurse
Copy-Item  $tariffs -Destination $folder -Force -Recurse
   

$batchfolder=$NewVersionfolder+"\batch\"
$envfile=$ClevaDeliveryfolder+$select.Cleva_Version +"\EnvironmentVariable.sh"
Copy-Item  $envfile -Destination $batchfolder -Force -Recurse
$CurrentJDK="export JAVA_HOME=/opt/jdk1.6.0_45"
$latestJDK="export JAVA_HOME=/opt/jdk"
$envfile=join-path $batchfolder -ChildPath "\EnvironmentVariable.sh"
	$filcontents=Get-Content $envfile
	$filcontents | %{$_.replace($CurrentJDK,$latestJDK)} | Set-Content $envfile -Force
	
if($MIGNewVersionfolderName){
	$envfile=join-path $batchfolder -ChildPath "\EnvironmentVariable.sh"
	$filcontents=Get-Content $envfile
	$filcontents | %{$_.replace($NewVersion,$MIGNewVersionfolderName)} | Set-Content $envfile -Force
}

$paramscriptversion=[String]::Format("{0}\ParameterizationScripts\{1}\*.zip",$Deliveryfolder,$select.Param_Script_Version)
$dbfolder=$NewVersionfolder+"\database\cleva\"
Copy-Item  $paramscriptversion -Destination $dbfolder -Force -Recurse

$paramversion=[String]::Format("{0}\Params\{1}\*.zip",$Deliveryfolder,$select.Param_Version)
Copy-Item  $paramversion -Destination $dbfolder -Force -Recurse

$parfolder=$NewVersionfolder+"\batch"+"\pars\"
$dbscripttxtfile=$dbfolder+"\deployScripts.txt"
	
	
Write-Host "New $Environment Version Info"
Write-Host "================================================================="
Write-Host "Baloise Version      :" $NewVersionfolder
Write-Host "MDIC Version         :" $select.MIDC_Version
Write-Host "ITN  Version         :" $select.ITN_Version
Write-Host "TARIFF Version       :" $select.Tariff_Version
Write-Host "Param Script Version :" $select.Param_Script_Version
Write-Host "Param Version        :" $select.Param_Version
Write-Host "================================================================="


Write-Host "Preparing Database packages"
foreach($version in $DeploymentVersions){
	Write-Host "Checking Version :" $version
	$selectQuery="Select * from ClevaVersions where Cleva_Version='$version'"
	$select=Invoke-Sqlcmd -Query $selectQuery -ServerInstance $Global:BaloiseBIDBserver -Database $Global:BaloiseReleaseVersionDB -Username $Global:BaloiseVersionDBuserid -Password $Global:BaloiseVersionDBuserpassword -ErrorVariable $out
	if($select){
		$scriptpath=[String]::Format("{0}TechnicalTeam\{1}\config-batch\{2}\batch\shell_script\*.sh",$Deliveryfolder,$select.MIDC_Version,$Environment)
		$mparpath=[String]::Format("{0}\TechnicalTeam\{1}\config-batch\{2}\batch\template\*.mpar",$Deliveryfolder,$select.MIDC_Version,$Environment)
		$ITNdbpackages=[String]::Format("{0}\ITN\{1}\database\cleva\maj_*.zip",$Deliveryfolder,$select.ITN_Version)
		$ITNdbpackagePath=[String]::Format("{0}\ITN\{1}\database\cleva\",$Deliveryfolder,$select.ITN_Version)
		$ClevaDBpackage=[String]::Format("{0}\InitialInstallation\Cleva_{1}\*.zip",$Deliveryfolder,$select.Cleva_Version)
		#checking for new ITN Versions
		if($select.ITN_Type -match "NEW" -and (Test-Path $ITNdbpackagePath)){
			Write-Host "New ITN DB Version: " $filename
			$filename=Get-ChildItem  $ITNdbpackagePath -Filter *.zip 
			Copy-Item  $ITNdbpackages -Destination $dbfolder -Force -Recurse
			Add-Content $dbscripttxtfile -Value $filename
		}
		
		#Adding MIDC DB packages
		$filename="CLEVA_"+$select.Cleva_Version+".zip"
		Add-Content $dbscripttxtfile -Value $filename
		Write-Host "New MIDC DB Version : " $filename
		Copy-Item  $ClevaDBpackage -Destination $dbfolder -Force -Recurse
		if($lastmajorver -ieq $version){
			Write-host "Adding Import Parameters for last Major version :" $version
			$pname=$select.Param_Version
			$pname=$pname -replace "tables",""
			$pname=$pname -replace ".exp",""
			$paramtext=[string]::Format("import {0} force",$pname)
			Add-Content $dbscripttxtfile -Value "newparam"
			if($Environment -ieq "PAR" -or $Environment -ieq "PLAB"){
				$paramtext="export"
			}
			if($Environment -ieq "DEV" -or $Environment -ieq "DCORP"){
				$paramtext="import"
			}
			Add-Content $dbscripttxtfile -Value $paramtext
			}
			
		}
 }
	




