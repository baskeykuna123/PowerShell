PARAM(
	[string]$ActionType,
	[string]$Branch,
	[string]$Release,
	[string]$CheckSFTP
	)

Clear-Host 


if(!$Release){
	$ActionType="Major"
	$Branch="DEV"
	$Release="29"
	$CheckSFTP=$false
}
	  
#Importing SQL modules for SQL commands to the Version database
Import-Module sqlps -DisableNameChecking
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}

$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	

#Variables
$DeliverysourcesFolder="\\balgroupit.com\appl_data\BBE\Packages\ErrorMonitoring\Sources\"
$Release="R"+$Release
$ApplicationName="ErrorMonitoring"
#Source paths on MIDC  SFTP
$sourcefolder='/in/Releases/'+ $Release + '_Errormon/'
$archive='/in/Releases/Archive/'+$Release+'_Errormon/'
$MIDCDownloadFolder="D:\Accenture\$Release\ErrorMonitoring_Delivery"
$sqltemplatepath="\\balgroupit.com\appl_data\BBE\Packages\ErrorMonitoring\Sources\templates\ErrorMonSQL_Template"

switch ($ActionType) 
      { 
		"Major"		{ 
						$pos=3
					} 
		"Patch"		{ 
						$pos=4
					}
	}


$Newdownload=DownloadSFTPFiles -Destination $MIDCDownloadFolder -source $sourcefolder -Type "Errormon" -Archive $archive

if($CheckSFTP -ieq "true"){
	if(!$Newdownload){
		Write-Host "There are are no new versions to download. Aborting new version..."
		Exit 1
	}
}

function GetLatestFolder($folderpath){
	return Get-ChildItem $folderpath | where {$_.PsIsContainer}| sort LastWriteTime -Descending | Select -First 1
}

	  
# DB server information
$DBuserid="L001171"
$DBpassword="teCH_Key_PRO"
$dbserver="sql-be-buildp"
$dbName="BaloiseReleaseVersions"


#getting the latest versions for new version creation
$ERRORMONVer=GetLatestFolder $MIDCDownloadFolder



$Release=$Release.Replace("R","")
#creating the new version based on the input
$exeproccmd="EXEC CreateNewBuildVersion @Application='$ApplicationName',@position='$pos',@Release='$Release',@Branch='$Branch'"
$newVersion=Invoke-Sqlcmd -Query $exeproccmd -ServerInstance $dbserver -Database $dbName -Username $DBuserid -Password $DBpassword -ErrorVariable $out
$newVersion=$newVersion.NEWVersion


$Release="R"+$Release
Write-Host "Preparing new version......"
Write-Host "================================================================="
Write-Host "Release                 :" $Release
Write-Host "Baloise Version      	:" $newVersion
Write-Host "ErrorMonitoring Version :" $ERRORMONVer
Write-Host "================================================================="

$DeliverysourcesFolder=join-path $DeliverysourcesFolder -ChildPath $newVersion
$DeliverySourceServer=join-path $DeliverysourcesFolder -ChildPath "server"
$DeliverySourceDatabase=join-path $DeliverysourcesFolder -ChildPath "Database"
New-Item Filesystem::$DeliverySourceServer -ItemType Directory  #| Out-Null
New-Item Filesystem::$DeliverySourceDatabase -ItemType Directory -Force #| Out-Null


#Parameter to check if a new MIDC Version is delivered
$selectQuery="Select top 1 MIDC_Version from ErrorMonitoringVersions where [MIDC_Version]='$ERRORMONVer'"
$select=Invoke-Sqlcmd -Query $selectQuery -ServerInstance $dbserver -Database $dbName -Username $DBuserid -Password $DBpassword -ErrorVariable $out
$midcvertype="NEW"
if($select.MIDC_Version -ne $null ){
	$midcvertype="REPEAT"
}

#inserting the pacakge values into the database
$insertQuery=[string]::Format("INSERT INTO [dbo].[ErrorMonitoringVersions] VALUES ('{0}','{1}','{2}',getdate(),'{3}')",$newVersion,$ERRORMONVer,$midcvertype,$Release)
$update=Invoke-Sqlcmd -Query $insertQuery -ServerInstance $dbserver -Database $dbName -Username $DBuserid -Password $DBpassword -ErrorVariable $out


# Extracting the server part
$sourcezip=Get-ChildItem $ERRORMONVer.FullName -Recurse -Filter "*.zip"  
$unzipcommand=[string]::Format("unzip -oq {0} -d {1}",$sourcezip.FullName,$DeliverySourceServer)
cmd /c $unzipcommand


#Preparing database
$SQLTemplate=@"
@sql/%SCRIPTNAME%
insert into T_MERC_LOG_PACKAGES (PKG_ID, PKG_TIME, PKG_PACKAGE, PKG_VERSION, PKG_LOG) values (SEQ_T_MERC_LOG_PACKAGES.nextval, sysdate, &ERROR_ID, &ERROR_VERSION,'%SCRIPTNAME%');
"@

Copy-Item Filesystem::"$sqltemplatepath\*" -Destination Filesystem::$DeliverySourceDatabase -Recurse -Force
$sqlfileslocation= Join-Path $DeliverySourceDatabase -ChildPath "sql"
$sqlsummaryFile=Join-Path $sqlfileslocation -ChildPath "summary.sql"
$packageVersionFile=Join-Path $DeliverySourceDatabase -ChildPath "pkg_version.sql"
$packageVersionFileContent=Get-Content Filesystem::$packageVersionFile
$summarycontent=Get-Content Filesystem::$sqlsummaryFile
$scriptsfolder=(Get-ChildItem $ERRORMONVer.FullName -Recurse -Filter "Scripts*" | select -First 1 ).FullName
$scriptlist=""
if ($scriptsfolder){
	if((test-path $scriptsfolder) -and $midcvertype -ieq "NEW"){
			Get-ChildItem $scriptsfolder -Recurse -Filter "*.sql"  | foreach{
			Write-Host "Preparing File : "  $_.Name
			copy $_.FullName -Destination Filesystem::$sqlfileslocation
			$Script=$SQLTemplate -ireplace "%SCRIPTNAME%",$_.Name
			$scriptlist+="`r`n" + $Script
		}
	}
}
$summarycontent=$summarycontent -ireplace "--SCRIPTLIST",$scriptlist
Set-Content Filesystem::$sqlsummaryFile -Value $summarycontent -Force

$packageVersionFileContent=$packageVersionFileContent -ireplace "%ErrorMonVersion%",$newVersion
$packageVersionFileContent=$packageVersionFileContent -ireplace "%ErrorMonMIDCVersion%",$($ERRORMONVer.Name)
Set-Content Filesystem::$packageVersionFile -Value $packageVersionFileContent -Force

#zip DB Folder
$templocation="D:\buildteam\temp\zips\"
Remove-Item "$($templocation)*" -Force -Recurse -ErrorAction SilentlyContinue
$ErrorMonitoringDBpackageFolder=[String]::Format("{0}\Database\",$DeliverysourcesFolder)
Copy-Item Filesystem::"$($ErrorMonitoringDBpackageFolder)*" -Destination $templocation -Force -Recurse
$zipfilename=[String]::Format("ErrorMon_{0}.zip",$newVersion)
Set-Location $templocation
cmd /c "zip -rq $zipfilename *"
$zipfilename=Join-Path $templocation -ChildPath $zipfilename
Copy-Item 	$zipfilename -Destination Filesystem::$ErrorMonitoringDBpackageFolder -Force -Recurse

$versionfile=join-path $DeliverysourcesFolder -childpath "version"
Set-Content Filesystem::$versionfile -Value $newVersion
