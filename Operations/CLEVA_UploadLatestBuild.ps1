PARAM($Release,$Buildoutput="Cleva")


if(!$Release){
	$Release="R32"
}
  
#Importing SQL modules for SQL commands to the Version database
Import-Module sqlps -DisableNameChecking
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}

$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	
$LatestBuild=Join-Path $global:NewPackageRoot -ChildPath "\Cleva\Builds\$Buildoutput\*"
$SessionOptions=CreateNewSession -FTPName "MIDC"
$sftppath="/in/VM_Installation/$Release/TempBuilddownload/"
$transferOptions=New-Object WinSCP.TransferOptions
$transferOptions.TransferMode = [WinSCP.TransferMode]::Binary
$Session=New-Object WinSCP.Session
$Session.Open($SessionOptions)
$Res=$Session.PutFiles($LatestBuild,$sftppath,$false,$transferOptions)
$Res.Transfers
if($Res.IsSuccess){
	Write-Host "Upload completed for $ziplocation successfully....."
}
$Session.Dispose()