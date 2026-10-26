//CICSTST  JOB (123),'CICSC',CLASS=A,MSGCLASS=A,MSGLEVEL=(1,1),
//             NOTIFY=&SYSUID
//*=====================================================================
//* COMPILES A CICS COBOL PROGRAM USING DFHZITCL (INTEGRATED CICS
//* TRANSLATOR + ENTERPRISE COBOL COMPILER + LINKAGE EDITOR).
//*=====================================================================
//CICSPROG EXEC DFHZITCL
//*---------------------------------------------------------------------
//* SOURCE PROGRAM TO TRANSLATE/COMPILE
//*---------------------------------------------------------------------
//COBOL.SYSIN  DD DISP=SHR,DSN=Z73460.COB.CICS.PRAC(ATMPGM1)
//*---------------------------------------------------------------------
//* COPYBOOK LIBRARIES: CICS-SUPPLIED + PROJECT COPYBOOKS
//*---------------------------------------------------------------------
//COBOL.SYSLIB DD DISP=SHR,DSN=DFH620.CICS.SDFHCOB
//             DD DISP=SHR,DSN=Z73460.CICS.COPYLIB
//             DD DISP=SHR,DSN=Z73460.COPYLIB
//*---------------------------------------------------------------------
//* TARGET LOAD LIBRARY FOR THE LINKED PROGRAM
//*---------------------------------------------------------------------
//LKED.SYSLMOD DD DISP=SHR,DSN=Z73460.CICS.PROD.DFHLOAD
//*---------------------------------------------------------------------
//* LINKAGE EDITOR CONTROL: NAME THE OUTPUT MODULE ATMPGM1 (REPLACE
//* IF IT ALREADY EXISTS)
//*---------------------------------------------------------------------
//LKED.SYSIN   DD *,SYMBOLS=EXECSYS
  NAME ATMPGM1(R)
/*
//
