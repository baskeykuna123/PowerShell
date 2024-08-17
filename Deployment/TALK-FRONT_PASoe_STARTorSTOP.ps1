# Luc Mercken
# 2019-07-04
# 2019-05-22 using functions,  this with additional tests
# 2019-05-23 move agent log to save save folder , and rename it with time-stamp
# 2019-06-13 adding : $CheckService.WaitForStatus('Stopped', '00:00:05')
#            adding : check if all processes ares started after a 'start', if not we do one restart  ($Tel)
# 2019-06-20          only if the PASoe service is present , else $Tel=2  
# 2019-07-04 changes only TALKOLAP   
# 2021-02-24 TALK-FRONT
#--------------------------------------------------------------------------------------

param($Action)

if($Action -ne "-stop" -and $Action -ne "-start") {$Action= "-start"}

#--------------------------------------------------------------------------------------
#      Pacifics names,  linked process names
#--------------------------------------------------------------------------------------


$PASoes = "pasAbstractieM",
          "pasAbstractieT"
          

$ProcessNames = "Tomcat7",
                "_mproapsv",
                "java"

#--------------------------------------------------------------------------------------


$LogFile="F:\TalkDb\Scripts\Log\TALKFRONT_PASoe_" + $Action + ".txt"

if (Test-Path $LogFile) {
    remove-item $LogFile -force
}

#--------------------------------------------------------------------------------------
#                                     Logging Function
#--------------------------------------------------------------------------------------


Function LogWrite {

    param ($logString)

    $TimeStamp=(Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    $Line=$TimeStamp + "   " + $LogString

    add-content $LogFile -value $Line
}

#--------------------------------------------------------------------------------------
#                    Check active Processes and evntly Kill process
#--------------------------------------------------------------------------------------
Function Check_Process {

          LogWrite "     Check_Process" 

         foreach ($ProcessName in $ProcessNames) {
             
                 
                  $ProcessNameExe=$ProcessName + ".exe"               
                 
                  $name=get-process -name $ProcessName -ErrorAction SilentlyContinue -ErrorVariable NoProcess


                  if ($NoProcess -ne "") {
                      $Line="      Warning :  " + $NoProcess 
                      # LogWrite $Line
                      }

                  else {$Name=get-ciminstance win32_process -filter "name = '$ProcessNameExe'" | select-object -property commandline, processname, processid

                        foreach($CmdName in $Name) {
                            
                                if ($cmdname.commandline -match ($PASoe)) { 
                                    $Line="      CommandLine = " + $CmdName.commandline 
                                    LogWrite $Line 

                                    $Line="      Process id = " + $CmdName.processid
                                    LogWrite $Line
                                        
                                    get-process -Id $CmdName.processid | stop-process -force 
                                    $Line = "           Forced Kill Process : " +  $CmdName.processid
                                    LogWrite $Line
                                }
                         }
                  }

         }

}


#--------------------------------------------------------------------------------------
#         after stop move agent.log to save folder,  rename it with time-stamp
#--------------------------------------------------------------------------------------

Function MoveRenameLog {

    param ($PASoe)

    $OEfolder="E:\OpenEdge\WRK\116\"
    
    $LogFolder=$OEfolder + $PASoe + "\logs\"
    $LogName= $PASoe + ".agent.log"
    $File=$LogFolder + $LogName

    $SaveFolder=$OEfolder + "Old_Logs\"
    
    move-item Filesystem::$File -Destination $SaveFolder -force
    
    $timestamp=get-date -Format "yyyyMMdd_HHmm"
    $SaveFile=$SaveFolder + $LogName
    $RenameFile=$LogName + "_" + $TimeStamp + ".log"

    rename-item Filesystem::$SaveFile -NewName $RenameFile

}

#--------------------------------------------------------------------------------------
#                                     Stop Function
#--------------------------------------------------------------------------------------


Function Action_Stop {

     if (Get-Service -name $PASoe -ea 0) {

         $line="   Start StopWatch  :  " + $PASoe 
         LogWrite $Line

         
         $stopWatch = New-Object -TypeName System.Diagnostics.Stopwatch
         $timeSpan = New-TimeSpan -Seconds 10
         $stopWatch.Start()
	     
         DO {
                                           
               $CheckService=get-service -name $PASoe  
                                       
               if ($CheckService.status -ne "Stopped") {
              
                   $Line="   Service : " + $PASoe + "   Status : " + $CheckService.status
                   LogWrite $Line
              
                   Stop-Service -Name $PASoe -Force -WarningVariable VWarning -ErrorVariable VError
                   $CheckService.WaitForStatus('Stopped', '00:00:05')

                   if ($VWarning -ne "") {
                       $Line="       Warning : " + $VWarning
                       LogWrite $Line
                   }
                   if ($VError -ne "") {
                       $Line="       Error : " + $VError
                       LogWrite $Line
                   }
                  
                   # start-sleep -seconds 2
               }
         }
         until (($CheckService.status -IEQ "Stopped" ) -or ($stopWatch.Elapsed.Seconds -ge $timeSpan.Seconds))
        

         LogWrite "   End StopWatch "
            

         $CheckService=get-service -name $PASoe

         if ($CheckService.status -ne "Stopped") { 
             LogWrite ">>>>>  Service Not Stopped"
             $Line="       Service : " + $PASoe + "   Status : " + $CheckService.status
             LogWrite $Line 
         }

         $Line="   Service : " + $PASoe + "   Status : " + $CheckService.status
         LogWrite $Line 

         #check if indeed all the linked processes are stopped,  if not then kill these processes
         Check_Process

         MoveRenameLog $PASoe
      }
}

#--------------------------------------------------------------------------------------
#                                     Start Function
#--------------------------------------------------------------------------------------


Function Action_Start {

     param ($Tel) 

     if (Get-Service -name $PASoe -ea 0) {

         #check if indeed all the linked processes are stopped,  
         #if not then kill these processes
         #if 1 process-type is still active, then a normal start is not possible
         Check_Process


         $line="   Start StopWatch  :  " + $PASoe 
         LogWrite $Line

         $StopWatch = [diagnostics.stopwatch]::StartNew()

    	 While($StopWatch.elapsed -lt (new-timespan -seconds 18)) {
                                            
               $CheckService=get-service -name $PASoe  
                                       
               if ($CheckService.status -ne "Running") {
               
                   $Line="   Service : " + $PASoe + "   Status : " + $CheckService.status
                   LogWrite $Line
              
                   Start-Service -Name $PASoe -WarningVariable VWarning -ErrorVariable VError
                   if ($VWarning -ne "") {
                       $Line="       Warning : " + $VWarning
                       LogWrite $Line
                   }
                   if ($VError -ne "") {
                       $Line="       Error : " + $VError
                       LogWrite $Line
                   }
                  
                   # start-sleep -seconds 6
               }
         }
        

         LogWrite "   End StopWatch "
         

         $CheckService=get-service -name $PASoe

         if ($CheckService.status -ne "Running") { 
             LogWrite ">>>>>  Service Not Running"
         }

         $Line="   Service : " + $PASoe + "   Status : " + $CheckService.status
         LogWrite $Line 

         #====

         if ($CheckService.status -ieq "Running") {  
              
             foreach ($ProcessName in $ProcessNames) {
             
                      LogWrite " "
                      $ProcessNameExe=$ProcessName + ".exe"               

                      $name=get-process -name $ProcessName -ErrorAction SilentlyContinue -ErrorVariable NoProcess


                      if ($NoProcess -ne "") {
                          $Line="      Error : " + $NoProcess 
                           LogWrite $Line
                      }

                      else {$Name=get-ciminstance win32_process -filter "name = '$ProcessNameExe'" | select-object -property commandline, processname, processid

                            foreach($CmdName in $Name) {
                            
                                    if ($cmdname.commandline -match ($PASoe)) { 
                                        $Line="      CommandLine = " + $CmdName.commandline 
                                        LogWrite $Line 

                                        $Line="      Process id = " + $CmdName.processid
                                        LogWrite $Line  
                                        
                                        $Tel = $Tel + 1                                       
                              
                                    }
                            }
                      }
             }
         }

         #====
     }
     else {
           # the PASoe service is not defined on this server,  so set $tel = 2, preventing an error mesaage and a restart-trial 
           $Tel = 2
     }
     return $Tel
}

#--------------------------------------------------------------------------------------


clear 



LogWrite "======================================================================"
$Line = "Start of executing : Action = " + $Action
LogWrite $Line


#--------------------------------------------------------------------------------------
#                                     Start Division
#--------------------------------------------------------------------------------------

if ($Action -eq "-start") {

    foreach ($PASoe in $PASoes) { 

        LogWrite " "
        $Line="***  " + $PASoe + "  ***"
        LogWrite $Line

        $Tel = 0
        $Tel = Action_Start $Tel

       if ($Tel -ne 2 ) {

           LogWrite "NOT ALL PROCESSEN ARE STARTED !"
           LogWrite "WE DO A SECOND RESTART"


           $Tel = 0
           Action_Start $Tel
        }
    }
}



#--------------------------------------------------------------------------------------
#                                     Stop Division
#--------------------------------------------------------------------------------------

if ($Action -eq "-stop") {

    foreach ($PASoe in $PASoes) { 

        LogWrite " "
        $Line="***  " + $PASoe + "  ***"
        LogWrite $Line

        Action_Stop
    }
}

#--------------------------------------------------------------------------------------

LogWrite " "
LogWrite "End of executing"
LogWrite "======================================================================"

get-content $logfile 
