//CICSTST  JOB (123),'CICSC',CLASS=A,MSGCLASS=A,MSGLEVEL=(1,1),
//             NOTIFY=&SYSUID
//*=====================================================================
//* Compiles a CICS COBOL program using DFHZITCL (integrated CICS
//* translator + Enterprise COBOL compiler + Linkage Editor).
//*=====================================================================
//CICSPROG EXEC DFHZITCL
//*---------------------------------------------------------------------
//* Source program to translate/compile
//*---------------------------------------------------------------------
//COBOL.SYSIN  DD DISP=SHR,DSN=Z73460.COB.CICS.PRAC(ATMPGM1)
//*---------------------------------------------------------------------
//* Copybook libraries: CICS-supplied + project copybooks
//*---------------------------------------------------------------------
//COBOL.SYSLIB DD DISP=SHR,DSN=DFH620.CICS.SDFHCOB
//             DD DISP=SHR,DSN=Z73460.CICS.COPYLIB
//             DD DISP=SHR,DSN=Z73460.COPYLIB
//*---------------------------------------------------------------------
//* Target load library for the linked program
//*---------------------------------------------------------------------
//LKED.SYSLMOD DD DISP=SHR,DSN=Z73460.CICS.PROD.DFHLOAD
//*---------------------------------------------------------------------
//* Linkage editor control: name the output module ATMPGM1 (replace
//* if it already exists)
//*---------------------------------------------------------------------
//LKED.SYSIN   DD *,SYMBOLS=EXECSYS
  NAME ATMPGM1(R)
/*
//
