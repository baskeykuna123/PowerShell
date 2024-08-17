$ScriptDirectory=split-path $MyInvocation.MyCommand.Definition -Parent
."$ScriptDirectory\fnSetGlobalParameters.ps1"
."$ScriptDirectory\fnUtilities.ps1"

Function GetStreamJobInfo(){
PARAM($CurrentStream,$StreamWorksEnvironment)
	$ts = New-TimeSpan -Hours 1
	$JobStatus=@{
	1="Not Started"
	3="pending"
	5="Running"
	6="Completed"
	10="Bypassed"
	}
	$jobstatusobj=@()
	$DBinfo=GetStreamWorksDBinfo -Environment $StreamWorksEnvironment
	$selectQuery=[string]::Format("select ActualStartDateTime,streamrunjobid,JobName,JobReturnCode,JobReturnMessage,ExecutionNo,JobStatusCd from StreamRunJob where StreamRunId={0} order by StreamRunJobId",$($CurrentStream.StreamRunid))
	$streamJobinfo=Invoke-Sqlcmd -Query $selectQuery -ServerInstance $DBinfo[0] -Database $DBinfo[1]
	foreach($info in $streamJobinfo){
		switch($($info.JobStatusCd)){
			5   {
					$startdate=[datetime]$($info.ActualStartDateTime) + $ts
					$enddate=[datetime]$($info.ActualStartDateTime) + $ts
				}
			3   {
					$startdate=""
					$enddate=""
				}	
			6   {
					$startdate=[datetime]$($info.ActualStartDateTime) + $ts
					$enddate=[datetime]$($info.ActualStartDateTime) + $ts
				}
			10  {
					$startdate=[datetime]$($info.ActualStartDateTime) + $ts
					$enddate=[datetime]$($info.ActualStartDateTime) + $ts
				}
			1   {
					$startdate=""
					$enddate=""
				}
			2   {
					$startdate=""
					$enddate=""
					$info
				}
		
				
		default {
				Write-Host "$($info.JobName) is in the Status code :$($info.JobStatusCd)... Status code not handled" 
				continue
				}
		}
		$jobstatusobj+=[PSCustomObject] @{
			JobName = $($info.JobName) ;
			ExecutionNo = $($info.ExecutionNo);
			StartDate = $startdate;
			EndDate = $enddate;
			Status = $JobStatus[($($info.JobStatusCd))];
			Message = $($info.JobReturnMessage);
		} 
		
	}
	$jobstatusobj | ft 
			
}


Function GetDeploymentStreamName(){
PARAM($Environment)
switch ($Environment) 
	      { 
		    "DEV" { $Streamname="D-BE-DCL92"}
	        "INT" { $Streamname="I-BE-ZCL92"}
			"ACC" { $Streamname="A-BE-ACL92"}
			"PRD" { $Streamname="P-BE-SCL92"}
			"MIG"{ $Streamname="D-BE-DCL92V0M"}
			"MIG4"  { $Streamname="D-BE-DCL92V04"}
			"PRED"  { $Streamname="D-BE-DCL92V0P"}
			"EMRG"  { $Streamname="D-BE-DCL92V0E"}
			"PAR"  { $Streamname="D-BE-DCL92PLB"}
		  }
	Return $Streamname
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