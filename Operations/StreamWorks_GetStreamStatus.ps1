PARAM
	(
		[string]$Environment,
		[string]$maillist,
		[string]$RunDate,
		[string]$ApplicatioName
	)

#Default Parametes
 if(!$Environment)
 {
	$Environment="DCORP"
	$maillist="Shivaji.pai@baloise.be"
	$ApplicatioName="CLEVA"
 }

 Clear-Host

Write-Host "Run Date  :" $RunDate

if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	

#Displaying Script Information
Write-host "Script Name :" $MyInvocation.MyCommand
Write-host "=======================Input Parameters======================================="
$($MyInvocation.MyCommand.Parameters) | Format-Table -AutoSize @{ Label = "Parameter Name"; Expression={$_.Key}; }, @{ Label = "Value"; Expression={(Get-Variable -Name $_.Key -EA SilentlyContinue).Value}; }
Write-host "=======================Input Parameters================================================="


 #Default date is always today
if(!$RunDate){
	$Yesterday=(get-date).addDays(-1)
	$RunDate=$Yesterday.ToString("yyyy-MM-dd")
}else{
	if($RunDate -ilike "yesterday"){
		$Yesterday=(get-date).addDays(-1)
		$RunDate=$Yesterday.ToString("yyyy-MM-dd")
	}else{
		if($RunDate -ilike "today"){
			$RunDate=get-date -format "yyyy-MM-dd"
		}else{
			$ParsedDate = $RunDate -as [DateTime]
			if (!$ParsedDate){
				$Yesterday=(get-date).addDays(-1)
				$RunDate=$Yesterday.ToString("yyyy-MM-dd")
			}else{
				$RunDate=$ParsedDate.ToString("yyyy-MM-dd")
			}
		}
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


$temphtmlfile = [string]::Format("{0}\{1}_{2}_streamStatus.html",$Global:TempNotificationsFolder,$Environment,[datetime]::Now.ToString("dd-MM-yyyy_HHmm"))
$MailTemplateFile=join-path $($Global:ScriptSourcePath)  -ChildPath "Notifications\Templates\StreamStatus.html"
$Htmlcontnet=get-content Filesystem::$MailTemplateFile
$StreamWorksEnvironment="Int"
if($Environment -ieq "PCORP"){
	$StreamWorksEnvironment="prd"
	write-host "Environmnet PCORP"
}
$DBinfo=GetStreamWorksDBinfo -Environment $StreamWorksEnvironment
$dbserver=$DBinfo[0]
$dbName=$DBinfo[1]
$ts = New-TimeSpan -Hours 1

$selectQuery="EXEC GetStreamSchedules @Application='$ApplicatioName',@Environment='$Environment'"
$Streamschedule=Invoke-Sqlcmd -Query $selectQuery -ServerInstance $Global:BaloiseBIDBserver -Database $Global:BaloiseReleaseVersionDB -Username $Global:BaloiseVersionDBuserid -Password $Global:BaloiseVersionDBuserpassword -ErrorVariable $out

if(!$Streamschedule){
	Write-Host "`r`n Stream Scheduled Not found!"
	Exit 1
}

$Streaminfo="<TABLE class='rounded-corner'>"
$Streaminfo+="<TR><TH>StreamName</TH><TH>Short Description</TH><TH>Run Number</TH><TH>StartDate</TH><TH>EndDate</B></TH><TH>Status</B></TH><TH>Error Rating</TH><TH>Modified By</TH></TR>"
foreach($Streamrun in $Streamschedule)
 {
	$StreamName=$($Streamrun.StreamName).Trim()
	Write-Host "Stream : $StreamName"
	$selectQuery=[string]::Format("select streamrunid,[ModifiedBy],StreamName,RunNumber,PlanDate,ActualStartDateTime,ActualEndDateTime,StatusCd,datediff(MINUTE,ActualStartDateTime,ActualEndDateTime) as duration from StreamRun  where  cast(PlanDate as date)='{0}'  and streamName='{1}' and RunNumber={2}  order by ActualStartDateTime",$RunDate,$StreamName,$Streamrun.RunNumber)
	$streamlist=Invoke-Sqlcmd -Query $selectQuery -ServerInstance $dbserver -Database $dbName
	$selectQuery=[string]::Format("select * from stream where StreamName='{0}' and StatusFlag=1",$StreamName)
	$streamdetails=Invoke-Sqlcmd -Query $selectQuery -ServerInstance $dbserver -Database $dbName
	$streamDescription=$streamdetails.ShortDescription
	if(!$streamlist){
		$Streaminfo+="<TR><TD>$StreamName</TD><TD>$streamDescription</TD><TD></TD><TD></TD><TD></TD><TD bgcolor='orange'>Not Planned/Scheduled</TD><TD>$($Streamrun.ErrorRating)</TD><TD></TD></TR>"
	}
	foreach($stream in $streamlist){
	$StreamName=$stream.StreamName
	$statuscolor=""	
			switch($($stream.StatusCd)){
				5   {
						$streamStart=([datetime]$($stream.ActualStartDateTime) + $ts)
						$streamend=""
						$status="RUNNING" 
						$statuscolor=""
						#$Streaminfo+= GetStreamInfo -CurrentStream $stream
					}
				6   {
						$streamStart=([datetime]$($stream.ActualStartDateTime) + $ts)
						$streamend=([datetime]$($stream.ActualEndDateTime) + $ts)
						$status="COMPLETED" 
						$statuscolor="green"
						#$Streaminfo+= GetStreamInfo -CurrentStream $stream			
					}
				10   {
						$streamStart=([datetime]$($stream.ActualStartDateTime) + $ts)
						$streamend=([datetime]$($stream.ActualEndDateTime) + $ts)
						$status="BYPASSED" 
						$statuscolor="yellow"
						#$Streaminfo+= GetStreamInfo -CurrentStream $stream			
					}
				1   {
						$streamStart=""
						$streamend=""
						$status="PREPARED" 

					
					}
				3   {
						$streamStart=""
						$streamend=""
						$status="PENDING" 
					}
	      default   {
						write-host "UNKNOWN: Stream Status code $($stream.StatusCd) not handled"
						$status="UNKNOWN"
					}
		}
		
		$modifiedby=""
		if($stream.ModifiedBy -inotmatch "system"){
			$modifiedby=$stream.ModifiedBy
		}
		
		$Streaminfo+= [string]::Format("<TR><TD>{0}</TD><TD>{1}</TD><TD>{2}</TD><TD>{3}<TD>{4}</TD></TD><TD bgcolor='$($statuscolor)'>{5}</TD><TD>{6}</TD><TD>{7}</TD></TR>",$($StreamName),$($streamDescription),$($stream.RunNumber),$streamStart,$streamend,$status,$($Streamrun.ErrorRating),$modifiedby)
	}
}
$Streaminfo+="</TABLE>"
$Htmlcontnet= $Htmlcontnet -ireplace "#STREAMINFO#",$Streaminfo
$Htmlcontnet= $Htmlcontnet -ireplace "#TYPE#",$StreamsType
$Htmlcontnet= $Htmlcontnet -ireplace "#ENV#",$Environment
$Htmlcontnet | Out-File Filesystem::$temphtmlfile
$Mailsubject = "$Environment $ApplicatioName Stream Status " + $RunDate
sendmail -To $maillist -subject $Mailsubject -body $Htmlcontnet
Remove-Item FileSystem::$temphtmlfile