Param($PreparationNumber,$TestType,$Environment)
CLS

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
 

#TFS user Credentials
$userid="Balgroupit\L002867"
$pwd="Jenk1ns@B@loise" | ConvertTo-SecureString -asPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($userid,$pwd)
$tfsServer = "http://tfs-be:9091/tfs/defaultcollection"

#Set up connection to TFS Server and get version control
$tfs = New-Object Microsoft.TeamFoundation.Client.TfsTeamProjectCollection($tfsServer,$credential)
$versionControlType = [Microsoft.TeamFoundation.VersionControl.Client.VersionControlServer]
$versionControlServer = $tfs.GetService($versionControlType)
#$localFolder="D:\TestWare\Dev\General\Technical\2.Business\BackOffice\Cleva"
$localFolder="D:\BuildTeam\Cleva\TechnicalTest"
#$tfsLocation="$/Baloise/BuildInstall/TEMP_TOBEDELETED"
$tfsLocation="$/Baloise/TestWare/Dev/General/Technical/2.Business/BackOffice/Cleva"
$DateTime=GET-DATE -format "dd-MM-yyyy hh:mm:ss"


#Delete the temp workspace
$wp=$versionControlServer.QueryWorkspaces("ClevaSoapUITechnicalTest",$userid,"$env:COMPUTERNAME")
if($wp -ne $null)
{
	$wp.Delete()
	Remove-Item -Path filesystem::"$localFolder*" -Recurse -Force
	Write-Host "Existing workspace Deleted Successfully"
}


#Create a "workspace" and map a local folder to a TFS location
$workspace = $versionControlServer.CreateWorkspace("ClevaSoapUITechnicalTest",$userid)
$workingfolder = New-Object Microsoft.TeamFoundation.VersionControl.Client.WorkingFolder($tfsLocation,$localFolder)
$workspace.CreateMapping($workingFolder)


# Download files from TFS
Write-Host "INFO:Get latest from TFS.. "
$workspace.Get() | Out-Null
$TFSFiles=gci $localFolder -Recurse -Force 
Write-Host "INFO:Executing CHECKOUT to update files.."
ForEach($file in $TFSFiles){
	$workspace.PendEdit($($file.fullname)) | out-null
	Write-Host "CHECKOUT:"$($file.Name)
}	

# Preparation
#$PrepBatFile=[String]::Format("Cleva_{0}-CommandLine - EXEC_{1}_{2} - 1Thread_1RunPerThread.bat",$PreparationNumber,$TestType,$Environment)
$PrepBatFile="Cleva_Prep-CommandLine.bat"
Write-Host "Preparation script file:"$PrepBatFile
$ScriptSource=[String]::Format("{0}\{1}",$localFolder,$PrepBatFile)
If(Test-Path $ScriptSource -ErrorAction Stop){
	Write-Host "==================================================================================="
	Write-Host "TestScript Source       :" $ScriptSource
	Write-Host "Preparation bat file    :" $PrepBatFile
	Write-Host "==================================================================================="
	
	cmd.exe /c $ScriptSource $Environment $TestType $localFolder $PreparationNumber | Write-Host
	#& $ScriptSource $Environment $TestType $localFolder $PreparationNumber | Write-Host
}

# List the pending changes and checkin the pending changes
$pendingChanges = $workspace.GetPendingChanges()
$workspace.CheckIn($pendingChanges,"Preparation completed - $DateTime.")
if($LastExitCode -eq '0'){
	Write-Host "INFO:Check-in pending changes successfully done."
}
Else{
	throw "ERROR:!!Checkin Failed."
}