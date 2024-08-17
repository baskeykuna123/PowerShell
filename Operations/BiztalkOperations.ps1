Param
(
[String]$Action,
[String]$Entity,
[String]$EntityName,
[String]$appName
)
CLS;

#Loading Functions
if(Get-Module -Name LoadFunctions){
	Remove-Module LoadFunctions -Force
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop

if(($Action) -and ($Entity) -and ($EntityName))
{
$FunctionName=$Action+"-"+$Entity

	if(($FunctionName -eq "Start-BTSApplication") -or ($FunctionName -eq "Stop-BTSApplication") -or ($FunctionName -eq "Start-HostInstance") -or ($FunctionName -eq "Stop-HostInstance") -or ($FunctionName -eq "Create-BTSApplication") -or ($FunctionName -eq "Remove-BTSApplication") -or ($FunctionName -eq "Export-BindingFile") -or ($FunctionName -eq "Import-BindingFile"))
	{
	$Expression = $Action+"-"+$Entity + " " +'"'+$EntityName+'"'
	Write-Host $Expression
	Invoke-Expression $Expression
	exit
	}
	
Write-Host "Creating Exppression to call...."
$Expression = $Action+"-"+$Entity + " " +'"'+$appName+'"'+ " " +'"'+$EntityName+'"'
Write-Host $Expression
Invoke-Expression $Expression -ErrorAction Stop
}

else
{
Write-Host "Parameter value is missing" 
}