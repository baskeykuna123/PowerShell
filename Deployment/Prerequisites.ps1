
#load WebDeployer function file
$currentDir = Split-Path $MyInvocation.MyCommand.Path
Set-Location $currentDir
#call funtion scripts
. (join-path  -path $currentDir "SetGlobalParameters.ps1")
. (join-path  -path $currentDir "BIIISFunctions.ps1")

CreateApplicationPool -Name TestAppPoolWS -AppPoolPassword PWD -AppPoolUserName userName -enable32BitAppOnWin64 $false -ManagedPipelineMode Integrated -ManagedRuntimeVersion v4.0 -restartSchedule "3:00:00" -restartTimeLimit "0:00:00"
CreateWebSite -WebSiteName TestWS -Port "666" -ApplicationPool TestAppPoolWS

#CreateApplicationPool -Name projectabc -AppPoolPassword PWD -AppPoolUserName userName -enable32BitAppOnWin64 $false -ManagedPipelineMode Integrated -ManagedRuntimeVersion v4.0 -restartSchedule "3:00:00" -restartTimeLimit "0:00:00"
CreateWebApplicationInWebsite -ProjectName projectabc -WebSiteName TestWS -ApplicationPool TestAppPoolWS -AnonymousAuthentication $true -AspImpersonation $false -BasicAuthentication $false -FormsAuthentication "Windows" -WindowsAuthentication $false
