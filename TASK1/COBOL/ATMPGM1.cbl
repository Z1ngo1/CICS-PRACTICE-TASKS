      *----------------------------------------------------------------*
      * CICS PSEUDO-CONVERSATIONAL LOGON SCREEN - ATM OPERATOR AUTH    *
      *                                                                *
      * PURPOSE:                                                       *
      * FIRST SCREEN OF THE ATM AUTHORIZATION MODULE. DISPLAYS THE     *
      * LOGON MAP, ACCEPTS OPERATOR ID + PIN, AND VALIDATES THE INPUT  *
      * ON THE SCREEN LEVEL ONLY (NO FILE / DATABASE LOOKUP).          *
      *                                                                *
      * BUSINESS LOGIC:                                                *
      *   FIRST ENTRY / CLEAR - SEND BLANK LOGON MAP.                  *
      *   ENTER - RECEIVE MAP, VALIDATE OPERATOR ID + PIN, SEND MAP    *
      *           BACK WITH RESULT MESSAGE (RED = ERROR,               *
      *           GREEN = SUCCESS).                                    *
      *   PF3   - END THE TRANSACTION.                                 *
      *   OTHER - RE-DISPLAY MAP WITH 'INVALID KEY PRESSED'.           *
      *                                                                *
      * AUTHOR: STANISLAV                                              *
      * DATE: 2026/02/18                                               *
      *                                                                *
      * CICS RESOURCES:                                                *
      * TRANSID: AUTH                                                  *
      * MAPSET:  JOB1SET (COPY)                                        *
      * MAP:     JOB1MAP - OPERATOR ID (8), PIN (4, DARK), MSG (40)    *
      *----------------------------------------------------------------*
                                                                        
       IDENTIFICATION DIVISION.                                         
       PROGRAM-ID. ATMPGM1.                                             
       ENVIRONMENT DIVISION.                                            
       DATA DIVISION.                                                   
       WORKING-STORAGE SECTION.                                         
                                                                        
      * CICS / BMS COPYBOOKS                                            
          COPY DFHAID.                                                  
          COPY DFHBMSCA.                                                
          COPY JOB1SET.                                                 
                                                                        
      * RESP/RESP2 CODES RETURNED BY EXEC CICS RECEIVE MAP              
       01 WS-RESP         PIC S9(8) COMP.                               
       01 WS-RESP2        PIC S9(8) COMP.                               
                                                                        
      * WORKING VARIABLES                                               
       01 WS-PINCODE      PIC X(4).                                     
                                                                        
      * COMMAREA LAYOUT                                                 
      *-------------------------------------------------------------*   
      * NOTE: A NON-ZERO COMMAREA LENGTH ON RETURN IS MANDATORY,    *   
      * OTHERWISE EIBCALEN WILL BE ZERO ON THE NEXT INVOCATION, AND *   
      * MAIN-LOGIC WILL ALWAYS TREAT IT AS THE FIRST ENTRY          *   
      *-------------------------------------------------------------*   
       01 WS-COMMAREA.                                                  
          05 CA-OPRID     PIC X(1) VALUE SPACES.                        
                                                                        
       LINKAGE SECTION.                                                 
                                                                        
       01 DFHCOMMAREA     PIC X(1).                                     
                                                                        
       PROCEDURE DIVISION.                                              
                                                                        
      *----------------------------------------------------------------*
      * MAINLINE. ROUTES BASED ON EIBCALEN/EIBAID:                     *
      * FIRST ENTRY OR CLEAR -> BLANK MAP.                             *
      * ENTER  -> RECEIVE, VALIDATE (SENDS UPDATE INTERNALLY), RETURN. *
      * PF3    -> END TRANSACTION.                                     *
      * OTHER  -> RE-SEND MAP WITH ERROR MESSAGE.                      *
      *----------------------------------------------------------------*
       MAIN-LOGIC.                                                      
           EVALUATE TRUE                                                
               WHEN EIBCALEN = ZERO                                     
                 MOVE LOW-VALUES TO JOB1MAPO                            
                 PERFORM SEND-MAP                                       
               WHEN EIBAID = DFHCLEAR                                   
                 MOVE LOW-VALUES TO JOB1MAPO                            
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
                  PERFORM RECEIVE-MAP                                   
                  PERFORM VALIDATE-OPRID                                
               WHEN OTHER                                               
                 MOVE LOW-VALUES TO JOB1MAPO                            
                 MOVE DFHYELLO TO MSGC                                  
                 MOVE 'INVALID KEY PRESSED' TO MSGO                     
                 PERFORM SEND-MAP                                       
           END-EVALUATE                                                 
                                                                        
           PERFORM RETURN-TRANS.                                        
                                                                        
      *---------------------------------------------------------*       
      * VALIDATES OPERATOR ID AND PIN ENTERED ON THE LOGON MAP. *       
      * VALIDATION CASCADE (STOPS AT FIRST FAILURE):            *       
      *   1. OPERATOR ID NOT ENTERED / BLANK.                   *       
      *   2. PIN NOT ENTERED / BLANK.                           *       
      *   3. PIN NOT NUMERIC.                                   *       
      *   4. ALL CHECKS PASSED -> SUCCESS MESSAGE.              *       
      * RESULT COLOR/TEXT PLACED INTO MSGC / MSGO FOR           *       
      * SEND-MAP-UPDATE TO DISPLAY.                             *       
      *---------------------------------------------------------*       
       VALIDATE-OPRID.                                                  
           IF OPRIDL = ZERO OR OPRIDI = SPACES OR OPRIDI = LOW-VALUES   
              MOVE LOW-VALUES TO JOB1MAPO                               
              MOVE DFHRED TO MSGC                                       
              MOVE 'OPERATOR ID IS REQUIRED' TO MSGO                    
              MOVE -1 TO OPRIDL                                         
              MOVE SPACES TO OPRIDO                                     
              PERFORM SEND-MAP-UPDATE                                   
              EXIT PARAGRAPH                                            
           END-IF                                                       
                                                                        
           MOVE SPACES TO MSGO                                          
           PERFORM VALIDATE-PINCODE.                                    
                                                                        
      *---------------------------------------------*                   
      * VALIDATES PIN: NOT BLANK, EXACTLY 4 DIGITS. *                   
      * ON SUCCESS, SETS THE GREEN SUCCESS MESSAGE. *                   
      *---------------------------------------------*                   
       VALIDATE-PINCODE.                                                
           MOVE PINCODEI TO WS-PINCODE                                  
           INSPECT WS-PINCODE REPLACING ALL LOW-VALUES BY SPACE         
                                                                        
           IF PINCODEL = ZERO OR WS-PINCODE = SPACES                    
              MOVE LOW-VALUES TO JOB1MAPO                               
              MOVE DFHRED TO MSGC                                       
              MOVE 'PIN CODE MUST BE ENTERED' TO MSGO                   
              MOVE OPRIDI TO OPRIDO                                     
              MOVE SPACES TO PINCODEO                                   
              MOVE -1 TO PINCODEL                                       
              PERFORM SEND-MAP-UPDATE                                   
              EXIT PARAGRAPH                                            
           END-IF                                                       
                                                                        
           IF PINCODEL NOT = 4 OR WS-PINCODE NOT NUMERIC                
              MOVE LOW-VALUES TO JOB1MAPO                               
              MOVE DFHRED TO MSGC                                       
              MOVE 'PIN CODE MUST CONTAIN 4 DIGITS' TO MSGO             
              MOVE OPRIDI TO OPRIDO                                     
              MOVE SPACES TO PINCODEO                                   
              MOVE -1 TO PINCODEL                                       
              PERFORM SEND-MAP-UPDATE                                   
              EXIT PARAGRAPH                                            
           END-IF                                                       
                                                                        
           MOVE DFHGREEN TO MSGC                                        
           MOVE 'AUTHORIZATION SUCCESSFUL' TO MSGO                      
           MOVE SPACES TO OPRIDO                                        
           MOVE SPACES TO PINCODEO                                      
           MOVE -1 TO OPRIDL                                            
           PERFORM SEND-MAP-UPDATE.                                     
                                                                        
      *--------------------------------------------*                    
      * SENDS JOB1MAP TO THE TERMINAL, ERASING THE *                    
      * PREVIOUS SCREEN CONTENT.                   *                    
      *--------------------------------------------*                    
       SEND-MAP.                                                        
           EXEC CICS SEND                                               
             MAP    ('JOB1MAP')                                         
             MAPSET ('JOB1SET')                                         
             FROM   (JOB1MAPO)                                          
             ERASE                                                      
             RESP   (WS-RESP)                                           
             RESP2  (WS-RESP2)                                          
           END-EXEC.                                                    
                                                                        
           EVALUATE WS-RESP                                             
               WHEN DFHRESP(NORMAL)                                     
                 CONTINUE                                               
               WHEN OTHER                                               
                 EXEC CICS ABEND                                        
                   ABCODE ('SEND')                                      
                 END-EXEC                                               
           END-EVALUATE.                                                
                                                                        
      *----------------------------------------------*                  
      * RETURNS CONTROL TO CICS, KEEPING THE         *                  
      * TRANSACTION PSEUDO-CONVERSATIONAL (WAITS FOR *                  
      * THE NEXT AID KEY UNDER TRANSID AUTH).        *                  
      *----------------------------------------------*                  
       RETURN-TRANS.                                                    
           EXEC CICS RETURN                                             
             TRANSID  ('AUTH')                                          
             COMMAREA (WS-COMMAREA)                                     
             LENGTH   (LENGTH OF WS-COMMAREA)                           
           END-EXEC.                                                    
                                                                        
      *------------------------------------------------*                
      * RECEIVES OPERATOR INPUT FROM JOB1MAP.          *                
      * NORMAL  - CONTINUE TO VALIDATION.              *                
      * MAPFAIL - NO DATA CHANGED, TREAT AS BLANK MAP. *                
      * OTHER   - ABEND WITH CODE 'RCVE' (UNEXPECTED)  *                
      *           CICS CONDITION).                     *                
      *------------------------------------------------*                
       RECEIVE-MAP.                                                     
           MOVE LOW-VALUES TO JOB1MAPI                                  
                                                                        
           EXEC CICS RECEIVE                                            
             MAP    ('JOB1MAP')                                         
             MAPSET ('JOB1SET')                                         
             INTO   (JOB1MAPI)                                          
             RESP   (WS-RESP)                                           
             RESP2  (WS-RESP2)                                          
           END-EXEC.                                                    
                                                                        
            EVALUATE WS-RESP                                            
                WHEN DFHRESP(NORMAL)                                    
                  CONTINUE                                              
                WHEN DFHRESP(MAPFAIL)                                   
                  MOVE LOW-VALUES TO JOB1MAPO                           
                WHEN OTHER                                              
                  EXEC CICS ABEND                                       
                    ABCODE ('RCVE')                                     
                  END-EXEC                                              
            END-EVALUATE.                                               
                                                                        
      *---------------------------------------------------*             
      * SENDS ONLY UPDATED DATA (NO ATTRIBUTES REBUILD,   *             
      * NO ERASE). USED AFTER VALIDATION SO OPRID/PINCODE *             
      * KEEP THEIR ENTERED VALUES AND THE CURSOR CAN BE   *             
      * DYNAMICALLY REPOSITIONED VIA -1 IN THE L-FIELD.   *             
      *---------------------------------------------------*             
       SEND-MAP-UPDATE.                                                 
           EXEC CICS SEND                                               
             MAP      ('JOB1MAP')                                       
             MAPSET   ('JOB1SET')                                       
             FROM     (JOB1MAPO)                                        
             DATAONLY                                                   
             CURSOR                                                     
             RESP     (WS-RESP)                                         
             RESP2    (WS-RESP2)                                        
           END-EXEC.                                                    
                                                                        
           EVALUATE WS-RESP                                             
               WHEN DFHRESP(NORMAL)                                     
                 CONTINUE                                               
               WHEN OTHER                                               
                 EXEC CICS ABEND                                        
                   ABCODE ('SNDD')                                      
                 END-EXEC                                               
           END-EVALUATE.                                                
