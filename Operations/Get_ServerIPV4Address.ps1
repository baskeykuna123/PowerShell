Param
(
[String]$ServerNames
)
clear-host
$ServerNames=""
#Loading Functions
if(Get-Module -Name LoadFunctions){
	Remove-Module LoadFunctions -Force
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop

# Get IP Address of Servers
ForEach($Server in $ServerNames.split(",")){
	Write-Host "Getting IPV4 address for Server:"$Server
	Test-Connection -ComputerName "$Server" -Count 1 | Select IPV4Address
	Write-Host "`n"
}