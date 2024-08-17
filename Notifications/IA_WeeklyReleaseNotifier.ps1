Param($Environment,[String]$start,[String]$end,$Comments)


if(!$Environment){
	$Environment="ICORP"
	$Release="33"
}

write-host "Additional Comments :`r`n" $Comments
$Comments.Contains("`n")
$Comments=$Comments.Replace("`n",'<BR/>')
clear

if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	


$strHTMLBody=Get-Content -Path "\\shw-me-pdnet01\BuildTeam\Templates\WeeklyRelease_Template.html"
$xml = [xml](Get-Content Filesystem::$global:ReleaseManifest )

#Get the application no to be updateed
$node=$xml.SelectSingleNode("/Release/environment[@Name='$Environment']")
$globalver=$node.GlobalReleaseVersion

# Update properties file on testp002 for ICORP and ACORP
$TestInputVerionFile=[String]::Format("\\svw-be-testp002\D$\TestWare\_PreAndPostProcessing_{0}\PreRunProcess\PreRunProcess-release.txt",$Environment)
if($(test-path Filesystem::$TestInputVerionFile)){
	set-content Filesystem::$TestInputVerionFile -Value  $globalver
}

# DB server information
$MailRecipients="#BE_BBE_INFO_TEST_ENVIRONMENTS@baloise.be,#BE_BBE_DIS_SUPPORTMANAGERS@baloise.be,#BE_BBE_LEVEN_PROJECT@baloise.be,#be_bbe_leven_procesenrapportering@baloise.be,alerts@codit.eu,#BE_BBE_ICT_BUILD&INSTALL@baloise.be,kenneth.Hauttekeete@Baloise.be,betty.vanuffelen@baloise.be,#BE_AdemarBusinessProjectAndProcess@baloise.be,#BE_BBE_ICT_DELIVERY_AT_SERVICE_GATEWAY_DEV@baloise.be,#BE_BBE_Tosca_Users@Baloise.be,shivaji.pai@baloise.be"
$MailRecipients=$MailRecipients.Split(',')

$CCRecipients="Johan.Eysackers@xerox.com,Delphine.Colle@baloise.be,mormal@gmisoft.be,pdw@sireus.net,Natacha.VanDerAuwermeulen@baloise.be,Geert.Thienpont@baloise.be,Baloise.tl@xerox.com,aditi.bhattacharya@baloise.be,daniel.caers@baloise.be,isabelle.verspreet@baloise.be,stijn.heylen@baloise.be,vera.demoor@baloise.be,kristine.aertgeerts@baloise.be,geert.thienpont@baloise.be,group_be-ict-at-user-facing-apps@baloise.be,alwin.vandenbosch@baloise.be,anja.lemmens@baloise.be,max.verbist@baloise.be,koen.vanvolsem@baloise.be,jonathan.sansens@baloise.be,glenn.mafranckx@baloise.be,BEL.GDO.SITE.IT.Monitoring.baloise@xerox.com,deepak.gorichela@baloise.be,bireshwar.adhikary@baloise.be,kuna.baskey@baloise.be,bel.gdo.site.it.monitoring.baloise@xerox.com,nik.torfs@baloise.be,leen.buizert@baloise.be,wim.vanschaik@baloise.be,kenneth.Hauttekeete@Baloise.be,arun_kumar.cherukuru@baloise.be, arben@contract.fit, efe@contract.fit, Jens@contract.fit,petra.van_hassel@baloise.be,peggy.claes@baloise.be,koen.verboven@baloise.be"
$CCRecipients=$CCRecipients.Split(',')

Write-Host "Mail Recievers list (To):$MailRecipients"
Write-Host "Mail Recievers list (CC):$CCRecipients"

$strHTMLBody=$strHTMLBody -replace "#ENV#",$Environment
$strHTMLBody=$strHTMLBody -replace "#VER#",$globalver
$strHTMLBody=$strHTMLBody -replace "#START#",$start
$strHTMLBody=$strHTMLBody -replace "#END#",$end
$strHTMLBody=$strHTMLBody -replace "#COMMENTS#",$Comments
$strHTMLBody=[string]$strHTMLBody

Set-Content "\\shw-me-pdnet01\buildteam\Temp\Release.html" -Value $strHTMLBody

$smtpServer = "smtp.baloisenet.com"
$smtpFrom = "buildandinstall@baloise.be"
$subject="$Environment $globalver Deployment -$start"

Send-MailMessage -To $MailRecipients -Cc $CCRecipients   -From $smtpFrom -Subject $subject -Body $strHTMLBody -BodyAsHtml -SmtpServer $smtpServer
