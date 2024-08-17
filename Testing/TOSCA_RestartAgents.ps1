Param
(
[String]$Server
)
CLS

# loading Function
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force 

$Server='SVW-BE-TSTFI007'

if(!$Server){
$Server='SVW-BE-TSTFI007'
}



Write-Host "======================"
Write-Host "Server     :"$Server
Write-Host "======================"



 $UserName="balgroupit\L004633" 
 $tempUserPassword ="@4:8,Z6F{5g55M"
 

$UserPassword = ConvertTo-SecureString $tempUserPassword -AsPlainText -force
$Creds = New-Object -TypeName System.management.Automation.PScredential -ArgumentList $UserName, $UserPassword
	ForEach($testserver in $Server)
	{
		Write-Host "Server : " $testserver
	    $RemoteSession = New-PSSession -Comp $Server -Credential $creds -Verbose -Authentication  Default
		$status="SUCCESS"
		if ($RemoteSession -eq $null)
		{	
			$status="ERROR"
		}
        else{
            $status="ERROR"
        }
		Remove-PSSession -Session $RemoteSession
		write-host $status
	}	
