PARAM
	(
		[string]$StreamsType,
		[string]$Environment,
		[string]$maillist,
		[string]$RunDate
	)

#Default Parametes
 if(!$StreamsType)
 {
	$StreamsType="Batch"
	$Environment="ICORP"
	$maillist="Shivaji.pai@baloise.be"
 }
 
 Clear-Host

if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	


 #Default date is always today
 if(!$RunDate){
 	$RunDate=get-date -format "yyyy-MM-dd"
	#$RunDate='2018-01-04'
 }
 
switch($RunDate){
	"Today" {
				$RunDate=get-date -format "yyyy-MM-dd"
			}
		}

#Importing SQL modules for SQL commands to the Version database
Import-Module sqlps -DisableNameChecking


function Convert-UTCtoLocal{
 	param
		(
	[parameter(Mandatory=$true)]
	[String] $UTCTime
		)
	 $strCurrentTimeZone = (Get-WmiObject win32_timezone).StandardName
	 $TZ = [System.TimeZoneInfo]::FindSystemTimeZoneById($strCurrentTimeZone)
	 $LocalTime = [System.TimeZoneInfo]::ConvertTimeFromUtc($UTCTime, $TZ)
	 return $LocalTime.tostring("dd/MM/yyy HH:MM:ss")
}


Function GetStreamInfo(){
PARAM($CurrentStream)
	$jobinfo="<TR><TH>JOB</TH><TH>Execution</TH><TH>StartDateTime</TH><TH>EndDateTime</TH><TH>Status</TH><TH>Return Message</TH></TR>"
	$selectQuery=[string]::Format("select ActualStartDateTime,streamrunjobid,JobName,JobReturnCode,JobReturnMessage,ExecutionNo,JobStatusCd from StreamRunJob where StreamRunId={0} order by StreamRunJobId",$($CurrentStream.StreamRunid))
	$streamJobinfo=Invoke-Sqlcmd -Query $selectQuery -ServerInstance $dbserver -Database $dbName
	
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
		$jobinfo+= [string]::Format("<TR><TD>{0}</TD><TD>{1}</TD><TD>{2}</TD><TD>{3}</TD><TD>{4}</TD><TD>{5}</TD></TR>",$($info.JobName),$($info.ExecutionNo),$($enddate),$startdate,$($status),$($info.JobReturnMessage))
	}
	return $jobinfo
			
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
$temphtmlfile = [string]::Format("\\svw-me-pcleva01\buildteam\temp\{0}_{1}_{2}.htm",$Environment,[datetime]::Now.ToString("dd-MM-yyyy_HHmm"),$StreamsType)
$InputLocation="D:\BuildTeam\InputFiles"
$StreamlistFile=[string]::Format("$InputLocation\{0}_{1}Streams.txt",$Environment,$StreamsType)
$streamlist=[System.IO.File]::ReadAllLines($StreamlistFile)
$MailTemplateFile="D:\BuildTeam\Templates\StreamStatus.html"
$Htmlcontnet=get-content $MailTemplateFile
$DBuserid="balgroupit\L002618"
$DBpassword="LoktJen8"
$dbserver="sql-ie1-ag11l.balgroupit.com"
$dbName="StreamWorksI"
#$RunDate=(get-date -format "yyyy-MM-dd")
$nextRun=$false
$timeout = new-timespan -Hours 2
$ts = New-TimeSpan -Hours 1



foreach($StreamName in $streamlist)
 {
 	
	Write-Host "Stream : $StreamName"
	$selectQuery=[string]::Format("select streamrunid,StreamName,RunNumber,ActualStartDateTime,ActualEndDateTime,StatusCd,StreamRunInterval,datediff(MINUTE,ActualStartDateTime,ActualEndDateTime) as duration from streamrun where StreamName = '{0}' and  cast(PlanDate as date)='{1}' order by RunNumber",$StreamName,$RunDate,$minduration)
	$streamlist=Invoke-Sqlcmd -Query $selectQuery -ServerInstance $dbserver -Database $dbName
	if(!$streamlist){
		$Streaminfo+="<TR><TH colspan='3'>$StreamName</TH><TH colspan='3'>NOT EXECUTED</TH></TR>"
	}
	foreach($stream in $streamlist){
		$Streaminfo+="<TR><TH colspan='2'><B>StreamName</B></TH><TH><B>Run</B></TH><TH><B>StartDate</B></TH><TH><B>EndDate</B></TH><TH><B>Status</B></TH></TR>"
			switch($($stream.StatusCd)){
				5   {
						$streamStart=([datetime]$($stream.ActualStartDateTime) + $ts)
						$streamend=""
						$status="RUNNING" 
						$Streaminfo+= [string]::Format("<TR><TH colspan='2'><B>{0}</B></TH><TH><B>{1}</B></TH><TH><B>{2}</B></TH><TH><B>{3}</B></TH><TH><B>{4}</B></TH></TR>",$($StreamName),$($stream.RunNumber),$streamStart,$streamend,$status)
						$Streaminfo+= GetStreamInfo -CurrentStream $stream
					}
				6   {
						$streamStart=([datetime]$($stream.ActualStartDateTime) + $ts)
						$streamend=([datetime]$($stream.ActualEndDateTime) + $ts)
						$status="COMPLETED" 
						$Streaminfo+= [string]::Format("<TR><TH colspan='2'><B>{0}</B></TH><TH><B>{1}</B></TH><TH><B>{2}</B></TH><TH><B>{3}</B></TH><TH><B>{4}</B></TH></TR>",$($StreamName),$($stream.RunNumber),$streamStart,$streamend,$status)
						$Streaminfo+= GetStreamInfo -CurrentStream $stream			
					}
				1   {
						$streamStart=""
						$streamend=""
						$status="PREPARED" 
						$Streaminfo+= [string]::Format("<TR><TH colspan='2'><B>{0}</B></TH><TH><B>{1}</B></TH><TH><B>{2}</B></TH><TH><B>{3}</B></TH><TH><B>{4}</B></TH></TR>",$($StreamName),$($stream.RunNumber),$streamStart,$streamend,$status)
					
					}
				3   {
						$streamStart=""
						$streamend=""
						$status="ON-HOLD" 
						$Streaminfo+= [string]::Format("<TR><TH colspan='2'><B>{0}</B></TH><TH><B>{1}</B></TH><TH><B>{2}</B></TH><TH><B>{3}</B></TH><TH><B>{4}</B></TH></TR>",$($StreamName),$($stream.RunNumber),$streamStart,$streamend,$status)
					}
	      default   {
						write-host "UNKNOWN: Stream Status code $($stream.StatusCd) not handled" 
					}
		}
	}
	$Streaminfo+="<TR><TH colspan='6'></TH></TR>"
}

$Htmlcontnet= $Htmlcontnet -ireplace "#STREAMINFO#",$Streaminfo
$Htmlcontnet= $Htmlcontnet -ireplace "#TYPE#",$StreamsType
$Htmlcontnet= $Htmlcontnet -ireplace "#ENV#",$Environment
$Htmlcontnet | Out-File Filesystem::$temphtmlfile
$Mailsubject = "$($StreamsType) STREAM  STATUS : $Environment " + (Get-Date -Format "yyyyMMdd HH::mm")
SendMail -To $maillist -subject $Mailsubject -body $Htmlcontnet
Remove-Item FileSystem::$temphtmlfile