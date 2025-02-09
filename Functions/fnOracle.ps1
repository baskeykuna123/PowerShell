$ScriptDirectory=split-path $MyInvocation.MyCommand.Definition -Parent
."$ScriptDirectory\fnSetGlobalParameters.ps1"

Join-Path  (split-path $ScriptDirectory	 -Parent) -ChildPath "Tools/Oracle/Oracle.ManagedDataAccess.dll"

Function CreateClevaDBConnection(){
PARAM(
	$User,
	$Password,
	$Database
	)
$datasource=[string]::Format('ora1{0}.bvch.ch:12051/{0}.bvch.ch',$dbName)
$query=(Get-Content "D:\BuildTeam\ClevaValidationQueries.sql")
$connectionstring=[string]::Format("User Id={0};Password={1};Data Source='{2}'",$username,$password,$datasource)
$connection=New-Object Oracle.ManagedDataAccess.Client.OracleConnection($connectionstring)
Return $connection
}