param([string]$Action,[String] $Users, [String] $Environment)

Clear-Host

#loading Functions
if(Get-Module -Name LoadFunctions){
	Remove-Module LoadFunctions -Force
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop

if(!$Users){
	#$Users=""
	#$Users="ikrnd"
	$Users="Valid03,Valid04,Valid03,, Valid04 ,"
	$Environment="Dcorp"
	$action="Add"
}

$ErrorActionPreference='Stop'

Write-Host "===================================================="
Write-Host "USERS		:"$Users
Write-Host "ENVIRONMENT	:"$Environment
Write-Host "ACTION		:"$action
Write-Host "===================================================="

$App01RootFolder="\\balgroupit.com\appl_data\bbe\App01"
$ClassicInteranal=[string]::Format("{0}\{1}\MercatorNet\MaintenanceModeFiles\Internal",$App01RootFolder,$Environment)
$ClassicBroker=[string]::Format("{0}\{1}\MercatorNet\MaintenanceModeFiles\Broker",$App01RootFolder,$Environment)
$WebBroker=[string]::Format("{0}\{1}\MercatorWeb\MercatorWebBroker\MaintenanceMode",$App01RootFolder,$Environment)
$WebInternal=[string]::Format("{0}\{1}\MercatorWeb\MercatorWebInternal\MaintenanceMode",$App01RootFolder,$Environment)

function TrimUsers($userlist){
$userlist=$userlist.Trim() -replace "\s+","" -replace ',+',',' -replace '^,|,$'
$uniq=@()
$uniq=$userlist.split(',') 
$userlist=($uniq|select -Unique ) -join ','
return $userlist
}

function DisplayUsers($list){
Write-Host "`Updated User List :" $list
}

function UpdateUserlist($userlist,$Users,$Action){
	$Users=TrimUsers $Users 
	if($Action -match "REMOVE"){
	foreach($usr in $Users.Split(',')){
	$userlist=$userlist -replace $usr,""
	}
	}
	elseif($Action -match "Add"){
	$userlist=$userlist+","+$Users
	}
	else{
	Write-Host "Invalid Action"
	Exit
	}
		$userlist= TrimUsers $userlist
		DisplayUsers $userlist
		return $userlist
}





Function UpdateMaintenanceModeUsers ($MaintenanceModeFolder, $Users,$Action)
{
	if (Test-Path $MaintenanceModeFolder)
	{
		Get-ChildItem $MaintenanceModeFolder | ForEach {
			$doc = New-Object System.Xml.XmlDocument
			Write-host "`r`nUpdating file : " $_.FullName
			$doc.Load($_.FullName)
			#maintenance mode users for MyBaloiseClassic are in key "MaintenanceUsers"
			$currentMaintenanceUsers=$doc.SelectSingleNode("//configuration/appSettings/add[@key='MaintenanceUsers']")
			#maintenance mode users for MyBaloiseWeb are in key "Users"
			$currentUsers=$doc.SelectSingleNode("//configuration/appSettings/add[@key='Users']")
			
			if ($currentMaintenanceUsers -ne $null) {
			   $currentMaintenanceUsers.value=UpdateUserlist $currentMaintenanceUsers.value $Users $Action
				}
			elseif ($currentUsers -ne $null) {
			$currentUsers.value=UpdateUserlist $currentUsers.value $Users $Action
			}
			else {
				Write-Host "Maintenande mode file" $_.FullName "is corrupt."
			 }
		 
			 $doc.Save($_.FullName)
	    }
	}
	else
	{
		Write-Host "Maintenande mode folder" $MaintenanceModeFolder "does not exist."
	}
	
				
	return $userlist
}

Write-host "Updating users on MyBaloiseClassic(Broker+Internal) and MyBaloiseWeb (Broker+Internal)"
Write-host "Environment  :" $Environment
UpdateMaintenanceModeUsers $ClassicInteranal $Users $Action
UpdateMaintenanceModeUsers $ClassicBroker $Users $Action
UpdateMaintenanceModeUsers $WebBroker $Users $Action
UpdateMaintenanceModeUsers $WebInternal $Users $Action

