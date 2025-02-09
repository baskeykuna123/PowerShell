###########################################################################" 
# 
# NAME: Mercator.ps1 
# 
# AUTHOR: Johan De Prins
# EMAIL: johan.de.prins@microsoft.com
# 
# COMMENT: Script with functions
# 
# VERSION HISTORY: 
# 1.0 20.09.2011 - Initial release 
# 
###########################################################################" 
      
Function write2EventLog ($Message, $EntryType = "Information")
{
	#check if event source exists
	If (!(test-path "HKLM:\SYSTEM\CurrentControlSet\Services\Eventlog\Application\StopStart"))
	{
		new-eventlog -LogName "Application" -source "StopStart"
		sleep -milli 500			
	}

	#write to eventlog	
	write-eventlog -LogName "Application" -source "StopStart" -Message $Message -EventId 25 -EntryType $EntryType	
}

Function Add2Log ($Message, $LogFile)
{  
	$StartTime = Get-date -format F
	add-content -path $LogFile -value ($StartTime + " - " + $Message )
	write-host ($Message)
}

Function GetIISVersion()
{
	try
	{
		$IISProperties=get-itemproperty HKLM:\SOFTWARE\Microsoft\InetStp\
		if ($IISProperties) {
		   Return $IISProperties
		   
		} 
		else {
		    Write-Host "IIS is not installed"
		}
		
	}
	catch
	{	
		write2EventLog $_ "Error"		
		throw $_
	}
}

try
{
    $IISVersion = GetIISVersion

    if ($IISVersion.majorversion -gt "6")
    {
		Import-Module WebAdministration		
	}
}
catch
{
	write2EventLog $_ "Error"
	throw $_
}

Function StopAppPool($AppPoolName)
{
	try
	{
	    $IISVersion = GetIISVersion
		$appPoolFound = $false

	    if ($IISVersion.majorversion -gt "6")
	    {
	      $a = [System.Reflection.Assembly]::LoadFrom( "C:\windows\system32\inetsrv\Microsoft.Web.Administration.dll" )
	      $pools = (New-Object Microsoft.Web.Administration.ServerManager).ApplicationPools | Select Name, State
	      foreach($i in $pools){
	        if ($i.state -eq "started" -and $i.name -eq $AppPoolName)
	          {                
			    Stop-WebAppPool -Name $i.name                
                $message = [String]::Format("Application Pool {0} stopped.",$i.name)
			  	Write-host $message
			  	write2EventLog $message "Information"
				$appPoolFound = $true
			  }
	        if ($i.state -eq "stopped" -and $i.name -eq $AppPoolName)
	          {
                $message = [String]::Format("Application Pool {0} is already stopped!",$i.name)
			  	Write-Warning $message
			  	write2EventLog $message "Warning"
				$appPoolFound = $true
	           }
	        }
	    }

	    if ($IISVersion.majorversion -eq "6") 
	    {
	      $computer = "Localhost" 
	      $namespace = "root\MicrosoftIISv2"
	      $a = Get-WmiObject -class IIsApplicationPoolSetting -computername $computer -namespace $namespace | Select Name, AppPoolState
	      foreach ($i in $a) 
		  {
			  $splitstring = $i.Name.tostring().Split("/")
			  $currentAppPoolName = $splitstring[$splitstring.Length-1]
	          if ($currentAppPoolName -eq $AppPoolName)
			  {
			  	$AppPool = Get-WmiObject -Namespace $namespace -class "IIsApplicationPool" | Where-object {$_.Name -eq $i.Name}
	          	$AppPool.Stop()
				$message = [String]::Format("Application Pool {0} stopped.",$AppPoolName)
				Write-Host $message
				write2EventLog $message "Information"
			  	$appPoolFound = $true
			  }
	      }
	    }
		
		if ($appPoolFound -eq $false)
		{
			$message = [String]::Format("Application Pool {0} not found!",$AppPoolName)
			Write-Warning $message
			write2EventLog $message "Error"		
		}
	}
	catch
	{	
		write2EventLog $_ "Error"		
		throw $_
	}
}

Function StartAppPool($AppPoolName)
{
	try
	{
	    $IISVersion = GetIISVersion
		$appPoolFound = $false
		
	    if ($IISVersion.majorversion -gt "6")
	    {
	      $a = [System.Reflection.Assembly]::LoadFrom( "C:\windows\system32\inetsrv\Microsoft.Web.Administration.dll" )
	      $pools = (New-Object Microsoft.Web.Administration.ServerManager).ApplicationPools | Select Name, State
	      foreach($i in $pools){
	        if ($i.state -eq "stopped" -and $i.name -eq $AppPoolName)
	          {
			    Start-WebAppPool -Name $i.Name
				$message = [String]::Format("Application Pool {0} started.",$i.name)
			  	Write-host $message
			  	write2EventLog $message "Information"
				$appPoolFound = $true
			  }
	        if ($i.state -eq "started" -and $i.name -eq $AppPoolName)
	          {
                $message = [String]::Format("Application Pool {0} is already started!",$i.name)
			  	Write-Warning $message
			  	write2EventLog $message "Warning"
				$appPoolFound = $true
	          }
	      }
	    }

	    if ($IISVersion.majorversion -eq "6") 
	    {
	      $computer = "Localhost" 
	      $namespace = "root\MicrosoftIISv2"
	      $a = Get-WmiObject -class IIsApplicationPoolSetting -computername $computer -namespace $namespace | Select Name, AppPoolState
	      foreach ($i in $a) 
		  {
	        $splitstring = $i.Name.tostring().Split("/")
			$currentAppPoolName = $splitstring[$splitstring.Length-1]
	        if ($currentAppPoolName -eq $AppPoolName)
			{
	          $AppPool = Get-WmiObject -Namespace "root\MicrosoftIISv2" -class "IIsApplicationPool" | Where-object {$_.name -eq $i.name}
	          $AppPool.Start() 
			  $message = [String]::Format("Application Pool {0} started.",$AppPoolName)
			  Write-Host $message
			  write2EventLog $message "Information"
			  $appPoolFound = $true
	        }
	      }
	    }
		
		if ($appPoolFound -eq $false)
		{
			$message = [String]::Format("Application Pool {0} not found!",$AppPoolName)
			Write-Warning $message
			write2EventLog $message "Error"		
		}
	}
	catch
	{	
		write2EventLog $_ "Error"		
		throw $_
	}
}

Function StopAllAppPools
{
	try
	{
	    $IISVersion = GetIISVersion

	    if ($IISVersion.majorversion -gt "6")
	    {
	      $a = [System.Reflection.Assembly]::LoadFrom( "C:\windows\system32\inetsrv\Microsoft.Web.Administration.dll" )
	      $pools = (New-Object Microsoft.Web.Administration.ServerManager).ApplicationPools | Select Name, State
	      foreach($i in $pools){
	        if ($i.state -eq "started")
	          {"Stopping Application Pool : " + $i.name; Stop-WebAppPool -Name $i.Name}
	        else {write-warning (" Application Pool : " + $i.name + " already stopped!")}
	        }
	    }

	    if ($IISVersion.majorversion -eq "6") 
	    {
	      $computer = "LocalHost" 
	      $namespace = "root\MicrosoftIISv2" 
	      $a = Get-WmiObject -class IIsApplicationPoolSetting -computername $computer -namespace $namespace | Select Name, AppPoolState
	      foreach ($i in $a) {
			#if ($i.AppPoolstate -eq 4){"Started Application Pools are: " + $i.name}
	        $AppPool = Get-WmiObject -Namespace "root\MicrosoftIISv2" -class "IIsApplicationPool" | Where-object {$_.name -eq $i.name}
	        $AppPool.Stop() 
	        $i.name + " Stopped"}
	    }
	}
	catch
	{	
		write2EventLog $_ "Error"		
		throw $_
	}
}

Function StartAllAppPools
{
	try
	{
	    $IISVersion = GetIISVersion
	    if ($IISVersion.majorversion -gt "6")
	    {
	      $a = [System.Reflection.Assembly]::LoadFrom( "C:\windows\system32\inetsrv\Microsoft.Web.Administration.dll" )
	      $pools = (New-Object Microsoft.Web.Administration.ServerManager).ApplicationPools | Select Name, State
	      foreach($i in $pools){
	        if ($i.state -eq "stopped")
	          {"Starting Application Pool : " + $i.name; Start-WebAppPool -Name $i.Name}
	        else {Write-Warning (" Application Pool : " + $i.name + " already started")}
	      }
	    }

	    if ($IISVersion.majorversion -eq "6") 
	    {
	      $computer = "LocalHost" 
	      $namespace = "root\MicrosoftIISv2" 
	      $a = Get-WmiObject -class IIsApplicationPoolSetting -computername $computer -namespace $namespace | Select Name, AppPoolState
	      foreach ($i in $a) {
	#        if ($i.AppPoolstate -eq 2){"Stopped Application Pools are: " + $i.name}
	        $AppPool = Get-WmiObject -Namespace "root\MicrosoftIISv2" -class "IIsApplicationPool" | Where-object {$_.name -eq $i.name}
	        $AppPool.Start() 
	        $i.name + " Started"}
	    }
	}
	catch
	{	
		write2EventLog $_ "Error"		
		throw $_
	}
}

function StopIIS 
{ 
	try
	{
		c:\Windows\System32\iisreset.exe "/stop" 
	}
	catch
	{	
		write2EventLog $_ "Error"		
		throw $_
	}
}

function StartIIS 
{
	try
	{
		c:\Windows\System32\iisreset.exe "/start" 
	}
	catch
	{	
		write2EventLog $_ "Error"		
		throw $_
	}
}

Function StopProcess ($ProcessName)
{
	try
	{
	    foreach ($i in Get-Process) 
	    {
	      if ($i.processname -eq $ProcessName) {
	        add2log " Stopping process" $ProcessName
	        Stop-Process -ProcessName $ProcessName
	        }
	    }
	}
	catch
	{	
		write2EventLog $_ "Error"		
		throw $_
	}
}

Function RemoveDirectory ($DirPath)
{
	try
	{
	    $sPath = Test-Path $DirPath
	      if ($sPath -like "true") {
	        add2log " Removing Directory: " $Dirpath
	        remove-item $DirPath -force -recurse
	        }
	      else {
	        Write-warning (" The Path " + $Dirpath + " does not exist")
	      }
	}
	catch
	{	
		write2EventLog $_ "Error"		
		throw $_
	}
}

function StopWebsite($WebsiteName)
{   
	try
	{
	    $IISVersion = GetIISVersion
		$websiteFound = $false
		
	    if ($IISVersion.majorversion -gt "6") 
	    {
	      $Websites = Get-Website | select Name,State
	      foreach($i in $Websites)
	      {
	        if ($i.state -eq "started" -and $i.Name -eq $WebsiteName)
			{				
				Stop-Website -Name $i.Name
				$message = [String]::Format("Website {0} stopped.",$i.name)
			  	Write-host $message
			  	write2EventLog $message "Information"
				$websiteFound = $true
			}
	        if ($i.state -eq "stopped" -and $i.Name -eq $WebsiteName)
			{
				$message = [String]::Format("Website {0} already stopped.",$i.name)
				Write-Warning $message
			  	write2EventLog $message "Warning"
				$websiteFound = $true
			}
	      }
	    }
		
	    if ($IISVersion.majorversion -eq "6") 
		{
			cscript.exe C:\Windows\System32\IISWeb.vbs /stop $WebsiteName
			$websiteFound = $true
		} 
		
		if ($websiteFound -eq $false)
		{
			$message = [String]::Format("Website {0} not found!",$WebsiteName)
			Write-Warning $message
			write2EventLog $message "Error"		
		}
	}
	catch
	{	
		write2EventLog $_ "Error"		
		throw $_
	}
}

function StartWebsite($WebsiteName)
{
	try
	{
	    $IISVersion = GetIISVersion
		$websiteFound = $false
		
	    if ($IISVersion.majorversion -gt "6") 
	    {
	      $Websites = Get-Website | select Name,State
	      foreach($i in $Websites)
	      {
	        if ($i.state -eq "Stopped" -and $i.Name -eq $WebsiteName)
			{
				Start-Website -Name $i.Name		
				$message = [String]::Format("Website {0} started.",$i.name)
			  	Write-host $message
			  	write2EventLog $message "Information"
				$websiteFound = $true
			}
	        if ($i.state -eq "Started" -and $i.Name -eq $WebsiteName)
			{
				$message = [String]::Format("Website {0} already started.",$i.name)
				Write-Warning $message
			  	write2EventLog $message "Warning"
				$websiteFound = $true
			}
	      }
	    }
		
	    if ($IISVersion.majorversion -eq "6") 
		{
	      $result = cscript.exe C:\Windows\System32\IISWeb.vbs /start $WebsiteName
		  
		  if ($result[$result.Length-1] -match "Server (.*) is already STARTED")
		  {
			$message = [String]::Format("Website {0} is already started.",$i.name)
			Write-Warning $message
			write2EventLog $message "Warning"		  
		  	$websiteFound = $true
		  }
		  elseif ($result[$result.Length-1] -match "Server (.*) has been STARTED")
		  {
			$message = [String]::Format("Website {0} has been started.",$i.name)
			Write-Warning $message
			write2EventLog $message "Information"	
			$websiteFound = $true
		  }
	    } 
		
		if ($websiteFound -eq $false)
		{
			$message = [String]::Format("Website {0} not found!",$WebsiteName)
			Write-Warning $message
			write2EventLog $message "Error"		
		}
	}
	catch
	{	
		write2EventLog $_ "Error"		
		throw $_
	}
}

function GetWebsites
{
	try
	{
	    $IISVersion = GetIISVersion
			    if ($IISVersion.majorversion -gt "6") {
	        $test = Get-Website | FL -Property Name,State
	        $test
	    }
	    if ($IISVersion.majorversion -eq "6") {$test = cscript.exe C:\Windows\System32\IISWeb.vbs /query
	        $test
	    }
	}
	catch
	{	
		write2EventLog $_ "Error"		
		throw $_
	}
}

Function StopService ($Service, $force=$false)
{
	try
	{
		#stop-Service $Service
		#"The Service : " + $Service + " is stopped!"
		$force = [bool] $force
	    $a = Get-Service | where-object {(($_.DisplayName -Like $Service) -or ($_.Name -Like $Service))}
	      if ( ! $a ) 
	        {
                $message = [String]::Format("The requested service {0} does not exist!.",$Service)
			     Write-host $message
			     write2EventLog $message "Warning"
	        }
	    elseif ($a.Status -eq "Running")
            {
				if ($force)
                    {
	          		Stop-Service $Service -Force
                    }
			  	else
                    {
			  		Stop-Service $Service
                    }		        
                $message = [String]::Format("The requested service {0} is succesfully stopped.",$Service)
			     Write-host $message
			     write2EventLog $message "Information"
	        }
         else
	        {
                $message = [String]::Format("The requested service {0} was already stopped.",$Service)
			     Write-Warning $message
			     write2EventLog $message "Warning"
	        }       
	}
	catch
	{	
		write2EventLog $_ "Error"		
		throw $_
	}
}

function Set-ServiceStartupType { 
param ([string]$name, [string]$type) 
    if ("Automatic", "Manual", "Disabled" -contains $type) {Set-Service -Name $name -StartupType $type} 
    else {Write-Host "Type must be Automatic, Manual or Disabled"} 
}

Function StartService ($Service)
{
	try
	{
		#Start-Service $Service
		#"The Service : " + $Service + " is started!"
	    $a = Get-Service | where-object {(($_.DisplayName -Like $Service) -or ($_.Name -Like $Service))}
	      if ( ! $a ) 
	        {
                $message = [String]::Format("The requested service {0} does not exist!.",$Service)
			     Write-host $message
			     write2EventLog $message "Warning"
	        }
	    elseif ($a.Status -eq "Stopped")
	        {
	            start-Service $Service 
                $message = [String]::Format("The requested service {0} is succesfully started.",$Service)
			     Write-host $message
			     write2EventLog $message "Information"
	        }
         else
	        {
                $message = [String]::Format("The requested service {0} was already started.",$Service)
			     Write-Warning $message
			     write2EventLog $message "Warning"
	        }       
	}
	catch
	{	
		write2EventLog $_ "Error"		
		throw $_
	}
}

Function RestartService ($Service)
{
	try
	{
	    $a = Get-Service | where-object {(($_.DisplayName -Like $Service) -or ($_.Name -Like $Service))}
	      if ( ! $a ) 
	        {
                 $message = [String]::Format("The requested service {0} does not exist!.",$Service)
			     Write-host $message
			     write2EventLog $message "Warning"
	        }
	    else
	        {
			Stop-Service $Service -Force
	        start-Service $Service 
                $message = [String]::Format("The requested service {0} is succesfully re-started.",$Service)
			     Write-host $message
			     write2EventLog $message "Information"
	        }
              
	}
	catch
	{	
		write2EventLog $_ "Error"		
		throw $_
	}
}

Function GetService ($Service)
{
	try
	{
	    $service = Get-Service | where-object {($_.DisplayName -Like $Service -or $_.Name -Like $Service)}
	    $Service | FL -Property DisplayName, status
	}
	catch
	{	
		write2EventLog $_ "Error"		
		throw $_
	}
}

Function StopComPlus ($ComPlusAppName)
{
	try
	{
	    $RemoteMachine = "Localhost"
	    $comObj = New-Object -comobject COMAdmin.COMAdminCatalog
	    $comObj.Connect($RemoteMachine)
	    $comObj.ShutdownApplication($COMPlusAppName)
	}
	catch
	{	
		write2EventLog $_ "Error"		
		throw $_
	}
}

Function StartComPlus ($ComPlusAppName)
{
	try
	{
	    $RemoteMachine = "Localhost"
	    $comObj = New-Object -comobject COMAdmin.COMAdminCatalog
	    $comObj.Connect($RemoteMachine)
	    $comObj.StartApplication($COMPlusAppName)
	}
	catch
	{	
		write2EventLog $_ "Error"		
		throw $_
	}
}


Function DeleteOldLatestFoldersByConfiguration ($buildconfiguration, $folderspec, $isshortname)
{
    if ($isshortname -eq $true)
	{
		if ($buildconfiguration -eq "D")
			{$maxage = 5}
		else
			{$maxage = 10}
			
		#$(Get-Item $folderspec)	| Get-ChildItem | ForEach-Object {
		Get-ChildItem -Path $folderspec | ForEach-Object {
			if ($_.name.ToUpper().StartsWith("L" + $buildconfiguration.ToUpper())){					
				$folderAge = (New-TimeSpan $($_.CreationTime	)$(Get-Date)).Days 
				#add2log $_.name "	" $folderAge "	" $_.CreationTime
				if ($folderAge -gt $maxage){
					#add2log $_.name "	" $folderAge "	" $_.CreationTime
					Remove-Item $_.PSPath -Recurse -Force
					add2log $_.name " Removed"
				}
			}
		}
	}
	else	
	{	
		if ($buildconfiguration -eq "DEBUG")
			{$maxage = 5}
		else
			{$maxage = 10}
			
		#$(Get-Item $folderspec)	| Get-ChildItem | ForEach-Object 
		
		$folders = (Get-ChildItem -Path $folderspec | where{$_.Psiscontainer}) #| Where ($_.name.ToUpper().StartsWith("LATEST." + $buildconfiguration.ToUpper())))
		foreach ($folder in $folders)
		{			
			if ( ($folder.name.ToUpper().StartsWith("LATEST." + $buildconfiguration.ToUpper())) -or ($folder.name.ToUpper().StartsWith($buildconfiguration.ToUpper())) ) 
			{					
				$folderAge = (New-TimeSpan $($folder.CreationTime	)$(Get-Date)).Days 
				#add2log $_.name "	" $folderAge "	" $_.CreationTime
				if ($folderAge -gt $maxage)
				{
					#add2log $_.name "	" $folderAge "	" $_.CreationTime
					Remove-Item $folder.PSPath -Recurse -Force
					add2log $folder.name " Removed"
				}
			}
		}
	}
}

Function DeleteOldLatestFolders ($folder)
{
	DeleteOldLatestFoldersByConfiguration "DEBUG" $folder $false
	DeleteOldLatestFoldersByConfiguration "CUSTOM" $folder $false
	DeleteOldLatestFoldersByConfiguration "D" $folder $true
	DeleteOldLatestFoldersByConfiguration "C" $folder $true
}

Function DeleteOldApplicationFoldersSingleApplication ($application, $folderspec)
{
	$maxage = 4
	
	$Shares = Get-WmiObject -Class Win32_Share -ComputerName "localhost"
	
	$(Get-Item $folderspec)	| Get-ChildItem | ForEach-Object {
		if ($_.Name.Length -gt $application.Length) {
			if ($_.Name.SubString(0, $application.Length) -eq $application){		
				$currentFolder=$_
				$folderAge = (New-TimeSpan $($_.CreationTime	)$(Get-Date)).Days 
				#add2log $_.name "	" $folderAge "	" $_.CreationTime
				if ($folderAge -gt $maxage){
					#add2log $_.name "	" $folderAge "	" $_.CreationTime
					if ((Get-WmiObject -Class Win32_Share -ComputerName "localhost" | Where {$_.Path -eq $currentFolder.FullName}) -eq $null){
						#add2log $_.name "	" $folderAge "	" $_.CreationTime
						Remove-Item $_.PSPath -Recurse -Force
						add2log $_.name " Removed"
					}
					else{
						#add2log $_.name "	" $folderAge "	" $_.CreationTime
						#add2log $_.name " not removed"
					}
				}
			}
		}
		#Else{add2log $_.Name  '  ' $_.Name.Length  '  '  $application.Length}
	}
}

Function DeleteOldApplicationFolders ($applicationRootFolder)
{
	$buildApplicationOverviewFileName = [String]::Concat($applicationRootFolder, "\Applications\BuildApplicationsOverview.xml")
	if ( (Test-path $buildApplicationOverviewFileName ) -eq $false)
	{    	
    	add2log (" BuildApplicationsOverview.xml does not exist!")
		break
    }
	
	$xml = New-Object XML
	$xml.load($buildApplicationOverviewFileName)
	$buildApplications = $xml.BuildApplicationsOverview.BuildApplication
	foreach ($buildApplication in $buildApplications) 
	{
		DeleteOldApplicationFoldersSingleApplication $buildApplication $applicationRootFolder
	}
}

Function CleanUpDir ($targetDir, $daysToKeep)
{
	Get-ChildItem $targetDir | where {$_.LastWriteTime -lt (Get-Date).AddDays(-$daysToKeep) -and  (! $_.PSIsContainer) } | remove-item -Force
}

Function CleanUpDirRecurse ($targetDir, $daysToKeep)
{
	Get-ChildItem $targetDir -recurse | where {$_.LastWriteTime -lt (Get-Date).AddDays(-$daysToKeep) -and  (! $_.PSIsContainer) } | remove-item -Force
}

Function ReCreateApplicationPool ($appPoolName, $appPoolUser, $appPoolUserPassword, $DotNetVersion, $Enable32Bit, $IdleTimeOut, $ManagedPipeLineMode, $MaxWorkerProcesses = 1)
{
	try
	{
		$IISVersion = GetIISVersion
		
		if ($IISVersion.majorversion -gt "6")
	    {
			if ((Test-Path IIS:\AppPools\$appPoolName) -eq $true)
			{
				Remove-Item	IIS:\AppPools\$appPoolName -Recurse
			}
			
			if ((Test-Path IIS:\AppPools\$appPoolName) -eq $false)
			{
				$newAppPool = New-Item IIS:\AppPools\$appPoolName
				$newAppPool.managedRuntimeVersion = $DotNetVersion
				$newAppPool.enable32BitAppOnWin64 = $Enable32Bit			
				$newAppPool.managedPipeLineMode = $ManagedPipeLineMode
				$newAppPool.processModel.identityType = [String]("SpecificUser")
				$newAppPool.processModel.username = $appPoolUser
				$newAppPool.processModel.password = $appPoolUserPassword
				$newAppPool.processModel.idleTimeout =  [TimeSpan]::FromMinutes($IdleTimeOut)
				$newAppPool.processModel.maxprocesses = [int] $MaxWorkerProcesses
				$newAppPool.recycling.periodicRestart.time = "0"
				
				if ($newAppPool.recycling.periodicRestart.Schedule.Collection)
				{
					$newAppPool.recycling.periodicRestart.Schedule.Collection[0].value = [TimeSpan] "2:30:00"   
				}
				else
				{
					set-ItemProperty IIS:\AppPools\$appPoolName -Name Recycling.periodicRestart.schedule -Value @{value="2:30:00"} 
				}

				$newAppPool | Set-Item
			}
	    }
	}
	catch
	{	
		write2EventLog $_ "Error"		
		throw $_
	}
}

Function ReCreateApplicationPoolWin2012 ($appPoolName, $appPoolUser, $appPoolUserPassword, $DotNetVersion, $Enable32Bit, $IdleTimeOut, $ManagedPipeLineMode, $MaxWorkerProcesses = 1)
{
	try
	{
		$IISVersion = GetIISVersion
		
		if ($IISVersion.majorversion -eq "8")
	    {
			if ((Test-Path IIS:\AppPools\$appPoolName) -eq $true)
			{
				Remove-Item	IIS:\AppPools\$appPoolName -Recurse
			}
			
			if ((Test-Path IIS:\AppPools\$appPoolName) -eq $false)
			{
				$newAppPool = New-Item IIS:\AppPools\$appPoolName
				$newAppPool.managedRuntimeVersion = $DotNetVersion
				$newAppPool.enable32BitAppOnWin64 = $Enable32Bit			
				$newAppPool.managedPipeLineMode = $ManagedPipeLineMode
				$newAppPool.processModel.identityType = [String]("SpecificUser")
				$newAppPool.processModel.username = $appPoolUser
				$newAppPool.processModel.password = $appPoolUserPassword
				$newAppPool.processModel.idleTimeout =  [TimeSpan]::FromMinutes($IdleTimeOut)
				$newAppPool.processModel.maxprocesses = [int] $MaxWorkerProcesses
				$newAppPool.recycling.periodicRestart.time = "0"
				
				if ($newAppPool.recycling.periodicRestart.Schedule.Collection)
				{
					$newAppPool.recycling.periodicRestart.Schedule.Collection[0].value = [TimeSpan] "2:30:00"   
				}
				else
				{
					set-ItemProperty IIS:\AppPools\$appPoolName -Name Recycling.periodicRestart.schedule -Value @{value="2:30:00"} 
				}

				$newAppPool | Set-Item
			}
	    }
	}
	catch
	{	
		write2EventLog $_ "Error"		
		throw $_
	}
}

Function DeleteWebSite ($SiteName)
{
	try
	{
		$IISVersion = GetIISVersion
		
		if ($IISVersion.majorversion -gt "6")
	    {
			if ((Test-Path IIS:\Sites\$SiteName) -eq $true)
			{
				Remove-Item	IIS:\Sites\$SiteName
			}
	    }
	}
	catch
	{	
		write2EventLog $_ "Error"		
		throw $_
	}
}

Function DeleteWebSiteWin2012 ($SiteName)
{
	try
	{
		$IISVersion = GetIISVersion
		
		if ($IISVersion.majorversion -eq "8")
	    {
			if ((Test-Path IIS:\Sites\$SiteName) -eq $true)
			{
				Remove-Item	IIS:\Sites\$SiteName
			}
	    }
	}
	catch
	{	
		write2EventLog $_ "Error"		
		throw $_
	}
}

Function CreateWebSite ($SiteName, $PortNumber, $PhysicalPath)
{
	try
	{
		$IISVersion = GetIISVersion
		
		if ($IISVersion.majorversion -eq "7")
	    {		
			if ((Test-Path IIS:\Sites\$SiteName) -eq $false)
			{
				$newSite = New-Item IIS:\Sites\$SiteName -bindings @{protocol="http";bindingInformation="*:" + $PortNumber + ":"} -physicalPath $PhysicalPath
			}
	    }
	}
	catch
	{	
		write2EventLog $_ "Error"		
		throw $_
	}
}

Function CreateWebSiteWin2012 ($SiteName, $PortNumber, $PhysicalPath)
{
	try
	{
		$IISVersion = GetIISVersion
		
		if ($IISVersion.majorversion -eq "8")
	    {		
			if ((Test-Path IIS:\Sites\$SiteName) -eq $false)
			{
				$newSite = New-Item IIS:\Sites\$SiteName -bindings @{protocol="http";bindingInformation="*:" + $PortNumber + ":"} -physicalPath $PhysicalPath
			}
	    }
	}
	catch
	{	
		write2EventLog $_ "Error"		
		throw $_
	}
}
Function Update-AssignAppPoolToWebSite ($SiteName, $AppPoolName)
{
	try
	{
		$IISVersion = GetIISVersion
		
		if ($IISVersion.majorversion -eq "7")
	    {
			if ((Test-Path IIS:\Sites\$SiteName) -eq $true)
			{
				Set-ItemProperty -Path iis:\sites\$SiteName -name applicationPool -value $AppPoolName
			}
	    }
	}
	catch
	{	
		write2EventLog $_ "Error"		
		throw $_
	}
}

Function Update-AssignAppPoolToWebSiteWin2012 ($SiteName, $AppPoolName)
{
	try
	{
		$IISVersion = GetIISVersion
		
		if ($IISVersion.majorversion -eq "8")
	    {
			if ((Test-Path IIS:\Sites\$SiteName) -eq $true)
			{
				Set-ItemProperty -Path iis:\sites\$SiteName -name applicationPool -value $AppPoolName
			}
	    }
	}
	catch
	{	
		write2EventLog $_ "Error"		
		throw $_
	}
}

Function Update-AssignAppPoolToWebSiteWin2012 ($SiteName, $AppPoolName)
{
	try
	{
		$IISVersion = GetIISVersion
		
		if ($IISVersion.majorversion -eq "8")
	    {
			if ((Test-Path IIS:\Sites\$SiteName) -eq $true)
			{
				Set-ItemProperty -Path iis:\sites\$SiteName -name applicationPool -value $AppPoolName
			}
	    }
	}
	catch
	{	
		write2EventLog $_ "Error"		
		throw $_
	}
}

Function ReCreateVirtualDirInWebSite ($SiteName, $VirtualDirName, $PhysicalPath, $AppPoolName)
{
	try
	{
		$IISVersion = GetIISVersion
		
		if ($IISVersion.majorversion -eq "7")
	    {		
			if ((Test-Path IIS:\Sites\$SiteName) -eq $true)
			{
				$newVirDir = New-Item -Path "IIS:\Sites\$SiteName\$VirtualDirName" -physicalpath $PhysicalPath -type Application -Force

				if ($AppPoolName -ne $null)
				{
					Set-ItemProperty -Path "IIS:\Sites\$SiteName\$VirtualDirName" -name applicationPool -value $AppPoolName
				}
			}
	    }
	}
	catch
	{	
		write2EventLog $_ "Error"		
		throw $_
	}
}

Function ReCreateVirtualDirInWebSiteWin2012 ($SiteName, $VirtualDirName, $PhysicalPath, $AppPoolName)
{
	try
	{
		$IISVersion = GetIISVersion
		
		if ($IISVersion.majorversion -eq "8")
	    {		
			if ((Test-Path IIS:\Sites\$SiteName) -eq $true)
			{
				$newVirDir = New-Item -Path "IIS:\Sites\$SiteName\$VirtualDirName" -physicalpath $PhysicalPath -type Application -Force

				if ($AppPoolName -ne $null)
				{
					Set-ItemProperty -Path "IIS:\Sites\$SiteName\$VirtualDirName" -name applicationPool -value $AppPoolName
				}
			}
	    }
	}
	catch
	{	
		write2EventLog $_ "Error"		
		throw $_
	}
}

Function Update-AnonymousAuthenticationForVirtualDirectory ($SiteName, $VirtualDirName, $AnonymousAuthenticationEnabled)
{
	try
	{
		Set-WebConfigurationProperty -filter /system.webServer/security/authentication/anonymousAuthentication -Name enabled -Value $AnonymousAuthenticationEnabled -PSPath IIS:\ -Location "$SiteName/$VirtualDirName"
	}
	catch
	{	
		write2EventLog $_ "Error"		
		throw $_
	}
}

Function Update-WindowsAuthenticationForVirtualDirectory ($SiteName, $VirtualDirName, $WindowsAuthenticationEnabled)
{
	try
	{
		Set-WebConfigurationProperty -filter /system.WebServer/security/authentication/windowsAuthentication -name enabled -value $WindowsAuthenticationEnabled -PSPath IIS:\ -Location "$SiteName/$VirtualDirName"
	}
	catch
	{	
		write2EventLog $_ "Error"		
		throw $_
	}
}

Function Update-BasicAuthenticationForVirtualDirectory ($SiteName, $VirtualDirName, $BasicAuthenticationEnabled)
{
	try
	{
		Set-WebConfigurationProperty -filter /system.WebServer/security/authentication/basicAuthentication -name enabled -value $BasicAuthenticationEnabled -PSPath IIS:\ -Location "$SiteName/$VirtualDirName"
	}
	catch
	{	
		write2EventLog $_ "Error"		
		throw $_
	}
}

Function Update-AspImpersonationForVirtualDirectory ($SiteName, $VirtualDirName, $AspImpersonationEnabled)
{
	try
	{
		$strPsPath = [string]::Format("MACHINE/WEBROOT/APPHOST/{0}/{1}",$SiteName,$VirtualDirName)
		Set-WebConfigurationProperty -Name impersonate -Filter system.web/identity -Value $AspImpersonationEnabled -PSPath $strPsPath
	}
	catch
	{	
		write2EventLog $_ "Error"		
		throw $_
	}
}

Function Update-FormsAuthenticationForVirtualDirectory ($SiteName, $VirtualDirName, $FormsAuthenticationEnabled)
{
	try
	{
		$strPsPath = [string]::Format("MACHINE/WEBROOT/APPHOST/{0}/{1}",$SiteName,$VirtualDirName)
		Set-WebConfigurationProperty -Name mode -Filter system.web/authentication -Value $FormsAuthenticationEnabled -PSPath $strPsPath	
	}
	catch
	{	
		write2EventLog $_ "Error"		
		throw $_
	}
}

Function Update-AssignAppPoolToVirtualDir ($SiteName, $VirtualDirName, $AppPoolName)
{
	try
	{
		$IISVersion = GetIISVersion
		
		if ($IISVersion.majorversion -eq "7")
	    {
			if ((Test-Path IIS:\Sites\$SiteName) -eq $true)
			{
				Set-ItemProperty -Path "IIS:\Sites\$SiteName\$VirtualDirName" -name ApplicationPool -value $AppPoolName
			}
	    }
	}
	catch
	{	
		write2EventLog $_ "Error"		
		throw $_
	}
}

Function Update-AssignAppPoolToVirtualDirWin2012 ($SiteName, $VirtualDirName, $AppPoolName)
{
	try
	{
		$IISVersion = GetIISVersion
		
		if ($IISVersion.majorversion -eq "8")
	    {
			if ((Test-Path IIS:\Sites\$SiteName) -eq $true)
			{
				Set-ItemProperty -Path IIS:\Sites\$SiteName\$VirtualDirName -name ApplicationPool -value $AppPoolName
			}
	    }
	}
	catch
	{	
		write2EventLog $_ "Error"		
		throw $_
	}
}

function Set-ComPlusIdentity ($targetApplication, $identity, $pswd, $runForever, $shutdownAfter)
{
$comAdmin = New-Object -comobject COMAdmin.COMAdminCatalog 
$apps = $comAdmin.GetCollection("Applications") 
$apps.Populate(); 
$app = $apps | Where-Object {$_.Name -eq $targetApplication} 
$app.Value("Identity") = $identity 
$app.Value("Password") = $pswd
$app.Value("RunForever") = $runForever # value=1 = leave running when idle
$app.Value("ShutdownAfter") = $shutdownAfter
$apps.SaveChanges()
}

Function DisableWsusReboot()
{
    <#
    .SYNOPSIS
	Disable WSUS patching and rebooting of the specified server
	
    .DESCRIPTION
    By setting the value to 1, the WSUS update process is prevented
	from patching and rebooting the server.
    
    .EXAMPLE
    #>
	try
	{
		$regpath = "HKLM:\System\CurrentControlSet\Control"
		if (Test-Path $regPath) {
			Set-ItemProperty -path $regpath -name "WSUS_Reboots_Cancel" -value "1"
			$message = [String]::Format("WSUS regkey is set to Disabled.")
			  Write-Host $message
			  write2EventLog $message "Information"
		}
	}
	catch
	{	
		write2EventLog $_ "Error"
		throw $_
	}
}
Function EnableWsusReboot()
{
    <#
    .SYNOPSIS
	Enable WSUS patching and rebooting of the specified server
	
    .DESCRIPTION
    By setting the value to 0, the WSUS update process can
	patch and reboot the server.
    
    .EXAMPLE
    #>
	try
	{
		$regpath = "HKLM:\System\CurrentControlSet\Control"
		if (Test-Path $regPath) {
			Set-ItemProperty -path $regpath -name "WSUS_Reboots_Cancel" -value "0"
			$message = [String]::Format("WSUS regkey is set to Enabled. Ready to be patched!")
			  Write-Host $message
			  write2EventLog $message "Information"
		}
	}
	catch
	{	
		write2EventLog $_ "Error"		
		throw $_
	}
}
Function CheckDisableWsusReboot()
{
    <#
    .SYNOPSIS
	Retrieves the value of the Registry settings Disable WSUS patching
	
    .DESCRIPTION
    
    .EXAMPLE
    #>
	try
	{
		$regpath = "HKLM:\System\CurrentControlSet\Control"
		if (Test-Path $regPath) {
			$rt = Get-ItemProperty -path $regpath -name "WSUS_Reboots_Cancel"
			return $rt
		}
		else {
			return $false
		}
	}
	catch
	{	
		write2EventLog $_ "Error"		
		throw $_
	}
}