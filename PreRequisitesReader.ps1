# Enable -Verbose option
[CmdletBinding()]

param(
	[String]$BuildID, #the buildnumber as known in Tfs Build
	[String]$Environment,
	[String]$ServerLabel
)

# if $BuildID is not set, it means the script has been called without parameters, meaning it is done for testing, so assign test values
if (!$BuildID) {
	$BuildID="Staging_BrokerLegacy_20170906.2"
	$Environment="ACORP"
	$ServerLabel = "Front"
	$VerbosePreference = "Continue"
	#$VerbosePreference = "SilentlyContinue"
}

cls

Write-Verbose "BuildID= $BuildID"
Write-Verbose "Environment= $Environment"
Write-Verbose "ServerLabel=$ServerLabel"

#load WebDeployer function file
$currentDir = Split-Path $MyInvocation.MyCommand.Path

. (join-path  -path $currentDir "fnSetGlobalParameters.ps1")
. (join-path  -path $currentDir "fnIO.ps1")
. (join-path  -path $currentDir "fnUtilities.ps1")
. (join-path  -path $currentDir "fnDscIIS.ps1")
. (join-path  -path $currentDir "fnDscRegistry.ps1")

$LabelArray = @()
$BuildVersion = $BuildID.Split("_")[$BuildID.Split("_").Length - 1]
$BuildDefenitionname = $BuildID.Replace("_" + $BuildVersion , "")
$applicationName = $BuildDefenitionname.Split("_")[$BuildDefenitionname.Split("_").Length - 1]
$PackageShare = Join-Path $PackageRoot -ChildPath $BuildDefenitionname | Join-Path -ChildPath $BuildVersion
$deployManifestFileName = $Environment + "." + $applicationName + "DeploymentManifest.xml"
$deployManifestFile = "$PackageShare\$deployManifestFileName"
$deployManifest = [xml] (Get-Content $deployManifestFile)

$deployManifest.DeploymentManifest.ChildNodes | where {$_.NodeType -ne "Comment"} | foreach {
	$currentNode = $_
	switch($_.Name){
	
	  	"Shared" {
		
	  		$currentNode.ChildNodes | where {$_.NodeType -ne "Comment"} | foreach{
				$currentSharedNode = $_
				switch($currentSharedNode.Name){
				
					"Folders"{
						$currentSharedNode.ChildNodes  | where {$_.NodeType -ne "Comment"} | foreach{
							$folder2Create = $_.GetAttribute("foldername")
							Write-Verbose "Creating $($folder2Create) ..."
							CreateFolder -FolderPath $folder2Create
						}
					}
					
					default {"Action ""$_"" in Shared element not defined."}
				}
			}
		}
		
	  	"Front" {
		
			$currentNode.ChildNodes | where {$_.NodeType -ne "Comment"}| foreach{
				$currentSharedNode = $_
				switch($currentSharedNode.Name){
				
					"Prerequisites"{ 
						#copy all DscModules
						if ($currentSharedNode.SelectSingleNode('DscModules')){
							$currentSharedNode.DscModules.SelectNodes('DscModule') | where {$_.NodeType -ne "Comment"} | foreach{
								$dscModuleName=$_.GetAttribute("name")
								$dscModuleVersion=$_.GetAttribute("version")
								CopyDscModules -DscModule $dscModuleName -ModuleVersion $dscModuleVersion
							}
						}
						
						#create all local folders
						if ($currentSharedNode.SelectSingleNode('Folders')){
							$currentSharedNode.Folders.SelectNodes('Folder') | where {$_.NodeType -ne "Comment"} | foreach{
								$folderName=$_.foldername
								CreateFolder -FolderPath $folderName
							}
						}
						
						#create all reg keys
						if ($currentSharedNode.SelectSingleNode('RegistryKeys')){
							$currentSharedNode.RegistryKeys.SelectNodes('RegistryKey') | where {$_.NodeType -ne "Comment"} | foreach{
								$regKey=$_.GetAttribute("key")
								$regValueName=$_.GetAttribute("valueName")
								$regValueData=$_.GetAttribute("valueData")
								CreateRegKey -regKey $regKey -regValueName $regValueName -regValueData $regValueData
							}
						}
						
						#create all reg keys
						if ($currentSharedNode.SelectSingleNode('blabla')){
							$currentSharedNode.RegistryKeys.SelectNodes('RegistryKey') | where {$_.NodeType -ne "Comment"} | foreach{
								$regKey=$_.RegistryKey.GetAttribute("key")
								$regValueName=$_.RegistryKey.GetAttribute("valueName")
								$regValueData=$_.RegistryKey.GetAttribute("valueData")
								CreateRegKey -regKey $regKey -regValueName $regValueName -regValueData $regValueData
							}
						}
						
					}
					
					"WebSites" {
						#loop all WebSite elements
						$currentSharedNode.ChildNodes  | where {$_.NodeType -ne "Comment"} | foreach{
							$webSiteName = $_.GetAttribute("name")
							$webSitePort = $_.GetAttribute("port")
							#read DefaultApplicationPool attributes
							$defAppPoolName = $_.DefaultApplicationPool.GetAttribute("name")
							#if no name is provided, assign websitename as app pool name
							if(!$defAppPoolName){
								$defAppPoolName = $webSiteName
							}
							$defAppPoolRuntime = $_.DefaultApplicationPool.GetAttribute("managedRuntimeVersion")
							$defAppPoolPipelineMode = $_.DefaultApplicationPool.GetAttribute("managedPipelineMode")
							$defAppPoolEnable32Bit = [system.Convert]::ToBoolean(($_.DefaultApplicationPool.GetAttribute("enable32BitAppOnWin64")))
							$defAppPoolRestartTime = $_.DefaultApplicationPool.GetAttribute("restartTimeLimit")
							$defAppPoolRestartSchedule = $_.DefaultApplicationPool.GetAttribute("restartSchedule")
							$defAppPoolUser = $_.DefaultApplicationPool.GetAttribute("appPoolUser")
							$defAppPoolPassword= $_.DefaultApplicationPool.GetAttribute("appPoolUserPassword")
							
							#create DefaultApplicationPool and WebSite
							CreateApplicationPool -Name $defAppPoolName -AppPoolPassword $defAppPoolPassword -AppPoolUserName $defAppPoolUser `
								-enable32BitAppOnWin64 $defAppPoolEnable32Bit -ManagedPipelineMode $defAppPoolPipelineMode `
								-ManagedRuntimeVersion $defAppPoolRuntime -restartSchedule $defAppPoolRestartSchedule -restartTimeLimit $defAppPoolRestartTime
								
							CreateWebSite -WebSiteName $webSiteName -Port $webSitePort -ApplicationPool $defAppPoolName
							
							#loop all webapplications 
							$currentWebSite = $_
							$currentWebSite.SelectNodes('WebApplication') | where {$_.NodeType -ne "Comment"} | foreach{
								#read webapplication attributes
								$WebAppName = $_.GetAttribute("name")
								$WebAppSourceProject = $_.GetAttribute("sourceProject")
								$WebAppAppDateDeploy= $_.GetAttribute("appdatadeploy")
								$WebAppAppDataDestination= $_.GetAttribute("appdataDestination")
								#read authentication attributes
								$WebApplicationAnonymousAuth = $_.IISSettings.Authentication.GetAttribute("Anonymous")
								$WebApplicationAspNetImpersonation = $_.IISSettings.Authentication.GetAttribute("AspNetImpersonation")
								$WebApplicationBasicAuth = $_.IISSettings.Authentication.GetAttribute("Basic")
								$WebApplicationFormsAuth = $_.IISSettings.Authentication.GetAttribute("Forms")
								$WebApplicationWindowsAuth = $_.IISSettings.Authentication.GetAttribute("Windows")
								#validate authentication attributes
								ValidateWebAppPoolAuthData -Basic ([ref]$WebApplicationBasicAuth) -Windows ([ref]$WebApplicationWindowsAuth) -Anonymous ([ref]$WebApplicationAnonymousAuth) `
									-AspNetImpersonation ([ref]$WebApplicationAspNetImpersonation) -Forms ([ref]$WebApplicationFormsAuth)
								
								#check if current WebApplication has ApplicationPool element 
								#if yes, create application pool
								$WebAppAppPool = $_.SelectSingleNode('IISSettings/ApplicationPool')
								if ($WebAppAppPool){
									#read DefaultApplicationPool attributes
									$AppPoolName = $WebAppAppPool.GetAttribute("name")
									if(!$AppPoolName){
										$AppPoolName = $WebAppName
									}
									$AppPoolRuntime = $WebAppAppPool.GetAttribute("managedRuntimeVersion")
									$AppPoolPipelineMode = $WebAppAppPool.GetAttribute("managedPipelineMode")
									$AppPoolEnable32Bit = [system.Convert]::ToBoolean(($WebAppAppPool.GetAttribute("enable32BitAppOnWin64")))
									$AppPoolRestartTime = $WebAppAppPool.GetAttribute("restartTimeLimit")
									$AppPoolRestartSchedule = $WebAppAppPool.GetAttribute("restartSchedule")
									$AppPoolUser = $WebAppAppPool.GetAttribute("appPoolUser")
									$AppPoolPassword= $WebAppAppPool.GetAttribute("appPoolUserPassword")
									
									#create ApplicationPool
									CreateApplicationPool -Name $AppPoolName -AppPoolPassword $AppPoolPassword -AppPoolUserName $AppPoolUser `
										-enable32BitAppOnWin64 $AppPoolEnable32Bit -ManagedPipelineMode $AppPoolPipelineMode `
										-ManagedRuntimeVersion $AppPoolRuntime -restartSchedule $AppPoolRestartSchedule -restartTimeLimit $AppPoolRestartTime
								}
								
								CreateWebApplicationInWebsite  -ProjectName $WebAppName -WebSiteName $webSiteName -ApplicationPool $AppPoolName -AnonymousAuthentication $WebApplicationAnonymousAuth `
									-AspImpersonation $WebApplicationAspNetImpersonation -BasicAuthentication $WebApplicationBasicAuth -FormsAuthentication $WebApplicationFormsAuth -WindowsAuthentication $WebApplicationWindowsAuth
								
							}
						}
					}
				}
			}
		}
		
		default {"Action ""$_"" not defined."}
	}
}
