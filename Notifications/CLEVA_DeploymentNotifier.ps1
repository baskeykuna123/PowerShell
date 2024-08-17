param($Environment,$BuildNumber,$mailrecipients)

Clear-Host
$ScriptDirectory=split-path $MyInvocation.MyCommand.Definition -Parent

#loading functions
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	


if(!$BuildNumber){
	
	$BuildNumber = "26.3.8.0"
	$Environment = "PLAB+DCORP"
	$DeploymentViewName = "CLEVA_DEV_and_PLAB_Deployments/"
	$mailrecipients="Shivaji.pai@baloise.be"
	#$mailrecipients="prithvi.k.sujeeun@accenture.com, anjoshni.seevathian@accenture.com, vanesha.dowlut@accenture.com, nishtabye.ittoo@accenture.com, pahllavee.mootoosamy@accenture.com, saniah.f.subratty@accenture.com, f.touopi.touopi@accenture.com, fadil.mohamudally@accenture.com, poornima.ram@accenture.com, Cleva.Releasemanagement@baloise.be, Ann.Matheus@baloise.be, arne.bormans@baloise.be, bart.helewaut@baloise.be, Wetzels, Bart <bart.wetzels@accenture.com>, betty.vanuffelen@baloise.be, christel.debie@baloise.be, Schenk, Cindy <cindy.schenk@accenture.com>, daniel.caers@baloise.be, danielle.liefferinckx@baloise.be, danny.huijbrechts@baloise.be, danny.pollenus@baloise.be, Therese, Daphnée E. <daphnee.e.therese@accenture.com>, Van Dyck, Dries <dries.van.dyck@accenture.com>, els.debaere@baloise.be, Schaekers, Filip <filip.schaekers@accenture.com>, gaby.vervoort@baloise.be, gert.adriaenssens@baloise.be, griet.dhondt@baloise.be, ingeborg.baeyens@baloise.be, jan.depuydt@baloise.be, Jens.Reyserhove@baloise.be, Hoolaus, Karishma <karishma.hoolaus@accenture.com>, katleen.vannieuwenhove@baloise.be, kenneth.hauttekeete@baloise.be, kris.vandeneede@baloise.be, Goinden, K. <k.goinden@accenture.com>, Beerachee, Lakshmita <lakshmita.beerachee@accenture.com>, leen.vanlancker@baloise.be, luc.vandevyver@baloise.be, maria.xhaet@baloise.be, marleen.vaneester@baloise.be, Seghers, Mathilde <mathilde.seghers@accenture.com>, Belloguet, Miguel L. <miguel.l.belloguet@accenture.com>, Sungum, Nishma V. <nishma.v.sungum@accenture.com>, Ramgoolam, Nousrina <nousrina.ramgoolam@accenture.com>, Eren, Ozgul <ozgul.eren@accenture.com>, peter.cardon@baloise.be, philippe.debondt@baloise.be, Bhaugmaneea, Prateema <prateema.bhaugmaneea@accenture.com>, Robin.schoenmakers@baloise.be, serge.vanmoeseke@baloise.be, sjerk.devalck@baloise.be, stefan.thoen@baloise.be, steven.vanmaercke@baloise.be, stijn.heylen@baloise.be, vicky.haazen@baloise.be, VinaykumarS@hexaware.com, Caussy, Yanesh <yanesh.caussy@accenture.com>, yves.vanhoye@baloise.be,z.ellahee@accenture.com,group_be-ict-at-user-facing-apps@baloise.be"
}


Write-Host "==============================================================================="
Write-Host "DeploymentVersion :" $BuildNumber
Write-Host "Environment       :" $Environment
Write-Host "==============================================================================="
$ApplicationName = "CLEVA"
$DBuserid="L001171"
$DBpassword="teCH_Key_PRO"
$dbserver="sql-be-buildp"
$dbName="BaloiseReleaseVersions"

#$JenkinsUrl = [string]::Format("http://Jenkins-be:8080/view/{0}/",$DeploymentViewName)
$HtmlBody = [System.IO.File]::ReadAllLines("\\shw-me-pdnet01\BuildTeam\Templates\CLEVADeploymentComplete.html")
$temphtmlfile = [string]::Format("\\shw-me-pdnet01\buildteam\temp\Timestamp\{0}_{1}_{2}.htm",$Environment,[datetime]::Now.ToString("dd-MM-yyyy_HHmm"),$ApplicationName)

$selectQuery="Select * from ClevaVersions where Cleva_Version='$BuildNumber'"
$select=Invoke-Sqlcmd -Query $selectQuery -ServerInstance $dbserver -Database $dbName -Username $DBuserid -Password $DBpassword -ErrorVariable $out


$Deploymentinfo=""
foreach($col in $select.Table.Columns.ColumnName){
	$Deploymentinfo += "<TR><TD><B>$($col)</B></TD><TD>$($select[$col])</TD></TR>"
}

#Validating the URLS
$status="SUCCESSFUL"
$testoutput = TestURLs -Environment $Environment -ApplicationName $ApplicationName
if($testoutput -ilike "*Red*"){
$status="FAILED"
}

$propfile|foreach {
$Deploymentinfo += "<TR><TD><B>$($_.key)</B></TD><TD>$($_.value)</TD></TR>"
}

$SOAPTestinfo="<TR><TH><B>Test Suite</B></TH><TH><B>Total</B></TH><TH><B>Failed</B></TH><TH><B>ExecutionTime</B></TH>"
Get-ChildItem FileSystem::"\\svw-be-itrace01\Jenkins\workspace\CLEVA_SOAPUITest_Executor\" -File -Filter "*.xml"  | foreach{
	$data=[xml] (Get-Content $($_.FullName))
	$data.testsuite | foreach {
		$SOAPTestinfo+=[string]::Format("<TR><TD><B>{0}</B></TD><TD>{1}</TD><TD>{2}</TD><TD>{3}</TD></TR>",$($_.name),$($_.tests),$($_.failures),$($_.time))
	}
}

 
 
#getting the Releases notes to be attached to the mail
$attachments=@()
$filefilter=@("*.docx","*.pdf")
$clevapacakge="\\svw-me-pcleva01\d$\Delivery\Deploy\Cleva\$($BuildNumber)"
$MIDClevapackage=[string]::Format("\\svw-me-pcleva01\d$\Accenture\{0}\ACN_Delivery\{1}\",$select.RELEASE_ID,$select.MIDC_VERSION)
$ITNClevapackage=[string]::Format("\\svw-me-pcleva01\d$\Accenture\{0}\ITN_Delivery\{1}\",$select.RELEASE_ID,$select.ITN_VERSION)
$attachments+=(Get-ChildItem  FileSystem::$MIDClevapackage -Include $filefilter  -Recurse).FullName
$attachments+=(Get-ChildItem  FileSystem::$ITNClevapackage -Include $filefilter  -Recurse).FullName

#preparing the HTML Body to the mail
$HtmlBody = $HtmlBody -ireplace "#DEPLOYMENTINFO#",$Deploymentinfo
$HtmlBody = $HtmlBody -ireplace "#TESTINFO#",$testoutput
$HtmlBody = $HtmlBody -ireplace "#ENV#",$Environment
$HtmlBody = $HtmlBody -ireplace "#SOAPTESTINFO#",$SOAPTestinfo
$HtmlBody | Out-File Filesystem::$temphtmlfile
$Mailsubject = "$ApplicationName $Environment Deployment - $BuildNumber : $status"

if(!$attachments){
	SendMail -To  $mailrecipients -body $HtmlBody -subject $Mailsubject
}
else {
	SendMailWithAttchments -To  $mailrecipients -body $HtmlBody -attachment $attachments -subject $Mailsubject
}

Remove-Item FileSystem::$temphtmlfile