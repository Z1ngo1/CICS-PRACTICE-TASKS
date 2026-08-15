# Register the mapset (physical map + symbolic map already generated via JCL)
CEDA DEFINE MAPSET(JOB1SET) GROUP(ZXPRDO)

# Register the COBOL program that implements the AUTH transaction logic
CEDA DEFINE PROGRAM(ATMPGM1) GROUP(ZXPRDO) LANGUAGE(COBOL)

# Register the transaction ID and link it to its program
CEDA DEFINE TRANSACTION(AUTH) GROUP(ZXPRDO) PROGRAM(ATMPGM1)

# Install every resource in the group at once
CEDA INSTALL GROUP(ZXPRDO)

# OR install resources individually, if only one changed
CEDA INSTALL PROGRAM(ATMPGM1) GROUP(ZXPRDO)
CEDA INSTALL MAPSET(JOB1SET) GROUP(ZXPRDO)
CEDA INSTALL TRANSACTION(AUTH) GROUP(ZXPRDO)

# Confirm all three resources are present in the group
CEDA DISPLAY GROUP(ZXPRDO)
