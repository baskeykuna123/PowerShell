$ScriptDirectory=split-path $MyInvocation.MyCommand.Definition -Parent
."$ScriptDirectory\fnSetGlobalParameters.ps1"

#loading SQL Funtions
if ((Get-PSSnapin -Registered | ? { ($_.Name -ieq "SqlServerCmdletSnapin100") -or ($_.Name -ieq "SqlServerProviderSnapin100") }) -eq $null) {
	Remove-PSSnapin -Name "SqlServerCmdletSnapin100" -ErrorAction SilentlyContinue
    Add-PSSnapin  -Name "SqlServerCmdletSnapin100" -ErrorAction SilentlyContinue
}

#add type for using unzip
Add-Type -AssemblyName System.IO.Compression.FileSystem

Function ValidateWebAppPoolAuthData{
	Param ([ref]$Windows,[ref]$Basic,[ref]$Anonymous,[ref]$AspNetImpersonation,[ref]$Forms)
	
	#BasiscAuthentication should be boolean
	#enabled ==> $true ; disabled ==> $false
	if ($Basic.Value.GetType().Name -ne "Boolean"){
		if ($Basic.Value -eq "enabled"){$Basic.Value = $true}
		elseif ($Basic.Value -eq "disabled"){$Basic.Value = $false}
		else {Write-Error "Basic not set correctly"}
	}
	
	#WindowsAuthentication should be boolean
	#enabled ==> $true ; disabled ==> $false
	if ($Windows.Value.GetType().Name -ne "Boolean"){
		if ($Windows.Value -eq "enabled"){$Windows.Value = $true}
		elseif ($Windows.Value -eq "disabled"){$Windows.Value = $false}
		else {Write-Error "Windows not set correctly"}
	}
	
	#$AspNetImpersonation should be boolean
	#enabled ==> $true ; disabled ==> $false
	if ($AspNetImpersonation.Value.GetType().Name -ne "Boolean"){
		if ($AspNetImpersonation.Value -eq "enabled"){$AspNetImpersonation.Value = $true}
		elseif ($AspNetImpersonation.Value -eq "disabled"){$AspNetImpersonation.Value = $false}
		else {Write-Error "AspNetImpersonation not set correctly"}
	}
	
	#$AnonymousAuthentication should be boolean
	#enabled ==> $true ; disabled ==> $false
	if ($Anonymous.Value.GetType().Name -ne "Boolean"){
		if ($Anonymous.Value -eq "enabled"){$Anonymous.Value = $true}
		elseif ($Anonymous.Value -eq "disabled"){$Anonymous.Value = $false}
		else {Write-Error "Anonymous not set correctly"}
	}
	
	#$Forms should be String
	#enabled ==> "Forms" ; disabled ==> "Windows"
	if ($Forms.Value -eq "enabled"){$Forms.Value = "Forms"}
	elseif ($Forms.Value -eq "disabled"){$Forms.Value = "Windows"}
	else {Write-Error "FormsAuthentication not set correctly"}
}

Function Set-MainframeAvailability
 	{
	PARAM($StartTime,$EndTime,$DayOfWeek,$DBserver,$DBName,$DBuser,$DBpassword)
		$SqlQuery = "update dbo.MainframeAvailability Set StartTime=$StartTime , EndTime=$EndTime where DayOfWeek=$DayOfWeek"
		$update=Invoke-Sqlcmd -Query $SqlQuery -ServerInstance $DBserver -Database $DBName -Username $DBuser -Password $DBpassword 
	Get-MainframeAvailability  -DBserver $DBServer -DBName $DBName  -DBuser $DBUser -DBpassword $DBPassword
	}

Function Reset-MainframeAvailability
{
	Param
	(
	[String]$DBServer,
	[String]$DBName,
	[String]$DBUser,
	[String]$DBPassword
	)
	$updateQuery = "update dbo.MainframeAvailability set StartTime='700', EndTime='2100' Where DayOfWeek in (1,2,3,4,5)"
	$update=Invoke-Sqlcmd -Query $updateQuery -ServerInstance $DBServer -Database $dbName -Username $DBuserid -Password $DBpassword 
	 
	$updateQuery = "update dbo.MainframeAvailability Set StartTime='0' , EndTime='0' where DayOfWeek='0' "
	$update=Invoke-Sqlcmd -Query $updateQuery -ServerInstance $DBServer -Database $dbName -Username $DBuserid -Password $DBpassword 

	$updateQuery = "update dbo.MainframeAvailability Set StartTime='700' , EndTime='1700' where DayOfWeek='6' "
	$update=Invoke-Sqlcmd -Query $updateQuery -ServerInstance $DBServer -Database $dbName -Username $DBuserid -Password $DBpassword
	Get-MainframeAvailability  -DBserver $DBServer -DBName $DBName  -DBuser $DBUser -DBpassword $DBPassword
}

Function Get-MainframeAvailability
{
	Param
	(
	[String]$DBServer,
	[String]$DBName,
	[String]$DBUser,
	[String]$DBPassword
	)
	
$Application="MNET"
if($DBName -like "ESB*"){$Application="ESB"}

$Sql = "  select StartTime,EndTime, (case 
  when DayOfWeek=1 then 'MONDAY'
  when DayOfWeek=2 then 'TUESDAY'
  when DayOfWeek=3 then 'WEDNESDAY'
  when DayOfWeek=4 then 'THURSDAY'
  when DayOfWeek=5 then 'FRIDAY'
  when DayOfWeek=6 then 'SATURDAY'
  when DayOfWeek=0 then 'SUNDAY'
  END  )as Day,DayOfWeek as DayNumber from dbo.MainframeAvailability  group by dayofweek,EndTime,StartTime"
$Details = Invoke-Sqlcmd -Query $Sql -ServerInstance $DBServer -Database $DBName -Username $DBUser -Password $DBPassword 

Write-Host "*********************MF availability - $Application**********************"
$Details | ft -Property StartTime,EndTime,Day,DayNumber  -AutoSize -Wrap
Write-Host "*********************MF availability - $Application **********************"


Return $Details
}




Function CreateFolder
{
param
(
[String]$FolderPath
)
Clear;
$SourcePath=Split-Path $FolderPath -Parent
try
{
	If(Test-Path $SourcePath)
	{
	New-Item -ItemType Directory -Path $FolderPath -Force | Out-Null
	}
	Else
	{
	Write-Host "Invalid Path or path does not exist $SourcePath"
	Exit 1
	}
}
Catch
{
$_.Message
}
}

Function DeleteFilesorFolders
{
Param
(
[String]$PathToDelete
)
$files=Resolve-Path $PathToDelete
if(Test-Path $PathToDelete -PathType Leaf){
Remove-Item $PathToDelete -Force -WhatIf
}
else{
$Basepath=Split-Path $PathToDelete -Parent
gci $PathToDelete -Force | foreach {
Write-Host "Deleting $($_.Name)"
Remove-Item $_.Fullname -Force -WhatIf
}	
}
}

Function Createpath 
{
	$SourcePath=$args[0]
	$i=1
	while($i -le $args.Count){
		$SourcePath=Join-Path $SourcePath -ChildPath $args[$i] -Resolve
		$i++
	}
		Test-Path $SourcePath
		return $SourcePath
}


Function SendMail($To,$cc,$subject,[string]$body){
	$smtpServer = "smtp.baloisenet.com"
	$smtpFrom = "Jenkins@baloise.be"
	$To=($global:BIAdmins +','+ $To) 
	if ($To.Substring($To.Length - 1) -ieq "," ){
        $To=$To.TrimEnd(',')| Get-Unique
    }
	Send-MailMessage -To ($To.split(',')) -From $smtpFrom -Subject $subject -Body $body -BodyAsHtml -SmtpServer $smtpServer -Verbose
	
}

Function SendMailWithoutAdmin($To,$cc,$subject,[string]$body){
	$smtpServer = "smtp.baloisenet.com"
	$smtpFrom = "Jenkins@baloise.be"
	Send-MailMessage -To ($To.split(',')) -From $smtpFrom -Subject $subject -Body $body -BodyAsHtml -SmtpServer $smtpServer -Verbose
	
}

Function SendMailWithAttchments($To,$cc,$subject,[string]$body,$attachment){
	$smtpServer = "smtp.baloisenet.com"
	$smtpFrom = "Jenkins@baloise.be"
	$To=($global:BIAdmins +','+ $To)| Get-Unique
	if ($To.Substring($To.Length - 1) -ieq "," ){
        $To=$To.TrimEnd(',') | Get-Unique
		
    }
	Send-MailMessage -To ($To.split(',')) -From $smtpFrom -Subject $subject -Body $body -BodyAsHtml -SmtpServer $smtpServer -Attachments $attachment -Verbose

}
Function Load-ParametersFromXML() {
	PARAM(
		$BuildSourcePath, 
		$Environment
	)
	$Params=@{}
	$buildSourcepath=$buildSourcepath+"\*Resolved.xml"
	$ParameterFileData=[xml]( Get-Content  Filesystem::$buildSourcepath)
	$nodes=$ParameterFileData.SelectNodes("//Environment[@name='$Environment']/add")
	foreach($node in $nodes){
		if($node.NodeType -ne "Comment"){
			$Params[$node.key]=$node.value
		}
	}
	return $Params
}

Function GetEnvironmentInfo() {
	PARAM(
		$Environment,
		$ServerType
	)
	$Testinputfile=join-path $($Global:InputParametersPath) -ChildPath "Environments.xml"
	$Environments=[xml] (get-content FileSystem::$Testinputfile)
	$EnvironmentInfo=($Environments.Environments.Environment | where {$_.Name -eq "$Environment"}).$($ServerType).SERVER
	return $EnvironmentInfo
}

Function get-Credentials() {
	PARAM(
		[string]$Environment,
		[string]$ParameterName
	)
	
	$Query="select $Environment from Credentials where ParameterName='$($ParameterName)'"
	$output=Invoke-Sqlcmd -Query $Query -ServerInstance $Global:BaloiseBIDBserver -Database $Global:BaloiseCredentialsDatabase -Username $Global:BaloiseVersionDBuserid -Password $Global:BaloiseVersionDBuserpassword -ErrorVariable $out
		if($output) {
		return $output[$Environment]
	} else {
		return "NA"
	}
}

Function get-UserCredentials() {
	PARAM(
		[string]$Environment,
		[string]$ParameterName,
		[string]$ApplicationType
	)

	$Query="select $Environment from Credentials where ParameterName like '$($ParameterName)$($ApplicationType)%'"
	$SQLOutput=Invoke-Sqlcmd -Query $Query -ServerInstance $Global:BaloiseBIDBserver -Database $Global:BaloiseCredentialsDatabase -Username $Global:BaloiseVersionDBuserid -Password $Global:BaloiseVersionDBuserpassword -ErrorVariable $out
	if($SQLOutput) {
		$credentials = New-Object -TypeName psobject 
		$credentials | Add-Member -MemberType NoteProperty -Name "User" -Value ($SQLOutput[0])[0]
		$credentials | Add-Member -MemberType NoteProperty -Name "UserPassword" -Value ($SQLOutput[1])[0]
		return $credentials
	}
	else {
		Write-Error  "Credentials Not found in the Database.... aborting operations"
		Exit 1
	}
}



Function Change-WindowsServiceExe(){
	Param(
		[string]$ServiceName,
		[string]$ServiceExePath,
		[string]$UserName,
		[string]$Password
	)

$currentService=Get-Service $ServiceName -ErrorAction SilentlyContinue
$description=$currentService.DisplayName
$startupType=$currentService.StartType
if ($currentService)
{
	$serviceToRemove = Get-WmiObject -Class Win32_Service -Filter "name='$ServiceName'"
    $serviceToRemove.delete()
    Write-host "$($ServiceName) service removed"
}
else
{
    Write-host "$($ServiceName) service does not exist"
}

Write-host "installing service : $($ServiceName)"
$secpasswd = ConvertTo-SecureString $Password -AsPlainText -Force
$mycreds = New-Object System.Management.Automation.PSCredential ($UserName, $secpasswd)
New-Service -name $serviceName -binaryPathName $ServiceExePath -displayName $description -startupType $startupType -credential $mycreds
Write-host "$($ServiceName) installation completed"
}

function SetTalkApplicationVersion 
( 
	[String] $version, 
	[String] $URL 
) 
{ 
    write-host "Sending SOAP Request To Server: $URL" 
    $soapWebRequest = [System.Net.httpWebRequest]::Create($URL) 
	$proxy=New-WebServiceProxy -Uri $URL -UseDefaultCredential 
	write-host $proxy
	$current=$proxy.getGeneralVersion()
	Write-host "Current Version :" $current
	$response=$proxy.setGeneralVersion($version)
	Write-host "Updated Version :" $response
}


function GetUserCreds(){

PARAM($Appname,$Environment)
$Userinfo=@()
switch($Appname){
	"BaloiseBackendBatch"	{
							Switch($Environment){ 
					  			"DCORP" {$Userinfo=("balgroupit\L002653","B@Be_Dev")}
					  			"ICORP" {$Userinfo=("balgroupit\L002654","B@Be_Int")} 
					  			"ACORP" {$Userinfo=("balgroupit\L002652","B@Be_ACC")}
							    "PCORP" {$Userinfo=("balgroupit\L002649","B@Be_PRO")}
							}
						}
	
	default				{
							Switch($Environment){
								"DCORP" {$Userinfo=("balgroupit\L001137","Basler09")}
					  			"ICORP" {$Userinfo=("balgroupit\L001136","Basler09")} 
					  			"ACORP" {$Userinfo=("balgroupit\L001135","h5SweHU8")}
							    "PCORP" {$Userinfo=("balgroupit\L001134","9hU5r5druS")}
							}
						}
										
}
If($Appname -ilike "*DocumentTransformBackgroundProcessingService"){
	Switch($Environment){ 
		"DCORP" {$Userinfo=("balgroupit\L006764","wDvkUmm8Q@G9TB")}
		"ICORP" {$Userinfo=("balgroupit\L006765","R3eLL4DK27RK@p")} 
		"ACORP" {$Userinfo=("balgroupit\L006766","Wh6rwBhATd#sBT")}
	    "PCORP" {$Userinfo=("balgroupit\L001147","Somi55rc")}
	}
}

return $Userinfo

}

Function RemoveReadOnly(){
PARAM($FolderPath,$Filter)
	if(-not (test-path ($FolderPath))){
		Write-Host "Invalid Test Path $($FolderPath)"
		Exit 1
	}
	Write-host "Removing Read only Attribute on :"
	get-childitem $FolderPath -Filter "$filter" -Recurse -Force | foreach {
		Write-host $_.Name
		Set-ItemProperty -Path $_.FullName -name IsReadOnly -Value $false
	}
}

Function GetVersionforNotification(){
PARAM(
	[String]$Application,
	[String]$Version
	)
$Deploymentinfo=@"
<TABLE class='rounded-corner'>
<TR align=center ><TH colspan='2'><B>Deployment Version Info</B></TH></TR>
"@
Switch($Application){
	"Cleva"				{
						$selectQuery="Select * from ClevaVersions where Cleva_Version='$Version'"
						Write-Host $selectQuery
						$select=Invoke-Sqlcmd -Query $selectQuery -ServerInstance $Global:BaloiseBIDBserver -Database $Global:BaloiseReleaseVersionDB -Username $Global:BaloiseVersionDBuserid -Password $Global:BaloiseVersionDBuserpassword -ErrorVariable $out
						foreach($col in $select.Table.Columns.ColumnName){
							$Deploymentinfo += "<TR><TD><B>$($col)</B></TD><TD>$($select[$col])</TD></TR>"
						}
						
						}
	"MyBaloiseWeb"		{
							$Deploymentinfo += "<TR align=center ><TH><B>Application</B></TH><TH><B>BuildVersion</B></TH></TR>"
							$Deploymentinfo += "<TR align=center ><TD><B>MyBaloiseWebBroker</B></TD><TD>$Version</TD></TR>"
							$Deploymentinfo += "<TR align=center ><TD><B>MyBaloiseWebInternal</B></TD><TD>$Version</TD></TR>"
							$Deploymentinfo += "<TR align=center ><TD><B>MyBaloiseWebPublic</B></TD><TD>$Version</TD></TR>"
						}
	"NINA"				{
							$Deploymentinfo += "<TR align=center ><TH><B>Application</B></TH><TH><B>BuildVersion</B></TH></TR>"
							$Deploymentinfo += "<TR align=center ><TD><B>NINA</B></TD><TD>$Version</TD></TR>"
						}
	"CentralDataStore"  {
							$Deploymentinfo += "<TR align=center ><TH><B>Application</B></TH><TH><B>BuildVersion</B></TH></TR>"
							$Deploymentinfo += "<TR align=center ><TD><B>CentralDataStore</B></TD><TD>$Version</TD></TR>"
						
						}
	"Backend"  {
							$Deploymentinfo += "<TR align=center ><TH><B>Application</B></TH><TH><B>BuildVersion</B></TH></TR>"
							$Deploymentinfo += "<TR align=center ><TD><B>Backend</B></TD><TD>$Version</TD></TR>"
						
						}
		Default		{
							$Deploymentinfo += "<TR align=center ><TH><B>Application</B></TH><TH><B>BuildVersion</B></TH></TR>"
							$Deploymentinfo += "<TR align=center ><TD><B>$($Application)</B></TD><TD>$Version</TD></TR>"
					}
}
$Deploymentinfo+="</TABLE>"	
Return $Deploymentinfo
}


Function GetMailRecipients(){
PARAM(
	[string]$ApplicationName,
	[string]$NotificationType,
	[string]$ParameterXml=""
)
	if($ParameterXml){
		Write-Host "Checking Parameter XML for MailRecipients"
		[xml]$xmldocument=Get-Content filesystem::$ParameterXml
		$RecipientNode = $xmldocument.SelectSingleNode('//Parameters/GlobalParameters/add[@key="DeploymentNotificationRecipients"]')
	}
	if($RecipientNode){
		Return $($RecipientNode.Value)
	}
		
	Switch($ApplicationName){
			"CLEVA" 	{
				if($NotificationType -eq "Deployment"){
					Return $global:CLEVADBDeploymentMail
				}
			}
			"NINA" 		{
				if($NotificationType -eq "Deployment"){
					Return $global:NINADeploymentMail
				}	
		   }
	"MyBaloiseWeb" 		{
				if($NotificationType -eq "Deployment"){
					Return $global:MWebDeploymentMail
				}
			}
	"MWebInternal"	    {
				if($NotificationType -eq "Deployment"){
					Return $global:MWebDeploymentMail
				}
	}
	"MWebBroker"	    {
				if($NotificationType -eq "Deployment"){
					Return $global:MWebDeploymentMail
				}
	}
	"CentralDataStore" {
				if($NotificationType -eq "Deployment"){
					Return $global:CDSDeploymentMail
				}
			
			}
	"Backend" {
				if($NotificationType -eq "Deployment"){
					Return $global:BackendDeploymentMail
				}
			
			}
	"MyBaloiseClassic" {
				if($NotificationType -eq "Deployment"){
					Return $global:MnetDeploymentMail
				}
			}
	"Fireco" {
				if($NotificationType -eq "Deployment"){
					Return $global:FirecoDeploymentMail
				}
			}
	Default {
				Return ""
			}
	}
}


Function GetStreamWorksDBinfo(){
PARAM(
	$Environment
	)
	switch($Environment){
	"INT"	{
				Return "sql-ie1-ag11l.balgroupit.com","StreamWorksI"
			}
	"PRD"	{
				Return "sql-pe1-ag11l.balgroupit.com","StreamWorksP"
			}
	}
}

Function GetProperties(){
PARAM(
	[String]$FilePath
	)
$properties=@{}
if((Test-Path Filesystem::$FilePath)){
	foreach($line in [System.IO.File]::ReadAllLines($FilePath)){
		$properties+= ConvertFrom-StringData $line
	}
	return $properties
}
else{
	Write-Host "Invalid Properties file path : $($FilePath)"
	Exit 1
}
}


Function DisplayProperties(){
PARAM(
	$properties
)
if($properties){
	$properties.Keys| foreach {
        $propdata=$($properties.Item($_)) -replace "\\","\\"
		Write-Host "$($_)=$propdata"
	}
}
else{
	Write-Host "No Properties to display"
}
}

Function SetProperties(){
PARAM(
	[String]$FilePath,
	$Properties
	)
$propdata=""	

if($Properties){
    $Properties.Keys|%{ $propdata+="$_="+$Properties.Item($_)+"`r`n"}
    $propdata=$propdata -replace "\\","\\"
	Set-Content Filesystem::$FilePath -Value $propdata -Force 
}
else{
	Write-Host "property list is empty. Set properties aborted"
	Exit 1
}
}

Function Copy-ACL(){
	param 
	( 
		[parameter()][string] $SourceDir,
		[parameter()][string] $DestinationDir		
	) 

	if(!$SourceDir){
		$SourceDir = '\\sql-bea2-work.balgroupit.com\ACORP'
		$DestinationDir = '\\sql-bea3-work.balgroupit.com\ACORP'
	}

	Get-ChildItem -Path $SourceDir | foreach {
		$currentSourceDir = [String]::Format("{0}\{1}", $SourceDir, $_.Name)
		$currentDestDir = [String]::Format("{0}\{1}", $DestinationDir, $_.Name)
		write-host 'setting ACL for' $currentDestDir
		get-acl -Path $currentSourceDir | Set-Acl -Path $currentDestDir
	}
}

Function GetClevaReleaseNotes(){
PARAM(
	[string]$version
	)
	$Release="R"+$version.split('.')[0]
	$Templocation="c:\Tempfolder\"
	Remove-Item $Templocation -Force -Recurse -ErrorAction SilentlyContinue
	New-Item $Templocation -ItemType directory -Force | Out-Null 
	$latestVersionFolder=Join-Path $Global:ClevaSourcePackages -ChildPath "$Release\$version\"
	$filefilter=@("*.docx","*.pdf","*.doc")
	Get-ChildItem Filesystem::$latestVersionFolder  -Include $filefilter -Recurse | foreach { Copy-Item Filesystem::$($_.FullName) -destination $Templocation -force }
	$attachments=(Get-ChildItem $Templocation -Include $filefilter -Recurse).FullName
	if(!$attachments) {
		Write-Host 	"WARNING : Attachments not for version - $version "
	}
	Return $attachments
}

#Function to get Database Server Information for Non Parameter Based applications
Function GetDBServerInfo(){
	Param($ServerType,$Environment)
	[xml] $Environments=Get-content Filesystem::$Global:EnvironmentXml
	Write-Host "//Environments/Environment[Name='$Environment']/$ServerType/SERVER"
	$node=$Environments.SelectSingleNode("//Environments/Environment[@Name='$Environment']/$ServerType/SERVER")
	Return $node.Name
#($Environments.Environments.Environment |%{ where $_.Value -ieq $Environment}).WEBFRONT.SERVER.Name #| where $ServerType.SERVER.Name
}




#Function to update the verions numbers
function ChangeVersion($version,[int]$pos,$Environment)
{
$Base=$version.Split(".")[0]
$major=$version.Split(".")[1]
$Minor=$version.Split(".")[2]
$patch=$version.Split(".")[3]


switch ($pos) 
	{ 
        1 	{
				$Base=([string]([int]$Base+1)) 
			    $major="0" 
				$Minor="0" 
				$patch="0" 
			}
		2 	{
			    $major=([string]([int]$major+1)) 
				$Minor="0" 
				$patch="0" 
			}
		3 	{
				$Minor=([string]([int]$Minor+1)) 
				$patch="0" 
			}
		4 	{
				$patch=([string]([int]$patch+1)) 
			}
	}
$newVersion=$Base + '.' + $major + '.' + $Minor + '.' + $patch
if($Environment -match "DCORP")	{
	$dt = (Get-Date).ToString("yyyMMdd")
	$time = (Get-Date).ToString("HHmmss")
	$newVersion=$Base + '.' + $major + '.' + $dt + '.' + $time
}

return $newVersion
}

#Function to copy rights from one folder to another. 
#It only copies the rights of all folders in the SourceDir to the DestinationDir, so only one level deep
Function Copy-ACL(){
	param 
	( 
		[parameter()][string] $SourceDir,
		[parameter()][string] $DestinationDir		
	) 

	if(!$SourceDir){
		$SourceDir = '\\sql-bea2-work.balgroupit.com\ACORP'
		$DestinationDir = '\\sql-bea3-work.balgroupit.com\ACORP'
	}

	Get-ChildItem -Path $SourceDir | foreach {
		$currentSourceDir = [String]::Format("{0}\{1}", $SourceDir, $_.Name)
		$currentDestDir = [String]::Format("{0}\{1}", $DestinationDir, $_.Name)
		write-host 'setting ACL for' $currentDestDir
		get-acl -Path $currentSourceDir | Set-Acl -Path $currentDestDir
	}
}

#Function used for cleanup of the build servers
Function DeleteOldLatestFoldersByConfiguration ()
{
	param 
	( 
		[parameter()][string] $buildconfiguration,
		[parameter()][string] $folderspec,		
		[parameter()][string] $isshortname
	) 

    if ($isshortname -eq $true)
	{
		if ($buildconfiguration -eq "D")
			{$maxage = 5}
		else
			{$maxage = 10}
			
		#$(Get-Item $folderspec)	| Get-ChildItem | ForEach-Object {
		Get-ChildItem -Path $folderspec | ForEach-Object {
			if ($_.name.ToUpper().StartsWith("L" + $buildconfiguration.ToUpper())){					
				$folderAge = (New-TimeSpan $($_.CreationTime	)$(Get-Date)).Days 
				#add2log $_.name "	" $folderAge "	" $_.CreationTime
				if ($folderAge -gt $maxage){
					#add2log $_.name "	" $folderAge "	" $_.CreationTime
					Remove-Item $_.PSPath -Recurse -Force
					write-host $_.name " Removed"
				}
			}
		}
	}
	else	
	{	
		if ($buildconfiguration -eq "DEBUG")
			{$maxage = 5}
		else
			{$maxage = 10}
			
		#$(Get-Item $folderspec)	| Get-ChildItem | ForEach-Object 
		
		$folders = (Get-ChildItem -Path $folderspec | where{$_.Psiscontainer}) #| Where ($_.name.ToUpper().StartsWith("LATEST." + $buildconfiguration.ToUpper())))
		foreach ($folder in $folders)
		{			
			if ( ($folder.name.ToUpper().StartsWith("LATEST." + $buildconfiguration.ToUpper())) -or ($folder.name.ToUpper().StartsWith($buildconfiguration.ToUpper())) ) 
			{					
				$folderAge = (New-TimeSpan $($folder.CreationTime	)$(Get-Date)).Days 
				#add2log $_.name "	" $folderAge "	" $_.CreationTime
				if ($folderAge -gt $maxage)
				{
					#add2log $_.name "	" $folderAge "	" $_.CreationTime
					Remove-Item $folder.PSPath -Recurse -Force
					write-host $folder.name " Removed"
				}
			}
		}
	}
}

#Function used for cleanup of the build servers
Function DeleteOldLatestFolders ()
{
	param 
	( 
		[parameter()][string] $folder
	) 

	DeleteOldLatestFoldersByConfiguration "DEBUG" $folder $false
	DeleteOldLatestFoldersByConfiguration "CUSTOM" $folder $false
	DeleteOldLatestFoldersByConfiguration "D" $folder $true
	DeleteOldLatestFoldersByConfiguration "C" $folder $true
}

#Function used for cleanup of the build servers
Function DeleteOldApplicationFoldersSingleApplication ()
{
	param 
	( 
		[parameter()][string] $application,
		[parameter()][string] $folderspec
	) 

	$maxage = 4
	
	$Shares = Get-WmiObject -Class Win32_Share -ComputerName "localhost"
    [System.Collections.ArrayList] $SharesArr = @()
    $Shares | ForEach-Object {
        $dummy=$SharesArr.Add($_.Path) 
    }
	
	$(Get-Item $folderspec)	| Get-ChildItem | ForEach-Object {
		if ($_.Name.Length -gt $application.Length) {
			if ($_.Name.SubString(0, $application.Length) -eq $application){		
				$currentFolder=$_
				$folderAge = (New-TimeSpan $($_.CreationTime	)$(Get-Date)).Days 
				#add2log $_.name "	" $folderAge "	" $_.CreationTime
				if ($folderAge -gt $maxage){
					#add2log $_.name "	" $folderAge "	" $_.CreationTime
					
                    #if ((Get-WmiObject -Class Win32_Share -ComputerName "localhost" | Where {$_.Path -eq $currentFolder.FullName}) -eq $null){
                    if (-not $SharesArr.Contains($currentFolder.FullName)) {
						#add2log $_.name "	" $folderAge "	" $_.CreationTime
						#write-host $_.name "-" $_.FullName "removed"
						Remove-Item $_.PSPath -Recurse -Force
					}
					else{
						#add2log $_.name "	" $folderAge "	" $_.CreationTime
						#write-host $_.name "-" $_.FullName "not removed"
					}
				}
			}
		}
		#Else{add2log $_.Name  '  ' $_.Name.Length  '  '  $application.Length}
	}
}

#Function used for cleanup of the build servers
Function DeleteOldApplicationFolders ()
{
	param 
	( 
		[parameter()][string] $applicationRootFolder
	) 

	$buildApplicationOverviewFileName = [String]::Concat($applicationRootFolder, "\Applications\BuildApplicationsOverview.xml")
	if ( (Test-path $buildApplicationOverviewFileName ) -eq $false)
	{    	
    	add2log (" BuildApplicationsOverview.xml does not exist!")
		break
    }
	
	$xml = New-Object XML
	$xml.load($buildApplicationOverviewFileName)
	$buildApplications = $xml.BuildApplicationsOverview.BuildApplication
	foreach ($buildApplication in $buildApplications) 
	{
		DeleteOldApplicationFoldersSingleApplication $buildApplication $applicationRootFolder
	}
}

function Test-EventLog {
    Param(
        [Parameter(Mandatory=$true)]
        [string] $LogName
    )

    [System.Diagnostics.EventLog]::SourceExists($LogName)
}

#function to check if all shares on a server are pointing to existing folders
Function validateLocalShares ()
{    
	param () 

    $totalSharesCounter=0
    $errorCounter=0

    try{
        Get-WmiObject -Class Win32_Share -ComputerName "localhost" | ForEach-Object {
            $totalSharesCounter++
            if ( ($_.Name -ne 'IPC$')) {
                if (!(test-path -path $_.Path)){
                    $errorCounter++
                    $message = [string]::Format("ShareName = {0} - LocalPath = {1}", $_.Name, $_.Path)
					if ( !( Test-EventLog "validateLocalShares") ){
						New-EventLog -Source "validateLocalShares" -LogName "Application"
					}
                    Write-EventLog -LogName "Application" -Source "validateLocalShares" -EventId 911 -EntryType Warning -Message $message
                } 
            }
        }
    }
    catch {
        $errorCounter++
    }

    if ($errorCounter -gt 0) {
        write-host "Number of shares " $totalSharesCounter
        write-host "Number of errors" $errorCounter

        SendMail -To $LocalSharesCheckMail -subject "Shares not ok on $env:computername" -body "shares not ok on $env:computername - errorCounter $errorCounter. Check eventviewer's application log."
    }
}

Function ExtractAndCopyToShare(){
Param([string]$source,[string]$destination)

#setting temp locations on C Drive
$Tempextractionsource="C:\CLEVATemp\Source\"
$TempExtracted="C:\CLEVATemp\Extracted\"
Remove-Item $Tempextractionsource -Force -Recurse
Remove-Item $TempExtracted -Force -Recurse
New-Item $Tempextractionsource -ItemType Directory -Force | Out-Null
New-Item $TempExtracted -ItemType Directory -Force | Out-Null
Copy-Item $source -Destination	$Tempextractionsource -Force -Recurse 
	$FileName=[System.IO.Path]::GetFileNameWithoutExtension($source)
	$unzipcommand=[string]::Format("unzip -oq {0}.zip -d {1}",($($Tempextractionsource)+$FileName),$($TempExtracted))
	cmd /c $unzipcommand
	Copy-Item "$($TempExtracted)\*" -Destination Filesystem::$destination -Force -Recurse
}

Function KillProcessByCommandLine($Name){

	$processes=""
	$processes = Get-WmiObject Win32_Process | where {$_.commandLine -ilike "*$($Name)*"  }
	if(!$processes){
		write-host "There are no running processes based on the Name : " $Name 	
	}
	else{
		$processes| ft -Property Name,(@{Label="User"; Expression={$_.GetOwner().user}}),Handle -AutoSize
		$processes | foreach {
			Stop-Process -Id $_.Handle -Force
		}
	}
}

function getClevaEnvironment()	{
param([string]$Environment)
	Write-Host "Environment Name : $Environment"
	switch ($Environment) 
	      { 
		    "DCORP" { $CLEVAEnv="DEV"}
	        "ICORP" { $CLEVAEnv="INT"}
			"ACORP" { $CLEVAEnv="ACC"}
			"PCORP" { $CLEVAEnv="PRD"}
			"DATAMIG"{ $CLEVAEnv="MIG"}
			"MCORP"  { $CLEVAEnv="MIG"}
			"MIG4"  { $CLEVAEnv="MIG4"}
			"MCORP4"  { $CLEVAEnv="MIG4"}
			"PRED"  { $CLEVAEnv="PRED"}
			"EMRG"  { $CLEVAEnv="EMRG"}
			"PARAM"  { $CLEVAEnv="PAR"}
			"PLAB"  { $CLEVAEnv="PAR"}
			"MIG2"  { $CLEVAEnv="MIG2"}
			"MIG"  { $CLEVAEnv="MIG"}
			
		  }
	Write-Host "Cleva Environment Name : $CLEVAEnv"
	return $CLEVAEnv
}

Function UpdateEnvironmentStatusInfoToDB{
	param($Application,$TestType,$status,$Environment)
	$Query = "INSERT INTO BIDashboard (ApplicationName,TestType,Status,DateTime,Environment) VALUES ('$Application','$TestType','$status',GETDATE(),'$Environment')"
	Invoke-Sqlcmd -ServerInstance $Global:BaloiseBIDBserver -Database $Global:BaloiseReleaseVersionDB -Username $Global:BaloiseVersionDBuserid -Password $Global:BaloiseVersionDBuserpassword -Query $Query 
}

function Unzip
{
    param([string]$zipfile, [string]$outpath)

    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $outpath)
}

function Get-RegistryValue ()
{
    param([string]$registryKey, [string]$RegistryName)

    return $(get-itemproperty $registryKey).($RegistryName)
}

function ReSet-RegistryValue ()
{
    param([string]$registryKey, [string]$RegistryName, [string]$Registryvalue)

    New-Item $registryKey -Force | New-ItemProperty -Name $RegistryName -Value $Registryvalue -Force | Out-Null
}

Function RegisterScheduledTask{
    Param(
	[String]$TaskExeName,
	[String]$TaskWorkingDirectory,
	[String]$TaskPath,
    [String]$Environment,
    [String]$TaskName,
	[String]$UserID,
	[String]$Password
    )
	
	# Variables
	Write-Host "==================================================="
	Write-Host "!! Registering Scheduled Task..!! " `n
	Write-Host "Environment		   :"$Environment
	Write-Host "Task name  		   :"$TaskName
	Write-Host "User ID    		   :"$UserID
    Write-Host "Task EXE Name      :"$TaskExeName
    Write-Host "Task Path          :"$TaskPath
    Write-Host "Task working folder:"$TaskWorkingDirectory
	Write-Host "==================================================="

	# creating a test task with similar configuration to check if it is working or not
	$action   = New-ScheduledTaskAction -Execute $TaskPath -WorkingDirectory $TaskWorkingDirectory
	$settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -IdleDuration (New-Timespan -Minutes 10) -IdleWaitTimeout (New-TimeSpan -Hours 1) -ExecutionTimeLimit (New-TimeSpan -Hours 72) -Priority "7"
	$Trigger  = New-ScheduledTaskTrigger -Daily -At 09:00
	$Task     = Register-ScheduledTask $TaskName -Action $action -Settings $settings -Trigger $Trigger -RunLevel Highest -Force

	# update triggers
	$Task.Triggers.Repetition.Duration="P1D"
	$Task.Triggers.Repetition.Interval="PT2M"
    $Task.Author=$UserID
    $Task.Principal.UserId=$UserID
    $Task.Principal.LogonType="Interactive"
	$Task.Settings.Enabled=$false

	$Task | Set-ScheduledTask -User $UserID -Password $Password -ErrorAction Stop | fl
} 

Function UnregisterScheduledTask{
    Param([String]$TaskName)
    $Task=Get-ScheduledTask -TaskName $TaskName -TaskPath "\" -ErrorAction SilentlyContinue
    if($Task){
        $Task.Settings.Enabled=$false
        Write-Host `n
        Write-Host "Unregistering scheduled Task - $TaskName .."
        Unregister-ScheduledTask -TaskName $TaskName -TaskPath "\" -Confirm:$false 
        Write-Host "Task $TaskName unregistered successfully..!!"
    }
    Else{Write-Host "INFO:Task $TaskName does not exist."}
}


Function CreateNetworkDrive($FolderPath){
	$usedDrive  = Get-PSDrive | Select-Object -Expand Name |
         	Where-Object { $_.Length -eq 1 }
	$freeDrive = 90..65 | ForEach-Object { [string][char]$_ } |
         	Where-Object { $usedDrive -notcontains $_ } |
         	Select-Object -First 1
	New-PSDrive -Name "$freeDrive" -PSProvider "FileSystem" -Root "$FolderPath"|Out-Null
	return $($freeDrive+':\')
}


Function DeleteNetworkDrive($NetworkDrive){
	$NetworkDrive=$NetworkDrive -ireplace ":\",""
	Remove-PSDrive -Name $NetworkDrive -ErrorAction SilentlyContinue | Out-Null
}

Function GetBuildDBVersionForTFSFramework($sourceBranch,$BuildDefinitionID,$DBServer,$Database,$UserID,$Password){
    $Query ="SELECT TOP 1 * FROM Release WHERE GETDATE() <= CONVERT(DATETIME, EndDate, 100) and GETDATE() >= CONVERT(DATETIME, StartDate, 100)"
    $GetBuildDBVersion=Invoke-Sqlcmd -ServerInstance $DBServer -Database $Database -Query $Query -Username $UserID -Password $Password
    $GetBuildDBVersion=$($GetBuildDBVersion.BuildDBVersion)
    $sourceBranch=$($sourceBranch).split("/")[-1]
    Write-Host "Source branch  :" $sourceBranch
    if($BuildDefinitionID -ilike "R*"){
            $ReleaseID=$([String]$sourceBranch.replace("R","")).split(".")[0]
            if($sourceBranch -ilike "*Baloise*"){
                $ReleaseID=[String]$($BuildDefinitionID.split("_")[0]).replace("R","")
            }
            Write-Host "Release ID      :"$ReleaseID
            $Query="SELECT BuildDBVersion FROM Release WHERE ReleaseID='$ReleaseID'"
            $GetBuildDBVersion=Invoke-Sqlcmd -ServerInstance $DBServer -Database $Database -Query $Query -Username $UserID -Password $Password
            $GetBuildDBVersion=$($GetBuildDBVersion.BuildDBVersion)
    }
    Write-Host "Build DB Version:"$GetBuildDBVersion
    return $GetBuildDBVersion
}


Function EnableDisableAutoStartIISApplicationPool($AppPoolName,$Action){
	Write-Host "Application pool:"$AppPoolName
	Write-Host "Action			:"$Action
	switch($Action){
		"Enable"  {$setAutoStart='true'}
		"Disable" {$setAutoStart='false'}
	}
	try{
		$GetIISApplicationPool=Get-ChildItem IIS:\AppPools | ?{$_.Name -ieq $AppPoolName}
		$GetIISApplicationPool.autoStart=$setAutoStart
		$GetIISApplicationPool | Set-Item
		Write-Host "INFO: Application pool auto start is $($Action+'d')"
	}
	catch{
		Write-Host $_
	}
}


Function SetNTServicesStartupType($ServiceName,$Actions){
	Write-Host "Service Name:"$ServiceName
	Write-Host "Action		:"$Actions
	switch($Actions){
		"Stop" {$StartupType="Manual"}
		"Start"{$StartupType="Automatic"}
	}
	try{
		Get-WmiObject -Class Win32_Service | ?{($_.Name -ieq $ServiceName) -or ($_.DisplayName -ieq $ServiceName)}|Set-Service -StartupType $StartupType
		Write-Host "startup type for service $ServiceName is set to" $StartupType
	}
	catch{
		Write-Host $_
	}
}