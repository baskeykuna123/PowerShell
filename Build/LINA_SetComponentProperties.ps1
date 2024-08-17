PARAM($sourcelocation,$ComponentName)

#------------------------------------------------------------------------------------------------------

# in case of a local run of the script (without input)

if(!$sourcelocation){
    $sourcelocation="E:\Buildteam\Build"
    $ComponentName="ValidationAppComponent"
    #ValidationAppComponent
    #IndividualContractAppComponent
}


#------------------------------------------------------------------------------------------------------

clear

#Loading All modules

if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions -Force
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	

#------------------------------------------------------------------------------------------------------

#Creating component property file

$version=get-date -Format "yyyyMMdd_HHmm"

$sourcelocation=join-path $sourcelocation -ChildPath $ComponentName
$SclName="SmartComponentLibrary"

#:::::::::::
$ComponentVersion=$ComponentName + "_" + $version

new-item $sourcelocation\$ComponentVersion\Compiled      -itemtype Directory -force
new-item $sourcelocation\$ComponentVersion\Database      -itemtype Directory -force
new-item $sourcelocation\$ComponentVersion\ProLib        -itemtype Directory -force
new-item $sourcelocation\$ComponentVersion\TestResult    -itemtype Directory -force
new-item $sourcelocation\$ComponentVersion\Documentation -itemtype Directory -force
#:::::::::::


$StFile=Get-ChildItem $sourcelocation -Filter "*.st" -Recurse -force | select -first 1
$DfFile=Get-ChildItem $sourcelocation -Filter "*.df" -Recurse -force | select -first 1

 
$Properties=@{}
 $Properties.add("ComponentName",$ComponentName)
 $Properties.add("DDbFolder",$sourcelocation + "\" + $ComponentVersion + "\Database")
 $Properties.add("DWorkFolder",$sourcelocation)
 $Properties.add("BuildVersion",$version)
 
 if($DfFile){
 
 $keyname=([System.IO.Path]::GetExtension($StFile.FullName)).Replace('.','') + "Filename"
 $Properties.add($keyname,$StFile.FullName)

 $keyname=([System.IO.Path]::GetExtension($DfFile.FullName)).Replace('.','') + "Filename"
 $Properties.add($keyname,$DfFile.FullName)
    
 $DbName=([System.IO.Path]::GetFileNameWithoutExtension($DfFile.FullName))
 $Properties.add("DDbName",$DbName)
 }
 else{
    $Properties.add("DDbName","")
 }

$PropertiesFilePath=Join-Path $sourcelocation -ChildPath ($ComponentName+".properties")

#------------------------------------------------------------------------------------------------------

# Creating component menu.pf file
# an exception for framework(smartcomponent),  just 1 db connection on localhost

$Templatesourcefile=join-path $Global:PackageTemplateLocation -ChildPath "Lina\Template.pf"
<#
if ($ComponentName -eq $SclName) {
   (Get-Content -Path $Templatesourcefile) | Foreach-Object {
    $_ -replace '-db SmartDb', ("-db " + $sourcelocation + "\" + $ComponentVersion + "\Database\" + $DbName + ".db") `
       -replace "-H svw-be-tlkcd001.balgroupit.com -S 9500", "-H localhost -1" `
       -replace "-db Db_LocName  -H Localhost -1", "" `
     } | set-content -Path ($sourcelocation + "\"  + $ComponentVersion + "\Database\menu.pf") -Force 
   }
else {
   (Get-Content -Path $Templatesourcefile) -replace "Db_LocName",($sourcelocation + "\" + $ComponentVersion + "\Database\" + $DbName + ".db") | set-content -Path ($sourcelocation + "\" + $ComponentVersion + "\Database\menu.pf") -Force 
   }
#>

if (-not $DfFile) {           
      (Get-Content -Path $Templatesourcefile) -replace "-db Db_LocName  -H Localhost -1", "" | set-content -Path ($sourcelocation + "\" + $ComponentVersion + "\Database\menu.pf") -Force 
      }

    elseif ($ComponentName -eq $SclName) {
           (Get-Content -Path $Templatesourcefile) | Foreach-Object {
           $_ -replace '-db SmartDb', ("-db " + $sourcelocation + "\" + $ComponentVersion + "\Database\" + $DbName + ".db") `
              -replace "-H svw-be-tlkcd001.balgroupit.com -S 9500", "-H localhost -1" `
              -replace "-db Db_LocName  -H Localhost -1", "" `
              } | set-content -Path ($sourcelocation + "\"  + $ComponentVersion + "\Database\menu.pf") -Force 
          }

          else {
               (Get-Content -Path $Templatesourcefile) -replace "Db_LocName",($sourcelocation + "\" + $ComponentVersion + "\Database\" + $DbName + ".db") | set-content -Path ($sourcelocation + "\" + $ComponentVersion + "\Database\menu.pf") -Force 
               } 


$pfFile=$sourcelocation + "\" + $ComponentVersion + "\Database\menu.pf"
$Properties.add("DpfFile",$pfFile)


#------------------------------------------------------------------------------------------------------


write-host "`r`nComponent properties"
Write-Host "`r`n----------------------------------------------------------------------------------"
DisplayProperties -properties $Properties
Write-Host "`r`n----------------------------------------------------------------------------------"
setproperties -FilePath $PropertiesFilePath  -Properties $Properties
