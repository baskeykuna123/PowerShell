
Function RemoteWindowsServiceStartStop
{
PARAM($serviceName,$Server="localhost",$Action="Start",$Environment)
		
$UserPassword = ConvertTo-SecureString $tempUserPassword -AsPlainText -force
$Creds = New-Object -TypeName System.management.Automation.PScredential -ArgumentList $UserName, $UserPassword
$status="Stopped"
if($Action -ieq "start" ){
$status="Running"
}
	try
	{
		$polling=5
		$timeout = new-timespan -Minutes 10
		$service= Get-Service -ComputerName $Server | Where-Object {($_.DisplayName -ilike "*$serviceName*") -or ($_.Name -ilike "*$serviceName*") }
		if($service -ne $null){
				$sw = [diagnostics.stopwatch]::StartNew()
				While($sw.elapsed -lt $timeout) {
					Write-Host "$($service.Name) Status  : $($service.Status)"							
					if($service.Status -ieq $status){
						Return
					}
					Start-Sleep -Seconds $polling -Verbose
					switch($Action){
						"Start" {
								$service.Start()
								
								}
						"Stop" {
								
								$service.Stop()		
								}			
					}
				$service.WaitForStatus($status,'00:00:30')
				}
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
	
		$service= Get-Service -ComputerName $Server |  Where-Object {($_.DisplayName -ilike "*$serviceName*") -or ($_.Name -ilike "*$serviceName*") }
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
PARAM($serviceName)
	try{
		$RetryCount=3
		$polling=1
		$service= Get-Service | Where-Object {($_.DisplayName -ilike "*$serviceName*") -or ($_.Name -ilike "*$serviceName*") }
		if($service -ne $null){
			while($RetryCount -gt 0) {
				if(($service.Status) -ieq "Running"){
					Write-Host "$($service.Name) Status  : $($service.Status)"
					Return
				}
				$RetryCount--
				Start-Service $service -Verbose
				Start-Sleep -Seconds $polling 
			}
		 	Write-Host "Service Start Action timed out after 3 attempts"

		}
		else{
			Write-Host "Service with name '$($ser)' was not found."
			Exit 1
		}
	}
	Catch
		{
			$_.Exception.Message
			throw $_
		}
}

Function Stop-WindowsService
{
PARAM($serviceName)
	try{
		$RetryCount=3
		$polling=1
		$service= Get-Service | Where-Object {($_.DisplayName -ilike "*$serviceName*") -or ($_.Name -ilike "*$serviceName*") }
		if($service -ne $null){
			While($RetryCount -gt 0) {
				
				if(($service.Status) -ieq "Stopped"){
					Write-Host "$($service.Name) Status  : $($service.Status)"
					Start-Sleep -Seconds $polling
					Return
				}
				$RetryCount--
				Stop-Service $service -Force -Verbose 
				Start-Sleep -Seconds $polling
			}
		 	Write-Host "Service Start Action timed out after 3 attempts"

		}
		else{
			Write-Host "Service with name '$($ser)' was not found."
			Exit 1
		}
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
		$polling=1
		$timeout = new-timespan -Minutes 10
		Start-WebAppPool -Name $AppPoolName -ErrorAction SilentlyContinue
		$AppPoolStatus=Get-AppPoolState $AppPoolName
		$sw = [diagnostics.stopwatch]::StartNew()
		While($sw.elapsed -lt $timeout) {
			Write-Host "$AppPoolName Status  : $($AppPoolStatus)"
			if($AppPoolStatus -ieq "Started"){
			return
			}
			Start-Sleep -Seconds $polling -ErrorAction SilentlyContinue
			Start-WebAppPool -Name $AppPoolName
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
		$polling=1
		$timeout = new-timespan -Minutes 10
		Stop-WebAppPool -Name $AppPoolName -ErrorAction SilentlyContinue
		$AppPoolStatus=Get-AppPoolState $AppPoolName
		$sw = [diagnostics.stopwatch]::StartNew()
		While($sw.elapsed -lt $timeout) {
			Write-Host "$AppPoolName Status  : $($AppPoolStatus)"
			if($AppPoolStatus -ieq "Stopped"){
			return
			}
			Start-Sleep -Seconds $polling -ErrorAction SilentlyContinue
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