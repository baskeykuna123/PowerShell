Param
(
[String]$Env,
[String]$Action
)
CLS

# loading Function
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force 

if(!$Env)
{
$Env='PCORP'
$Action='Start'
}
$LogFile=[String]::Format("{0}WSUS\Logs\WSUS_TestServerConnection_Logs\{1}.txt",$Global:ScriptSourcePath,(Get-Date -Format "yyyyMMdd-hhmmss"))
New-Item Filesystem::$LogFile -ItemType File -Force |Out-Null

#$WSUSXmlPath=[String]::Format("\\shw-me-pdnet01\E$\PSScripts\MercatorRebootPlan\{0}\{0}_{1}_All.xml",$Env,$Action)
$WSUSXmlPath=[String]::Format("{0}WSUS\{1}\{1}_{2}_All.xml",$Global:ScriptSourcePath,$Env,$Action)

Write-Host "======================"
Write-Host "Environment:"$Env
Write-Host "Action     :"$Action
Write-Host "======================"


 
Switch($Env){ 
  "DCORP" {$UserName="balgroupit\L001137" 
           $tempUserPassword ="Basler09"} 
  "ICORP" {$UserName="balgroupit\L001136" 
           $tempUserPassword ="Basler09"} 
  "ACORP" {$UserName="balgroupit\L001135" 
  		   $tempUserPassword ="h5SweHU8"}
  "PCORP" {$UserName="balgroupit\L001134" 
           $tempUserPassword ="9hU5r5druS"}
}
$Datestamp = Get-Date -format yyyyMMddHHmm
$logfile=[string]::Format("\\balgroupit.com\appl_data\BBE\Transfer\Packages\Scripts\Notifications\Temp\{0}_{1}_{2}.txt",$Env,$Action,$Datestamp)
$UserPassword = ConvertTo-SecureString $tempUserPassword -AsPlainText -force
$Creds = New-Object -TypeName System.management.Automation.PScredential -ArgumentList $UserName, $UserPassword
if(Test-Path Filesystem::$WSUSXmlPath){
	$wsusXML=[xml](gc Filesystem::$WSUSXmlPath)
	$WSUSServers=$wsusXML.Roles.Role.ServerName | Select -Unique
	ForEach($Server in $WSUSServers)
	{
		Write-Host "Server : " $Server
		$Server=$Server
	    $RemoteSession = New-PSSession -Comp $Server -Credential $creds -Verbose -Authentication  Default
		$status="SUCCESS"
		if ($RemoteSession -eq $null)
		{	
			$status="ERROR"
		}
		Remove-PSSession -Session $RemoteSession
		$Info=[string]::Format("{0}:{1}",$Server,$status)
		write-host $Info
		Add-Content Filesystem::$logfile -Force -Value $Info
	}	
}