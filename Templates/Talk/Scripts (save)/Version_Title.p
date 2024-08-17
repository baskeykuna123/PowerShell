define stream test.
output stream test to "c:\tmp\luc.txt".

DEFINE VARIABLE cVersion    AS CHARACTER   NO-UNDO.
DEFINE VARIABLE cCorp       AS CHARACTER   NO-UNDO.

RUN Proc_Sessie_Param_lezen.
put stream test unformatted "cVersion = " cVersion skip
                            "cCorp = " cCorp skip.


find first sys_param exclusive-lock no-error.

if available sys_param 
then do:

     case cCorp :
         when "ICORP" then assign applic_title = "Baloise Insurance Life Icorp (Version " + cVersion + ")".
         when "ACORP" then assign applic_title = "Baloise Insurance Life Acorp (Version " + cVersion + ")".
     end case.
     
end.

quit.


/* ---------------------------------------------------------------------------------------- */


PROCEDURE Proc_Sessie_Param_lezen.

    DEFINE VARIABLE iEntry  AS INTEGER     NO-UNDO.
    DEFINE VARIABLE cEntry  AS CHARACTER   NO-UNDO.


    do iEntry = 1 to num-entries(session:parameter):
            cEntry = entry(iEntry,session:parameter).
            if cEntry begins "RelNum="    THEN cVersion = entry(2,cEntry,"=").
            if cEntry begins "Corp="      THEN cCorp    = entry(2,cEntry,"=").
    end.


END PROCEDURE. /* Proc_Sessie_Param_lezen */


/* =================================================================================================== */
