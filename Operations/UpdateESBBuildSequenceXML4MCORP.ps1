param (
[string]$tfsLocation,
[string]$file
)

#$tfsLocation = "$/Baloise/Esb/dev/general/Deployment/BuildSequence"
#$file= "Mercator.Esb.BuildSequence.xml"

$localFolder = "D:\Nolio\Repository\EsbMcorpWS\"
$Environment="ICORP"
$Application="MercatorESB"

#TFS user Credentials
$userid="prod\builduser"
$pwd="Wetzel01" | ConvertTo-SecureString -asPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($userid,$pwd)
$tfsServer = "http://tfs-be:9091/tfs/defaultcollection"


Write-Host "*****************Input Parameters****************"
write-host "TFS Build Sequence XML path : "$tfsLocation
write-host "Build Sequence File Name    : "$file
Write-Host "*************************************************"



if ((Get-PSSnapIn -Name Microsoft.TeamFoundation.PowerShell -ErrorAction SilentlyContinue) -eq $null)
{
    Add-PSSnapin Microsoft.TeamFoundation.PowerShell
}
 
#Load Reference Assemblies
[void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.TeamFoundation.Client")  
[void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.TeamFoundation.VersionControl.Client")  

#Set up connection to TFS Server and get version control
$tfs = New-Object Microsoft.TeamFoundation.Client.TfsTeamProjectCollection($tfsServer,$credential)
$versionControlType = [Microsoft.TeamFoundation.VersionControl.Client.VersionControlServer]
$versionControlServer = $tfs.GetService($versionControlType)
#Delete the temp workspace
$wp=$versionControlServer.QueryWorkspaces("BuildSequenceUpdater",$userid,"SHW-me-pdnet01")
if($wp -ne $null)
{
	$wp.Delete()
	Remove-Item -Path $localFolder -Recurse -Force
	Write-Host "Existing workspace Deleted Successfully"
}
#Create a "workspace" and map a local folder to a TFS location
$workspace = $versionControlServer.CreateWorkspace("BuildSequenceUpdater",$userid)
$workingfolder = New-Object Microsoft.TeamFoundation.VersionControl.Client.WorkingFolder($tfsLocation,$localFolder)
$workspace.CreateMapping($workingFolder)
$filePath = $localFolder + "\" + $file

$workspace.Get()
$workspace.PendEdit($filePath)
Add-TfsPendingChange -Edit -Item $filepath 

#setting all patchToBuild attribute to false
$xml=[XML](Get-Content $filepath)
$solutions = $xml.SelectNodes("//BuildSolution")
foreach($node in $solutions){
	$node.patchToBuild="false"
}

#setting all patchToBuild attribute to true for db solutions
$dbprojects = "Mercator.Esb.Services.Mft.Database","Mercator.Esb.Database"
foreach($dbproject in $dbprojects){
	$xmlnode = $xml.SelectSingleNode("//BuildSolution[@name='$dbproject']")
	Write-Host "updating $dbproject, setting the patch build flag to true "
	$xmlnode.patchToBuild="true"
	write-host "Solution Name  : "$xmlnode.Name
	write-host "Patch to build : "$xmlnode.patchToBuild
	Write-Host "==================================================================="
}

#Submit file as a Pending Change and submit the change
$xml.Save($filepath)
$pendingChanges = $workspace.GetPendingChanges()
Write-Host "checking in updated Build Sequence XML for MCORP database build"
Write-Host "Updating BuidSequence XML for MCORP database build"
$workspace.CheckIn($pendingChanges,"Updating BuidSequence XML for MCORP database build")





