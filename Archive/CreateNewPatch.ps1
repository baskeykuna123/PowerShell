Param([String]$Release,[String]$patchNumber,[string]$Assmeblies,[String]$ApplicationName,$tfsbranch,$applicationsToBuild,$hostInstances,$IsBindingPatch,$StopStart,$AddBizTalkReferences,$UninstallApplication,$CreateApplication)

clear

#loading Function
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	


# Test input parameters
if(!$patchNumber){
$Release="R36"
$ApplicationName="ESB"
$patchNumber="499480"
$Assmeblies=
@"
Baloise.Esb.Service.BrokerPackage.Internal.B2B.Portima.ProcessSupport.dll##2.0
Baloise.Esb.Service.BrokerPackage.SharedArtifacts.Portima.Processing.dll#true#2.0
Baloise.Esb.Service.BrokerPackage.Batch.Internal.B2B.Portima.Processing.dll#true#2.0
"@
$tfsbranch="Production/R36.0"
$hostInstances="RestartHostInstances#true#BiztalkProcessing_Async"
$IsBindingPatch="ImportBinding#true#Baloise.Esb.Service.BrokerPackage.BindingInfo.xml"
$StopStart="StopStart#true#Baloise.Esb.Service.BrokerPackage"
$AddBizTalkReferences="AddBizTalkReferences##"
$UninstallApplication="UninstallApplication##"
$CreateApplication="CreateApplication##"
}


#Load Reference Assemblies
if ((Get-PSSnapIn -Name Microsoft.TeamFoundation.PowerShell -ErrorAction SilentlyContinue) -eq $null)
{
    Add-PSSnapin Microsoft.TeamFoundation.PowerShell -ErrorAction SilentlyContinue
}

[void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.TeamFoundation.WorkItemTracking.Client") 
[void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.TeamFoundation.Client")  
[void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.TeamFoundation.VersionControl.Client")  


# Variables
$file="Mercator.Esb.BuildSequence.xml"
$patchWorkspace="D:\ESBPatch\"
$localFolder = $patchWorkspace + "TFSWorkspace\"
$tfsLocation = [String]::Format("$/Baloise/Esb/{0}/Deployment/BuildSequence",$tfsbranch)
$HostInstances2Restart=$hostInstances.Split('#')[2]
$BindingFile=$IsBindingPatch.split('#')[2]
$BizTalkReferences=$AddBizTalkReferences.split("#")[2]
$UninstallApplication=$UninstallApplication.split("#")[2]
$CreateApplication=$CreateApplication.split("#")[2]
$StopStartApplication=$StopStart.split('#')[2]
$PatchFolder=[String]::Format("PR-{0}_{1}",$patchNumber,$ApplicationName)
$PatchxmlFile=[String]::Format("{0}{1}\{2}\{3}\{4}.xml",$global:PatchManifestRoot,$Release,$ApplicationName,$PatchFolder,$patchNumber)
#$GLobal:ReleaseDeliverablesLocation

# Get MercatorBuild Version
$Query="Select BuildDBVersion from Release Where ReleaseID='$($Release.replace('R',''))'"
$MercatorBuildVersion=Invoke-Sqlcmd -ServerInstance $Global:BaloiseBIDBserver  -Database $Global:BaloiseReleaseVersionDB -Username $Global:BaloiseVersionDBuserid -Password $Global:BaloiseVersionDBuserpassword -Query $Query

# Get updated patch Esb version
$ProperiesFile=$(gci Filesystem::$($Global:JenkinsPropertiesRootPath)|?{$_.Name -ieq 'IAP_Esb_Patch.properties'}).FullName
$GetProperiesFileDetails = convertfrom-stringdata (gc FileSystem::$ProperiesFile -Raw)
$PreviousEsbVersion=$GetProperiesFileDetails.ESBVersion
$CurrentEsbVersion=$PreviousEsbVersion.split('.')[0]+'.'+$PreviousEsbVersion.split('.')[1]+'.'+$PreviousEsbVersion.split('.')[2]+'.'+$([int]$PreviousEsbVersion.split('.')[3]+1)

#updates the properties files
function UpdatePatchproperties($filepath,$ApplicationName,$tfsbranch,$Pnumber){
	foreach($line in [System.IO.File]::ReadAllLines($filepath)){
		$propfile+= ConvertFrom-StringData $line
	}

	$vername=$ApplicationName+"Version"
	$propfile["TFSBranch"]=$tfsbranch
	$propfile["MercatorBuildVersion"]=$($MercatorBuildVersion.BuildDBVersion)
	$propfile["$vername"]=$CurrentEsbVersion
	$propfile["Release"]=$Release
	$propfile["ApplicationsToBuild"]=$applicationsToBuild

	$propfile.Keys|%{$propdata+="$_="+$propfile.Item($_)+"`r`n"}
	Set-Content filesystem::$filepath -Value $propdata
}

function WritefixInfo($patch,$fixfile)
{
	if(-Not (Test-Path $fixfile))
	{
		$links=$patch.get_WorkItemLinks()
		foreach($ln in $links){
			$did=$ln.TargetId
			Add-Content -Path  filesystem::$fixfile "======================================"
			Add-Content -Path  filesystem::$fixfile "`nDefect : $did" 
			$defect=$WIT.GetWorkItem($ln.TargetId)
			$fixinfo=$defect.Fields["Proposed Fix"].Value
			$fixinfo=$fixinfo -ireplace "<Br>","`r`n"
			$fixinfo=$fixinfo -ireplace "<BR/>","`r`n"
			$fixinfo=$fixinfo -ireplace "</P>","`r`n"
			$fixinfo=$fixinfo -ireplace "<.*?>",""
			$fixinfo=$fixinfo.Trim("`r`n")
			#$fixinfo=[System.Web.HttpUtility]::HtmlDecode($fixinfo)|Out-Null
			$fixinfo=[System.Net.WebUtility]::HtmlDecode($fixinfo)
			Add-Content -Path  filesystem::$fixfile -Value $fixinfo 
			Add-Content -Path  filesystem::$fixfile "======================================"
		}
	}
}

[string] $tfsServer = "http://tfs-be:9091/tfs/DefaultCollection"
$patchinfo=Join-path $Global:JenkinsPropertiesRootPath -Childpath "IAP_Esb_Patch.Properties"

if(-not (Test-Path filesystem::$PatchxmlFile)){
	New-Item Filesystem::$PatchxmlFile -ItemType File -Force | Out-Null
}

$PatchXMLTemplate=@"
<?xml version="1.0" encoding="utf-8" ?>
<Patch>
</Patch>
"@

Set-Content Filesystem::$PatchxmlFile -Value $PatchXMLTemplate -Force

[XML]$Patchxml=(gc filesystem::$PatchxmlFile)
$nodes=$Patchxml.SelectSingleNode("//Patch")
$nodes.SetAttribute("Number",$patchNumber)
$nodes.SetAttribute("ApplicationBaseVersion","")
$patch=$Patchxml.SelectSingleNode("//Patch[@Number='$patchNumber']")
if($Assmeblies){
	$asmb=$Assmeblies.Split("`r`n")
	$asmb | foreach {
		$dll=[System.IO.Path]::GetFileNameWithoutExtension(($_ -split "#")[0]) +".dll"
	#	if($dll -notlike "*.dll" ){
	#		$dll=$dll+".dll"
	#	}

		if((($_ -split"#")[1]) -eq $null){
			$addbts="False"
		} 
		else {
			$addbts=($_ -split"#")[1]
		}

		if((($_ -split"#")[2]) -eq $null){
			$Ver=""
		} 
		else {
			$Ver=($_ -split"#")[2]
		}
		if(($Patchxml.SelectSingleNode("//Patch[@Number='$patchNumber']/Assembly[@Name='$dll']")) -eq $null){
			$new=$Patchxml.CreateElement("Assembly")
			$new.SetAttribute("Name",$dll)
			$new.SetAttribute("AddGac","true")
			$new.SetAttribute("AddResource",$addbts)
			$new.SetAttribute("Version",$Ver)
			$patch.AppendChild($new) | Out-Null
		}
	}
}
$CreateUpdateDeploymentAction=$Patchxml.CreateElement("DeploymentActions")

# Update binding info in patch XML
if($BindingFile -ine $null){
	$CreateUpdateDeploymentAction.SetAttribute("BindingFile",$BindingFile)
}
Else{
	$CreateUpdateDeploymentAction.SetAttribute("BindingFile","")
}

# Update BizTalk reference info in patch XML

if($BizTalkReferences -ine $null){
	$CreateUpdateDeploymentAction.SetAttribute("AddBizTalkReferences",$BizTalkReferences)
}
Else{
	$CreateUpdateDeploymentAction.SetAttribute("AddBizTalkReferences","")
}

# Update host instances info in patch XML
if($HostInstances2Restart -ine $null){
	$CreateUpdateDeploymentAction.SetAttribute("hostInstancesToRestart",$HostInstances2Restart)
}
else{
	$CreateUpdateDeploymentAction.SetAttribute("hostInstancesToRestart","")
}


# Update application info to be uninstalled in patch XML
if($UninstallApplication -ine $null){
	$CreateUpdateDeploymentAction.SetAttribute("UninstallApplication",$UninstallApplication)
}
else{
	$CreateUpdateDeploymentAction.SetAttribute("UninstallApplication","")
}


# Update application info to be created in patch XML
if($CreateApplication -ine $null){
	$CreateUpdateDeploymentAction.SetAttribute("CreateApplication",$CreateApplication)
}
else{
	$CreateUpdateDeploymentAction.SetAttribute("CreateApplication","")
}

# Update application name thats needs to be stopped and started in patch XML
if($StopStartApplication -ine $null){
	$CreateUpdateDeploymentAction.SetAttribute("StopStartApplication",$StopStartApplication)
}
else{
	$CreateUpdateDeploymentAction.SetAttribute("StopStartApplication","")
}

$patch.AppendChild($CreateUpdateDeploymentAction)|Out-Null
$Patchxml.Save($PatchxmlFile)

#Set up connection to TFS Server and get version control
#$tfs = New-Object Microsoft.TeamFoundation.Client.TfsTeamProjectCollection($tfsServer,$Global:secureCred)
$Password="Jenk1ns@B@loise"
$pwd=$Password | ConvertTo-SecureString -asPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Global:Jenkinsmasteruser,$pwd)
$tfs = New-Object Microsoft.TeamFoundation.Client.TfsTeamProjectCollection($tfsServer,$credential)
$versionControlType = [Microsoft.TeamFoundation.VersionControl.Client.VersionControlServer]
$versionControlServer = $tfs.GetService($versionControlType)
$WIT = $tfs.GetService([Microsoft.TeamFoundation.WorkItemTracking.Client.WorkItemStore])

#Get Latest version of build sequence from repective branch.
#Delete the temp workspace
$wp=$versionControlServer.QueryWorkspaces("BuildSequenceUpdater",$Global:Jenkinsmasteruser,"svw-be-bldp001")
if($wp -ne $null)
{
	$wp.Delete()
	Remove-Item -Path filesystem::"$localFolder*" -Recurse -Force
	Write-Host "Existing workspace Deleted Successfully"
}
#Create a "workspace" and map a local folder to a TFS location
$workspace = $versionControlServer.CreateWorkspace("BuildSequenceUpdater",$Global:Jenkinsmasteruser)
$workingfolder = New-Object Microsoft.TeamFoundation.VersionControl.Client.WorkingFolder($tfsLocation,$localFolder)
$workspace.CreateMapping($workingFolder)
$filePath = $localFolder + $file
$workspace.Get() | Out-Null


#$str="select * from WorkItems where [Work Item type] = 'Patch Request' and State <> 'Closed' and Id='$patchNumber'"
$str="select * from WorkItems where [Work Item type] = 'Patch Request' and Id='$patchNumber'"
$Workitmes=$WIT.Query($str)

$patch=$Workitmes[0]
$pnum=$patch.Id
$state=$patch.State
$env=($patch.State -split " ")[0]
$appname=$patch.Fields["Platform"].value

$nodes.SetAttribute("State",$state)
$UpdateStateInPatchXML=$Patchxml.SelectSingleNode("//Patch[@Number='$patchNumber']")
$Patchxml.Save($PatchxmlFile)

Write-Host "==============================================================================================="
Write-Host "Release       :" $Release
Write-Host "Application   :" $appname
Write-Host "Patch Number  :" $pnum
Write-Host "State         :" $state
Write-Host "TFS Branch    :" $tfsbranch
Write-Host "Host Instances:" $HostInstances2Restart
Write-Host "===============Assemblies==============="
Write-Host $Assmeblies
Write-Host "==============================================================================================="


#read all defects and prepare th fix.txt file in the share location
$PatchFolderLocation=[String]::Format("{0}{1}\{2}\{3}",$global:PatchManifestRoot,$Release,$ApplicationName,$PatchFolder,$patchNumber)
$fixfile=[string]::Format('{0}\{1}_defectFixes.txt',$PatchFolderLocation,$patchNumber)
WritefixInfo $patch $fixfile

# Update Properties file
UpdatePatchproperties  $patchinfo $ApplicationName $tfsbranch $pnum
