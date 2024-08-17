$ReplacementString=@{
"acc-clevabo.balgroupit.com:9111" = "acc-clevabo.balgroupit.com";	
} 



$SearchLocation=@"
asgwbts01=E$\Program Files\Mercator\Esb\
"@


$missedlist=@()
$list=@()
$filelist=@()
$filecount=0

clear
$filefilter=@("*.xml")
$SearchLocation | %{$_.Split("`r`n")} | where {-not [string]::IsNullOrEmpty($_)} | foreach {
	$SerachBasepath=[string]::Format("\\{0}\{1}",$_.Split('=')[0],$_.Split('=')[1])
	if(Test-Path Filesystem::$SerachBasepath){
		write-host "Search Path :" $SerachBasepath
		$filelist=get-childitem Filesystem::$SerachBasepath  -Force -Recurse -Filter "*.xml" -File | where {$_.Name -ilike "*BindingInfo.xml"}
		
		foreach($fl in $filelist){
			$data=Get-Content -Path Filesystem::$($fl.FullName)
			$originalData=$data
			$ReplacementString.GETENUMERATOR() | ForEach-Object {
				$serachtext=[Regex]::Escape($_.key)
				Write-Host "Search TExt :" $_.key
				$data=$data -replace $serachtext,$_.value 
			}
			if($originalData -ieq $data){
				Write-Host "Missed Replace for file :" $($fl.FullName) 
				$missedlist+=$($fl.FullName)
			}else {
				Write-Host "File updated :"  (split-path  $fl.FullName -Leaf)
				$list+=$($fl.FullName)
				Set-Content -Path Filesystem::$($fl.FullName) -Value $data
			}
		
		}
	}
}
Write-Host "Total files :" $list.Count
Write-Host "Missed file list"
$missedlist


