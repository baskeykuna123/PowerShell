$ScriptDirectory=split-path $MyInvocation.MyCommand.Definition -Parent
."$ScriptDirectory\fnSetGlobalParameters.ps1"
."$ScriptDirectory\fnUtilities.ps1"

$WinSCPDllPath=Join-Path  (split-path $ScriptDirectory -Parent) -ChildPath "Tools/Winscp/WinSCPnet.dll"
if($env:COMPUTERNAME -ilike '*svw-me-pcleva01*'){
    Add-Type -path $WinSCPDllPath
}
else{
    Write-Host "WINSCP assembly not loaded"
}

#[System.Reflection.Assembly]::Load([IO.File]::ReadAllBytes($WinSCPDllPath))


Function CreateNewSession(){
PARAM($FTPName)
$WinSCPDllPath=(Join-Path  (split-path $ScriptDirectory	 -Parent) -ChildPath "Tools/Winscp/WinSCPnet.dll")
[Reflection.Assembly]::LoadFrom($WinSCPDllPath)| Out-Null 
$SessionOptions=New-Object WinSCP.SessionOptions
Switch($FTPName){
	"ITN"		{
					$SessionOptions.Protocol = [WinSCP.Protocol]::Ftp
					$SessionOptions.HostName = "ftp4.cleva.fr"
					$SessionOptions.UserName = "BALOISE"
					$SessionOptions.Password = "QhQdGDsIBv"
					$SessionOptions.PortNumber = 21
					$SessionOptions.FtpMode = [WinSCP.FtpMode]::Passive
					$SessionOptions.FtpSecure =[WinSCP.FtpSecure]::Explicit			
					$SessionOptions.TlsHostCertificateFingerprint = 'ad:1b:47:65:07:6e:b9:92:a0:00:27:d0:fb:ee:59:ce:93:21:c3:c6'
					
					break;
				}
{($_ -ieq "MIDC") -or ($_ -ieq "Errormon") -or ($_ -ieq "InjectR") -or ($_ -ieq "SASLOADER")}		{
					$SessionOptions.Protocol = [WinSCP.Protocol]::Sftp
					$SessionOptions.HostName = "sftp.baloise.com"
					$SessionOptions.UserName = "midc"
					$SessionOptions.PortNumber = 990
					$SessionOptions.GiveUpSecurityAndAcceptAnySshHostKey=$true	
					$SessionOptions.SshPrivateKeyPath = "D:\TEMP\IGVRV\pkeys\20120424-GV-private.ppk"			
					break;
				}
"Deployment"	{
				  	$SessionOptions.Protocol=[WinSCP.Protocol]::Sftp
					$SessionOptions.HostName="svx-be-cled01.balgroupit.com"
					$SessionOptions.UserName="e000930"
					$SessionOptions.Password="Strong2014"
					$SessionOptions.PortNumber=22
					$SessionOptions.GiveUpSecurityAndAcceptAnySshHostKey=$true	
					break;
				}
"JBOSSDeployment"	{
				  	$SessionOptions.Protocol=[WinSCP.Protocol]::Sftp
					$SessionOptions.HostName="svx-be-jbcledt001.balgroupit.com"
					$SessionOptions.UserName="L002618@balgroupit.com"
					$SessionOptions.Password="LoktJen8"
					$SessionOptions.PortNumber=22
					$SessionOptions.GiveUpSecurityAndAcceptAnySshHostKey=$true	
					break;
				}
"SASDeployment"	{
				  	$SessionOptions.Protocol=[WinSCP.Protocol]::Sftp
					$SessionOptions.HostName="svx-sas1igri001.balgroupit.com"
					$SessionOptions.UserName=""
					$SessionOptions.Password=""
					$SessionOptions.PortNumber=22
					$SessionOptions.GiveUpSecurityAndAcceptAnySshHostKey=$true	
					break;
				}
"BuildServer"	{
				  	$SessionOptions.Protocol=[WinSCP.Protocol]::Sftp
					$SessionOptions.HostName="svx-be-jnkp001.balgroupit.com"
					$SessionOptions.UserName="balgroupit\L004344"
					$SessionOptions.Password="WceZ7@nZ"
					$SessionOptions.PortNumber=22
					$SessionOptions.GiveUpSecurityAndAcceptAnySshHostKey=$true	
					break;
				}
		
}
Return $SessionOptions
}


function DownlodSASFiles(){
	PARAM(
	[String]$source,
	[String]$Destination,
	[String]$Type
	)
	$transferOptions=New-Object WinSCP.TransferOptions
	$transferOptions.TransferMode = [WinSCP.TransferMode]::Binary
	$SessionOptions=CreateNewSession -FTPName $Type
	$Session=New-Object WinSCP.Session
	$Session.Open($SessionOptions)
	$directory = $session.ListDirectory($source)
	$directory.Files
	$Res=$Session.GetFiles($source,$Destination,$false,$transferOptions)
}


Function DownloadSFTPFiles(){
PARAM(
	[String]$source,
	[String]$Destination,
	[String]$PackagePath,
	[String]$Type,
	[String]$Archive,
    [string]$AlwaysArchive="True"
	
)
	Write-Host "=============================Downloading Files======================================================"
	Write-Host "Source      :" $source
	Write-Host "Destination :" $Destination
	Write-Host "Archive     :" $archive
	Add-Type -Path "C:\Program Files (x86)\WinSCP\WinSCPnet.dll"
	$transferOptions=New-Object WinSCP.TransferOptions
	$transferOptions.TransferMode = [WinSCP.TransferMode]::Binary
	$SessionOptions=CreateNewSession -FTPName $Type
	$Session=New-Object WinSCP.Session
	$Session.Open($SessionOptions)
	$directory = $session.ListDirectory($source)	
	$newversion=""
	
	switch($Type){
	  "ITN"		{
					$filecount=1
					$filter="2010"
					break;
				}
	"MIDC"		{
					$filecount=2
					$filter="JBoss_"
					break;
				}
	"InjectR"		{
					$filecount=2
					$filter="InjectR_"
					break;
				}
    "SASLOADER"	{
					$filecount=2
					$filter="SASloader_"
					break;
				}
  "Errormon"	{
					$filecount=2
					$filter="Error-Monitoring-"
					break;
				}		
	default 	{
					$filter="Nofilter"
					Write-Host "Invalid Type.... aborting"
				}
	}
	if($directory.Files.Count -le $filecount ){
		Write-host "No $Type Version to download....aborting Download"
		Return $false
	}
	
	$newversion = (([system.IO.Path]::GetFileName(($directory.Files | where {$_.Name -ilike "$filter*"} | select -First 1))).Replace(".zip","")).Replace("JBoss_","")
	Write-Host "NewVersion: "$newversion
	if(test-path $PackagePath){
		if(Get-ChildItem -Path $PackagePath -Filter $newversion){
			Write-Host "$($newversion) is already used/Deployed... Aborting Download"
			Exit 1
		}
	}
	
	#Creates a new folder since MIDC SFTP files are not grouped in a version folder
	if(($Type -ieq "MIDC")-or ($Type -ieq "Errormon") -or ($Type -ieq "InjectR") -or ($Type -ieq "SASLOADER")){
		$Destination=join-path $Destination -ChildPath $newversion
		New-Item $Destination -ItemType Directory -Force |Out-Null	
	
	}
	
	Write-Host "Version     :" $newversion
	Write-Host "======================================================================================================="
	#Downloading file from the SFTP
	$Res=$Session.GetFiles($source,$Destination,$false,$transferOptions)
	
	if($Res.IsSuccess){
		
		Write-Host "Download completed successfully....."
	}
	else {
		$Res.Transfers
		Write-Host "The Download of the new verison has failed. Aborting new deployments"
		Exit 1
	}
	#moving to Archive
	if($AlwaysArchive -ieq "True"){
	    $Res=$Session.MoveFile("$($source)*",$archive)
	    if($Res.IsSuccess){
		    Write-Host "Archiving Compelete Successfully"
		    $Res.Transfers
			}
	}
	else
	{
		Write-Host "INFO : The Always Archive Flag is set to False"
	}

	$Session.Dispose()
	Return $true

}

function FTPArchiver(){
PARAM($source,$Archive,$Type)

	$SessionOptions=CreateNewSession -FTPName $Type
	$Session=New-Object WinSCP.Session
	$Session.Open($SessionOptions)
	$Res=$Session.MoveFile("$($source)*",$Archive)
	
	if($Res.IsSuccess){
		Write-Host "Archiving Compelete Successfully"
		$Res.Transfers
	}
	else{
		Write-Host "FAILED : Moving from $source  to $Archive"
		Exit 1
	}
	$Session.Dispose()
}


Function GetDeploymentPackageFolder(){
PARAM([String]$Environment,[String]$DeploymentDate=(get-date -Format "yyyy-MM-dd"))
	Write-Host "Checking for Deployment Package folder on : $Environment"
	$deploymentFolder=[string]::Format("{0}_{1}_",$DeploymentDate,$Environment)
	$SessionOptions= CreateNewSession -FTPName "JBOSSDeployment" 
	$Session=New-Object WinSCP.Session
	$Session.Open($SessionOptions)
	$destinationpath="/mercator/work/BUILD/Deploys/"
	$directory = $session.ListDirectory($destinationpath)
	$NameFilter=$deploymentFolder+"*"
	$PackageFolder= ([system.IO.Path]::GetFileName(($directory.Files | where {$_.Name -ilike $NameFilter} | select -First 1)))
	Write-Host "Deployment Folder Found : "$PackageFolder
	#Added for PRED Environment on DEPLOY V14 location		
	if(!$PackageFolder){
		$destinationpath="/mercator/work/BUILD/DeploysV14/"
		$directory = $session.ListDirectory($destinationpath)
		$PackageFolder= ([system.IO.Path]::GetFileName(($directory.Files | where {$_.Name -ilike $NameFilter} | select -First 1)))
		Write-Host "Deployment Folder Found : "$PackageFolder
	}
	if(!$PackageFolder){
		Write-Host "There are no deployment packages found. "
		$PackageFolder=""
	}
	return $PackageFolder
}



Function TestSFTPFiles(){
PARAM(
	[String]$source,
	[String]$Destination,
	[String]$PackagePath,
	[String]$Type,
	[String]$Archive
	
)
	Write-Host "=============================Downloading Files======================================================"
	Write-Host "Source      :" $source
	Write-Host "Destination :" $Destination
	Write-Host "Archive     :" $archive
	#Add-Type -Path "C:\Program Files (x86)\WinSCP\WinSCPnet.dll"
	$transferOptions=New-Object WinSCP.TransferOptions
	$transferOptions.TransferMode = [WinSCP.TransferMode]::Binary
	$SessionOptions=CreateNewSession -FTPName $Type
	$Session=New-Object WinSCP.Session
	$Session.Open($SessionOptions)
	$directory = $session.ListDirectory($source)	
	$newversion=""
	
	switch($Type){
	  "ITN"		{
					$filecount=1
					$filter="2010"
					break;
				}
	"MIDC"		{
					$filecount=2
					$filter="JBoss_"
					break;
				}
  "Errormon"	{
					$filecount=2
					$filter="Error-Monitoring-"
					break;
				}		
	default 	{
					$filter="Nofilter"
					Write-Host "Invalid Type.... aborting"
				}
	}
	if($directory.Files.Count -le $filecount ){
		Write-host "No $Type Version to download....aborting Download"
		Return $false
	}
	
	$newversion= (([system.IO.Path]::GetFileName(($directory.Files | where {$_.Name -ilike "$filter*"} | select -First 1))).Replace(".zip","")).Replace("JBoss_","")
	if(test-path $PackagePath){
		if(Get-ChildItem -Path $PackagePath -Filter $newversion){
			Write-Host "$($newversion) is already used/Deployed... Aborting Download"
			Exit 1
		}
	}
	
	#Creates a new folder since MIDC SFTP files are not grouped in a version folder
	if(($Type -ieq "MIDC")-or ($Type -ieq "Errormon")){
		$Destination=join-path $Destination -ChildPath $newversion
		New-Item $Destination -ItemType Directory -Force |Out-Null	
	
	}
	
	Write-Host "Version     :" $newversion
	Write-Host "======================================================================================================="
	#Downloading file from the SFTP
	$Res=$Session.GetFiles($source,$Destination,$false,$transferOptions)
	
	if($Res.IsSuccess){
		
		Write-Host "Download completed successfully....."
	}
	else {
		$Res.Transfers
		Write-Host "The Download of the new verison has failed. Aborting new deployments"
		Exit 1
	}
	#moving to Archive
	$Res=$Session.MoveFile("$($source)*",$archive)
	
	if($Res.IsSuccess){
		Write-Host "Archiving Compelete Successfully"
		$Res.Transfers
	}
	$Session.Dispose()
	Return $true

}


