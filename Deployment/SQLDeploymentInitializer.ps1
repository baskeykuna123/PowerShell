Param($EM3only)
Write-Host "$EM3only"
if(!$EM3only){
	$EM3only="true"
}

#$baselocation="D:\Accenture\ACN_Scripts\"
$baselocation="\\balgroupit\appl_data\BBE\User01\pcorp\Cleva\ACN_Scripts\"
$uploadfile=$baselocation+ "ScriptUploadInfo.xml"
$scriptinfo= [xml](get-content -Path Filesystem::$uploadfile)

function Renamefiles($files){
	foreach($f in $files){
		$newname= $f.BaseName
		Write-Host "InputFile :" $newname
		$newname=$newname -replace '-','_'
		$newname=$newname -replace ' ','_'
		$newname=$newname+".sql"
		Rename-Item Filesystem::$f -NewName $newname
		Write-Host "Renamed File :" $newname
	}
}

$list=""
$list=get-childitem Filesystem::$baselocation  -Include *.sql,*.txt -Force -recurse
Write-Host "`r`n List of files"
$list.FullName

if($list){
	Renamefiles $list
}
else{
	Write-Host "There are no files to process at this moment in time"
	Exit
}

if($EM3only -match "true"){
	Write-Host "Seraching Emergency3"
	$scriptlocation=$baselocation+"Emergency_3\"
	$list=get-childitem Filesystem::$scriptlocation  -Include *.sql,*.txt -Force -recurse -Verbose
}
else{
	$list = Get-ChildItem Filesystem::$baselocation -recurse -Include *.sql,*.txt -Verbose|  where-object {$_.FullName -notlike "*Emergency_3*"}
}


if($list)
{
Write-Host "Found files"
foreach($folder in $list){
$filename=Split-Path $folder -Leaf
$SQLFname=$folder.DirectoryName
$NewSQLScritps=$folder.FullName
$SQLFname=$SQLFname.Replace($baselocation,"")
$Env=$SQLFname.Split('\')[1]
$Deploymenttype=($SQLFname.Split('\')[0]).Split('_')[0]
$seq=($SQLFname.Split('\')[0]).Split('_')[1]

#ScriptLog info
$node=$scriptinfo.SelectSingleNode("/SqlScripts/$Env/$Deploymenttype")
$timestamp=[DateTime]::Now.ToString("yyyy-MM-dd_HH:mm")
$new=$scriptinfo.CreateElement("File")
$new.SetAttribute("Name",$filename)
$new.SetAttribute("Environment",$Env)
$new.SetAttribute("DateTime",$timestamp)
$new.SetAttribute("Sequence",$seq)
$node.AppendChild( $new)
$scriptinfo.Save($uploadfile)

$ErrorActionPreference="stop"
$Buildteam="D:\BuildTeam\temp\"
$date=Get-Date -format yyyy-MM-dd
$Currentdate="ReleaseDate="+$date
$templatelocation="\\balgroupit\appl_data\BBE\Packages\ClevaV14\Sources\templates\SQLPackage_Template\*"

if($Deploymenttype -match "Daily" -or $Deploymenttype -match "monthly"){
	$DeploymentLocation="\\balgroupit\appl_data\BBE\Packages\ClevaV14\Sources\SQLScripts\Scheduled\"
	$scheduledfolder=$Deploymenttype+"_"+$Env+"_"+$seq
	$Summaryinsert="insert into T_MERC_LOG_PACKAGES (PKG_ID, PKG_TIME, PKG_PACKAGE, PKG_VERSION, PKG_LOG) values (SEQ_T_MERC_LOG_PACKAGES.nextval, sysdate, &SCRIPT_ID, &SCRIPT_VERSION, 'Sqlfile');"
	$insert="insert into T_MERC_LOG_PACKAGES (PKG_ID, PKG_TIME, PKG_PACKAGE, PKG_VERSION, PKG_LOG) values (SEQ_T_MERC_LOG_PACKAGES.nextval, sysdate, &SCRIPT_ID, &SCRIPT_VERSION, 'defect xxxx');"
}

if($Deploymenttype -match "Emergency"){
	$Deploymenttype="YMR"
	$DeploymentLocation="\\balgroupit\appl_data\BBE\Packages\ClevaV14\Sources\SQLScripts\Emergency\"
	$scheduledfolder=$Deploymenttype+"_"+$date+"_"+$Env+"_"+$seq
	$Summaryinsert="insert into T_MERC_LOG_PACKAGES (PKG_ID, PKG_TIME, PKG_PACKAGE, PKG_VERSION, PKG_LOG) values (SEQ_T_MERC_LOG_PACKAGES.nextval, sysdate, &YMR_ID, &YMR_VERSION, 'Sqlfile');"
	$insert="insert into T_MERC_LOG_PACKAGES (PKG_ID, PKG_TIME, PKG_PACKAGE, PKG_VERSION, PKG_LOG) values (SEQ_T_MERC_LOG_PACKAGES.nextval, sysdate, &YMR_ID, &YMR_VERSION, 'defect xxxx');"
}

$DeploymentFolder=$Deploymenttype+"_"+$date+"_"+$Env+"_$seq"
$NewVersionFolderPath=$DeploymentLocation + $DeploymentFolder


$summarytemplate="$NewVersionFolderPath\sql\Daily_summary.sql"

Write-Host "Preparing $Deploymenttype deployement packages based on the following inputs"
Write-Host "========================================================="
Write-Host "Environment       : $Env"
Write-Host "Date              : $date"
Write-Host "Deployment Type   : $Deploymenttype"
Write-Host "Deployment Folder : $DeploymentFolder"
Write-Host "Source SQL(s)path : $NewSQLScritps"
Write-Host "Sequence Number   : $seq"
Write-Host "========================================================="



Write-Host "Preparing the SQL scripts for deployment"
write-host "****************************************************"
if( -not (Test-Path Filesystem::$NewVersionFolderPath)){
	New-Item Filesystem::$NewVersionFolderPath -Force -ItemType Directory 
	Copy-Item Filesystem::$templatelocation -Destination Filesystem::$NewVersionFolderPath -Force -Recurse

if($Deploymenttype -match "YMR"){
	Remove-Item "$NewVersionFolderPath\sql\Daily_Summary.sql" -Force
	Remove-Item "$NewVersionFolderPath\Daily_pkg_version.sql" -Force
	Rename-Item "$NewVersionFolderPath\sql\YMR_Summary.sql" -NewName "summary.sql"
	Rename-Item "$NewVersionFolderPath\YMR_pkg_version.sql" -NewName "pkg_version.sql"
}
else{
	Remove-Item "$NewVersionFolderPath\sql\YMR_Summary.sql" -Force
	Remove-Item "$NewVersionFolderPath\YMR_pkg_version.sql" -Force
	Rename-Item "$NewVersionFolderPath\sql\Daily_Summary.sql" -NewName "summary.sql"
	Rename-Item "$NewVersionFolderPath\Daily_pkg_version.sql" -NewName "pkg_version.sql"
}

write-host "Make deploy file for Scheduled-scripts........"
Add-Content  "$NewVersionFolderPath\deployScripts.txt" -Value "$scheduledfolder.zip"
$ScriptVer=$date+"_"+$Env+"_"+$seq
write-host   "Make pkg_file for Scheduled-scripts..................."
$packagedata=Get-Content Filesystem::"$NewVersionFolderPath\pkg_version.sql"
$packagedata=$packagedata -ireplace "'Version'","'$ScriptVer'"
$packagedata=$packagedata -ireplace "'Scripttype'","'$Deploymenttype'"
Set-Content Filesystem::"$NewVersionFolderPath\pkg_version.sql" -Value $packagedata
}
Copy-Item -Path Filesystem::$NewSQLScritps -Destination "$NewVersionFolderPath\SQL\"
#Copy-Item -Path $NewSQLScritps -Destination "$NewVersionFolderPath\pkg_content\"
write-host "Preparing the SQL deployment Summary File"


$contents=get-content $NewVersionFolderPath\sql\Summary.sql

$replacementToken="--NEWSQLS"
if($filename -notlike "summary*"){
$Summaryinsert=$Summaryinsert -ireplace "Sqlfile",$filename
$newfileinfo=@"
@sql/$filename
$Summaryinsert
--NEWSQLS
"@
$contents=$contents -ireplace $replacementToken,$newfileinfo
Set-Content $NewVersionFolderPath\sql\Summary.sql -Value $contents
}

Remove-Item  $NewSQLScritps -force 
}
}
