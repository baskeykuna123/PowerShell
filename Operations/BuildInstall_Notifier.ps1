Param
(
[String]$subject,
[String]$Body,
[String]$Comments
)
CLS

#loading functionss
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	

$MailRecipients="#BE_BBE_INFO_TEST_ENVIRONMENTS@baloise.be,#BE_BBE_DIS_SUPPORTMANAGERS@baloise.be,#BE_BBE_LEVEN_PROJECT@baloise.be,#be_bbe_leven_procesenrapportering@baloise.be,alerts@codit.eu,#BE_BBE_ICT_DEVELOPMENT_ESB@baloise.be,#BE_BBE_ICT_BUILD&INSTALL@baloise.be,toon.vanlooveren@baloise.be,Surekha.deshmukh@baloise.be,kenneth.Hauttekeete@Baloise.be,betty.vanuffelen@baloise.be"
$MailRecipients=$MailRecipients.split(",")

$CCRecipients="Johan.Eysackers@xerox.com,Delphine.Colle@baloise.be,VinaykumarS@hexaware.com,MullasattarM@hexaware.com,arifs@hexaware.com,youven.s.ankiah@accenture.com,lakshmita.beerachee@accenture.com,prateema.bhaugmaneea@accenture.com,khalish.a.bhundoo@accenture.com,yanesh.caussy@accenture.com,thanigai.cooroopdoss@accenture.com,vanesha.dowlut@accenture.com,z.ellahee@accenture.com,bibi.s.emamdhully@accenture.com,k.goinden@accenture.com,pajani.goinden@accenture.com,avisha.devi.gunga@accenture.com,karishma.hoolaus@accenture.com,shawkat.a.hossenally@accenture.com,sudesh.kumar.jeeanah@accenture.com,muneer.m.jubokawa@accenture.com,vanshaheer.h.khoodoruth@accenture.com,ravi.raj.a.kowlessur@accenture.com,didier.jean.b.labour@accenture.com,dheeraj.ludhor@accenture.com,javed.mandary@accenture.com,n.mooneeramsing@accenture.com,kreshnee.motee@accenture.com,nitum.mungur@accenture.com,roubina.pyanee@accenture.com,nousrina.ramgoolam@accenture.com,n.razafindrabekoto@accenture.com,a.seegoolam@accenture.com,daphnee.e.therese@accenture.com,v.radha-hurbungs@accenture.com,mohammad.paurobally@accenture.com,bodhee.bibi.zaynab@accenture.com,smitha.hegde.k@accenture.com,stef.vandeweyer@accenture.com,mormal@gmisoft.be,pdw@sireus.net,jli@sireus.net,toon.lybaert@accenture.com,Natacha.VanDerAuwermeulen@baloise.be,Geert.Thienpont@baloise.be,m.schrooten@accenture.com,Jef.Meys@baloise.be,o.diouani@accenture.com,kelly.van.der.poten@accenture.com,akshay.r.ramluckhun@accenture.com,Baloise.tl@xerox.com,alain.vanlaer@xerox.com,srinivasa.raghavan@baloise.be,aditi.bhattacharya@baloise.be,daniel.caers@baloise.be,isabelle.verspreet@baloise.be,stijn.heylen@baloise.be,stijn.debroux@baloise.be,vera.demoor@baloise.be,kristine.aertgeerts@baloise.be,geert.thienpont@baloise.be,yasseen.deherdt@baloise.be,ShubhamJ@hexaware.com,group_be-ict-at-user-facing-apps@baloise.be,alwin.vandenbosch@baloise.be,anja.lemmens@baloise.be,wannes.gevels@baloise.be,max.verbist@baloise.be"
$CCRecipients=$CCRecipients.split(",")

# Change of line validation for Body 
$Body.Contains("`n")
$Body=$Body.Replace("`n",'<BR/>')
$Comments=$Comments.Replace("`n",'<BR/>')

$smtpServer = "smtp.baloisenet.com"
$smtpFrom = "Jenkins@baloise.be"
$HTMLTemplate= [String]::Format("{0}Notifications\Templates\OperationalNotifier.html",$Global:ScriptSourcePath)
[String]$HTMLBody = [system.IO.File]::ReadAllLines($HTMLTemplate)
$HTMTemplate = [String]::Format("{0}\Build&InstallNotifier.htm",$Global:TempNotificationsFolder)
# shivaji.pai@Baloise.be,uday.turumella@baloise.be,pankaj.kumarjha@baloise.be

Write-Host "Mail Recievers list (To):$MailRecipients"
Write-Host "Mail Recievers list (CC):$CCRecipients"

$HTMLBody=$HTMLBody -replace "#BODY#",$Body
$HTMLBody=$HTMLBody -replace "#COMMENTS#",$Comments
$HTMLBody | Out-File Filesystem::$HTMTemplate
$smtpServer = "smtp.baloisenet.com"
$smtpFrom = "buildandinstall@baloise.be"

Send-MailMessage -To $MailRecipients -Cc $CCRecipients -From $smtpFrom -Subject $subject -SmtpServer $smtpServer -Body $HTMLBody -BodyAsHtml
