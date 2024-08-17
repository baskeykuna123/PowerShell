PARAM($FolderName,$Release)


if(!$FolderName){
$FolderName=".m2"
$Release="R31"

}
  
#Importing SQL modules for SQL commands to the Version database
Import-Module sqlps -DisableNameChecking
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}

$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	
$Destination="c:\TempBuilddownload\"
$sharepath="\\balgroupit.com\appl_data\BBE\Transfer\B&I\TempFolder\ClevaBuilds\"
Remove-Item $Destination -Force -Recurse -ErrorAction SilentlyContinue 
New-Item -ItemType Directory -Path $Destination -Force 
$sourcePath="/home/nfs/balgroupit.com/l004344/jenkins/jenkins/workspace/CLEVA_Build/atlas-cleva/"+ $FolderName
if($FolderName -ilike "*m2"){
	$sourcePath="/home/nfs/balgroupit.com/l004344/" + $FolderName
}
$transferOptions=New-Object WinSCP.TransferOptions
$transferOptions.TransferMode = [WinSCP.TransferMode]::Binary
$SessionOptions=CreateNewSession -FTPName "buildServer"
$Session=New-Object WinSCP.Session
$Session.Open($SessionOptions)
$directory = $session.ListDirectory($sourcePath)
$Res=$Session.GetFiles($sourcePath,$Destination,$false,$transferOptions)
if($Res.IsSuccess){
		Write-Host "Download completed successfully....."
}
$Session.Dispose()
#Remove-Item Filesystem::"$($sharepath)\*" -Force -Recurse
#Copy-Item "$($Destination)\*" -Destination Filesystem::"$sharepath" -Force -Recurse

Write-Host "Files downloaded to : " $Destination
$SessionOptions=CreateNewSession -FTPName "MIDC"
$sftppath="/in/VM_Installation/$Release/"
$transferOptions=New-Object WinSCP.TransferOptions
$transferOptions.TransferMode = [WinSCP.TransferMode]::Binary
$Session=New-Object WinSCP.Session
$Session.Open($SessionOptions)
$Res=$Session.PutFiles($Destination,$sftppath,$false,$transferOptions)
$Res.Transfers
if($Res.IsSuccess){
	Write-Host "Upload completed for $ziplocation successfully....."
}
$Session.Dispose()