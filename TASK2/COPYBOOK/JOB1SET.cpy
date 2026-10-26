       01  JOB1MAPI.                                                    
           02  FILLER PIC X(12).                                        
           02  OPRIDL    COMP  PIC  S9(4).                              
           02  OPRIDF    PICTURE X.                                     
           02  FILLER REDEFINES OPRIDF.                                 
             03 OPRIDA    PICTURE X.                                    
           02  FILLER   PICTURE X(2).                                   
           02  OPRIDI  PIC X(8).                                        
           02  PINCODEL    COMP  PIC  S9(4).                            
           02  PINCODEF    PICTURE X.                                   
           02  FILLER REDEFINES PINCODEF.                               
             03 PINCODEA    PICTURE X.                                  
           02  FILLER   PICTURE X(2).                                   
           02  PINCODEI  PIC 9(4).                                      
           02  MSGL    COMP  PIC  S9(4).                                
           02  MSGF    PICTURE X.                                       
           02  FILLER REDEFINES MSGF.                                   
             03 MSGA    PICTURE X.                                      
           02  FILLER   PICTURE X(2).                                   
           02  MSGI  PIC X(40).                                         
       01  JOB1MAPO REDEFINES JOB1MAPI.                                 
           02  FILLER PIC X(12).                                        
           02  FILLER PICTURE X(3).                                     
           02  OPRIDC    PICTURE X.                                     
           02  OPRIDH    PICTURE X.                                     
           02  OPRIDO  PIC X(8).                                        
           02  FILLER PICTURE X(3).                                     
           02  PINCODEC    PICTURE X.                                   
           02  PINCODEH    PICTURE X.                                   
           02  PINCODEO  PIC X(4).                                      
           02  FILLER PICTURE X(3).                                     
           02  MSGC    PICTURE X.                                       
           02  MSGH    PICTURE X.                                       
           02  MSGO  PIC X(40).                                         
