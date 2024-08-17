PARAM($SigedisSources,$Environment,[int]$TimeIntervalinMinutes)

if(!$Environment){
    $SigedisSources="D:\Shivaji\sigedisfile\"
    $TimeIntervalinMinutes=10
	$Environment="ACORP"
}


Write-Host "Input parameters..."
Write-Host "Environment           : " $Environment
Write-Host "Sigedis Source         : " $SigedisSources
Write-Host "FileDropInterval(mins): " $TimeIntervalinMinutes

$TimeIntervalinMinutes=60
Clear
#FileLocations

switch($Environment){
"ICORP" {$ESBFileClusterServer="sql-bed3-work.balgroupit.com"}
"ACORP" {$ESBFileClusterServer="sql-bea3-work.balgroupit.com"}
"PCORP" {$ESBFileClusterServer="sql-bep3-work.balgroupit.com"}

}

$SigdisDataFilePath=[string]::Format("\\{0}\{1}\BTIN\Document\Batch\Preprocess\Sigedis\Instance\",$ESBFileClusterServer,$Environment)
$SigdisTriggerFilePath=[string]::Format("\\{0}\{1}\BTIN\Document\Batch\Preprocess\Sigedis\Trigger\",$ESBFileClusterServer,$Environment)

$TriggerFileTemplate=@"
<DocumentBatchOutboundTriggerFile_In xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://document.mercator.be/batch/1.0">
  <EsbContext xmlns="">
    <ApplicationId>Unknown</ApplicationId>
    <CorrelationId>%CorrelationID%</CorrelationId>
    <CultureCode>nl-BE</CultureCode>
    <ProcessId>0001</ProcessId>
    <Timestamp>%TimeStamp%</Timestamp>
    <UserId>%UserID%</UserId>
  </EsbContext>
  <BatchContext xmlns="">
    <BundlingStartTypeCode>2</BundlingStartTypeCode>
    <BundlingTypeCode>2</BundlingTypeCode>
    <PacketGroupCount>1</PacketGroupCount>
    <PacketGroupSequence>1</PacketGroupSequence>
    <ProcessName>Pensionfile</ProcessName>
  </BatchContext>
  <Data xmlns="">
    <File>
      <FileName>%FILENAME%</FileName>
      <Path>%PATH%</Path>
    </File>
    <PacketId>01</PacketId>
  </Data>
</DocumentBatchOutboundTriggerFile_In>
"@


#UserID for Trigger File
$UserID=@{
	"ICORP"="L001094"
	"ACORP"="L001095"
	"PCORP"="L001096"
}


#Preparing SourceFolder
$CompletedFolder=join-path $SigedisSources -ChildPath "Completed"
New-Item -ItemType Directory -Path Filesystem::$CompletedFolder -Force |Out-Null 

#Getting each Datafile
$SigedisDatafiles=get-childitem  Filesystem::$SigedisSources -Force |where { ! $_.PSIsContainer }
Write-host "Total data File Count : " $SigedisDatafiles.Count
  foreach($file in $SigedisDatafiles){
  	Write-Host "======================================================================="
  	Write-Host "`r`n Processing File : "  $file.Name 
    [string] $NewGuid = [System.Guid]::NewGuid()
    $datafilePath=[string]::Format("{0}{1}\data\",$SigdisDataFilePath,$NewGuid)
    New-Item -ItemType Directory -Path Filesystem::$datafilePath -Force
	Copy-Item Filesystem::$($file.FullName) -Destination Filesystem::$datafilePath -Force
	[string] $CorrelationID = [System.Guid]::NewGuid()
	$TimeStamp=get-date -Format "yyyy-MM-ddTHH:mm:00"
	$TriggerFileData=$TriggerFileTemplate -replace "%UserID%",($UserID.$($Environment))
	$TriggerFileData=$TriggerFileData -ireplace "%CorrelationID%",$CorrelationID
	$TriggerFileData=$TriggerFileData -ireplace "%TimeStamp%",$TimeStamp
	$TriggerFileData=$TriggerFileData -ireplace "%FILENAME%",$($file.Name)
	$TriggerFileData=$TriggerFileData -ireplace "%PATH%",$($datafilePath)
	$TriggerFileSourcePath=join-path $SigedisSources -ChildPath "$($file.Name).xml"
	Set-Content Filesystem::$TriggerFileSourcePath -Force -Value $TriggerFileData
	Copy-Item Filesystem::$TriggerFileSourcePath -Destination Filesystem::$SigdisTriggerFilePath -Force
	Write-Host "`r`nWaiting for  $($TimeIntervalinMinutes) mins Till the next File Drop........"
	Start-Sleep -Milliseconds ($($TimeIntervalinMinutes)*60000)
	Write-Host "`r`n Archiving File : "  $file.Name 
	move-Item Filesystem::$($file.FullName) -Destination Filesystem::$CompletedFolder -Force
	move-Item Filesystem::$($TriggerFileSourcePath) -Destination Filesystem::$CompletedFolder -Force
	Write-Host "======================================================================="
}