Param($Environment,$Action)


#loading Utilities 
#. "FileSystem::\\balgroupit.com\appl_data\BBE\Transfer\Packages\Scripts\fnStartStop.ps1"

#loading Functions
if(Get-Module -Name LoadFunctions){
	Remove-Module LoadFunctions -Force
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop

Clear-Host
if(!$Environment){
	$Environment="ICORP"
	$Action="Start"
}

#Variables
$ErrorActionPreference='Stop'
$RemoteServices=@()


Switch($Environment){ 
  			"ICORP" {$UserName="balgroupit\L001136" 
           			 $tempUserPassword ="Basler09"
					 $server="SHW-Be-SQLD60.balgroupit.com"
					 $servicename="ClevaOracleCB1I"}
  			"ACORP" {$UserName="balgroupit\L001135" 
  		   			 $tempUserPassword ="h5SweHU8"
					 $server="SHW-Be-SQLi60.balgroupit.com"
					 $servicename="ClevaOracleCB1A"}
		    "PCORP" {$UserName="balgroupit\L001134" 
           			 $tempUserPassword ="9hU5r5druS"
					 $server="SHW-BE-SQLP10.balgroupit.com"
					 $servicename="ClevaOracleCB1P"}
		}


#Displaying Parmeters
Write-Host "==============================Input Parameters=============================="
Write-Host "Service Name     :" $serviceName
Write-Host "Action           :" $Action
Write-Host "Server           :" $server
Write-Host "Environment      :" $Environment
Write-Host "==============================Input Parameters=============================="

if($Action -ieq "Get"){
	$service=GetRemoteWindowsServiceStatus $serviceName $server
	write-host 	"Name	:" $service.Name 
	Write-Host 	"Status	:" $service.Status
	Write-Host 	"`r`n"
}
else{
	$service=GetRemoteWindowsServiceStatus $serviceName $server
	RemoteWindowsServiceStartStop -serviceName $service.Name  -Server $service.MachineName -Action $Action -Environment $Environment
}	
