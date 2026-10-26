      *----------------------------------------------------------------*
      * ATM OPERATOR AUTHENTICATION WITH VSAM VALIDATION               *
      *                                                                *
      * PURPOSE:                                                       *
      * SECOND VERSION OF THE ATM AUTHORIZATION SCREEN. ACCEPTS        *
      * OPERATOR ID + PIN, CHECKS THE INPUT ON THE SCREEN, THEN CHECKS *
      * THE OPERATOR AGAINST A VSAM KSDS FILE (READ UPDATE / REWRITE). *
      *                                                                *
      * BUSINESS LOGIC:                                                *
      *   FIRST ENTRY / CLEAR - SEND BLANK LOGON MAP.                  *
      *   ENTER - RECEIVE MAP AND CHECK THE SCREEN INPUT:              *
      *     OPERATOR ID EMPTY -> 'OPERATOR ID IS REQUIRED'             *
      *     PIN EMPTY         -> 'PIN CODE IS REQUIRED'                *
      *     PIN NOT NUMERIC   -> 'PIN CODE MUST BE NUMERIC'            *
      *     PIN NOT 4 DIGITS  -> 'PIN MUST CONTAIN 4 DIGITS'           *
      *   THEN READ THE OPERATOR RECORD FROM THE FILE:                 *
      *     NOT FOUND         -> 'INVALID OPERATOR ID'                 *
      *     STATUS = 'L'      -> 'ACCOUNT LOCKED' (RECORD NOT CHANGED) *
      *     PIN CORRECT       -> FAIL COUNT = 0,                       *
      *                          'ACCESS GRANTED - WELCOME <NAME>'     *
      *     PIN WRONG         -> FAIL COUNT + 1, 'INVALID PIN CODE'    *
      *     3RD WRONG PIN     -> STATUS = 'L', 'ACCOUNT LOCKED'        *
      *   PF3   - SEND 'END OF PROGRAM' AND END THE TRANSACTION.       *
      *   OTHER - SEND 'INVALID KEY - PRESS ENTER OR F3'.              *
              *                                                                *
      * AUTHOR: STANISLAV                                              *
      * DATE:   2026/02/27                                             *
      *                                                                *
      * CICS RESOURCES:                                                *
      * TRANSID:    ATM2                                               *
      * PROGRAM:    ATMPGM2                                            *
      * MAPSET:     JOB1SET (COPY)                                     *
      * MAP:        JOB1MAP - OPERATOR ID (8), PIN (4, DARK), MSG (40) *
      * VSAM(KSDS): TASK2.CICS.BANK.OPER                               *
      * COPYBOOK:   OPERREC  - OPERATOR RECORD LAYOUT                  *
      *----------------------------------------------------------------*
                                                                        
       IDENTIFICATION DIVISION.                                         
       PROGRAM-ID. ATMPGM2.                                             
       ENVIRONMENT DIVISION.                                            
       DATA DIVISION.                                                   
       WORKING-STORAGE SECTION.                                         
                                                                        
      * COMMAREA LAYOUT                                                 
       01 WS-COMMAREA PIC X(1).                                         
                                                                        
      * CICS / BMS COPYBOOKS / VSAM COPYBOOK                            
           COPY DFHAID.                                                 
           COPY DFHBMSCA.                                               
           COPY JOB1SET.                                                
           COPY OPERREC.                                                
                                                                        
      * WORKING VARIABLES                                               
       01 WS-OPER-KEY  PIC X(8).                                        
       01 WS-PINCODE   PIC X(4).                                        
       01 WS-OPRID-LEN PIC S9(4) COMP.                                  
       01 WS-PIN-LEN   PIC S9(4) COMP.                                  
       01 WS-OPER-LEN  PIC S9(4) COMP VALUE +100.                       
                                                                        
      * RESP/RESP2 CODES RETURNED BY EXEC CICS COMMANDS                 
       01 WS-RESP  PIC S9(8) COMP.                                      
       01 WS-RESP2 PIC S9(8) COMP.                                      
                                                                        
       LINKAGE SECTION.                                                 
                                                                        
       01 DFHCOMMAREA PIC X(1).                                         
                                                                        
      *----------------------------------------------------------------*
      * MAINLINE. ROUTES BASED ON EIBCALEN / EIBAID:                   *
      * FIRST ENTRY OR CLEAR -> BLANK MAP.                             *
      * PF3    -> 'END OF PROGRAM' MESSAGE, RETURN WITHOUT TRANSID.    *
      * ENTER  -> RECEIVE, CHECK INPUT, CHECK VSAM, SEND RESULT.       *
      * OTHER  -> 'INVALID KEY' MESSAGE (YELLOW).                      *
      * AFTER ALL CASES EXCEPT PF3 -> RETURN WITH TRANSID ATM2.        *
      *----------------------------------------------------------------*
       PROCEDURE DIVISION.                                              
       MAIN-LOGIC.                                                      
           EVALUATE TRUE                                                
               WHEN EIBCALEN = ZERO                                     
                 MOVE LOW-VALUES TO JOB1MAPO                            
                 MOVE -1 TO OPRIDL                                      
                 PERFORM SEND-MAP                                       
               WHEN EIBAID = DFHCLEAR                                   
                 MOVE LOW-VALUES TO JOB1MAPO                            
                 MOVE -1 TO OPRIDL                                      
                 PERFORM SEND-MAP                                       
               WHEN EIBAID = DFHPF3                                     
                 MOVE LOW-VALUES TO JOB1MAPO                            
                 MOVE 'END OF PROGRAM. PRESS CLEAR' TO MSGO             
                 MOVE -1 TO OPRIDL                                      
                 PERFORM SEND-MAP                                       
                 EXEC CICS                                              
                   RETURN                                               
                 END-EXEC                                               
               WHEN EIBAID = DFHENTER                                   
                 PERFORM PROCESS-INPUT                                  
               WHEN OTHER                                               
                 MOVE LOW-VALUES TO JOB1MAPO                            
                 MOVE DFHYELLO TO MSGC                                  
                 MOVE 'INVALID KEY - PRESS ENTER OR F3' TO MSGO         
                 MOVE -1 TO OPRIDL                                      
                 PERFORM SEND-DATAONLY                                  
           END-EVALUATE                                                 
                                                                        
           EXEC CICS RETURN                                             
             TRANSID('ATM2')                                            
             COMMAREA (WS-COMMAREA)                                     
             LENGTH(1)                                                  
           END-EXEC.                                                    
                                                                        
      *----------------------------------------------------------------*
      * RECEIVES THE MAP, CHECKS OPERATOR ID AND PIN ON THE SCREEN     *
      * LEVEL, THEN READS THE OPERATOR RECORD WITH UPDATE.             *
      * RECEIVE: NORMAL / MAPFAIL - CONTINUE (MAPFAIL = EMPTY INPUT).  *
      *          OTHER            - ABEND 'RCVE'.                      *
      * SCREEN CHECKS (STOP AT FIRST ERROR):                           *
      *   1. OPERATOR ID NOT ENTERED / BLANK.                          *
      *   2. PIN NOT ENTERED / BLANK.                                  *
      *   3. PIN NOT NUMERIC.                                          *
      *   4. PIN LENGTH NOT EQUAL TO 4.                                *
      * PIN FORMAT ERRORS DO NOT COUNT AS FAILED ATTEMPTS.             *
      * READ: NORMAL   - GO TO VALIDATE-CREDENTIALS.                   *
      *       NOTFND   - 'INVALID OPERATOR ID'.                        *
      *       NOTOPEN  - 'FILE IS CLOSED'.                             *
      *       DISABLED - 'FILE IS DISABLED'.                           *
      *       OTHER    - 'VSAM ERROR'.                                 *
      *----------------------------------------------------------------*
       PROCESS-INPUT.                                                   
           MOVE LOW-VALUES TO JOB1MAPI                                  
                                                                        
           EXEC CICS RECEIVE                                            
             MAP('JOB1MAP')                                             
             MAPSET('JOB1SET')                                          
             INTO(JOB1MAPI)                                             
             RESP(WS-RESP)                                              
             RESP2(WS-RESP2)                                            
           END-EXEC                                                     
                                                                        
           EVALUATE WS-RESP                                             
               WHEN DFHRESP(NORMAL)                                     
                 CONTINUE                                               
               WHEN DFHRESP(MAPFAIL)                                    
                 CONTINUE                                               
               WHEN OTHER                                               
                 EXEC CICS ABEND                                        
                   ABCODE('RCVE')                                       
                 END-EXEC                                               
           END-EVALUATE                                                 

      * SAVE SCREEN INPUT BEFORE JOB1MAPO IS CLEARED                    
           MOVE OPRIDL   TO WS-OPRID-LEN                                
           MOVE OPRIDI   TO WS-OPER-KEY                                 
           MOVE PINCODEL TO WS-PIN-LEN                                  
           MOVE PINCODEI TO WS-PINCODE                                  
           INSPECT WS-OPER-KEY REPLACING ALL LOW-VALUES BY SPACE        
           INSPECT WS-PINCODE  REPLACING ALL LOW-VALUES BY SPACE        
                                                                        
      * CLEAR OUTPUT MAP - ENTERED DATA IS NOT SENT BACK                
           MOVE LOW-VALUES TO JOB1MAPO                                  
                                                                        
           IF WS-OPRID-LEN = ZERO OR WS-OPER-KEY = SPACES               
              MOVE DFHRED TO MSGC                                       
              MOVE 'ERROR: OPERATOR ID IS REQUIRED' TO MSGO             
              MOVE -1 TO OPRIDL                                         
              PERFORM SEND-MAP                                          
              EXIT PARAGRAPH                                            
           END-IF                                                       
                                                                        
           IF WS-PIN-LEN = ZERO OR WS-PINCODE = SPACES                  
              MOVE DFHRED TO MSGC                                       
              MOVE 'ERROR: PIN CODE IS REQUIRED' TO MSGO                
              MOVE WS-OPER-KEY TO OPRIDO                                
              MOVE -1 TO PINCODEL                                       
              PERFORM SEND-MAP                                          
              EXIT PARAGRAPH                                            
           END-IF                                                       
                                                                        
           IF WS-PINCODE NOT NUMERIC                                    
              MOVE DFHRED TO MSGC                                       
              MOVE 'ERROR: PIN CODE MUST BE NUMERIC' TO MSGO            
              MOVE WS-OPER-KEY TO OPRIDO                                
              MOVE -1 TO PINCODEL                                       
              PERFORM SEND-MAP                                          
              EXIT PARAGRAPH                                            
           END-IF                                                       
                                                                        
      * NUM FIELD IS RIGHT-JUSTIFIED AND ZERO-FILLED BY BMS,            
      * SO SHORT PIN (E.G. '12' -> '0012') IS CAUGHT BY LENGTH          
           IF WS-PIN-LEN NOT = 4                                        
              MOVE DFHRED TO MSGC                                       
              MOVE 'ERROR: PIN MUST CONTAIN 4 DIGITS' TO MSGO           
              MOVE WS-OPER-KEY TO OPRIDO                                
              MOVE -1 TO PINCODEL                                       
              PERFORM SEND-MAP                                          
              EXIT PARAGRAPH                                            
           END-IF                                                       
                                                                        
      * READ WITH UPDATE - RECORD IS LOCKED UNTIL REWRITE / UNLOCK      
           EXEC CICS READ                                               
             FILE('ATMTASK2')                                           
             INTO(OPERATOR-RECORD)                                      
             RIDFLD(WS-OPER-KEY)                                        
             LENGTH(WS-OPER-LEN)                                        
             UPDATE                                                     
             RESP(WS-RESP)                                              
             RESP2(WS-RESP2)                                            
           END-EXEC                                                     
                                                                        
           EVALUATE WS-RESP                                             
               WHEN DFHRESP(NORMAL)                                     
                 PERFORM VALIDATE-CREDENTIALS                           
               WHEN DFHRESP(NOTFND)                                     
                 MOVE DFHRED TO MSGC                                    
                 MOVE 'ERROR: INVALID OPERATOR ID' TO MSGO              
                 MOVE -1 TO OPRIDL                                      
                 PERFORM SEND-MAP                                       
               WHEN DFHRESP(NOTOPEN)                                    
                 MOVE DFHRED TO MSGC                                    
                 MOVE 'ERROR: FILE IS CLOSED' TO MSGO                   
                 MOVE WS-OPER-KEY TO OPRIDO                             
                 MOVE -1 TO PINCODEL                                    
                 PERFORM SEND-MAP                                       
               WHEN DFHRESP(DISABLED)                                   
                 MOVE DFHRED TO MSGC                                    
                 MOVE 'ERROR: FILE IS DISABLED' TO MSGO                 
                 MOVE WS-OPER-KEY TO OPRIDO                             
                 MOVE -1 TO PINCODEL                                    
                 PERFORM SEND-MAP                                       
               WHEN OTHER                                               
                 MOVE DFHRED TO MSGC                                    
                 MOVE 'VSAM ERROR' TO MSGO                              
                 MOVE WS-OPER-KEY TO OPRIDO                             
                 MOVE -1 TO PINCODEL                                    
                 PERFORM SEND-MAP                                       
           END-EVALUATE.                                                
                                                                        
      *----------------------------------------------------------------*
      * CHECKS THE OPERATOR RECORD AFTER A SUCCESSFUL READ.            *
      *   1. STATUS = 'L' - UNLOCK THE RECORD, 'ACCOUNT LOCKED'.       *
      *   2. PIN CORRECT  - FAIL COUNT = 0, 'ACCESS GRANTED' (GREEN).  *
      *   3. PIN WRONG    - FAIL COUNT + 1, 'INVALID PIN CODE'.        *
      *      IF FAIL COUNT >= 3 - STATUS = 'L', 'ACCOUNT LOCKED'.      *
      * IN CASES 2 AND 3 THE RECORD IS UPDATED BY REWRITE-OPERATOR.    *
      * NOTE: MSG IS 40 CHARS, SO NAME IS CUT AFTER 15 CHARS.          *
      *----------------------------------------------------------------*
       VALIDATE-CREDENTIALS.                                            
           IF OPER-STATUS = 'L'                                         
              EXEC CICS UNLOCK                                          
                FILE('ATMTASK2')                                        
                RESP(WS-RESP)                                           
                RESP2(WS-RESP2)                                         
              END-EXEC                                                  
                                                                        
              EVALUATE WS-RESP                                          
                  WHEN DFHRESP(NORMAL)                                  
                    CONTINUE                                            
                  WHEN OTHER                                            
                    EXEC CICS ABEND                                     
                      ABCODE('UNLK')                                    
                    END-EXEC                                            
              END-EVALUATE                                              
                                                                        
              MOVE DFHRED TO MSGC                                       
              MOVE 'ACCOUNT LOCKED' TO MSGO                             
              MOVE -1 TO OPRIDL                                         
              PERFORM SEND-MAP                                          
              EXIT PARAGRAPH                                            
           END-IF                                                       
                                                                        
      * X(4) VS 9(4) - COMPARED AS TEXT, NO NUMERIC CONVERSION          
           IF WS-PINCODE = OPER-PIN                                     
              MOVE 0 TO OPER-FAIL-COUNT                                 
              MOVE DFHGREEN TO MSGC                                     
              MOVE SPACES TO MSGO                                       
              STRING 'ACCESS GRANTED - WELCOME '                        
                     FUNCTION TRIM(OPER-NAME TRAILING)                  
                     DELIMITED BY SIZE                                  
                     INTO MSGO                                          
              END-STRING                                                
              MOVE -1 TO OPRIDL                                         
           ELSE                                                         
              ADD 1 TO OPER-FAIL-COUNT                                  
              MOVE DFHRED TO MSGC                                       
              IF OPER-FAIL-COUNT >= 3                                   
                 MOVE 'L' TO OPER-STATUS                                
                 MOVE 'ACCOUNT LOCKED' TO MSGO                          
                 MOVE -1 TO OPRIDL                                      
              ELSE                                                      
                 MOVE 'ERROR: INVALID PIN CODE' TO MSGO                 
                 MOVE WS-OPER-KEY TO OPRIDO                             
                 MOVE -1 TO PINCODEL                                    
              END-IF                                                    
           END-IF                                                       
                                                                        
           PERFORM REWRITE-OPERATOR                                     
           PERFORM SEND-MAP.                                            
                                                                        
      *----------------------------------------------------------------*
      * WRITES THE UPDATED OPERATOR RECORD BACK TO THE FILE            *
      * (FAIL COUNT AND STATUS) AND RELEASES THE LOCK FROM READ UPDATE.*
      * NORMAL - KEEP THE MESSAGE SET BY VALIDATE-CREDENTIALS.         *
      * OTHER  - REPLACE IT WITH 'FILE UPDATE FAILED' (RED).           *
      *----------------------------------------------------------------*
       REWRITE-OPERATOR.                                                
           EXEC CICS REWRITE                                            
             FILE('ATMTASK2')                                           
             FROM(OPERATOR-RECORD)                                      
             LENGTH(WS-OPER-LEN)                                        
             RESP(WS-RESP)                                              
             RESP2(WS-RESP2)                                            
           END-EXEC                                                     
                                                                        
           EVALUATE WS-RESP                                             
               WHEN DFHRESP(NORMAL)                                     
                 CONTINUE                                               
               WHEN OTHER                                               
                 MOVE DFHRED TO MSGC                                    
                 MOVE 'ERROR: FILE UPDATE FAILED' TO MSGO               
           END-EVALUATE.                                                
                                                                        
      *----------------------------------------------------------------*
      * SENDS THE FULL MAP AND ERASES THE SCREEN.                      *
      *----------------------------------------------------------------*
       SEND-MAP.                                                        
           EXEC CICS SEND                                               
             MAP('JOB1MAP')                                             
             MAPSET('JOB1SET')                                          
             FROM(JOB1MAPO)                                             
             ERASE                                                      
             CURSOR                                                     
             FREEKB                                                     
             RESP(WS-RESP)                                              
             RESP2(WS-RESP2)                                            
           END-EXEC                                                     
                                                                        
           EVALUATE WS-RESP                                             
               WHEN DFHRESP(NORMAL)                                     
                 CONTINUE                                               
               WHEN OTHER                                               
                 EXEC CICS ABEND                                        
                   ABCODE('SEND')                                       
                 END-EXEC                                               
           END-EVALUATE.                                                
                                                                        
      *----------------------------------------------------------------*
      * SENDS ONLY DATA FROM JOB1MAPO (NO ERASE, LABELS STAY).         *
      * ONLY MSG AND ITS COLOR ARE SENT. FIELDS WITH LOW-VALUES ARE NOT*
      * SENT, SO TYPED OPERATOR ID / PIN STAY ON THE SCREEN.           *
      * CURSOR GOES TO THE FIELD WITH LENGTH = -1.                     *
      *----------------------------------------------------------------*
       SEND-DATAONLY.                                                   
           EXEC CICS SEND                                               
             MAP('JOB1MAP')                                             
             MAPSET('JOB1SET')                                          
             FROM(JOB1MAPO)                                             
             DATAONLY                                                   
             CURSOR                                                     
             FREEKB                                                     
             RESP(WS-RESP)                                              
             RESP2(WS-RESP2)                                            
           END-EXEC                                                     
                                                                        
           EVALUATE WS-RESP                                             
               WHEN DFHRESP(NORMAL)                                     
                 CONTINUE                                               
               WHEN OTHER                                               
                 EXEC CICS ABEND                                        
                   ABCODE('SNDD')                                       
                 END-EXEC                                               
           END-EVALUATE.                                                
