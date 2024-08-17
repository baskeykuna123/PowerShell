$MailList="Shivaji.pai@Baloise.be"

$Checklist=@{
"sql-be-mybalp.balgroupit.com"="1433";
"nlb-be-psoagwi.balgroupit.com"="6002";
}

Clear

$connectionInfo=""
$Checklist.keys | foreach {
$server=$_
$port=$Checklist.Item($_)
        $Socket = New-Object Net.Sockets.TcpClient
        $ErrorActionPreference = 'SilentlyContinue'
        # Try to connect
        $Socket.Connect($server, $Port)
        $ErrorActionPreference = 'Continue'

        # Determine if we are connected.
        if ($Socket.Connected) {
            $connectionInfo+="${server}:$Port -SUCCESSFUL`r`n"
            $Socket.Close()
        }
        else {
            $connectionInfo+="${server}:$Port -FAILED `r`n"  
        }
        # Apparently resetting the variable between iterations is necessary.
        $Socket = $null
		
}
Send-MailMessage -subject "Connection Test Results" -To $MailList -From "ConnectionTester@baloise.be" -SmtpServer "smtp.baloisenet.com" -Body $connectionInfo