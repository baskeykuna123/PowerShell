Param($version,$Env)
Clear

if(!$version){
	$version='28.3.6.0'
	$Env="DEV"
}
#folder excludes
$exclude= @('client','client_dynatrace')
$version="JBoss_"+$version
#WINSCP Inputs
$date=[DateTime]::Now.ToString("yyyy-MM-dd")
$Hostserver="svx-be-jbcledt001.balgroupit.com"
$port=22
$seq="1"
$username="L002618@balgroupit.com"
$password="LoktJen8"
$source="D:\ClevaPackages\$Env\$version\"
$uploadfolder=[string]::Format("{0}_{1}_{2}",$date,$Env,$seq)
$templocation="D:\buildteam\temp\$uploadfolder\"
if(Test-Path $templocation){
	$seq=([int](Split-Path $templocation -Leaf).split('_')[2])+1
	$uploadfolder=[string]::Format("{0}_{1}_{2}",$date,$Env,$seq)
	Remove-Item $templocation -Recurse -Force
}
$templocation="D:\buildteam\temp\$uploadfolder\"
 
Copy-Item $source -Destination $templocation -Force -Recurse
$fl=$templocation+"Client"
Remove-item $fl -force -Recurse  -ErrorAction SilentlyContinue
$fl=$templocation+"client_dynatrace" 
Remove-item $fl -force -Recurse  -ErrorAction SilentlyContinue
$fl=$templocation+"client_TOSCA" 
Remove-item $fl -force -Recurse -ErrorAction SilentlyContinue
#Getting the FolderName to be deployed
	$destinationpath="/mercator/work/BUILD/Deploys/"
	
	Write-Host "Preparing $DeliveryFolder deployment"
	Write-Host "========================================================="
	Write-Host "Environment       : $Env"
	Write-Host "Date              : $date"
	Write-Host "Source            : $templocation"
	Write-Host "Destination       : $destinationpath"
	Write-Host "========================================================="
	$ZipfolderName
    [Reflection.Assembly]::LoadFrom("D:\buildteam\WinSCP\WinSCPnet.dll")| Out-Null
    Set-Location $source 
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
    Write-Host "Uploading.. files to the server"
	$Res=$Session.PutFiles($templocation,$destinationpath,$false,$transferOptions)
    $Res.Transfers
	
	if($Res.IsSuccess){
	Write-Host "Upload completed for $ziplocation successfully....."
	}
	$Session.Dispose()


