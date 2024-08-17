Param($BuildNumber,$EsbOrEai)

if(!$BuildNumber){
	$BuildNumber="1.29.20181130.190047"
	$EsbOrEai="ESB"
}


#Importing SQL modules for SQL commands to the Version database
Import-Module sqlps -DisableNameChecking
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	


if($EsbOrEai -ieq "Esb"){
    $BuildOutputPath="e:\P.ESB"
    $masterSequence="Mercator.Esb.Master.DeploySequence.xml"
}
else{
    $BuildOutputPath="e:\P.EAI"
	$masterSequence="Mercator.Esb.Master.DeploySequence.xml"
    
}
$PackageSource=Join-Path $BuildOutputPath -ChildPath $BuildNumber
$ESBparameterXML=join-path $BuildOutputPath -childpath "ESBDeploymentParameters_Resolved.xml"
$DeploymentxmlDirectory=Join-Path $PackageSource -ChildPath "XML\"

$params=[xml](get-content $ESBparameterXML)
$params.Parameters.EnvironmentParameters.Environment | foreach {
	$Environment=$_.Name 
	$MasterSequeneceFilename=[string]::Format("{0}"."{1}",$Environment,$masterSequence)
	$MasterDeploySequencePath=join-path $DeploymentxmlDirectory  -ChildPath $MasterSequeneceFilename

	if($MasterDeploySequencePath){
		$MasterDeployXML=[xml](get-content filesystem::$MasterDeploySequencePath -Force )
		$DeploySequencelist=$MasterDeployXML.'Master.DeploySequence'.'DeployPackages.DeploySequence'.DeployPackage 
		foreach($DeploySequenceXML in $DeploySequencelist){
    	#clear All Variables for each application
		$BiztalkApplicationName=$DeploySequenceName=""
		#Get Application Deployment Sequence XML and load XML sections
	    if ($DeploySequenceXML.Attributes.Count -eq 0){
	        $DeploySequenceXMLInnerText=$DeploySequenceXML
	    }
	    else{
	        $DeploySequenceXMLInnerText=$DeploySequenceXML.InnerText
	    }
		$DeploySequenceName=$DeploySequenceXMLInnerText -ireplace ".DeploySequence.xml",""
		$ApplicationDeploySequenceFile=[String]::Format("{0}{1}.{2}",$DeploymentxmlDirectory,$Environment,$DeploySequenceXMLInnerText)	
		$DeploySequenceReader=[XML](gc Filesystem::$ApplicationDeploySequenceFile)
		$systemConfiguration=$DeploySequenceReader.'Package.DeploySequence'.SystemConfiguration
		}
	}
	}
#		#Deploying System Configuration
#		if($systemConfiguration.childNodes){
#			$DFSAppFileShares=$systemConfiguration.SelectNodes("//Folders/RemoteFolders/DfsAppFileShare/Path")
#			$ESBFileClusters=$systemConfiguration.SelectNodes("//Folders/RemoteFolders/EsbFileCluster/Path")
#			Write-Host "===================================SYSTEM CONFIGURATION========================================================="
#			if($DFSAppFileShares){
#				Write-Host "--- *** DFS Shares *** ---"
#				ForEach($DFSAppFileShare in $($DFSAppFileShares.innerText)){
#					
#						if(-not (Test-Path $DFSAppFileShare)){
#							Write-Host "CREATE : " $DFSAppFileShare
#			        		New-Item $DFSAppFileShare -ItemType Directory -Force | Out-Null
#						}
#				}
#			}
#
#			# Creating ESB cluster file 
#			if($ESBFileClusters){
#				Write-Host "--- *** ESB File Cluster Shares *** ---"
#				ForEach($ESBFileCluster in $($ESBFileClusters.innerText)){
#						if(-not (Test-Path $ESBFileCluster)){
#							Write-Host "CREATE : " $ESBFileCluster
#			        		New-Item $ESBFileCluster -ItemType Directory -Force  | Out-Null
#						}
#				}
#			}
#			Write-Host "===================================SYSTEM CONFIGURATION========================================================="
#	}