Param($Iteration, $IterationRootPath, $Project, $Collection, $URL)
{
[Parameter(Mandatory=$true)]
[String]$Iteration,

$IterationRootPath = "Baloise"
$Project = "Baloise"
[String]$Collection= "http://svw-be-tfsp002:9192/tfs/DefaultCollection"
[String]$URL = (Invoke-WebRequest -Uri "http://svw-be-tfsp002:9192/tfs/DefaultCollection/Baloise/_admin/_work?_a=iterations").Content;

$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop

#adding TFS Asseblies
Add-Type -AssemblyName System.web
if ((Get-PSSnapIn -Name Microsoft.TeamFoundation.PowerShell -ErrorAction SilentlyContinue) -eq $null)
{
    Add-PSSnapin Microsoft.TeamFoundation.PowerShell -ErrorAction SilentlyContinue
}
 
[string] $tfsServer = "http://svw-be-tfsp002:9192/tfs/DefaultCollection"

#Connecting to TFS
$Password=$Global:builduserPassword | ConvertTo-SecureString -asPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Global:builduser,$Password)
$tfs = New-Object Microsoft.TeamFoundation.Client.TfsTeamProjectCollection($tfsServer,$credential)

foreach($IterationRootPath in $URL)        
    	{
        if ($IterationRootPath.Value -eq 'Baloise')
        {
		Get-Content $URL
        }
		{
        if($Iteration -eq $URL.content)
        {
		$Iteration = $IterationPath.Split("\")."IterationRootPath[0]\Release[1]\Portfolio[2]\IterationName[3]"	
		Remove-Variable $Iteration -Scope $IterationRootPath -Project $Project -Collection $Collection -Verbose -force
        	$Iteration.Remove-icontains(" ")
        	$USERNAME = 'L001146'
       	 	$Password = 'Baloise09'
        	Write-Host "Iteration Path removed successfully"
            }
        	{
            else
        	Write-Host "Iteration path was not found"

}
            Write-Host "Available Iterations in list"
}
}
}
