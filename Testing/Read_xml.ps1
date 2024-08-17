Set-ExecutionPolicy RemoteSigned
$XMLfile = '\\balgroupit.com\appl_data\BBE\Transfer\Packages\Scripts\InputParameters\BIToolsHealthCheckParameters.xml'
[XML]$TFSBuildServer = Get-Content $XMLfile
 
foreach($TFSBuildServer in $TFSBuildServers.TFSBuildServers.Properties){
if(TFSagentInUse -eq "True")
{
Write-Host "Details Server:" $TFSBuildServer.DetailsServer
Write-Host "agentService:" $TFSBuildServer.agentService
Write-Host "Status:" $TFSBuildServers.Status
}
}