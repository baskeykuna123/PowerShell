Clear-Host 


if(!$Release){
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

$DBuserid=get-Credentials -Environment $Environment -ParameterName  "DataBaseDeploymentUser"
$DBpassword=get-Credentials -Environment $Environment -ParameterName  "DataBaseDeploymentUserPassword"

$DBuserid="builduser"
$DBpassword="Wetzel01"
$dbserver="sql-bep1-ps1202\ps1202,30252"
$dbName="BaloiseReleaseVersions"


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
$select=Invoke-Sqlcmd -Query $selectQuery -ServerInstance $dbserver -Database $dbName -Username $DBuserid -Password $DBpassword -ErrorVariable $out
if($select -ne $null){
	Write-Host "`r`n$($ITNfolder) and $($MIDCVer) are already used.. New Version cannot be created for a existing pacakge "
}

$Release=$Release.Replace("R","")
#creating the new version based on the input
$exeproccmd="EXEC CreateNewBuildVersion @Application='$ApplicationName',@position='$pos',@Release='$Release',@Branch='$Branch'"
$newVersion=Invoke-Sqlcmd -Query $exeproccmd -ServerInstance $dbserver -Database $dbName -Username $DBuserid -Password $DBpassword -ErrorVariable $out
$newVersion=$newVersion.NEWVersion


#Parameter to check if a new MIDC Version is delivered
$selectQuery="Select top 1 MIDC_Version from CLEVAVersions where [MIDC_Version]='$MIDCVer'"
$select=Invoke-Sqlcmd -Query $selectQuery -ServerInstance $dbserver -Database $dbName -Username $DBuserid -Password $DBpassword -ErrorVariable $out
$midcvertype="NEW"
if($select.MIDC_Version -ne $null ){
	$midcvertype="REPEAT"
}

#Parameter to check if a new ITN Version is delivered
$selectQuery="Select top 1 ITN_Version from CLEVAVersions where [ITN_Version]='$ITNfolder'"
$select=Invoke-Sqlcmd -Query $selectQuery -ServerInstance $dbserver -Database $dbName -Username $DBuserid -Password $DBpassword -ErrorVariable $out
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

#inserting the pacakge valeues into the database
$insertQuery=[string]::Format("INSERT INTO [dbo].[CLEVAVersions] VALUES ('{0}','{1}','{2}','{3}','{4}','{5}','{6}','{7}',getdate(),'{8}')",$newVersion,$MIDCVer,$midcvertype,$ITNfolder,$itnvertype,$TarifVer,$paramScriptVer,$paramVer,$Release)
$update=Invoke-Sqlcmd -Query $insertQuery -ServerInstance $dbserver -Database $dbName -Username $DBuserid -Password $DBpassword -ErrorVariable $out

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

if($ActionType -ieq "Emergency"){
	$PatchPropertiesFilePath=[string]::Format("{0}Patch_ClevaDeploy.properties",$Global:JenkinsPropertiesRootPath)
	$PatchProperties=GetProperties -FilePath $PatchPropertiesFilePath
	$PatchProperties["Version"]=$newVersion
	$PatchProperties["ParamImportExport"]=$ParamImport
	setProperties -FilePath $PatchPropertiesFilePath -Properties $PatchProperties
}else{
	$NewVersionPropertiesFilePath=[string]::Format("{0}NewVersion_ClevaDeploy.properties",$Global:JenkinsPropertiesRootPath)
	$NewVersionProperties=GetProperties -FilePath $NewVersionPropertiesFilePath
	$NewVersionProperties["Version"]=$newVersion
	$NewVersionProperties["ParamImportExport"]=$ParamImport
	setProperties -FilePath $NewVersionPropertiesFilePath -Properties $NewVersionProperties
}