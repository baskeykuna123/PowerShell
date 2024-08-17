PARAM($Environment)
if(Get-Module -Name LoadFunctions){
	Remove-Module LoadFunctions -Force
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop


$TriggerJenkinsScriptFile=

if(!$Environment){
	$Environment="DCORP"
	$ApplicationName="CLEVA"
}

clear
$today=(get-date).DayOfWeek
$currenthour=(get-date).hour

#reading the scheduler xml
$XML=[xml](Get-Content FileSystem::$global:TOSCASchedulerXML)
$schedules=$XML.SelectNodes("//Environments/Environment[@Name='$($Environment)']")
$schedules.childNodes | foreach {
	if($_.Name -ieq $today){
		Write-Host "Todays Slots : `r`n"  $_.childnodes
		foreach($slot in $($_.childnodes) ){
			$Slothour=$($slot.StartTime).split(':')[0]
			if($Slothour -ieq $currenthour){
				if(!$($slot.BundleName)){
					Write-Host "Bundle name not found... Aborting Trigger!!"
					Exit 0
				}
				else{
					Write-Host "Day         : " $today
					Write-Host "StartTime   : " $Environment
					Write-Host "StartTime   : " $($slot.StartTime)
					Write-Host "Bundlename  : " $($slot.BundleName)
					Write-Host "Application : " $($slot.Applicationname)
					$parameters=@{BundleName="$($slot.BundleName)";ApplicationName="$($slot.Applicationname)";Environment="$($Environment)"}
					TriggerJenkinsJob -JobName "TOSCA_TestExecutor" -parameters $parameters -AuthToken "TOSCA"
				}
			}
		
		}
		
	}
}
