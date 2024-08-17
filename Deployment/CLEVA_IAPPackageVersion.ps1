Param($Environment)
##
if(!$Environment){
$Environment='ACORP'
}

Clear
$date=[DateTime]::Now.ToString("yyyy-MM-dd")

switch ($Environment) 
      { 
        "ICORP" { $PreEnv="DCORP"}
		"ACORP" { $PreEnv="ICORP"}
		"PCORP" { $PreEnv="ACORP"}
     }
#$PreEnv='DCORP'
switch ($Environment) 
      { 
	    "DCORP" { $ClevaEnv="DEV"}
        "ICORP" { $ClevaEnv="INT"}
		"ACORP" { $ClevaEnv="ACC"}
		"PCORP" { $ClevaEnv="PRD"}
     }
#Importing SQL modules for SQL commands to the Version database
Import-Module sqlps -DisableNameChecking


$PacakgeBase="D:\ClevaPackages\$ClevaEnv\"
$Deliveryfolder="D:\Delivery\Deploy\packages\"
$ClevaDeliveryfolder="D:\Delivery\Deploy\Cleva\"
$templatelocation="D:\BuildTeam\Templates\DeploymentTemplates\*"
$propertiesfile=[string]::Format("D:\BuildTeam\Properties\{0}_ClevaDeploy.Properties",$ClevaEnv)
$versions=@()
$propfile=@{}
$propdata=""
foreach($line in [System.IO.File]::ReadAllLines($propertiesfile)){
$propfile+= ConvertFrom-StringData $line
}
 #DB server information
$DBuserid="L001171"
$DBpassword="teCH_Key_PRO"
$dbserver="sql-be-buildp"
$dbName="BaloiseReleaseVersions"
$SqlConnection = New-Object System.Data.SqlClient.SqlConnection
$SqlCmd = New-Object System.Data.SqlClient.SqlCommand

$currentVersion=""
$exeproccmd="EXEC GetDeployedAppVersion @Application='CLEVA',@Environment='$Environment'"
$currentVersion=Invoke-Sqlcmd -Query $exeproccmd -ServerInstance $dbserver -Database $dbName -Username $DBuserid -Password $DBpassword -ErrorVariable $out
$currentVersion=$currentVersion.BuildVersion
$exeproccmd="EXEC GetDeployedAppVersion @Application='CLEVA',@Environment='$PreEnv'"
$prevenv=Invoke-Sqlcmd -Query $exeproccmd -ServerInstance $dbserver -Database $dbName -Username $DBuserid -Password $DBpassword -ErrorVariable $out
$prevenv=$prevenv.BuildVersion


$exeproccmd="EXEC GetBuildVersionsBetween @Application='CLEVA',@Environment='$Environment',@sourceVersion='$currentVersion',@targetVersion='$prevenv'"
$preversions=Invoke-Sqlcmd -Query $exeproccmd -ServerInstance $dbserver -Database $dbName -Username $DBuserid -Password $DBpassword -ErrorVariable $out
[system.Data.DataRow]$row=$null
$versions=@()

Write-Host "========================Version Package info===================="
Write-Host "Latest Version on $($PreEnv)      : " $prevenv
Write-Host "Latest Version on $($Environment) : " $currentVersion
if($currentVersion -ieq $prevenv){
	Write-Host "There are no new versions to be packaged for $($Environment). Error in pacakging"
	Exit 1
}
Write-Host "Packaging the following Version(s)"

$lastmajorver=""
Foreach($row in $preversions){
	$row.Version
	if(($row.Version).split('.')[3] -eq 0){
		$lastmajorver=$row.Version
	}
	$versions+=([string]$row.Version)
}

Write-Host "========================Version Package info===================="
$NewVersion=$versions[-1]
$NewVersionfolder=$PacakgeBase+$NewVersion
New-Item -ItemType Directory -Path $NewVersionfolder
Copy-Item $templatelocation -Destination $NewVersionfolder -Force -Recurse

#preparing deployment properties file for Deployment
$propfile["Version"]=$NewVersion
$propfile["ReleaseDate"]=$date
$propfile.Keys|%{$propdata+="$_="+$propfile.Item($_)+"`r`n"}
Set-Content $propertiesfile -Value $propdata


$selectQuery="Select * from ClevaVersions where Cleva_Version='$NewVersion'"
$select=Invoke-Sqlcmd -Query $selectQuery -ServerInstance $dbserver -Database $dbName -Username $DBuserid -Password $DBpassword -ErrorVariable $out


Write-Host "New ICORP Version Info"
Write-Host "================================================================="
Write-Host "Baloise Version      :" $select.Cleva_Version
Write-Host "MDIC Version         :" $select.MIDC_Version
Write-Host "ITN  Version         :" $select.ITN_Version
Write-Host "TARIFF Version       :" $select.Tariff_Version
Write-Host "Param Script Version :" $select.Param_Script_Version
Write-Host "Param Version        :" $select.Param_Version
Write-Host "================================================================="


$versionfile=$ClevaDeliveryfolder+"$NewVersion\version"
Copy-Item $versionfile -Destination $NewVersionfolder -Force -Recurse

#server
$folder=$NewVersionfolder+"\server\"
#getting ears
$earpath=$Deliveryfolder+"TechnicalTeam\"+$select.MIDC_Version+"\*.ear"
Copy-Item  $earpath -Destination $folder -Force -Recurse

#gettingconfig files
$configzip=$Deliveryfolder+"TechnicalTeam\"+$select.MIDC_Version+"\config-dist.zip"
Copy-Item  $configzip -Destination $folder -Force -Recurse

 
 
$folder=$NewVersionfolder+"\webupdate\"
$UpdateSitepath=$Deliveryfolder+"TechnicalTeam\"+$select.MIDC_Version+"\updatesite*.zip"
Copy-Item  $UpdateSitepath -Destination $folder -Force -Recurse



$folder=$NewVersionfolder+"\prexlib_jar\"
$tarifxml=$Deliveryfolder+"tarification\"+$select.Tariff_Version +"\tarifs.xml"
$tariffs=$Deliveryfolder+"tarification\"+$select.Tariff_Version +"\T9-tarif-*"
Copy-Item  $tarifxml -Destination $folder -Force -Recurse
Copy-Item  $tariffs -Destination $folder -Force -Recurse
   

$batchfolder=$NewVersionfolder+"\batch\"
$envfile=$ClevaDeliveryfolder+$select.Cleva_Version +"\EnvironmentVariable.sh"
Copy-Item  $envfile -Destination $batchfolder -Force -Recurse

$paramscriptversion=[String]::Format("{0}\ParameterizationScripts\{1}\*.zip",$Deliveryfolder,$select.Param_Script_Version)
$dbfolder=$NewVersionfolder+"\database\cleva\"
Copy-Item  $paramscriptversion -Destination $dbfolder -Force -Recurse


$paramversion=[String]::Format("{0}\Params\{1}\*.zip",$Deliveryfolder,$select.Param_Version)
Copy-Item  $paramversion -Destination $dbfolder -Force -Recurse

$parfolder=$NewVersionfolder+"\batch"+"\pars\"
$dbscripttxtfile=$dbfolder+"\deployScripts.txt"
#[system.Data.DataRow]$row=$null
Foreach($ver in $versions)
{
	#[string]$ver=$row.BuildVersion
	$selectQuery="Select * from ClevaVersions where Cleva_Version='$ver'"
	$select=Invoke-Sqlcmd -Query $selectQuery -ServerInstance $dbserver -Database $dbName -Username $DBuserid -Password $DBpassword -ErrorVariable $out
	$scriptpath=[String]::Format("{0}TechnicalTeam\{1}\config-batch\{2}\batch\shell_script\*.sh",$Deliveryfolder,$select.MIDC_Version,$ClevaEnv)
	$mparpath=[String]::Format("{0}\TechnicalTeam\{1}\config-batch\{2}\batch\template\*.mpar",$Deliveryfolder,$select.MIDC_Version,$ClevaEnv)

	#dbfolders

	$ITNdbpackages=[String]::Format("{0}\ITN\{1}\database\cleva\maj_*.zip",$Deliveryfolder,$select.ITN_Version)
	$ITNdbpackagePath=[String]::Format("{0}\ITN\{1}\database\cleva\",$Deliveryfolder,$select.ITN_Version)
	$ClevaDBpackage=[String]::Format("{0}\InitialInstallation\Cleva_{1}\*.zip",$Deliveryfolder,$select.Cleva_Version)
	 
	if($select.ITN_Type -match "NEW" -and (Test-Path $ITNdbpackagePath)){
		$filename=Get-ChildItem  $ITNdbpackagePath -Filter "maj*.zip"
		Copy-Item  $ITNdbpackages -Destination $dbfolder -Force -Recurse
		Add-Content $dbscripttxtfile -Value $filename
	}
	$val="CLEVA_"+$select.Cleva_Version+".zip"
	Add-Content $dbscripttxtfile -Value $val
	Copy-Item  $ClevaDBpackage -Destination $dbfolder -Force -Recurse


	if($lastmajorver -eq $select.CLEVA_VERSION){
		$pname=$select.Param_Version
		$pname=$pname -replace "tables",""
		$pname=$pname -replace ".exp",""
		$paramtext=[string]::Format("import {0} force",$pname)
		Add-Content $dbscripttxtfile -Value "newparam"
		Add-Content $dbscripttxtfile -Value $paramtext
		
	}
	#getting the batches set
	#if($select.MIDC_VersionType -match "NEW"){
	##Copy-Item  $scriptpath -Destination $batchfolder -Force -Recurse
	##Copy-Item  $mparpath -Destination $parfolder -Force -Recurse
	#} 
}

$envfile=$ClevaDeliveryfolder+$NewVersion +"\EnvironmentVariable.sh"
Copy-Item  $envfile -Destination $batchfolder -Force -Recurse


