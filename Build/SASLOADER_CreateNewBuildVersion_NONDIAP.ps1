PARAM([string]$Environment)

Clear-Host 


if(!$Environment){
    $Environment="MIG"
}
	  
#Importing SQL modules for SQL commands to the Version database
Import-Module sqlps -DisableNameChecking
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}

$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	

#Variables
$ApplicationName="SASLOADER"
$VersionType="Major"
$Branch="DEV"
$Release="99"
$CheckSFTP="True"

#Download location and paths 
$tempdownload="C:\"+$ApplicationName+"MATCdownloadfolder"
$DownloadFolder=join-path $Global:SASLOADERDownloadPackages -childpath "R$($Release)"
$MATCDownloadFolder=join-path $DownloadFolder -childpath "MATC\$($Environment)"
$PackagePath=join-path $DownloadFolder -childpath "MATC"

if(test-path $tempdownload){
	Write-Host "Removing Temporary folders - $($tempdownload)"
	Remove-Item $tempdownload -Force -Recurse -ErrorAction Stop
	New-Item $tempdownload -ItemType directory -Force | Out-Null
}


function GetLatestFolder($folderpath){
	return Get-ChildItem Filesystem::$folderpath | where {$_.PsIsContainer}| sort LastWriteTime -Descending | Select -First 1
}


#If the folder does not exit then create it 
if(-not(test-path filesystem::$MATCDownloadFolder)){
	New-Item Filesystem::$MATCDownloadFolder -ItemType directory -Force | Out-Null
}

$MATCsourcefolder=[string]::Format('/in/ReleasesV14/R{0}_{1}_NonDIAP/{2}/',$Release,$ApplicationName,$Environment)
$MATCarchive=[string]::Format('/in/ReleasesV14/Archive/R{0}_{1}_NonDIAP/{2}/',$Release,$ApplicationName,$Environment)

if($ApplicationName -ieq "SASLOADER"){
    $MATCarchive=[string]::Format('/in/ReleasesV14/Archive/R{0}_Sasloader_NonDIAP/{1}/',$Release,$Environment)
}

#Download MATC souce Code
if($CheckSFTP -ieq "true"){
    $Newdownload=DownloadSFTPFiles -Destination $tempdownload -source $MATCsourcefolder -Type $ApplicationName -Archive $MATCarchive -PackagePath $PackagePath #-AlwaysArchive "False"
	if(!$Newdownload){
		Write-Host "There are are no new versions to download. Aborting new version..."
		Exit 1
	}
     Copy-Item -Path $tempdownload\* -Destination Filesystem::$MATCDownloadFolder -recurse
}





#getting the latest versions for new version creation
$SASLOADERVer=GetLatestFolder $MATCDownloadFolder


#creating the new version based on the input
$Newverisoninfo=CreateNewApplicationVersion -ApplicationName $ApplicationName -VersionType $VersionType -Release $Release -Branch $Branch
$newVersion=$Newverisoninfo.Version


#Parameter to check if a new MIDC Version is delivered
$selectQuery="Select top 1 MATC_Version from SASLOADERVersions where [MATC_Version]='$SASLOADERVer'"
$select=ExecuteSQLonBIVersionDatabase -SqlStatement $selectQuery
$midcvertype="NEW"
if($select.MATC_Version -ne $null ){
	$midcvertype="REPEAT"
}


$Release="R"+$Release
Write-Host "Preparing new version......"
Write-Host "================================================================="
Write-Host "Release                 :" $Release
Write-Host "Baloise Version      	:" $newVersion
Write-Host "SASLOADER Version 	    :" $SASLOADERVer
Write-Host "================================================================="


#inserting the pacakge values into the database
$insertStatement=[string]::Format("INSERT INTO [dbo].[SASLOADERVersions] VALUES ('{0}','{1}','{2}',getdate(),'{3}')",$newVersion,$SASLOADERVer,$midcvertype,$Release)
$select=ExecuteSQLonBIVersionDatabase -SqlStatement $insertStatement



# Extracting the server part
$propertiesfilename=[string]::Format("{0}_Build.properties",$ApplicationName)
$ApplicationPropertiesfile=join-path $Global:JenkinsPropertiesRootPath -ChildPath $propertiesfilename
setProperties -FilePath $ApplicationPropertiesfile -Properties $Newverisoninfo


$MIDCJBossSourcezip=[string]::Format("{0}\{1}\{2}.zip",$tempdownload,$SASLOADERVer,$SASLOADERVer)
$TempBasedFolder="C:\SASLOADERTempFolder\"
$TempExtracted=join-path $TempBasedFolder -childpath "zips"
$PackageSourceFolder=[string]::Format("{0}\{1}\sources",$global:NewPackageRoot,$ApplicationName)

#cleanup
If(test-path $TempBasedFolder){
    write-host "Recreating fld"
    Remove-Item $TempBasedFolder -Force -Recurse -ErrorAction SilentlyContinue
  }

New-Item $TempExtracted -ItemType directory -Force
#creating Temporary Folder
Write-Host "Extracting the Package to temp location : $TempBasedFolder"
Write-Host "Zip file  - " $MIDCJBossSourcezip

#creating a new Drive mapped to the source folder 
Remove-PSDrive -Force -Name R -ErrorAction SilentlyContinue
New-PSDrive  -Name R -Root $PackageSourceFolder -PSProvider "Filesystem" -Persist | Out-Null
$PackageSourceFolder="R:\"
$DeploymentTemplatefolder=join-path $PackageSourceFolder -ChildPath "Templates\SourceTemplate\"
$currentReleasefolder=join-path $PackageSourceFolder -ChildPath "$Release\$Environment\"
Expand-Archive -Path "$MIDCJBossSourcezip" -DestinationPath "$TempExtracted" -Force

#preparing the folders
$localNewVersionFolder=join-path $TempBasedFolder -ChildPath "$newVersion\"
New-Item $localNewVersionFolder -itemtype Directory -Force  | Out-Null
Copy-Item $DeploymentTemplatefolder\* -Destination $localNewVersionFolder  -Recurse -Force -ErrorAction Stop


#server - jboss
$folder=join-path $localNewVersionFolder  -childpath "server\"
$loaderzipfile=join-path $TempExtracted -ChildPath "\loader.zip"
#Expand-Archive -Path "$loaderzipfile" -DestinationPath "$folder" -Force


#gettingconfig files
$configzip=join-path $TempExtracted -ChildPath "\config-dist.zip"
Copy-Item  $configzip -Destination $folder -Force -Recurse

#Getting loader.zip files
$loaderzip=join-path $TempExtracted -ChildPath "\loader.zip"
Copy-Item  $loaderzip -Destination $folder -Force -Recurse

#preparing Releasenotes
write-host "==================Preparing Release notes===================================="
#write-host "Preparing Release notes - MATC"
#$MATCSourcePath=$($MIDCVer.FullName)
#$notes=Get-ChildItem Filesystem::$MATCSourcePath -Filter "*.docx"-Force
#if($notes){
	
#	Copy-Item $notes.FullName -Destination $localNewVersionFolder -ErrorAction SilentlyContinue
#	$ReleaseNoteName=[string]::Format("MATC_{0}_{1}_{2}_Releasenotes.docx",$Release,$MIDCVer.Name,$newVersion)
#	rename-item "$localNewVersionFolder$notes" -NewName $ReleaseNoteName -Force 
#}
#else {
#	Write-Host "INFO: There were no release notes found..."
#}


#creating a version file for deployment
$versionfile=Join-Path $localNewVersionFolder -ChildPath "version"
#INT Version is not added since it is not relavent anymore
Add-Content $versionfile -Value $newVersion

write-host "==================Preparing Batch and MPAR Files===================================="
$batchfolder=[string]::Format("{0}\batch",$localNewVersionFolder)
$envfile=[string]::Format("{0}\batch\EnvironmentVariable.sh",$localNewVersionFolder)
$envfile=join-path $batchfolder -ChildPath "\EnvironmentVariable.sh"
$envfilcontents=Get-Content $envfile
$envfilcontents=$envfilcontents.replace("%NEWVERSION%","$newVersion")
Set-Content $envfile -Value $envfilcontents

#Extracting batch zip 
#checking for batch file list 
$Mparfilepath=(Get-ChildItem Filesystem::$MATCDownloadFolder -Filter "mpars_*.txt" -Force).FullName
if($Mparfilepath){ 
	if(test-path $Mparfilepath){
		Write-Host "New mpars found"
		Copy-Item $Mparfilepath -Destination $localNewVersionFolder -Force 
	}
}
else {
 write-host "No Adhoc Batch files to be deployed"
}
$batchzip=join-path $TempExtracted -ChildPath "config-batch.zip"
$tempbatchextracted=join-path $TempExtracted -ChildPath "batches"
New-Item $tempbatchextracted -ItemType directory -force | out-null
Expand-Archive -Path $batchzip -DestinationPath $tempbatchextracted -Force

foreach($Environment in $($Global:CLEVAEnvironments).split(',')){
	$clevenv=getClevaEnvironment -Environment $Environment
	$EnvBatchfolder=[string]::Format("{0}batch\{1}",$localNewVersionFolder,$Environment)
	$shellscripts=[string]::Format("{0}\{1}\",$tempbatchextracted,$clevenv)
	
	if(Test-Path $shellscripts){
		copy-item "$($shellscripts)\*" -Destination $EnvBatchfolder -Force -Recurse
	}
	else {
		Write-Host "WARNING : No Batches found for Environment : $clevenv in the source package"
		#Except for PARAM all other envs should have the batches
	}
	Copy-Item $envfile -Destination $EnvBatchfolder
}
write-host "==================Preparing Batch and MPAR Files===================================="


#Preparing database
write-host "==================Preparing SQL Scripts for Deployment===================================="
Write-Host 	"Checking if SQL Files are to be deployed"
$SQLTemplate=@"
@sql/%SCRIPTNAME%
insert into T_MERC_LOG_PACKAGES (PKG_ID, PKG_TIME, PKG_PACKAGE, PKG_VERSION, PKG_LOG) values (SEQ_T_MERC_LOG_PACKAGES.nextval, sysdate, &SASLOADER_ID, &SASLOADER_VERSION,'%SCRIPTNAME%');
"@
$midcvertype="NEW"
$sqlfileslocation= Join-Path $localNewVersionFolder -ChildPath "database\SASLOADER\sql"
$sqlsummaryFile=Join-Path $sqlfileslocation -ChildPath "summary.sql"
$summarycontent=Get-Content $sqlsummaryFile
$scriptsfolder=(Get-ChildItem Filesystem::$tempdownload -Recurse -Filter "Scripts*" | select -First 1 ).FullName
$scriptlist=""
if($scriptsfolder){
	Write-Host "INFO: This Version has SQL Scripts - Ceating SQL package..."
	if((test-path $scriptsfolder) -and $midcvertype -ieq "NEW"){
			Get-ChildItem $scriptsfolder -Recurse -Filter "*.sql" | sort | foreach{
			Write-Host "Preparing File : "  $_.Name
			copy $_.FullName -Destination $sqlfileslocation
			$Script=$SQLTemplate -ireplace "%SCRIPTNAME%",$_.Name
			$scriptlist+="`r`n" + $Script
		}
	}
}
else{
	Write-Host 	"INFO: There are no DB Scripts in this package"
}
$summarycontent=$summarycontent -ireplace "--SCRIPTLIST",$scriptlist
Set-Content $sqlsummaryFile -Value $summarycontent -Force

#setting the PackageVersion File
$packageVersionFile=Join-Path "$($localNewVersionFolder)\database\SASLOADER" -ChildPath "pkg_version.sql"
$packageVersionFileContent=Get-Content $packageVersionFile
$packageVersionFileContent=$packageVersionFileContent -ireplace "NEWVERSION",$newVersion
$packageVersionFileContent=$packageVersionFileContent -ireplace "MATCVERSION",$SASLOADERVer
Set-Content $packageVersionFile -Value $packageVersionFileContent -Force

Write-Host 	"Zipping the SQL Package..."
$ClevaDBpackageFolder=Join-Path $localNewVersionFolder -ChildPath "database\SASLOADER\"
$tempsqlextracted=join-path $TempExtracted -ChildPath "SQLPackage"
New-Item $tempsqlextracted -ItemType directory -force | out-null
Copy-Item "$($ClevaDBpackageFolder)\*" -Destination $tempsqlextracted -Force -Recurse
$desitnationzipfullPath=[String]::Format("{0}\SASLOADER_{1}.zip",$tempsqlextracted,$newVersion)
Compress-Archive "$tempsqlextracted\*" -DestinationPath $desitnationzipfullPath -Force
Start-Sleep -Seconds 3
Copy-Item $desitnationzipfullPath -Destination $ClevaDBpackageFolder -ErrorAction Stop

write-host "==================Preparing SQL Scripts for Deployment===================================="

write-host "=========================Uploading the new verison $newVersion to the Package Share============================="
#moving the Newly created Package to the share 
copy-item $localNewVersionFolder -destination $currentReleasefolder -Force -Recurse

#cleanup
Write-Host "Cleaning up Temp directory used for creating the new version"
Set-Location "c:\"
cmd.exe /c "rd /s /q $TempBasedFolder"
Remove-PSDrive R -Force 
write-host "=========================Uploading the new verison $newVersion to the Package Share============================="
