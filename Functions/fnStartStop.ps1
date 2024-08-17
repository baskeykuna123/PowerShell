$ScriptDirectory=split-path $MyInvocation.MyCommand.Definition -Parent
."$ScriptDirectory\fnSetGlobalParameters.ps1"

Function RemoteWindowsServiceStartStop
{
PARAM($serviceName,$Server="localhost",$Action="Start")
	try
	{
	
		$RetryCount=3
		$status="Stopped"
		
		$service= Get-Service -ComputerName $Server | Where-Object {($_.DisplayName -ilike "*$serviceName*") -or ($_.Name -ilike "*$serviceName*") }
		if($service -ne $null){
			
			do {
				
					if($Action -ieq "start"){
						$service.Start()
						$status="Running"}
					else{
						$service.Stop()
						$status="Stopped"
						}
					
					sleep -Seconds $($Global:ApplicationStartStopPollingSeconds)
					if(($service.Status) -ieq $status){
						Write-Host "$($service) Status  : $($service.Status)"
						return
				}
				    $RetryCount--
				}until($RetryCount -gt 0)
					
		 	Write-Host "Service Start Action timed out after 3 attempts"

		}
		else{
			Write-Host "Service with name '$($ser)' was not found."
		}
	}
	Catch
		{
			$_.Exception.Message
			throw $_
		}
}


Function GetRemoteWindowsServiceStatus
{
PARAM($serviceName,$Server="localhost")
	try
	{
	
		$service= Get-Service -ComputerName $Server | Where-Object {($_.DisplayName -ilike "*$serviceName*") -or ($_.Name -ilike "*$serviceName*") }
		if($service -ne $null){
		return $service
		}
	}
	Catch
		{
			$_.Exception.Message
			throw $_
		}
}


Function GetWindowsServiceStatus {
PARAM($serviceName)
	try
	{
	
		$service= Get-Service | Where-Object {($_.DisplayName -ilike "*$serviceName*") -or ($_.Name -ilike "*$serviceName*") }
		if($service -ne $null){
		return $service
		}
		else {
			Write-Host "Service Not found"
			Exit 1
		}
	}
	Catch
		{
			$_.Exception.Message
			throw $_
		}
}

Function Start-WindowsService
{
PARAM([string]$serviceName)
	try{
		$service= Get-Service | Where-Object {($_.DisplayName -ilike "*$serviceName*") -or ($_.Name -ilike "*$serviceName*") }
		if($service -eq $null){
			 "Service with name '$($ser)' was not found."
			Exit 1
		}
		$sw = [diagnostics.stopwatch]::StartNew()
		While($sw.elapsed -lt $Global:ApplicationStartStopTimeOutMinutes) {
			if(($service.Status) -ieq "Running"){
				 "===================================================================="
				 "Windows Service :- $($service.Name) Status  : $($service.Status)"
				 "===================================================================="
				Start-Sleep -Seconds $($Global:ApplicationStartStopPollingSeconds)
				return
			}
			Start-Service $service 
			Start-Sleep -Seconds $($Global:ApplicationStartStopPollingSeconds)
		}
		throw "Service startup failed after $($Global:ApplicationStartStopTimeOutMinutes) minutes."
		return
	}
	Catch
		{
			$_.Exception.Message
			throw $_
		}
}

Function Stop-WindowsService
{
PARAM([string]$serviceName)
	try{
		$service= Get-Service | Where-Object {($_.DisplayName -ilike "*$serviceName*") -or ($_.Name -ilike "*$serviceName*") }
		if($service -eq $null){
			"Service with name '$($ser)' was not found."
			Exit 1
		}
		$sw = [diagnostics.stopwatch]::StartNew()
		While($sw.elapsed -lt $Global:ApplicationStartStopTimeOutMinutes) {
				
				if(($service.Status) -ieq "Stopped"){
					"===================================================================="
					"Windows Service :- $($service.Name) Status  : $($service.Status)"
					"===================================================================="
					Return
				}
				Stop-Service $service -Force 
				Start-Sleep -Seconds $($Global:ApplicationStartStopPollingSeconds)
			}
		THROW "Stop Service failed after $($Global:ApplicationStartStopTimeOutMinutes) minutes."
		Return		
	}
	Catch
		{
			$_.Exception.Message
			throw $_
		}
}

Function Start-AppPool(){
PARAM($AppPoolName)
try{
		Import-Module WebAdministration
		Start-WebAppPool -Name $AppPoolName -ErrorAction SilentlyContinue
		Start-Sleep -Seconds $($Global:ApplicationStartStopPollingSeconds) -ErrorAction SilentlyContinue
		$AppPoolStatus=Get-AppPoolState $AppPoolName
		$sw = [diagnostics.stopwatch]::StartNew()
		While($sw.elapsed -lt $Global:ApplicationStartStopTimeOutMinutes) {
			Write-Host "===================================================================="
			Write-Host "IIS Application Pool :- $AppPoolName Status  : $($AppPoolStatus)"
			Write-Host "===================================================================="
			if($AppPoolStatus -ieq "Started"){
			return
			}
			Start-WebAppPool -Name $AppPoolName
			Start-Sleep -Seconds $($Global:ApplicationStartStopPolling) -ErrorAction SilentlyContinue
		}
		Write-Host "App pool Start Action Timed out"
	}
	Catch
		{
			$_.Exception.Message
			throw $_
		}
}

Function Stop-AppPool(){
PARAM($AppPoolName)
try{
		Import-Module WebAdministration
		Stop-WebAppPool -Name $AppPoolName -ErrorAction SilentlyContinue
		Start-Sleep -Seconds $($Global:ApplicationStartStopPollingSeconds) -ErrorAction SilentlyContinue
		$AppPoolStatus= Get-AppPoolState $AppPoolName
		$sw = [diagnostics.stopwatch]::StartNew()
		While($sw.elapsed -lt $Global:ApplicationStartStopTimeOutMinutes) {
			Write-Host "===================================================================="
			Write-Host "IIS Application Pool :- $AppPoolName Status  : $($AppPoolStatus)"
			Write-Host "===================================================================="
			if($AppPoolStatus -ieq "Stopped"){
			return
			}
			Start-Sleep -Seconds $($Global:ApplicationStartStopPollingSeconds) -ErrorAction SilentlyContinue
			Stop-WebAppPool -Name $AppPoolName
		}
		Write-Host "App pool Stop Action Timed out"
	}
	Catch
		{
			$_.Exception.Message
			throw $_
		}
}

Function Get-AppPoolState()
{
	PARAM($AppPoolName)
	
	if((Get-WebAppPoolState $AppPoolName )-ne $null){
		$AppPoolStatus=(Get-WebAppPoolState $AppPoolName).Value
		return $AppPoolStatus
	}
	else{
		Write-Host "$AppPoolName Not found.. "
		Exit 1
	}
}