# Luc Mercken
# 2019-03-28
# stop or start the classique appservers,  when failed to stop (after a timeout) then kill the processes related to the appserver
# 2021-01-14 : adding info

#--------------------------------------------------------------------------------------

param($Action)

if($Action -ine "-stop" -and $Action -ine "-start") {$Action="-start"}
#--------------------------------------------------------------------------------------

$LogFile="F:\Database_Scripts\Appserver\Log\Appservers" + $Action + ".txt"

Function LogWrite {

    param ($logString)

    $TimeStamp=(Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    $Line=$TimeStamp + "   " + $LogString

    add-content $LogFile -value $Line
}

#--------------------------------------------------------------------------------------

clear 

#--------------------------------------------------------------------------------------
#      Check cmd and/or log allready exist, if so delete them
#--------------------------------------------------------------------------------------

if (test-path $LogFile) {    
    remove-item -path $LogFile  -force -recurse -ErrorAction Ignore
}


LogWrite "**********************************************************************"

$Line="action =    " + $Action
LogWrite $Line

LogWrite "**********************************************************************"




#-----------
#OpenEdge environment, variables

$Bin="E:\Progress\OpenEdge\117\bin\asbman.bat "
$HostName="-host localhost "
$AdmPrt="-port 20931 "

#Command line 
$Cmd=$Bin + $HostName + $AdmPrt + " -name "



#Appserver names
$AppServers = "asLinaT",
              "asTBackOffice",
              "asMBackOffice",
              "asTBpro",
              "asMBpro",
              "asOlapT"

          
          
#Process names, used by appservers
$ProcessNames = "_proapsv",
                "java"



LogWrite "======================================================================"
LogWrite "Start of executing"


#----------
#for each appserver we execute the stop or start cmd
foreach ($Appserver in $Appservers) { 

    LogWrite " "
    $Line="Appserver  :  " + $Appserver
    LogWrite $Line
    
    # using OE default command file,  if exist then execute command                 
    $BatFile = $Cmd + $Appserver + "  " + $Action
    
    
    if (test-path $Bin -pathtype leaf) {
        
            cmd.exe /C $Batfile

            $Line="     Executing :     " + $BatFile
            LogWrite $Line
                  
            start-sleep -seconds 2        
    }
 
}


 
#----------
# we'll wait so giving time all processes to stop normally in case of stop-event,  or start the processes
LogWrite " "  
LogWrite " "
LogWrite "Wait 15 seconds start"
start-sleep -seconds 15
LogWrite "Wait 15 seconds end"
LogWrite " "
LogWrite " "

    
#----------        
# check wether the processes related to the Appserver are running
# in case of stop command , then kill these processes  

foreach ($Appserver in $Appservers) { 
               
    foreach ($ProcessName in $ProcessNames) {
        
        $ProcessNameExe=$ProcessName + ".exe"   

        $Line= "        " + $ProcessNameExe
        LogWrite $Line            

        $name=get-process -name $ProcessName -ErrorAction SilentlyContinue -ErrorVariable NoProcess


        if   ($NoProcess -ne "") {
                                  $Line="      Error " + $NoProcess 
                                  #LogWrite $Line
        }

        else {$Name=get-ciminstance win32_process -filter "name = '$ProcessNameExe'" | select-object -property commandline, processname, processid
                      
              foreach($CmdName in $Name) {
                          
                  if ($cmdname.commandline -match ($Appserver)) { 
                      $Line="             CommandLine = " + $CmdName.commandline 
                      LogWrite $Line 

                      $Line="             Process id = " + $CmdName.processid
                      LogWrite $Line

                          
                      #when STOP action then kill the related processes            
                      if ($Action -eq "-stop") {  

                          $Line="             Killing Process id = " + $CmdName.processid 
                          LogWrite $Line
                                          
                          get-process -Id $CmdName.processid | stop-process -force 
                      }

                  }
              }
        }
    }
         
    
}

LogWrite " "
LogWrite "End of executing"
LogWrite "======================================================================"

