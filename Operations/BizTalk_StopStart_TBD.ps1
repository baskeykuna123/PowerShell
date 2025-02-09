Param
(
	[String]$Action,
	[String]$Platform,
	[String]$ServerType,
	[String]$Environment
)
CLS

if(!$Action){
	$Action="Stop"
	$Platform="Esb"
	$ServerType="Admin"
	$Environment="dcorpbis"
}
Write-Host "Environment:"$Environment
# loading Function
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop

$ErrorActionPreference='Stop'

#Getting MasterDeploy Sequence
$DeploymentxmlDirectory=join-path $global:ESBRootFolder -ChildPath "$Platform\XML"

if($Platform -ieq "Esb"){
	$MasterDeploySequencePath=join-path $DeploymentxmlDirectory "Mercator.Esb.Master.DeploySequence.xml"
}
elseif($Platform -ieq "Eai")
{
	$MasterDeploySequencePath=Join-Path $DeploymentxmlDirectory "Mercator.Esb.Eai.Master.DeploySequence.xml"
}
else{
    Throw "Platform ""$platform"" not supported."
}
    
if(!(Test-Path $MasterDeploySequencePath)){
	Write-Host "MasterDeploySequence not found. So nothing to Stop. Abort stopping and continue.."
	exit
}

$paramxmlfilepath=Join-Path $global:ESBRootFolder -ChildPath "$Platform\ESBDeploymentParameters_Resolved.xml"		
$MasterDeployXML=[XML](gc $MasterDeploySequencePath) 
$DeploySequencelist=$($MasterDeployXML.'Master.DeploySequence'.'DeployPackages.DeploySequence'.DeployPackage)

$ReadResolvedDeploymentParametersXMLFile =[XML](Gc $paramxmlfilepath)

# Read attribute for ApplicationToExclude
$ExcludedAplicationList=$ReadResolvedDeploymentParametersXMLFile.SelectNodes("//Parameters/EnvironmentParameters/Environment[@name='$Environment']/add[@key='ApplicationToExclude']").value

$ListofDeploySequences=@()
Foreach($deploysequencename in $DeploySequencelist){
    $ApplicationName=$deploysequencename -ireplace ".DeploySequence.xml",""
    if($ExcludedAplicationList -inotlike "*$ApplicationName*"){
        $ListofDeploySequences+=$deploysequencename
    }
}
$DeploySequencelist=$ListofDeploySequences

$ESBDeploymentFolder=Join-Path $global:ESBRootFolder -ChildPath "$Platform"
$DateTime=Get-Date -Format yyyyMMdd-hhmmss
$hostInstances = Get-WmiObject MSBTS_HostInstance -Namespace 'root/MicrosoftBizTalkServer'
$Rootlogfolder=[String]::Format("{0}\Logs",$ESBDeploymentFolder)
$StopLogFolder=Join-Path $Rootlogfolder -ChildPath "\StopEsb_$DateTime"
$StartLogFolder=Join-Path $Rootlogfolder -ChildPath "\StartEsb_$DateTime"

$overallDeployStatus=$MasterDeployXML.'Master.DeploySequence'.'MasterDeployName'.status

if(($Action -eq "Stop")){

    if ($overallDeployStatus -eq "Stopped") {
        Write-Host "OverallStatus is already stopped."
        exit
    }
	elseif (($overallDeployStatus -ne "Started") -and ($overallDeployStatus -ne "Stopping") ){
        #throw "overallDeployStatus has an unsupported status - $overallDeployStatus."
        Write-Host "OverallStatus ($overallDeployStatus -ne ""Started"") -and ($overallDeployStatus -ne ""Stopping"")."
        exit
    }
    else{
        SetAttribute -XmlPath $MasterDeploySequencePath -ParentElement "Master.DeploySequence/MasterDeployName" -Attribute "status" -NewAttributeValue "Stopping"
    }

	# Stop ETW Tracing
    $EtwTracingStatus=$MasterDeployXML.'Master.DeploySequence'.'MasterDeployName'.statusEtwTracing
    if ([string]::IsNullOrEmpty($EtwTracingStatus) -or ($EtwTracingStatus -ieq "Stopping") ) {
        AddAttributeToElement -XmlPath $MasterDeploySequencePath -ParentElement "Master.DeploySequence/MasterDeployName" -NewAttribute "statusEtwTracing" -NewAttributeValue "Stopping"
	    if($Platform -ieq "Esb"){
		    $cmdFilePath="$global:ESBRootFolder\Esb\Tools\StopDefaultTrace.cmd"
		    $stopFolder=[String]::Format("{0}\StopETWTrace_Log.txt",$StopLogFolder)
		    New-Item $stopFolder -ItemType File -Force | Out-Null
		
		    if(Test-Path $cmdFilePath){
			    Start-Process -FilePath $cmdFilePath -Verb runas -ErrorAction Stop| Tee-Object -FilePath $stopFolder -Append
		    }
		    else{
			    throw "Stopping Esb - ""StopDefaultTrace.cmd"" not found"
		    }
        }
        SetAttribute -XmlPath $MasterDeploySequencePath -ParentElement "Master.DeploySequence/MasterDeployName" -Attribute "statusEtwTracing" -NewAttributeValue "Stopped"
    }
    elseif ($EtwTracingStatus -ieq "Stopped") {
        Write-Host "EtwTracing is already stopped."
    }
    else{
        throw "statusEtwTracing has an unsupported value - $EtwTracingStatus"
    }
		
	[array]::Reverse($DeploySequencelist)

    $BtsApplicationsStatus=$MasterDeployXML.'Master.DeploySequence'.'MasterDeployName'.statusBtsApplications
	if ( ($BtsApplicationsStatus -ieq "Started") -or ($BtsApplicationsStatus -ieq "Stopping") ){

        SetAttribute -XmlPath $MasterDeploySequencePath -ParentElement "Master.DeploySequence/MasterDeployName" -Attribute "statusBtsApplications" -NewAttributeValue "Stopping"

	    foreach($DeploySequenceXML in $DeploySequencelist)
	    {
		    # Read XML
            if ($DeploySequenceXML.Attributes.Count -eq 0){
                $DeploySequenceXMLInnerText=$DeploySequenceXML
            }
            else{
                $DeploySequenceXMLInnerText=$DeploySequenceXML.InnerText
            }
		
		    $DeploySequenceName=$DeploySequenceXMLInnerText -ireplace ".DeploySequence.xml",""
		    $ApplicationDeploySequenceFile=[String]::Format("{0}\XML\{1}",$ESBDeploymentFolder,$DeploySequenceXMLInnerText)	
  		    $DeploySequenceReader=[XML](gc $ApplicationDeploySequenceFile)
			if(!$DeploySequenceReader){
				throw "Deploy Sequence does not exist."
			}
  		    $ApplicationConfiguration=$DeploySequenceReader.'Package.DeploySequence'.ApplicationConfiguration
		    $NTServices=$ApplicationConfiguration.NTServices.NTService
  		    $Application=$ApplicationConfiguration.BizTalkApplications.BizTalkApplication.BizTalkApplicationName
            $masterXPpath=[string]::Format("//DeployPackage[text()=""{0}""]",$DeploySequenceXMLInnerText)
            $DeployPackageNode=$MasterDeployXML.SelectSingleNode($masterXPpath)
            $CurrenApplicationDeployStatus=$DeployPackageNode.status
            $CurrenNtServicesDeployStatus=$DeployPackageNode.statusNtServices
            $CurrenBTSDeployStatus=$DeployPackageNode.statusBtsApplication

            if ( ($CurrenApplicationDeployStatus -ieq "Started") -or ($CurrenApplicationDeployStatus -ieq "Stopping") ){
                SetAttribute -XmlPath $MasterDeploySequencePath -ParentElement $masterXPpath -Attribute "status" -NewAttributeValue "Stopping"

  		        # Stopping NT Services
  		        if ( $NTServices -and ($CurrenNtServicesDeployStatus -ine "Stopped") ){
                    SetAttribute -XmlPath $MasterDeploySequencePath -ParentElement $masterXPpath -Attribute "statusNtServices" -NewAttributeValue "Stopping"

			        $stopFolder=[String]::Format("{0}\Services\StopNTService_{1}.txt",$StopLogFolder,$DeploySequenceName)
			        New-Item $stopFolder -ItemType File -Force | Out-Null
	 		        Write-Host "`n --- STOP SERVICE ---"	
     		        ForEach($Service in $NTServices){
                        $serviceName=$Service.NTServiceName.InnerText
		 		        "Stopping Windows service:$serviceName" | Tee-Object -FilePath $stopFolder -Append
		 		        Stop-WindowsService -serviceName $serviceName | Tee-Object -FilePath $stopFolder -Append
    		        }

                    SetAttribute -XmlPath $MasterDeploySequencePath -ParentElement $masterXPpath -Attribute "statusNtServices" -NewAttributeValue "Stopped"
		        }

		        # Stop BTS Application
                if($Application -and ($ServerType -ieq "Admin") -and ($CurrenBTSDeployStatus -ine "Stopped") ){
                    SetAttribute -XmlPath $MasterDeploySequencePath -ParentElement $masterXPpath -Attribute "statusBtsApplication" -NewAttributeValue "Stopping"

			        $stopFolder=[String]::Format("{0}\Applications\StopApplication_{1}.txt",$StopLogFolder,$DeploySequenceName)
			        New-Item $stopFolder -ItemType File -Force | Out-Null
			        Stop-BTSApplication -ApplicationName $Application | Tee-Object -FilePath $stopFolder -Append 

                    SetAttribute -XmlPath $MasterDeploySequencePath -ParentElement $masterXPpath -Attribute "statusBtsApplication" -NewAttributeValue "Stopped"
		        }

                SetAttribute -XmlPath $MasterDeploySequencePath -ParentElement $masterXPpath -Attribute "status" -NewAttributeValue "Stopped"

            }
            elseif  ($CurrenApplicationDeployStatus -ieq "Stopped"){
                Write-Host "$DeploySequenceName already stopped."
            }
            else{
                throw "$DeploySequenceName has an unsupported status - $CurrenApplicationDeployStatus."
            }
			
			# Disable Scheduled Tasks
			if(($Platform -ieq "Esb") -and ($ServerType -ieq "Admin")){
				$stopFolder=[String]::Format("{0}\DisableScheduledTasks_Log.txt",$StopLogFolder)
				New-Item $stopFolder -ItemType File -Force | Out-Null	
				$ScheduledTasks=$DeploySequenceReader.SelectNodes("//Package.DeploySequence/SystemConfiguration/ScheduledTasks")
				If($ScheduledTasks.ChildNodes){
					$ScheduledTask=$ScheduledTasks.ScheduledTask
					$TaskName=$($ScheduledTask.name)
					EnableDisable-ScheduledTask -TaskName $TaskName -Enable $False | Tee-Object -Filepath $stopFolder -Append
				}			
	    	}
		}	

        SetAttribute -XmlPath $MasterDeploySequencePath -ParentElement "Master.DeploySequence/MasterDeployName" -Attribute "statusBtsApplications" -NewAttributeValue "Stopped"

    }
    elseif ($BtsApplicationsStatus -ieq "Stopped") {
        Write-Host "All NtServices and BtsApplications are already stopped.."
    }
    else{
        throw "statusBtsApplications has an unsupported value - $BtsApplicationsStatus"
    }

	# Stop Biztalk Host Instances	
    $HostInstancesStatus=$MasterDeployXML.'Master.DeploySequence'.'MasterDeployName'.statusHostInstances
    if ( ($HostInstancesStatus -ieq "Started") -or ($HostInstancesStatus -ieq "Stopping") ){
        SetAttribute -XmlPath $MasterDeploySequencePath -ParentElement "Master.DeploySequence/MasterDeployName" -Attribute "statusHostInstances" -NewAttributeValue "Stopping"	
	    
        Write-Host "STOPPING ALL HOST INSTANCES.."
	    $stopFolder=[String]::Format("{0}\HostInstances\StopHostInstances_Log.txt",$StopLogFolder)
	    New-Item $stopFolder -ItemType File -Force | Out-Null	
	    ForEach($Instance in $($hostInstances)){
	        if($Platform -ieq "Esb"){
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
	        Elseif($Platform -ieq "Eai"){
		        if((($($Instance.ServiceState)) -eq '4') -and ($($Instance.Name) -ilike "*Eai*")){
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
	    }

        SetAttribute -XmlPath $MasterDeploySequencePath -ParentElement "Master.DeploySequence/MasterDeployName" -Attribute "statusHostInstances" -NewAttributeValue "Stopped"	
    }
    elseif ($HostInstancesStatus -ieq "Stopped"){
        Write-Host "All host instances are already stopped.."
    }
    else{
        throw "statusHostInstances has an unsupported value - $HostInstancesStatus"
    }

    SetAttribute -XmlPath $MasterDeploySequencePath -ParentElement "Master.DeploySequence/MasterDeployName" -Attribute "status" -NewAttributeValue "Stopped"
	if($Platform -ieq "Esb"){
		try{
			iisreset /STOP
		}
		catch{
			throw "ERROR:IIS is not fully stopped."
		}
	}

}

if($Action -eq "Start"){

    if ($overallDeployStatus -eq "Started"){
        Write-Host "OverallStatus is already started."
        exit
    }elseif (($overallDeployStatus -ne "Deployed") -and ($overallDeployStatus -ne "Starting") ){
        throw "overallDeployStatus has an unsupported status - $overallDeployStatus."
    }
    else{
        SetAttribute -XmlPath $MasterDeploySequencePath -ParentElement "Master.DeploySequence/MasterDeployName" -Attribute "status" -NewAttributeValue "Starting"
    }

    #starting ntservices and bts applications
    $BtsApplicationsStatus=$MasterDeployXML.'Master.DeploySequence'.'MasterDeployName'.statusBtsApplications
    if ( [string]::IsNullOrEmpty($BtsApplicationsStatus) -or ($BtsApplicationsStatus -ieq "Starting") ){

        AddAttributeToElement -XmlPath $MasterDeploySequencePath -ParentElement "Master.DeploySequence/MasterDeployName" -NewAttribute "statusBtsApplications" -NewAttributeValue "Starting"

	    foreach($DeploySequenceXML in $DeploySequencelist){
		    # Read XML
            if ($DeploySequenceXML.Attributes.Count -eq 0){
                $DeploySequenceXMLInnerText=$DeploySequenceXML
            }
            else{
                $DeploySequenceXMLInnerText=$DeploySequenceXML.InnerText
            }
		    $DeploySequenceName=$DeploySequenceXMLInnerText -ireplace ".DeploySequence.xml",""
		    $ApplicationDeploySequenceFile=[String]::Format("{0}\XML\{1}",$ESBDeploymentFolder,$DeploySequenceXMLInnerText)	
  		    $DeploySequenceReader=[XML](gc $ApplicationDeploySequenceFile)
  		    $ApplicationConfiguration=$DeploySequenceReader.'Package.DeploySequence'.ApplicationConfiguration
            $NTServices=$ApplicationConfiguration.NTServices.NTService
  		    $Application=$ApplicationConfiguration.BizTalkApplications.BizTalkApplication.BizTalkApplicationName
		
            $masterXPpath=[string]::Format("//DeployPackage[text()=""{0}""]",$DeploySequenceXMLInnerText)
            $DeployPackageNode=$MasterDeployXML.SelectSingleNode($masterXPpath)
            $CurrenApplicationDeployStatus=$DeployPackageNode.status
            $CurrenNtServicesDeployStatus=$DeployPackageNode.statusNtServices
            $CurrenBTSDeployStatus=$DeployPackageNode.statusBtsApplication
            if ( ($CurrenApplicationDeployStatus -ieq "Deployed") -or ($CurrenApplicationDeployStatus -ieq "Starting") ){
                SetAttribute -XmlPath $MasterDeploySequencePath -ParentElement $masterXPpath -Attribute "status" -NewAttributeValue "Starting"

		        # Starting Windows Service
  		        if( $($NTServices) -and ($CurrenNtServicesDeployStatus -ine "Started") ){
	 		        Write-Host "`n --- START SERVICE ---"	
                    AddAttributeToElement -XmlPath $MasterDeploySequencePath -ParentElement $masterXPpath -NewAttribute "statusNtServices" -NewAttributeValue "Starting"
			        $startFolder=[String]::Format("{0}\Services\StartService_{1}.txt",$StartLogFolder,$DeploySequenceName)
			        New-Item $startFolder -ItemType File -Force | Out-Null
     		        ForEach($Service in $NTServices){
                        #read attribute "onlyRunOn1Server" in application deploysequence
                        $runServiceOnOneServer=$Service.NTServiceName.onlyRunOn1Server
                        if ( ($runServiceOnOneServer -ieq "False") -or ($ServerType -ieq "Admin") ){
                            $serviceName=$Service.NTServiceName.InnerText
		 		            "Starting Windows service:$serviceName"| Tee-Object -FilePath $startFolder -append
		 		            Start-WindowsService -serviceName $serviceName | Tee-Object -FilePath $startFolder -append 
                        }
						if(($runServiceOnOneServer -ieq "True") -and ($ServerType -ine "Admin")){
							Try{
							$GetService = Get-WmiObject win32_Service | ?{$_.Name -ieq $Service}
								if($($CheckService.StartMode) -ine "Disabled"){
									Set-Service -Name "$($Service.NTServiceName.InnerText)" -ErrorAction Stop -StartMode Disabled
									Write-Host "Service $($Service.NTServiceName.InnerText) is Disabled."
								}
							}
							catch
							{
								throw $_
							}
						}
    		        }
                    SetAttribute -XmlPath $MasterDeploySequencePath -ParentElement $masterXPpath -Attribute "statusNtServices" -NewAttributeValue "Started"
		        }
		
		        # Start BTS Application
		        if($Application -and ($ServerType -ieq "Admin") -and ($CurrenBTSDeployStatus -ine "Started") ){
                    AddAttributeToElement -XmlPath $MasterDeploySequencePath -ParentElement $masterXPpath -NewAttribute "statusBtsApplication" -NewAttributeValue "Starting"
			        $startFolder=[String]::Format("{0}\Applications\StartApplication_{1}.txt",$StartLogFolder,$DeploySequenceName)
			        New-Item $startFolder -ItemType File -Force | Out-Null	
			        Start-BTSApplication -ApplicationName $Application | Tee-Object -FilePath $startFolder -append
                    SetAttribute -XmlPath $MasterDeploySequencePath -ParentElement $masterXPpath -Attribute "statusBtsApplication" -NewAttributeValue "Started"
		        }

                SetAttribute -XmlPath $MasterDeploySequencePath -ParentElement $masterXPpath -Attribute "status" -NewAttributeValue "Started"
            }
            elseif  ($CurrenApplicationDeployStatus -ieq "Started"){
                Write-Host "$DeploySequenceName already started."
            }
            else{
                throw "$DeploySequenceName has an unsupported status - $CurrenApplicationDeployStatus."
            }
			
			# Enable Scheduled Tasks
			if(($Platform -ieq "Esb") -and ($ServerType -ieq "Admin")){
				$startFolder=[String]::Format("{0}\EnableScheduledTasks_Log.txt",$StartLogFolder)
				New-Item $startFolder -ItemType File -Force | Out-Null
			
				$ScheduledTasks=$DeploySequenceReader.SelectNodes("//Package.DeploySequence/SystemConfiguration/ScheduledTasks")
				If($ScheduledTasks.ChildNodes){
					$ScheduledTask=$ScheduledTasks.ScheduledTask
					$TaskName=$($ScheduledTask.name)
					EnableDisable-ScheduledTask $TaskName $True "localhost" | Tee-Object -FilePath $startFolder -Append
				}	
			}
	    }

        #all nt services and bts applications should be started at this point
        SetAttribute -XmlPath $MasterDeploySequencePath -ParentElement "Master.DeploySequence/MasterDeployName" -Attribute "statusBtsApplications" -NewAttributeValue "Started"	
    }
    elseif ($BtsApplicationsStatus -ieq "Started"){
        Write-Host "All NtServices and BtsApplications are already started.."
    }
    else{
        throw "statusBtsApplications has an unsupported value - $BtsApplicationsStatus"
    }

	# Start Biztalk Host Instances	
    $HostInstancesStatus=$MasterDeployXML.'Master.DeploySequence'.'MasterDeployName'.statusHostInstances
    if ( [string]::IsNullOrEmpty($HostInstancesStatus) -or ($HostInstancesStatus -ieq "Starting") ){

        AddAttributeToElement -XmlPath $MasterDeploySequencePath -ParentElement "Master.DeploySequence/MasterDeployName" -NewAttribute "statusHostInstances" -NewAttributeValue "Starting"
	    Write-Host "STARTING ALL HOST INSTANCES.."
	    $startFolder=[String]::Format("{0}\HostInstances\StartHostInstances_Log.txt",$StartLogFolder)
	    New-Item $startFolder -ItemType File -Force | Out-Null
	    ForEach($Instance in $($hostInstances)){
		    if($Platform -ieq "Esb"){
			    if((($($Instance.ServiceState)) -eq '1') -and ($($Instance.Name -inotlike "*Eai*")) -and (!$($Instance.IsDisabled) -ieq "False")){
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
		    elseif($Platform -ieq "Eai"){
				    if((($($Instance.ServiceState)) -eq '1') -and ($($Instance.Name -ilike "*Eai*")) -and (!$($Instance.IsDisabled) -ieq "False")){
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
	    }
	
        #all host instances should be started at this point
        SetAttribute -XmlPath $MasterDeploySequencePath -ParentElement "Master.DeploySequence/MasterDeployName" -Attribute "statusHostInstances" -NewAttributeValue "Started"	
    }
    elseif ($HostInstancesStatus -ieq "Started"){
        Write-Host "All host instances are already started.."
    }
    else{
        throw "statusHostInstances has an unsupported value - $HostInstancesStatus"
    }
	
	# All is started, now start ETW Tracing
	if($Platform -ieq "Esb"){
		foreach($DeploySequenceXML in $DeploySequencelist){
			# Read XML
			if ($DeploySequenceXML.Attributes.Count -eq 0){
				$DeploySequenceXMLInnerText=$DeploySequenceXML
			}
			else{
				$DeploySequenceXMLInnerText=$DeploySequenceXML.InnerText
			}
			$DeploySequenceName=$DeploySequenceXMLInnerText -ireplace ".DeploySequence.xml",""
			$ApplicationDeploySequenceFile=[String]::Format("{0}\XML\{1}",$ESBDeploymentFolder,$DeploySequenceXMLInnerText)	
			$DeploySequenceReader=[XML](gc $ApplicationDeploySequenceFile)
			$ApplicationConfiguration=$DeploySequenceReader.'Package.DeploySequence'.ApplicationConfiguration
			$ApplicationRootPath= Join-Path $ESBDeploymentFolder -ChildPath (GetApplicationDeploymentFolder $DeploySequenceName)

			#getting EtwTracing
			$EtwTracing=$ApplicationConfiguration.EtwTracing
			if($($EtwTracing)){
				#read xml
				$TraceName=$EtwTracing.TraceName
				$MaxTraceSize=$EtwTracing.MaxTraceSize
				$TraceLevel=$EtwTracing.TraceLevel
				$BufferSize=$EtwTracing.BufferSize
				$MaxBuffers=$EtwTracing.MaxBuffers
				$EtwTracingComponents=$EtwTracing.EtwTracingComponents.EtwTracingComponent 
				#delete old file
				$cmdFilePath= Join-Path $ApplicationRootPath -ChildPath "RestartTraceAfterReboot.cmd"
				if(Test-Path $cmdFilePath){
					Remove-Item $cmdFilePath -Force
				}
                $cmdFilePath= Join-Path $ApplicationRootPath -ChildPath "StartDefaultTrace.cmd"
				if(Test-Path $cmdFilePath){
					Remove-Item $cmdFilePath -Force
				}
				#create RestartTraceAfterReboot.cmd
				$RestartTraceAfterRebootCmd=Get-TemplateRestartTraceAfterRebootCmd
                Add-Content -Path (Join-Path $ApplicationRootPath -ChildPath "RestartTraceAfterReboot.cmd") -Value $RestartTraceAfterRebootCmd
				#create StartDefaultTraceCmd.cmd
				$StartDefaultTraceCmd=Get-TemplateStartDefaultTraceCmd -TraceName $TraceName
				Add-Content -Path (Join-Path $ApplicationRootPath -ChildPath "StartDefaultTrace.cmd") -Value $StartDefaultTraceCmd
				$counter=0
				$EtwTracingComponents | foreach {
					$EtwGuid=$_.EtwGuid
					if ($counter -eq 0){
						$ComponentFirstLine=Get-TemplateComponentFirstLine -TraceName $TraceName -MaxTraceSize $MaxTraceSize -EtwGuid $EtwGuid -BufferSize $BufferSize -MaxBuffers $MaxBuffers 
						Add-Content -Path (Join-Path $ApplicationRootPath -ChildPath "StartDefaultTrace.cmd") -Value $ComponentFirstLine
					}
					else{
						$ComponentNextLines=Get-TemplateComponentNextLines -TraceName $TraceName -EtwGuid $EtwGuid
						Add-Content -Path (Join-Path $ApplicationRootPath -ChildPath "StartDefaultTrace.cmd") -Value $ComponentNextLines
					}
					$counter++
				}
				
				# StartDefaultTrace.cmd is created, now launch it
				$cmdFilePath="$global:ESBRootFolder\Esb\Tools\StartDefaultTrace.cmd"
				$startFolder=[String]::Format("{0}\StartETWTrace_Log.txt",$StartLogFolder)
				New-Item $startFolder -ItemType File -Force | Out-Null
				
				if(Test-Path $cmdFilePath){
					Start-Process -FilePath $cmdFilePath -Verb runas #| Tee-Object -FilePath $startFolder -Force
				}
				else{
					throw "Starting Esb - ""StartDefaultTrace.cmd"" not found"
				}
			}
		}
	}

    SetAttribute -XmlPath $MasterDeploySequencePath -ParentElement "Master.DeploySequence/MasterDeployName" -Attribute "status" -NewAttributeValue "Started"
	if($Platform -ieq "Esb"){
		Try{
			iisreset /START
		}
		catch
		{
			throw "ERROR:IIS is not fully started"
		}
	}
}

$stopFolder=[String]::Format("{0}\DisableScheduledTasks_Log.txt",$StopLogFolder)
New-Item $stopFolder -ItemType File -Force | Out-Null	
#if($ServerType -ine "Admin"){
#	EnableDisable-ScheduledTask -TaskName "BizTalkAutoArtifactsHandler" -Enable $False | Tee-Object -Filepath $stopFolder -Append
#}

