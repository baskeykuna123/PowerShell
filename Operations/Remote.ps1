Param($xmlFile)
CLS

#Loading All modules
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions -Force
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop

$Datestamp = Get-Date -format yyyyMMddHHmm
$StartTime = Get-date -format F

if(!$xmlFile){
	#$xmlFile = $Global:ScriptSourcePath + "WSUS\PCORP\Stop\Pcorp_stop_All.xml"
	#$xmlFile = $Global:ScriptSourcePath + "WSUS\PCORP\Start\Pcorp_Start_All.xml"
	#$xmlFile = "E:\BuildTeam\Pankaj\Test_WSUS\Dcorp_Stop_All.xml"
	$xmlFile = "E:\BuildTeam\Pankaj\Test_WSUS\Dcorp_Start_All.xml"
}
$xmlFilename=[System.IO.Path]::GetFileNameWithoutExtension($xmlFile)
$Environment=$xmlFilename.Split('_')[0]


$ServerFunctionsFile = $Global:ScriptSourcePath + "Operations\Functions.ps1"
$LocalFunctionsFile = "c:\temp\Functions.ps1"
$WSUSAction=$($xmlFile.split("\")[-1]).split("_")[1]

Function Add2Log ($Message, $LogFile)
{  
	$StartTime = Get-date -format F
	add-content -path $LogFile -value ($StartTime + " - " + $Message )
	write-host ($Message)
}


#$LogFile = [string]::Format("E:\PSScripts\Logs\{0}_{1}.log",$xmlFilename,$Datestamp)
$LogFile = [string]::Format("{0}{1}_{2}.log",$Global:WSUSLogsPath,$xmlFilename,$Datestamp)
  
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

Add2log "READING XML File :  $xmlFile" $LogFile
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

# Process Functions based on XML
Add2log "" $LogFile

$previousServer = $null
$RemoteSession = $null
$grouped = $xml.Roles.Role | Group ServerName
$CreateFunctionFile={
	Test-path $LocalFunctionsFile
	Remove-item -path $LocalFunctionsFile
}


$IISStartScriptBlock={
IISRESET /START

}
$IISStopScriptBlock={
IISRESET /STOP
}


#$grouped="svw-be-portp01.balgroupit.com"
#foreach($server in $grouped){
foreach($server in $grouped.Name){
	$WSUSAction=$($xmlFile.split("\")[-1]).split("_")[1]
	$ServerActions=$xml.SelectNodes("//Roles/Role[@ServerName='$server']")
	$RemoteSession = New-PSSession -Comp $server -Credential $Creds -ErrorAction SilentlyContinue
	Add2log ("================================$server======================================") $LogFile
	#check if connection can be established
		if ($RemoteSession -eq $null){
				 Add2log ([string]::Format(" {0} remote session could not be created.", $server)) $LogFile
		}
		else{
			if($xmlFilename -ilike '*stop*'){
				Write-Host "Special actions on these servers , Killing all W3WP processes"
				Invoke-Command -Session $RemoteSession -Scriptblock $IISStopScriptBlock
			}
			if($xmlFilename -ilike '*start*'){
				Write-Host "IIS Start command"
				Invoke-Command -Session $RemoteSession -Scriptblock $IISStartScriptBlock
			}
			Invoke-Command -Session $RemoteSession -Filepath $ServerFunctionsFile
			foreach($action in $ServerActions){
				$WSUSFunction=$($action.FunctionName)
				$WSUSDescription=$($action.Description)
				$ScriptLine = $action.FunctionName + ' "' + $action.Description + '"'
				Add2log ("Commandline		: $Scriptline") $LogFile
				Invoke-command -session $RemoteSession -Scriptblock {Param ($scriptline) Invoke-Expression $Scriptline} -ArgumentList $scriptline
				
				Invoke-command -session $RemoteSession -Scriptblock {
					param ($WSUSFunction,$WSUSDescription,$WSUSAction) 
					If($WSUSFunction -ilike "*Service*"){
						Write-Host "Service Name	:"$WSUSDescription
						Write-Host "Action			:"$WSUSAction
						switch($WSUSAction){
							"Stop" {$StartupType="Manual"}
							"Start"{$StartupType="Automatic"}
						}
						try{
							$GetServiceDetails=Get-WmiObject -Class Win32_Service | ?{($_.Name -ieq $WSUSDescription) -or ($_.DisplayName -ieq $WSUSDescription)}
							If($($GetServiceDetails.StartMode) -ine "Disabled"){
								$GetServiceDetails|Set-Service -StartupType $StartupType
								Write-Host "startup type for service $ServiceName is set to" $StartupType
							}
							Else{
								Write-Host "INFO: Service $WSUSDescription is in disabled state"
							}
						}
						catch{
							Write-Host $_
						}
					}
					If($WSUSFunction -ilike "*AppPool*"){
						Write-Host "Application pool	:"$WSUSDescription
						Write-Host "Action				:"$WSUSAction
						switch($WSUSAction){
							"Stop"  {$setAutoStart='false_disable'}
							"Start" {$setAutoStart='true_enable'}
						}
						try{
							$GetIISApplicationPool=Get-ChildItem IIS:\AppPools | ?{$_.Name -ieq $WSUSDescription}
							$GetIISApplicationPool.autoStart=$($setAutoStart.split("_")[0])
							$GetIISApplicationPool | Set-Item
							Write-Host "INFO: Application pool auto start is $($($setAutoStart.split("_")[1])+'d')"
						}
						catch{
							Write-Host $_
						}
					}
				} -ArgumentList $WSUSFunction,$WSUSDescription,$WSUSAction
			}
			Remove-PSSession  -Session $RemoteSession
		}
	Add2log ("================================$server======================================") $LogFile
}

