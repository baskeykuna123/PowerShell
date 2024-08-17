param($ApplicationNames,$ReleaseBranchName,$Version,$TfsServerUrl)
#$ApplicationNames="Esb"
#$ApplicationNames="Backend,CentralDataStore,Framework,MyBaloiseWeb"
#$ApplicationNames="Cleva,Database,DMS,DMSFw,Etl,Hexaware,Mainframe,MBC,MBCFw,Oms,Portal,PortalFramework,Talk,Testware"
#$productionBranchName="R22"
#$Version="D13/01/2017 21:00:00"
#$TfsServerUrl="http://svw-me-source01:9091/tfs/DefaultCollection/"

#loading Function
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	

$userid = "prod\builduser"
$pwd = "Wetzel01" | ConvertTo-SecureString -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential ($userid,$pwd)
foreach ($app in $ApplicationNames.Split(','))
{
	$sourceBranch = [string]::Format("$/Baloise/{0}/Staging",$app)
	$TargetHotfixBranch = [string]::Format("$/Baloise/{0}/Production/{1} HotFix",$app,$ReleaseBranchName)
	$TargetBranch = [string]::Format("$/Baloise/{0}/Production/{1}.0",$app,$ReleaseBranchName)
	$server = $tfs = New-Object Microsoft.TeamFoundation.Client.TfsTeamProjectCollection($tfsServer,$credential)
	$vcServer = $server.GetService([Microsoft.TeamFoundation.VersionControl.Client.VersionControlServer]);

	if ($Version -ne "")
	{
		$changesetId = $vcServer.CreateBranch($sourceBranch,$TargetHotfixBranch,[Microsoft.TeamFoundation.VersionControl.Client.DateVersionSpec]::ParseSingleSpec($Version,$null),$null,"New Production Release Hotfix Branch $productionBranchName HotFix from $sourceBranch",$null,$null,$null)
	}
	else {
		$changesetId = $vcServer.CreateBranch($sourceBranch,$TargetHotfixBranch,[Microsoft.TeamFoundation.VersionControl.Client.VersionSpec]::Latest,$null,"New Production Release Hotfix Branch $productionBranchName HotFix from $sourceBranch",$null,$null,$null)
		Write-Host "NO SPECIFIC VERSION Mentioned.. Creating branch with Latest Version"

	}

	Write-Host "Branch $TargetHotfixBranch  created with ChangesetID: $changesetId"
	$changesetId = $vcServer.CreateBranch($TargetHotfixBranch,$TargetBranch,[Microsoft.TeamFoundation.VersionControl.Client.VersionSpec]::Latest,$null,"New Rlease Branch $productionBranchName from $productionBranchName HotFix",$null,$null,$null)
	Write-Host "Branch $TargetBranch  created with ChangesetID: $changesetId"
}
