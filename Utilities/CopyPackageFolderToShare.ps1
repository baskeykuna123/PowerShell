param (
    [string]$SourceFolder,
    [string]$DestinationFolder,
    [string]$Version,
    [string]$Application
)

if(! $SourceFolder){
    $SourceFolder="E:\P.ESB\1.29.20181210.210518"
    $DestinationFolder="\\balgroupit.com\appl_data\bbe\Packages\Esb"
}

# loading Function
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force 

Copy-FolderWithNetUse -SourceFolder $SourceFolder -DestinationRootFolder $DestinationFolder

if($Application -ieq "ESB"){
	SendMailWithAttchments -To "deepak.gorichela@baloise.be" -body "Please find the ESB Missing parameters list in the attachments" -subject "ESB Missing Parameters" -attachment "\\balgroupit.com\appl_data\BBE\Packages\Esb\$Version\MissingParameterslist.txt"
}

