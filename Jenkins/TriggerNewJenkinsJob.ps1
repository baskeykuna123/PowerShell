PARAM($JobName,$parameters,$AuthToken)

if(!$JobName){
	$JobName="PLAB_Cleva_Package_tester"
	$parameters=@{PlannedTime="20:00";Version=""}
	$AuthToken="ScheduledTriggers"
}
	
Write-Host "======================================Triggering Jobs=============================="
Write-Host "Triggerng a New build on :$($JenkinsJobName)"
Write-Host "Parameters)"
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