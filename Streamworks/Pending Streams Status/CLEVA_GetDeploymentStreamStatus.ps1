PARAM
	(
		[string]$StreamName,
		[string]$curdate,
		[string]$Environment,
		[String]$StreamWorksEnvironment="Int",
		[String]$CheckDeploymentFolder=$true
	)

#Testing Parametes
 if(!$Environment)
 {
	$StreamName="D-BE-DCL92"
	$StreamWorksEnvironment="Int"
	$Environment="Dev"
 }
 

 
#Default date is always today
 if(!$curdate){
 	$curdate=get-date -format "yyyy-MM-dd"
 }
Clear-Host
#loading Functions
Import-Module sqlps -DisableNameChecking

if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	


#Mail preparation
$Subject=[string]::Format("CLEVA Deployment for {0} on {1} - ",$Environment,$curdate)
$HTMLTemplateFilePath=join-path $($Global:ScriptSourcePath)  -ChildPath "Notifications\Templates\StreamStatus.html"
$HtmlBody=get-content Filesystem::$HTMLTemplateFilePath
$HtmlBody=$HtmlBody -replace "#ENV#",$Environment
$DeploymentInfo="<TABLE class='rounded-corner'>"
$DeploymentInfo+="<tr><th>Stream Name</th><td>$($StreamName)</td></tr>"
$DeploymentInfo+="<tr><th>Environment</th><td>$($Environment)</td></tr>"
$DeploymentInfo+="<tr><th>Deployment Date</td><td>$($curdate)</td></tr>"




if($Environment -ieq "PCORP"){
	$StreamWorksEnvironment="PRD"
}
$DBinfo=GetStreamWorksDBinfo -Environment $StreamWorksEnvironment
$pollingtimeinSecs=2
$Executontimeout = new-timespan -Hours 6
$CLEVAEnv=GetClevaEnvironment -Environment $Environment
$ts = New-TimeSpan -Hours 2
if(!$CheckDeploymentFolder){
	if(GetDeploymentPackageFolder -Environment $CLEVAEnv){
		$DeploymentRunNumber=(GetDeploymentPackageFolder -Environment $CLEVAEnv).Split('_')[2]
		$Pacakgeid=GetDeploymentPackageFolder -Environment $CLEVAEnv
		$DeploymentInfo+="<tr><th>Deployment Package</td><td>$($Pacakgeid)</td></tr>"
	}
	else{
		Write-Host "`r`n`r`nThere were no deployment folders present..Aborting`r`n`r`n"
		Exit 1
	}
}
else{
	$DeploymentRunNumber=1
}
$DeploymentInfo+="<tr><th>Deployment RunNumber</td><td>$($DeploymentRunNumber)</td></tr>"

if($StreamName -ieq "Patch"){
	$streamName=GetDeploymentStreamName -Environment $CLEVAEnv
}

$StreamStatus=@{
	1="Planned"
	3="On-Hold"
	5="Running"
}

	Write-Host "Stream : $StreamName"
	$sw = [diagnostics.stopwatch]::StartNew()
	do{
	$selectQuery=[string]::Format("select * from streamrun where StreamName = '{0}' and  cast(PlanDate as date)='{1}' and RunNumber={2}",$streamname,$curdate,[int]$DeploymentRunNumber)
	$stream=Invoke-Sqlcmd -Query $selectQuery -ServerInstance $DBinfo[0] -Database $DBinfo[1]
	$startDate="NA"
	$EndDate="NA"
	$PlannedDate="NA"
	if(-not ([string]::IsNullOrEmpty($stream.ActualStartDateTime))){
		$startDate=([datetime]$($stream.ActualStartDateTime) + $ts)
	}
	if(-not ([string]::IsNullOrEmpty($stream.ActualEndDateTime))){
		$EndDate=([datetime]$($stream.ActualEndDateTime) + $ts)
	}
	if(-not ([string]::IsNullOrEmpty($stream.PlannedStartDateTime))){
		$PlannedDate=([datetime]$($stream.PlannedStartDateTime) + $ts)
	}
	Write-Host "================================================================================================================"
	Write-host 'RunNumber			: ' $stream.RunNumber
	Write-host 'Status				: ' $StreamStatus[$($stream.StatusCd)]
	Write-host 'Planned Datetime	: ' $PlannedDate
	write-host 'Start DateTime		: ' $startDate
	write-host 'End DateTime		: ' $EndDate
	Write-Host "=================================================================================================================="
	switch($($stream.StatusCd)){
	{($_ -eq 1) -or ($_ -eq 3)} {
									
								
								Start-sleep -Seconds $pollingtimeinSecs
								$selectQuery=[string]::Format("select * from streamrun where StreamRunId = '{0}' order by RunNumber",$stream.StreamRunid)
								$stream=Invoke-Sqlcmd -Query $selectQuery -ServerInstance $DBinfo[0] -Database $DBinfo[1]
								GetStreamJobInfo -CurrentStream $stream -StreamWorksEnvironment $StreamWorksEnvironment
								}
							6   {
									Write-Host "PENDING: Stream $CurrentStream execution Planned...."
									GetStreamJobInfo -CurrentStream $stream -StreamWorksEnvironment $StreamWorksEnvironment
									$DeploymentInfo+="<tr><th>Status</th><td bgcolor='Orange'>PENDING</td></tr></table>"
									$HtmlBody=$HtmlBody -replace "#STREAMINFO#",$DeploymentInfo
									SendMail -To $global:BICLEVADeploymentMail -subject ($Subject + "- Pending") -body $HtmlBody
									Exit 0
								}
							    {
									Write-Host "PENDING: Stream $CurrentStream execution On-Hold...."
									GetStreamJobInfo -CurrentStream $stream -StreamWorksEnvironment $StreamWorksEnvironment
									$DeploymentInfo+="<tr><th>Status</th><td bgcolor='Orange'>PENDING</td></tr></table>"
									$HtmlBody=$HtmlBody -replace "#STREAMINFO#",$DeploymentInfo
									SendMail -To $global:BICLEVADeploymentMail -subject ($Subject + "- Pending") -body $HtmlBody
									Exit 0
								}
							    {
									Write-Host "PENDING: Stream $CurrentStream execution Running...."
									GetStreamJobInfo -CurrentStream $stream -StreamWorksEnvironment $StreamWorksEnvironment
									$DeploymentInfo+="<tr><th>Status</th><td bgcolor='Orange'>PENDING</td></tr></table>"
									$HtmlBody=$HtmlBody -replace "#STREAMINFO#",$DeploymentInfo
									SendMail -To $global:BICLEVADeploymentMail -subject ($Subject + "- Pending") -body $HtmlBody
									Exit 0
								}
							5   {
									write-host "Start DateTime	:" ([datetime]$($stream.ActualStartDateTime) + $ts)
									Start-sleep -Seconds $pollingtimeinSecs
									GetStreamJobInfo -CurrentStream $stream -StreamWorksEnvironment $StreamWorksEnvironment
								}
					    	2   { 
									write-host "Status code 2 : Stream Starting Up " 
									Start-sleep -Seconds $pollingtimeinSecs
								}	   
					  default   {
									write-host "UNKNOWN: Stream Status code $($stream.StatusCd) not handled" 
									$DeploymentInfo+="<tr><th>Status</th><td bgcolor='red'>STATUS UNKNOWN</td></tr></table>"
									$HtmlBody=$HtmlBody -replace "#STREAMINFO#",$DeploymentInfo
									SendMail -To $global:BICLEVADeploymentMail -subject ($Subject + "- UKNOWNSTATUS") -body $HtmlBody
									Exit 1
								}
				
	}
	
	
	}while ($sw.elapsed -lt $Executontimeout )
	Write-Host "Time out occured..."
	$DeploymentInfo+="<tr><th>Status</th><td bgcolor='red'>Polling Time out</td></tr></table>"
	$HtmlBody=$HtmlBody -replace "#STREAMINFO#",$DeploymentInfo
	SendMail -To $global:BICLEVADeploymentMail -subject ($Subject + "- TIMEOUT") -body $HtmlBody
	Exit 1
	
Write-Host "=================================================================================================================="


