Param
(
[String]$Platform,
[String]$BuildVersion,
[String]$Environment
)
Clear-host

if (!$Platform){
    $Platform="esb"
    $BuildVersion="1.29.20181205.190051"
}

if($Platform -ieq "Esb"){
    $BuildOutputPath="\\svw-be-bldp001\E$\P.ESB"
    $masterSequence="Mercator.Esb.Master.DeploySequence.xml"
}
if($Platform -ieq "Eai"){
    $BuildOutputPath="\\svw-be-bldp001\E$\P.EAI"
    $masterSequence="Mercator.Esb.Master.DeploySequence.xml"
}

$PackageSource=Join-Path $BuildOutputPath -ChildPath $BuildVersion
$ESBparameterXML=join-path $PackageSource -childpath "ESBDeploymentParameters_Resolved.xml"
$DeploymentxmlDirectory=Join-Path $PackageSource -ChildPath "XML\"
$MasterDeploySequencePath=join-path $DeploymentxmlDirectory  -ChildPath $masterSequence


if($MasterDeploySequencePath){
	$MasterDeployXML=[xml](get-content filesystem::$MasterDeploySequencePath -Force )
	
	#$DeploySequencelist1= "Mercator.Esb.Service.Contract.NonLife.DeploySequence.xml"
	$DeploySequencelist=$MasterDeployXML.'Master.DeploySequence'.'DeployPackages.DeploySequence'.DeployPackage 
	
	foreach($DeploySequenceXML in $DeploySequencelist){

    	#clear All Variables for each application
		$systemConfiguration=""
		#Get Application Deployment Sequence XML and load XML sections
	    if ($DeploySequenceXML.Attributes.Count -eq 0){
	        $DeploySequenceXMLInnerText=$DeploySequenceXML
	    }
	    else{
	        $DeploySequenceXMLInnerText=$DeploySequenceXML.InnerText
	    }
		$DeploySequenceName=$DeploySequenceXMLInnerText -ireplace ".DeploySequence.xml",""
		$ApplicationDeploySequenceFile=[String]::Format("{0}{1}",$DeploymentxmlDirectory,$DeploySequenceXMLInnerText)	
		$DeploySequenceReader=[XML](gc Filesystem::$ApplicationDeploySequenceFile)
		$systemConfiguration=$DeploySequenceReader.'Package.DeploySequence'.SystemConfiguration
		
		#Deploying System Configuration
		if($systemConfiguration.childNodes){
			#DFS App shares
			$DFSAppFileShares=$systemConfiguration.Folders.RemoteFolders.DfsAppFileShare.path
			$DFSAppFileShareFolder=$($systemConfiguration.Folders.RemoteFolders.DfsAppFileShare).Name
			
			#DFS User shares
			$DFSUserFileShares=$systemConfiguration.Folders.RemoteFolders.DfsUserFileShare.path
			$DFSUserFileShareFolder=$($systemConfiguration.Folders.RemoteFolders.DfsUserFileShare).Name

			#ESB File Cluster Shares
			$ESBFileClusters=$systemConfiguration.Folders.RemoteFolders.EsbFileCluster.Path
			$ESBFileClusterFolder=$($systemConfiguration.Folders.RemoteFolders.EsbFileCluster).Name

			Write-Host "DFS app share    :"$DFSappShare
			Write-Host "ESB Cluster Share:"$EsbClusterShare

			Write-Host "===================================SYSTEM CONFIGURATION========================================================="
			if($DFSAppFileShares){
				Write-Host "--- *** DFS Shares *** ---"
                $ToBeReplaced=[String]::Format("{0}\{1}\SharedFolders\{2}",$BuildOutputPath,$BuildVersion,$DFSAppFileShareFolder)
				ForEach($DFSAppFileShare in $($DFSAppFileShares)){
					$DFSAppFileShare=$DFSAppFileShare.replace("\\localhost\AppFileShare","$ToBeReplaced")
							New-Item $DFSAppFileShare -ItemType Directory -Force | Out-Null
						}
			}
			
			if($DFSUserFileShares){
				Write-Host "--- *** DFS Shares *** ---"
                $ToBeReplaced=[String]::Format("{0}\{1}\SharedFolders\{2}",$BuildOutputPath,$BuildVersion,$DFSUserFileShareFolder)
				ForEach($DFSUserFileShare in $($DFSUserFileShares)){
					$DFSUserFileShare=$DFSUserFileShare.replace("\\localhost\UserFileShare","$ToBeReplaced")
							New-Item $DFSUserFileShare -ItemType Directory -Force | Out-Null
						}
			}

		   #Creating ESB cluster file 
		   if($ESBFileClusters){
		   		Write-Host "--- *** ESB File Cluster Shares *** ---"
            	$ToBeReplacedWith=[String]::Format("{0}\{1}\SharedFolders\{2}",$BuildOutputPath,$BuildVersion,$ESBFileClusterFolder)
		 		ForEach($ESBFileCluster in $($ESBFileClusters)){
		 			$ESBFileCluster=$ESBFileCluster.replace("\\%EsbFileCluster%","$ToBeReplacedWith")
		 			$LocalhostEsbCluster=$ESBFileCluster.replace("\\localhost\EsbFileCluster","$ToBeReplacedWith")
                    New-Item $LocalhostEsbCluster -ItemType Directory -Force -Verbose | Out-Null
		 		}
		 	}
			Write-Host "===================================SYSTEM CONFIGURATION========================================================="
		}
	}
}
