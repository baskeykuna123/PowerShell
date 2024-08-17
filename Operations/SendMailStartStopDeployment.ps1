param(
	$Application,
	$Environment,
    $Action,
    $Version
)
CLS

#loading functions
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	

#get Deployment Pipeline Url
if ( ($Environment -ieq "Dcorp") -or ($Environment -ieq "Dcorpbis") ){
    $url=[string]::Format("`$global:{0}{1}DeploymentPipelineUrl", $Application, $Environment)
}
else{
    #there is only a IAP pipeline for icorp, acorp and pcorp
    $url=[string]::Format("`$global:{0}{1}DeploymentPipelineUrl", $Application, "IAP")
}
$resolvedUrl=$ExecutionContext.InvokeCommand.ExpandString($url)

#get mail Recipients
$Recipients=[string]::Format("`$global:{0}DeploymentMail", $Application)
$resolvedRecipients=$ExecutionContext.InvokeCommand.ExpandString($Recipients)

$HtmlTemplate = [String]::Format("{0}Notifications\Templates\{1}Deployment.html",$Global:ScriptSourcePath, $Action)
$HtmTemplate =  [String]::Format("{0}{1}Deployment_{2}.htm",$Global:TempNotificationsFolder, $Action, $Version)

if($Action -ieq "Start"){
    $subject="$Application $Environment - Deployment started - version $Version"
}
elseif($Action -ieq "Stop"){
    $subject="$Application $Environment - Deployment finished - version $Version"
}
else{
    throw "Action $Action not supported - SendMailStartStopDeployment.ps1."
}

if(! (Test-Path $HtmTemplate)){
    New-Item $HtmTemplate -itemtype file | Out-Null
}
else{
    #Template already exists, meaning that the mail for this version and this action already has been send
    #so exit because we do not want to send the mail twice
    Write-Host "Mail ""$subject"" has already been sent.."
    exit
}

$HtmlBody = [System.IO.File]::ReadAllLines($HtmlTemplate)

[string]$HtmlBody = $HtmlBody -ireplace "#Application#",$Application
$HtmlBody=$HtmlBody -ireplace "#Environment#",$Environment
$HtmlBody=$HtmlBody -ireplace "#PipelineURL#",$resolvedUrl

$HtmlBody| Out-File $HtmTemplate

# Sending mail 
SendMail -To $resolvedRecipients -body $HtmlBody -subject $subject
