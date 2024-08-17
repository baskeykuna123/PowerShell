Param($Release)

if(!$Release){
	 $Release="99"
}

clear
#Importing SQL modules for SQL commands to the Version database
Import-Module sqlps -DisableNameChecking

if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	

$PreviousRelease="R"+(([int]$Release.Replace("R",""))-1).Tostring()
$nextRelease="R"+(([int]$Release.Replace("R",""))+1).Tostring()
$Release="R"+ $Release
$selectQuery="Select InjectR_VERSION from InjectRVersions where Release_ID in ('$PreviousRelease','$Release','$nextRelease') order by CreatedDate"
Write-Host $selectQuery
$select=Invoke-Sqlcmd -Query $selectQuery -ServerInstance $Global:BaloiseBIDBserver -Database $Global:BaloiseReleaseVersionDB -Username $Global:BaloiseVersionDBuserid -Password $Global:BaloiseVersionDBuserpassword -ErrorVariable $out
$versionlist=(($select.InjectR_VERSION) -join ",").trim(',')
$BIproperties=getproperties -FilePath $Global:JenkinsBIPropertiesFile
$BIproperties["InjectRCurrentReleaseVersions"]=$versionlist
setproperties -FilePath $Global:JenkinsBIPropertiesFile -properties $BIproperties
Write-Host "New Version added in the adhoc list successfully"