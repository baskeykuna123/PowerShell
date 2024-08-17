Function CreateLocalFolder (){
	Param (	[String]$localFolder)
	
	if (Test-Path $localFolder) {
		Write-Verbose "Folder $($localFolder) already exists."
	}
	else{
		$dummy=New-Item $localFolder -Force -ItemType Directory 
		Write-Verbose "Folder $($localFolder) created."
	}
}

Function CreateFolderOnShare (){
	Param (	[String]$UNCPath)
	
	if (Test-Path $UNCPath) {
		Write-Verbose "Folder $($UNCPath) already exists."
	}
	else{
		$dummy=New-Item $UNCPath -Force -ItemType Directory 
		Write-Verbose "Folder $($UNCPath) created."
	}
}

Function Set-MainframeAvailability($StartTime,$EndTime)
 {
	$dbserver="SQL-BE-MYbalD"
	$dbName="Peach_Data"
	$DBuserid="L001174"
	$DBpassword="teCH_Key_DEV"
	$Env="ICORP"
	$DayOfWeek=""
	$StartTime= 700
	$EndTime=2100
		if ($StartTime -lt $EndTime)
		{
		$SqlQuery = "update dbo.MainframeAvailability Set StartTime=$StartTime , EndTime=$EndTime where DayOfWeek=$DayOfWeek"
		#$select=Invoke-Sqlcmd -Query $SqlQuery -ServerInstance $dbserver -Database $dbName -Username $DBuserid -Password $DBpassword 
		$Query = "select * from dbo.MainframeAvailability "#where DayOfWeek=$DayOfWeek"
		$Details = Invoke-Sqlcmd -Query $Query -ServerInstance $dbserver -Database $dbName -Username $DBuserid -Password $DBpassword 
		return $Details #| ft -Property StartTime,EndTime,DayOFWeek
		}
	  elseif($StartTime -gt $EndTime)
	  {
	  Write-Host " `n Start-Time is greater than End-Time, Update failed" -ForegroundColor red
	  }
}

	
	
Function Reset-MainframeAvailability
{
	Param
	(
	[String]$dbserver,
	[String]$dbName,
	[String]$DBuserid,
	[String]$DBpassword
	)
$Sql = "update dbo.MainframeAvailability set StartTime='700', EndTime='2100' Where DayOfWeek in (1,2,3,4,5)"
$select=Invoke-Sqlcmd -Query $Sql -ServerInstance $dbserver -Database $dbName -Username $DBuserid -Password $DBpassword 
 
$Sql = "update dbo.MainframeAvailability Set StartTime='0' , EndTime='0' where DayOfWeek='0' "
$select=Invoke-Sqlcmd -Query $SqlQuery0 -ServerInstance $dbserver -Database $dbName -Username $DBuserid -Password $DBpassword 

$Sql = "update dbo.MainframeAvailability Set StartTime='700' , EndTime='1700' where DayOfWeek='6' "
$select=Invoke-Sqlcmd -Query $SqlQuery6 -ServerInstance $dbserver -Database $dbName -Username $DBuserid -Password $DBpassword

$Sql = "select * from dbo.MainframeAvailability"
$Details = Invoke-Sqlcmd -Query $SqlQuery -ServerInstance $dbserver -Database $dbName -Username $DBuserid -Password $DBpassword  

return $Details | ft -Property StartTime,EndTime,DayOfWeek 
}

Function AppShare-Deployment
{
	Param([string]$source,[string]$destinationPath)

	
	Write-Host "AddDataShare   : $source"
	Write-Host "AddDataShare   : $source"
	Copy-Item -Path "$source\*.*" -Destination $destinationPath -Force -Recurse
	Remove-Item  $source -Force -Recurse
}



