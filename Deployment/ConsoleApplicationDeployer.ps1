Param($Environment,$buildnumber)
Clear
#$ApplicationName="ConversiePolissenLevenMailingList"
#$Envrionment="DCORP"
#$PackageSubFolder='Mercator.Conversie.Polissen.Leven.MailingList'
#$buildnumber='DEV_CDSReports_20170523.3'
. ".\ApplicationDeployer.ps1"

$AppInfo=@{
ConversiePolissenLevenMailingList="Mercator.Conversie.Polissen.Leven.MailingList"
ConversiePolissenNietLevenMailingList="Conversion.Policy.NonLife.MailList"
BijstandMailingList="Mercator.Bijstand.MailingList"
ExecuteMailingListProjects="ExecuteMailingListProjects"
OnbetaaldeLevenMailingList="Mercator.Onbetaalde.Leven.MailingList"
POSLanguageUploadCsvData="Mercator.POS.Language.UploadCsvData"
DiefstalMailingactie="Mercator.Diefstal.Mailingactie"
GezinsplanGlobaalMailingList="Mercator.Gezinsplan.Globaal.MailingList"
InboedelBrandMailingactie="Mercator.InboedelBrand.Mailingactie"
IPTMailingList="Mercator.IPT.MailingList"
KMOGlobaalMailingList="Mercator.KMO.Globaal.MailingList"
KMOWinstdeelnameMailingList="Mercator.KMOWinstdeelname.MailingList"
LangetermijnSparenMailingList="Mercator.LangetermijnSparen.MailingList"
OnbetaaldPSVAPZLSMailingList="Mercator.Onbetaald.PS.VAPZ.LS.MailingList"
OnbetaaldeNietLevenMailingList="Mercator.Onbetaalde.NietLeven.MailingList"
PensioensparenMailingList="Mercator.Pensioensparen.MailingList"
Pensioensparen2535MailingList="Mercator.Pensioensparen25-35.MailingList"
SterSelectMailingList="Mercator.SterSelect.MailingList"
SurroundPackageMailingactie="Mercator.SurroundPackage.Mailingactie"
VAPZMailingList="Mercator.VAPZ.MailingList"
}

$AppInfo.Keys |foreach {
Write-Host "Deploying :" $_
ApplicationDeployer -Environment $Environment -applicationName $_ -buildnumber $buildnumber -PackageSubFolder $appInfo.Item($_) -applicationType "ConsoleApplication"
}