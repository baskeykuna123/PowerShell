Param($hostInstances)
CLS

$GetHostInstances = Get-WmiObject MSBTS_HostInstance -Namespace 'root/MicrosoftBizTalkServer' 
$GetHostInstances| %{`
    ForEach($instance in $hostInstances.split(",")){
        if($($_.HostName) -ieq $instance){
			Write-Host "==========================================="
            Write-Host "Host Name:"$_.HostName
			Write-Host `n
			
			Switch($_.ServiceState){
				4 {$HostState="Running"}
				1 {$HostState="Stopped"}
			}
			
            Write-Host "Host State:"$HostState
            Write-Host "Stopping host.."
            $_.invokeMethod("Stop",$null) | Out-Null
            Write-Host "$($_.HostName) status: stopped"
			
            Write-Host "Starting host.."
            $_.invokeMethod("Start",$null) | Out-Null
            Write-Host "$($_.HostName) status: Running"
			Write-Host "==========================================="
			
        }
    }
}