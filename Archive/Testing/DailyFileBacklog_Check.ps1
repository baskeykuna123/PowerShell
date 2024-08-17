Param
(
[String]$Environment,
[String]$Directories
)
CLS

#Loading Functions
if(Get-Module -Name LoadFunctions){
	Remove-Module LoadFunctions -Force
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	


#Default declaration
if(!$Path)
{
$Environment="PCORP"
$ClevaFilePath=""
$MainframeFilePath="" 
$ESBFilePath="" 
[String]$Directories = "$ClevaFilePath,$MainframeFilePath,$ESBFilePath"
}

$Subject = "File backlog followup"
$HtmlTemplate=[String]::Format("{0}\{1}_DailyFile_BacklogFollowup.html",$global:FileBacklogFollowUpMailingList,$Environment)
$HtmTemplate=[String]::Format("{0}\{1}_DailyFil_Backlog_Followup.htm",$global:TempNotificationsFolder,$Environment)
$HtmlBody = [System.IO.File]::ReadAllLines($HtmlTemplate)

Write-Host "======================================================================="
Write-Host "Directories to check:" $Directories
Write-Host "===============Initializing Check on the above directories============="

if((Test-Path $HtmTemplate) -eq $true)
{
Write-Host "Clearing content ---> $HtmTemplate"
Clear-Content $$HtmTemplate -Force -Verbose
}

# Checking the child items recursively on Parent dir
forEach($file in $Files.Split(",")){
   if((Test-Path $file.FullName) -eq $true)
   {
		$GetFiles = gci $file -Recurse | ?(!$_.PSIsContainer)	
		
		# Creating HTML table for the file records
		$FileHistory = "<Table class='rounded-corner'>"
		$FileHistory += "<TR align=Center><TH colspan='2'>$($file.Name) History</TH></TR>"
		$FileHistory += "<TR align=center><TH>File Name</TH><TH>Last Write Time</TH></TR>"
		ForEach($Item in $GetFiles)
		{
		$FileHistory += "<TR align=center><TD align=center>$($Item.Name)</TD><TD>$($Item.LastWriteTime)</TD>"
		}
	
	}
	else{
	Continue;
	}

$HtmlBody = $HtmlBody -ireplace "#FileInfo#",$FileHistory
$HtmlBody | Out-File FileSystem::$HtmTemplate -Append		
}

# Mailing Content
SendMail -To $global:FileBacklogFollowUpMailingList -body $HtmlBody -subject $Subject