param (
	[string]$PatchManifestPath,
	[string]$tfsLocation,
	[string]$file
)


if(!$PatchManifestPath){
	#$PatchManifestPath="D:\Nolio\Repository\GlobalPatchmanifest.xml"
	$PatchManifestPath="\\cl-me-re01\Transfer\Packages\Scripts\InputParameters\GlobalPatchmanifest.xml"
	$tfsLocation="$/Baloise/Esb/Production/R26.0/Deployment/BuildSequence"
	$file="Mercator.Esb.BuildSequence.xml"
}


#loading Function
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	


if ((Get-PSSnapIn -Name Microsoft.TeamFoundation.PowerShell -ErrorAction SilentlyContinue) -eq $null)
{
    Add-PSSnapin Microsoft.TeamFoundation.PowerShell -ErrorAction SilentlyContinue
}
 
#Load Reference Assemblies
[void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.TeamFoundation.Client")  
[void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.TeamFoundation.VersionControl.Client")  

Clear-Host
$PatchManifestPath=$global:PatchManifest
#$PatchManifestPath=$global:PatchManifest
$patchWorkspace="\\shw-me-pdnet01\d$\Nolio\"
$localFolder = $patchWorkspace + "TFSWorkspace\"
$Application="ESB"

#TFS user Credentials
$userid="prod\builduser"
$pwd="Wetzel01" | ConvertTo-SecureString -asPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($userid,$pwd)
$tfsServer = "http://tfs-be:9091/tfs/defaultcollection"
#Set up connection to TFS Server and get version control
$tfs = New-Object Microsoft.TeamFoundation.Client.TfsTeamProjectCollection($tfsServer,$credential)
$versionControlType = [Microsoft.TeamFoundation.VersionControl.Client.VersionControlServer]
$versionControlServer = $tfs.GetService($versionControlType)

#reading the patch manifest file to run the 
$Patchxml=[XML](Get-Content Filesystem::$PatchManifestPath)
$patches=$Patchxml.SelectNodes("//Release/Application[@Name='$Application']/PatchRequest")



Write-Host "*****************Input Parameters****************"
write-host "Patch Manifest Path         : "$PatchManifestPath
write-host "TFS Build Sequence XML path : "$tfsLocation
write-host "Build Sequence File Name    : "$file
Write-Host "*************************************************"


 


#Delete the temp workspace
$wp=$versionControlServer.QueryWorkspaces("BuildSequenceUpdater",$userid,"shw-me-pdnet01")
if($wp -ne $null)
{
	$wp.Delete()
	Remove-Item -Path filesystem::"$localFolder*" -Recurse -Force
	Write-Host "Existing workspace Deleted Successfully"
}
#Create a "workspace" and map a local folder to a TFS location
$workspace = $versionControlServer.CreateWorkspace("BuildSequenceUpdater",$userid)
$workingfolder = New-Object Microsoft.TeamFoundation.VersionControl.Client.WorkingFolder($tfsLocation,$localFolder)
$workspace.CreateMapping($workingFolder)
$filePath = $localFolder + $file
$workspace.Get() | Out-Null
$workspace.PendEdit($filePath) | out-null
$xml=[XML](Get-Content $filepath)

$solutions = $xml.SelectNodes("//BuildSolution")
foreach($node in $solutions){
$node.patchToBuild="false"
}

foreach($patch in $patches)
{	 
	if($patch.State -ilike "*Planned")
	{
		Write-Host "Patch : " $patch.Number
		foreach($Assembly in $patch.ChildNodes)
		{
			$AssemblyName =  [System.IO.path]::GetFileNameWithoutExtension($Assembly.Name)
			$xmlnodes = $xml.SelectNodes("//BuildSolution/Projects/Project")
			foreach($node in $xmlnodes){
				if(($node.Name) -match $AssemblyName){
					$xmlnode=$node.ParentNode.ParentNode
					$xmlnode.patchToBuild="true"
					$name=$Assembly.Name
					$addtogac=$Assembly.AddtoGAC
					$addtobts=$Assembly.AddtoBiztalkResouces
					Write-Host "==================================================================="
					Write-Host "Assemblyname         : "$name
					write-host "Solution Name        : "$xmlnode.Name
					Write-Host "AddtoGac             : "$addtogac
					Write-Host "AddtoBiztalkResouces : "$addtobts
					Write-Host "==================================================================="
				}
			}
		}
	}
}

#Submit file as a Pending Change and submit the change
$xml.Save($filepath)
$pendingChanges = $workspace.GetPendingChanges()
Write-Host "Updating BuidSequence XML for Patches"
$workspace.CheckIn($pendingChanges,"PatchBuilds")