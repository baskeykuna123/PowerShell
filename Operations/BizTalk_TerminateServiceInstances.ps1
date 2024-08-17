Param(
    $Platform,
    $Environment,
    $ServiceType=$null
)

if(!$Platform){
	$Platform="Esb"
	$Environment="dcorp"
    $ServiceType="Mercator.Esb.Service.Party.Customer.Internal.Publish.Processing.Publish, Mercator.Esb.Service.Party.Customer.Internal.Publish.Processing, Version=1.0.0.0, Culture=neutral, PublicKeyToken=0bd698de1c1bb82d"
    #$ServiceType=$null
}

Clear-Host

# loading Function
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop

Add-Type -AssemblyName ('Microsoft.BizTalk.Operations, Version=3.0.1.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35, processorArchitecture=MSIL')
$dbServer=(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\BizTalk Server\3.0\Administration' 'MgmtDBServer').MgmtDBServer
$dbName=(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\BizTalk Server\3.0\Administration' 'MgmtDBName').MgmtDBName
$BizTalkOperation=New-Object Microsoft.BizTalk.Operations.BizTalkOperations $dbServer,$dbName


if ($ServiceType){

    # Instances Info 
    Write-Host "`n"
    Write-Host "=============================================="
    Write-Host "Total Instances to be terminated:" $($BizTalkOperation.GetServiceInstances() | Where-Object {$_.ServiceType -ilike $ServiceType} ).count
    Write-Host "Environment:"$Environment
    Write-Host "=============================================="

    $BizTalkOperation.GetServiceInstances() | Where-Object {$_.ServiceType -ilike $ServiceType} | ForEach-Object {
        Try{
	        $BizTalkOperation=New-Object Microsoft.BizTalk.Operations.BizTalkOperations $dbServer,$dbName
	        $BizTalkOperation.TerminateInstance($_.ID)
	        $BizTalkOperation.Dispose() | out-null
        }
        Catch{
	        $_.Exception.Message 
        }
    }

}
else{

    # Instances Info 
    Write-Host "`n"
    Write-Host "=============================================="
    Write-Host "Total Instances to be terminated:" $($BizTalkOperation.GetServiceInstances()).Count
    Write-Host "Total Not Resumable Instances   :" $($BizTalkOperation.GetServiceInstances() | ?{$_.InstanceStatus -ilike "NotResumable"}).count
    Write-Host "Total Suspended Instances       :" $($BizTalkOperation.GetServiceInstances()| ?{$_.InstanceStatus -ilike "Suspended"}).count
    Write-Host "Total Dehydrated Instances      :" $($BizTalkOperation.GetServiceInstances()| ?{$_.InstanceStatus -ilike "Dehydrated"}).count
    Write-Host "Total Active Instances          :" $($BizTalkOperation.GetServiceInstances()| ?{$_.InstanceStatus -ilike "Active"}).count
    Write-Host "Environment:"$Environment
    Write-Host "=============================================="

    # Terminate Esb Instances
    if($Platform -ieq "Esb"){
       Write-Host "Platform:" $Platform
        if($($BizTalkOperation.GetServiceInstances()|?{$_.HostName -inotmatch "EAI*"})){
		    ForEach($instance in $($BizTalkOperation.GetServiceInstances()|?{$_.HostName -inotmatch "EAI*"})){
    		    Try{
	    		    $BizTalkOperation=New-Object Microsoft.BizTalk.Operations.BizTalkOperations $dbServer,$dbName
	    		    $BizTalkOperation.TerminateInstance($instance.ID)
	    		    $BizTalkOperation.Dispose() | out-null
	    	    }
    		    Catch{
	    		    $_.Exception.Message 
	    	    }
    	    }
        }
        Else{
		    Write-Host "INFO: No Esb Service instances found to terminate"
	    }
    }

    # Terminate Eai Instances
    if($Platform -ieq "Eai"){
       Write-Host "Platform:" $Platform
        if($($BizTalkOperation.GetServiceInstances()|?{$_.HostName -imatch "EAI*"})){
    	    ForEach($instance in $($BizTalkOperation.GetServiceInstances()|?{$_.HostName -imatch "EAI*"})){
    		    Try{
	    		    $BizTalkOperation=New-Object Microsoft.BizTalk.Operations.BizTalkOperations $dbServer,$dbName
	    		    "Instance ID :$($instance.ID)" 
	    		    $BizTalkOperation.TerminateInstance($instance.ID)
	    		    $BizTalkOperation.Dispose()
	    	    }
    		    Catch{
	    		    $_.Exception.Message
	    	    }
    	    }
        }
	    Else{
		    Write-Host "INFO: No EAI service instances found to terminate"
	    }
    }

}