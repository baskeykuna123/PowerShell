# Luc Mercken
# 2020-01-29
# 
# Actions Stop or Start  foe one PASoe
# Parameters :  $Action   (Stop, Start)
#               $Name     name of the PASoe
# 
# 2020-12-28 : changes to OE117 Version
# 2021-02-10 : creating a powershell script which launches parallel several other ps1 scripts
#              similar as talk_pasoe_startorstop,  but restricted to 1 pasoe as input parameter $Name
# 
#--------------------------------------------------------------------------------------

param($Action,$Name)

if($Action -ne "-stop" -and $Action -ne "-start") {$Action= "-start"}

#--------------------------------------------------------------------------------------
#      Pacifics names,  linked process names
#--------------------------------------------------------------------------------------


$PASoes = $Name
          

$LogFile="F:\Database_Scripts\PASoe\Log\_Pacific_" + $Name + ".txt"
$GenericPS1="F:\Database_Scripts\PASoe\Pacific_" + $Name + "_Action.ps1"

#--------------------------------------------------------------------------------------
#                                      Functions
#--------------------------------------------------------------------------------------


Function LogWrite {

    param ($logString)

    $TimeStamp=(Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    $Line=$TimeStamp + "   " + $LogString

    add-content $LogFile -value $Line
}


Function PS1Write {

    param ($PS1String)

    add-content $GenericPS1 -value $PS1String
}

#--------------------------------------------------------------------------------------

clear 

   
#--------------------------------------------------------------------------------------
#      Check ps1 and/or log allready exist, if so delete them
#--------------------------------------------------------------------------------------

                
if (test-path $GenericPS1) {
    write-host ">>  Old input file is present, will be cleared : " $GenericPS1  
    remove-item -path $GenericPS1  -force -recurse -ErrorAction Ignore
}

if (test-path $LogFile) {
    write-host ">>  Old Log file is present, will be cleared : " $LogFile  
    remove-item -path $LogFile  -force -recurse -ErrorAction Ignore
}


#--------------------------------------------------------------------------------------
#                                     Create Executing PS1
#--------------------------------------------------------------------------------------

LogWrite "======================================================================"
LogWrite "Start of executing"


LogWrite " "
LogWrite " "

$Line="param($" +"Action)"
PS1Write $Line
PS1Write " "
$Line="if(" + "$" + "Action" + " -ine "+ "'-stop'" + " -and " + "$" + "Action" + " -ine " + "'-start'" + ") " + "{$" + "Action= " + "-start" + "}"
PS1Write $Line
#PS1Write "if($Actions -ne "-stop" -and $Actions -ne "-start") {$Actions= "-start"}"
PS1Write " "
PS1Write " "
PS1Write "Workflow ExecuteAction {"
PS1Write " "
PS1Write "    parallel {"
PS1Write " "


foreach ($PASoe in $PASoes) { 

    LogWrite " "
    $Line="PASoe  :  " + $PASoe
    LogWrite $Line
        
             
    $Line = "             powershell.exe  -file F:\Database_Scripts\PASoe\1-PASoe_Check_Processes.ps1 -Action " + $Action + " -Name " + $PASoe
    PS1Write $Line               
             
    $Line = "             powershell.exe  -file F:\Database_Scripts\PASoe\1-PASoe_STARTorSTOP.ps1 -Action " + $Action + " -Name " + $PASoe
    PS1Write $Line               
    
    PS1Write " "
}


PS1Write " "
PS1Write "    }"
PS1Write "}"



PS1Write " "
PS1Write " "

PS1Write "clear"
PS1Write " "
PS1Write "ExecuteAction"
PS1Write " "

#--------------------------------------------------------------------------------------
#      If exist ps1 file,  then execute 
#--------------------------------------------------------------------------------------

if (test-path $GenericPS1) {
        
    LogWrite " "

    LogWrite " "
    $Line=">>  Generic Powershell is present : " + $GenericPS1  
    LogWrite $Line  

    $Line=">>>   Executing                   : " + $GenericPS1 
    LogWrite $Line

    powershell.exe -file $GenericPS1 -Action $Action

}


LogWrite " "
LogWrite ">>>   End of executing"
LogWrite "======================================================================"

