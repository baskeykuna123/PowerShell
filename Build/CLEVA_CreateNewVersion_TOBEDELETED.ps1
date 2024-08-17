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
	$Release="30"
	$CheckSFTP=$true
}
	  
#Importing SQL modules for SQL commands to the Version database
Import-Module sqlps -DisableNameChecking
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}

$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	

$Release="R"+$Release
$ApplicationName="Cleva"

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

#Source paths on MIDC  SFTP
$sourcefolder='/in/Releases/'+$Release+'/'
$archive='/in/Releases/Archive/'+$Release+'/'
$MIDCDownloadFolder="D:\Accenture\$Release\ACN_Delivery\"
#$Newdownload=DownloadSFTPFiles -Destination $MIDCDownloadFolder -source $sourcefolder -Type "MIDC" -Archive $archive

if($CheckSFTP -ieq "true"){
	if(!$Newdownload){
		Write-Host "There are are no new versions to download. Aborting new version..."
		Exit 1
	}
}

#Source paths on ITN SFTP
$sourcefolder='/Baloise/'+$Release+ '/'
$archive='Baloise/Archive/'+$Release+'/'
$ITNDownloadFolder="D:\Accenture\$Release\ITN_Delivery\"
$Newdownload=DownloadSFTPFiles -Destination $ITNDownloadFolder -source $sourcefolder -Type "ITN" -Archive $archive


function GetLatestFolder($folderpath){
	return Get-ChildItem $folderpath | where {$_.PsIsContainer}| sort LastWriteTime -Descending | Select -First 1
}

	  

#getting the latest versions for new version creation
$MIDCVer=GetLatestFolder $MIDCDownloadFolder
$ITNfolder=GetLatestFolder $ITNDownloadFolder
$TarifVer=GetLatestFolder "D:\Accenture\$Release\Tarif_Delivery\"
$paramScriptVer=GetLatestFolder  "D:\Accenture\$Release\ParamScript_Delivery\"

if($MIDCVer -inotlike "*$ITNfolder*"){
	Write-Host "Versions $MIDCVer and $ITNfolder do not match. No new version will be created."
	$LastExitCode=1
	Exit 1
}

$selectQuery="Select  * from CLEVAVersions where [MIDC_Version]='$MIDCVer' and [ITN_Version]='$ITNfolder'"
$select=Invoke-Sqlcmd -Query $selectQuery -ServerInstance $Global:BaloiseBIDBserver -Database $Global:BaloiseReleaseVersionDB -Username $Global:BaloiseVersionDBuserid -Password $Global:BaloiseVersionDBuserpassword -ErrorVariable $out
if($select -ne $null){
	Write-Host "`r`n$($ITNfolder) and $($MIDCVer) are already used.. New Version cannot be created for a existing pacakage"
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
$selectQuery="Select top 1 ITN_Version from CLEVAVersions where [ITN_Version]='$ITNfolder'"
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
Write-Host "ITN  Version         :" $ITNfolder
Write-Host "ITN  Type            :" $itnvertype
Write-Host "TARIFF Version       :" $TarifVer
Write-Host "Param Script Version :" $paramScriptVer
Write-Host "Param Version        :" $paramVer
Write-Host "================================================================="

#inserting the pacakge values into the database
$insertQuery=[string]::Format("INSERT INTO [dbo].[CLEVAVersions] VALUES ('{0}','{1}','{2}','{3}','{4}','{5}','{6}','{7}',getdate(),'{8}')",$newVersion,$MIDCVer,$midcvertype,$ITNfolder,$itnvertype,$TarifVer,$paramScriptVer,$paramVer,$Release)
$update=Invoke-Sqlcmd -Query $insertQuery -ServerInstance $Global:BaloiseBIDBserver -Database $Global:BaloiseReleaseVersionDB -Username $Global:BaloiseVersionDBuserid -Password $Global:BaloiseVersionDBuserpassword -ErrorVariable $out

$ttfile="D:\BuildTeam\Templates\Config_Build_Template.txt"
$template=get-content $ttfile
$template=$template -replace "%Release%",$Release
$template=$template -replace "%clevaversion%",$newVersion
$template=$template -replace "%midcversion%",$MIDCVer
$template=$template -replace "%midctype%",$midcvertype
$template=$template -replace "%itnversion%",$ITNfolder
$template=$template -replace "%itntype%",$itnvertype
$template=$template -replace "%tariffversion%",$TarifVer
$template=$template -replace "%paramversion%",""
$template=$template -replace "%paramscriptversion%",$paramScriptVer
Set-Content -Path "D:\Delivery\Deploy\Config_Build.cmd" -Value $template

$NewVersionPropertiesFilePath=[string]::Format("{0}NewVersion_ClevaDeploy.properties",$Global:JenkinsPropertiesRootPath)
$NewVersionProperties=GetProperties -FilePath $NewVersionPropertiesFilePath
$NewVersionProperties["Version"]=$newVersion
$NewVersionProperties["ParamImportExport"]=$ParamImport
setProperties -FilePath $NewVersionPropertiesFilePath -Properties $NewVersionProperties
