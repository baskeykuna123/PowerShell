$ReplacementString=@{
"sql-bea1-as1201.balgroupit.com\as1201,30201" = "SQL-BE-MyBalA.balgroupit.com";		
"sql-bea1-as1203.balgroupit.com\as1203,30203" = "SQL-BE-PortalA.balgroupit.com";		
"sql-bea1-as1205.balgroupit.com\as1205,30205"= "SQL-BE-MyBalPuA.balgroupit.com";		
"sql-bea1-as1206.balgroupit.com\as1201,30206"="SQL-BE-BabeA.balgroupit.com"		
"\\sql-bea1-work\"="\\sql-bed4-Work\"		
} 



$SearchLocation=@"
Awebfm03=E$\Baloise\
Awebfm04=E$\Baloise\
Awebfm03=E$\Mercator\
Awebfm04=E$\Mercator\
"@


$missedlist=@()
$list=@()
$filelist=@()
$filecount=0

clear
$testSearchpattern="sql-bea"
$filefilter=@("*.config","*.ps1","*.bat","*.xml")
$SearchLocation | %{$_.Split("`r`n")} | where {-not [string]::IsNullOrEmpty($_)} | foreach {
	$SerachBasepath=[string]::Format("\\{0}\{1}",$_.Split('=')[0],$_.Split('=')[1])
	if(Test-Path $SerachBasepath){
		write-host "Search Path :" $SerachBasepath
		$filelist=get-childitem $SerachBasepath -file -Include  $filefilter -recurse  -Force | Select-String -Pattern $testSearchpattern -SimpleMatch -List | Select-Object -Unique Path
		
		foreach($fl in $filelist){
			$data=Get-Content -Path $fl.Path
			$originalData=$data
			$ReplacementString.GETENUMERATOR() | ForEach-Object {
				$serachtext=[Regex]::Escape($_.key)
				Write-Host "Search TExt :" $_.key
				$data=$data -replace $serachtext,$_.value 
			}
			if($originalData -ieq $data){
				Write-Host "Missed Replace for file :" $fl.Path 
				$missedlist+=$fl.Path
			}else {
				Write-Host "File updated :"  (split-path  $fl -Leaf)
				$list+=$fl.Path
				Set-Content -Path $fl.Path -Value $data
			}
		
		}
	}
}
Write-Host "Total files :" $list.Count
Write-Host "Missed file list"
$missedlist


