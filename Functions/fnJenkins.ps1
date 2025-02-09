$ScriptDirectory=split-path $MyInvocation.MyCommand.Definition -Parent
."$ScriptDirectory\fnSetGlobalParameters.ps1"


Function ManageJenkinsResources(){
	Param($Environment,$Application,$Action)

	$Uri =[string]::Format("http://Jenkins-be:8080/lockable-resources/{0}?resource={1}_{2}",$Action,$Application,$Environment)
	$Username = "L002867"
	$Password = "Jenk1ns@B@loise"
	$Headers = @{ "Authorization" = "Basic {0}" -f [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $Username,$Password))) }
	Write-Host "====================================================================="
	Write-Host "Action      :" $Action
	Write-Host "Application :" $Application
	Write-Host "Environment :" $Environment
	Write-Host "====================================================================="
	Invoke-RestMethod -Uri $Uri -Headers $Headers -Verbose | Out-Null
	if($Action -ine "reserve"){
		$ResetUri =[string]::Format("http://Jenkins-be:8080/lockable-resources/reset?resource={1}_{2}",$Action,$Application,$Environment)
		Invoke-RestMethod -Uri $ResetUri -Headers $Headers -Verbose | Out-Null
	}
}

function TriggerJenkinsJob(){
PARAM($JobName,$parameters,$AuthToken)

if(!$JobName){
	$JobName="PLAB_Cleva_Package_tester"
	$parameters=@{PlannedTime="20:00";Version=""}
	$AuthToken="ScheduledTriggers"
}
	
Write-Host "======================================Triggering Jobs=============================="
Write-Host "Triggerng a New build on :$($JenkinsJobName)"
Write-Host "Parameters"
	$parameters.Keys| foreach {
		Write-Host "$($_)=$($parameters.Item($_))" 
	}
	
$url=[string]::Format("http://Jenkins-be:8080/buildByToken/buildWithParameters?job={0}&token={1}&",$JobName,$AuthToken)
$parameters.Keys| foreach {
	$url+="$($_)=$($parameters.Item($_))&"
	}
$url.Trimend('&')
Invoke-WebRequest -Uri $url -Method Post -Verbose -UseBasicParsing
Write-Host "======================================Triggering Jobs=============================="
}