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
	$Release="34"
	$CheckSFTP="False"
}
	  
#Importing SQL modules for SQL commands to the Version database
Import-Module sqlps -DisableNameChecking
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}

$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	

#Variables
$Release="R"+$Release
$ApplicationName="Cleva"


Write-Host "========================Input parameters=================================================="
Write-Host "Version type :" $ActionType
Write-Host "Release      :" $Release
Write-Host "Check SFTP   :" $CheckSFTP
Write-Host "========================Input parameters=================================================="

switch ($ActionType) 
      { 
		"Major"		{ 
						$pos=3
					 	$ParamImport="Y"
					}
		"Patch"		{ 
						$pos=4
						$ParamImport="N"
					}
	}

#Variable or paths
$tempMIDCdownload="C:\MATCdownloadfolder\MIDC"
$tempGFIdownload="C:\MATCdownloadfolder\GFI"
$DownloadFolder="\\balgroupit.com\appl_data\bbe\packages\$($ApplicationName)\Downloads\$($Release)\"
#Remove-PSDrive K -Force -ErrorAction SilentlyContinue
#New-PSdrive  -Name K -Root Filesystem::$DownloadFolder -PSProvider "Filesystem" -Persist | Out-Null
$MIDCDownloadFolder=join-path $DownloadFolder -childpath "MATC\"
$ITNDownloadFolder= join-path $DownloadFolder -childpath "GFI\"
$TarifDownloadFolder=join-path $DownloadFolder -childpath "Tariffs\"
$ParamScriptDownloadFolder= join-path $DownloadFolder -childpath "ParameterScripts\"
$PackagePath="\\balgroupit.com\appl_data\bbe\packages\$ApplicationName\Downloads\$Release\MATC"


#Deleting and recreating temp
Remove-Item $tempMIDCdownload -Force -Recurse -ErrorAction SilentlyContinue
New-Item $tempMIDCdownload -ItemType directory -Force | Out-Null
Remove-Item $tempGFIdownload -Force -Recurse -ErrorAction SilentlyContinue
New-Item $tempGFIdownload -ItemType directory -Force | Out-Null


if($CheckSFTP -ieq "true"){
#Source paths on MIDC  SFTP
$MIDCsourcefolder='/in/Releases/'+$Release+'/'
$MIDCarchive='/in/Releases/Archive/'+$Release+'/'
$Newdownload=TestSFTPFiles -Destination $tempMIDCdownload -source $MIDCsourcefolder -Type "MIDC" -Archive $MIDCarchive -PackagePath $PackagePath
	if(!$Newdownload){
		Write-Host "There are are no new versions to download. Aborting new version..."
		Exit 1
	}
Copy-Item -Path $tempMIDCdownload\* -Destination FileSystem::$MIDCDownloadFolder -recurse -force

	#ITN SFTP
	#Source paths on ITN SFTP
#	$ITNsourcefolder='/Baloise/'+$Release+ '/'
#	$ITNarchive='Baloise/Archive/'+$Release+'/'
#	$Newdownload=TestSFTPFiles -Destination $tempGFIdownload -source $ITNsourcefolder -Type "ITN" -Archive $ITNarchive -PackagePath $PackagePath
#	if($Newdownload){
#		Copy-Item -Path $tempGFIdownload\* -Destination FileSystem::$ITNDownloadFolder -recurse -force
#	}
}

function GetLatestFolder($folderpath){
	return Get-ChildItem FileSystem::$folderpath | where {$_.PsIsContainer} | sort LastWriteTime -Descending | Select -First 1
}

	 
#getting the latest versions for new version creation
$MIDCVer=GetLatestFolder $MIDCDownloadFolder
$ITNVernumber=(($MIDCVer.Name).Replace("JBoss_","")).split('-')[0]
#chang request - Check ITN Version based on MATC
$ITNVer=Get-ChildItem FileSystem::$ITNDownloadFolder -Filter "$ITNVernumber" | where {$_.PsIsContainer}| sort LastWriteTime -Descending | Select -First 1
#$ITNVer=GetLatestFolder FileSystem::$ITNDownloadFolder
$TarifVer=GetLatestFolder $TarifDownloadFolder
$paramScriptVer=GetLatestFolder $ParamScriptDownloadFolder

if(!$ITNVer){
	Write-Host "ERROR : ITN version Not found or not requested for Download : $ITNVernumber "
	$LastExitCode=1
	Exit 1
}


$Release=$Release.Replace("R","")
#creating the new version based on the input
$exeproccmd="EXEC CreateNewBuildVersion @Application='$ApplicationName',@position='$pos',@Release='$Release',@Branch='$Branch'"
$newVersion=Invoke-Sqlcmd -Query $exeproccmd -ServerInstance $Global:BaloiseBIDBserver -Database $Global:BaloiseReleaseVersionDB -Username $Global:BaloiseVersionDBuserid -Password $Global:BaloiseVersionDBuserpassword -ErrorVariable $out
$newVersion=$newVersion.NEWVersion


#Parameter to check if a new MIDC Version is delivered
$selectQuery="Select top 1 MIDC_Version from CLEVAVersions where [MIDC_Version]='$MIDCVer'"
$select=Invoke-Sqlcmd -Query $selectQuery -ServerInstance $Global:BaloiseBIDBserver -Database $Global:BaloiseReleaseVersionDB -Username $Global:BaloiseVersionDBuserid -Password $Global:BaloiseVersionDBuserpassword -ErrorVariable $out
$midcvertype="NEW"
if($select.MIDC_Version -ne $null ){
	$midcvertype="REPEAT"
}

#Parameter to check if a new ITN Version is delivered
$selectQuery="Select top 1 ITN_Version from CLEVAVersions where [ITN_Version]='$ITNVer'"
$select=Invoke-Sqlcmd -Query $selectQuery -ServerInstance $Global:BaloiseBIDBserver -Database $Global:BaloiseReleaseVersionDB -Username $Global:BaloiseVersionDBuserid -Password $Global:BaloiseVersionDBuserpassword -ErrorVariable $out
$itnvertype="NEW"
if($select.ITN_Version -ne $null){
	$itnvertype="REPEAT"
}

$Release="R"+$Release
Write-Host "Preparing new version......"
Write-Host "================================================================="
Write-Host "Release              :" $Release
Write-Host "Baloise Version      :" $newVersion
Write-Host "MDIC Version         :" $MIDCVer
Write-Host "MDIC TYPE            :" $midcvertype
Write-Host "ITN  Version         :" $ITNVer
Write-Host "ITN  Type            :" $itnvertype
Write-Host "TARIFF Version       :" $TarifVer
Write-Host "Param Script Version :" $paramScriptVer
Write-Host "Param Version        :" $paramVer
Write-Host "================================================================="

#inserting the pacakge values into the database
$insertQuery=[string]::Format("INSERT INTO [dbo].[CLEVAVersions] VALUES ('{0}','{1}','{2}','{3}','{4}','{5}','{6}','{7}',getdate(),'{8}')",$newVersion,$MIDCVer,$midcvertype,$ITNVer,$itnvertype,$TarifVer,$paramScriptVer,$paramVer,$Release)
$update=Invoke-Sqlcmd -Query $insertQuery -ServerInstance $Global:BaloiseBIDBserver -Database $Global:BaloiseReleaseVersionDB -Username $Global:BaloiseVersionDBuserid -Password $Global:BaloiseVersionDBuserpassword -ErrorVariable $out


#updating new version properties file
$NewVersionPropertiesFilePath=[string]::Format("{0}NewVersion_ClevaDeploy.properties",$Global:JenkinsPropertiesRootPath)
$NewVersionProperties=GetProperties -FilePath $NewVersionPropertiesFilePath
$NewVersionProperties["Version"]=$newVersion
$NewVersionProperties["ParamImportExport"]=$ParamImport
setProperties -FilePath $NewVersionPropertiesFilePath -Properties $NewVersionProperties


$MIDCJBossSourcezip=[string]::Format("{0}\JBoss_{1}.zip",$MIDCVer.FullName,$MIDCVer.Name)
$TempBasedFolder="C:\ClevaTempFolder"
$TempExtracted=join-path $TempBasedFolder -childpath "zips"
$PackageSourceFolder=[string]::Format("{0}\Cleva\sources",$global:NewPackageRoot)

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
$currentReleasefolder=join-path $PackageSourceFolder -ChildPath "$Release\"
#$unzipcommand=Expand-Archive -Path $MIDCJBossSourcezip -DestinationPath $TempExtracted -Force
$unzipcommand=[string]::Format("unzip -oq {0} -d {1}",$MIDCJBossSourcezip,$TempExtracted)
cmd /c $unzipcommand


#preparing the folders
$localNewVersionFolder=join-path $TempBasedFolder -ChildPath "$newVersion\"
New-Item $localNewVersionFolder -itemtype Directory -Force 
Copy-Item $DeploymentTemplatefolder\* -Destination $localNewVersionFolder  -Recurse -Force -ErrorAction Stop


#Phase 1 check if EAR, configok ZIP , batches zip 
#phase 2 if there are not TARIFFs reject

$MIDCJBossSourcezip=[string]::Format("{0}\JBoss_{1}.zip",$MIDCVer.FullName,$MIDCVer.Name)
#$unzipcommand=Expand-Archive -Path $MIDCJBossSourcezip -DestinationPath $TempExtracted -Force
$unzipcommand=[string]::Format("unzip -oq {0} -d {1}",$MIDCJBossSourcezip,$TempExtracted)
cmd /c $unzipcommand
Start-Sleep -Seconds 3

#server - jboss
$folder=join-path $localNewVersionFolder  -childpath "server\"
$earpath=join-path $TempExtracted -ChildPath "\T9-Assurance.ear"
Copy-Item  $earpath -Destination $folder -Force -Recurse

#gettingconfig files
$configzip=join-path $TempExtracted -ChildPath "\config-dist.zip"
Copy-Item  $configzip -Destination $folder -Force -Recurse

#$folder=$localNewVersionFolder+"\webupdate\"
#$UpdateSitepath=join-path $TempExtracted -ChildPath "\updatesite-dev-specifique.zip"
#Copy-Item  $UpdateSitepath -Destination $folder -Force -Recurse

$folder=join-path $localNewVersionFolder -ChildPath "\prexlib_jar\" 
Copy-Item  -path FileSystem::$($TarifVer.FullName)\* -Destination $folder -Force -Recurse

#preparing Releasenotes
write-host "Prearing Release notes.."
$notes=Get-ChildItem FileSystem::$($MIDCVer.FullName) -Filter "*.docx"-Force
if($notes){
	$filepath=$notes.FullName
	Copy-Item Filesystem::$filepath -Destination $localNewVersionFolder -ErrorAction SilentlyContinue
	$ReleaseNoteName=[string]::Format("MATC_{0}_{1}_{2}_Releasenotes.docx",$Release,$MIDCVer.Name,$newVersion)
	rename-item "$localNewVersionFolder$notes" -NewName $ReleaseNoteName -Force 
}
else {
	Write-Host "INFO: There were no release notes found..."
}

$notes=Get-ChildItem FileSystem::$($ITNVer.FullName) -Filter "*.pdf"
if($itnvertype  -ieq "NEW"){
	$filepath=$notes.FullName
	Copy-Item Filesystem::$filepath -Destination $localNewVersionFolder -ErrorAction SilentlyContinue
	$ReleaseNoteName=[string]::Format("ITN_{0}_{1}_{2}_Releasenotes.pdf",$Release,$ITNVer.Name,$newVersion)
	rename-item "$localNewVersionFolder$notes" -NewName $ReleaseNoteName -Force 
}
else{
	Write-Host "INFO : There is no new ITN Version ,Hence no new ITN Release notes"
}


#creating a version file for deployment
$versionfile=Join-Path $localNewVersionFolder -ChildPath "version"
Add-Content $versionfile -Value $ITNVer.Name
Add-Content $versionfile -Value $newVersion


Write-Host "Preparing Batch and MPAR Files ......"
$batchfolder=[string]::Format("{0}\batch",$localNewVersionFolder)
$envfile=[string]::Format("{0}\batch\EnvironmentVariable.sh",$localNewVersionFolder)
$envfile=join-path $batchfolder -ChildPath "\EnvironmentVariable.sh"
$envfilcontents=Get-Content $envfile
$envfilcontents=$envfilcontents.replace("%NEWVERSION%","$newVersion")
Set-Content $envfile -Value $envfilcontents

#Extracting batch zip 
#checking for batch file list 
$Mparfilepath=(Get-ChildItem FileSystem::$($MIDCVer.FullName) -Filter "mpars_*.txt" -Force).FullName
if($Mparfilepath){
	Write-Host "INFO : New Param list file : " $Mparfilepath
	Copy-Item Filesystem::$Mparfilepath -Destination $localNewVersionFolder -Force 
}
else{
	 Write-host "WARNING: There are no Mpar file list for this version "
}

$batchzip=join-path $TempExtracted -ChildPath "config-batch.zip"
$tempbatchextracted=join-path $TempExtracted -ChildPath "batches"
New-Item $tempbatchextracted -ItemType directory -force | out-null
#$unzipcommand=Expand-Archive -Path $batchzip -DestinationPath $tempbatchextracted -Force
$unzipcommand=[string]::Format("unzip -oq {0} -d {1}",$batchzip,$tempbatchextracted)
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

#creating the client 
Write-Host "Extracting the Clients Normal + DEBUG ...."
$Clientpath=join-path $localNewVersionFolder -ChildPath "client\"
$Clientdebugpath=join-path $localNewVersionFolder -ChildPath "client_debug\"
$tempclientextracted=join-path $TempExtracted -ChildPath "unzippedClient\"
New-Item $tempclientextracted -ItemType directory -force | out-null
#preparing the sources for Clients
$ITNClient=(get-childitem -Path "FileSystem::$($ITNVer.FullName)\client" -Filter "*.zip"| select -First 1 ).FullName
$ITNdebugClient=(get-childitem -Path "FileSystem::$($ITNVer.FullName)\client_debug_assurance" -Filter "*.zip"| select -First 1 ).FullName
$midclient=join-path $TempExtracted -ChildPath "updatesite-dev-specifique.zip"

#if the Client zip (debug) does not exist then reject the version

#unziping the core files for the client
#Expand-Archive -Path $ITNClient -DestinationPath $tempclientextracted -Force
cmd /c "unzip.exe -oq $ITNClient -d $tempclientextracted"
Start-Sleep -Seconds 5
#Expand-Archive -Path $midclient -DestinationPath $tempclientextracted -Force
cmd /c "unzip.exe -oq $midclient -d $tempclientextracted"
Start-Sleep -Seconds 5
Copy-Item "$($tempclientextracted)\*" -Destination $Clientpath -Force -Recurse
remove-item	 "$($tempclientextracted)\*" -Recurse -Force
#Expand-Archive -Path $ITNdebugClient -DestinationPath $tempclientextracted -Force
cmd /c "unzip.exe -oq $ITNdebugClient -d $tempclientextracted"
Start-Sleep -Seconds 5
#Expand-Archive -Path $midclient -DestinationPath $tempclientextracted -Force
cmd /c "unzip.exe -oq $midclient -d $tempclientextracted"
Start-Sleep -Seconds 5
Copy-Item "$($tempclientextracted)\*" -Destination $Clientdebugpath -Force -Recurse

#creating the ini File for the client
$versionfile=join-path $Clientpath -ChildPath "version.ini"
Set-Content -Path $versionfile -Value $release -Force
$versionfile=join-path $Clientdebugpath -ChildPath "version.ini"
Set-Content -Path $versionfile -Value $release -Force


#Preparing database
Write-Host 	"Checking if SQL Files are to be deployed"
$SQLTemplate=@"
@sql/%SCRIPTNAME%
insert into T_MERC_LOG_PACKAGES (PKG_ID, PKG_TIME, PKG_PACKAGE, PKG_VERSION, PKG_LOG) values (SEQ_T_MERC_LOG_PACKAGES.nextval, sysdate, &CLEVA_ID, &CLEVA_VERSION,'%SCRIPTNAME%');
"@
$sqlfileslocation= Join-Path $localNewVersionFolder -ChildPath "database\cleva\sql"
$sqlsummaryFile=Join-Path $sqlfileslocation -ChildPath "summary.sql"
$summarycontent=Get-Content $sqlsummaryFile
$scriptsfolder=(Get-ChildItem FileSystem::$($MIDCVer.FullName) -Recurse -Filter "Scripts*" | select -First 1 ).FullName
$scriptlist=""
if($scriptsfolder){
	Write-Host "SQL Scripts Found.. Creating SQL package..."
	if((test-path FileSystem::$scriptsfolder) -and $midcvertype -ieq "NEW"){
			Get-ChildItem FileSystem::$scriptsfolder -Recurse -Filter "*.sql" | sort | foreach{
			$fileName=$_
			Write-Host "Preparing File : "  $fileName.Name
			copy Filesystem::$($fileName.FullName) -Destination $sqlfileslocation
			$Script=$SQLTemplate -ireplace "%SCRIPTNAME%",$fileName.Name
			$scriptlist+="`r`n" + $Script
		}
	}
}
else{
	Write-Host 	"NOTE: There are no DB Scripts in this package"
}
$summarycontent=$summarycontent -ireplace "--SCRIPTLIST",$scriptlist
Set-Content $sqlsummaryFile -Value $summarycontent -Force

#setting the PackageVersion File
$packageVersionFile=Join-Path "$($localNewVersionFolder)\database\cleva" -ChildPath "pkg_version.sql"
$packageVersionFileContent=Get-Content FileSystem::$packageVersionFile
$packageVersionFileContent=$packageVersionFileContent -ireplace "NEWVERSION",$newVersion
$packageVersionFileContent=$packageVersionFileContent -ireplace "ITNVERSION",$ITNVer.Name
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
#Compress-Archive "$tempsqlextracted\*" -DestinationPath $desitnationzipfullPath -Force
$zipfilename=[String]::Format("CLEVA_{0}.zip",$newVersion)
Set-Location $tempsqlextracted
cmd /c "zip -rq $zipfilename *"
Start-Sleep -Seconds 3
Copy-Item $desitnationzipfullPath -Destination $ClevaDBpackageFolder -ErrorAction Stop
# if there are sql scirpts, if the zip is not created correctly then reject the version

#copying the Parameter Scripts
$dbfolder=Join-Path $localNewVersionFolder -ChildPath "database\cleva\"
Copy-Item  "$($paramScriptVer.FullName)\$($paramScriptVer.Name).zip" -Destination $dbfolder -Force -Recurse
#moving the Newly created Package to the share 
Write-host "Uploading the new verison $newVersion to the Package Share"
copy-item $localNewVersionFolder -destination $currentReleasefolder -Force -Recurse


#cleanup
Write-Host "Cleaning up Temp directory used for creating the new version"
Set-Location "c:\"
cmd.exe /c "rd /s /q $TempBasedFolder"
Remove-PSDrive R -Force 
Remove-PSDrive R -Force -ErrorAction SilentlyContinue


