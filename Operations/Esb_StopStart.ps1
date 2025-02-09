Param
(
[String]$Action
)
CLS

# loading Function
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop

#Getting MasterDeploy Sequence
$DeploymentxmlDirectory=join-path $global:ESBRootFolder -ChildPath "Esb\XML"
$ESBMasterDeploySequencePath=join-path $DeploymentxmlDirectory  "Mercator.Esb.Master.DeploySequence.xml"
$MasterDeployXML=[xml] (get-content filesystem::$ESBMasterDeploySequencePath -Force )
$DeploySequencelist=$MasterDeployXML.'Master.DeploySequence'.'DeployPackages.DeploySequence'.DeployPackage 
$ESBDeploymentFolder=Join-Path $global:ESBRootFolder -ChildPath "Esb"
$DateTime=Get-Date -Format yyyyMMdd-hhmmss
$hostInstances = Get-WmiObject MSBTS_HostInstance -Namespace 'root/MicrosoftBizTalkServer'
$Rootlogfolder=[String]::Format("{0}\Logs",$ESBDeploymentFolder)
$StopLogFolder=Join-Path $Rootlogfolder -ChildPath "\StopEsb_$DateTime"
$StartLogFolder=Join-Path $Rootlogfolder -ChildPath "\StartEsb_$DateTime"

if($Action -eq "Stop"){
	# Stop ETW Tracing
	#$cmdFilePath="E:\Program Files\Mercator\Esb\Tools\StopDefaultTrace.cmd"
	#$stopFolder=[String]::Format("{0}\StopETWTrace_Log.txt",$Rootlogfolder)
	#New-Item $stopFolder -ItemType File -Force | Out-Null
	
	#if(Test-Path $cmdFilePath){
		#Start-Process -FilePath $cmdFilePath -Verb runas | Tee-Object -Path $stopFolder -Force
	#}
    
	[array]::Reverse($DeploySequencelist)
	
	foreach($DeploySequenceXML in $DeploySequencelist)
	{
		# Read XML
		$DeploySequenceName=$DeploySequenceXML -ireplace ".DeploySequence.xml",""
		$ApplicationDeploySequenceFile=[String]::Format("{0}\XML\{1}",$ESBDeploymentFolder,$DeploySequenceXML)	
  		$DeploySequenceReader=[XML](gc $ApplicationDeploySequenceFile)
  		$ApplicationConfiguration=$DeploySequenceReader.'Package.DeploySequence'.ApplicationConfiguration
		$NTServices=$ApplicationConfiguration.NTServices.NTService.NTServiceName.InnerText
  		$Application=$ApplicationConfiguration.BizTalkApplications.BizTalkApplication.BizTalkApplicationName
  		# Stopping NT Services
  		if($NTServices)
		{	
			$stopFolder=[String]::Format("{0}\Services\StopNTService_{1}.txt",$StopLogFolder,$DeploySequenceName)
			New-Item $stopFolder -ItemType File -Force | Out-Null
	 		Write-Host "`n --- STOP SERVICE ---"	
     		ForEach($Service in $NTServices){
		 		"Stopping Windows service:$Service" | Tee-Object -FilePath $stopFolder -Append
		 		Stop-WindowsService -serviceName $Service | Tee-Object -FilePath $stopFolder -Append
    		}
		}

		# Stop BTS Application
		if($Application)
		{
			$stopFolder=[String]::Format("{0}\Applications\StopApplication_{1}.txt",$StopLogFolder,$DeploySequenceName)
			New-Item $stopFolder -ItemType File -Force | Out-Null
			Stop-BTSApplication -ApplicationName $Application | Tee-Object -FilePath $stopFolder -Append 
		}
	}


	# Stop Biztalk Host Instances	
	Write-Host "STOPPING ALL HOST INSTANCES.."
	$stopFolder=[String]::Format("{0}\HostInstances\StopHostInstances_Log.txt",$StopLogFolder)
	New-Item $stopFolder -ItemType File -Force | Out-Null	
	ForEach($Instance in $($hostInstances)){
		if((($($Instance.ServiceState)) -eq '4') -and ($($Instance.Name) -inotlike "*Eai*")){
			"`n STOP HOST INSTANCE: $($Instance.HostName)"|Tee-Object -FilePath $stopFolder -Append
			Try{
				$Instance.Stop() | Out-Null -ErrorAction Stop
				"$($Instance.HostName) Status: Stopped" | Tee-Object -FilePath $stopFolder -Append
			}
			Catch{
				$_ | Add-Content -Path $stopFolder -Force
			}
		}
	}
	
	# Disable Scheduled Tasks
	$stopFolder=[String]::Format("{0}\DisableTasks_Log.txt",$StartStoplogfolder)
	New-Item $stopFolder -ItemType File -Force | Out-Null	
	
	Disable-ScheduledTask -TaskName "BizTalkAutoArtifactsHandler" -Server "localhost"
}

if($Action -eq "Start"){

	# Start ETW Tracing
	#
	
	foreach($DeploySequenceXML in $DeploySequencelist)
	{
		# Read XML
		$DeploySequenceName=$DeploySequenceXML -ireplace ".DeploySequence.xml",""
		$ApplicationDeploySequenceFile=[String]::Format("{0}\XML\{1}",$ESBDeploymentFolder,$DeploySequenceXML)	
  		$DeploySequenceReader=[XML](gc $ApplicationDeploySequenceFile)
  		$ApplicationConfiguration=$DeploySequenceReader.'Package.DeploySequence'.ApplicationConfiguration
  		$NTServices=$ApplicationConfiguration.NTServices.NTService.NTServiceName.InnerText
  		$Application=$ApplicationConfiguration.BizTalkApplications.BizTalkApplication.BizTalkApplicationName
		
		<## Starting Windows Service
  		if($($NTServices)){
	 		Write-Host "`n --- START SERVICE ---"	
			$startFolder=[String]::Format("{0}\Services\StartService_{1}.txt",$StartLogFolder,$DeploySequenceName)
			New-Item $startFolder -ItemType File -Force | Out-Null
     		ForEach($Service in $NTServices){
		 		"Starting Windows service:$Service"| Tee-Object -FilePath $startFolder -append
		 		Start-WindowsService -serviceName $Service | Tee-Object -FilePath $startFolder -append 
    		}
		}
		
		# Start BTS Application
		if($Application){
			$startFolder=[String]::Format("{0}\Applications\StartApplication_{1}.txt",$StartLogFolder,$DeploySequenceName)
			New-Item $startFolder -ItemType File -Force | Out-Null	
			Start-BTSApplication -ApplicationName $Application | Tee-Object -FilePath $startFolder -append
		}#>
	}
	
	# Start Biztalk Host Instances	
	Write-Host "STARTING ALL HOST INSTANCES.."
	ForEach($Instance in $($hostInstances)){
		$startFolder=[String]::Format("{0}\HostInstances\StartHostInstances_Log.txt",$StartLogFolder)
		New-Item $startFolder -ItemType File -Force | Out-Null	
		
			if((($($Instance.ServiceState)) -eq '1') -and ($($Instance.Name -inotlike "*Eai*")) -and (!$($Instance.IsDisabled) -ieq "True")){
				"`n START HOST INSTANCE: $($Instance.HostName)" | Tee-Object -FilePath $startFolder -Append	
				Try{
					$Instance.Start() | Out-Null -ErrorAction Stop
					"$($Instance.HostName) Status: Started"| Tee-Object -FilePath $startFolder -Append
				}
				catch{
					$_ | Tee-Object -FilePath $startFolder -Append
				}
			}
		}	
	
	# Enable Scheduled Tasks 
	$startFolder=[String]::Format("{0}\EnableTasks_Log.txt",$StartLogFolder)
	New-Item $startFolder -ItemType File -Force | Out-Null
	
	Enable-ScheduledTask -TaskName "BizTalkAutoArtifactsHandler" -Server "localhost" | Tee-Object -FilePath $startFolder -Append
}