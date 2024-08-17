
/* 
   Luc Mercken
   2020/02/10
   tabel-definities opladen per db
   
   
   er zijn 3 laad programma"s in de prodict.pl
            prodict\load_df.p
            prodict\dump\_load_df.p
            prodict\load_df_silent.p  (we gebruiken deze omdat er een return is van de fouten
*/

define input parameter Db_LogicName as character.
define input parameter Df_File      as character.
define input parameter ReleaseDir   as character.
define input parameter cFileName    as character.
define output parameter cErrorFile  as character.
define output parameter cLogFile    as character.

DEFINE VARIABLE cError              AS CHARACTER   NO-UNDO.
DEFINE VARIABLE cName               AS CHARACTER   NO-UNDO.

assign cFileName = "Load_" + cFileName          + 
                   "_"                          +
                   string(year(today),"9999")   +  
                   string(month(today),"99")    + 
                   string(day(today),"99")      +
                   '_' + string(time, "999999") + '_Log.txt'.
                   

assign cName    = ReleaseDir + cFileName
       cLogFile = cName.

output to value(cName).

run Proc_Df-Opladen.


output close. 

/* ====================================================================================================== */

procedure Proc_Df-Opladen.

/*     do on error undo, return : */
    
      CREATE ALIAS dictdb FOR DATABASE value(Db_LogicName).  

      run  prodict/load_df_silent.p(input Df_File, input "", output cError).

      display cError skip.
      assign cErrorFile = cError.

      delete alias dictdb.

/*     end. */

    

end procedure.

/* ------------------------------------------------------------------------------------------------------ */
