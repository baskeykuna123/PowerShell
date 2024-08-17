param($Environment,$Application,$type,$Database)
#$Environment="DCORP"
#$Application="Mainframe"
#$type="SSIStests"
#$Database="TODS_TEST"
#loading Functions
if(Get-Module -Name LoadFunctions){
	Remove-Module LoadFunctions -Force
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	

Clear-Host

$DBUser=get-Credentials -Environment $Environment -ParameterName  "DataBaseDeploymentUser"
$DBUserPassword=get-Credentials -Environment $Environment -ParameterName  "DataBaseDeploymentUserPassword"
Switch($Environment){ 
			"DCORP" {
			$DBServer="SQL-BE-BIM-SASd.balgroupit.com"
			
			}
  			 
  			"ICORP" {
			$DBServer="SQL-BE-BIM-SASi.balgroupit.com"
			} 
  			
		        "PCORP" {
				 $DBServer="SQL-BE-BIM-SASp.balgroupit.com"}
	}

$Anabelinputfile = (get-childitem -Path FileSystem::$($Global:InputParametersPath) -Force -File -Filter *.xml | where {$_.Name -ilike "*Anabel*"} ).FullName

[XML]$ParametersInfo=get-content FileSystem::$Anabelinputfile
$ObjectType = "StoredProcedure"

$Names=$ParametersInfo.Actions.$($type).$($Application).$($ObjectType)|Select Name,Schema -Verbose

Write-Host "------------------------------------------$($ObjectType)--------------------------------------------"



foreach($Object in $Names){
    $ObjectName=$Object.Name
    $ObjectSchema=$Object.Schema
	$query="$($ObjectSchema).$($ObjectName)"
	$SQLQuery="EXEC $($query)"
	WriteJunitXML -Schema $ObjectSchema -StoredProc $ObjectName
	#return ([xml]$set.column1).Save('.\test.xml')
    
}