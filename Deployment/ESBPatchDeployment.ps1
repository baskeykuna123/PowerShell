Param
(
[String]$ServerType,
[String]$CoreApplication,
[String]$Environment
)
Clear-Host

# Default
if(!$ServerType)
{
$ServerType="Admin"
$CoreApplication='Esb'
$Environment='ICORP'
}

# loading Function
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop

$XML=[XML](Get-Content FileSystem::$global:PatchManifest)

$Release=$XML.Release.Release
$PNum=$XML.Release.SelectSingleNode("//Application[@Name='$CoreApplication']").PatchRequest
$PNum=$PNum | ?{$_.State -eq "$Environment Planned"}|select Number
$PatchRequestNumber=$($PNum.Number)

$PatchState=$XML.Release.SelectSingleNode("//Application[@Name='$CoreApplication']/PatchRequest[@Number='$PatchRequestNumber']").State
$AppName=$XML.Release.SelectSingleNode("//Application[@Name='$CoreApplication']/PatchRequest[@Number='$PatchRequestNumber']").Assembly.ApplicationName
$AssemblyAdd2Gac=$XML.Release.SelectSingleNode("//Application[@Name='$CoreApplication']/PatchRequest[@Number='$PatchRequestNumber']").Assembly.AddtoGAC
$AssemblyAdd2BiztalkResources=$XML.Release.SelectSingleNode("//Application[@Name='$CoreApplication']/PatchRequest[@Number='$PatchRequestNumber']").Assembly.AddtoBiztalkResources		
$ESBAssemblyRootPath=[String]::Format("{0}\{1}\{2}",$global:ESBDeploymentRootFolder,$CoreApplication,$AppName)
$Assemblies=$XML.Release.SelectSingleNode("//Application[@Name='$CoreApplication']/PatchRequest[@Number='$PatchRequestNumber']").Assembly.Name
$AssemblyPath=(Get-ChildItem -recurse $ESBAssemblyRootPath  |?{$_.Name -ilike $Assemblies}).FullName
$ReleaseDeliverablePath=[String]::Format("\\balgroupit.com\appl_data\bbe\Transfer\B&I\ReleasedDeliverables\{0}\{1}\",$Release,$Environment)
$PatchFolderName='PR-'+$PatchRequestNumber+'_'+$CoreApplication
$ApplicationPatchFolderPath= [String]::Format("{0}{1}\{2}",$ReleaseDeliverablePath,$PatchFolderName,$CoreApplication)

if($PNum){
Write-Host "========================================================================"
Write-Host "Patch Number is  :" $PatchRequestNumber
Write-Host "Patch state is 	 :" $PatchState
Write-Host "Patch Folder Path:" $ReleaseDeliverablePath
Write-Host "========================================================================"
}
else{
	Write-Host "Patch Request Number is not found. Kindly check if it exists."
	Write-Host "Aborting the Operation"
	Exit
}

$PatchFolder = gci $ReleaseDeliverablePath | where{($_.PSIsContainer) -and ($_.Name -like $PatchFolderName)}

if($PatchState -ieq "$Environment Planned"){
	if($PatchFolder)
	{
		Copy-Item $ApplicationPatchFolderPath -Destination $global:ESBDeploymentRootFolder -Recurse -Force -Verbose	
		
		$Add_GACBatFile=[String]::Format("{0}\{1}\{2}\Deployment\Add2Gac.bat",$global:ESBDeploymentRootFolder,$CoreApplication,$AppName)
		$Add_ResourceBatFile=[String]::Format("{0}\{1}\{2}\Deployment\AddBtsResources.bat",$global:ESBDeploymentRootFolder,$CoreApplication,$AppName)

		Write-Host "========================================================================================="
		Write-Host "AssemblyPath is - $AssemblyPath"
		Write-Host "========================================================================================="
		
		Write-Host "Adding assembly to GAC.."
		Add-GAC -ApplicationName $AppName -AssemblyPath $AssemblyPath
		
		if($ServerType -ieq "Admin"){
			if($AssemblyAdd2BiztalkResources -ieq "true"){
				Write-Host "Adding Biztalk resources..."
				Add-Resources -ApplicationName $AppName -ResourcePath $AssemblyPath
			}
			
			# Restarting Host Instances
			$HostInstances=$XML.Release.SelectSingleNode("//Application[@Name='$CoreApplication']/PatchRequest[@Number='$PatchRequestNumber']").HostInstance
			$HostInstances=$HostInstances.Trim() -split '\r?\n'
			ForEach($Instance in $HostInstances)
			{
				$Instance=$Instance.Trim()
				if($Instance -ne ""){
					Stop-HostInstance $Instance 
					Start-HostInstance $Instance
				}
				else{
				Continue;
				}
			}
		}		
	}
	else
	{
		Write-Host "Patch folder does not exist. Aborting the operation."
		Exit 
	}
}
else{
	Write-Host "The given patch request is not in Icorp planned state"
	Write-Host "Patch Request - $PatchRequestNumber is in"'"'$PatchState'"' "State".
}