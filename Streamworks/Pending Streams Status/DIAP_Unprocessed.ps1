param($Environment,$MailRecipients,$PendingFiles)

CLS
if(!$Environment){
	$Environment="DCORP"
}
#loading Functions
if(Get-Module -Name LoadFunctions){
	Remove-Module LoadFunctions -Force
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	

$Timestamp = Get-Date
$XMLfile = [String]::Format("{0}DIAP_Unprocessed.xml",$Global:InputParametersPath)
$UnprocessedFileHTMLTemplate=[String]::Format("{0},{1}(DIAPUnProcessedFile.html",$Global:HTMLTemplateRoot))
$UnprocessedFileHtmTemplate=[String]::Format("{0}\DIAPUnProcessedFile.htm",{1}$Global:EnvironmentHTMLReportLocation)

$XML = [XML](Get-Content filesystem::$XMLfile)
$GetUNProcessedFileDetails=$XML.SelectNodes("//Environment[@Name='$Environment']/Stream")
$Locations=$GetUNProcessedFileDetails.LOCATION
$Streams=$GetUNProcessedFileDetails.STREAM
$Report = "<Table class='rounded-corner'>"
$Report += "<TR align='Center'><TH colspan='3'>Baloise $Environment Unprocessed File Report</TH></TR>"
$ReportHeader += "<TR align='center'><TH>Location</TH><TH>Unprocessed Files</TH></TR>"

Foreach($pathin $($Locations.Value)){	
	Write-Host "Path:" $path
	$Content=gci filesystem::$path -File
	$Filecount=[int]$($Content.count)
	$PendingFiles=$null
	$PathData="<TD rowspan=$Filecount>$path</TD>"
	Foreach($strm in $($Streams.Name)){
	   Write-Host "strm:" $strm
	   $Content=gci filesystem::$path -File
	   $Filecount=[int]$($Content.count)
	   $PendingFiles=$null
	   $strmData="<TD rowspan=$Filecount>$strm</TD>"
	if($Filecount){
		[int]$count=1
		Write-Host "Unprocessed files :"
		ForEach($File in $($Content.Name)){
			Write-Host `t $File
			if($count -gt 1){
			$PendingFiles += [string]::Format("<TR><TD align='center'>{0}</TD></TR>",$File)
			}
			else{
				$PendingFiles += [string]::Format("<TR>{0}<TD align='center'>{1}</TD><TD align='center'>{2}</TD></TR>",$PathData,$File)
			}
		$count++	
		}
		$Report += $PendingFiles
		
	}
	else{
		Write-Host "Unprocessed files : No Files available"
		$Report += "<TR><TD>$path</TD><TD align='center' bgcolor='Orange'>No Files</TD></TR>"
	}
	}
	Write-Host `n
	
}

$Report += "</Table>"
$ReadHTML=[System.IO.File]::ReadAllLines($UnprocessedFileHTMLTemplate)
$ReadHTML=$ReadHTML -replace "#ENV#",$Environment
$ReadHTML=$ReadHTML -replace "#TESTINFO#",$Report
$ReadHTML | Out-File Filesystem::$UnprocessedFileHtmTemplate
$Mailsubject = [String]::Format("Baloise Unprocessed File Status - {0} ",$Environment)
SendMailWithoutAdmin -To $MailRecipients -subject $Mailsubject -body $ReadHTML