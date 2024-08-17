Param($ApplicationName,[String]$Release,[String]$patchNumber,[string]$Assemblies,[String]$tfsbranch,$ClearSoss,$Startstop,$hostInstances,$ImportBinding,$StartStopESBApplications)

clear
if(!$patchNumber){
$Release="R31"
$patchNumber="393633"
$Assemblies=@"
Mercator.MercatorLine.Policy.Bdc.dll
Mercator.Peach.MercatorLine.Wsc.dll
"@
$tfsbranch="staging"
$ApplicationName="MyBaloiseClassic"
$ClearSoss="true"
$Startstop="true"
$ImportBinding="false"
$hostInstances="BizTalkSending_Sync,BizTalkReceiving_Sync,BizTalkProcessing_Sync"
$StartStopESBApplications=""
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

$CurrentReleasePatchSourcefolder= join-path $global:NewPackageRoot -ChildPath "Patches\$Release"
$ApplicationPatchPropertiesFile=Join-path $Global:JenkinsPropertiesRootPath -Childpath "ESB_Patch.Properties"

#Getting the Patch Info from TFS
#checking if Patch is planned,else abort Patch Preparation

$WIService=Connect2TFSWorkitems
#$str="select * from WorkItems where [Work Item type] = 'Patch Request' and [PatchType] <> 'PlannedIteration' and State <> 'Closed' and Id='$patchNumber'"
$TFSQuery="select * from WorkItems where [Work Item type] = 'Patch Request' and Id='$PatchNumber'"
$TFSPatchInfo=$WIService.Query($TFSQuery)
$TFSPatchInfo=$TFSPatchInfo[0]
if($TFSPatchInfo){
	if($Patchinfo.State -ine "*planned"){
		Write-Host "ERROR : Patch - $patchNumber Is not planned. Patch Preparation aborted"
		#Exit 1
	}
	[hashtable]$Patchinfo = @{}
	$Patchinfo.Add('ID',$TFSPatchInfo.Id)
	$Patchinfo.Add('Environment',((($($TFSPatchInfo.State) -split " ")[0]).ToUpper()))
	$Patchinfo.Add('Application',$TFSPatchInfo.Fields["Platform"].value)
	$Patchinfo.Add('State',$TFSPatchInfo.State)
	$patchfolder=[string]::Format("{0}\{1}\PR-{2}_{1}",$CurrentReleasePatchSourcefolder,$Patchinfo.Application,$Patchinfo.ID)
	$Patchinfo.Add('Folder',$patchfolder)
	$fixfile=[string]::Format('{0}\{1}_defectFixes.txt',$Patchinfo.Folder,$Patchinfo.ID)
	$Patchinfo.Add('FixInfoFile',$fixfile)
	$PatchXML=join-path $Patchinfo.Folder -ChildPath "$($patchNumber).xml"
	$Patchinfo.Add('PatchXML',$PatchXML)
	#creating patch Directory and fix file
	New-Item -ItemType Directory -Path filesystem::$patchfolder -Force | Out-Null
	#Create XML Template
	Remove-Item Filesystem::$PatchXML -ErrorAction SilentlyContinue
	[System.XML.XMLDocument]$oXMLDocument=New-Object System.XML.XMLDocument
	[System.XML.XMLElement]$oXMLRoot=$oXMLDocument.CreateElement("Patch")
	$oXMLDocument.appendChild($oXMLRoot)
	# Add a Attribute
	$oXMLRoot.SetAttribute("Number",$Patchinfo.ID)
	$oXMLRoot.SetAttribute("State",$Patchinfo.State)
	$oXMLDocument.Save($PatchXML)
	WritefixInfo -WorkItemInfo $WIService -TFSPatchInfo $TFSPatchInfo -fixfile $fixfile
	
 }
else{
	Write-Host "ERROR : Patch Number not found in TFS : $PatchNumber"
	Exit 1
}





#version updating , to be handled after new version implementation
$ReleaseManifest=[xml] (Get-Content filesystem::$global:ReleaseManifest)
$CurrentApplicationnode=$ReleaseManifest.SelectSingleNode("//Release/environment[@Name='ICORP']/Application[@Name='$ApplicationName']")
$MNetBaseVersion=$(($CurrentApplicationnode.Version).split("."))[0]+'.'+$(($CurrentApplicationnode.Version).split("."))[1]
$newVersion=ChangeVersion $($CurrentApplicationnode.Version) 4 $($Patchinfo.Environment)
$CurrentApplicationnode.Version=$newVersion
$ReleaseManifest.Save($global:ReleaseManifest)

#Adding Additional attributes on XML based on type of the application /Patch 
[string]$filpath=$($Patchinfo.PatchXML)
[xml]$PatchInfoXML=[System.IO.File]::ReadAllLines($($Patchinfo.PatchXML))
$patch=$PatchInfoXML.SelectSingleNode("//Patch")
$patch.SetAttribute("ApplicationBaseVersion",$MNetBaseVersion)

$CreateDeploymentActionElement=$PatchInfoXML.CreateElement("DeploymentActions")
if($application -ilike "*ESB"){
	ForEach ($line in ($($Assemblies.split("`r`n"))).Trim()){
		if($line -ne ""){
			$ASsembly=$line.Split('#')[0]
			$AddResource=""
			if($line.Split('#')[1] -ine $null){
				$AddResource=$line.Split('#')[1]
			}
			$version=""
			if($line.Split('#')[2] -ine $null){
				$version=$line.Split('#')[2]
			}
			$CreateAssemblyElement=$PatchInfoXML.CreateElement("Assembly")
			$CreateAssemblyElement.SetAttribute("Name",$ASsembly)
			$CreateAssemblyElement.SetAttribute("AddGac",'true')
			$CreateAssemblyElement.SetAttribute("AddResource",$AddResource)
			$CreateAssemblyElement.SetAttribute("Version",$version)
			$patch.AppendChild($CreateAssemblyElement) | Out-Null
		}
	}
$CreateDeploymentActionElement.SetAttribute("ImportBinding",$ImportBinding)
$CreateDeploymentActionElement.SetAttribute("StartStopHostInstances",$hostInstances)
$CreateDeploymentActionElement.SetAttribute("StartStopApplication",$StartStopESBApplications)
$patch.AppendChild($CreateDeploymentActionElement) | Out-Null	
}
if($ApplicationName -ilike "MNET" -or $ApplicationName -ilike "MyBaloiseClassic"){
ForEach($assembly in $Assemblies.Split("`n")){
	$CreateAssemblyElement=$PatchInfoXML.CreateElement("Assembly")
	$CreateAssemblyElement.SetAttribute("Name",$assembly)
	$patch.AppendChild($CreateAssemblyElement) | Out-Null
}
$CreateDeploymentActionElement.SetAttribute("StartStop",$Startstop)
$CreateDeploymentActionElement.SetAttribute("ClearSoss",$ClearSoss)	
$patch.AppendChild($CreateDeploymentActionElement) | Out-Null	
}

#$PatchInfoXML.Save($($Patchinfo.PatchXML))



#updates the properties files
$application=$Patchinfo.Application
$PropertiesFileName=[string]::Format("{0}_{1}_Patch.properties",$Release,$application)
$PatchPropertiesfilepath=Join-Path $Global:JenkinsPropertiesRootPath -ChildPath $PropertiesFileName
$propfile=@{}
#$propfile=getproperties -FilePath $PatchPropertiesfilepath
$propfile["PatchNumber"]=$Pnumber
$propfile["BaseVersion"]=$newVersion.Split[0]+"."+$newVersion.Split[1]
$propfile["TFSBranch"]=$tfsbranch
$propfile["GlobalReleaseVersion"]=$node.ParentNode.GlobalReleaseVersion
$propfile["MercatorBuildVersion"]=$node.ParentNode.MercatorBuildVersion
$propfile["Version"]=$newVersion
$propfile["Release"]=$Release
$propfile=getproperties -FilePath $PatchPropertiesfilepath -Properties $propfile
DisplayProperties $propfile

Write-Host "==============================================================================================="
Write-Host "Release       : $Release"
Write-Host "Application   : $($Patchinfo.Application)"
Write-Host "Patch Number  : $patchNumber"
Write-Host "State         : $($Patchinfo.Status)"
Write-Host "TFS Branch    : $tfsbranch"
Write-Host "Environment   : $($Patchinfo.Environment)"
Write-Host "===============Assemblies======================================================================"
Write-Host $Assemblies
Write-Host "==============================================================================================="

