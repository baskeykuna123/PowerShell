#getting the version to be deployed
param($env)
Clear-Host



if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	


if(!$env){
	$env="DCORP"
}

$xml = [xml](Get-Content Filesystem::$global:ReleaseManifest )
$envname=$env
if($env -match "PCORPTEST"){ $envname="PCORP"}


#Get the application no to be updated
$node=$xml.SelectSingleNode("/Release/environment[@Name='$envname']/Application[@Name='MyBaloiseClassic']")
$ClassicBaseversion=$node.Version.Split('.')[0] + '.' +$node.Version.Split('.')[1]

$curentVersion=$node.Version
$dbScriptBuildFolder=[string]::Format("\\shw-me-pdtalk51\Released Deliverables\MercatorNet Release {0}\Database\{1}\",$ClassicBaseversion,$curentVersion)
$dbfile=[string]::Format("{0}_db_batch_main.bat",$node.Version)

 if($env -ieq "DCORP"){
 	$curentVersion=[string]::Format("{0}.{1}.0",$ClassicBaseversion,(get-date -format "yyyyMMdd"))
	$dbScriptBuildFolder=[string]::Format("F:\Released Deliverables\MN{0}\Database\{1}",$ClassicBaseversion,$curentVersion)
	$dbfile=[string]::Format("{0}_db_batch_main.bat",$curentVersion)
}


$dbScriptDeployFolder="F:\DatabaseDeployment\$env\"

$DBExecutableFolder=$dbScriptDeployFolder+ $curentVersion
$DBExecutable=join-path $DBExecutableFolder -ChildPath $dbfile

#PCORP DB is already Setup for execution. there is no need to add deploym
if($env -eq "PCORP") {
	$dbfile="PCORP_"+$dbfile
	$DBExecutable=join-path $DBExecutableFolder -ChildPath $dbfile
	Set-Location $DBExecutableFolder
	cmd /c $DBExecutable
}
else {
Copy-Item $dbScriptBuildFolder -Destination $dbScriptDeployFolder -Force -Recurse
if($env -ieq "DCORP"){
Set-Location $DBExecutableFolder
cmd /c $DBExecutable
}

#update username and passwords based on Environments
$batfileinfo=get-content $DBExecutable -Raw

$template=@"
SET FrontDBUser=sa
SET FrontDBPassword=_TODO_
SET FrontDBServer=_TODO_
SET FrontDBInstance=_TODO_
SET FrontDBInstanceDriveLetter=_TODO_
REM InstanceDriveLetter ==> E for icorp
REM InstanceDriveLetter ==> N for acorp and prod

SET BABEDBUser=sa
SET BABEDBPassword=_TODO_
SET BABEDBServer=_TODO_
SET BABEDBInstance=_TODO_
SET BABEDBInstanceDriveLetter=_TODO_

SET DmsDBUser=sa
SET DmsDBPassword=_TODO_
SET DmsDBServer=_TODO_

SET PortalDBUser=sa
SET PortalDBPassword=_TODO_
SET PortalDBServer=_TODO_

SET domain=_TODO_
"@

$ICORPDBinfo=@"
SET FrontDBUser=L001173
SET FrontDBPassword=teCH_Key_INT
SET FrontDBServer=Sql-be-MyBalI.Balgroupit.com
SET FrontDBInstance=is1201
SET FrontDBInstanceDriveLetter=E
REM InstanceDriveLetter ==> E for icorp
REM InstanceDriveLetter ==> N for acorp and prod

SET BABEDBUser=L001173
SET BABEDBPassword=teCH_Key_INT
SET BABEDBServer=Sql-be-BabeI.Balgroupit.com
SET BABEDBInstance=is1206
SET BABEDBInstanceDriveLetter=E

SET DmsDBUser=L001173
SET DmsDBPassword=teCH_Key_INT
SET DmsDBServer=Sql-be-MyBalI.Balgroupit.com

SET PortalDBUser=sa
SET PortalDBPassword=_TODO_
SET PortalDBServer=_TODO_

SET domain=ICORP
"@

$ACORPDBinfo=@"
SET FrontDBUser=L001172
SET FrontDBPassword=teCH_Key_ACC
SET FrontDBServer=SQL-BE-MyBalA.balgroupit.com
SET FrontDBInstance=as0801
SET FrontDBInstanceDriveLetter=E
REM InstanceDriveLetter ==> E for icorp
REM InstanceDriveLetter ==> N for acorp and prod

SET BABEDBUser=L001172
SET BABEDBPassword=teCH_Key_ACC
SET BABEDBServer=SQL-BE-BabeA.balgroupit.com
SET BABEDBInstance=as1206
SET BABEDBInstanceDriveLetter=E

SET DmsDBUser=L001172
SET DmsDBPassword=teCH_Key_ACC
SET DmsDBServer=SQL-BE-PortalA.balgroupit.com

SET PortalDBUser=L001172
SET PortalDBPassword=teCH_Key_ACC
SET PortalDBServer=SQL-BE-PortalA.balgroupit.com

SET domain=ACORP
"@

$PCORPTESTDBinfo=@"
SET FrontDBUser=L001171
SET FrontDBPassword=teCH_Key_PRO
SET FrontDBServer=sql-bep1-ps1204\ps1204,30254
SET FrontDBInstance=ps1204
SET FrontDBInstanceDriveLetter=E

SET domain=PRODTEST
"@

$dbfile=$env+"_"+$dbfile 

Switch($env){
 "ICORP" {
 $batfileinfo=$batfileinfo -ireplace $template,$ICORPDBinfo
 }
 "ACORP" {
 $batfileinfo=$batfileinfo -ireplace $template,$ACORPDBinfo
 }
 "PCORPTEST" {
  $batfileinfo=$batfileinfo -ireplace $template,$PCORPTESTDBinfo
 }
 }
$batfilepath=join-path $DBExecutableFolder -ChildPath $dbfile
Write-Host "$env File : $batfilepath"
Set-Content $batfilepath -Value $batfileinfo

	if($env -ieq "PCORPTEST"){
		Write-host "$env file generated.There will no script execution since it is a test environment"
		Exit 0
	}
	else {
		Set-Location $DBExecutableFolder
		cmd /c $batfilepath
	}
}

#Checking for Errors after execution
$ErrorFiles=@()
$ErrorFiles=Get-ChildItem -Path $DBExecutableFolder -Filter *.txt -Recurse -Force | Select-String -Pattern "Msg\s\d*,(.|\n)*."  -AllMatches  -Context 0,1 #| select path #| select Name
if ($ErrorFiles.Length -gt 0){
	Write-Host "DB Script execution had errors"
	$HtmlBody="<B>Please find the script error files`n`r </B><BR><BR>"

	Foreach($detail in $ErrorFiles){
		$fname=($detail.ToString().Split(':')[0]).Replace('>','')
		$errortext=$detail.ToString().Replace($fname,"")
		$HtmlBody+= "FileName : $fname<BR>" 
		$HtmlBody+= $errortext + "<BR><BR>"
	}
	$Mailsubject = "MyBaloise Classic DB Deployment for $curentVersion on  $env :  - Failed"
	SendMail -To $global:DBFailedMailingList -subject $Mailsubject -body $HtmlBody
}
