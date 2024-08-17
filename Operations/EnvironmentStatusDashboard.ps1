CLS

if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop	

$DateTime=Get-Date -Format "dd-MM-yyyy hh:mm:ss"
$HTMLTemplateFile=[String]::Format("{0}Notifications\Templates\EnvironmentStatusTest.html",$Global:ScriptSourcePath)
$HTMLTemplate=gc $HTMLTemplateFile
$HTMTemplateFile=[String]::Format("{0}\EnvironmentStatus.html",$global:EnvironmentHTMLReportLocation)
$SQLQuery="Select * from BIDashboard"
$Environments="DCORP","ICORP","ACORP"
$TestTypes="URLTest","MFCheck","CodedUI","SoapUISMOKETest","WindowsService","ClientCheck"
$EnvironmentStatusReportLocation=[String]::Format("{0}\EnvironmentStatus.html",$global:EnvironmentHTMLReportLocation)

ForEach($Env in $Environments){
	Write-Host "=================================================="
	Write-Host "Environment:"$Env
	Write-Host "=================================================="
	ForEach($app in $($global:EnvironmentStatusApplications)){
		Write-Host "Application Name:"$app
		Write-Host "----------------------------"
		Switch($app){
			"MyBaloiseWeb" 		{$TestTypes="URLTest"}
			"CentralDataStore"  {$TestTypes="URLTest","WindowsService"}
			"Backend" 			{$TestTypes="URLTest","WindowsService"}
			"Cleva" 			{$TestTypes="URLTest","SoapUISMOKETest","ClientCheck"}
			"NINA"				{$TestTypes="URLTest","SoapUISMOKETest"}
			"Mainframe"         {$TestTypes="MFCheck"}
			"MyBaloiseClassic"	{$TestTypes="URLTest","WindowsService","ClientCheck"}
			"TALK"				{$TestTypes="ClientCheck"}
			"EAI"				{$TestTypes="WindowsService"}
			"ESB"				{$TestTypes="WindowsService"}
		}
		ForEach($TestType in $TestTypes){
			Write-Host "Test Type:"$TestType
			#=========================================================================
			# UPDATE TEST REPORTS STATUS TO DATABASE
			#=========================================================================
			$(gci FileSystem::$global:EnvironmentHTMLReportLocation -Filter "$($env+"_"+$TestType+"_"+$app+"_")*" | sort LastWriteTime -Descending | select -First 1 ) | %{`
				$Application=$($($_.Name).split("_"))[$($($_.Name).split("_")).Length -2]
				$Environment=$($($_.Name).split("_"))[$($($_.Name).split("_")).Length -4]
				$TestType=$($($_.Name).split("_"))[$($($_.Name).split("_")).Length -3]
				$Status=$($($($_.Name).split("_"))[$($($_.Name).split("_")).Length -1]).replace(".htm","")
				UpdateEnvironmentStatusInfoToDB -Application $Application -TestType $TestType -status $Status -Environment $Environment
			}
		}
	}
}

$cmd=$(Invoke-Sqlcmd -ServerInstance $($Global:BaloiseBIDBserver) -Database $($Global:BaloiseReleaseVersionDB) -Username $($Global:BaloiseVersionDBuserid) -Password $($Global:BaloiseVersionDBuserpassword) -Query $SQLQuery)
$applications=$cmd.ApplicationName | Select -Unique
$Environments=$cmd.Environment|Select -unique
$TestTypes=$cmd.TestType|Select -unique
$DCORPOverallStatus="OK"
$ICORPOverallStatus="OK"
$ACORPOverallStatus="OK"
$GetEnvHeader=""
$Environments|%{
	$GetEnvHeader+="<TH>$_</TH>"
	}
	$AppendRow=""
	ForEach($app in $applications){
		$RowData=""
		$ApplicationTestType=$cmd| ?{$_.ApplicationName -ieq $app} | Select -Property "TestType" -unique
		$TestCount=$($ApplicationTestType.TestType).Count
		[int]$count=$TestCount
		$count=1
		ForEach($TestType in $($ApplicationTestType.TestType)){
			$Appdata="<TD rowspan='$TestCount'>$app</TD>"
			$TestStatus=""
			ForEach($env in $Environments){
				$status=$($cmd | ?{($_.Environment -ieq $env) -and ($_.ApplicationName -ieq $app) -and ($_.TestType -ieq $TestType)} | Sort DateTime -Descending| Select -First 1).Status
				$TestStatus+="<TD align='center'>$status</TD>"
				if(($env -ieq "DCORP") -and ($status -ieq "NOK")){
					$DCORPOverallStatus="NOK"
				}
				if(($env -ieq "ICORP") -and ($status -ieq "NOK")){
					$ICORPOverallStatus="NOK"
				}
				if(($env -ieq "ACORP") -and ($status -ieq "NOK")){
					$ACORPOverallStatus="NOK"
				}
			}
			if($count -gt "1"){
				$RowData+=[String]::Format("<TR><TD align='left'>$TestType</TD>{0}</TR>",$TestStatus)
			}
			else{
				$RowData+=[String]::Format("<TR>{0}<TD align='left'>$TestType</TD>{1}</TR>",$Appdata,$TestStatus)
			}
			$count++
		}
	$AppendRow+=$RowData
	}
$OverallStatus=[String]::Format("<TR><TD align='center' colspan='2'><b>Overall Status</b></TD><TD align='center'>{0}</TD><TD align='center'>{1}</TD><TD align='center'>{2}</TD></TR>",$DCORPOverallStatus,$ICORPOverallStatus,$ACORPOverallStatus)
$HeaderRow=[String]::Format("<TR><TH>Applications</TH><TH>Validation Tests</TH>{0}</TR>",$GetEnvHeader)	
$BIDashboard=[String]::Format("<TABLE class='rounded-corner'><TR><TH colspan='5'>Environment Status</TH></TR>{0}{1}{2}</TABLE>",$HeaderRow,$AppendRow,$OverallStatus)
$BIDashboard=$BIDashboard -ireplace "<TD align='center'>OK</TD>","<TD align='center' bgcolor='Green'>OK</TD>"
$BIDashboard=$BIDashboard -ireplace "<TD align='center'>NOK</TD>","<TD align='center' bgcolor='Red'>NOK</TD>"
$BIDashboard=$BIDashboard -ireplace "<TD align='center'>NA</TD>","<TD align='center' bgcolor='Orange'>NA</TD>"

$HTMLTemplate=$HTMLTemplate -ireplace "#DateTime#",$DateTime
$HTMLTemplate=$HTMLTemplate -ireplace "#StatusReport#",$BIDashboard
$HTMLTemplate|Out-File FileSystem::$HTMTemplateFile
[String]$Mailsubject="Environment Status Dashboard - DCORP, ICORP & ACORP"
SendMailWithoutAdmin -To "pankaj.kumarjha@baloise.be,uday.turumella@baloise.be" -subject $Mailsubject -body $HTMLTemplate