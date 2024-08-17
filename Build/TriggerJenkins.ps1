Param($JenkinsJobName,$AuthToken,$Server,$Environment,$Deploy,$DeployDatabase=$false,$WeeklyPatch )

if($Deploy -ieq "true"){
	$url=[string]::Format("http://Jenkins-be:8080/buildByToken/buildWithParameters?job={0}&token={1}&BuildNumber={2}&Environment={3}&Server={4}&DeployDB={5}&WeeklyPatch={6}",$JenkinsJobName,$AuthToken,$env:BUILD_BUILDNUMBER,$Environment,$Server,$DeployDatabase,$WeeklyPatch)
	Invoke-WebRequest -Uri $url -Method Post -Verbose -UseBasicParsing
}
else{
	Write-host "TriggerDeployment was set to 'FALSE'. Build  $env:BUILD_BUILDNUMBER  will not be deployed"
}