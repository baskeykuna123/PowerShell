PARAM($XMLFilePath,$Environment)
  
CLS

if(!$XMLFilePath){
	$XMLFilePath="S:\WSUS\DCORP\Stop\Dcorp_Stop_All.xml"
	$Environment="DCORP"
	$Action="GetStatus"
}
#Loading All modules
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions -Force
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop

$Datestamp = Get-Date -format yyyyMMddHHmm

$LocalFunctionsFile = "c:\temp\Functions.ps1"
$ServerFunctionsFile = $Global:ScriptSourcePath + "Operations\Functions.ps1"
$LogFile = [string]::Format("{0}\{1}\{2}.log",$Global:WSUSLogsPath,$Environment,$Action)
Write-Host "=====================================Input Parameters==========================================="
Write-Host "XML File Path :" $XMLFilePath
Write-Host "Environment   :" $Environment
Write-Host "=====================================Input Parameters==========================================="


Function Add2Log ($Message, $LogFile)
{  
	$StartTime = Get-date -format F
	add-content -path Filesystem::$LogFile -value ($StartTime + " - " + $Message )
	write-host ($Message)
}

#Check if input XML file exists else abort and throw error
if(-not(Test-Path Filesystem::$XMLFilePath)){
	Write-Error "XML FILE NOT FOUND : " $XMLFilePath
	Exit 1
}
  
Switch($Environment){ 
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
$Creds = New-Object -TypeName System.management.Automation.PScredential -ArgumentList $UserName, $UserPassword
$XMLFileName=[System.IO.Path]::GetFileNameWithoutExtension($XMLFilePath)

$WUSUXml=[xml] (get-content Filesystem::$XMLFilePath )

$LogFile=$LogFile=$Global:ScriptSourcePath + "WSUS\Logs\" + $XMLFileName + ".log"

Add2log " XML File Retrieved - $($XMLFilePath)" $LogFile
Add2log "`r`n========================================WSUS $Datestamp=====================================`r`n" $LogFile

$previousServer = $null
$RemoteSession = $null

$grouped = $WUSUXml.Roles.Role | Group ServerName

$IISStopScriptBlock={
IISRESET /STOP
taskkill /F /IM w3wp.exe /T
}

$IISStopScriptBlock={
IISRESET /start
}

$GetServiceStatusBlock={
Param($logfilePath)
	$Statusfolder=Split-Path $logfilePath -Parent
	net use k: $Statusfolder
$ServiceList=Get-WmiObject -Class Win32_Service | Where-Object{$_.StartName -ilike "*L0*"}
		foreach($service in $ServiceList){
			$value=[string]::Format("{0}-{1}-{2}",$service.Name,$service.StartMode,$service.state)
			Add-Content Filesystem::$logfilePath -Value $value -Force
		}
}

foreach($server in $grouped.Name){
$ServerActions=$WUSUXml.SelectNodes("//Roles/Role[@ServerName='$server']")
Write-Host "Server :" $server
$RemoteSession = New-PSSession -Comp $server -Credential $Creds -ErrorAction SilentlyContinue
#check if connection can be established
	if ($RemoteSession -eq $null){	
			 Add2log ([string]::Format(" {0} remote session could not be created.", $CurrentServer)) $LogFile
	}
	else{
		if($action -ieq "GetStatus"){
		$ServerstatusFile=[string]::Format("{0}\WSUS\{1}\Status\{2}.log",$Global:ScriptSourcePath,$Environment,$server)
		if(Test-Path Filesystem::$ServerstatusFile){
			Remove-Item $ServerstatusFile -Force -Recurse
		}
			Invoke-Command -Scriptblock $GetServiceStatusBlock -Session $RemoteSession -ArgumentList $ServerstatusFile
		}
#		Add2Log " IIS on : $($server)" 
#		#Invoke-Command -Scriptblock {IISRESET /STOP} -Session $RemoteSession
#		foreach ($role in $ServerActions) {
#				if($role.FunctionName -ine "StopWebsite"-or $role.FunctionName -ine "StopWebsite"){
#					Copy-Item Filesystem::$($ServerFunctionsFile) -Destination $LocalFunctionsFile -Force -WhatIf
#			}
#		}
	}
}
#	if (Invoke-Command -Session $RemoteSession -Scriptblock {Param ($LocalFunctionsFile) Test-path $LocalFunctionsFile} -ArgumentList $LocalFunctionsFile) 
#		{
#			Invoke-Command -Session $RemoteSession -Scriptblock {Param ($LocalFunctionsFile) Remove-item -path $LocalFunctionsFile} -ArgumentList $LocalFunctionsFile
#    	}
#    
#		$Functions = get-content $ServerFunctionsFile
#		Invoke-Command -Session $RemoteSession -Scriptblock {Param ($LocalFunctionsFile, $Functions) add-content -path $LocalFunctionsFile -value ($Functions)} -ArgumentList $LocalFunctionsFile, $Functions
#		Invoke-Command -Session $RemoteSession -Filepath $ServerFunctionsFile
#      
#    	$ScriptLine = $role.FunctionName + ' "' + $role.Description + '"'
#		$SetLogFileScriptLine = "SetLogFile" + ' "' + $LogFile + '"'
#	    
#		switch ($role.FunctionName)
#		{
#			"StopService" 
#			{
#				$forceStop = $role.SelectSingleNode("Parameters/ForceStop")
#				if (($forceStop -ne $null) -and ($forceStop.InnerXml.ToUpper() -eq "TRUE"))
#				{
#					$ScriptLine = $ScriptLine + ' "$True"'
#				}
#			}
#		}
#	  
#   		Invoke-command -session $RemoteSession -Scriptblock {Param ($scriptline) Invoke-Expression $Scriptline} -ArgumentList $scriptline
#
#		Add2log "" $LogFile
#		Add2log ("  ComputerName : " + $role.ServerName) $LogFile
#        Add2log ("  Commandline  : " + $Scriptline) $LogFile
#        Add2log (" Initiating the commandline...") $LogFile
#		if ($role.returnvalue -eq $true )
#		{
#            	$rt = Invoke-command -session $RemoteSession -Scriptblock {Param ($scriptline) Invoke-Expression $Scriptline} -ArgumentList $scriptline
#            	Add2log (" " + $role.ServerName + " returnvalue: " + $rt)
#				Write-Host -ForegroundColor Yellow  " "  $role.ServerName  " returnvalue: "  $rt
#		}
#	else
#	{
#            	Invoke-command -session $RemoteSession -Scriptblock {Param ($scriptline) Invoke-Expression $Scriptline} -ArgumentList $scriptline
#	}
#}
#	
#	Else {      
#	  Add2log ([string]::Format(" {0} remote session could not be created.", $role.ServerName)) $LogFile
#      Add2log " " $LogFile
#	  }
#  } 
#  Else 
#  {
#      Add2log ([string]::Format(" {0} is not available", $role.ServerName)) $LogFile
#      Add2log " " $LogFile
#  }
#}
#
#Add2log "END OF SCRIPT" $LogFile
#[system.io.file]::WriteAllLines($logfile)