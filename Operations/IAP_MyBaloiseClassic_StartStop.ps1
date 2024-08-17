Param
(
[String]$Servers,
[String]$Action,
[String]$ApplicationType
)
ForEach($Server in $Servers)
{
	if($Action -imatch "Stop"){
		if($ApplicationType -match "BACK"){
			CD "E:\Program Files\Mercator\Management\"
			&"E:\Program Files\Mercator\Management\ServicesServer_Stop.bat"
			}
		else{
			CD "E:\Mercator\Management\"
			&"E:\Mercator\Management\WEBFMServer_Recycle.bat"
			&"E:\Mercator\Management\WEBFMServer_Stop.bat"
			}
	}

	if($Action -imatch "Start"){
		if($ApplicationType -match "BACK"){
			CD "E:\Program Files\Mercator\Management\"
			&"E:\Program Files\Mercator\Management\ServicesServer_Start.bat"
			}
		else{
			CD "E:\Mercator\Management\"
			&"E:\Mercator\Management\WEBFMServer_Recycle.bat"
			&"E:\Mercator\Management\WEBFMServer_Start.bat"
			}
	}
}
