Param($Version,$ApplicationName='Cleva')
Clear

if(!$Version){
	$Version='36.19.9.0'
}
Import-Module sqlps -DisableNameChecking
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	

Write-Host $ApplicationName
Write-Host $Version



Write-Host "Updating Parameters for Version : $Version"
$source="/mercator/work/BUILD/ParameterHandling/Results/*.exp"
$archive="/mercator/work/BUILD/ParameterHandling/Archive/"
$Release="R"+$Version.split('.')[0]
$sourcepath=$Global:ClevaSourcePackages
if($ApplicationName -ieq 'ClevaV14'){
	$sourcepath=$Global:ClevaV14SourcePackages
}
write-host $sourcepath
$latestVersionFolder=Join-Path $sourcepath -ChildPath "$Release\$version\parameterExport\"
$transferOptions=New-Object WinSCP.TransferOptions
$transferOptions.TransferMode = [WinSCP.TransferMode]::Binary
$SessionOptions=CreateNewSession -FTPName "JBOSSDeployment"
$Session=New-Object WinSCP.Session
$Session.Open($SessionOptions)
Write-Host "Downloading.. param file(s) to the $source"
$Res=$Session.GetFiles($source,$latestVersionFolder,$false,$transferOptions)
$directory = $session.ListDirectory("/mercator/work/BUILD/ParameterHandling/Results/")
if(!($directory.Files | where {$_.Name -ilike '*.exp'} | select -First 1)){
	Write-host "No Parameters to download on the SFTP... aborting"
	Exit 1
}
$paramVer=$Res.Transfers
if($Res.IsSuccess){
	Write-Host "Parameters downloaded Successfully"
}
Write-Host "Archiving parameters file"
$Res=$Session.MoveFile($source,$archive)
	$Res.Transfers
if($Res.IsSuccess){
	Write-Host "archiving of Parameters Compelete Successfully"
}
$Session.Dispose()




$newparamname=(Get-ChildItem filesystem::$latestVersionFolder -Filter "*.exp" -Force -Recurse).Name

#updating the parameter name in the verison
$insertQuery=[string]::Format("update [CLEVAVersions] set [PARAM_VERSION]='{0}' where  CLEVA_VERSION='{1}'",$newparamname,$Version)
$update=Invoke-Sqlcmd -Query $insertQuery -ServerInstance $Global:BaloiseBIDBserver -Database $Global:BaloiseReleaseVersionDB -Username $Global:BaloiseVersionDBuserid -Password $Global:BaloiseVersionDBuserpassword -ErrorVariable $out

Write-Host "`r`nDownoaded File :" $newparamname
Write-Host "Updated Version info :"
$getquery=[string]::Format("Select * from [CLEVAVersions] where  CLEVA_VERSION='{0}'",$Version)
$results=Invoke-Sqlcmd -Query $getquery -ServerInstance $Global:BaloiseBIDBserver -Database $Global:BaloiseReleaseVersionDB -Username $Global:BaloiseVersionDBuserid -Password $Global:BaloiseVersionDBuserpassword -ErrorVariable $out
$results