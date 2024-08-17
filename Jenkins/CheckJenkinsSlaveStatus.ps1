Param($ServiceName,$Serverlistfile)

#loading Utilities 
. "FileSystem::\\balgroupit.com\appl_data\BBE\Transfer\Packages\Scripts\fnUtilities.ps1"

Clear-Host
if(!$serverlistfile){
	$serverlistfile="E:\BuildTeam\Input\Servers\DIAPServerList.txt"
	$serviceName="Jenkins"
}

#Variables
$RemoteServices=@()

#Displaying Parmeters
Write-Host "==============================Input Parameters=============================="
Write-Host "Service Name     :" $serviceName
Write-Host "Server List File :" $Serverlistfile
Write-Host "==============================Input Parameters=============================="


#Validating inputs
if(-not (Test-Path FileSystem::$serverlistfile)){
	Write-Host "Server List File not found : $serverlistfile"
	Exit 1
}


foreach($server in [System.IO.File]::ReadAllLines($serverlistfile)){
	$service=GetRemoteWindowsServiceStatus "Jenkins" $server
	if($service.Status -ine "Running") {
		RemoteWindowsServiceStartStop -serviceName $service.Name  -Server $service.MachineName -Action "Start"	
	}
	$RemoteServices +=$service
}

#displaying the services
$RemoteServices |Ft -AutoSize -Property Name,Status,MachineName