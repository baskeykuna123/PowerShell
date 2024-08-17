Param([String]$Release,[String]$patchNumber,[string]$Assmeblies,[String]$ApplicationName,$tfsbranch,$applicationsToBuild,$hostInstances)

clear
if(!$patchNumber){
$Release="R32"
$ApplicationName="ESB"
$patchNumber="393777"
$Assmeblies=@"
Baloise.Esb.Service.Claim.NonLife.Vehicle.Rdr.Get.Messaging.dll#true#2.0
"@
$tfsbranch="Production/R32.0"
}

#loading Function
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	

$UpdateVersionScriptfile="$ScriptDirectory\ReleaseManagement\UpdateReleaseVersion.ps1"

#adding TFS Asseblies
Add-Type -AssemblyName System.web
if ((Get-PSSnapIn -Name Microsoft.TeamFoundation.PowerShell -ErrorAction SilentlyContinue) -eq $null)
{
    Add-PSSnapin Microsoft.TeamFoundation.PowerShell -ErrorAction SilentlyContinue
}

# get an instance of TfsTeamProjectCollection
#[void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.TeamFoundation.WorkItemTracking.Client") 
#[void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.TeamFoundation.Client")  
#[void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.TeamFoundation.VersionControl.Client")  


#updates the properties files
function UpdatePatchproperties($filepath,$node,$ApplicationName,$tfsbranch,$Pnumber){
	foreach($line in [System.IO.File]::ReadAllLines($filepath)){
		$propfile+= ConvertFrom-StringData $line
	}

	$vername=$ApplicationName+"Version"
	#$propfile["PatchNumber"]=$Pnumber
	$propfile["TFSBranch"]=$tfsbranch
	$propfile["GlobalReleaseVersion"]=$node.ParentNode.GlobalReleaseVersion
	#$propfile["MercatorBuildVersion"]=$node.ParentNode.MercatorBuildVersion
	$propfile["$vername"]=$node.Version
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
			$fixinfo=[System.Web.HttpUtility]::HtmlDecode($fixinfo)
			Add-Content -Path  filesystem::$fixfile -Value $fixinfo 
			Add-Content -Path  filesystem::$fixfile "======================================"
		}
	}
}


[string] $tfsServer = "http://tfs-be:9091/tfs/DefaultCollection"
#$patchmanifest="D:\Nolio\Repository\GlobalPatchmanifest.xml"
$Patchxml=[XML](Get-Content filesystem::$global:PatchManifest)
$patchSharePath=join-path ($Patchxml.Release.source) -ChildPath  $Release
$patchinfo=Join-path $Global:JenkinsPropertiesRootPath -Childpath "IAP_Esb_Patch.Properties"


#Connecting to TFS

$pwd=$Global:builduserPassword | ConvertTo-SecureString -asPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Global:builduser,$pwd)
$tfs = New-Object Microsoft.TeamFoundation.Client.TfsTeamProjectCollection($tfsServer,$credential)
$WIT = $tfs.GetService([Microsoft.TeamFoundation.WorkItemTracking.Client.WorkItemStore])


write-host "Updating Patch Requests"
$patches=($Patchxml.Release.Application | where {$_.Name -ieq "ESB"}).PatchRequest | foreach {
	$WK=$WIT.GetWorkItem($_.Number)
	 $_.State=$WK.State
}

#$str="select * from WorkItems where [Work Item type] = 'Patch Request' and [PatchType] <> 'PlannedIteration' and State <> 'Closed' and Id='$patchNumber'"
#$str="select * from WorkItems where [Work Item type] = 'Patch Request' and State <> 'Closed' and Id='$patchNumber'"
$str="select * from WorkItems where [Work Item type] = 'Patch Request' and Id='$patchNumber'"
$Workitmes=$WIT.Query($str)

$patch=$Workitmes[0]
$pnum=$patch.Id
$state=$patch.State
$env=($patch.State -split " ")[0]
$appname=$patch.Fields["Platform"].value


if($Workitmes.Count -eq 0){
$Patchxml.Save($global:PatchManifest)
	Write-Host "Patch not found...please check the patch number"
	EXIT 1
}


if($patch.State -inotlike "*Planned"){
	$Patchxml.Save($global:PatchManifest)
	Write-Host "$($patch.Id) is not set to the planned state. Patch Creation aborted........"
	EXIT 1
}



Switch($env){
		"ICORP" { $preenv="DCORP"}
		"ACORP" { $preenv="ICORP"}
		"PCORP" { $preenv="ACORP"}   
}

$patchfolderName=[string]::Format('PR-{0}_{1}',[string]$patch.Id,$appname)
$patchfolder=[string]::Format('{0}\{1}\{2}',$patchSharePath,$env,$patchfolderName)
$fixfile=[string]::Format('{0}\{1}_defectFixes.txt',$patchfolder,$pnum)

Write-Host "==============================================================================================="
Write-Host "Release       :" $Release
Write-Host "Application   :" $appname
Write-Host "Patch Number  :" $pnum
Write-Host "State         :" $state
Write-Host "TFS Branch    :" $tfsbranch
Write-Host "Host Instances:" $hostInstances
Write-Host "===============Assemblies==============="
Write-Host $Assmeblies
Write-Host "==============================================================================================="


#creating patch Directory and fix file
New-Item -ItemType Directory -Path filesystem::$patchfolder -Force | Out-Null
#read all defects and prepare th fix.txt file in the share location
WritefixInfo $patch $fixfile

#adding New Patch Node in the Manifest

$patch=$Patchxml.SelectSingleNode("//Release/Application[@Name='$ApplicationName']/PatchRequest[@Number='$pnum']")
if($patch -eq $null){
	$nodes=$Patchxml.SelectSingleNode("//Release/Application[@Name='$appname']")
	$new=$Patchxml.CreateElement("PatchRequest")
	$new.SetAttribute("Number",$pnum)
	$new.SetAttribute("State",$state)
	$nodes.AppendChild($new) | Out-Null
}
$patch=$Patchxml.SelectSingleNode("//Release/Application[@Name='$ApplicationName']/PatchRequest[@Number='$pnum']")

$asmb=$Assmeblies.Split("`r`n")
$asmb | foreach {
	$dll=[System.IO.Path]::GetFileNameWithoutExtension(($_ -split "#")[0]) +".dll"
	if($dll -notlike "*.dll" ){
		$dll=$dll+".dll"
	}

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
	if(($Patchxml.SelectSingleNode("//PatchRequest[@Number='$pnum']/Assembly[@Name='$dll']")) -eq $null){
		$new=$Patchxml.CreateElement("Assembly")
		$new.SetAttribute("Name",$dll)
		$new.SetAttribute("AddtoGAC","true")
		$new.SetAttribute("AddtoBiztalkResouces",$addbts)
		$new.SetAttribute("ver",$Ver)
		$patch.AppendChild($new) | Out-Null
	}
}

If($hostInstances){
	$($hostInstances.split(","))|%{
		$new=$Patchxml.CreateElement("HostInstance")
		$new.SetAttribute("Name",$_)
		$patch.AppendChild($new) | Out-Null
	}
}

$HostInstances=$Patchxml.SelectSingleNode("//Release/Application[@Name='$ApplicationName']/PatchRequest[@Number='$pnum']/HostInstance")

$Patchxml.Save($global:PatchManifest)

#& Filesystem::$UpdateVersionScriptfile "ICORP" "MercatorESB" "upgrade" "application" "patch"
$xml = [xml](Get-Content Filesystem::$global:ReleaseManifest )
$node=$xml.SelectSingleNode("/Release/environment[@Name='ICORP']/Application[@Name='MercatorESB']")
UpdatePatchproperties  $patchinfo $node $ApplicationName $tfsbranch $pnum

