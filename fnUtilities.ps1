. "$PSScriptRoot\Functions\fnSetGlobalParameters.ps1"

if(!(Get-PSSnapin -Name SqlServerCmdletSnapin100 -ErrorAction SilentlyContinue)){
	Add-PSSnapin SqlServerCmdletSnapin100 -PassThru -ErrorAction SilentlyContinue
}
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




Function TestURLs
{
	Param
	(
	[String]$Environment,
	[String]$ApplicationName
	)
	
	$URLListFile =[string]::Format("\\shw-me-pdnet01\BuildTeam\Input\URLS\{0}_{1}_URLList.txt",$Environment,$ApplicationName)
  Write-host "==================================================================="
  $URLList = Get-Content FileSystem::$URLListFile -ErrorAction SilentlyContinue
  $Res = @()
  
  
  Foreach($Uri in $URLList) {
  write-host $Uri
  $time = try{
  $request = $null
   ## Request the URI, and measure how long the response took.
  $result1 = Measure-Command { $request = Invoke-WebRequest -Uri $uri -UseDefaultCredentials }
  $result1.TotalMilliseconds
  } 
  catch
  {
   $request = $_.Exception.Response
   $time = -1
  }  
  $Res += [PSCustomObject] @{
  Time = Get-Date;
  Uri = $uri;
  StatusCode = [int] $request.StatusCode;
  StatusDescription = $request.StatusDescription;
  ResponseLength = $request.RawContentLength;
  TimeTaken =  $time; 
  }
  
}
Write-host "==================================================================="

if($Res -ne $null)
{  
	$UrlTestResults="<TR align=center><TH><B>URL</B></TH><TH><B>StatusCode</B></TH><TH><B>StatusDescription</B></TH><TH><B>ResponseLength</B></TH><TH><B>TimeTaken</B></TH</TR>"
    Foreach($Entry in $Res)
    {
        if($Entry.StatusCode -ne "200")
        {
            $UrlTestResults += "<TR style=""background:'red'"">"
        }
        else
        {
            $UrlTestResults += "<TR>"
        }
        $UrlTestResults += "<TD><B>$($Entry.uri)</B></TD><TD align=center>$($Entry.StatusCode)</TD><TD align=center>$($Entry.StatusDescription)</TD><TD align=center>$($Entry.ResponseLength)</TD><TD align=center>$($Entry.timetaken)</TD></TR>"
    }
}

return $UrlTestResults
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
	Send-MailMessage -To ($To.split(',')) -From $smtpFrom -Subject $subject -Body $body -BodyAsHtml -SmtpServer $smtpServer -Verbose
}
Function SendMailWithAttchments($To,$cc,$subject,[string]$body,$attachment){
	$smtpServer = "smtp.baloisenet.com"
	$smtpFrom = "Jenkins@baloise.be"
	Send-MailMessage -To ($To.split(',')) -From $smtpFrom -Subject $subject -Body $body -BodyAsHtml -SmtpServer $smtpServer -Attachments $attachment -Verbose

}
Function Load-ParametersFromXML() {
	PARAM(
		$BuildSourcePath, 
		$Environment
	)
	$Params=@{}
	$buildSourcepath=$buildSourcepath+"\*Resolved.xml"
	$ParameterFileData=[xml]( Get-Content  $buildSourcepath)
	$nodes=$ParameterFileData.SelectNodes("//Environment[@name='$Environment']/add")
	foreach($node in $nodes){
		if($node.NodeType -ne "Comment"){
			$Params[$node.key]=$node.value
		}
	}
	return $Params
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
	$current=$proxy.getGeneralVersion()
	Write-host "Current Version :" $current
	$response=$proxy.setGeneralVersion($version)
	Write-host "Updated Version :" $response
}


function GetUserCreds(){

PARAM($Appname,$Environment)
$Userinfo=@()
$Environment
switch($Appname){
	"BaloiseBackendBatch"	{
							Switch($Envrionment){ 
					  			"DCORP" {$Userinfo=("balgroupit\L002653","B@Be_Dev")}
					  			"ICORP" {$Userinfo=("balgroupit\L002654","B@Be_Int")} 
					  			"ACORP" {$Userinfo=("balgroupit\L002652","B@Be_ACC")}
							    "PCORP" {$Userinfo=("balgroupit\L002649","B@Be_PRO")}
							}
						}
	default				{
							Switch($Envrionment){
								"DCORP" {$Userinfo=("balgroupit\L001137","Basler09")}
					  			"ICORP" {$Userinfo=("balgroupit\L001136","Basler09")} 
					  			"ACORP" {$Userinfo=("balgroupit\L001135","h5SweHU8")}
							    "PCORP" {$Userinfo=("balgroupit\L001134","9hU5r5druS")}
							}
						}
						
						
}
return $Userinfo
}