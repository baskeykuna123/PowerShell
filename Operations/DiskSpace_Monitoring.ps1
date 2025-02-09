Clear-Host;

if(Get-Module -name LoadFunctions){
	Remove-Module LoadFunctions
}
$ScriptDirectory=split-path (split-path $MyInvocation.MyCommand.Definition -Parent) -parent 
Import-Module "$ScriptDirectory\LoadFunctions.psm1" -DisableNameChecking -Force -ErrorAction Stop

$HTMLFile=[String]::Format("{0}Notifications\Templates\DiskSpace_Status.html",$Global:ScriptSourcePath)
$htmFile=[String]::Format("{0}\DiskSpace.htm",$global:EnvironmentHTMLReportLocation)
$EnvironmentXML="\\balgroupit.com\appl_data\BBE\Transfer\Packages\Scripts\InputParameters\Environments.xml"
$xml=[xml](Get-Content FileSystem::$EnvironmentXML)
$Envs=$xml.Environments.Environment
$Subject="Baloise Disk Space Report - $(GET-DATE -f dd/MM/yyyy)"

#ForEach($Env in $Envs){
#	ForEach($item in $($Env.ChildNodes)){
		$ServerNames=$item.SERVER.Name
		$ServerNames="SVW-BE-BABBP001.balgroupit.com","SVW-BE-BABBP002.balgroupit.com","SVW-BE-BABSP001.balgroupit.com","SVW-BE-BABSP002.balgroupit.com","SVW-BE-WEBFP001.balgroupit.com","SVW-BE-WEBFP002.balgroupit.com","SVW-BE-WEBFP003.balgroupit.com","SVW-BE-WEBFP004.balgroupit.com","SVW-BE-NINAP001.balgroupit.com","SVW-BE-NINAP002.balgroupit.com","svw-be-tlkbp001.balgroupit.com","svw-be-tlkcp001.balgroupit.com","svw-be-tlkcp002.balgroupit.com","svw-be-mftp001.balgroupit.com","svw-be-mftp002.balgroupit.com","svw-be-bizp001.balgroupit.com","svw-be-bizp002.balgroupit.com","svw-be-bizp003.balgroupit.com","svw-be-bizp004.balgroupit.com","svw-be-eaip01.balgroupit.com","svw-be-eaip04.balgroupit.com","svw-be-eaip05.balgroupit.com","svw-be-webp02.balgroupit.com","svw-be-webp03.balgroupit.com"
		$DiskReports=""
		ForEach($Server in $ServerNames){
			if($Server -ilike "*.balgroupit.com"){
				$DiskReport="<TABLE class='rounded-corner'>"
				$DiskReport+="<TR align=center><TH colspan='5'>$($Server)</TH></TR>"
				$DiskReport+="<TR align=center><TH><B>DeviceID</B></TH><TH><B>FreeSpace(GB)</B></TH><TH><B>Size(GB)</B></TH><TH><B>USED(GB)</B></TH><TH><B>Free(%)</B></TH></TR>"
				$DiskSpaceINFO=Get-WmiObject -Class Win32_LogicalDisk -Filter "DriveType = '3'" -ComputerName $Server -ErrorAction SilentlyContinue
				ForEach($info in $DiskSpaceINFO){
					$Freespace=([MATH]::Round($info.Freespace /1GB,2))
					$Size=([MATH]::Round($info.Size /1GB,2))
					$FreeSpacePercent=[MATH]::Round(($Freespace/$Size)*100)
					[float]$Used = $Size-$Freespace
					$info | Ft DeviceID,DriveType,`
					@{Name="Free Space(GB)";Expression={$Freespace}},
					@{Name="Size(GB)";Expression={$Size}},
					@{Name="Used(GB)";Expression={$Used}},
					@{Name="Free Space(%)";Expression={$FreeSpacePercent}}
					$bgcolor=""
					$DriveLetter=$($info.DeviceID) -ireplace ":",""
					if([int]$Freespace -lt '10'){
						$bgcolor='Red'
						$mailAlert=@"
							Dear Colleagues,
							<BR></BR>
							This is to inform you that  <b>"$DriveLetter"</b>  drive on server  <b>"$Server"</b>  has only <b>"$Freespace"GB</b> of space left.<BR>
							Kindly check.
							<BR></BR>
							<b><i>Warm Regards</i></b><BR>
							Build&Install Team.
"@
					SendMailWithoutAdmin -To "shivaji.pai@baloise.be,pankaj.kumarjha@baloise.be,uday.turumella@baloise.be" -subject "Disk Space Alert - $Server" -body $mailAlert
						
					}
					
					$DiskReport+="<TR><TD>$($info.DeviceID)</TD><TD align=center bgcolor=$bgcolor>$Freespace</TD><TD align=center>$Size</TD><TD align=center>$Used</TD><TD align=center>$FreeSpacePercent</TD></TR>"	
				}
				$DiskReport+="</TABLE>"	
				$DiskReports+=$DiskReport
			}
		}
#	}
#}
$HTMLBody = [system.IO.File]::ReadAllLines($HTMLFile)
$HTMLBody = $HTMLBody -ireplace "#DISKSPACEINFO#",$DiskReports
$HTMLBody | Out-File Filesystem::$htmFile
SendMailWithoutAdmin -To "pankaj.kumarjha@baloise.be,uday.turumella@baloise.be,Shivaji.pai@baloise.be" -subject $Subject -body ([string]$HTMLBody)