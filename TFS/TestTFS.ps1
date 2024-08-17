cls
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}

$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	

$file="Cleanup.xml"
$dropfilepath=join-path $Global:InputParametersPath  -ChildPath $File
$MailRecipients="deepak.gorichela@baloise.be"
$today=Get-Date -Format "dd/MM/yyyy,hh:mm:ss"
$subject="ESB Missing parameters - $today"
$bdy="C's<BR><BR>Please find the ESB Missing parameters Report Attached <BR><BR>Regards<BR>Build and Install"
SendMailWithAttchments -attachment $dropfilepath -To $MailRecipients -subject $subject -body $bdy
SendMailWithoutAdmin -To "Deepak.Gorichela@baloise.be" -subject $subject -body $bdy
