# CICS Setup (RDO, CEMT, CECI)

Resources defined through CEDA for the ATM2 transaction, plus CEMT and CECI
commands used to run and test it.

## Mapset

No new definition needed. The program uses mapset `JOB1SET` from Task 1,
which is already defined and installed in group `ZXPRDO`.

## Program

Registers the COBOL program that implements the ATM2 transaction logic.

```
CEDA DEFINE PROGRAM(ATMPGM2) GROUP(ZXPRDO) LANGUAGE(COBOL)
```

## Transaction

Registers the transaction ID and links it to its program.

```
CEDA DEFINE TRANSACTION(ATM2) GROUP(ZXPRDO) PROGRAM(ATMPGM2)
```

## File

Registers the VSAM KSDS with CICS. This is the RDO equivalent of an FCT
entry. The program uses the file name `ATMTASK2` in `READ`, `REWRITE` and
`UNLOCK`; CICS links this name to the real dataset through `DSNAME`.

```
CEDA DEFINE FILE(ATMTASK2) GROUP(ZXPRDO)
     DSNAME(TASK2.CICS.BANK.OPER)
     RECORDFORMAT(F)
     READ(YES) UPDATE(YES)
     ADD(NO) DELETE(NO) BROWSE(NO)
```

| Attribute | Value | Why |
|---|---|---|
| `READ` | `YES` | program reads operator records |
| `UPDATE` | `YES` | needed for `READ UPDATE` and `REWRITE` (fail counter, status) |
| `ADD` / `DELETE` / `BROWSE` | `NO` | program never adds, deletes or browses records |
| `RECORDFORMAT` | `F` | all records are 100 bytes |

## Install

```
# All at once
CEDA INSTALL GROUP(ZXPRDO)

# Or individually
CEDA INSTALL PROGRAM(ATMPGM2) GROUP(ZXPRDO)
CEDA INSTALL TRANSACTION(ATM2) GROUP(ZXPRDO)
CEDA INSTALL FILE(ATMTASK2) GROUP(ZXPRDO)
```

## Verify

```
CEDA DISPLAY GROUP(ZXPRDO)
CEMT INQUIRE FILE(ATMTASK2)
```

`CEDA DISPLAY` confirms that the program, transaction and file are in the
group. `CEMT INQUIRE FILE` shows the current file state (open/closed,
enabled/disabled).

## Useful CEMT Commands

```
# Close the file before reloading it with IDCAMS (DELETE/DEFINE/REPRO)
CEMT SET FILE(ATMTASK2) CLOSED

# Open and enable the file again after reloading
CEMT SET FILE(ATMTASK2) OPEN ENABLED

# Disable the file (used for test E2 - 'FILE IS DISABLED')
CEMT SET FILE(ATMTASK2) DISABLED

# Load the new version of the program after each recompile
CEMT SET PROGRAM(ATMPGM2) NEWCOPY
```

## Check Records (CECI)

Reads one record without a program. Used during tests to check the fail
counter and status after each attempt.

```
CECI READ FILE(ATMTASK2) RIDFLD(OP000001)
```

Press ENTER twice. The record is shown in `INTO(...)`. Status and fail
counter are the 3 characters right after the name (e.g. `A00`, `L03`).
For a short key, pad it to 8 chars: `RIDFLD('OP1     ')`.
Do not add `UPDATE` in CECI - it would lock the record.
