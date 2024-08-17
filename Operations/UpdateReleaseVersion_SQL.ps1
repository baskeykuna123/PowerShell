PARAM($Environment,$PlatformName,$Action,$ActionType)
#$PlatformName="Baloise.CentralDataStore"
#$Action="upgrade"
#$ActionType="minor"
#$Environment="ICORP"

$GlobalManifest="\\shw-me-pdnet01\Repository\GlobalReleaseManifest.xml"
$xml = [xml](Get-Content $GlobalManifest )
$node=$xml.SelectSingleNode("/Release/environment[@Name='$Environment']")

# DB server information
$Global:DBuserid="L001171"
$Global:DBpassword="teCH_Key_PRO"
$dbserver="sql-be-buildp"
$dbName=[string]::Format("MercatorBuild.{0}",$node.MercatorBuildVersion)

#setting the position to be udpated
switch ($ActionType) 
      { 
        "Base"  { $pos=1}
		"Major" { $pos=2}
		"Minor" { $pos=3}
		"Patch" { $pos=4}   
      }

# Function to create the new version
function ChangeVersion($version,[int]$pos)
{
$Base=$version.Split(".")[0]
$major=$version.Split(".")[1]
$Minor=$version.Split(".")[2]
$patch=$version.Split(".")[3]

switch ($pos) 
    { 
        1 {$newVersion=[string]([int]$Base+1) + '.' + [string]([int]$major*0) + '.' + [string]([int]$Minor*0) + '.' + [string]([int]$patch*0)} 
        2 {$newVersion=$Base + '.' + [string]([int]$major+1) + '.' + [string]([int]$Minor*0) + '.' + [string]([int]$patch*0)} 
        3 {$newVersion=$Base + '.' + $major + '.' + ([int]$Minor+1) + '.' + [string]([int]$patch*0)} 
        4 {$newVersion=$Base + '.' + $major + '.' + $Minor + '.' + [string]([int]$patch+1)} 
		-1 {$newVersion=[string]([int]$Base-1) + '.' + [string]([int]$major*0) + '.' + [string]([int]$Minor*0) + '.' + [string]([int]$patch*0)} 
        -2 {$newVersion=$Base + '.' + [string]([int]$major-1) + '.' + [string]([int]$Minor*0) + '.' + [string]([int]$patch*0)} 
        -3 {$newVersion=$Base + '.' + $major + '.' + [string]([int]$Minor-1) + '.' + [string]([int]$patch*0)} 
        -4 {$newVersion=$Base + '.' + $major + '.' + $Minor + '.' + [string]([int]$patch-1)}  
     }
return $newVersion
}




#Database Update queries
$selectQuery="select PlatformName,platformVersion from Platforms where PlatformName='$PlatformName'"
$select=Invoke-Sqlcmd -Query $selectQuery -ServerInstance $dbserver -Database $dbName -Username $Global:DBuserid -Password $Global:DBpassword -ErrorVariable $out
$version = ChangeVersion $select.platformVersion $pos
$updateQuery="Update Platforms set platformVersion='$version' where PlatformName='$PlatformName'"
$update=Invoke-Sqlcmd -Query $updateQuery -ServerInstance $dbserver -Database $dbName -Username $Global:DBuserid -Password $Global:DBpassword -ErrorVariable $out
if($PlatformName -match "Mercator.Web"){
$PlatformName="Mercator.Web.Broker"
$updateQuery="Update Platforms set platformVersion='$version' where PlatformName='$PlatformName'"
$update=Invoke-Sqlcmd -Query $updateQuery -ServerInstance $dbserver -Database $dbName -Username $Global:DBuserid -Password $Global:DBpassword -ErrorVariable $out
}

Write-Host "`n================================================================================"
Write-Host "Platfrom Name : " $select.platformName
Write-host "Current Verison in the DB : " $select.platformVersion
Write-host "Updated Version : " $version
Write-host "Update type :""$ActionType"" Version update "
Write-Host "`n================================================================================"



