Clear;
$ApplicationType=""
if(!$ApplicationType){
	$ApplicationType="MFT"
}
$MasterDeployXML="C:\Users\CH36107\Desktop\Mercator.Esb.Master_Kurt.DeploySequence.xml"
$ReadMasterDeployXML=[XML](gc $MasterDeployXML)
$Prerequisites=$ReadMasterDeployXML.'Master.DeploySequence'.SelectSingleNode("//Prerequisites")
$ApplicationDeploySequencesList=$ReadMasterDeployXML.'Master.DeploySequence'.SelectSingleNode("//DeployPackages.DeploySequence")

#Pre-requisites Installation as per the input (application type)
Write-Host "----------- ** PRE-REQUISITES INSTALLATION ** -----------"
Write-Host `n
ForEach($Prerequisite in $($Prerequisites.Prerequisite)){
	$PrerequisiteName=$Prerequisite.name
	Write-Host "Prerequisite :"$PrerequisiteName
	if($($Prerequisite.installOnServerType) -ieq "BizTalk,Mft"){
		Write-Host "Check installOnServerType is verified. Please proceed with the installation on $ApplicationType Servers"
		If(($ApplicationType -ieq "BizTalk") -or ($ApplicationType -ieq "Mft")){
			Write-Host "$PrerequisiteName installation on - $ApplicationType Servers is in progress.."
		}
		Write-Host `n
	}
	else{
		Write-Host "Installation to be done only on BizTalk Servers"
		if($ApplicationType -ne "Mft"){
			Write-Host "$PrerequisiteName installation on - BizTalk Servers is in progress.."
		}
		Write-Host `n
	}
}

#Pre-requisites Installation as per the input (application type)
Write-Host "----------- ** BIZTALK/MFT APPLICATION INSTALLATION ** -----------"
Write-Host `n
ForEach($DeploySequence in $($ApplicationDeploySequencesList.DeployPackage)){
	#$CheckinstallOnServerTypeFlag=$($ApplicationDeploySequencesList.DeployPackage) | ?{$_.installOnServerType -ieq "BizTalk,Mft"}
	if($($DeploySequence.installOnServerType) -ieq "BizTalk,Mft"){
		If(($ApplicationType -ieq "BizTalk") -or ($ApplicationType -ieq "Mft")){
			Write-Host "DEPLOY SEQUENCE:"$($DeploySequence.'#text')
			Write-Host "Check installOnServerType for the application installation is verified. Please proceed with the installation on $ApplicationType Servers"
			Write-Host "Application installation on - $ApplicationType Servers is in progress.."
		}
	}
	else{
		Write-Host "DEPLOY SEQUENCE:"$DeploySequence
		Write-Host "Installation to be done only on BizTalk Servers"
		if($ApplicationType -ne "Mft"){
			Write-Host "Application installation on - BizTalk Servers is in progress.."
		}
	}
	Write-Host `n
}	




