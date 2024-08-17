PARAM(
	[string]$Version
	)

Clear-Host 


if(!$Version){
	$Version="30.3.20.0"
}
	  
#Importing SQL modules for SQL commands to the Version database
Import-Module sqlps -DisableNameChecking
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}

$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	


Write-Host "========================Input parameters=================================================="
Write-Host "Extracting inforamtion for Version      :" $Version
Write-Host "========================Input parameters=================================================="
$Release="R"+$Version.split('.')[0]
#Parameter to check if a new MIDC Version is delivered
$selectQuery="Select * from Buildversions where applicationid=3 and Version='$Version'order by builddate"
$select=Invoke-Sqlcmd -Query $selectQuery -ServerInstance $Global:BaloiseBIDBserver -Database $Global:BaloiseReleaseVersionDB -Username $Global:BaloiseVersionDBuserid -Password $Global:BaloiseVersionDBuserpassword -ErrorVariable $out
foreach($ver in $select){
	$SQL=""
	$mpar=""
	$latestVersionDBFolder=Join-Path $Global:ClevaSourcePackages -ChildPath "$Release\$($ver.Version)\database\cleva\sql\"
	$latestVersionMparFolder=Join-Path $Global:ClevaSourcePackages -ChildPath "$Release\$($ver.Version)\batch\DCORP\pars\"
	if($ver.STATUS -ieq "AVAILABLE"){
		$Sqlfiles=(Get-ChildItem filesystem::$latestVersionDBFolder -Filter "*.sql" -Force -Recurse | where {$_.Name -ine "summary.sql"}).Name
		$mparfiles=(Get-ChildItem filesystem::$latestVersionMparFolder -Filter "*.mpar" -Force -Recurse ).Name
		
	
	if($Sqlfiles){
		Write-Host $Sqlfiles
		$SQL="_SQL"
	}else{
		Write-Host "INFO : No SQL Scripts for this version "
		$Sqlfiles="NO SCRIPTS"
	}
	if($mparfiles){
		Write-Host $mparfiles
		$mpar="_MPAR"
	}else{
		Write-Host "INFO : No Mpar files found"
		$mparfiles="NO MPARS"
	}
	$ver | select Release,Version,Status | ft -AutoSize
	$ReportsFile=[string]::Format("{0}{1}{2}{3}.txt",$Global:ClevaReportsFolder,$ver.Version,$SQL,$mpar)
	if($SQL -or $mpar){
		$selectQuery="select * from CLEVAVersions where CLEVA_VERSION='$($ver.Version)'"
		$select=Invoke-Sqlcmd -Query $selectQuery -ServerInstance $Global:BaloiseBIDBserver -Database $Global:BaloiseReleaseVersionDB -Username $Global:BaloiseVersionDBuserid -Password $Global:BaloiseVersionDBuserpassword -ErrorVariable $out
		$select | Format-List  | Out-File filesystem::$ReportsFile -Force 
		Add-Content -Path filesystem::$ReportsFile -Value "`r`n*******SQL Scripts********" -Force
		foreach($script in $Sqlfiles){
			Add-Content -Path filesystem::$ReportsFile -Value $script -Force
		}
		Add-Content -Path filesystem::$ReportsFile -Value "*******SQL Scripts********" -Force
		Add-Content -Path filesystem::$ReportsFile -Value "`r`n*******MPAR FILES********" -Force
		foreach($par in $mparfiles){
			Add-Content -Path filesystem::$ReportsFile -Value $par -Force
		}
		Add-Content -Path filesystem::$ReportsFile -Value "*******MPAR FILES********" -Force
	}
	}
	
	$selectQuery="INSERT INTO [dbo].[CLEVAVersionsScriptInfo] ([ClevaVersion],[SQLScripts],[mpars])   VALUES('$($ver.Version)','$Sqlfiles','$mparfiles')"
	$select=Invoke-Sqlcmd -Query $selectQuery -ServerInstance $Global:BaloiseBIDBserver -Database $Global:BaloiseReleaseVersionDB -Username $Global:BaloiseVersionDBuserid -Password $Global:BaloiseVersionDBuserpassword -ErrorVariable $out
	$select | ft -AutoSize
}
