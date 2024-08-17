PARAM ($TFSurl, $ProjectName, $Environment, $PatchNumber, $PatchStatus, $ApplicationDeploymentStatus)
	
#Testing Parametes
 if($Environment=ICORP)
 {
	$TFSurl=http://svw-be-tfsp002:9192/tfs/DefaultCollection/Baloise
	$ProjectName=Baloise
	$PatchNumber=
	$PatchStatus=ICORP Planned
	$ApplicationDeploymentStatus=Deployed
 }


if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	

}
{
if($ApplicationDeploymentStatus=Deployed){

	$PatchStatus=3
}
$DeploymentInfo="<tr><th>Planned PatchNumber</td><td>$($Planned PatchNumber)</td></tr>"

}

$PatchStatus=@{
	1="ICORP Requested"
	2="ICORP Planned"
	3="ICORP Deployed"
}

	Write-Host "ICORP Deployed"

}
	
	



