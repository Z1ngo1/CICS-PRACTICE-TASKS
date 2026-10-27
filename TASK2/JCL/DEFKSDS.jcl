//DEFKSDS  JOB (123),'IDCAMS',CLASS=A,MSGCLASS=A,MSGLEVEL=(1,1),        
//             NOTIFY=&SYSUID                                           
//**********************************************************************
//* TASK2: CREATE AND LOAD OPERATOR MASTER VSAM KSDS (ATMTASK2)        *
//* STEP010 - DELETE OLD CLUSTER IF EXISTS, DEFINE NEW KSDS            *
//* STEP020 - SORT INLINE DATA BY KEY INTO TEMP PS FILE (LRECL=100)    *
//*           SKIPPED IF STEP010 RC != 0                               *
//* STEP030 - LOAD TEMP PS FILE INTO KSDS VIA IDCAMS REPRO             *
//*           SKIPPED IF ANY PREVIOUS STEP RC != 0                     *
//* STEP040 - PRINT KSDS CONTENT TO SYSPRINT TO CHECK THE LOAD         *
//**********************************************************************
//**********************************************************************
//* DELETE OLD CLUSTER (SET MAXCC=0 - NO ERROR IF NOT FOUND)           *
//* DEFINE KSDS: KEY = OPER-ID (8 BYTES, OFFSET 0), RECORD = 100 BYTES *
//**********************************************************************
//STEP010  EXEC PGM=IDCAMS                                              
//SYSPRINT DD SYSOUT=*                                                  
//SYSIN    DD *                                                         
  DELETE Z73460.TASK2.CICS.BANK.OPER PURGE CLUSTER                      
  SET MAXCC = 0                                                         
                                                                        
  DEFINE CLUSTER (NAME(Z73460.TASK2.CICS.BANK.OPER) -                   
      RECORDSIZE(100 100)       -                                       
      TRACKS(1 1)               -                                       
      KEYS(8 0)                 -                                       
      FREESPACE(10 20)          -                                       
      SHAREOPTIONS(2 3)         -                                       
      INDEXED)                  -                                       
  DATA (NAME(Z73460.TASK2.CICS.BANK.OPER.DATA)) -                       
  INDEX (NAME(Z73460.TASK2.CICS.BANK.OPER.INDEX))                       
/*                                                                      
//**********************************************************************
//* BYPASSED IF STEP010 RC != 0                                        *
//* SORT BY OPER-ID (REPRO INTO KSDS NEEDS ASCENDING KEYS)             *
//* PAD 80-BYTE INLINE RECORDS WITH 20 SPACES TO 100 BYTES             *
//* FIELDS: ID(8) PIN(4) NAME(30) STATUS(1) FAIL-COUNT(2) FILLER(55)   *
//**********************************************************************
//STEP020  EXEC PGM=SORT,COND=(0,NE)                                    
//SYSOUT   DD SYSOUT=*                                                  
//SORTIN   DD *                                                         
OP0000011234JOHN SMITH                    A00                           
OP0000025678MARY JOHNSON                  A01                           
OP0000039999LOCKED USER                   L03                           
OP0000044444SARAH CONNOR                  L03                           
OP0000055555JAMES BOND                    A00                           
OP0000060123ALEXANDER KONSTANTINOV        A00                           
OP0000077777ANNA LEE                      A02                           
OP1     1111SHORT ID USER                 A00                           
/*                                                                      
//SORTOUT  DD DSN=&&TEMP,                                               
//            DISP=(NEW,PASS,DELETE),                                   
//            SPACE=(TRK,(1,1),RLSE),                                   
//            DCB=(DSORG=PS,RECFM=FB,LRECL=100)                         
//SYSIN    DD *                                                         
  SORT FIELDS=(1,8,CH,A)                                                
  OUTREC BUILD=(1,80,20X)                                               
/*                                                                      
//**********************************************************************
//* BYPASSED IF ANY PREVIOUS STEP RC != 0                              *
//* REPRO COPIES SORTED RECORDS FROM INDD INTO KSDS OUTDD              *
//**********************************************************************
//STEP030  EXEC PGM=IDCAMS,COND=(0,NE)                                  
//SYSPRINT DD SYSOUT=*                                                  
//INDD     DD DSN=&&TEMP,DISP=(OLD,DELETE)                              
//OUTDD    DD DSN=Z73460.TASK2.CICS.BANK.OPER,DISP=SHR                  
//SYSIN    DD *                                                         
  REPRO INFILE(INDD) -                                                  
        OUTFILE(OUTDD)                                                  
/*                                                                      
//**********************************************************************
//* BYPASSED IF ANY PREVIOUS STEP RC != 0                              *
//* PRINT ALL KSDS RECORDS IN CHARACTER FORMAT (CHECK RESULT IN SPOOL) *
//**********************************************************************
//STEP040  EXEC PGM=IDCAMS,COND=(0,NE)                                  
//SYSPRINT DD SYSOUT=*                                                  
//SYSIN    DD *                                                         
  PRINT INDATASET(Z73460.TASK2.CICS.BANK.OPER) CHARACTER                
/*                                                                      
//                                                                      
