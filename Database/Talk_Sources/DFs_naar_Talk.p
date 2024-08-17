
/* 
   Luc Mercken
   2020/02/10
   tabel-definities opladen per db
   Df bestanden staan in een centrale directorie.
   daar ook een bestand waarin vermeld welke database en de naam van de Df
   layout bestand :
   Database locatie;database logical naam;Df bestandsnaam ;

   
*/

define variable cReleaseDir                     as character   no-undo      initial 'F:\TalkDb\DB-Schema\'.
define variable cIn_InputFile                   as character   no-undo      initial 'Input_DB_DFs.txt'.

define variable In_Lijn                         as character   no-undo.
DEFINE VARIABLE ii                              AS INTEGER     NO-UNDO.

DEFINE VARIABLE lErrorLoad                      AS LOGICAL     NO-UNDO      initial false.
DEFINE VARIABLE lLoad                           AS LOGICAL     NO-UNDO      initial false.

DEFINE VARIABLE cProgName                       AS CHARACTER   NO-UNDO.
DEFINE VARIABLE cCorp                           AS CHARACTER   NO-UNDO.


define temp-table TT_Input
            field Db_Location                   as character
            field Db_LogicName                  as character
            field Df_File                       as character
            index TT_Index      Db_Location.  

define temp-table TT_Db
            field Db_Name                       as character
            index TT_Db_Index   Db_Name.

define temp-table TT_Db_Names
            field Db_Name                       as character
            field Db_Disp_Name                  as character.

define temp-table TT_Error
            field TT_LogFile                    as character.

/* streams */ 
DEFINE VARIABLE cLogName                        AS CHARACTER   NO-UNDO      initial "Logging_Load_DFs.txt".
DEFINE VARIABLE cBat_Db_stop                    AS CHARACTER   NO-UNDO      initial "Database_Stop.bat".
DEFINE VARIABLE cBat_Db_Start                   AS CHARACTER   NO-UNDO      initial "Database_Start.bat".
DEFINE VARIABLE cInput_Names                    AS CHARACTER   NO-UNDO      initial "Talk\Corp_Db_Names.csv".
    

define stream strLog.
define stream strBat_Stop.
define stream strBat_Start.

/* ====================================================================================================== */

assign cIn_InputFile  = cReleaseDir + cIn_InputFile.

assign cLogName = cReleaseDir + cLogName.

output stream strLog to value(cLogName) unbuffered.


put stream strLog unformatted string(time,"hh:mm:ss") "  " "Start   " string(year(today),"9999") +  
                                                                      string(month(today),"99")  +  
                                                                      string(day(today),"99")       skip
                                                      "  "                                          SKIP(2).



run Proc_Read_InputFile.


if lLoad eq true
then do:
     run Proc_Db_Names.
     run Proc_Loading_Schema.
end.

put stream strLog unformatted  "  "                                                                 SKIP(2).
put stream strLog unformatted string(time,"hh:mm:ss") "  " "Stop    " string(year(today),"9999") +  
                                                                      string(month(today),"99")  +  
                                                                      string(day(today),"99")       skip.


if lErrorLoad eq true
then do:

     put stream strLog unformatted  "  "                            SKIP(2)
                                    "  " "***   LOAD ERRORS   ***"  skip.

     for each TT_error :
         put stream strLog unformatted  "  " TT_LogFile skip.
     end.

end. /* lErrorLoad eq true */


output stream strLog close.


QUIT.

/* ====================================================================================================== */

procedure Proc_Read_InputFile.

    input from value(cIn_InputFile).

    repeat :
        import unformatted In_Lijn.

        if index(In_Lijn,"rem") ne 0
        then next.

        if index(In_Lijn,"Corp") ne 0
        then do:
             assign cCorp = string(entry(1,in_Lijn, ";")).
        end.
        else do:

             create TT_Input.
             assign TT_Input.Db_Location   = string(entry(1,In_Lijn, ";"))
                    TT_Input.Df_File       = string(entry(2,In_Lijn, ";")).
    
    
             assign ii = num-entries(TT_Input.Db_Location, "\").
             assign TT_Input.Db_LogicName = entry(ii, TT_Input.Db_Location, "\")
                    TT_Input.Db_logicName = entry(1, TT_Input.Db_logicName, ".").
    
    
             find first TT_Db no-lock
                  where TT_Db.Db_Name eq TT_Input.Db_LogicName
                        no-error.
             if not available TT_Db
             then do:
                  create TT_Db.
                  assign TT_Db.Db_Name = TT_Input.Db_LogicName.
             end.

        end. /* else do */
    end. /* repeat */

    input close.
    
    for each TT_Input :
        put stream strLog unformatted string(time,"hh:mm:ss") "  ** FILE ** " TT_Input.Df_File skip.
        assign lLoad = true.
    end.

end procedure. /* Proc_Read_InputFile */

/* ------------------------------------------------------------------------------------------------------ */

procedure Proc_Loading_Schema.

    DEFINE VARIABLE cUser           AS CHARACTER   format "x(10)" NO-UNDO.
    DEFINE VARIABLE cPasw           AS CHARACTER   format "x(40)" NO-UNDO.
    DEFINE VARIABLE cFileName       AS CHARACTER   NO-UNDO.
    DEFINE VARIABLE cErrorFile      AS CHARACTER   NO-UNDO.
    DEFINE VARIABLE strLogFile      AS CHARACTER   NO-UNDO.


    put stream strLog unformatted string(time,"hh:mm:ss") "  "               skip
                                  string(time,"hh:mm:ss") "  "               skip
                                  string(time,"hh:mm:ss") "  START LOADING " skip
                                  string(time,"hh:mm:ss") "  "               skip.


    run Proc_Stop_Databases.    /* Stop Database */


    for each TT_Input
        break by TT_Input.Db_Location :

        if first-of(TT_Input.Db_Location) /* database connection */
        then do:

             put stream strLog unformatted string(time,"hh:mm:ss") "  Database Connection  >> " TT_Input.Db_LogicName skip.

             if TT_Input.Db_LogicName eq "Talkcore"
             or TT_Input.Db_LogicName eq "Talkmig"
             or TT_Input.Db_LogicName eq "Mercator"
             or TT_Input.Db_LogicName eq "Stddb"
             or TT_Input.Db_LogicName eq "Wldb"
             then do:
                  assign cUser = "ptchld"
                         cPasw = "TalkAce58".
                  
                  connect value(TT_Input.Db_Location) -1 -U value(cUser) -P value(cPasw).
                  
             end.
             else connect value(TT_Input.Db_Location) -1.
        end.

        PAUSE 2 NO-MESSAGE.  /* 5 seconden wachten tussen iedere load file */
        put stream strLog unformatted string(time,"hh:mm:ss") "  "                             skip
                                      string(time,"hh:mm:ss") "   > " TT_Input.Df_file 
                                                              "   >>>   "
                                                              TT_Input.Db_Location             skip.

        assign cFileName = replace(cFileName, "/", "\")
               cFileName = entry(2, DF_File, ":")
               cFileName = entry(num-entries(cFileName, "\"), cFileName, "\")
               cFileName = entry(1,cFileName, ".").
        

        assign cProgName = cReleaseDir + "Talk\DFFile_Load.p".  /* Schema load */


        run value(cProgName) (input TT_Input.Db_LogicName,
                              input TT_Input.Df_File,
                              input cReleaseDir,
                              input cFileName,
                              output cErrorFile,
                              output strLogFile).

        if cErrorFile ne ? /* return value from  prodict\load_df_silent.p  */
        then do:
             put stream strLog unformatted string(time,"hh:mm:ss") "  " "          =================================================================================== " skip.
             put stream strLog unformatted string(time,"hh:mm:ss") "  " "          ERRORS DURING LOAD !!! "                                                              skip
                                           string(time,"hh:mm:ss") "  " "          Log       : " strLogFile                                                              skip
                                           string(time,"hh:mm:ss") "  " "          ErrorFile : " TT_Input.Df_File                                                        skip.
             
             run Proc_Get_ErrorLog (input strLogFile).

             put stream strLog unformatted string(time,"hh:mm:ss") "  " "          =================================================================================== " skip.

             assign lErrorLoad = yes.

             create TT_Error.
             assign TT_LogFile = strLogFile.
        end.

        if last-of(TT_Input.Db_Location)    /* disconnect from database */
        then do:
             assign cProgName = cReleaseDir + "Talk\Disconnect.p".
             run value(cProgName) (input TT_Input.Db_LogicName).
             put stream strLog unformatted string(time,"hh:mm:ss") "  " skip
                                           string(time,"hh:mm:ss") "  " skip
                                           string(time,"hh:mm:ss") "  " skip.   
        end.

    end.


    run Proc_Start_Databases.   /* Start Database */

end procedure. /* Proc_Loading_Schema */

/* ------------------------------------------------------------------------------------------------------ */

procedure Proc_Get_ErrorLog.

    define input parameter strLogFileName   as character.
    DEFINE VARIABLE cLine                   AS CHARACTER   NO-UNDO.


    input from value (strLogFileName).


    repeat:
        import unformatted cLine.

        put stream strLog unformatted string(time,"hh:mm:ss") "  " "               " cLine skip.

    end.

end procedure. /* Proc_Get_ErrorLog */


/* ------------------------------------------------------------------------------------------------------ 
   creating generic bat files : stop and start databases using dbman utility,  with logging file
   extra line forseen if talkcore database,  T and M base
*/

procedure Proc_Stop_Databases.

    DEFINE VARIABLE cLocation               AS CHARACTER   NO-UNDO.
    DEFINE VARIABLE cDb_Disp_Name           AS CHARACTER   NO-UNDO.


    assign cBat_Db_Stop = cReleaseDir + cBat_Db_Stop.
    output stream strBat_Stop to value(cBat_Db_Stop) unbuffered.

    assign cBat_Db_Start = cReleaseDir + cBat_Db_Start.
    output stream strBat_Start to value(cBat_Db_Start) unbuffered.


    put stream strBat_Stop unformatted "Set probin=E:\Progress\OpenEdge\116\bin"                 skip
                                       "call %probin%\proenv psc"                                skip
                                       " "                                                       skip (2)
                                       "set logfile=F:\TalkDb\Db-Schema\Log_Db_Stop.txt"         skip
                                       " "                                                       skip (2)
                                       "echo Stop Procedure Beginning %date% %time%  >%logfile%" skip
                                       " "                                                       skip (2).



    put stream strBat_Start unformatted "Set probin=E:\Progress\OpenEdge\116\bin"                  skip
                                        "call %probin%\proenv psc"                                 skip
                                        " "                                                        skip (2)
                                        "set logfile=F:\TalkDb\Db-Schema\Log_Db_Start.txt"         skip
                                        " "                                                        skip (2)
                                        "echo Start Procedure Beginning %date% %time%  >%logfile%" skip
                                        " "                                                        skip (2).

    /* */
    for each TT_Db :

        find first TT_Db_Names 
             where TT_Db_Names.Db_Name eq TT_Db.Db_Name
                   no-error.

        if available TT_Db_Names
        then do:
             put stream strBat_Stop  unformatted "call %probin%\dbman -host localhost -port 20931 -stop -database "   TT_Db_Names.Db_Disp_Name "    >>%logfile%" skip. 
             put stream strBat_Start unformatted "call %probin%\dbman -host localhost -port 20931 -start -database "  TT_Db_Names.Db_Disp_Name "    >>%logfile%" skip. 

             if TT_Db_Names.Db_Name eq "talkcore" /* extra Talkcore_M */
             then do:

                  assign cDb_Disp_Name = TT_Db_Names.Db_Disp_Name + "_M".

                  put stream strBat_Stop  unformatted "call %probin%\dbman -host localhost -port 20931 -stop -database "   cDb_Disp_Name "    >>%logfile%" skip. 
                  put stream strBat_Start unformatted "call %probin%\dbman -host localhost -port 20931 -start -database "  cDb_Disp_Name "    >>%logfile%" skip. 

                  
             end.
        end.

    end. /* each TT_Db*/

    put stream strBat_Stop  unformatted " "                                         skip
                                        " "                                         skip
                                        ":WAIT"                                     skip     
                                        "ping -n 20 127.0.0.1 >nul"                 skip
                                        "echo waiting  %date% %time%  >>%logfile%"  skip 
                                        " "                                         skip
                                        " "                                         skip.
    /* Lock file of database */
    for each TT_Input
        break by TT_Input.Db_Location :

        if first-of(TT_Input.Db_Location)
        then do:
             assign cLocation = TT_Input.Db_Location
                    cLocation = replace(cLocation, ".db", ".lk").

             put stream strBat_Stop unformatted "if exist " cLocation " goto WAIT" skip.
        end.

    end.
    /* */

    put stream strBat_Stop  unformatted " "                                       skip
                                        "echo Exit  %date% %time%    >>%logfile%" skip 
                                        "exit"                                    skip.
    put stream strBat_Start unformatted " "                                       skip
                                        "echo Exit  %date% %time%    >>%logfile%" skip 
                                        "exit"                                    skip.


    output stream strBat_Stop  close.
    output stream strBat_Start close.


    os-command value(cBat_Db_Stop).

end procedure. /* Proc_Stop_Databases. */

/* ------------------------------------------------------------------------------------------------------ */

procedure Proc_Start_Databases.

    os-command value(cBat_Db_Start).

end procedure. /* Proc_Start_Databases. */

/* ------------------------------------------------------------------------------------------------------ */

procedure Proc_Db_Names.

    assign cInput_Names = cReleaseDir + cInput_Names.

    input from value(cInput_names).

    repeat:
        import unformatted In_Lijn.

        create TT_Db_Names.
        case cCorp:
            when "Icorp" then assign TT_Db_Names.Db_name      = entry(1, in_Lijn, ";")
                                     TT_Db_Names.Db_Disp_Name = entry(2, in_Lijn, ";").


            when "Acorp" then assign TT_Db_Names.Db_name      = entry(1, in_Lijn, ";")
                                     TT_Db_Names.Db_Disp_Name = entry(3, in_Lijn, ";").


            when "Pcorp" then assign TT_Db_Names.Db_name      = entry(1, in_Lijn, ";")
                                     TT_Db_Names.Db_Disp_Name = entry(4, in_Lijn, ";").
        end case.
    end.

end procedure. /* Proc_Db_Names */
