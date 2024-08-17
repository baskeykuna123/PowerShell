Param(
[String]$TaskName,
[String]$Env
)
CLS

# check and delete task if exists
$Task=Get-ScheduledTask -TaskName $TaskName -TaskPath "\" -ErrorAction SilentlyContinue
if($Task){
Write-Host "Unregistering scheduled Task - $TaskName .."
Unregister-ScheduledTask -TaskName $TaskName -TaskPath "\" -Confirm:$false
Write-Host "Task "
}

# Credentials details
Switch($Env){
		"DCORPBIS" { 
			$User="BALGROUPIT\L001094"
			$Pwd="Basler09"
			}
		"ICORP"	{
			$User="BALGROUPIT\L001094"
			$Pwd="Basler09"
			}
		"ACORP"	{
			$User="BALGROUPIT\L001096"
			$Pwd="Basler09"
			}
		"PCORP" {
			$User =""
			$PWD  ="" 
			}
}

If($Env -ine 'DCORP'){
	#Variables
	Write-Host "==================================================="
	Write-Host "Environment:"$Env
	Write-Host "Task name  :"$TaskName
	Write-Host "User ID    :"$User
	Write-Host "==================================================="

	#creating a test task with similar configuration to check if it is working or not
	$action = New-ScheduledTaskAction -Execute "E:\Program Files\Mercator\Esb\Framework\ConsoleApplications\1.0\Mercator.Esb.Framework.Management.BizTalkAutoArtifactStatusHandler.exe" -WorkingDirectory "E:\Program Files\Mercator\Esb\Framework\ConsoleApplications\1.0"
	$settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -IdleDuration (New-Timespan -Minutes 10) -IdleWaitTimeout (New-TimeSpan -Hours 1) -ExecutionTimeLimit (New-TimeSpan -Hours 72) -Priority "7"
	$Principal = New-ScheduledTaskPrincipal -UserId $User -LogonType Interactive -RunLevel Highest
	$Trigger = New-ScheduledTaskTrigger -Daily -At 09:00 
	$Task=Register-ScheduledTask $TaskName -Action $action -Settings $settings -Trigger $Trigger -RunLevel Highest -Force 
	 

	# update Task
	$Task.Triggers.Repetition.Duration="P1D"
	$Task.Triggers.Repetition.Interval="PT2M"
	$Task.Author=$User
    $Task.Principal.UserId=$User
    $Task.Principal.LogonType="Interactive"
	
	#Set Task
	$Task | Set-ScheduledTask -User $User -Password $Pwd | fl
}