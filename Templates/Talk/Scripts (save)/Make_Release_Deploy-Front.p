/*         extra files ook apart te stockeren           */


/*
Luc Mercken
2019-12-26

Automated release and deployment of object out of RoundTable Front

Input parameters : Deployment folder (path)     (cRelease_Directory)
                   Deployment/Release Number    (cRelease_Version)  
 
 
Proc_Session_Parameters_Input :
                   
Proc_cWorkSpace : get info where the sources RTB_ICorp are physically located on the server-disks

Proc_WorkSpace_Get_Counter : latest used event-id  (RTB_ICorp) is saved in variable

Proc_Create_Release : a new RTB_Release record is created, updated with latest used event-id counter

Proc_Create_Deploy : a new RTB_Deploy record is created (WIP) , updated with the new release number
                     previous deploy status is set to Completed
                     
Proc_Execute_Deployment : All objects in table RTB_Hist which have an event-id (RTB_ICorp)  between the previous release and the new release
                          the folder structure is created in the release destination folder (depending object)
                          the object is copied from the Icorp RTB (on disk) to the release destination (sub)folder
                          extra information about related task is gathered
                          
Proc_Report_Overview : Create a report of the current release,  report is placed in the the release folder
                       - Overview all tasks included (details)
                       - Overview all objects included (details)
                       - Overview all programmers involved (details)
                       - Overview all (sub) folders used and their objects
                       - Overview all code/program subtypes and their objects
                       - Summary release and possible remarks on the occurence of special file types  
                       
Db schema changes are reported,  but the actual Db-schema file should be delivered by the development team                                                                     
                   
*/

DEFINE VARIABLE cRelease_Version            AS CHARACTER   NO-UNDO.          /* input via sysparam (menu.pf) !*/
DEFINE VARIABLE cRelease_Directory          AS CHARACTER   NO-UNDO.          /* input via sysparam (menu.pf) !*/

/* ===================================================================================== */

/* BUFFERS */
define buffer buf_RTB_WsCount for rtb_wscount.
define buffer buf_RTB_Release for rtb_release.
define buffer new_RTB_Release for rtb_release.
define buffer buf_RTB_Deploy  for rtb_deploy.
define buffer new_RTB_Deploy  for rtb_deploy.
define buffer buf_RTB_Hist    for rtb_hist.
define buffer buf_RTB_Hist_D  for rtb_hist.
define buffer buf_RTB_Wspace  for rtb_wspace.
define buffer buf_RTB_Pname   for rtb_pname.
define buffer buf_RTB_Path    for rtb_path.
define buffer buf_RTB_Task    for rtb_task. 
define buffer buf_RTB_Ver     for rtb_ver.
define buffer buf_RTB_User    for rtb._user. 


/* ===================================================================================== */
DEFINE VARIABLE cWorkSpace_D                AS CHARACTER   NO-UNDO   initial "DCORP".  
DEFINE VARIABLE cWorkSpace                  AS CHARACTER   NO-UNDO   initial "ICORP".
DEFINE VARIABLE cJenkins                    AS CHARACTER   no-undo   initial "Jenkins".

DEFINE VARIABLE cBI_Server_Path             AS CHARACTER   NO-UNDO   initial "E:\DEV\Talk3WS\ICORP".
DEFINE VARIABLE cBI_Server_Name             AS CHARACTER   no-undo   initial "SVW-BE-TLKBP001".
DEFINE VARIABLE cServerName                 AS CHARACTER   NO-UNDO.
DEFINE VARIABLE lBI                         AS LOGICAL     no-undo   initial false.
DEFINE VARIABLE lSubType                    AS LOGICAL     NO-UNDO.
DEFINE VARIABLE lDbSchema                   AS LOGICAL     NO-UNDO   initial false.


DEFINE VARIABLE Actual_Event-counter        AS INT64       NO-UNDO.
DEFINE VARIABLE Previous_Event-counter      AS INT64       NO-UNDO.
DEFINE VARIABLE isd                         AS INTEGER     NO-UNDO.


DEFINE VARIABLE cRelease_Xtr_Dir            AS CHARACTER   NO-UNDO.
DEFINE VARIABLE cRelease_Rep_Dir            AS CHARACTER   NO-UNDO.
DEFINE VARIABLE cGeneral_Directory          AS CHARACTER   NO-UNDO.
DEFINE VARIABLE cProgName                   AS CHARACTER   NO-UNDO.
DEFINE VARIABLE cSub_Directory              AS CHARACTER   NO-UNDO.
DEFINE VARIABLE cNew_Directory              AS CHARACTER   NO-UNDO.
DEFINE VARIABLE cCopy_From                  AS CHARACTER   NO-UNDO.


define stream strReport.
DEFINE VARIABLE cReport                     AS CHARACTER   NO-UNDO.


define temp-table tt_Hist
            field tt_Object             as character
            field tt_Obj-Type           as character
            field tt_Sub-Type           as character
            field tt_Pmod               as character
            field tt_Version            as integer
            field tt_Change-Date        as date
            field tt_User-Id            as character
            field tt_Event-Counter      as int64
            field tt_Task-Num           as integer
            field tt_Programmer         as character
            field tt_Programmer-Name    as character
            field tt_Latest-Version     as logical
            index tt_Ind1   tt_Task-Num
            index tt_Ind2   tt_Programmer
                            tt_Task-Num
            index tt_Ind3   tt_Object
            index tt_Ind4   tt_Sub-Type 
                            tt_Object
            index tt_Ind5   tt_Pmod
                            tt_Object
            .


/* ===================================================================================== */

RUN Proc_Session_Parameters_Input.

run Proc_cWorkSpace.

run Proc_WorkSpace_Get_Counter.

run Proc_Create_Release.

run Proc_Create_Deploy.

run Proc_Execute_Deployment.

run Proc_Report_Overview.

output stream strReport close.

quit.

/* ------------------------------------------------------------------------------------- */
/*
Getting input :  Release directory location (Main)
                 Release number
*/
PROCEDURE Proc_Session_Parameters_Input.

    DEFINE VARIABLE iEntry  AS INTEGER     NO-UNDO.
    DEFINE VARIABLE cEntry  AS CHARACTER   NO-UNDO.


    do iEntry = 1 to num-entries(session:parameter):
            cEntry = entry(iEntry,session:parameter).
            if cEntry begins "RelDir="    THEN cRelease_Directory  = entry(2,cEntry,"=").
            if cEntry begins "RelNum="    THEN cRelease_Version    = entry(2,cEntry,"=").
    end.

    assign cRelease_Xtr_Dir   = cRelease_Directory
           cRelease_Directory = cRelease_Directory + "\" + cRelease_Version
           cRelease_Rep_Dir   = cRelease_Directory.
    

END PROCEDURE. /* Proc_Session_Parameters_Input */


/* ------------------------------------------------------------------------------------- */
/*
   get the info where all programs and elements are stored on disk
   there is a different path depending running this script on development-server or build-and-install server
*/
procedure Proc_cWorkSpace.

    assign cServerName = OS-GETENV("COMPUTERNAME").

    if cServerName eq  cBI_Server_name
    then assign cGeneral_Directory = cBI_Server_Path
                lBI                = true.            /* on Build&Install server we have to use a fixed pathname */
    else do:                                                    /* on Dev server we can use data from RTB itself */
         find first buf_RTB_Wspace no-lock
              where buf_RTB_Wspace.wspace-id eq cWorkSpace
                    no-error.
         if available buf_RTB_Wspace
         then assign cGeneral_Directory = entry(1,buf_RTB_Wspace.wspace-path, ",").
    end.

end procedure. /* Proc_cWorkSpace */


/* ------------------------------------------------------------------------------------- */
/*
   get the current( last ) event-counter in the workspace
*/
procedure Proc_WorkSpace_Get_Counter.

    find first buf_RTB_WsCount exclusive-lock
         where buf_RTB_WsCount.wspace-id eq cWorkSpace
               no-error.
    if available buf_RTB_WsCount
    then assign Actual_Event-counter = buf_RTB_WsCount.event-counter.
    
    find first buf_RTB_WsCount no-lock no-error.
    release buf_RTB_WsCount.

end procedure. /* Proc_WorkSpace_Get_Counter */


/* ------------------------------------------------------------------------------------- */
/*
   new release record created,  
   first get the previous release record and save release.event-counter
   needed to get all artefacts between this counter and the actual counter
*/
procedure Proc_Create_Release.

    find first  buf_RTB_Release no-lock
         where buf_RTB_Release.wspace-id eq cWorkSpace
               no-error.
    if available buf_RTB_Release
    then do:
         assign Previous_Event-counter = buf_RTB_Release.event-counter.

         create new_RTB_Release.
         assign new_RTB_Release.wspace-id     = cWorkSpace
                new_RTB_Release.event-counter = Actual_Event-counter
                new_RTB_Release.release-num   = buf_RTB_Release.release-num + 1
                new_RTB_Release.date-stamp    = today
                new_RTB_Release.user-stamp    = cJenkins
                new_RTB_Release.user-note     = cRelease_Version
                new_RTB_Release.ver-counter   = 1.
    end.

end procedure. /* Proc_Create_Release */


/* ------------------------------------------------------------------------------------- */
/*
   create deployment record
   assigning new release to new deployment
   set prevous deployment in status "Complete"
   new deployment in status "WIP"
*/
procedure Proc_Create_Deploy.

    find first buf_RTB_Deploy exclusive-lock
         where buf_RTB_Deploy.wspace-id eq cWorkSpace
               no-error.
    if available buf_RTB_Deploy
    then assign buf_RTB_Deploy.deploy-status = "Complete".
    

    create new_RTB_Deploy.
    assign new_RTB_Deploy.wspace-id       = cWorkSpace
           new_RTB_Deploy.release-num     = new_RTB_Release.release-num
           new_RTB_Deploy.deploy-status   = "WIP"
           new_RTB_Deploy.site-code       = "R23"
           new_RTB_Deploy.deploy-sequence = buf_RTB_Deploy.deploy-sequence + 1
           new_RTB_Deploy.directory       = cRelease_Directory + "\Talk".


    OS-CREATE-DIR VALUE(cRelease_Directory).
    assign cRelease_Directory = cRelease_Directory + "\Talk".
    OS-CREATE-DIR VALUE(cRelease_Directory).
    
    run Proc_Report_Initial.

end procedure. /* Proc_Create_Deploy */


/* ------------------------------------------------------------------------------------- */
/*
All objects in table RTB_Hist which have an event-id (RTB_ICorp)  between the previous release and the new release
    the folder structure is created in the release destination folder (depending object)
    the object is copied from the Icorp RTB (on disk) to the release destination (sub)folder
    extra information about related task is gathered
*/
procedure Proc_Execute_Deployment.

    for each  buf_RTB_Hist no-lock
        where buf_RTB_Hist.wspace-id     eq cWorkSpace
          and buf_RTB_Hist.event-counter gt Previous_Event-counter
          and buf_RTB_Hist.event-counter le Actual_Event-counter :

              run Proc_Task_Object_Info.

              find first buf_RTB_Pname no-lock
                   where buf_RTB_Pname.object-guid eq buf_RTB_Hist.object-guid
                         no-error.
              if available buf_RTB_Pname
              then do:

                   assign cProgName = buf_RTB_Pname.pname.

                   find first buf_RTB_Path no-lock
                        where buf_RTB_Path.path-guid eq buf_RTB_Pname.path-guid
                              no-error.
                   if available buf_RTB_Path
                   then do:
                        assign cSub_Directory = buf_RTB_Path.rtb-path
                               cNew_Directory = "".
                   end.

                   assign cNew_Directory = cRelease_Directory.

                   repeat isd = 1 to num-entries(cSub_Directory, "/") :
                          assign cNew_Directory = cNew_Directory + "/" + entry(isd, cSub_Directory, "/").
                          os-create-dir value(cNew_Directory).
                   end.

                   assign cCopy_From = cGeneral_Directory + "/" + cSub_Directory + "/" + cProgName.

                   os-copy value(cCopy_From)
                           value(cNew_Directory).

                   /* if there are special file types present, then there is an extra copie of the object
                      under the root_release_directory\Talk  we gather all these object (allways the latest object version
                      
                      ********************************************************************************************
                      we moeten nog uitzoeken hoe we deploy i-a-p we deze bestanden automatisch meekrijgen
                      een routine die de Talk folder afloopt en copieert ??? 
                      ********************************************************************************************
                   */
                   if lSubType eq true
                   then do:
                        
                        assign cNew_Directory = cRelease_Xtr_Dir.

                        repeat isd = 1 to num-entries(cSub_Directory, "/") :
                               assign cNew_Directory = cNew_Directory + "/" + entry(isd, cSub_Directory, "/").
                               os-create-dir value(cNew_Directory).
                        end.

                        os-copy value(cCopy_From)
                                value(cNew_Directory).
                   end.
              end.

                     
    end. /* for each  buf_RTB_Hist */


end procedure. /* Proc_Execute_Deployment */


/* ------------------------------------------------------------------------------------- */
/*
   getting task information related to the object
*/
procedure Proc_Task_Object_Info.

    assign lSubType = false.

    find first tt_Hist exclusive-lock
         where tt_Hist.tt_Object         eq buf_RTB_Hist.object
           and tt_Hist.tt_Latest-Version eq yes
               no-error.
    if available tt_Hist
    then assign tt_Hist.tt_Latest-Version = false.



    create tt_hist.
    assign tt_Object         = buf_RTB_Hist.object
           tt_Obj-Type       = buf_RTB_Hist.obj-type
           tt_Pmod           = buf_RTB_Hist.pmod
           tt_Version        = buf_RTB_Hist.version
           tt_Change-Date    = buf_RTB_Hist.change-date
           tt_User-Id        = buf_RTB_Hist.user-id
           tt_Event-Counter  = buf_RTB_Hist.event-counter
           tt_Latest-Version = true.


    find first buf_RTB_Hist_D no-lock
         where buf_RTB_Hist_D.wspace-id eq cWorkSpace_D
           and buf_RTB_Hist_D.object    eq buf_RTB_Hist.object
           and buf_RTB_Hist_d.version   eq buf_RTB_Hist.version
               no-error.
    if available buf_RTB_Hist_D
    then assign tt_Task-Num = buf_RTB_Hist_D.task-num.


    find first buf_RTB_Ver no-lock
         where buf_RTB_Ver.object  eq buf_RTB_Hist.object
           and buf_RTB_Ver.version eq buf_RTB_Hist.version
               no-error.
    if available buf_RTB_Ver
    then assign tt_Sub-Type = buf_RTB_Ver.sub-type.


    if  tt_Sub-Type ne "p"
    and tt_Sub-Type ne "w"
    and tt_Sub-Type ne "i"
    and tt_Sub-Type ne "cls"
    and tt_Sub-Type ne "PDBASE"
    and tt_Sub-Type ne "PFIELD"
    and tt_Sub-Type ne "PFile"
    then assign lSubType = true.

    if tt_Sub-Type eq "PDBASE"
    or tt_Sub-Type eq "PFIELD"
    or tt_Sub-Type eq "PFile"
    then assign lDbSchema = true.

end procedure. /* Proc_Task_Object_Info */


/* ------------------------------------------------------------------------------------- */
/*
   creating a report file, Header and general info
*/
procedure Proc_Report_Initial.

    assign cReport = cRelease_Rep_Dir + "\" + cRelease_Version + ".txt".   
    output stream strReport to value(cReport).

    put stream strReport unformatted "Report RoundTable Release " cRelease_Version      
                                     "                                                            "
                                     "Date : " string(year(today),"9999") +  "-" +          
                                               string(month(today),"99")  +  "-" +         
                                               string(day(today),"99")    +   
                                               '_' + STRING(time,"HH:MM:SS")                skip(2)
                                     "Workspace      : " cWorkSpace                         skip
                                     "RTB Deployment : " new_RTB_Deploy.deploy-sequence     skip
                                     "RTB Release    : " new_RTB_Deploy.release-num         skip
                                     "User           : " new_RTB_Release.user-stamp         skip
                                     "Note           : " new_RTB_Release.user-note          skip
                                     "RTB Release-Id from-to : " buf_RTB_Release.release-num  " - " new_RTB_Release.release-num     skip
                                     "RTB Event-Id   from-to : " buf_RTB_Release.event-counter  " - " new_RTB_Release.event-counter skip.

    put stream strReport unformatted " " skip(2)
                                     "************************************************************************************************************************" skip
                                     "*****                                        TASKS Summary and Details                                             *****" skip
                                     "************************************************************************************************************************" skip
                                     " " skip(2).

        
end procedure. /* Proc_Report_Initial */


/* ------------------------------------------------------------------------------------- */
/*
Create a report of the current release,  report is placed in the the release folder
- Overview all tasks included (details)
- Overview all objects included (details)
- Overview all programmers involved (details)
- Overview all (sub) folders used and their objects
- Overview all code/program subtypes and their objects
- Summary release and possible remarks on the occurence of special file types
*/
procedure Proc_Report_Overview.

    DEFINE VARIABLE ix                  AS INTEGER     NO-UNDO.
    DEFINE VARIABLE iy                  AS INTEGER     NO-UNDO.
    DEFINE VARIABLE iTasks              AS INTEGER     NO-UNDO.
    DEFINE VARIABLE iSubtypes           AS INTEGER     NO-UNDO.
    DEFINE VARIABLE iFolders            AS INTEGER     NO-UNDO.
    DEFINE VARIABLE iObjects            AS INTEGER     NO-UNDO.
    DEFINE VARIABLE iObjects-Db         AS INTEGER     NO-UNDO.
    DEFINE VARIABLE cProgrammer         AS CHARACTER   NO-UNDO.
    DEFINE VARIABLE cProgrammer-Name    AS CHARACTER   NO-UNDO.
    DEFINE VARIABLE lKomma              AS LOGICAL     no-undo initial false.

    DEFINE VARIABLE lExtensions         AS LOGICAL     no-undo initial false.
    DEFINE VARIABLE lXml                AS LOGICAL     no-undo initial false.
    DEFINE VARIABLE lResx               AS LOGICAL     no-undo initial false.
    DEFINE VARIABLE lWsdl               AS LOGICAL     no-undo initial false.
    DEFINE VARIABLE lJson               AS LOGICAL     no-undo initial false.
    DEFINE VARIABLE lXls                AS LOGICAL     no-undo initial false.
    DEFINE VARIABLE lDot                AS LOGICAL     no-undo initial false.
    DEFINE VARIABLE lWrx                AS LOGICAL     no-undo initial false.
    DEFINE VARIABLE lXlt                AS LOGICAL     no-undo initial false.
    DEFINE VARIABLE lZip                AS LOGICAL     no-undo initial false.
    DEFINE VARIABLE lXsd                AS LOGICAL     no-undo initial false.
    DEFINE VARIABLE lOther              AS LOGICAL     no-undo initial false.
    DEFINE VARIABLE lDbFolder           AS LOGICAL     no-undo initial false.
    DEFINE VARIABLE cOther-Extent       AS CHARACTER   NO-UNDO.
    DEFINE VARIABLE cTable-Names        AS CHARACTER   NO-UNDO.

    /* ---------------------------------------------------------------------- */

    put stream strReport unformatted "Tasks in this Release/Deployment : ".
    
    for each tt_Hist
        break by (tt_Task-Num) :

        if first-of (tt_Task-Num)
        then do:
             if lKomma eq true
             then put stream strReport unformatted ", ".

             put stream strReport unformatted tt_Task-Num.
             assign iTasks = iTasks  + 1
                    iy     = iy + 1.

             if lKomma eq false
             then assign lKomma = true.

             if iy gt 9 /* per print-line a maximum of 10 task-id's */
             then do:
                  put stream strReport unformatted skip.                                  /* print previous line */
                  put stream strReport unformatted "                                   ". /* new line, indented  */
                  assign iy     = 0
                         lKomma = false.
             end.

        end. /* if first-of */
    end.     /* for each tt_Hist tt_task-Num */
    
    put stream strReport unformatted skip(2).
    


/* Task and task-detail Overview */
    put stream strReport unformatted "//============================================================//" skip(2).

    for each tt_Hist
        break by (tt_Task-Num) :

        if first-of (tt_Task-Num)
        then do:
             assign iy = 0.

             find first buf_RTB_Task no-lock
                  where buf_RTB_Task.task-num eq tt_Task-Num
                        no-error.
             if available buf_RTB_Task
             then do:
                  
                  assign cProgrammer = buf_RTB_Task.programmer.

                  assign cProgrammer-Name = "".
                  repeat ix = 1 to num-entries(cProgrammer, ";") :
                         find first buf_RTB_User no-lock
                              where buf_RTB_User._Userid eq entry(ix, cProgrammer, ";")
                                    no-error.
                         if available buf_RTB_User
                         then assign cProgrammer-Name = cProgrammer-Name  + buf_RTB_User._User-Name.
            
                         if ix lt num-entries(cProgrammer, ";")
                         then assign cProgrammer-Name = cProgrammer-Name + ", ".
                  end. /* repeat ix */


                  put stream strReport unformatted "Task Info : "                                                                skip
                                                   "     "  "Task Number : " buf_RTB_Task.task-num                               skip
                                                   "     "  "Programmer  : " buf_RTB_Task.programmer "   (" cProgrammer-Name ")" skip
                                                   "     "  "Summary     : " buf_RTB_Task.summary                                skip.
                  

                  put stream strReport unformatted "     "  "Description : " skip.
                  do ix = 1 to extent(buf_RTB_Task.description):
                     if buf_RTB_Task.description[ix] ne ""
                     then put stream strReport unformatted "     "  "     " buf_RTB_Task.description[ix] skip.
                  end.

                  put stream strReport unformatted " "                  skip
                                                   "Objects in Task : " skip.

             end.
        end. /* first-of tt_Task-Num */

    
        assign tt_Programmer      = cProgrammer
               tt_Programmer-Name = cProgrammer-Name.

        assign iy = iy + 1.

        put stream strReport unformatted "          " tt_Object                                                                                      skip
                                         "               " 
                                         "Version : " tt_Version "     " tt_Obj-Type "     " tt_Change-Date "     " tt_Event-Counter "     " tt_Pmod skip.

        
        if last-of (tt_Task-Num)
        then do:
             put stream strReport unformatted " " skip.
             if iy gt 1
             then put stream strReport unformatted "     " iy " Objects in Task " tt_Task-Num skip.
             else put stream strReport unformatted "     " iy " Object in Task " tt_Task-Num  skip.
             put stream strReport unformatted " " skip
                                              "//============================================================//" skip
                                              " " skip.
        end.

    end. /* for each tt_Hist tt_Task-Num */



/* Object and Object-detail Overview */
    put stream strReport unformatted " " skip(2)
                                     "************************************************************************************************************************" skip
                                     "*****                                           OBJECTS OVERVIEW                                                   *****" skip
                                     "************************************************************************************************************************" skip
                                     " " skip(2).

    for each tt_hist
        use-index tt_Ind3 :

        put stream strReport unformatted tt_Object                                                               skip
                                         "               " "Version     : " tt_Version                           skip
                                         "               " "Obj_Type    : " tt_Obj-Type                          skip
                                         "               " "Sub_Type    : " tt_Sub-Type                          skip
                                         "               " "Date Change : " tt_Change-Date                       skip
                                         "               " "Pmod        : " tt_Pmod                              skip
                                         "               " "Task        : " tt_Task-Num                          skip
                                         "               " "Event-Id    : " tt_Event-Counter                     skip.
        if tt_Latest-Version eq false
        then put stream strReport unformatted "               " "***     OLDER VERSION     ***"                  skip.
        
        put stream strReport unformatted "//------------------------------------------------------------//"      skip
                                         " "                                                                     skip.

        if tt_Latest-Version eq true
        then do:
             if  tt_Obj-Type ne "PDBASE"
             and tt_Obj-Type ne "PFILE"
             and tt_Obj-Type ne "PFIELD"
             then assign iObjects = iObjects + 1.
             else assign iObjects-Db = iObjects-Db + 1.
        end.

    end. /* for each tt_hist tt_Ind3 */



/* Programmer and Task/Object-detail Overview */
    put stream strReport unformatted " " skip(2)
                                     "************************************************************************************************************************" skip
                                     "*****                                           PROGRAMMER OVERVIEW                                                *****" skip
                                     "************************************************************************************************************************" skip
                                     " " skip(2).
    

    for each tt_Hist
        break by (tt_Programmer) :

        if first-of (tt_Programmer)
        then do:
             assign iy = 0.
             put stream strReport unformatted "Programmer : " tt_Programmer "  (" tt_Programmer-Name ")"  skip
                                              "     Task-Number / Version  -  Date      -  Object"        skip.
        end.

        assign iy = iy + 1.
        put stream strReport unformatted "          " tt_Task-Num "  /   " tt_Version "    -  " tt_Change-Date "  -  " tt_Object.
        
        if tt_Latest-Version eq false
        then put stream strReport unformatted "     *** OLDER VERSION ***" skip.
        else put stream strReport                                          skip.


        if last-of (tt_Programmer)
        then do:
             put stream strReport unformatted " " skip.
             if iy gt 1
             then put stream strReport unformatted "     " iy " Objects counted for programmer " tt_Programmer skip.
             else put stream strReport unformatted "     " iy " object counted for programmer " tt_Programmer  skip.
             put stream strReport unformatted " " skip
                                              "//............................................................//" skip
                                              " " skip.
        end.

    end. /* for each tt_hist tt_programmer */



/* Object Module Overview */
    put stream strReport unformatted " " skip(2)
                                     "************************************************************************************************************************" skip
                                     "*****                                        Folder/Subfolder OVERVIEW                                             *****" skip
                                     "************************************************************************************************************************" skip
                                     " " skip(2).


    assign iFolders = 0
           iy       = 0.

    for each tt_Hist
        break by (tt_Pmod) :

        if first-of (tt_Pmod)
        then do:

             if  tt_pMod ne "t3_db_Talkcore"
             and tt_pMod ne "t3_db_Mercator"
             and tt_pMod ne "t3_db_Talkmig"
             and tt_pMod ne "t3_pss_db"
             and tt_pMod ne "t3_wl_db"
             then do:
                  if iy eq 0
                  then put stream strReport unformatted "Object folders in this Release/Deployment : " tt_pMod skip.
                  else put stream strReport unformatted "                                            " tt_Pmod skip.

                  assign iFolders = iFolders + 1
                         iy       = iy + 1.
             end.
             else assign lDbFolder = true. 

        end. /* if first-of */
    end.     /* for each tt_Hist tt_Pmod */
    
    put stream strReport unformatted " " skip
                                     "Number of Folders : " iFolders                                    skip.

    if lDbFolder eq true
    then put stream strReport unformatted "Database-Schema folders are not taken in account (No Deployment)" skip.

    put stream strReport unformatted " " skip
                                     "//............................................................//" skip(2).
                                      

    assign iy = 0.

    for each tt_Hist
        break by (tt_Pmod) :

        if first-of (tt_Pmod)
        then put stream strReport unformatted "Folder : " tt_pMod skip(2). 
        
        if tt_Latest-Version eq true
        then do:
             assign iy = iy + 1.
             put stream strReport unformatted "            Task : " tt_Task-Num "     Version : " tt_Version "     " tt_Object skip.
        end.

        if last-of (tt_Pmod)
        then do:
            put stream strReport unformatted " " skip.

            if iy gt 1
            then put stream strReport unformatted "         " iy " objects in folder " tt_Pmod skip.
            else put stream strReport unformatted "         " iy " object in folder " tt_Pmod  skip.
            
            put stream strReport unformatted " " skip
                                             "//............................................................//" skip
                                             " " skip.

             assign iy = 0. 
        end.

    end. /* for each tt_Hist tt_Pmod */




/* Object Subtype Overview */
    put stream strReport unformatted " " skip(2)
                                     "************************************************************************************************************************" skip
                                     "*****                                             Subtypes OVERVIEW                                                *****" skip
                                     "************************************************************************************************************************" skip
                                     " " skip(2).


    assign lKomma    = false
           iy        = 0
           iSubtypes = 0.

    put stream strReport unformatted "Object subtypes in this Release/Deployment : ".
    
    for each tt_Hist
        break by (tt_Sub-Type) :

        if first-of (tt_Sub-Type)
        then do:
             if lKomma eq true
             then put stream strReport unformatted ", ".

             put stream strReport unformatted tt_Sub-Type.
             assign iSubtypes = iSubtypes  + 1
                    iy        = iy + 1.

             if lKomma eq false
             then assign lKomma = true.

             if iy gt 9 /* per print-line a maximum of 10 subtype-id's */
             then do:
                  put stream strReport unformatted skip.                                            /* print previous line */
                  put stream strReport unformatted "                                             ". /* new line */
                  assign iy     = 0
                         lKomma = false.
             end.


             case tt_Sub-Type :
             
                  when "xml"  then assign lXml        = true
                                          lExtensions = true.
                  when "resx" then assign lResx       = true
                                          lExtensions = true.
                  when "wsm"  then assign lWsdl       = true
                                          lExtensions = true.
                  when "wsdl" then assign lWsdl       = true
                                          lExtensions = true.
                  when "json" then assign lJson       = true
                                          lExtensions = true.
                  when "xls"  
               or when "xlsx" then assign lXls        = true
                                          lExtensions = true.
                  when "dot"  then assign lDot        = true
                                          lExtensions = true.
                  when "wrx"  then assign lWrx        = true
                                          lExtensions = true.
                  when "xlt"  
               or when "xltx" then assign lXlt        = true
                                          lExtensions = true.
                  when "zip"  then assign lZip        = true
                                          lExtensions = true.
                  when "xsd"  then assign lXsd        = true
                                          lExtensions = true.

                  otherwise   do:
                                 if  tt_Sub-Type ne "p"
                                 and tt_Sub-Type ne "w"
                                 and tt_Sub-Type ne "i"
                                 and tt_Sub-Type ne "cls"
                                 and tt_Sub-Type ne "PDBASE"
                                 and tt_Sub-Type ne "PFIELD"
                                 and tt_Sub-Type ne "PFILE"
                                 then assign lOther        = true
                                             lExtensions   = true.

                                 if   cOther-Extent ne ""
                                 then cOther-Extent = cOther-Extent + ", " + tt_Sub-Type.
                                 else cOther-Extent = tt_Sub-Type.

                              end.
             end case.


        end. /* if first-of */
    end.     /* for each tt_Hist tt_Sub-Type */
    
    put stream strReport unformatted " " skip
                                     "Number of Subtypes : " iSubtypes                                  skip
                                     " " skip
                                     "//............................................................//" skip(2).


    for each tt_Hist
        break by (tt_Sub-Type) :

        if first-of (tt_Sub-Type)
        then put stream strReport unformatted "SubType : " tt_Sub-Type skip. 
        

        put stream strReport unformatted "          " tt_Object skip
                                         "               Version : " tt_Version "     Task : " tt_Task-Num "     Pmod : " tt_Pmod.
        if tt_Latest-Version eq false
        then put stream strReport unformatted "     *** OLDER VERSION ***" skip.
        else put stream strReport                                          skip.

        if tt_Sub-Type eq "PFILE"
        then do:
             if cTable-Names eq ""
             then assign cTable-Names = tt_Object.
             else assign cTable-Names = cTable-Names + ", " + tt_Object.
        end.

        if last-of (tt_Sub-Type)
        then put stream strReport unformatted " " skip
                                              "//............................................................//" skip
                                              " " skip.

    end. /* for each tt_Hist tt_Sub-Type */



/* Overview #Tasks,  #Objects,  #Subtypes,  #Folders */
    put stream strReport unformatted " " skip(2)
                                     "************************************************************************************************************************" skip
                                     "*****                                                  SUMMARY                                                     *****" skip
                                     "************************************************************************************************************************" skip
                                     " " skip(2).

    put stream strReport unformatted "     Number of Tasks    : " iTasks    skip
                                     "     Number of Objects  : " iObjects  skip
                                     "     Number of Subtypes : " iSubtypes skip
                                     "     Number of Folders  : " iFolders  skip.

    if lExtensions eq true
    then do:
         put stream strReport unformatted " " skip(2).
         
         if lXml  eq true then put stream strReport unformatted "     ** There are XML      files in release/deployment **" skip.
         if lResx eq true then put stream strReport unformatted "     ** There are RESX     files in release/deployment **" skip.
         if lWsdl eq true then put stream strReport unformatted "     ** There are WSDL/WSM files in release/deployment **" skip.
         if lJson eq true then put stream strReport unformatted "     ** There are JSON     files in release/deployment **" skip.
         if lXls  eq true then put stream strReport unformatted "     ** There are XLS      files in release/deployment **" skip.
         if lDot  eq true then put stream strReport unformatted "     ** There are DOT      files in release/deployment **" skip.
         if lWrx  eq true then put stream strReport unformatted "     ** There are WRX      files in release/deployment **" skip.
         if lXlt  eq true then put stream strReport unformatted "     ** There are XLT      files in release/deployment **" skip.
         if lZip  eq true then put stream strReport unformatted "     ** There are ZIP      files in release/deployment **" skip.
         if lXsd  eq true then put stream strReport unformatted "     ** There are XSD      files in release/deployment **" skip.

         if lOther eq true 
         then put stream strReport unformatted "     ** There are NOT COMMON files in release/deployment **" skip
                                               "        " cOther-Extent                                      skip
                                               "     ** ................................................ **" skip.
         
    end. /* if lExtensions eq true */


    if lDbSchema eq true
    then put stream strReport unformatted " " skip
                                          "**  Database Schema Changes : df-file to be provided by development team"   skip
                                          "**  " cTable-Names skip
                                          "**  Number of Db-Objects : " iObjects-Db skip.


    put stream strReport unformatted " " skip(2)
                                     "************************************************************************************************************************" skip
                                     " " skip(2).



/* Closure of report */
    put stream strReport unformatted "**  End of report RoundTable Release " cRelease_Version "  **"     
                                     "                                             "
                                     "Date : " string(year(today),"9999") +  "-" +          
                                               string(month(today),"99")  +  "-" +         
                                               string(day(today),"99")    +   
                                               '_' + STRING(time,"HH:MM:SS")                skip.

    if lBI eq true
    then put stream strReport unformatted " " skip
                                          "**  Procedure executed on build server " cServerName skip.
    else put stream strReport unformatted " " skip
                                          "**  Procedure executed on development server " cServerName skip.

    put stream strReport unformatted "**  Objects are stored in " cRelease_Directory skip.

    if lExtensions eq true
    then put stream strReport unformatted "**  Non-Compile objects are additional stored in " cRelease_Xtr_Dir "\Talk" skip.


end procedure. /* Proc_Report_Overview */

/* ------------------------------------------------------------------------------------- */
