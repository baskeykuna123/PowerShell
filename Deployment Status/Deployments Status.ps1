param($Environment,$DeploymentStatus,$Application,$mailrecipients)

Clear-Host
$ScriptDirectory=split-path $MyInvocation.MyCommand.Definition -Parent

#loading functions
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	

if($DeploymentStatus){
	$Environment= DCORP, ICORP, ACORP
	$Applications=Babe,CDS,ESB,EAI,MyBaloiseWeb,MyBaloiseClassic
	$DeploymentStatus="Completed"
	$URL="http://svw-be-jnkbp001:8080/"
	Write-Host= "Completed"
switch($Environment){
		"DCORP" { $Environment="DCORP"}
	    "ICORP" { $Environment="ICORP"}
        "ACORP" { $Environment="ACORP"}
		
	$Applications=Backend
	$Get-Status DCORP=http://svw-be-jnkbp001:8080/view/20.Deployments_BaBe/view/01.DCORP/job/DCORP_Babe_Deployment/
	$Get-Status ICORP=http://svw-be-jnkbp001:8080/view/20.Deployments_BaBe/view/02.IAP/job/ICORP_BaBe_Deployment/
	$Get-Status ACORP=http://svw-be-jnkbp001:8080/view/20.Deployments_BaBe/view/02.IAP/job/ACORP_BaBe_Deployment/
	$Applications=CentralDataStore
	$Get-Status DCORP=http://svw-be-jnkbp001:8080/view/20.Deployments_CDS/view/01.DCORP/job/DCORP_CDS_Deployment/
	$Get-Status ICORP=http://svw-be-jnkbp001:8080/view/20.Deployments_CDS/view/02.IAP/job/ICORP_CDS_Deployment/
	$Get-Status ACORP=http://svw-be-jnkbp001:8080/view/20.Deployments_CDS/view/02.IAP/job/ACORP_CDS_Deployment/
	
if($Results="Passed")
	Write-Host $DeploymentStatus="Completed";
else if ($Results="Failed")
	Write-Host $DeploymentStatus="Failed";
	$mailrecipients="uday.turumella@baloise.be"
}


$selectQuery="Select * from DeploymentStatus where Applications='$DeploymentStatus'"
$select=Invoke-Sqlcmd -Query $selectQuery -ServerInstance $dbserver -Database $dbName -Username $DBuserid -Password $DBpassword -ErrorVariable $out


$Deploymentinfo=""
foreach($col in $select.Table.Columns.ColumnName){
	$Deploymentinfo += "<TR><TD><B>$($col)</B></TD><TD>$($select[$col])</TD></TR>"
}
