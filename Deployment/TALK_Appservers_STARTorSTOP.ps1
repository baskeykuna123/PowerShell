# Luc Mercken
# 2019-05-13
# stop or start the classique appservers,  when failed to stop (after a timeout) then kill the processes related to the appserver
# 2019-08-08 exception ECorp
#--------------------------------------------------------------------------------------

param($Action)

if($Action -ne "-stop" -and $Action -ne "-start") {$Action="-start"}

#--------------------------------------------------------------------------------------


$LogFile="F:\TalkDb\Scripts\Log\Appservers_" + $Action + ".txt"

if (Test-Path $LogFile) {
    remove-item $LogFile -force
}

#--------------------------------------------------------------------------------------

Function LogWrite {

    param ($logString)

    $TimeStamp=(Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    $Line=$TimeStamp + "   " + $LogString

    add-content $LogFile -value $Line
}

#--------------------------------------------------------------------------------------

clear 


LogWrite "**********************************************************************"

$Line="action =    " + $Action
LogWrite $Line

LogWrite "**********************************************************************"


$Bin="E:\Progress\OpenEdge\116\bin\asbman.bat "
$HostName="-host localhost "
$AdmPrt="-port 20931 "

$Cmd=$Bin + $HostName + $AdmPrt + " -name "




$AppServers = "asLinaT",
              "asBackOfficeM", 
              "asBackOfficeT",
              "asBproM",
              "asBproT",
              "asOlapT"

          
          

$ProcessNames = "_proapsv",
                "java"



LogWrite "======================================================================"
LogWrite "Start of executing"

foreach ($Appserver in $Appservers) { 

    LogWrite " "
    $Line="***  " + $Appserver + "  ***"
    LogWrite $Line
    
 # using OE default command file,  if exist then execute command                 
    $BatFile = $Cmd + $Appserver + "  " + $Action
    
    
    if (test-path $Bin -pathtype leaf) {
        cmd.exe /C $Batfile

        $Line=$BatFile
        LogWrite $Line
                  
        start-sleep -seconds 5
    }
    
    
        
# check wether the processes related to the Appserver are running
# in case of stop command , then stop these processes                  
    foreach ($ProcessName in $ProcessNames) {
        
        $ProcessNameExe=$ProcessName + ".exe"   

        $Line= "        " + $ProcessNameExe
        LogWrite $Line            

        $name=get-process -name $ProcessName -ErrorAction SilentlyContinue -ErrorVariable NoProcess


        if   ($NoProcess -ne "") {
                                 # $Line="      Warning : " + $NoProcess 
                                 # LogWrite $Line
        }

        else {$Name=get-ciminstance win32_process -filter "name = '$ProcessNameExe'" | select-object -property commandline, processname, processid
                      
              foreach($CmdName in $Name) {
                          
                  if ($cmdname.commandline -match ($Appserver)) { 
                      if ($cmdname.commandline -match "eme_") { 
                          #Emergency Corp keep alive in normal DIAP,  no action required  (LME 2019/08/08)
                      }
                      else {
                            $Line="             CommandLine = " + $CmdName.commandline 
                            LogWrite $Line 

                            $Line="             Process id = " + $CmdName.processid
                            LogWrite $Line
                          
                            #when STOP action then kill the related processes            
                            if ($Action -eq "-stop") {                  
                                get-process -Id $CmdName.processid | stop-process -force 
                                $Line = "                  Forced Stop Process  " + $CmdName.processid
                                LogWrite $Line
                            }
                      }

                  }
              }
        }
    }
         
    
}

LogWrite " "
LogWrite "End of executing"
LogWrite "======================================================================"

get-content $LogFile