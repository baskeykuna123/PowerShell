
Param(
	[string]$ApplicationName
)

Clear

#default parameters for script Testing
if(!$buildnumber){
	$ApplicationName="Biversity"
}

#Loading All modules
#Loading All modules
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions -Force
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	

$BuildSource=join-path $global:PackageRoot -ChildPath "DEV_Biversity"

Stop-AppPool -AppPoolName $ApplicationName
Remove-Item "E:\Baloise\WebApplication\Biversity\*.*" -Recurse -Force
Copy-Item  "$($BuildSource)\*" -Destination "E:\Baloise\WebApplication\Biversity" -Force -Recurse
Start-AppPool -AppPoolName $ApplicationName
