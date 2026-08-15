//MAPCOMP  JOB (987),'ASSEMBLE MAP',CLASS=A,MSGCLASS=A,MSGLEVEL=(1,1),  
//             NOTIFY=&SYSUID                                           
//SETLIB   JCLLIB ORDER=DFH620.CICS.SDFHPROC                            
//*--------------------------------------------------------------------*
//* Assembles the BMS mapset (JOB1SET) using the IBM-supplied          *
//* DFHMAPS procedure. Produces:                                       *
//*   - physical map (load module)      -> MAPLIB                      *
//*   - symbolic map (copybook/DSECT)   -> DSCTLIB                     *   
//*--------------------------------------------------------------------*
//MAPSET   EXEC DFHMAPS,                                                
//           INDEX=DFH620.CICS,                                         
//           MAPLIB=Z73460.CICS.PROD.DFHLOAD,                           
//           DSCTLIB=Z73460.CICS.COPYLIB,                               
//           MAPNAME=JOB1SET                                            
//COPY.SYSUT1 DD DSN=Z73460.CICS.BMS(JOB1SET),DISP=SHR                  
//                                                                      
