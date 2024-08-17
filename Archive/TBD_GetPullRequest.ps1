$ScriptDirectory=split-path $MyInvocation.MyCommand.Definition -Parent
#."$ScriptDirectory\fnSetGlobalParameters.ps1"
#."$ScriptDirectory\fnUtilities.ps1"
CLS
$TFSAssemblies="Microsoft.TeamFoundation.WorkItemTracking.Client.dll",
"Microsoft.TeamFoundation.Client.dll",
"Microsoft.TeamFoundation.VersionControl.Client.dll"

$TFSAssemblyPaths="D:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\CommonExtensions\Microsoft\TeamFoundation\Team Explorer",
"C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\CommonExtensions\Microsoft\TeamFoundation\Team Explorer",
"D:\Program Files (x86)\Microsoft Visual Studio\2017\Enterprise\Common7\IDE\CommonExtensions\Microsoft\TeamFoundation\Team Explorer",
"C:\Program Files (x86)\Microsoft Visual Studio\2017\Enterprise\Common7\IDE\CommonExtensions\Microsoft\TeamFoundation\Team Explorer",
"C:\Program Files (x86)\Microsoft Visual Studio\2017\TeamExplorer\Common7\IDE\CommonExtensions\Microsoft\TeamFoundation\Team Explorer",
"C:\Program Files (x86)\Microsoft Visual Studio\2017\TeamExplorer\Common7\IDE\CommonExtensions\Microsoft\TeamFoundation\Team Explorer",
"C:\Program Files (x86)\Microsoft Visual Studio\2017\TeamExplorer\Common7\IDE\CommonExtensions\Microsoft\TeamFoundation\Team Explorer"

clear
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	


$TFSInstalled=$false

$TFSAssemblyPaths.GetEnumerator() | foreach {	
	if(test-path $_){
		$Assmeblypath=$_
	}
	
}

if(!$Assmeblypath){
		Write-Host "WARNING:TFS Client Assemblies not found : TFS Fucntions are not loaded"
}
else{
	foreach($assembly in $TFSAssemblies){
		$assemblypath=join-path $Assmeblypath -ChildPath $assembly
		#Write-Host "Loading : $assembly"
		add-type -Path $assemblypath
	}
	Write-Host "SUCCESS:TFS Client Assemblies Loaded Succesfully"			
	
}
$TFSServer=$global:TFSServer
$tfs=ConnecttoTFS $TFSServer
$sourceControlService = $tfs.GetService([Microsoft.TeamFoundation.VersionControl.Client.VersionControlServer])
$sourceControlService.TeamProjectCollection.get_Uri()
	

$collectionurl="http://tfs-be:9091/tfs"
#Get pull request list for a specific project
$url = "$collectionurl//DefaultCollection/_git/AT%20-%20NINA/pullrequests?api-version=2.0"
#$prs = (Invoke-RestMethod -Uri $prsurl -Method Get -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)})
#$prurls = $prs.value.url