Param([string]$Environment,[string]$ApplicationName,[System.Xml.XmlElement]$Versioninfo,[System.Xml.XmlElement]$GlobalVersioninfo)


if(!$Environment){
	$Environment="ICORP"
	$ApplicationName="MyBaloiseClassic"
	
}

$PropertiesFileName=$Environment+"_"+$ApplicationName+".properties"
$propertiesfile =join-path $Global:JenkinsPropertiesRootPath -ChildPath $PropertiesFileName
$properties=GetProperties -FilePath $propertiesfile
$properties["$($ApplicationName)_Version"]=$Versioninfo.Version
$properties["GlobalReleaseVersion"]=$GlobalVersioninfo.GlobalReleaseVersion
$properties["MercatorBuildVersion"]=$GlobalVersioninfo.MercatorBuildVersion
$properties["TFSBranch"]=$Versioninfo.TFSBranch
$properties["PreviousVersion"]=$Versioninfo.PreviousVersion
DisplayProperties $properties
setProperties -FilePath $propertiesfile -Properties $properties



