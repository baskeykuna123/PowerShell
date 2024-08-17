PARAM
	(
		[string]$StreamName,
		[string]$curdate
	)

#Default Parametes
 if(!$StreamName)
 {
	$StreamName="D-BE-DCL90"
 }
 
 
 #Default date is always today
 if(!$curdate){
 	$curdate=get-date -format "yyyy-MM-dd"
 }
$curdate
#Importing SQL modules for SQL commands to the Version database
Import-Module sqlps -DisableNameChecking

#echo "C:\Program Files\Arvato Systems\StreamworksAgent\bin`tools_3.1.36\StreamworksAgentCLI.exe" --env int --mand "%MAND%" --cliuser "%CLIuser%" --clicmd %Command%

Function GetStreamInfo(){
PARAM($CurrentStream)
	
	$selectQuery=[string]::Format("select ActualStartDateTime,streamrunjobid,JobName,JobReturnCode,JobReturnMessage,ExecutionNo,JobStatusCd from StreamRunJob where StreamRunId={0} order by StreamRunJobId",$($CurrentStream.StreamRunid))
	$streamJobinfo=Invoke-Sqlcmd -Query $selectQuery -ServerInstance $dbserver -Database $dbName
	write-host "JOB NAME `t EXECUTIONNUMBER `t JOBSTART DATETIME `t JOBEND DATETIME `t STATUS `t STATUS MESSAGE"
	foreach($info in $streamJobinfo){
		switch($($info.JobStatusCd)){
			5   {
				$startdate=[datetime]$($info.ActualStartDateTime) + $ts
				$enddate=[datetime]$($info.ActualStartDateTime) + $ts
				$status="Running"
				}
			3   {
				$startdate=""
				$enddate=""
				$status="pending"
				}	
			6   {
				$startdate=[datetime]$($info.ActualStartDateTime) + $ts
				$enddate=[datetime]$($info.ActualStartDateTime) + $ts
				$status="Completed"
				}
			10  {
				$startdate=[datetime]$($info.ActualStartDateTime) + $ts
				$enddate=[datetime]$($info.ActualStartDateTime) + $ts
				$status="Bypassed"
				}
			1   {
				$startdate=""
				$enddate=""
				$status="Not Started"
				}
				
		default {
				Write-Host "$($info.JobName) is in the Status code :$($info.JobStatusCd)... Status code not handled" 
				continue
				}
		}
		write-host "$($info.JobName) `t $($info.ExecutionNo) `t $startdate `t $($enddate) `t $($status) `t $($info.JobReturnMessage) "
	}
			
}

Function TriggerNewDeployment(){
PARAM($streamName)

#path where the StreamworksCLI is located
$StreamCLIExePath="C:\Program Files\Arvato Systems\StreamworksAgent\bin\tools_3.1.36\"
Set-Location $StreamCLIExePath
if($streamName -ilike "P-*"){
	$env="prd"
}
else{
	$env="int"
}
	Write-Host "SCHEDULING:Scheduling Stream -$streamName"
	$command=[string]::Format('StreamworksAgentCLI.exe --env {1} --mand "I200" --cliuser "L002618" --clicmd "func=SCHED strname={2} pdate=CURDATE action=A"',$StreamCLIExePath,$env,$streamName)
 	cmd /c $command
	Write-Host "EXECUTING:Executing Stream -$streamName"
	$command=[string]::Format('StreamworksAgentCLI.exe --env {1} --mand "I200" --cliuser "L002618" --clicmd "func=PREP strname={2} pdate=CURDATE runno=S inp= "',$StreamCLIExePath,$env,$streamName)
	cmd /c $command
}

Clear-Host
$DBuserid="balgroupit\L002618"
$DBpassword="LoktJen8"
$dbserver="sql-ie1-ag11l.balgroupit.com"
$dbName="StreamWorksI"
$pollingtime=60
#$curdate=(get-date -format "yyyy-MM-dd")
$nextRun=$false
$timeout = new-timespan -Hours 2
$ts = New-TimeSpan -Hours 1
Write-Host "Stream : $StreamName"
#$selectQuery=[string]::Format("select streamrunid,StreamName,RunNumber,ActualStartDateTime,ActualEndDateTime,StatusCd,StreamRunInterval,datediff(MINUTE,ActualStartDateTime,ActualEndDateTime) as duration from streamrun where StreamName = '{0}' and  cast(PlanDate as date)='{1}' order by RunNumber",$streamname,$curdate,$minduration)
$selectQuery=[string]::Format("select *,datediff(MINUTE,ActualStartDateTime,ActualEndDateTime) as duration from streamrun where StreamName = '{0}' and  cast(PlanDate as date)='{1}' order by RunNumber",$streamname,$curdate,$minduration)
$streamlist=Invoke-Sqlcmd -Query $selectQuery -ServerInstance $dbserver -Database $dbName
Write-Host "========================================================================"
	foreach($stream in $streamlist){
		$sw = [diagnostics.stopwatch]::StartNew()
		$statuscode=$stream.StatusCd
		do{
		$selectQuery=[string]::Format("select *,datediff(MINUTE,ActualStartDateTime,ActualEndDateTime) as duration from streamrun where StreamRunId = '{0}' order by RunNumber",$stream.StreamRunid)
		$stream=Invoke-Sqlcmd -Query $selectQuery -ServerInstance $dbserver -Database $dbName
		switch($($stream.StatusCd)){
			5   {
					Write-host 'RunNumber	    :' $stream.RunNumber
					write-host "Start DateTime	:" ([datetime]$($stream.ActualStartDateTime) + $ts)
					write-host "Status	        : Running" 
					GetStreamInfo -CurrentStream $stream
					Start-sleep -Seconds $pollingtime
					
				}
			6   {
					Write-host 'RunNumber	    :' $stream.RunNumber
					write-host "Start DateTime	:" ([datetime]$($stream.ActualStartDateTime) + $ts)
					write-host "End DateTime	:" ([datetime]$($stream.ActualEndDateTime) + $ts)
					write-host "Status	        : Completed" 
					GetStreamInfo -CurrentStream $stream			
					Write-Host "COMPLETED: Stream $CurrentStream execution Completed...."
				}
			1   {
					Write-host 'RunNumber	                :' $stream.RunNumber
					Write-host 'Planned StartDatetime	    :' $stream.PlannedStartDateTime
					Write-Host "PREPARED:Stream  $CurrentStream is prepared.. A Execution will be triggered..."
					TriggerNewDeployment $StreamName
					Start-sleep -Seconds $pollingtime
				}
			3   {
					Write-host 'RunNumber	    :' $stream.RunNumber
					Write-Host "PREPARED:Stream  $CurrentStream is on hold.. A Execution will be triggered..."
					#TriggerNewDeployment $StreamName
					Start-sleep -Seconds $pollingtime
				}
      default   {
					write-host "UNKNOWN: Stream Status code $($stream.StatusCd) not handled" 
					Exit 1
				}
	}
	}while (($sw.elapsed -lt $timeout)-and ($stream.StatusCd -ne 6))
		Write-Host "========================================================================"
	}



