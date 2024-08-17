Param
(
[String]$Action,
[String]$HandlerName,
[String]$HandlerValue
)
CLS;

#Loading Functions
if(Get-Module -Name LoadFunctions){
	Remove-Module LoadFunctions -Force
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop

if(($Action) -and ($HandlerName) -and ($HandlerValue))
{
Write-Host "Creating Exppression to call...."
$Expression = $Action+"-"+$HandlerName + " " + '"'+$HandlerValue+'"'
Write-Host $Expression
Invoke-Expression $Expression -ErrorAction Stop
}
else
{
Write-Host "Parameter value is missing" -fore Red `n `r
}


