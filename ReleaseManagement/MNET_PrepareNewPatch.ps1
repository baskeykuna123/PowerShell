Param([String]$Release,[String]$patchNumber,[string]$Assmeblies,[String]$tfsbranch,$ApplicationName,$Startstop,$ClearSoss)

clear
if(!$patchNumber){
$Release="R31"
$patchNumber="381917"
$Assmeblies=@"
Mercator.Framework.dll 
"@
$tfsbranch="staging"
$ApplicationName="MyBaloiseClassic"
$ClearSoss="true"
$Startstop="true"
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

#variables
[string] $tfsServer = "http://tfs-be:9091/tfs/DefaultCollection"
$CurrentReleasePatchSourcefolder= join-path $global:NewPackageRoot -ChildPath "Patches\$Release"
$ApplicationPatchPropertiesFile=Join-path $Global:JenkinsPropertiesRootPath -Childpath "MNET_Patch.Properties"


#Connecting to TFS
$pwd=$Global:builduserPassword | ConvertTo-SecureString -asPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Global:builduser,$pwd)
$tfs = New-Object Microsoft.TeamFoundation.Client.TfsTeamProjectCollection($tfsServer,$credential)
$WIT = $tfs.GetService([Microsoft.TeamFoundation.WorkItemTracking.Client.WorkItemStore])

#$str="select * from WorkItems where [Work Item type] = 'Patch Request' and [PatchType] <> 'PlannedIteration' and State <> 'Closed' and Id='$patchNumber'"
$str="select * from WorkItems where [Work Item type] = 'Patch Request' and Id='$patchNumber'"
$Workitmes=$WIT.Query($str)

$patch=$Workitmes[0]
$pnum=$patch.Id
$state=$patch.State
$env=($patch.State -split " ")[0]
$appname=$patch.Fields["Platform"].value
$env="Icorp"
$env=$env.ToUpper()

$patchfolderName=[string]::Format('PR-{0}_{1}',$patchNumber,$appname)
$patchfolder=[string]::Format("{0}\{1}\{2}",$CurrentReleasePatchSourcefolder,$appname,$patchfolderName)

Write-Host "Patch folder:"$patchfolder
#creating patch Directory and fix file
New-Item -ItemType Directory -Path filesystem::$patchfolder -Force | Out-Null
$CurrentReleasePatchSourcefolder= join-path $global:NewPackageRoot -ChildPath "Patches\$Release"
$PatchXML=join-path $patchfolder -ChildPath "$($patchNumber).xml"
$fixfile=[string]::Format('{0}\{1}_defectFixes.txt',$patchfolder,$patchNumber)

#read all defects and prepare th fix.txt file in the share location
WritefixInfo $patch $fixfile

#Create XML Template
$PatchXMLContent=@"
<?xml version="1.0" encoding="UTF-8"?>
<Patch>
</Patch>
"@

If(Test-Path Filesystem::$PatchXML){
	Remove-Item Filesystem::$PatchXML -Force -Verbose
}
New-Item Filesystem::$PatchXML -ItemType File -Force | Out-Null
Set-Content Filesystem::$PatchXML -Value $PatchXMLContent -Force

$ReleaseManifest=[xml] (Get-Content filesystem::$global:ReleaseManifest)
$CurrentApplicationnode=$ReleaseManifest.SelectSingleNode("//Release/environment[@Name='ICORP']/Application[@Name='$ApplicationName']")
$MNetBaseVersion=$(($CurrentApplicationnode.Version).split("."))[0]+'.'+$(($CurrentApplicationnode.Version).split("."))[1]
$ReadPatchManifest=[XML](gc Filesystem::$PatchXML)
$patch=$ReadPatchManifest.SelectSingleNode("//Patch")
if($patch -ne $null){
	$patch.SetAttribute("State",$state)
	$patch.SetAttribute("ApplicationBaseVersion",$MNetBaseVersion)
	ForEach($assembly in $Assmeblies.Split("`n")){
		if(($ReadPatchManifest.SelectSingleNode("//Patch/Assembly[@Name='$assembly']")) -eq $null){
			$CreateAssemblyElement=$ReadPatchManifest.CreateElement("Assembly")
			$CreateAssemblyElement.SetAttribute("Name",$assembly)
			$CreateDeploymentActionElement=$ReadPatchManifest.CreateElement("DeploymentActions")
			$patch.AppendChild($CreateAssemblyElement) | Out-Null
			
		}
	}
	$CreateDeploymentActionElement.SetAttribute("StartStop","$Startstop")
	$CreateDeploymentActionElement.SetAttribute("ClearSoss","$ClearSoss")
	$patch.AppendChild($CreateDeploymentActionElement) | Out-Null
}	
$ReadPatchManifest.Save($PatchXML)

#checking if Patch is planned,else abort Patch Preparation
#if($state -ine "*planned"){
#	Write-Host "ERROR : Patch - $patchNumber Is not planned. Patch Preparation aborted"
#	Exit 1
#}

$newVersion=ChangeVersion $($CurrentApplicationnode.Version) 4 $env
$CurrentApplicationnode.Version=$newVersion
$ReleaseManifest.Save($global:ReleaseManifest)

#updates the properties files
function UpdatePatchproperties($filepath,$node,$ApplicationName,$tfsbranch,$Pnumber){
	foreach($line in [System.IO.File]::ReadAllLines($filepath)){
		$propfile+= ConvertFrom-StringData $line
	}

	$vername=$ApplicationName+"_Version"
	$propfile["PatchNumber"]=$Pnumber
	$propfile["TFSBranch"]=$tfsbranch
	$propfile["GlobalReleaseVersion"]=$node.ParentNode.GlobalReleaseVersion
	$propfile["MercatorBuildVersion"]=$node.ParentNode.MercatorBuildVersion
	$propfile["$vername"]=$newVersion
	$propfile["Release"]=$Release
	#$propfile["ApplicationsToBuild"]=$applicationsToBuild

	$propfile.Keys|%{$propdata+="$_="+$propfile.Item($_)+"`r`n"}
	Set-Content filesystem::$filepath -Value $propdata
}


Write-Host "==============================================================================================="
Write-Host "Release       :" $Release
Write-Host "Application   :" $appname
Write-Host "Patch Number  :" $patchNumber
Write-Host "State         :" $state
Write-Host "TFS Branch    :" $tfsbranch
Write-Host "Environment   :" $env
Write-Host "===============Assemblies==============="
Write-Host $Assmeblies
Write-Host "==============================================================================================="


$xml = [xml](Get-Content Filesystem::$global:ReleaseManifest )
$node=$xml.SelectSingleNode("/Release/environment[@Name='ICORP']/Application[@Name='$ApplicationName']")
UpdatePatchproperties  $ApplicationPatchPropertiesFile $node $ApplicationName $tfsbranch $pnum
