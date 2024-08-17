PARAM
	(
		[string]$Environment,
		[string]$maillist,
		[string]$RunDate,
		[string]$GetDetailInfo="false"
	)

#Default Parametes
 if(!$Environment)
 {
	$Environment="ICORP"
	$maillist="kuna.baskey@baloise.be"
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

# to provide easy input parameters to be used
switch($RunDate){
	"Today" {
				$RunDate=get-date -format "yyyy-MM-dd"
			}
		}

#Importing SQL modules for SQL commands to the Version database
Import-Module sqlps -DisableNameChecking


#changes UTC time to current local time
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
	$addjoblog=$false
	foreach($info in $streamJobinfo){
		switch($($info.JobStatusCd)){
			5   {
					$startdate=[datetime]$($info.ActualStartDateTime) + $ts
					$enddate=[datetime]$($info.ActualStartDateTime) + $ts
					$status="Running"
					$addjoblog=$true
				}
			3   {
					$startdate=""
					$enddate=""
					$status="pending"
					$addjoblog=$true
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
					$addjoblog=$true
				}
			1   {
					$startdate=""
					$enddate=""
					$status="Not Started"
					$addjoblog=$true
				}
				
		default {
				Write-Host "$($info.JobName) is in the Status code :$($info.JobStatusCd)... Status code not handled" 
				continue
				}
		}
		if($addjoblog){
			$jobinfo+= [string]::Format("<TR><TD>{0}</TD><TD>{1}</TD><TD>{2}</TD><TD>{3}</TD><TD>{4}</TD><TD>{5}</TD></TR>",$($info.JobName),$($info.ExecutionNo),$($enddate),$startdate,$($status),$($info.JobReturnMessage))
		}
		else{
		$jobinfo=""
		}
	}
	return $jobinfo
			
}
Write-Host $RunDate
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
$temphtmlfile = [string]::Format("\\svw-me-pcleva01\buildteam\temp\{0}_{1}.htm",$Environment,[datetime]::Now.ToString("dd-MM-yyyy_HHmm"))
$MailTemplateFile="D:\BuildTeam\Templates\StreamStatus.html"
$Htmlcontnet=get-content $MailTemplateFile
$DBuserid="balgroupit\L002618"
$DBpassword="LoktJen8"
$StreamWorksEnvironment="Int"
if($Environment -ieq "PCORP"){
	$StreamWorksEnvironment="prd"
}
$DBinfo=GetStreamWorksDBinfo -Environment $StreamWorksEnvironment
$dbserver=$DBinfo[0]
$dbName=$DBinfo[1]
#$RunDate=(get-date -format "yyyy-MM-dd")
$nextRun=$false
$timeout = new-timespan -Hours 2
$ts = New-TimeSpan -Hours 1

switch($Environment){
"DCORP" {$StreamPrefix="D-BE-"}
"ICORP" {$StreamPrefix="I-BE-"}
"ACORP" {$StreamPrefix="A-BE-"}
"PCORP" {$StreamPrefix="P-BE-"}
"PLAB"  {$StreamPrefix="D-BE-"} 
"MIG1"  {$StreamPrefix="D-BE-"} 
"MIG4"  {$StreamPrefix="D-BE-"}
}


$PlannedStreaminfo="<TABLE class='rounded-corner'>"
$PlannedStreaminfo+="<TR><TH><B>StreamName</B></TH><TH><B>Stream Description</B></TH><TH><B>Planned Date</B></TH><TH><B>Run Number</B></TH><TH><B>StartDate</B></TH><TH><B>EndDate</B></TH><TH><B>Status</B></TH><TH><B>Duration</B></TH></TR>"

$Streaminfo="<TABLE class='rounded-corner'>"	
$Streaminfo+="<TR><TH><B>StreamName</B></TH><TH><B>Stream Description</B></TH><TH><B>Planned Date</B></TH><TH><B>Run Number</B></TH><TH><B>StartDate</B></TH><TH><B>EndDate</B></TH><TH><B>Status</B></TH><TH><B>Duration</B></TH></TR>"

#getting the list of the Streams 
$selectQuery=[string]::Format("select StreamName,ShortDescription from stream where StreamName like  '{0}%'",$StreamPrefix)
$streamlist=Invoke-Sqlcmd -Query $selectQuery -ServerInstance $dbserver -Database $dbName

foreach($Streamdetails in $streamlist)
 {
 	$StreamName=$Streamdetails.StreamName
	$streamDescription=$Streamdetails.ShortDescription
	Write-Host "Stream : $StreamName"
	$selectQuery=[string]::Format("select streamrunid,StreamName,RunNumber,ActualStartDateTime,ActualEndDateTime,StatusCd,StreamRunInterval,PlanDate,datediff(MINUTE,ActualStartDateTime,ActualEndDateTime) as duration from streamrun where StreamName = '{0}' and  cast(PlanDate as date)='{1}' order by RunNumber",$StreamName,$RunDate)
#	Write-Host $selectQuery
	$streamlist=Invoke-Sqlcmd -Query $selectQuery -ServerInstance $dbserver -Database $dbName
		if(!$streamlist){
		$statuscolor="yellow"
		$PlannedStreaminfo+= [string]::Format("c<TD><B>{0}</B></TD><TD><B>{1}</B></TD><TD><B>NA</B></TD><TD><B>NA</B></TD><TD><B>NA</B></TD><TD><B>NA</B></TD> <TD bgcolor='$($statuscolor)'><B>NOT PLANNED</B></TD></TD><TD><B>0</B></TD></TD></TR>",$($StreamName),$streamDescription)
	}
	foreach($stream in $streamlist){
	$statuscolor=""	
			switch($($stream.StatusCd)){
				5   {
						$streamStart=([datetime]$($stream.ActualStartDateTime) + $ts)
						$streamend=""
						$status="RUNNING"
						$statuscolor="blue"
						if ($GetDetailInfo -ieq "true") {$Streaminfo+= GetStreamInfo -CurrentStream $stream}
						
					}
				6   {
						$streamStart=([datetime]$($stream.ActualStartDateTime) + $ts)
						$streamend=([datetime]$($stream.ActualEndDateTime) + $ts)
						$status="COMPLETED" 
						$statuscolor="green"
						if ($GetDetailInfo -ieq "true") {$Streaminfo+= GetStreamInfo -CurrentStream $stream}		
					}
				1   {
						$streamStart=""
						$streamend=""
						$status="PREPARED" 
						$statuscolor="white"

					
					}
				3   {
						$streamStart=""
						$streamend=""
						$statuscolor="red"
						$status="ON-HOLD" 
					}
	      default   {
						write-host "UNKNOWN: Stream Status code $($stream.StatusCd) not handled" 
					}
		}
		$Streaminfo+= [string]::Format("<TR><TD><B>{0}</B></TD><TD><B>{6}</B></TD><TD><B>{5}</B></TD><TD><B>{1}</B></TD><TD><B>{2}</B></TD><TD><B>{3}</B></TD> <TD bgcolor='$($statuscolor)'><B>{4}</B></TD><TD><B>{7}</B></TD></TR>",$($StreamName),$($stream.RunNumber),$streamStart,$streamend,$status,$($stream.PlanDate),$streamDescription,$($stream.duration))
	}
	$Streaminfo+="<TR><TH colspan='6'></TH></TR>"
}
$PlannedStreaminfo+="</TABLE>"
$Streaminfo+="</TABLE>"
$Htmlcontnet= $Htmlcontnet -ireplace "#PLANNEDSTREAMINFO#",$PlannedStreaminfo
$Htmlcontnet= $Htmlcontnet -ireplace "#STREAMINFO#",$Streaminfo
$Htmlcontnet= $Htmlcontnet -ireplace "#TYPE#",$StreamsType
$Htmlcontnet= $Htmlcontnet -ireplace "#ENV#",$Environment
$Htmlcontnet | Out-File Filesystem::$temphtmlfile
$Mailsubject = "$($StreamsType) STREAM  STATUS : $Environment - " + $RunDate
SendMailWithoutadmin -To $maillist -subject $Mailsubject -body $Htmlcontnet
Remove-Item FileSystem::$temphtmlfile