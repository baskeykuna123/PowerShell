###########################################################################" 
# 
# NAME: Remote.ps1 
# 
# AUTHOR: Johan De Prins
# EMAIL: johan.de.prins@microsoft.com
# 
# COMMENT: Script for remote control using predefined function from XML file
# 
# VERSION HISTORY: 
# 1.0 20.09.2011 - Initial release 
# 
###########################################################################" 
#Requires -Version 2.0 
  
CLS

#Loading All modules
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions -Force
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop

$Datestamp = Get-Date -format yyyyMMddHHmm
$StartTime = Get-date -format F

$ServerPath = "\\shw-me-pdnet01.balgroupit.com\PSScripts"
#$xmlFile = $ServerPath + "\XML_Contoso\Services.xml"

$ServerFunctionsFile = $Global:ScriptSourcePath + "Operations\Functions.ps1"
$LocalFunctionsFile = "c:\temp\Functions.ps1"
$LogFile = $null 
#set default log file
#$LogFile = $ServerPath + "\Logs\" + $Datestamp + "-Test.log"
$LogFile="\\shw-me-pdnet01.balgroupit.com\PSScripts\Logs\" + $Datestamp + ".log"
Function Add2Log ($Message, $LogFile)
{  
	write-host $LogFile
	$StartTime = Get-date -format F
	add-content -path $LogFile -value ($StartTime + " - " + $Message )
	write-host ($Message)
}

# read XML file
add2log "XML FILE CHECK..." $LogFile
if ($Args[0] -ne $Null) 
{
	try
	{
		$xmlFile = Get-ChildItem $args[0]
		
		if (-not $?)
    	{
			throw $error[0].Exception
		}
	}
	catch
	{
		Add2Log " Please provide a valid xml file!" $LogFile
		exit
	}
}
else 
{
	Add2Log " Please provide a valid xml file!" $LogFile
	exit
}


#$LogFile = $ServerPath + "\Logs\" + $xmlFile.BaseName + ".log"
$LogFile = $Global:ScriptSourcePath +"WSUS\Logs\" + $xmlFile.BaseName + ".log"

  
Switch($Args[1]){ 
  "DCORP" {$UserName="balgroupit\L001137" 
           $tempUserPassword ="Basler09"} 
  "ICORP" {$UserName="balgroupit\L001136" 
           $tempUserPassword ="Basler09"} 
  "ACORP" {$UserName="balgroupit\L001135" 
  		   $tempUserPassword ="h5SweHU8"}
  "PCORP" {$UserName="balgroupit\L001134" 
           $tempUserPassword ="9hU5r5druS"}
}
$UserPassword = ConvertTo-SecureString $tempUserPassword -AsPlainText -force

#if ($Args[1] -ne $Null) 
#	{$UserName = $args[1]}
#else 
#{
#	Add2Log " Please provide a valid UserName!"  $LogFile
#	exit
#}
#
#if ($Args[2] -ne $Null) 
#	{
#	$tempUserPassword = $args[2]
#	$UserPassword = ConvertTo-SecureString $tempUserPassword -AsPlainText -force
#	}
#else 
#{
#	Add2Log " Please provide a valid UserPassword!" $LogFile
#	exit
#}

$Creds = New-Object -TypeName System.management.Automation.PScredential -ArgumentList $UserName, $UserPassword
# $Creds = Get-Credential -Credential $UserName

Add2log "READING XML File : " + $xmlFile $LogFile
$xml = New-Object XML
try
{
	$xml.load($xmlFile)
}
catch [System.IO.FileNotFoundException]
{
	Add2Log " File not found: $_" $LogFile
	exit
}
catch
{
	Add2Log " Please provide a valid xml file!" $LogFile
	exit
}

$a = $xml.Roles.Role
# $a | FT -Autosize
Add2log " XML File Retrieved" $LogFile

# Process Functions based on XML
Add2log "" $LogFile
Add2log "REMOTE CONTROL SESSIONS" $LogFile
Add2log "-----------------------" $LogFile
Add2log "" $LogFile

$previousServer = $null
$RemoteSession = $null

foreach ($role in $a) {

  if ($role.ServerName.ToUpper() -eq "LOCAL") 
  {  	
  	RenameFile -PathFile $role.PathFile -NewName $role.NewName
  }
  Elseif (Test-Connection -ComputerName $role.ServerName -Count 1 -ErrorAction silentlycontinue) 
  {
   
	if ($role.ServerName -ne $previousServer)
	{
		if ($RemoteSession -ne $null)
		{
			Exit-PSSession
			Remove-PSSession $RemoteSession
		}
		
		$RemoteSession = New-PSSession -Comp $role.ServerName -Credential $creds 
	}

	if ($RemoteSession -ne $null)
	{	  	
		$previousServer = $role.ServerName
		
		if (Invoke-Command -Session $RemoteSession -Scriptblock {Param ($LocalFunctionsFile) Test-path $LocalFunctionsFile} -ArgumentList $LocalFunctionsFile) 
		{
			Invoke-Command -Session $RemoteSession -Scriptblock {Param ($LocalFunctionsFile) Remove-item -path $LocalFunctionsFile} -ArgumentList $LocalFunctionsFile
    	}
    
		$Functions = get-content $ServerFunctionsFile
		Invoke-Command -Session $RemoteSession -Scriptblock {Param ($LocalFunctionsFile, $Functions) add-content -path $LocalFunctionsFile -value ($Functions)} -ArgumentList $LocalFunctionsFile, $Functions
		Invoke-Command -Session $RemoteSession -Filepath $ServerFunctionsFile
      
    	$ScriptLine = $role.FunctionName + ' "' + $role.Description + '"'
		$SetLogFileScriptLine = "SetLogFile" + ' "' + $LogFile + '"'
	    
		switch ($role.FunctionName)
		{
			"StopService" 
			{
				$forceStop = $role.SelectSingleNode("Parameters/ForceStop")
				if (($forceStop -ne $null) -and ($forceStop.InnerXml.ToUpper() -eq "TRUE"))
				{
					$ScriptLine = $ScriptLine + ' "$True"'
				}
			}
		}
	  
   		Invoke-command -session $RemoteSession -Scriptblock {Param ($scriptline) Invoke-Expression $Scriptline} -ArgumentList $scriptline

		Add2log "" $LogFile
		Add2log ("  ComputerName : " + $role.ServerName) $LogFile
        Add2log ("  Commandline  : " + $Scriptline) $LogFile
        Add2log (" Initiating the commandline...") $LogFile
		if ($role.returnvalue -eq $true )
		{
            	$rt = Invoke-command -session $RemoteSession -Scriptblock {Param ($scriptline) Invoke-Expression $Scriptline} -ArgumentList $scriptline
            	Add2log (" " + $role.ServerName + " returnvalue: " + $rt)
				Write-Host -ForegroundColor Yellow  " "  $role.ServerName  " returnvalue: "  $rt
		}
	else
	{
            	Invoke-command -session $RemoteSession -Scriptblock {Param ($scriptline) Invoke-Expression $Scriptline} -ArgumentList $scriptline
	}
}
	
	Else {      
	  Add2log ([string]::Format(" {0} remote session could not be created.", $role.ServerName)) $LogFile
      Add2log " " $LogFile
	  }
  } 
  Else 
  {
      Add2log ([string]::Format(" {0} is not available", $role.ServerName)) $LogFile
      Add2log " " $LogFile
  }
}

Add2log "END OF SCRIPT" $LogFile
[system.io.file]::WriteAllLines($logfile)