$ScriptDirectory=split-path $MyInvocation.MyCommand.Definition -Parent
."$ScriptDirectory\fnSetGlobalParameters.ps1"

# Loading Biztalk management Assembly 
if(-not(Test-Path $global:BiztalkOMPath))
{
 	Write-Host "WARNING: Biztalk not found.Biztalk functions are loaded"
}
Else
{
	[System.Reflection.Assembly]::LoadFrom($global:BiztalkOMPath)
	$global:BtsCatalogExplorer = New-Object Microsoft.BizTalk.ExplorerOM.BtsCatalogExplorer
	$group = Get-WmiObject MSBTS_GroupSetting -n root\MicrosoftBizTalkServer
	$global:BiztalkDBName = $group.MgmtDBName
	$global:BiztalkServer = $group.MgmtDBServerName
	$($global:BtsCatalogExplorer).ConnectionString= "SERVER=$global:BiztalkServer;DATABASE=$global:BiztalkDBName;Integrated Security=SSPI"
	$global:DeploymentLogsBasePath="E:\BaloiseESB\Logs\"
	Write-Host "Biztalk Database   :" $global:BIztalkDBName
	Write-Host "Biztalk Server     :" $global:BiztalkServer 
	Write-Host "Biztalk Server     :" $global:DeploymentLogsBasePath  
}

# Function to generate log file
Function Create-Log($ApplicationName,$FileName)
{
	$DateTime = Get-Date -Format "dd-MM-yyyy--hh:mm:ss"
	$TimeStamp=Get-Date -Format "ddMMyyy"
 	$script:logFile= [String]::Format("{0}\{1}\{2}_Output{3}.txt",$global:DeploymentLogsBasePath,$ApplicationName,$FileName,$TimeStamp)
	if(-not(Test-Path $logFile)){
    	New-Item  $logFile -ItemType File -Force
 	} 
	Write-Host `n
 	Write-Host -- $DateTime --
	Write-Host `n

}

# Get the Connection String 
function Get-BTSConnectionString
{
Try
{
	Write-Host "CONNECTION_STRING -"
	[System.String]::Concat("server=", $global:BiztalkServer, ";database=", $global:BiztalkDBName, ";Integrated Security=SSPI")
}
catch
{
	throw $_
}
}

# Stop the Biztalk applications
function Stop-BTSApplication
{ 
  param([string]$ApplicationName)
  try
  {
	    $app = $global:BtsCatalogExplorer.Applications[$ApplicationName]
	    if($app -eq $null){
	    	"Application - $ApplicationName not found"
	    }
	    else{
	    	if($app.Status -ne 2){
	    		#full stop of application
				"Stopping application - $ApplicationName" 
	    		$app.Stop(15) 
	    		$global:BtsCatalogExplorer.SaveChanges() 
				if($(($global:BtsCatalogExplorer).Applications).Status -ieq "Stopped"){
					"Stopped application - $ApplicationName" 
					Write-Host `n
				}	
				else{
                    throw "Application $ApplicationName could not be stopped."
                }
		    }
		    Else{
				"Application - $ApplicationName is already stopped"
				Write-Host `n
		    }
	    }
  }
  catch
  {
	throw $_
  }
	
}

Function Start-BTSApplication($ApplicationName){
Try{
	"Starting Application: $ApplicationName"
	$($global:BtsCatalogExplorer).Applications | ?{$_.Name -ieq $ApplicationName}|ForEach-Object{$_.start("StartAll")}
	$($global:BtsCatalogExplorer).SaveChanges()
		if($(($global:BtsCatalogExplorer).Applications).Status -ieq "Started")
		{
			"Application Started - $ApplicationName "
			Write-Host `n
		}else
		{
			"Application is not started"
			Write-Host `n
		}
}
Catch
{
	Write-Error "FAILED: $ApplicationName failed to start."
	throw $_
}
}

# Starts the Orchestration
function Start-Orchestration{
param(
[String]$ApplicationName,
[string]$OrchestrationName
)
Try
{
    $Orchestration = Get-WmiObject MSBTS_Orchestration -n root\MicrosoftBizTalkServer -filter "Name='$OrchestrationName'"
    if($Orchestration -ne $null)
    {
    	if($Orchestration.OrchestrationStatus -eq 2 -or $Orchestration.OrchestrationStatus -eq 3){
	    	if($Orchestration.OrchestrationStatus -eq 2){
				"Enlisting orchestration - $OrchestrationName"
			    $Orchestration.Enlist()
		    }
			"Starting orchestration - $OrchestrationName"
		    $Orchestration.Start()
			"Started orchestration - $OrchestrationName"
	    }
	    else{
			"Orchestration - $OrchestrationName is already started"
	    }
    }
    else{
		"Orchestration - $OrchestrationName not found"
    }

}
catch
{
	throw $_
}
}
  
# Stops the Orchestration 
 Function Stop-Orchestration{
param
(
[String]$ApplicationName,
[String]$OrchestrationName
)	
try
{
        $Orchestration = Get-Wmiobject MSBTS_Orchestration -n root\MicrosoftBiztalkServer -Filter "Name='$OrchestrationName'"
        if($Orchestration -ne $null){
            if($Orchestration.OrchestrationStatus -eq 4){               
                "Stopping orchestration: $OrchestrationName"
                $Orchestration.Stop(2,2)
				"Stopped orchestration - $OrchestrationName"
            }
            else{
				"Orchestration - $OrchestrationName is already stopped"
            }
        }
        else{
		"Orchestration - $OrchestrationName not found"
        }
    
}
catch
{
	throw $_
}
} 

# Unenlist the Orchestration  
function Unenlist-Orchestration{
param
(
[String]$ApplicationName,
[string]$OrchestrationName
)	
try
{
	$Orchestration = Get-WmiObject MSBTS_Orchestration -n root\MicrosoftBizTalkServer -filter "Name='$OrchestrationName'"
	if($Orchestration -ne $null){
		if($Orchestration.OrchestrationStatus -eq 3 -or $Orchestration.OrchestrationStatus -eq 4){
			if($Orchestration.OrchestrationStatus -eq 4){
				"Stopping orchestration - $OrchestrationName"
				$Orchestration.Stop()
			}
			"Unenlisting orchestration - $OrchestrationName"
			$Orchestration.Unenlist()
		    "Unenlisted orchestration - $OrchestrationName"
		}
		else{
			"Orchestration - $OrchestrationName is already unenlisted"
		}
	}
	else{
		"Orchestration not found" 
	}
}
catch
{
	throw $_
}
}  

# Start the Send Ports
function Start-SendPort{
param
(
[String]$ApplicationName,
[string]$portName
)
Try
{
    	$sendPort = Get-WmiObject MSBTS_SendPort -n root\MicrosoftBizTalkServer -filter "Name='$portName'"
    	if($sendPort -ne $null){
    		if($sendPort.Status -eq 1 -or $sendPort.Status -eq 2){				
    			if($sendPort.Status -eq 1){
					"Enlisting the port - $portName"
    				$sendPort.Enlist() 
    			}			
				"Starting send port - $portName `n"
    			$sendPort.Start()
    			"Started send port - $portName "
    		}
    		else{
				"Send port - $portName is already started"
    		}
    	}
    	else{
			"Send port not found"
    	}
}
Catch
{
	throw $_
}
}

# Un-enlist the Send Ports
function Unenlist-SendPort{
param
(
[String]$ApplicationName,
[string]$portName
)
Try
{
	$SendPort = Get-WmiObject MSBTS_SendPort -n root\MicrosoftBizTalkServer -filter "Name='$portName'"
	if($SendPort -ne $null){
		if($SendPort.Status -eq 3 -or $SendPort.Status -eq 2){
			"Stopping send port - $portName `n"
			if($SendPort.Status -eq 3){
				$SendPort.Stop()
			}
			
			"Unenlisting send port - $portName `n"
			$SendPort.Unenlist()
			"`n Unenlisted send port - $portName"
		}
		else{
			"Send port - $portName is already unenlisted"
		}
	}
	else{
		"Send port not found"
	}
  }
Catch
{
	throw $_
}
}

# Get all the Biztalk applications status details
function Get-BTSApplicationStatus ($ApplicationName)
{ 
try
{
	"`r`n`Getting status of application: $ApplicationName "
	$global:BtsCatalogExplorer.ConnectionString = Get-BTSConnectionString
	$app = $global:BtsCatalogExplorer.Applications[$ApplicationName]
	if($app -eq $null){
		"Application - $ApplicationName not found"
	}
	else{
		"$ApplicationName status:  $($app.Status) "
	}
}
catch
{
	throw $_
}
  
}


# Enables the biztalk receive location 
function Enable-ReceiveLocation{
param
(
[String]$ApplicationName,
[string]$locationName
)
Try
{
	$receiveLocation = get-wmiobject MSBTS_ReceiveLocation -n root\MicrosoftBizTalkServer -filter "Name='$locationName'"
	if($receiveLocation -ne $null){       
		if($receiveLocation.IsDisabled -eq $true){
			"Enabling receive location - $locationName `n"			
            $receiveLocation.Enable()		
			"`n Enabled receive location:  + $locationName"
		}
		else{
			"Receive location - $locationName is already disabled"
		}
	}
	else{
		"Receive location not found"
	}
}
catch
{
	throw $_
}
}

# Disable the Biztalk receive location 
function Disable-ReceiveLocation{
param
(
[String]$ApplicationName,
[string]$locationName
)
Try
{
	$receiveLocation = get-wmiobject MSBTS_ReceiveLocation -n root\MicrosoftBizTalkServer -filter "Name='$locationName'"
	if($receiveLocation -ne $null){
		if($receiveLocation.IsDisabled -eq $false){
			"Disabling receive location - $locationName `n"	
			$receiveLocation.Disable()
			"`n Disabled receive location - $locationName"
		}
		else{
			"Receive location $locationName is already disabled"
		}
	}
	else{
		throw "Receive location not found"
		
	}
}
catch
{
	throw $_
}
}


# Starts the Biztalk applications
function Start-BTSApplicationByComponent ($ApplicationName)
{ 
Try
{
	"`n`Start application:  $ApplicationName "
	$global:BtsCatalogExplorer.ConnectionString = Get-BTSConnectionString
	$app = $global:BtsCatalogExplorer.Applications[$ApplicationName]
	if($app -eq $null){
		"Application - $ApplicationName - not found"
	}
	else{
		#full start of application
		$app.Start(2)
		$global:BtsCatalogExplorer.SaveChanges()		
		"`n StartAllSendPorts: $ApplicationName" 
		
		$app.Start(4)
		$global:BtsCatalogExplorer.SaveChanges()	
		
		"`n StartAllSendPortGroups: $ApplicationName" 
		
		$null = $app.Start(8)
		$null = $global:BtsCatalogExplorer.SaveChanges()
		
		"Enable all ReceiveLocations: $ApplicationName "
		
		"`n Starting application - $ApplicationName"
				
		foreach ($orchestration in $app.Orchestrations){
			Write-Host "Starting orchestration:" $orchestration
			Start-Orchestration "$ApplicationName" $orchestration.FullName
		}
		
		$global:BtsCatalogExplorer = New-Object Microsoft.BizTalk.ExplorerOM.BtsCatalogExplorer
		$global:BtsCatalogExplorer.ConnectionString = Get-BTSConnectionString
		$app = $global:BtsCatalogExplorer.Applications[$ApplicationName]
		
		"`r`n`Doublecheck applicationStatus: $app.Status"
		
		If ($app.Status -ne "Started"){
			"Application not fully started"
			foreach ($sendPort in $app.SendPorts){
				"Starting send ports - $sendport.Name" 
				Start-SendPort "$ApplicationName" $sendPort.Name 
			}
		
			foreach ($receivePort in $app.ReceivePorts){
				foreach ($receiveLocation in $receivePort.ReceiveLocations){
					"Enabling receive location - $receiveLocation.Name"
					Enable-ReceiveLocation "$ApplicationName" $receiveLocation.Name
				}
			}
			foreach ($orchestration in $app.Orchestrations){
				"Starting Orchestration - $orchestration.FullName"
				Start-Orchestration "$ApplicationName" $orchestration.FullName
			}
		}
		elseif($app.Status -ieq "Started"){
			"Application fully started "
		}
	}
}
catch
{
	throw $_
}
}

# Stops the biztalk host instances
Function Stop-HostInstance{
Param
(
[String]$HostInstance
)
Try
{
$hosts = Get-WmiObject MSBTS_HostInstance -Namespace 'root/MicrosoftBiztalkServer' | ?{$_.HostName -ieq  $HostInstance}
    if( ($hosts.ServiceState -ne 1) -and ($hosts.ServiceState -ne 8)) {	
		$HostInstance = $hosts.HostName
		"Stopping HostInstance - $HostInstance" 
        $hosts.Stop() 
		"Stopped HostInstance - $HostInstance" 
    }
    else{
        throw "FAILED:Invalid Host Instance" 
		 
    }
 }
 catch
 {
	throw $_
 }
}

# Starts the biztalk host instances
Function Start-HostInstance{
Param
(
[String]$HostInstance
)
Try
{
	$hosts = Get-WmiObject MSBTS_HostInstance -Namespace 'root/MicrosoftBiztalkServer' | ?{$_.HostName -ieq  $HostInstance}
    if($hosts.ServiceState -eq 1) {
		$HostInstance=$hosts.HostName
		"Starting host-instance - $HostInstance"
        $hosts.Start()
		if($hosts.ServiceState -eq 4){
			 "Started host-instance + $HostInstance"
    	}
	}	
    else{
         throw "FAILED: Invalid Host Instance"
    } 
 }
 catch
 {
	throw $_
 }
}

# Creates BTS Application
function Create-BTSApplication
{
    param([string]$ApplicationName) 
	Try
	{
        & "$env:BTSINSTALLPATH\BTSTask.exe" AddApp /A:$ApplicationName
		$($global:BtsCatalogExplorer).Refresh()
		$app = $($global:BtsCatalogExplorer).Applications|?{$_.Name -ieq "$ApplicationName"}
		if($app.Name -ieq "$ApplicationName"){
    		Write-Host "Application created successfully"|Out-Host
		} 
		else {
    		 throw "FAILED:Application is not created" | Out-Host
			
		}
	}
	Catch
	{
		throw $_
	}
    
}

# Removes the BTS Application
function Remove-BTSApplication
{
param([string]$ApplicationName)
Try
{
    & "$env:BTSINSTALLPATH\BTSTask.exe" RemoveApp /A:$ApplicationName
	$app = $global:BtsCatalogExplorer.Applications|?{$_.Name -ieq "$ApplicationName"}
	$($global:BtsCatalogExplorer).SaveChanges()
	#if($app.Name -ine "$ApplicationName"){
	if($LASTEXITCODE -eq '0'){
		Write-Host "Application Removed successfully"|Out-Host
	} 
	else {
		  throw "FAILED:Remove Application failed."|Out-Host  
	}
}
catch
{
	throw $_
}

}

# Adds assembly in GAC
Function Add-GAC{
param
(
[String]$AssemblyPath, [String]$GacUtilPath=$null
)

Try
{
	$AssemblyName = Split-Path $AssemblyPath -Leaf
	if ($GacUtilPath){
        $GacUtilEXEPath=Join-Path $GacUtilPath -ChildPath "gacutil.exe"
    }
    else{
        $GacUtilEXEPath = "C:\Program Files (x86)\Microsoft SDKs\Windows\v8.1A\bin\NETFX 4.5.1 Tools\gacutil.exe" 
    	if(-not (Test-path $GacUtilEXEPath)){
		    $GacUtilEXEPath="C:\Program Files (x86)\Microsoft SDKs\Windows\v10.0A\bin\NETFX 4.7.2 Tools\gacutil.exe"
	    }
    }
	#& $GacUtilEXEPath /if $AssemblyPath /r FILEPATH $AssemblyPath "ESB"
	#$command=[string]::format("`"{0}`" /i `"{1}`" /r FILEPATH `"{1}`" `"ESB`" /f",$GacUtilEXEPath,$AssemblyPath)
	#$command=[string]::format("`"{0}`" /i `"{1}`" /f",$GacUtilEXEPath,$AssemblyPath)
	#cmd /c $command
	
	$GacUtilExeArgs=@("/i", "$AssemblyPath", "/f")
    &$GacUtilEXEPath $GacUtilExeArgs	
	
	if($LastExitCode -eq 0){
		Write-Host "GACED:" $AssemblyName|Out-Host
	}
	Else{
		Write-Host "LastExit Code:"$LastExitCode
		throw "Error : $AssemblyName"|Out-Host
	}
	#$SourceAssemblyVersion = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($AssemblyPath).FileVersion 
	<#
		$AssemblyName = Split-Path $AssemblyPath -Leaf
	$GacUtilEXEPath = "C:\Program Files (x86)\Microsoft SDKs\Windows\v8.1A\bin\NETFX 4.5.1 Tools\gacutil.exe" 
	#Set-Location "E:\Program Files\Mercator\InstallationUtilities\Executables\"
	#Write-Host "gacutil.exe /if $AssemblyPath /r FILEPATH $AssemblyPath ESB"
	$command=[string]::Format(" /i \\?\`"{1}`" /r FILEPATH \\?\`"{1}`" `"ESB`"",$GacUtilEXEPath,$AssemblyPath)
	write-host "& `"$GacUtilEXEPath`" $command" 
	Invoke-Expression "& `"$GacUtilEXEPath`" $command"   
	#write-host "`r`n $command"
	#cmd /c $command
	#>
	
	
	<#$GACAssemblyPath= gci -recurse "C:\Windows\Microsoft.NET\assembly\GAC_MSIL\" |?{(-not($_.PSIsContainer)) -and ($_.Name -eq "$AssemblyName")}
	$GACAssemblyPath=@()
	if(!$GACAssemblyPath){
		#search in 2.0 GAC location
	    $GACAssemblyPath= gci -recurse "C:\Windows\assembly\GAC_MSIL" |?{(-not($_.PSIsContainer)) -and ($_.Name -eq "$AssemblyName")}            
	}
	if(!$GACAssemblyPath){
		Write-Host "FAILED: Assembly not added to the gac" | Out-Host
	}

	if($($GACAssemblyPath.VersionInfo.FileVersion) -eq $SourceAssemblyVersion){
	        Write-Host "ADDED TO GAC:$AssemblyName" | Out-Host
	    }
	else{
			Write-Host "FAILED TO GAC:$AssemblyName" | Out-Host        
	}#>

}
catch
{
	throw $_
}

}

# Remove Assemblies from GAC
Function Remove-GAC{
param
(
[String]$AssemblyName,
[String]$LogFile,
[String]$GacUtilPath=$null
)
Try
{
	if ($GacUtilPath){
        $GacUtilEXEPath=Join-Path $GacUtilPath -ChildPath "gacutil.exe"
    }
    else{
        $GacUtilEXEPath = "C:\Program Files (x86)\Microsoft SDKs\Windows\v8.1A\bin\NETFX 4.5.1 Tools\gacutil.exe" 
    	if(-not (Test-path $GacUtilEXEPath)){
		    $GacUtilEXEPath="C:\Program Files (x86)\Microsoft SDKs\Windows\v10.0A\bin\NETFX 4.7.2 Tools\gacutil.exe"
	    }
    }

    $AssemblyNameWithoutExtension = $AssemblyName -ireplace ".dll",""
	& $GacUtilEXEPath /u $AssemblyNameWithoutExtension | Out-Null
	if($LastExitCode -eq 0){
		Write-Host "UNGACED:"$AssemblyName|Out-Host
	}
	Else{
		throw "FAILED:$AssemblyName"|Out-Host
	 
	}
	
	<#$GACAssemblyPath= gci -recurse "C:\Windows\Microsoft.NET\assembly\GAC_MSIL\" |?{(-not($_.PSIsContainer)) -and ($_.Name -eq "$AssemblyName")}
	if(!$GACAssemblyPath){
		#search in 2.0 GAC location
	    $GACAssemblyPath= gci -recurse "C:\Windows\assembly\GAC_MSIL" |?{(-not($_.PSIsContainer)) -and ($_.Name -eq "$AssemblyName")}            
	}
	if(!$GACAssemblyPath){
		Write-Host "REMOVED FROM GAC:" $AssemblyName|Out-Host
	}
	else{
    	Write-Host "FAILED:" $AssemblyName|Out-Host
    }#>

    	
}
catch
{
	$_.Exception.Message| Add-Content -Path $LogFile -Force
	throw $_ 
}
}

# Exports binding file 
Function Export-BindingFile{
Param
(
[String]$ApplicationName,
[String]$AppFolder
)
Try
{
$BindingFilePath = [String]::Format("{0}\Esb\{1}\Deployment\BindingFiles",$global:deploymentRootFolder,$AppFolder)

$GetBindingFiles = gci $BindingFilePath -recurse -Include "*.xml"
	ForEach($file in $GetBindingFiles){
		#Write-Host "BINDING FILE:" $file
	    & "$env:BTSINSTALLPATH\BTSTask.exe" ExportBindings /ApplicationName:$ApplicationName /Destination:$file /Server:$global:BiztalkServer /Database:$global:BiztalkDBName
		if($lastexitcode -eq 0){
	    	Write-Host "BINDING EXPORTED:$file" 
	    }
		else{
			throw "FAILED:$file"
		}
		Write-Host `r`n
	}	
}
catch
{
	throw $_
}
}

# Imports Binding file 
Function Import-BindingFile{
	Param
	(
	[String]$ApplicationName,
	[String]$BindingFilePath
	)
	Try
	{
		#Write-Host "BINDING FILE:" $BindingFilePath
		$BindingName=Split-Path $BindingFilePath -leaf
	    & "$env:BTSINSTALLPATH\BTSTask.exe" ImportBindings /A:$ApplicationName /Source:$BindingFilePath /Server:$global:BiztalkServer /Database:$global:BiztalkDBName /ImportTrackingSettings:"false"
	    if($lastexitcode -eq 0){
			Write-Host "BINDING IMPORTED:" $BindingName |Out-Host
		}
		else{
			throw "FAILED:$BindingName" |Out-Host 
		}
	}
	Catch
	{
		throw $_
	}
}

# Adds Resource in the application.
Function Add-Resources{
Param
(
[String]$ApplicationName,
[String]$ResourcePath
) 
Try{
	#Write-Host "ADDING RESOURCE:"$ResourcePath
	$ResourceName=Split-Path $ResourcePath -leaf
	& "$env:BTSINSTALLPATH\BTSTask.exe" AddResource /ApplicationName:$ApplicationName /Type:System.BizTalk:BizTalkAssembly /Overwrite /Source:$ResourcePath /Options:GacOnAdd /Server:$global:BiztalkServer /Database:$global:BiztalkDBName 
	if($lastexitcode -eq 0){
		Write-Host "RESOURCE ADDED:"$ResourceName|Out-Host
	}
	else{    
		throw "FAILED:$ResourceName"|Out-Host 
	}
}
Catch
{
	throw $_
}
}	

# Adds References to Biztalk application
Function Add-References{
param
(
[String]$ApplicationName,
[String]$Reference
)
Try
{
$Application = $global:BtsCatalogExplorer.Applications| where-object{$_.Name -ieq "$ApplicationName"}
	    #"Adding reference:$Reference"
    	$global:BtsCatalogExplorer.Applications[$ApplicationName].AddReference($global:BtsCatalogExplorer.Applications[$Reference])
		$global:BtsCatalogExplorer.SaveChanges()
		$CheckReference=$Application.References.Name | ?{$_ -eq $Reference}
        if($CheckReference){
			"REFERENCE ADDED: $Reference"
        }
        Else {
			 throw "FAILED: Add-Reference - $Reference"
			 
        }
}
Catch
{
	throw $_
}

}

# Remove resources of the application 
Function Remove-Resources{
param
(
[String]$ApplicationName
)
Try
{
$applications= $global:BtsCatalogExplorer.Applications | ?{$_.Name -ieq $ApplicationName}
$ApplicationNames = $applications.Name
$assemblies = $applications.Assemblies
Write-Host `r`n
	ForEach($assembly in $assemblies)
	{
		Write-Host `n
		$AssemblyNameWithExtension = $assembly.Name + '.dll'
		Write-Host "RESOURCES TO BE REMOVED:"$AssemblyNameWithExtension
		$AssemblyName = $assembly.DisplayName
		$LUID = $assembly.DisplayName
		& "$env:BTSINSTALLPATH\BTSTask.exe" RemoveResource /ApplicationName:$ApplicationNames /Luid:$LUID /Server:$global:BiztalkServer /Database:$global:BiztalkDBName
	}
	$($global:BtsCatalogExplorer).SaveChanges()
}
Catch
{
	throw $_
}
}

#function to reconfigure the default send handler of a dynamic send port
function Reconfigure-DynamicSendPort() { 
	
	param(
		[string]$sendPortName,
		[string]$adapter,
		[string]$sendHandler)
		
	try{
		$($global:BtsCatalogExplorer).Refresh()
		$global:BtsCatalogExplorer.SendPorts | Where-Object {$_.Name -eq $sendPortName} | foreach  {  
			# Changing the default send handlers of the dynamic port
            Write-Host "`rReconfiguring $($_.Name)`r"
            Write-Host "$adapter, $sendHandler `n`r"
			$_.SetSendHandler($adapter, $sendHandler)
		}
		$global:BtsCatalogExplorer.SaveChanges()
	}
    catch{
        throw $_
    }
}

# Derives Application Folder Name
Function GetApplicationDeploymentFolder(){
    PARAM([string]$ApplicationName)

    Switch -Wildcard ($ApplicationName) {
	"*.Database" 	  		{	 
							$ApplicationDeploymentFolderName=$ApplicationName
							break;
		 					}
	"*Framework.1.0"  		{ 
						  	$ApplicationDeploymentFolderName="Framework"
						  	break;
                       		} 					
	"*Framework.Services.1.0"  		{ 
						  	$ApplicationDeploymentFolderName="Framework.Services"
						  	break;
                       		} 
    "Mercator.Esb.*"   		{ 
						  	$ApplicationDeploymentFolderName=$ApplicationName -ireplace "Mercator.Esb.",""
						   	break;
                       		}
	"Baloise.Esb.Service.*" { 
						  	$ApplicationDeploymentFolderName=$ApplicationName -ireplace "Baloise.Esb.Service","BEService"
						  	break;
                       		}				   
    "Baloise.Esb.*"   		{ 
						 	$ApplicationDeploymentFolderName=$ApplicationName -ireplace "Baloise.Esb.",""
						  	break;
                       		}
    default           		{ 
                          	$ApplicationDeploymentFolderName=$ApplicationName
                       		} 
                        
    }
	
	Return $ApplicationDeploymentFolderName
}

Function CreateFolderJunction(){
Param($JunctionDestination,$JunctionSource,$LogPath,$InstallUtilitiesPath=$Global:InstallutilitiesPath)

    try{
	    Write-Host "Creating Juncton at $($JunctionDestination) from source $($JunctionSource)"
	    Set-Location $InstallUtilitiesPath
	    $JunctionCommand=[string]::format("Junction.exe -q ""{0} "" ""{1} "" >> ""{2}""",$JunctionDestination,$JunctionSource,$LogPath)
	    cmd /c $JunctionCommand
    }
    catch{
        throw $_
    }
}

Function DeleteFolderJunction(){
Param($JunctionDestination,$LogPath,$InstallUtilitiesPath=$Global:InstallutilitiesPath)
    try{
	    Write-Host "Deleting Juncton at $($JunctionDestination)"
	    Set-Location $InstallUtilitiesPath
	    $JunctionCommand=[string]::format("Junction.exe -d ""{0} "" >> ""{1}""",$JunctionDestination,$LogPath)
	    cmd /c $JunctionCommand
    }
    catch{
        throw $_
    }
}

# Deploys BRE bat file
Function DeployBRE(){
	Param($BREFilePath,$BREVersion,$BRELogile)
		$BREPolicyName=$BREFilePath.BaseName
		$BREPolicyFile=$BREFilePath.FullName
		Set-Location $Global:InstallutilitiesPath	
		Write-Host "Deleting Exisitng BRE policies"
		$BRECommand=[string]::format("DeployBTRules.exe /ruleSetName ""{0}"" /unpublish /ruleSetversion ""{1}"" >> ""{2}""",$BREPolicyName,$BREVersion,$BRELogile)
		cmd /c $BRECommand
		Write-Host "Creating BRE policies"
		$BRECommand=[string]::format("DeployBTRules.exe /ruleSetFile ""{0}"" /ruleSetName ""{1}"" /ruleSetVersion ""{2}"" >> ""{3}""",$BREPolicyFile,$BREPolicyName,$BREVersion,$BRELogile)
		cmd /c $BRECommand
	}

# Enables and Disables Scheduled Task on BizTalk Server based on the boolean value supplied.
function EnableDisable-ScheduledTask
{
    param([string]$TaskName,
		  [bool]$Enable,
          [string]$Server="LocalHost"
         )

    try	
    {	
		$TaskScheduler = New-Object -ComObject Schedule.Service
		$TaskScheduler.Connect($Server)
		$TaskRootFolder = $TaskScheduler.GetFolder('\')
		$Task = $TaskRootFolder.GetTask($TaskName)
		if(-not $?)
		{
			throw "Task $TaskName not found on $Server"
		}

		if($Enable)	{
			$Task.Enabled = $true
			Write-Host $TaskName " Enabled."
		}
		else {
			$Task.Stop(0)
			$Task.Enabled = $False
			Write-Host $TaskName " Disabled."
		}    
    }
    catch {
	    throw $_
    }
}


Function Get-TemplateRestartTraceAfterRebootCmd () {

$RestartTraceAfterRebootCmd=
@"
REM RestartTraceAfterReboot.cmd
REM ***************************

CD "$global:ESBRootFolder\Esb\Tools"
E:
call TransformDefaultTrace.cmd

CD "$global:ESBRootFolder\Esb\Tools"
E:
call StartDefaultTrace.cmd
"@
return $RestartTraceAfterRebootCmd
}

Function Get-TemplateStartDefaultTraceCmd () {
	param([string]$TraceName)

$StartDefaultTraceCmd=
@"
REM CREATE StopDefaultTrace.cmd
SET DRIVE=E:
SET TRACE_DIR=E:\Trace
SET TRACINGTOOL_DIR=$global:EtwToolFolder
SET APPLICATION_DIR=$global:ESBRootFolder\Esb\Tools
SET DATE_TIME=%Date:~-4,4%-%Date:~-7,2%-%Date:~-10,2%-%time:~0,2%%time:~3,2%%time:~6,2%%time:~9,2%

REM Create StopDefaultTrace.cmd
REM ***************************
ECHO CD "%TRACINGTOOL_DIR%" > "%APPLICATION_DIR%\StopDefaultTrace.cmd"
ECHO %DRIVE% >> "%APPLICATION_DIR%\StopDefaultTrace.cmd"
ECHO REM FLUSH >> "%APPLICATION_DIR%\StopDefaultTrace.cmd"
ECHO tracelog.exe -flush "%DATE_TIME%-$TraceName" >> "%APPLICATION_DIR%\StopDefaultTrace.cmd"
ECHO REM STOP >> "%APPLICATION_DIR%\StopDefaultTrace.cmd"
ECHO tracelog.exe -stop "%DATE_TIME%-$TraceName" >> "%APPLICATION_DIR%\StopDefaultTrace.cmd"
ECHO REM FORMAT >> "%APPLICATION_DIR%\StopDefaultTrace.cmd"
ECHO tracefmt.exe "%TRACE_DIR%\%DATE_TIME%-$TraceName.bin" -o "%TRACE_DIR%\%DATE_TIME%-$TraceName.txt" -tmf "%TRACINGTOOL_DIR%\Default.tmf" -v >> "%APPLICATION_DIR%\StopDefaultTrace.cmd"

REM Create TransformDefaultTrace.cmd
REM ***************************
ECHO CD "%TRACINGTOOL_DIR%" > "%APPLICATION_DIR%\TransformDefaultTrace.cmd"
ECHO %DRIVE% >> "%APPLICATION_DIR%\TransformDefaultTrace.cmd"
ECHO REM FORMAT >> "%APPLICATION_DIR%\TransformDefaultTrace.cmd"
ECHO tracefmt.exe "%TRACE_DIR%\%DATE_TIME%-$TraceName.bin" -o "%TRACE_DIR%\%DATE_TIME%-$TraceName.txt" -tmf "%TRACINGTOOL_DIR%\Default.tmf" -v >> "%APPLICATION_DIR%\TransformDefaultTrace.cmd"
"@
return $StartDefaultTraceCmd
}

Function Get-TemplateComponentFirstLine () {
	param([string]$TraceName,
		[string]$MaxTraceSize,
		[string]$EtwGuid,
		[string]$BufferSize,
		[string]$MaxBuffers
	)
$ComponentFirstLine=
@"

CD "%TRACINGTOOL_DIR%"
%DRIVE%
tracelog.exe -cir $MaxTraceSize -start "%DATE_TIME%-$TraceName"  -flags 0x1 -f "%TRACE_DIR%\%DATE_TIME%-$TraceName.bin"  -guid $EtwGuid -b $BufferSize -max $MaxBuffers
"@
return $ComponentFirstLine
}

Function Get-TemplateComponentNextLines () {
	param([string]$TraceName,
		[string]$EtwGuid
	)
$ComponentNextLines=
@"
tracelog.exe -enable "%DATE_TIME%-$TraceName"  -flags 0x1 -guid $EtwGuid
"@
return $ComponentNextLines
}

Function UpdateHostPriorityLevel($ConfigFileName,$ApplicationShortName){
	if($ConfigFileName -ieq "Mercator.Esb.Services.Mft.Service.exe.config"){
		$ApplicationPackageFolder=[String]::Format("{0}\ESB\{1}",$global:ESBRootFolder,$ApplicationShortName)
		$MftDeploymentManifestFile=Join-Path $global:ESBRootFolder -ChildPath "Esb\XML\MftDeploymentManifest.xml"
		$MFTServiceConfigPath=Join-Path $ApplicationPackageFolder -childPath "Mercator.Esb.Services.Mft.Service.exe.config"
		$ReadMftConfig=[XML](GC $MFTServiceConfigPath -ErrorAction Stop)
		$MachineName=$([System.Net.Dns]::GetHostByName(($env:COMPUTERNAME)).HostName)
		Write-Host "SERVER:"$($MachineName.ToString().ToLower())
		$ReadMftDeploymentManifest=[XML](gc $MftDeploymentManifestFile -ErrorAction Stop)
		$FindReplaceInConfig=$ReadMftDeploymentManifest.SelectNodes("//DeploymentManifest/commonDeployment/findReplaceInConfigFile")

		# Find and replace host priority level in mft service config
		if(($MachineName -ilike "*mft*") -and ($FindReplaceInConfig)){
			$MftHostPriorityLevel=$($FindReplaceInConfig|?{$_.keyName -ieq "HostPriorityLevel"}).keyValue
			Write-Host "Updating host priority level.."
			$HostPriorityLevel=$ReadMftConfig.SelectSingleNode("//configuration/appSettings/add[@key='HostPriorityLevel']")
			$HostPriorityLevel.value=$MftHostPriorityLevel
			$ReadMftConfig.Save($MFTServiceConfigPath)
			Write-Host "Updated host priority level value in config:"$($HostPriorityLevel.value)
		}
		else{
			throw "Server is not of MFT type."
		}
	}
}


Function AddEnvVariable($SystemVariable){
	Write-Host "`n -- ADDING ENVIRONMENT VARIABLES --"
	ForEach($Variable in $SystemVariable){
        Write-Host "Variable Name :"$Variable.name
        Write-Host "Variable Value:"$Variable.value
        if(![Environment]::GetEnvironmentVariable($($Variable.name),"Machine")){
		    [Environment]::SetEnvironmentVariable($($Variable.name),$($Variable.value),"Machine")
			if($LastExitCode -ne 0){
				throw "FAILED:Something went wrong while creating system variables"
			}
	    }
    }
}


Function DeploySecurity($MasterDeploySequencePath){
	$MasterDeployXML=[xml](get-content filesystem::$MasterDeploySequencePath -Force )
    $ESBDeploymentFolder=Join-Path $global:ESBRootFolder -ChildPath "Esb"
	<#if($($CertificateStorePrerequisiteXpath).ChildNodes)
	{
		$CertificateStoreDeploymentDirectory= join-path $global:ESBRootFolder -childpath "CertificateStore\"
		$CertificateStorePackageSource=[String]::Format("{0}\CertificateStore\",$ESBDeploymentFolder)
		copy-item "$($CertificateStorePackageSource)*" -Destination $CertificateStoreDeploymentDirectory -Force -Recurse -ErrorAction Stop
		$CertificateFiles=Get-ChildItem $CertificateStoreDeploymentDirectory -Recurse -Force -File
		$CertificateNames=$MasterDeployXML.selectNodes("//Prerequisite/Certificate/file")
		
		foreach($CertificateFile in $CertificateFiles){
				if($CertificateNames.name -notcontains $CertificateFile.Name){
					Remove-Item $CertificateFile.FullName -Force -Recurse -Verbose -ErrorAction Stop
			}
		}

		#delete empty folders
		Get-ChildItem $CertificateStoreDeploymentDirectory -Recurse | Where-Object {$_.PSIsContainer} | Where-Object {$_.GetFiles().Count -eq 0} | Where-Object {$_.GetDirectories().Count -eq 0} | ForEach-Object { 
            write-host "Folder $($_.FullName) is empty and will be deleted.."
            remove-item $_.FullName
        }
	}#>
	$securityCollections=$MasterDeployXML.selectNodes("//Prerequisite[@name='Security']/Collection")
	foreach($securityCollection in $SecurityCollections){
		$CollectionDeploymentDirectory= $securityCollection.serverPath
        $separator = [string[]]@("Security")
        $option = [System.StringSplitOptions]::RemoveEmptyEntries
        $subPath=$securityCollection.tfsRootPath.Split($separator,$option)[1]
        $subPath=$subPath -replace ("/","\")

        $CollectionPackageSource=Join-Path -Path $ESBDeploymentFolder -ChildPath "Security" | Join-Path -ChildPath $subPath
        if (Test-Path $CollectionDeploymentDirectory){
            Remove-Item $CollectionDeploymentDirectory -Force -Recurse
        }
        New-Item -ItemType directory -Path $CollectionDeploymentDirectory
		
		copy-item "$($CollectionPackageSource)\*" -Destination $CollectionDeploymentDirectory -Force -Recurse -ErrorAction Stop
		$CollectionFiles=Get-ChildItem $CollectionDeploymentDirectory -Recurse -Force -File
		$CollectionNames=$securityCollection.selectNodes("Folder/File")
		
		foreach($CollectionFile in $CollectionFiles){
				if($CollectionNames.name -notcontains $CollectionFile.Name){
					Remove-Item $CollectionFile.FullName -Force -Recurse -Verbose -ErrorAction Stop
			}
		}

		#delete empty folders
		Get-ChildItem $CollectionDeploymentDirectory -Recurse | Where-Object {$_.PSIsContainer} | Where-Object {$_.GetFiles().Count -eq 0} | Where-Object {$_.GetDirectories().Count -eq 0} | ForEach-Object { 
            write-host "Folder $($_.FullName) is empty and will be deleted.."
            remove-item $_.FullName
        }
	}
}


Function CheckBiztalkApp($BizTalkAppName){
	Write-Host "`n -- CHECKING PRE_REQUISITE BIZTALK APPLICATIONS --"
	ForEach($app in $BizTalkAppName)
    {
        $SearchResult=$global:BtsCatalogExplorer.Applications | ?{$_.Name -imatch $app}
	    Write-Host "Application :" $app
	    if(!$SearchResult.Name){
            Write-Error "NOT FOUND : " $app
            Exit 1
        }
    }
}


