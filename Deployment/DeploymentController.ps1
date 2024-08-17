PARAM($Action,$Application,$Environment)

switch ($Action) 
      { 
	    "Release" { $Action="unreserve"}
        "Restrict" { $Action="reserve"}
      }

if(!$Action){
	$Application="CLEVA"
	$Environment="PLAB"
	$Action="unreserve"
}


clear
if($Action -ieq "unreserve"){
$ResetUri =[string]::Format("http://Jenkins-be:8080/lockable-resources/ResetResource?resource={1}_{2}",$Action,$Application,$Environment)
}
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
if($Action -ieq "unreserve"){
$ResetUri =[string]::Format("http://Jenkins-be:8080/lockable-resources/reset?resource={1}_{2}",$Action,$Application,$Environment)
Invoke-RestMethod -Uri $ResetUri -Headers $Headers -Verbose | Out-Null
}