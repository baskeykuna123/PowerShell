PARAM([string]$Environment)

Clear-Host 


if(!$Environment){
	$Environment="MIG4"

}

	  
#Importing SQL modules for SQL commands to the Version database
Import-Module sqlps -DisableNameChecking
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}

$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	

#Variables
$ApplicationName="ClevaV14"
$VersionType="Major"
$Branch="DEV"
$Release="99"
$CheckSFTP="True"

Write-Host "========================Input parameters=================================================="
Write-Host "Version type :" $VersionType
Write-Host "Release      :" $Release
Write-Host "Check SFTP   :" $CheckSFTP
Write-Host "========================Input parameters=================================================="


#setting Import Parameter flag based on type of the version
$ParamImport="Y"
if($VersionType -ieq "patch"){
	$ParamImport="N"
}

#Download location and paths 
$tempdownload="C:\MATCdownloadfolder\"
$DownloadFolder=join-path $Global:ClevaV14DownloadPackages -childpath "R$($Release)\"
$MIDCDownloadFolder=join-path $DownloadFolder -childpath "MATC\$($Environment)\"
$TarifDownloadFolder=join-path $DownloadFolder -childpath "Tariffs"
$ParamScriptDownloadFolder= join-path $DownloadFolder -childpath "ParameterScripts"
$PackagePath=join-path $DownloadFolder -childpath "MATC"

if(test-path $tempdownload){
	Remove-Item $tempdownload -Force -Recurse -ErrorAction SilentlyContinue
	New-Item $tempdownload -ItemType directory -Force | Out-Null
}


function GetLatestFolder($folderpath){
	return Get-ChildItem Filesystem::$folderpath | where {$_.PsIsContainer}| sort LastWriteTime -Descending | Select -First 1
}

$MATCsourcefolder=[string]::Format('/in/ReleasesV14/R{0}_NonDIAP/{1}/',$Release,$Environment)
$MATCarchive=[string]::Format('/in/ReleasesV14/Archive/R{0}_NonDIAP/{1}/',$Release,$Environment)

#Download MATC souce Code
if($CheckSFTP -ieq "true"){
    $Newdownload=DownloadSFTPFiles -Destination $tempdownload -source $MATCsourcefolder -Type "MIDC" -Archive $MATCarchive -PackagePath $PackagePath
	if(!$Newdownload){
		Write-Host "There are are no new versions to download. Aborting new version..."
		Exit 1
	}
    Copy-Item -Path $tempdownload\* -Destination Filesystem::$MIDCDownloadFolder -recurse
}


	 
#getting the latest versions for new version creation
$MIDCVer=GetLatestFolder $MIDCDownloadFolder
$TarifVer=GetLatestFolder $TarifDownloadFolder
$paramScriptVer=GetLatestFolder  $ParamScriptDownloadFolder

#creating the new version based on the input
$Newverisoninfo=CreateNewApplicationVersion -ApplicationName $ApplicationName -VersionType $VersionType -Release $Release -Branch $Branch
$newVersion=$Newverisoninfo.Version
$ITNVer=(($MIDCVer.Name).Replace("JBoss_","")).split('-')[0]

#check if MIDC version is new or repeat
$selectQuery="Select top 1 MIDC_Version from CLEVAVersions where [MIDC_Version]='$MIDCVer'"
$select=ExecuteSQLonBIVersionDatabase -SqlStatement $selectQuery
$midcvertype="NEW"
if($select.MIDC_Version -ne $null ){
	$midcvertype="REPEAT"
}

#Parameter to check if a new ITN Version is delivered
$selectQuery="Select top 1 ITN_Version from CLEVAVersions where [ITN_Version]='$ITNVer'"
$select=ExecuteSQLonBIVersionDatabase -SqlStatement $selectQuery
$itnvertype="NEW"
if($select.ITN_Version -ne $null){
	$itnvertype="REPEAT"
}



$Release="R"+$Release

#inserting the pacakge values into the database
$insertStatement=[string]::Format("INSERT INTO [dbo].[CLEVAVersions] VALUES ('{0}','{1}','{2}','{3}','{4}','{5}','{6}','{7}',getdate(),'{8}')",$newVersion,$MIDCVer,$midcvertype,$ITNVer,$itnvertype,$TarifVer,$paramScriptVer,$paramVer,$Release)
$select=ExecuteSQLonBIVersionDatabase -SqlStatement $insertStatement


Write-Host "Preparing new version......"
Write-Host "================================================================="
Write-Host "Release              :" $Release
Write-Host "Baloise Version      :" $newVersion
Write-Host "MATC Version         :" $MIDCVer
Write-Host "MATC Version TYPE    :" $midcvertype
Write-Host "INT Version          :" $ITNVer
Write-Host "ITN Version TYPE     :" $itnvertype
Write-Host "TARIFF Version       :" $TarifVer
Write-Host "Param Script Version :" $paramScriptVer
Write-Host "================================================================="


$Newverisoninfo.Add("ParamImportExport",$ParamImport)
$propertiesfilename=[string]::Format("{0}_Build.properties",$ApplicationName)
$ApplicationPropertiesfile=join-path $Global:JenkinsPropertiesRootPath -ChildPath $propertiesfilename
setProperties -FilePath $ApplicationPropertiesfile -Properties $Newverisoninfo


$MIDCJBossSourcezip=[string]::Format("{0}{1}\JBoss_{1}.zip",$tempdownload,$MIDCVer.Name)
$TempBasedFolder="C:\ClevaTempFolderV14"
$TempExtracted=join-path $TempBasedFolder -childpath "zips"
$PackageSourceFolder=[string]::Format("{0}\{1}\sources",$global:NewPackageRoot,$ApplicationName)

#cleanup
Remove-Item $TempBasedFolder -Force -Recurse -ErrorAction SilentlyContinue
New-Item $TempExtracted -ItemType directory -Force | Out-Null
#creating Temporary Folder
Write-Host "Extracting the Package to temp location : $TempBasedFolder"
Write-Host "Zip file  - " $MIDCJBossSourcezip

#creating a new Drive mapped to the source folder 
Remove-PSDrive -Force -Name R -ErrorAction SilentlyContinue
New-PSDrive  -Name R -Root $PackageSourceFolder -PSProvider "Filesystem" -Persist | Out-Null
$PackageSourceFolder="R:\"
$DeploymentTemplatefolder=join-path $PackageSourceFolder -ChildPath "Templates\SourceTemplate\"
$currentReleasefolder=join-path $PackageSourceFolder -ChildPath "$Release\$Environment\"
$unzipcommand=Expand-Archive -Path $MIDCJBossSourcezip -DestinationPath $TempExtracted -Force
#$unzipcommand=[string]::Format("unzip -oq {0} -d {1}",$MIDCJBossSourcezip,$TempExtracted)
cmd /c $unzipcommand


#preparing the folders
$localNewVersionFolder=join-path $TempBasedFolder -ChildPath "$newVersion\"
New-Item $localNewVersionFolder -itemtype Directory -Force  | Out-Null
Copy-Item $DeploymentTemplatefolder\* -Destination $localNewVersionFolder  -Recurse -Force -ErrorAction Stop




$MIDCJBossSourcezip=[string]::Format("{0}\JBoss_{1}.zip",$MIDCVer.FullName,$MIDCVer.Name)
$unzipcommand=Expand-Archive -Path $MIDCJBossSourcezip -DestinationPath $TempExtracted -Force
#$unzipcommand=[string]::Format("unzip -oq {0} -d {1}",$MIDCJBossSourcezip,$TempExtracted)
cmd /c $unzipcommand
Start-Sleep -Seconds 3

#unzipping the clients zip 
$clientSourcezip=[string]::Format("{0}\Client_{1}.zip",$MIDCVer.FullName,$MIDCVer.Name)
$unzipcommand=Expand-Archive -Path $clientSourcezip -DestinationPath $TempExtracted -Force
#$unzipcommand=[string]::Format("unzip -oq {0} -d {1}",$clientSourcezip,$TempExtracted)
cmd /c $unzipcommand
Start-Sleep -Seconds 3



#server - jboss
$folder=join-path $localNewVersionFolder  -childpath "server\"
$earpath=join-path $TempExtracted -ChildPath "\T9-Assurance.ear"
Copy-Item  $earpath -Destination $folder -Force -Recurse

#gettingconfig files
$configzip=join-path $TempExtracted -ChildPath "\config-dist.zip"
Copy-Item  $configzip -Destination $folder -Force -Recurse


$folder=join-path $localNewVersionFolder -ChildPath "\prexlib_jar\" 
Copy-Item  Filesystem::"$($TarifVer.FullName)\*" -Destination $folder -Force -Recurse

#preparing Releasenotes
write-host "==================Preparing Release notes===================================="
write-host "Preparing Release notes - MATC"
$MATCSourcePath=$($MIDCVer.FullName)
$notes=Get-ChildItem Filesystem::$MATCSourcePath -Filter "*.docx"-Force
if($notes){
	
	Copy-Item $notes.FullName -Destination $localNewVersionFolder -ErrorAction SilentlyContinue
	$ReleaseNoteName=[string]::Format("MATC_{0}_{1}_{2}_Releasenotes.docx",$Release,$MIDCVer.Name,$newVersion)
	rename-item "$localNewVersionFolder$notes" -NewName $ReleaseNoteName -Force 
}
else {
	Write-Host "INFO: There were no release notes found..."
}
write-host "Preparing Release notes - ITN "
$notes=Get-ChildItem Filesystem::$($MIDCVer.FullName) -Filter "*.pdf"-Force
if($notes){
	
	Copy-Item $MATCSourcePath::$notes.FullName -Destination $localNewVersionFolder -ErrorAction SilentlyContinue
	$ReleaseNoteName=[string]::Format("INT_{0}_{1}_{2}_Releasenotes.pdf",$Release,$MIDCVer.Name,$newVersion)
	rename-item "$localNewVersionFolder$notes" -NewName $ReleaseNoteName -Force 
}
else {
	Write-Host "INFO: There were no release notes found..."
}
write-host "==================Preparing Release notes===================================="


#creating a version file for deployment
$versionfile=Join-Path $localNewVersionFolder -ChildPath "version"
#INT Version is not added since it is not relavent anymore
Add-Content $versionfile -Value $ITNVer
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
$Mparfilepath=(Get-ChildItem Filesystem::$MATCSourcePath -Filter "mpars_*.txt" -Force).FullName
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
$unzipcommand=Expand-Archive -Path $batchzip -DestinationPath $tempbatchextracted -Force
#$unzipcommand=[string]::Format("unzip -oq {0} -d {1}",$batchzip,$tempbatchextracted)
cmd /c $unzipcommand
Start-Sleep -Seconds 5
foreach($Environment in $($Global:CLEVAEnvironments).split(',')){
	$clevenv=getClevaEnvironment -Environment $Environment
	$EnvBatchfolder=[string]::Format("{0}batch\{1}",$localNewVersionFolder,$Environment)
	$parfolder=join-path $EnvBatchfolder -childpath "pars\"
	$shellscripts=[string]::Format("{0}\{1}\batch\shell_script\",$tempbatchextracted,$clevenv)
	$mparfiles=[string]::Format("{0}\{1}\batch\template\",$tempbatchextracted,$clevenv)
	if(Test-Path $shellscripts){
		copy-item "$($mparfiles)\*" -Destination $parfolder
		copy-item "$($shellscripts)\*" -Destination $EnvBatchfolder
	}
	else {
		Write-Host "WARNING : No Batches found for Environment : $clevenv in the source package"
		#Except for PARAM all other envs should have the batches
	}
	Copy-Item $envfile -Destination $EnvBatchfolder
}
write-host "==================Preparing Batch and MPAR Files===================================="

#creating the client 
write-host "==================Extracting the Clients Normal + DEBUG ===================================="
$Clientpath=join-path $localNewVersionFolder -ChildPath "client\"
$Clientdebugpath=join-path $localNewVersionFolder -ChildPath "client_debug\"
$tempclientextracted=join-path $TempExtracted -ChildPath "unzippedClient\"
New-Item $tempclientextracted -ItemType directory -force | out-null
#$midclient=get-childitem (join-path $TempExtracted -ChildPath "updatesite-dev-specifique.zip")

#if the Client zip (debug) does not exist then reject the version
Write-Host "Exracting NORMAL Client"
Copy-Item "$($TempExtracted)\client\*" -Destination $Clientpath -Force -Recurse
Write-Host "Exracting DEBUG Client"
Copy-Item "$($TempExtracted)\client_debug_assurance\*" -Destination $Clientdebugpath -Force -Recurse

#creating the ini File for the client
$versionfile=join-path $Clientpath -ChildPath "version.ini"
Set-Content -Path $versionfile -Value $release -Force
$versionfile=join-path $Clientdebugpath -ChildPath "version.ini"
Set-Content -Path $versionfile -Value $release -Force
write-host "==================Extracting the Clients Normal + DEBUG ===================================="

#Preparing database
write-host "==================Preparing SQL Scripts for Deployment===================================="
Write-Host 	"Checking if SQL Files are to be deployed"
$SQLTemplate=@"
@sql/%SCRIPTNAME%
insert into T_MERC_LOG_PACKAGES (PKG_ID, PKG_TIME, PKG_PACKAGE, PKG_VERSION, PKG_LOG) values (SEQ_T_MERC_LOG_PACKAGES.nextval, sysdate, &CLEVA_ID, &CLEVA_VERSION,'%SCRIPTNAME%');
"@
$midcvertype="NEW"
$sqlfileslocation= Join-Path $localNewVersionFolder -ChildPath "database\cleva\sql"
$sqlsummaryFile=Join-Path $sqlfileslocation -ChildPath "summary.sql"
$summarycontent=Get-Content $sqlsummaryFile
$scriptsfolder=(Get-ChildItem Filesystem::$($MIDCVer.FullName) -Recurse -Filter "Scripts*" | select -First 1 ).FullName
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
$packageVersionFile=Join-Path "$($localNewVersionFolder)\database\cleva" -ChildPath "pkg_version.sql"
$packageVersionFileContent=Get-Content $packageVersionFile
$packageVersionFileContent=$packageVersionFileContent -ireplace "NEWVERSION",$newVersion
$packageVersionFileContent=$packageVersionFileContent -ireplace "ITNVERSION",$ITNVer
$packageVersionFileContent=$packageVersionFileContent -ireplace "MIDCVERSION",$MIDCVer.Name
$packageVersionFileContent=$packageVersionFileContent -ireplace "TARIFFVERSION",$TarifVer.Name
$packageVersionFileContent=$packageVersionFileContent -ireplace "PARAMETERSCRIPTVERSION",$paramScriptVer.Name
Set-Content $packageVersionFile -Value $packageVersionFileContent -Force

Write-Host 	"Zipping the SQL Package..."
$ClevaDBpackageFolder=Join-Path $localNewVersionFolder -ChildPath "database\cleva\"
$tempsqlextracted=join-path $TempExtracted -ChildPath "SQLPackage"
New-Item $tempsqlextracted -ItemType directory -force | out-null
Copy-Item "$($ClevaDBpackageFolder)\*" -Destination $tempsqlextracted -Force -Recurse
$desitnationzipfullPath=[String]::Format("{0}\CLEVA_{1}.zip",$tempsqlextracted,$newVersion)
Compress-Archive "$tempsqlextracted\*" -DestinationPath $desitnationzipfullPath -Force
Start-Sleep -Seconds 3
Copy-Item $desitnationzipfullPath -Destination $ClevaDBpackageFolder -ErrorAction Stop


#copying the Parameter Scripts
$dbfolder=Join-Path $localNewVersionFolder -ChildPath "database\cleva\"
Copy-Item  "$($paramScriptVer.FullName)\$($paramScriptVer.Name).zip" -Destination $dbfolder -Force -Recurse
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


