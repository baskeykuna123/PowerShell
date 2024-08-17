# Luc Mercken
# 2021-01-12
#
# creating a powershell script which launches parallel several other ps1 scripts
# depending on how many PASoe should be stopped or started
# see $PASoes
# 2021-10-12 : Talk and Lina Pacifics together,  
#              Start-actio : delayed start of pasWorkFlow,  
#              while stop-action all Pacifics are stopped parallel included pasWorkFlow
#              Classique Appserver integrated
#
#              pasWorkFlow : in case of 'start' this should start as latest
#                            in case of stop , can stop parallel with the others PASoe
#              asLinaT : should allways start first 
# 2021-10-27 : Function LogWrite_Host
# 2021-11-04 : Pacific folders are used instead of a fixed names-table
#
#
 


param($Action)

if($Action -ne "-stop" -and $Action -ne "-start") {$Action= "-start"}


#Scripts WorkFlowPoller Scheduler (enable, disable)
$EnableWorkFlowPoller="D:\Schedul_Scripts\Enable_WorkFlowPoller_Scheduler.ps1"
$DisableWorkFlowPoller="D:\Schedul_Scripts\Disable_WorkFlowPoller_Scheduler.ps1"


#Appservers  (OpenEdge environment, variables)
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



#Wrk folder
$PASoeHeadFolder="E:\OpenEdge\Wrk\117"

#Pacfics
$pasWorkFlow="pasWorkFlow"

$PASoes=@()
$NoPas1 = "pasLinaT"
$NoPas2 = $pasWorkFlow

get-childitem -path $PASoeHeadFolder -Directory | foreach-object { if ($_.Name -match "pas" -and $_.Name -ne $NoPas1 -and $_.Name -ne $NoPas2) 
                                                                         {$PASoes+=$_.Name }
                                                                 } 

# if STOP, then pasWorkFlow follows the normal executing stream, so added to $PASoes
if ($action -eq '-stop') {
     $PASoes+=$pasWorkFlow
} 
  
       

#Script
$GenericPS1="F:\Database_Scripts\PASoe\PASoe_Talk_Action.ps1"


#Logs
$Logfile_PAS="F:\Database_Scripts\PASoe\Log\_PASoe_Talk" + $Action + ".txt"
$Logfile_APP="F:\Database_Scripts\Appserver\Log\_Appservers" + $Action + ".txt"




#--------------------------------------------------------------------------------------
#                                      Functions
#--------------------------------------------------------------------------------------

#--------------------------------------------------------------------------------------
#     Write-Host_with_TimeStamp Function
#--------------------------------------------------------------------------------------
Function LogWrite_Host {

    param ($LogString)

    $TimeStamp=(Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    Write-Host $TimeStamp "     " $LogString
}

#--------------------------------------------------------------------------------------
#      Pacfics Logging Function
#--------------------------------------------------------------------------------------
Function LogWrite_PAS {

    param ($logString)

    $TimeStamp=(Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    $Line=$TimeStamp + "   " + $LogString

    add-content $Logfile_PAS -value $Line
}


#--------------------------------------------------------------------------------------
#      Appservers Logging Function
#--------------------------------------------------------------------------------------
Function LogWrite_APP {

    param ($logString)

    $TimeStamp=(Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    $Line=$TimeStamp + "   " + $LogString

    add-content $Logfile_APP -value $Line
}


#--------------------------------------------------------------------------------------
#      Pacfics Generic Script Function
#--------------------------------------------------------------------------------------
Function PS1Write {

    param ($PS1String)

    add-content $GenericPS1 -value $PS1String
}


#--------------------------------------------------------------------------------------
#      Appservers function
#--------------------------------------------------------------------------------------

Function Func_Appservers {

    LogWrite_APP "**********************************************************************"

    LogWrite_APP "action =    $Action "

    LogWrite_APP "**********************************************************************"


    LogWrite_APP "======================================================================"
    LogWrite_APP "Start of executing"


    #----------
    #for each appserver we execute the stop or start cmd
    foreach ($Appserver in $Appservers) { 

        LogWrite_APP " "
        LogWrite_APP "Appserver  :  $Appserver "
    
        # using OE default command file,  if exist then execute command                 
        $BatFile = $Cmd + $Appserver + "  " + $Action    
    
        if (test-path $Bin -pathtype leaf) {
        
                cmd.exe /C $Batfile

                LogWrite_APP "     Executing :     $BatFile "
                  
                start-sleep -seconds 2        
        }
 
    }


 
    #----------
    # we'll wait so giving time all processes to stop normally in case of stop-event,  or start the processes
    LogWrite_APP " "  
    LogWrite_APP " "
    LogWrite_APP "Wait 15 seconds start"
    start-sleep -seconds 15
    LogWrite_APP "Wait 15 seconds end"
    LogWrite_APP " "
    LogWrite_APP " "

    
    #----------        
    # check wether the processes related to the Appserver are running
    # in case of stop command , then kill these processes  

    foreach ($Appserver in $Appservers) { 
               
        foreach ($ProcessName in $ProcessNames) {
        
            $ProcessNameExe=$ProcessName + ".exe"   

            LogWrite_APP "        $ProcessNameExe "            

            $name=get-process -name $ProcessName -ErrorAction SilentlyContinue -ErrorVariable NoProcess


            if   ($NoProcess -ne "") {                                      
                                      #LogWrite_APP "      Error $NoProcess "
            }

            else {$Name=get-ciminstance win32_process -filter "name = '$ProcessNameExe'" | select-object -property commandline, processname, processid
                      
                  foreach($CmdName in $Name) {
                          
                      if ($cmdname.commandline -match ($Appserver)) { 

                          $Line="             CommandLine = " + $CmdName.commandline 
                          LogWrite_APP $Line

                          $Line="             Process id = " + $CmdName.processid
                          LogWrite_APP $Line

                          
                          #when STOP action then kill the related processes            
                          if ($Action -eq "-stop") {  

                              $Line="             Killing Process id = " + $CmdName.processid 
                              LogWrite_APP $Line
                                          
                              get-process -Id $CmdName.processid | stop-process -force 
                          }

                      }
                  }
            }
        }
         
    
    }

    LogWrite_APP " "
    LogWrite_APP "End of executing"
    LogWrite_APP "======================================================================"



} #Func_Appservers

#--------------------------------------------------------------------------------------


clear 

LogWrite_Host " "
LogWrite_Host " "
   
#--------------------------------------------------------------------------------------
#      Check ps1 and/or log allready exist, if so delete them
#--------------------------------------------------------------------------------------

                
if (test-path $GenericPS1) {
    LogWrite_Host ">>  Old input file is present, will be cleared : $GenericPS1 "
    remove-item -path $GenericPS1  -force -recurse -ErrorAction Ignore
}


if (test-path $Logfile_PAS) {
    LogWrite_Host ">>  Old Log file is present, will be cleared : $Logfile_PAS "  
    remove-item -path $Logfile_PAS  -force -recurse -ErrorAction Ignore
}


if (test-path $Logfile_APP) {
    LogWrite_Host ">>  Old Log file is present, will be cleared : $Logfile_APP " 
    remove-item -path $Logfile_APP  -force -recurse -ErrorAction Ignore
}




#--------------------------------------------------------------------------------------
#                                     Create Executing PS1
#--------------------------------------------------------------------------------------

LogWrite_Host " "
LogWrite_Host " "
LogWrite_Host "Start of executing"



LogWrite_PAS "======================================================================"
LogWrite_PAS "Start of executing"


LogWrite_PAS " "
LogWrite_PAS " "


PS1Write "#Action = $Action"
PS1Write " "


PS1Write " "
PS1Write "#--------------------------------------------------------------------------------------"
PS1Write " "
PS1Write "Workflow ExecuteAction {"
PS1Write " "
PS1Write "    parallel {"
PS1Write " "


foreach ($PASoe in $PASoes) { 

    LogWrite_Host "PASoe  :  $Pasoe "

    LogWrite_PAS " "
    LogWrite_PAS "PASoe  :  $PASoe "   
          
    PS1Write "             powershell.exe  -file F:\Database_Scripts\PASoe\1-PASoe_Check_Processes.ps1 -Action $Action  -Name $PASoe "               
    PS1Write "             powershell.exe  -file F:\Database_Scripts\PASoe\1-PASoe_STARTorSTOP.ps1 -Action $Action  -Name $PASoe "             
    
    PS1Write " "
    
}


PS1Write " "
PS1Write "    }"
PS1Write "}"



#--------------------------------------------------------------------------------------
# When START : pasWorkFlow has to be the last one to start,  
# so first all others in parallel then the seperate start of pasWorkFlow
#--------------------------------------------------------------------------------------

if ($Action -eq '-start') {

    LogWrite_Host "PASoe  :  $pasWorkFlow "

    PS1Write " "
    PS1Write "#--------------------------------------------------------------------------------------"
    PS1Write " "
    PS1Write "Workflow ExecuteAction-2 {"
    PS1Write " "
    PS1Write "    parallel {"
    PS1Write " "
    
    LogWrite_PAS " "
    LogWrite_PAS "PASoe  :  $pasWorkFlow "    
          
    PS1Write "             powershell.exe  -file F:\Database_Scripts\PASoe\1-PASoe_Check_Processes.ps1 -Action $Action  -Name  $pasWorkFlow "              
    PS1Write "             powershell.exe  -file F:\Database_Scripts\PASoe\1-PASoe_STARTorSTOP.ps1 -Action $Action  -Name $pasWorkFlow "              
    
    PS1Write " "
    PS1Write " "
    PS1Write "    }"
    PS1Write "}"

}

#--------------------------------------------------------------------------------------


PS1Write " "
PS1Write "#--------------------------------------------------------------------------------------"
PS1Write " "

PS1Write "clear"
PS1Write " "
PS1Write "ExecuteAction"
PS1Write " "


#--------------------------------------------------------------------------------------

if ($Action -eq '-start') {
    
    PS1Write " "
    PS1Write "#--------------------------------------------------------------------------------------"

    PS1Write " "
    PS1Write " "
    PS1Write "ExecuteAction-2"


}



#--------------------------------------------------------------------------------------
#      If exist ps1 file,  then execute 
#      Start :  first Appservers, then Paifics, then Enable Scheduler
#      Stop  :  Disable Scheduler,  stop Pacfics,  then Appservers 
#--------------------------------------------------------------------------------------

#ACTION : START
if ($Action -eq '-start') {

    LogWrite_Host "Executing START "    

    Func_Appservers

    LogWrite_Host "Executing PAS "

    
    if (test-path $GenericPS1) {
        
        LogWrite_PAS " "

        LogWrite_PAS " "
        LogWrite_PAS ">>  Generic Powershell is present : $GenericPS1 " 
        LogWrite_PAS ">>>   Executing                   : $GenericPS1 "

        powershell.exe -file $GenericPS1 -Action $Action

    }

    #enable scheduler
    if (test-path $EnableWorkFlowPoller) {

        LogWrite_Host " "
        LogWrite_Host " "
        LogWrite_Host "Enable WorkFlowPoller Scheduler "

        LogWrite_PAS " "
	    LogWrite_PAS " "
        LogWrite_PAS ">>>   Executing                   : $EnableWorkFlowPoller "

        powershell.exe -file $EnableWorkFlowPoller 

    }

    LogWrite_Host " "
    LogWrite_Host " "
    LogWrite_Host "End of START"

                
} #START




#ACTION : STOP
if ($Action -eq '-stop') {

    LogWrite_Host " "
    LogWrite_Host " "
    LogWrite_Host "Executing STOP"


    #disable scheduler
    if (test-path $DisableWorkFlowPoller) {

        LogWrite_Host " "
        LogWrite_Host " "
        LogWrite_Host "Disable WorkFlowPoller Scheduler "

        LogWrite_PAS " "
        LogWrite_PAS " "
        LogWrite_PAS ">>>   Executing                   :  $DisableWorkFlowPoller "

        powershell.exe -file $DisableWorkFlowPoller 

    }

    LogWrite_Host " "
    LogWrite_Host " "
    LogWrite_Host "Executing PAS"

    
    if (test-path $GenericPS1) {
        
        LogWrite_PAS " "

        LogWrite_PAS " "
        LogWrite_PAS ">>  Generic Powershell is present : $GenericPS1 " 
        LogWrite_PAS ">>>   Executing                   : $GenericPS1 "

        powershell.exe -file $GenericPS1 -Action $Action

    }

    LogWrite_Host " "
    LogWrite_Host " "
    LogWrite_Host "Executing Appservers"


    Func_Appservers

        
} #STOP



LogWrite_PAS " "
LogWrite_PAS ">>>   End of executing"
LogWrite_PAS "======================================================================"


LogWrite_Host " "
LogWrite_Host " "
LogWrite_Host "End of executing"
LogWrite_Host " "
LogWrite_Host " "
