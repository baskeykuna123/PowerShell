Param($Environment,$Servers,$Recipients)

if(!$Environment){
$servers='SVW-BE-WEBP02,SVW-BE-WEBP03'
$Environment='PCORP'
$Recipients='shivaji.pai@Baloise.be'
}
#$servers = Get-Content Filesystem::"\\balgroupit.com\appl_data\BBE\Transfer\Packages\Scripts\Utilities\Serverlist.txt"
#Run the commands for each server in the list
clear

Write-Host "Server Name - $servers"
Write-Host "Recipients - $Recipients"

#Loading All modules
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions -Force
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	
$Environment="PCORP"
$Output = 'C:\temp\Result.html'
$ScriptBLock = {  

  $CPUPercent = @{
    Label = 'CPUUsed'
    Expression = {
      $SecsUsed = (New-Timespan -Start $_.StartTime).TotalSeconds
      [Math]::Round($_.CPU * 10 / $SecsUsed)
    }
  }

  $MemUsage = @{
    Label ='RAM(MB)' 
    Expression = {
    [Math]::Round(($_.WS / 1MB),2)
    }
}
	$data+="<TABLE>"
  Get-Process | Select-Object -Property Name, CPU, $CPUPercent, $MemUsage,
  Description | 
  Sort-Object -Property CPUUsed -Descending  |ConvertTo-Html
 }

Switch($Environment){ 
  "DCORP" {$UserName="balgroupit\L001137" 
           $tempUserPassword ="Basler09"} 
  "ICORP" {$UserName="balgroupit\L001136" 
           $tempUserPassword ="Basler09"} 
  "ACORP" {$UserName="balgroupit\L001135" 
  		   $tempUserPassword ="h5SweHU8"}
  "PCORP" {$UserName="balgroupit\L001134" 
           $tempUserPassword ="9hU5r5druS"}
}
$UserPassword = ConvertTo-SecureString $tempUserPassword -AsPlainText -force
$Creds = New-Object -TypeName System.management.Automation.PScredential -ArgumentList $UserName, $UserPassword

foreach ($ServerName in $servers.Split(',') ){
	$ServerName=$ServerName+".balgroupit.com"
	$datetime= Get-Date
	"`r`n`r`n`r`n$ServerName -  CPU & MEMORY USAGE - $datetime`r`n`r`n"  | Out-File $Output -Append	
	Invoke-Command -ScriptBlock $ScriptBLock -ComputerName $ServerName -Credential $Creds | Out-File $Output -Append	
	
}
$data=[IO.File]::ReadAllText($Output)
sendmailwithoutadmin -To $Recipients -body $data -subject "$Environment CPU and Memory info - $datetime"
Remove-item $Output -Force -Recurse
