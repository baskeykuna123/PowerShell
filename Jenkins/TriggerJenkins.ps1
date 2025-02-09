Param($JenkinsJobName,$AuthToken,$Server,$Environment,$Deploy,$DeployDatabase=$false,$checkDeployment=$false,$ReleaseID )

clear
if(!$AuthToken){
	$JenkinsJobName="TestTriggerJenkins"
	$AuthToken="TestTrigger"
	$Server=""
	$Environment="DCORP"
	$Deploy=$true
	$DeployDatabase=$false
	$ReleaseID="R35"
}


$Deploymenttimeout=120
$jobUrl="http://Jenkins-be:8080/job/$($JenkinsJobName)"

if($Deploy -ieq "true"){
	Write-Host "Triggering following deployment job"
	Write-Host $jobUrl
	$url=[string]::Format("http://Jenkins-be:8080/buildByToken/buildWithParameters?job={0}&token={1}&BuildNumber={2}&Environment={3}&Server={4}&DeployDB={5}&ReleaseID={6}",$JenkinsJobName,$AuthToken,$env:BUILD_BUILDNUMBER,$Environment,$Server,$DeployDatabase,$ReleaseID)
	$Res=Invoke-WebRequest -Uri $url -Method Post -UseBasicParsing
	$Res.StatusDescription
	if($Res.StatusDescription -ieq "Created"){
		Write-Host "Deployment Triggered for Build  : $($env:BUILD_BUILDNUMBER)"
		Write-Host "Waiting for the Job to start"
		
	}
}
else{
	Write-host "TriggerDeployment was set to 'FALSE'. Build  $env:BUILD_BUILDNUMBER  will not be deployed"
}

if($checkDeployment){
	$jobStatusURl="http://Jenkins-be:8080/job/$($JenkinsJobName)/lastBuild/api/json"

	$sw = [diagnostics.stopwatch]::StartNew()
	While($sw.elapsed.Minutes -lt $Deploymenttimeout){
		Start-Sleep -Seconds 10
		
	 	$res = Invoke-WebRequest $jobStatusURl
		If ($res.StatusCode -ne 200) {
			Write-Host "Jenkis Job not found ......"
			exit 1
		}
		$data = $res.Content | ConvertFrom-Json
		if($data.building){
	    	Write-Host "The Deployment is running .........."
	    	Start-sleep -Seconds 10 
		}
		else{
			Write-Host "Deployment completed"
			break;
		}
		
	}
	switch($data.result){
		"SUCCESS"	{
	 					Write-Host "SUCESSS :The Jenkins Job completed successfully"
	 					exit 0
				  	}
		"FAILURE"	{
	 					Write "FAILED : The Jenkins Job Failed, Please refer $jobUrl for more details"
		 				exit 1
				  	}
		"UNSTABLE"	{
	 					Write-Host "FAILED : The Jenkins Job partiallysucceeded, Please refer $jobUrl for more details"
		 				exit 1
				  	}
		Default 	{
						Write-Host "UNKNOWN : Jenkins Job result was incorrect or not known"
						Exit 1
					}
	}
	
}