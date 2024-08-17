Param($ServiceName,$Action)
CLS

#loading Function
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	

# Stop service 
If($Action -ieq "Stop")
{
	Stop-WindowsService -serviceName $serviceName
}

# Start Service
If($Action -ieq "Start")
{
	Start-WindowsService -serviceName $serviceName
}