# CICS Resource Definitions (RDO)

Resources defined interactively through CEDA for the ATM/AUTH transaction.

## Mapset

Physical map and symbolic map were already generated via JCL beforehand,
this just registers the mapset with CICS.

```
CEDA DEFINE MAPSET(JOB1SET) GROUP(ZXPRDO)
```

## Program

Registers the COBOL program that implements the AUTH transaction logic.

```
CEDA DEFINE PROGRAM(ATMPGM1) GROUP(ZXPRDO) LANGUAGE(COBOL)
```

## Transaction

Registers the transaction ID and links it to its program.

```
CEDA DEFINE TRANSACTION(AUTH) GROUP(ZXPRDO) PROGRAM(ATMPGM1)
```

## Install

```
# All at once
CEDA INSTALL GROUP(ZXPRDO)

# Or individually
CEDA INSTALL PROGRAM(ATMPGM1) GROUP(ZXPRDO)
CEDA INSTALL MAPSET(JOB1SET) GROUP(ZXPRDO)
CEDA INSTALL TRANSACTION(AUTH) GROUP(ZXPRDO)
```

## Verify

```
CEDA DISPLAY GROUP(ZXPRDO)
```

Confirms all three resources (mapset, program, transaction) are present in
the group.
