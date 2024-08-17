param(
	[String]$BunndleToBeUpdated,
	[string]$Environment,
	[string]$Application
	
)
CLS

#Loading Functions
if(Get-Module -Name LoadFunctions){
	Remove-Module LoadFunctions -Force
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop


#Displaying Script Information
Write-host "Script Name :" $MyInvocation.MyCommand
Write-host "=======================Input Parameters======================================="
$($MyInvocation.MyCommand.Parameters) | Format-Table -AutoSize @{ Label = "Parameter Name"; Expression={$_.Key}; }, @{ Label = "Value"; Expression={(Get-Variable -Name $_.Key -EA SilentlyContinue).Value}; }
Write-host "=======================Input Parameters================================================="


if(!$Environment){
	$Environment="DCORP"
}


switch ($Environment) 
      { 
	    "DCORP" { $ToscEnvironment="DTOS"}
        "ICORP" { $ToscEnvironment="ITOS"}
		"ACORP" { $ToscEnvironment="ATOS"}
		"PCORP" { $ToscEnvironment="PRD"}
		"MIG"   { $ToscEnvironment="MIG"}
		"MIG3"  { $ToscEnvironment="MIG3"}
		"MIG4"  { $ToscEnvironment="MIG4"}
	  }







#copy clients for CLEVA only
if($Application -ieq "CLEVA" -or $Application -ieq "MC" -or $Application -ieq "MorningCheck"){
    Write-Host "Environment    : " $Environment
	$ClientSource=[string]::Format("{0}\{1}-Current-Tosca",$global:ClevaCitrixClientSourcePath,$Environment)
	$Workspaceshare=[string]::Format("{0}TOSCA_WORKSPACES\Clients\{1}\",$global:TranferFolderBase,(GetClevaEnvironment -Environment $ToscEnvironment))
    
    if($env:COMPUTERNAME -ieq "SVW-BE-TESTP002"){
        $serverlist=($global:TestFarm2Servers)
		write-host "TestFarmServer : " $Global:TestFarm2Servers
    }
    else {
        $serverlist=($Global:TestFarm1Servers)
		write-host "TestFarmServer : " $global:TestFarm1Servers
        Get-ChildItem -Path Filesystem::$Workspaceshare -Include * | remove-Item -recurse -Force 
	    Copy-Item Filesystem::"$($ClientSource)\*" -Destination Filesystem::$Workspaceshare -Force -Recurse
        Write-Host "Updating clients on the share"
	    Write-Host "Client Source  : " $ClientSource
	    Write-Host "Workspace Share: " $Workspaceshare
    }
	
	if(Test-Path Filesystem::$ClientSource){
		Write-Host "`r`n Updating the latest clients for : $($Environment)"
		Foreach($server in $serverlist.split(',')){
			$TestServerClientPath=[string]::Format("\\{0}\c$\Program Files (x86)\Cleva\BE\CLEVA_{1}\",$server,$ToscEnvironment)
			Write-Host "Updating Client on : " $server
			Write-Host "Client Path        : " $TestServerClientPath
			Write-Host "Removing Client........"
			Get-ChildItem -Path $TestServerClientPath -Include * | remove-Item -recurse -Force
			Write-Host "Copying New Client......."
			Copy-Item "$($ClientSource)\*" -Destination $TestServerClientPath -Force -Recurse
		}
	}
}


# Read config and set element in config 
 $TestconfigXMLPath=$global:TOSCATestExecutionConfig
 #if($env:COMPUTERNAME -ilike "*SVW-BE-TESTP002*"){
        $TestconfigXMLPath="C:\Program Files (x86)\TRICENTIS\Tosca Testsuite\ToscaCommander\ToscaCI\Client\CITestExecutionConfiguration.xml"
 #}
$XML=[xml](Get-Content FileSystem::$TestconfigXMLPath)
$TestEventElement=$XML.SelectSingleNode("//testConfiguration/TestEvents/TestEvent")

$TestEventElement.InnerText = $BunndleToBeUpdated
$XML.Save($TestconfigXMLPath)

Write-Host "`r`n`r`n========================================================="
Write-Host "Executing Bundle=" $BunndleToBeUpdated
Write-Host "========================================================="


