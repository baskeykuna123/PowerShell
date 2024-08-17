Param($Environment)

Clear-Host

if(!$Environment){
	$Environment="Par"
}

#Varibales
if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	

$ErrorActionPreference="stop"

$NewReleaseDate=Get-Date -format yyyy-MM-dd

#getting the Environment porperties
$PropertiesFilePath=[string]::Format("{0}{1}_ClevaDeploy.properties",$Global:JenkinsPropertiesRootPath,$Environment)
$EnvironmentProperties=GetProperties -FilePath $PropertiesFilePath


#getting the new created Version porperties
$NewVersionPropertiesFilePath=[string]::Format("{0}NewVersion_ClevaDeploy.properties",$Global:JenkinsPropertiesRootPath)
$NewVersionProperties=GetProperties -FilePath $NewVersionPropertiesFilePath


Write-Host "================New Version Properties========================================"
DisplayProperties -Properties $NewVersionProperties
Write-Host "================New Version Properties========================================"

#Updating the Environment Properties to use the new Version Properties for Deployment
$EnvironmentProperties["Version"]=$NewVersionProperties["Version"]
$EnvironmentProperties["ParamImportExport"]=$NewVersionProperties["ParamImportExport"]

#Setting Release Number based on Current Date
if($EnvironmentProperties["ReleaseDate"]-ne $NewReleaseDate){
	$EnvironmentProperties["ReleaseNumber"]=1
	$EnvironmentProperties["ReleaseDate"]=$NewReleaseDate
	}
else{
#update Release number and check if reaches maximum
([int]($EnvironmentProperties["ReleaseNumber"]))++
	if(([int]($EnvironmentProperties["ReleaseNumber"])) -gt 5 ){
		Write-Error "Maximum no of release for $date(5) Exceeded. Aborting...."
		Exit 1
	}
}
Write-Host "================Updated $Environment Properties========================================"
DisplayProperties -Properties $EnvironmentProperties
Write-Host "================Updated $Environment Properties========================================"

#update the Properties File
setProperties -FilePath $PropertiesFilePath -Properties $EnvironmentProperties
