Clear

$Server=$env:computername
$SessionInfo = quser /server:$server 2>$null
if(!($SessionInfo)){
	Write-Host "`r`n`r`nThere are NO USER(s) logged on`r`n`r`n"
    Continue
}
[int]$count=$SessionInfo.count-1
While ($count -gt 0){
	$User=($SessionInfo[$count] -split ' +')[1]
	$session=($SessionInfo[$count] -split  ' +')[2]
	$ID=($SessionInfo[$count] -split ' +')[3]

	$state=($SessionInfo[$count] -split ' +')[4]
	$IdleTime=($SessionInfo[$count] -split ' +')[5]
	$LogonTime=($SessionInfo[$count] -split ' +')[6]
	if($session -notlike "*rdp-tcp*"){
		$session='Null'
		$ID=($SessionInfo[$count] -split ' +')[2]
		$state=($SessionInfo[$count] -split ' +')[3]
		$IdleTime=($SessionInfo[$count] -split ' +')[4]
		$LogonTime=($SessionInfo[$count] -split ' +')[5]
	}
	Write-Host "========================================"
	Write-Host "SERVER:"$Server
	Write-Host "========================================"
	Write `n

	Write-Host "`n****************SESSION INFO******************`n"
	Write-Host "USERNAME     :"$User
	Write-Host "SESSION NAME :"$session
	Write-Host "SESSION ID   :"$ID
	Write-Host "SESSION STATE:"$state
	Write-Host "IDLE TIME    :"$IdleTime
	Write-Host "LOGON TIME   :"$LogonTime
	Write-Host "`n************************************************"
	Write `n

	Invoke-RDUserLogoff -HostServer $Server -UnifiedSessionID $ID -Force
	$count--
}


