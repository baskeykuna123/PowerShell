Param($Action,$siteName,$filePath)
Import-Module WebAdministration


# Self-elevate the script if required
if (-Not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
 if ([int](Get-CimInstance -Class Win32_OperatingSystem | Select-Object -ExpandProperty BuildNumber) -ge 6000) {
  $CommandLine = "-File `"" + $MyInvocation.MyCommand.Path + "`" " + $MyInvocation.UnboundArguments
  Start-Process -FilePath PowerShell.exe -Verb Runas -ArgumentList $CommandLine
  Exit
 }
}

if(!$Action){
	$Action="IMport"
	$siteName="Mercator"
	$filePath="\\balgroupit.com\appl_data\BBE\Transfer\Packages\Scripts\Notifications\Temp\test.xml"
}

Write-Host "=====================Input Parameters======================"
Write-Host "Action    : "	$Action
Write-Host "Website   : "	$siteName
Write-Host "FilePath  : "	$filePath
Write-Host "=====================Input Parameters======================"


Switch($Action){
	"Import"	{
					if($filePath){
						cmd /c "%windir%\system32\inetsrv\appcmd add site /in < $($filePath)"
					}
					else{
						Write-Host "File Not Found or Invalid : $($filePath)"
					}
				}
	"Export"	{
					if($siteName -ieq "All"){
						cmd /c "%windir%\system32\inetsrv\appcmd list site /config /xml > $($filePath)"
					}
					else{
						cmd /c "%windir%\system32\inetsrv\appcmd list site `"$($siteName)`" /config /xml > $($filePath)"
					}
					
				}
}

