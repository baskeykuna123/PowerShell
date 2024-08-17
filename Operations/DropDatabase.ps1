param($DBserver,$DBuser,$DBPassword,$DBNameFilter)
$DBserver
$DBuser
$DBnameFilter=$DBNameFilter+"%"
$DBname=invoke-sqlcmd  -ServerInstance $DBserver -Username $DBuser -Password $DBPassword -query "select name from sys.databases where name like '$DBnameFilter'"

 Try 
 {
	if($DBname -ne $null){
		Write-host "The Following DB will be Dropped :" $DBname.name
		$Executionresult=invoke-sqlcmd  -ServerInstance $DBserver -Username $DBuser -Password $DBPassword -query "Drop database $($DBname.name)"
	}
	else {
		Write-Host "Database with name $DBname not found.. Database Drop aborted"
		EXIT 0
	}
 }
 Catch {
 	throw $_
 }