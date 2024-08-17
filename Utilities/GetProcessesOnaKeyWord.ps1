PARAM($SearchString)
clear

if(!$SearchString){
	Write-host "Search String Path required"
	Exit 0
}

	$processes=""
	$openProcesses=@()
	$processes = Get-WmiObject Win32_Process

	foreach($proc in $processes){
			
		if($proc.commandLine -ilike "*$SearchString*"){
			
			$openProcesses+=$proc
			
		}
			 
	}
	if($openProcesses){
		Write-Host "The following processes are open on the ESB Deployment folder were Killed"
		$openProcesses| foreach {
		write-host "============================================================================"
		Write-Host "Name : " $_.Name
		Write-Host "Name : " $_.CommandLine,
		Write-Host "Name : " @{Label="User"; Expression={$_.GetOwner().user}},
		Write-Host "Name : " $_.Handle
		write-host "============================================================================"
		$openProcesses | foreach {
			#Stop-Process -id ([int]$($_.Handle)) -Verbose -Force
		}
	}
	else{
		write-host "There are no running processes on the this folder : " $FolderPath	
	}
