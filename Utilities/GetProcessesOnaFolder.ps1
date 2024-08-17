PARAM($FolderPath)
clear
$FolderPath="E:\Program Files\Mercator\Esb\Logs\Install_20210706-095745\Mercator.Esb.Service.Document"
if(!$FolderPath){
	Write-host "Folder Path required"
	Exit 0
}

if(Test-Path $FolderPath){
	$processes=""
	$openProcesses=@()
	$processes = Get-WmiObject Win32_Process

	foreach($proc in $processes){
			
		if($proc.commandLine -ilike "*$FolderPath*"){
			
			$openProcesses+=$proc
			
		}
			 
	}
	if($openProcesses){
		Write-Host "The following processes open on the specified folder were Killed"
		$openProcesses| ft Id,Name,CommandLine,@{Label="User"; Expression={$_.GetOwner().user}},Handle
		$openProcesses | foreach {
			Write-Host `n`n"========================================================"
			Write-Host "Folder Path :"$FolderPath
			Write-Host "Process(PID):"$($_.Handle)
			Write-Host "Process Name:"$($_.ProcessName)
			Write-Host "Command Line:"$($_.CommandLine)
			Write-Host "User        :"$($_.GetOwner().user)
			Write-Host "========================================================"
			Stop-Process -id ([int]$($_.Handle)) -Verbose -Force
		}
	}
	else{
		write-host "There are no running processes on the this folder : " $FolderPath	
	}
}
else {
 Write-Host "FOLDER DOES NOT EXIST : " $FolderPath
}
