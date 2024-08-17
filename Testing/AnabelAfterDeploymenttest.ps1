param($Environment,$Application,$type,$Database)

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

$Anabelinputfile = (get-childitem -Path FileSystem::$($Global:InputParametersPath) -Force -File -Filter *.xml | where {$_.Name -ilike "*postdeployactions*"} ).FullName
New-Item -Type Directory -Path "./Reports" -force
rm ./Reports/*.xml
[XML]$ParametersInfo=get-content FileSystem::$Anabelinputfile
if(($type -ilike "SQLTests") -or ($type -ilike 'SSISTests')){
	$Objects = @("StoredProcedure")
}else{
$Objects = @("Table","View")
}
foreach($ObjectType in $Objects){
$Names=$ParametersInfo.Actions.$($type).$($Application).$($ObjectType)|Select Name,Schema -Verbose
#$Schemas-$ParametersInfo.Actions.$($type).$($Application).Table|Select Schema -Verbose
Write-Host "------------------------------------------$($ObjectType)--------------------------------------------"

foreach($Object in $Names){
    $ObjectName=$Object.Name
    $ObjectSchema=$Object.Schema
	if(($type -ilike "SQLTests") -or ($type -ilike 'SSISTests')){
		Write-Host "------------------------------------------$($Object.Schema)--------------------------------------------"
		$query="$($ObjectSchema).$($ObjectName)"
		$SQLQuery="EXEC $($query)"
		WriteJunitXML -Schema $ObjectSchema -StoredProc $ObjectName
	}else{
		$SQLQuery="IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = '$ObjectSchema' AND TABLE_NAME = '$ObjectName') BEGIN PRINT '$($ObjectType) $($Object.Name) exists' END ELSE BEGIN PRINT '$($ObjectType) $($Object.Name) doesnt exist' END"
		$output=Invoke-Sqlcmd -ServerInstance "$($DBServer)" -Username "$($DBUser)" -Password "$($DBUserPassword)" -Database "$($Database)" -Query $SQLQuery -Verbose
		$output
		if($output -ilike "*doesnt exist"){
        		$existence="No"
        	}
        	else{
        		$existence="Yes"
        	}
        		WriteXML -Application $Application -type $type -ObjectName $ObjectName -ObjectSchema $ObjectSchema -output $existence

	}
Write-Host "-----------------------------------------------------------------------------------------------------"

}
}