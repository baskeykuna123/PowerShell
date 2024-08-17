PARAM(
	[string]$version
	)

Clear-Host 


if(!$Release){
	$version="0.0.1"
}
	  
#Importing SQL modules for SQL commands to the Version database
Import-Module sqlps -DisableNameChecking
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}

$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	



#Source paths on MIDC  SFTP
$sourcefolder="/sas_d/"
$downloadfolder="\\balgroupit.com\appl_data\BBE\Packages\SAS\$version"
New-Item -Force $downloadfolder -ItemType directory 
$Newdownload=DownlodSASFiles -Destination $downloadfolder -source $sourcefolder -Type "SASDeployment" 
