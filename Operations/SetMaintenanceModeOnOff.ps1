param([String] $Mode, [String] $Environment, [String] $ApplicationNames)

clear


#Test Parameters
if(!$Environment){
	$Mode="off"
	$Environment="dcorp"
	$ApplicationNames="MyBaloiseClassic"
}


#loading Functions
if(Get-Module -Name LoadFunctions){
	Remove-Module LoadFunctions -Force
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	

$ErrorActionPreference='Stop'

#Displaying Script Information
Write-host "=======================SCRIPT INFO================================================="
Write-host "Script Name = " $MyInvocation.MyCommand.Definition
$($MyInvocation.MyCommand.Parameters).Keys | foreach {
	 Write-host "$([string]::Format("{0} = {1}",$_,(Get-Variable -Name $_ -EA SilentlyContinue).Value))"
}
Write-host "=======================SCRIPT INFO================================================="
Function RenameMaintenanceModeFile ($oldFileFullName, $newFileName)
{

	$oldFolderName=Split-Path $oldFileFullName
	$newFileFullName = [string]::Format("{0}\{1}", $oldFolderName, $newFileName)
	
	if (Test-Path $oldFileFullName)
	{
		if (Test-Path $newFileFullName) {
			Remove-Item $oldFileFullName -Force
		}
		else {
			Rename-Item -path $oldFileFullName -newname $newFileName -Force
			Write-Host "Maintenande mode set to" $mode "for" $ApplicationName "-" $newFileName
		}
	}
	else
	{
		if (Test-Path $newFileFullName) {
			Write-Host "Maintenande mode  is already" $mode "for" $ApplicationName "-" $newFileName
		}
		else {
			Write-Host "File not found. Check maintenance mode directory" $oldFolderName
		}
	}
}

switch ($Mode) 
      { 
        "On"  { $filename="NOT_IN" 
				$newFileName="IN" 
				}
		"Off" { $filename="IN" 
				$newFileName="NOT_IN" 
				}
      }



Write-Host "`r`n============================================================"
foreach($ApplicationName in $ApplicationNames.split(',')){
	Write-Host "Application  	   : " $ApplicationName
	Write-Host "Maintainence Mode  : " $Mode
	if($ApplicationName -match "MyBaloiseClassic"){
		$classicMM=$Mode
		$filepath=[string]::Format("{0}{1}\MercatorNet\MaintenanceModeFiles\Internal\{2}_MaintenanceMode_Internal.xml",$global:AppShareRoot,$Environment,$filename)
		$renamefile=[string]::Format("{0}_MaintenanceMode_Internal.xml",$newFileName)
		RenameMaintenanceModeFile $filepath $renamefile

		$filepath=[string]::Format("{0}{1}\MercatorNet\MaintenanceModeFiles\Broker\{2}_MaintenanceMode_Broker.xml",$global:AppShareRoot,$Environment,$filename)
		$renamefile=[string]::Format("{0}_MaintenanceMode_Broker.xml",$newFileName)
		RenameMaintenanceModeFile $filepath $renamefile
	}

	if($ApplicationName -match "MyBaloiseWeb"){
		$MWebMM=$Mode
		$filepath=[string]::Format("{0}{1}\MercatorWeb\MercatorWebBroker\MaintenanceMode\{2}_MaintenanceMode_MyBaloiseBroker.xml",$global:AppShareRoot,$Environment,$filename)
		$renamefile=[string]::Format("{0}_MaintenanceMode_MyBaloiseBroker.xml",$newFileName)
		RenameMaintenanceModeFile $filepath $renamefile

		$filepath=[string]::Format("{0}{1}\MercatorWeb\MercatorWebInternal\MaintenanceMode\{2}_MaintenanceMode_MyBaloiseInternal.xml",$global:AppShareRoot,$Environment,$filename)
		$renamefile=[string]::Format("{0}_MaintenanceMode_MyBaloiseInternal.xml",$newFileName)
		RenameMaintenanceModeFile $filepath $renamefile
	}
}
Write-Host "============================================================"

#HTML validations for Maintenance mode on/Off
$MaintenanceModeStatus="<TABLE class='rounded-corner'>"
$MaintenanceModeStatus+="<TR align=center><TH colspan='2'>Maintenance Mode Status : $($Environment)</TH></TR>"
$MaintenanceModeStatus+="<TR align=center><TH>Application Name</TH><TH>Mode</TH></TR>"
$MaintenanceModeStatus+="<TR align=center><TD>MyBaloiseClassic</TD><TD>$classicMM</TD></TR>"
$MaintenanceModeStatus+="<TR align=center><TD>MyBaloiseWeb</TD><TD>$MWebMM</TD></TR>"
$MaintenanceModeStatus+="</TABLE>"

$EnvironmentStatusHTM = [string]::Format("{0}\{1}_MaintenanceMode_Status.htm",$global:EnvironmentHTMLReportLocation,$Environment)
$HtmlBodyStatus = [system.IO.File]::ReadAllLines((join-path $Global:ScriptSourcePath  -ChildPath "Notifications\Templates\EnvironmentStatusTest.html" ))
$Timestamp = Get-Date
$HtmlBodyStatus = $HtmlBodyStatus -ireplace "#DateTime#",$Timestamp
$HtmlBodyStatus = $HtmlBodyStatus -ireplace "#StatusReport#",$MaintenanceModeStatus
$HtmlBodyStatus | Out-File Filesystem::$EnvironmentStatusHTM -Force


