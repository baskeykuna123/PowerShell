Param($Release,$ApplicationName)

if(!$Release){
	 $Release="31"
	 $ApplicationName="ClevaV14"
}

clear
#Importing SQL modules for SQL commands to the Version database
Import-Module sqlps -DisableNameChecking

if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	
$StoredProc="EXEC [GetBuildVersionsforPatch] @Applicationname='$ApplicationName',@Release=$Release"
$Versionlist=ExecuteSQLonBIVersionDatabase -SqlStatement $StoredProc

$versionlist=(($Versionlist.version) -join ",").trim(',')
$BIproperties=getproperties -FilePath $Global:JenkinsBIPropertiesFile
$BIproperties[$ApplicationName+"CurrentReleaseVersions"]=$versionlist
setproperties -FilePath $Global:JenkinsBIPropertiesFile -properties $BIproperties
Write-Host "New Version added in the adhoc list successfully"