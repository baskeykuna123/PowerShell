$ScriptDirectory=split-path $MyInvocation.MyCommand.Definition -Parent
	$Functionlist=Get-ChildItem -Path "$ScriptDirectory\functions\" -Filter *.ps1
	if($Functionlist){
		Get-ChildItem -Path "$ScriptDirectory\functions\" -Filter *.ps1 | ForEach-Object -process {
			Import-Module $_.FullName -DisableNameChecking -ErrorAction Stop -Verbose:$false 
		}
	}
	else{
		write-host "WARNING - UNABLE TO LOAD FUNCTIONS"
	}
	
	
	
	
