PARAM($Version,$Action="AVAILABLE")
Clear

if(!$Version){
$Version='24.3.44.11'
$Action="OBSOLETE"
}


#Importing SQL modules for SQL commands to the Version database
Import-Module sqlps -DisableNameChecking

  
# DB server information
$DBuserid="L001171"
$DBpassword="teCH_Key_PRO"
$dbserver="sql-be-buildp"
$dbName="BaloiseReleaseVersions"

#to check if build version exists 
$selectQuery="Select * from buildversions where Version='$Version'" 
$select=Invoke-Sqlcmd -Query $selectQuery -ServerInstance $dbserver -Database $dbName -Username $DBuserid -Password $DBpassword -ErrorVariable $out

if($select -eq $null){
	write-host "The Version $($Version) was not found. nothing to update"
	Exit 1
}
else {
	$udpatecmd=[string]::Format("Update buildversions set Status='{0}' where Version='{1}'",$Action,$Version)
	$select=Invoke-Sqlcmd -Query $udpatecmd -ServerInstance $dbserver -Database $dbName -Username $DBuserid -Password $DBpassword -ErrorVariable $out
	$select=Invoke-Sqlcmd -Query $selectQuery -ServerInstance $dbserver -Database $dbName -Username $DBuserid -Password $DBpassword -ErrorVariable $out
	$select | ft -Property Release,Version,Status -AutoSize
	
	
}

