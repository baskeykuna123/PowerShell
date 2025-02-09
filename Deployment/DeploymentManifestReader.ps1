# Enable -Verbose option
[CmdletBinding()]

param(
	[String]$BuildID, #the buildnumber as known in Tfs Build
	[String]$Environment,
	[String]$ServerLabel
)

# if $BuildID is not set, it means the script has been called without parameters, meaning it is done for testing, so assign test values
if (!$BuildID) {
	$BuildID="DEV_BrokerLegacy_20170802.1"
	$Environment="DCORP"
	$ServerLabel = "Front"
	$VerbosePreference = "Continue"
	#$VerbosePreference = "SilentlyContinue"
}

cls

Write-Verbose "BuildID= $BuildID"
Write-Verbose "Environment= $Environment"
Write-Verbose "ServerLabel=$ServerLabel"

#load WebDeployer function file
$currentDir = Split-Path (Split-Path $MyInvocation.MyCommand.Path -Parent) -Parent

. (join-path  -path $currentDir "SetGlobalParameters.ps1")
. (join-path  -path $currentDir "BIDeployerFunctions.ps1")
. (join-path  -path $currentDir "BIFunctions.ps1")

$LabelArray = @()
$BuildVersion = $BuildID.Split("_")[$BuildID.Split("_").Length - 1]
$BuildDefenitionname = $BuildID.Replace("_" + $BuildVersion , "")
$applicationName = $BuildDefenitionname.Split("_")[$BuildDefenitionname.Split("_").Length - 1]
#$PackageShare = Join-Path $PackageRoot -ChildPath $BuildDefenitionname | Join-Path -ChildPath $BuildVersion
$PackageShare=[String]::Format("{0}\{1}\{2}\{3}",$NewPackageRoot,$($BuildID.Split("_")[$BuildID.Split("_").Length - 2]),$BuildDefenitionname,$BuildVersion)
$deployManifestFileName = $Environment + "." + $applicationName + "DeploymentManifest.xml"
$deployManifestFile = "$PackageShare\$deployManifestFileName"
$deployManifest = [xml] (Get-Content $deployManifestFile)

$deployManifest.DeploymentDescription.ChildNodes | where {$_.NodeType -ne "Comment"} | foreach {
	$currentNode = $_
	switch($_.Name){
	
	  	"Folders" {
	  		$currentNode.ChildNodes | foreach{
				$folder2Create = $_.GetAttribute("foldername")
				Write-Verbose "Creating $($folder2Create) ..."
				CreateFolderOnShare -UNCPath $folder2Create
			}
	  	}
		
	  	"WebSites" {
			$currentNode.ChildNodes | foreach{
				$sourceProject = $_.GetAttribute("sourceProject")
				$webSiteName = $_.GetAttribute("IISWebSiteName")
				$deployAppData = $_.AppData.appdatadeploy
				$appDataDestination= $_.AppData.appdataDestination
				$destinationServerLabel = $_.DestinationServer.label
				
				if ($destinationServerLabel -ieq $ServerLabel){
					Write-Verbose "Deploying $($webSiteName) ..."
					
					WebDeployer -environment $Environment -sourceProject $sourceProject -websiteName $webSiteName `
						-buildnumber $BuildID -applicationType $_.Name -deployAppData $deployAppData -appDataDestination $appDataDestination 
				}
			}
		}
		
	  	"ConsoleApplications" {"Do ConsoleApplications"}
		
	  	"AfterDeployomentActions" {"Do AfterDeployomentActions"}
		
		default {"Action ""$_"" not defined."}
	}
}
