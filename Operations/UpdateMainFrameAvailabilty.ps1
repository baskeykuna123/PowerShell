param
(
	[String]$Env,
	[String]$DayOfWeek,
	[int]$StartTime,
	[int]$EndTime,
	[String]$Action
)
Clear-Host
#loading Functions
if(Get-Module -Name LoadFunctions){
	Remove-Module LoadFunctions -Force
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	

if(!$Env){
	$Env="DCORP"
	$DayOfWeek="SATURDAY"
	$StartTime=600
	$EndTime=2200
	$Action="RESET"
}

$ErrorActionPreference='Stop'

write-host "================================================================================"
Write-host "Environment : " $Env
Write-host "Action      : " $Action
write-host "================================================================================"

$ESBDBName="ESB_2_0"
$MNETDBName="Peach_Data"

#Function UpdateMainframeAvailability(){
#PARAM($Env,$Action)
 switch ($DayOfWeek) 
      { 
        "MONDAY" { $DayOfWeek=1}
		"TUESDAY" {$DayOfWeek=2}
		"WEDNESDAY" {$DayOfWeek=3}
		"THURSDAY" {$DayOfWeek=4}
		"FRIDAY" {$DayOfWeek=5}
		"SATURDAY" {$DayOfWeek=6}
		"SUNDAY" {$DayOfWeek=0}
      }
	


# Set and Reset query	
	
	
	
# Query to be executed for "GET".	
	 $Sql = "  select StartTime,EndTime, (case 
  when DayOfWeek=1 then 'MONDAY'
  when DayOfWeek=2 then 'TUESDAY'
  when DayOfWeek=3 then 'WEDNESDAY'
  when DayOfWeek=4 then 'THURSDAY'
  when DayOfWeek=5 then 'FRIDAY'
  when DayOfWeek=6 then 'SATURDAY'
  when DayOfWeek=0 then 'SUNDAY'
  END  )as Day,DayOfWeek as DayNumber from dbo.MainframeAvailability  group by dayofweek,EndTime,StartTime"

#Check file and remove if exists.
$MainframeStatusHTMFile = [String]::Format("{0}\{1}_Mainframe_Status.htm",$global:EnvironmentHTMLReportLocation, $Env)
$TestHTMfile = Test-Path FileSystem::$MainframeStatusHTMFile
if($TestHTMfile -ieq "True")
{
	Clear-Content -Path FileSystem::$MainframeStatusHTMFile -Force
}

# Main Logic to out the report to htm file based on application and environment
foreach($Application in $(($global:MainFrameAvailablityAppList).split(",")))
{
	Switch($Application)
	{
	"MyBaloiseClassic" {
			$ServerType="WEBFRONTDB"
			$DBName="Peach_Data"
			}
	"ESB" {
			$ServerType="ESBDB"
			$DBName="ESB_2_0"
			}
	}

	$DBuser=get-Credentials -Environment $Env -ParameterName  "DataBaseDeploymentUser"
	$DBpassword=get-Credentials -Environment $Env -ParameterName  "DataBaseDeploymentUserPassword"
	$DBServerInfo = GetEnvironmentInfo  -Environment $Env -ServerType $ServerType
	$DBServer = $DBServerInfo.Name


	switch($Action) 
		{
			"SET"	{
						if($StartTime -gt $EndTime){
							Write-Host "Invalid Start and End Time. Start time cannot be greater than  end time"
							Exit 1
						}
						$SqlQuery = "update dbo.MainframeAvailability Set StartTime=$StartTime , EndTime=$EndTime where DayOfWeek=$DayOfWeek"
						$update=Invoke-Sqlcmd -Query $SqlQuery -ServerInstance $DBserver -Database $DBName -Username $DBuser -Password $DBpassword 
					}
					
			"RESET"	{
						$updateQuery = "update dbo.MainframeAvailability set StartTime='700', EndTime='2100' Where DayOfWeek in (1,2,3,4,5)"
						$update=Invoke-Sqlcmd -Query $updateQuery -ServerInstance $DBServer -Database $DBName -Username $DBuser -Password $DBpassword 
						 
						$updateQuery = "update dbo.MainframeAvailability Set StartTime='0' , EndTime='0' where DayOfWeek='0' "
						$update=Invoke-Sqlcmd -Query $updateQuery -ServerInstance $DBServer -Database $DBName -Username $DBuser -Password $DBpassword 

						$updateQuery = "update dbo.MainframeAvailability Set StartTime='700' , EndTime='1700' where DayOfWeek='6' "
						$update=Invoke-Sqlcmd -Query $updateQuery -ServerInstance $DBServer -Database $DBName -Username $DBuser -Password $DBpassword
					}
					
		}
		



	$MainframeStatus="<TABLE class='rounded-corner'>"
	$MainframeStatus+="<TR align=center><TH colspan='4'>Mainframe Status : $($Env)</TH></TR>"
	$MainframeStatus+="<TR align=center><TH colspan='4'>MF Availibility - $Application</TH></TR>" 
	$MainframeStatus+="<TR align=center><TH>Start Date</TH><TH>End Date</TH><TH>Day</TH><TH>Day of Week</TH></TR>"

	$Details = Invoke-Sqlcmd -Query $Sql -ServerInstance $DBserver -Database $DBName -Username $DBUser -Password $DBPassword 
	$Details | ft -Property StartTime,EndTime,Day,DayNumber  -AutoSize -Wrap

	ForEach($Item in $Details)
	{
		$MainframeStatus+="<TR align=center><TD>$($Item.StartTime)</TD><TD>$($Item.EndTime)</TD><TD>$($Item.Day)</TD><TD>$($Item.DayNumber)</TD></TR>"
	}

	$MainframeStatus+="</TABLE>" 
	$MainframeStatus+="<BR>" 
	$EnvironmentStatusHTM = [string]::Format("{0}\{1}_Mainframe_Status.htm",$global:EnvironmentHTMLReportLocation,$Env)
	$HtmlBodyStatus = [system.IO.File]::ReadAllLines($Global:EnvironmentStatusTemplate)
	$Timestamp = [datetime]::Now.ToString("dd-MM-yyyy_HHmm")
	$HtmlBodyStatus = $HtmlBodyStatus -ireplace "#DateTime#",$Timestamp
	$HtmlBodyStatus = $HtmlBodyStatus -ireplace "#StatusReport#",$MainframeStatus
	$HtmlBodyStatus | Out-File Filesystem::$EnvironmentStatusHTM -Force -Append
}
