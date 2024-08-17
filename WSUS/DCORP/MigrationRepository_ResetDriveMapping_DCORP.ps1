#User Names and passwords for DCORP DB
$Global:DBuserid="L001174"
$Global:DBpassword="teCH_Key_DEV"

#Database Server details
$server1="sql-bed1-ds1201\ds1201,30101"
$db1="Migration_Repository"

#Database Update queries
$remapQuery=@" 
exec xp_cmdshell 'net use /delete a:'
exec xp_cmdshell 'net use a: \\sql-bed1-work\dcorp\conversion'
"@

#function to execute the SQL command. 
#need to passs the Database Server Name, Database name and SQL command to the function
Function ExecuteSQL
{
	PARAM($DBServer,$DBName,$SqlCmd)
	
	$sqlConnection = new-object System.Data.SqlClient.SqlConnection
	$sqlConnection.ConnectionString = "server=" + $DBServer + ";database=" + $DBName +";User Id="+$Global:DBuserid+";Password="+$Global:DBpassword 
	$handler = [System.Data.SqlClient.SqlInfoMessageEventHandler] {param($sender, $event) Write-Host $event.Message }; 
	$sqlConnection.add_InfoMessage($handler); 
	$sqlConnection.FireInfoMessageEventOnUserErrors = $true;
	$sqlConnection.Open()
	$sqlCommand = new-object System.Data.SqlClient.SqlCommand
	$sqlCommand.CommandTimeout = 120
	$sqlCommand.Connection = $sqlConnection
	$sqlCommand.CommandText=$SqlCmd
	$sqlCommand.ExecuteNonQuery() | Out-null
	$sqlConnection.Close()
}

Try
{
	Write-host "Updating Mapping in $db1 Database on $server1`n"
	ExecuteSQL $server1 $db1 $remapQuery
	Write-host "`n Updating completed successfully......on $server1"
}
catch
{
	Write-Host $_.Exception.Message
	write-host $_.Exception.ItemName
	write-host $error
	Throw $lastexitcode
}