Param($DeploymentType,$Env,$seq)
Clear

if(!$DeploymentType){
	$DeploymentType=$Env=$seq="select"
}
#WINSCP Inputs
$date=[DateTime]::Now.ToString("yyyy-MM-dd")
$Hostserver="svx-be-jbcledt001.balgroupit.com"
$port=22
$username="L002618@balgroupit.com"
$password="LoktJen8"
$depfile="D:\Delivery\SQLScriptPackages\DeploymentCatalog.xml"
$deploymentInfo= [xml](get-content -Path $depfile)
$archive="D:\Delivery\SQLScriptPackages\DeployedScripts\"


$WeblogicHostserver="svx-be-cled01.balgroupit.com"
$port=22
$weblogicusername="e000930"
$weblogicpassword="Strong2014"

Function UploadPackages($DeploymentType,$Env,$seq,$date)
{
#Getting the FolderName to be deployed
	$destinationpath="/mercator/work/BUILD/DatabaseProperties/"
	if($DeploymentType -match "Emergency"){
		$SDeploymentType="YMR"
	}
	if($DeploymentType -match "Daily" -or $DeploymentType -match "Monthly"){
		$sourceFolder="\\balgroupit\appl_data\BBE\Packages\ClevaV14\Sources\SQLScripts\Scheduled\"
		$DeliveryFolder=[string]::Format("{0}_{1}_{2}",$DeploymentType,$Env,$seq)
		$folderName=[string]::Format("{0}_{1}_{2}_{3}",$DeploymentType,$date,$Env,$seq)
		$ZipfolderName=$sourceFolder+$DeliveryFolder
	}
	else{
		$sourceFolder="\\balgroupit\appl_data\BBE\Packages\ClevaV14\Sources\SQLScripts\Emergency\"
		$folderName=[string]::Format("{0}_{1}_{2}_{3}",$SDeploymentType,$date,$Env,$seq)
		$DeliveryFolder=[string]::Format("Emergency_{0}_{1}_{2}",$date,$Env,$seq)
		$ZipfolderName=$sourceFolder+$folderName
	}
	$source=$sourceFolder+$folderName
	$zipfolder=$sourceFolder+$DeliveryFolder
	
	
	Write-Host "Preparing $DeliveryFolder deployment"
	Write-Host "========================================================="
	Write-Host "Environment       : $Env"
	Write-Host "Date              : $date"
	Write-Host "Deployment Type   : $Deploymenttype"
	Write-Host "DeliveryFolder    : $DeliveryFolder"
	Write-Host "Source            : $sourceFolder"
	Write-Host "Destination       : $destinationpath"
	Write-Host "========================================================="
	
if(-NOT(Test-Path $source)){
	Write-Host "Package not found......$folderName"
}
else{
   Write-Host "Package Found.... Preparing for Deployement to the server : $destinationpath"
	if(-not(test-path $zipfolder)){
		Write-Host "Creating Deployment Folder....$DeliveryFolder"
		New-Item -ItemType Directory -Path $zipfolder
	}
	[Reflection.Assembly]::LoadFrom("D:\buildteam\WinSCP\WinSCPnet.dll")| Out-Null
	Set-Location $source 
	Move-Item $source\deployScripts.txt -Destination $zipfolder
	cmd /c "zip -rq $ZipfolderName.zip *"
	copy-Item "$ZipfolderName.zip" -Destination $zipfolder
	Write-Host "Creating $source.zip completed"
	#jboss
  	$SessionOptions=New-Object WinSCP.SessionOptions
	$SessionOptions.Protocol=[WinSCP.Protocol]::Sftp
	$SessionOptions.HostName=$Hostserver
	$SessionOptions.UserName=$username
	$SessionOptions.Password=$password
	$SessionOptions.PortNumber=$port
	$SessionOptions.GiveUpSecurityAndAcceptAnySshHostKey=$true	
	$Session=New-Object WinSCP.Session
    $Session.Open($SessionOptions)
    $transferOptions=New-Object WinSCP.TransferOptions
    $transferOptions.TransferMode=[WinSCP.TransferMode]::Binary
    Write-Host "Uploading.. files to the JBOSS Server"
	$Res=$Session.PutFiles($zipfolder,$destinationpath,$false,$transferOptions)
    $Res.Transfers
	if($Res.IsSuccess){
		Write-Host "Upload done successfully for JBOSS"
	}
	$Weblogicdestinationpath="/mercator/work/DEV/upload/"
	$SessionOptions=New-Object WinSCP.SessionOptions
	$SessionOptions.Protocol=[WinSCP.Protocol]::Sftp
	$SessionOptions.HostName=$WeblogicHostserver
	$SessionOptions.UserName=$weblogicusername
	$SessionOptions.Password=$weblogicpassword
	$SessionOptions.PortNumber=$port
	$SessionOptions.GiveUpSecurityAndAcceptAnySshHostKey=$true	
	$Session=New-Object WinSCP.Session
    $Session.Open($SessionOptions)
    $transferOptions=New-Object WinSCP.TransferOptions
    $transferOptions.TransferMode=[WinSCP.TransferMode]::Binary
    Write-Host "Uploading.. files to the Weblogic Server"
	$Res=$Session.PutFiles($zipfolder,$Weblogicdestinationpath,$false,$transferOptions)
    $Res.Transfers
	if($Res.IsSuccess){
		Write-Host "Moving Files to Archive....."
		move-Item "$ZipfolderName.zip" -Destination $archive -Force
		Set-Location $archive 
		remove-item "$sourceFolder$folderName" -Force -Recurse
		remove-item $zipfolder -Force -Recurse
		$node=$deploymentInfo.SelectSingleNode("/SqlScripts/$Env/$Deploymenttype")
		$timestamp=[DateTime]::Now.ToString("yyyy-MM-dd_HH:mm")
		$new=$deploymentInfo.CreateElement("Package")
		$new.SetAttribute("Name",$DeliveryFolder)
		$new.SetAttribute("Environment",$Env)
		$new.SetAttribute("DateTime",$timestamp)
		$new.SetAttribute("Sequence",$seq)
		$node.AppendChild($new)
		$deploymentInfo.Save($depfile)
	}
	$Session.Dispose()
}
}
$hour=(Get-Date -UFormat %H) 
if($DeploymentType -match "select")
{

#searching for Scirpt packages
if($hour -eq 11)
{
Write-Host "Searching to upload EMERGENCY SCRIPTS 3"
$ymr=get-childitem "\\balgroupit\appl_data\BBE\Packages\ClevaV14\Sources\SQLScripts\Emergency"  -Filter "*$date*3"  -recurse
}
else{
Write-Host "Searching for Emergency and daily scirpts"
$ymr=get-childitem "\\balgroupit\appl_data\BBE\Packages\ClevaV14\Sources\SQLScripts\Emergency"  -Filter "*$date*"  -recurse
$scheduled=get-childitem "\\balgroupit\appl_data\BBE\Packages\ClevaV14\Sources\SQLScripts\Scheduled" -filter "*$date*" -recurse
}

if($scheduled -ne  $null)
{
foreach($folder in $scheduled){
$filename=Split-Path $folder -Leaf
$Deploymenttype=$filename.Split('_')[0]
$Env=$filename.Split('_')[2]
$seq=$filename.Split('_')[3]
Write-Host "Uploding Scheduled folders "
UploadPackages $DeploymentType $Env $seq $date
}
}
else{
Write-Host "No Daily or Monthly Scirpts found"
}

if($ymr -ne  $null)
{
foreach($folder in $ymr){
$filename=Split-Path $folder -Leaf
$Deploymenttype="Emergency"
$Env=$filename.Split('_')[2]
$seq=$filename.Split('_')[3]
Write-Host "Uploding EMERGERNCY folders "
UploadPackages $DeploymentType $Env $seq $date
}
}
else{
Write-Host "No Emergency Scirpts Found to upload"
}
}
else
{
UploadPackages $DeploymentType $Env $seq $date
}
Exit 0

