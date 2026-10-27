# Task 2 - ATM Operator Authentication with VSAM Validation (Banking System)

## Overview

Second version of the ATM authorization screen from [Task 1](../TASK1). The program uses the same BMS screen (Operator ID + PIN), checks the input on the screen, and then validates the operator against a VSAM KSDS file. It reads the operator record with `READ UPDATE`, checks the account status and PIN, counts failed attempts, and locks the account after 3 wrong PINs using `REWRITE`. Runs in pseudo-conversational mode.

## Files

| Folder | File | Description |
|---|---|---|
| [`BMS`](BMS) | [`JOB1SET.bms`](BMS/JOB1SET.bms) | Mapset source - same mapset as Task 1 (`JOB1MAP` with `OPRID`, `PINCODE`, `MSG`) |
| [`COPYBOOK`](COPYBOOK) | [`JOB1SET.cpy`](COPYBOOK/JOB1SET.cpy) | Symbolic map copybook generated from the BMS mapset |
| [`COPYBOOK`](COPYBOOK) | [`OPERREC.cpy`](COPYBOOK/OPERREC.cpy) | Operator record layout (100 bytes) for the VSAM file |
| [`COBOL`](COBOL) | [`ATMPGM2.cbl`](COBOL/ATMPGM2.cbl) | Transaction program (`ATM2`) - screen checks, `READ UPDATE`, `REWRITE`, `UNLOCK`, fail counter and lock logic |
| [`JCL`](JCL) | [`MAPCOMP.jcl`](JCL/MAPCOMP.jcl) | Assembles the BMS mapset (same as Task 1, not needed if `JOB1SET` is already installed) |
| [`JCL`](JCL) | [`CICSCOB2.jcl`](JCL/CICSCOB2.jcl) | Translates, compiles and link-edits `ATMPGM2` for CICS |
| [`JCL`](JCL) | [`DEFKSDS.jcl`](JCL/DEFKSDS.jcl) | Deletes, defines and loads the operator VSAM KSDS (IDCAMS + SORT + REPRO + PRINT) |
| [`RDO`](RDO) | [`CICS-COMMANDS.md`](RDO/CICS-COMMANDS.md) | CEDA definitions (program, transaction, file), CEMT and CECI commands used for testing |
| [`DATA`](DATA) | [`OPERATOR.MASTER.BEFORE.txt`](DATA/OPERATOR.MASTER.BEFORE.txt) | Operator records before testing (loaded by `DEFKSDS.jcl`) |
| [`DATA`](DATA) | [`OPERATOR.MASTER.AFTER.txt`](DATA/OPERATOR.MASTER.AFTER.txt) | Operator records after all test scenarios |
| [`OUTPUT`](OUTPUT) | [`SYSOUT.STEP010`](OUTPUT/SYSOUT.STEP010.txt)-[`SYSOUT.STEP040`](OUTPUT/SYSOUT.STEP040.txt) `.txt` | Spool output of `DEFKSDS.jcl` for each step |
| [`SCREENSHOTS`](SCREENSHOTS) | [`01`](SCREENSHOTS/01-INITIAL-SCREEN.png)-[`19`](SCREENSHOTS/19-CECI-AFTER-SUCCESS-RESET.png) `.png` | Terminal and CECI screenshots for the key test scenarios below |

## Screen Fields

Same screen as Task 1.

| Field | Attribute | Length | Description |
|---|---|---|---|
| `OPRID` | UNPROT, FSET, IC | 8 | Operator ID - VSAM key |
| `PINCODE` | UNPROT, DRK, NUM | 4 | PIN code - numeric keyboard shift, dark (non-display), no FSET |
| `MSG` | PROT, COLOR set at runtime (RED/GREEN/YELLOW) | 40 | Output message line - text and color set by the program via `MSGO`/`MSGC` |

## VSAM File

| Property | Value |
|---|---|
| CICS file name | `ATMTASK2` |
| Dataset | `Z73460.TASK2.CICS.BANK.OPER` |
| Type | KSDS |
| Key | `OPER-ID` - 8 bytes, offset 0 |
| Record length | 100 bytes, fixed |

### Record Layout ([`OPERREC.cpy`](COPYBOOK/OPERREC.cpy))

| Field | PIC | Position | Description |
|---|---|---|---|
| `OPER-ID` | `X(8)` | 1-8 | Operator ID (key) |
| `OPER-PIN` | `9(4)` | 9-12 | PIN code |
| `OPER-NAME` | `X(30)` | 13-42 | Operator name |
| `OPER-STATUS` | `X(1)` | 43 | `A` = Active, `L` = Locked |
| `OPER-FAIL-COUNT` | `9(2)` | 44-45 | Number of failed PIN attempts in a row |
| `FILLER` | `X(55)` | 46-100 | Not used |

### Test Data

| Operator ID | PIN | Name | Status | Fail count | Used for |
|---|---|---|---|---|---|
| `OP000001` | 1234 | JOHN SMITH | A | 00 | Successful login, counter reset |
| `OP000002` | 5678 | MARY JOHNSON | A | 01 | Counter reset from 01 to 00 on success |
| `OP000003` | 9999 | LOCKED USER | L | 03 | Already locked account |
| `OP000004` | 4444 | SARAH CONNOR | L | 03 | Locked account, counter must not grow |
| `OP000005` | 5555 | JAMES BOND | A | 00 | 3 wrong PINs -> account locked |
| `OP000006` | 0123 | ALEXANDER KONSTANTINOV | A | 00 | Long name (cut on screen), PIN with leading zero |
| `OP000007` | 7777 | ANNA LEE | A | 02 | Locked on the first wrong PIN |
| `OP1` | 1111 | SHORT ID USER | A | 00 | Key shorter than 8 chars (padded with spaces) |

## Business Logic: Validation Rules

### Screen Checks (no file access)

| Condition | Message | Operator ID after | Cursor |
|---|---|---|---|
| First entry (`EIBCALEN=0`) / `CLEAR` | Blank screen | cleared | `OPRID` |
| `OPRID` empty or all spaces | `ERROR: OPERATOR ID IS REQUIRED` (red) | cleared | `OPRID` |
| `PINCODE` empty or all spaces | `ERROR: PIN CODE IS REQUIRED` (red) | kept | `PINCODE` |
| `PINCODE` not numeric (e.g. `12!4`, `12 4`) | `ERROR: PIN CODE MUST BE NUMERIC` (red) | kept | `PINCODE` |
| `PINCODE` shorter than 4 digits | `ERROR: PIN MUST CONTAIN 4 DIGITS` (red) | kept | `PINCODE` |

PIN format errors are not counted as failed attempts - the file is not read.

### File Checks

| Condition | Message | File update | Operator ID after | Cursor |
|---|---|---|---|---|
| Operator not found (`NOTFND`) | `ERROR: INVALID OPERATOR ID` (red) | - | cleared | `OPRID` |
| `OPER-STATUS = 'L'` | `ACCOUNT LOCKED` (red) | none (`UNLOCK`) | kept | `OPRID` |
| PIN correct | `ACCESS GRANTED - WELCOME <NAME>` (green) | fail count = 0 | cleared | `OPRID` |
| PIN wrong, fail count < 3 | `ERROR: INVALID PIN CODE` (red) | fail count + 1 | kept | `PINCODE` |
| PIN wrong, fail count reaches 3 | `ACCOUNT LOCKED` (red) | fail count + 1, status = `L` | kept | `OPRID` |
| File closed (`NOTOPEN`) | `ERROR: FILE IS CLOSED` (red) | - | kept | `PINCODE` |
| File disabled (`DISABLED`) | `ERROR: FILE IS DISABLED` (red) | - | kept | `PINCODE` |
| Other `READ` error | `VSAM ERROR` (red) | - | kept | `PINCODE` |
| `REWRITE` failed | `ERROR: FILE UPDATE FAILED` (red) | - | - | - |

### Keys

| Key | Result |
|---|---|
| `ENTER` | Process input (rules above) |
| `CLEAR` | Blank screen |
| `PF3` | `END OF PROGRAM. PRESS CLEAR` (turquoise), fields cleared, transaction ends |
| Any other `PF`/`PA` key | `INVALID KEY - PRESS ENTER OR F3` (yellow), entered data stays on screen |

`PINCODE` is never sent back to the screen - after every `ENTER` it must be typed again.

## Program Flow

1. **Routing** - the program checks `EIBCALEN` first, then `EIBAID`. `RECEIVE MAP` is issued only when `ENTER` is pressed.
2. **First entry / CLEAR** - send the blank map with `ERASE`, cursor on `OPRID`.
3. **PF3** - send `END OF PROGRAM. PRESS CLEAR` with `ERASE`, then `RETURN` without `TRANSID` - the pseudo-conversation ends.
4. **ENTER** - `RECEIVE MAP` (`MAPFAIL` is treated as empty input). The entered ID, PIN and their lengths are copied to WORKING-STORAGE, then `JOB1MAPO` is cleared (`JOB1MAPO` redefines `JOB1MAPI`).
5. **Screen checks** - ID not empty → PIN not empty → PIN numeric → PIN length = 4. The first error is sent back and the program returns.
6. **READ UPDATE** - read the operator record by `OPER-ID`. The record is locked until `REWRITE` or `UNLOCK`. `NOTFND`, `NOTOPEN`, `DISABLED` and other errors are shown as messages.
7. **VALIDATE-CREDENTIALS**:
   - status `L` → `UNLOCK` the record, `ACCOUNT LOCKED`;
   - PIN correct → fail count = 0, `ACCESS GRANTED - WELCOME <NAME>`;
   - PIN wrong → fail count + 1; if it reaches 3, status = `L` and `ACCOUNT LOCKED`, otherwise `INVALID PIN CODE`.
8. **REWRITE** - the updated record is written back (only after a PIN check). If `REWRITE` fails, the message is replaced with `FILE UPDATE FAILED`.
9. **Send result** - every `ENTER` result is sent as a full map with `ERASE`, so old data and old message color are removed. Only a wrong key uses `SEND MAP DATAONLY`, so the entered data stays on screen.
10. **Return** - every path except PF3 ends with `RETURN TRANSID('ATM2') COMMAREA(...)`. The 1-byte COMMAREA carries no data; the fail counter is kept in the VSAM file.

## Manual Test Scenarios

All scenarios below were executed manually on the 3270 terminal emulator. File values were checked with CECI after each step (see [`CICS-COMMANDS.md`](RDO/CICS-COMMANDS.md)). Before testing, the file was loaded with [`OPERATOR.MASTER.BEFORE.txt`](DATA/OPERATOR.MASTER.BEFORE.txt); after all scenarios in order, it matches [`OPERATOR.MASTER.AFTER.txt`](DATA/OPERATOR.MASTER.AFTER.txt).

### A. Start and keys

1. Clear the screen, type `ATM2` - blank map, cursor on `OPRID` - **PASSED** ([screenshot](SCREENSHOTS/01-INITIAL-SCREEN.png))
2. `ENTER` on an empty screen - `OPERATOR ID IS REQUIRED` (red), cursor on `OPRID` - **PASSED**
3. `CLEAR` after an error - map, fields and message cleared - **PASSED**
4. `PF1` / `PF5` / `PF12` - `INVALID KEY - PRESS ENTER OR F3` (yellow) - **PASSED** ([screenshot](SCREENSHOTS/02-INVALID-KEY-PRESSED.png))
5. `PA1` / `PA2` - same as A4 - **PASSED**
6. Type ID and PIN, press `PF5` - yellow message, entered data stays on screen - **PASSED**
7. Press `ENTER` after A6 - data is processed as normal input - **PASSED**
8. `PF3` after a red error with data on screen - `END OF PROGRAM. PRESS CLEAR` in turquoise, fields cleared - **PASSED** ([screenshot](SCREENSHOTS/03-END-OF-PROGRAM.png))
9. `ENTER` after `PF3` - CICS message "transaction not recognized" (session is really closed) - **PASSED**
10. `CLEAR` + `ATM2` after `PF3` - transaction starts again - **PASSED**

### B. Screen checks

1. Empty ID + empty PIN - `OPERATOR ID IS REQUIRED`, cursor on `OPRID` - **PASSED** ([screenshot](SCREENSHOTS/04-VALIDATION-ERROR-OPRID.png))
2. ID filled with spaces - `OPERATOR ID IS REQUIRED` - **PASSED**
3. `OP000001` + empty PIN - `PIN CODE IS REQUIRED`, ID kept, cursor on `PINCODE` - **PASSED** ([screenshot](SCREENSHOTS/05-VALIDATION-ERROR-PIN.png))
4. `OP000001` + 4 spaces - `PIN CODE IS REQUIRED` - **PASSED**
5. `OP000001` + `12!4` - `PIN CODE MUST BE NUMERIC`, ID kept, PIN cleared - **PASSED** ([screenshot](SCREENSHOTS/06-VALIDATION-ERROR-PIN-NUMERIC.png))
6. `OP000001` + `12 4` - `PIN CODE MUST BE NUMERIC` - **PASSED**
7. Right after B6, type only `12` - `PIN MUST CONTAIN 4 DIGITS` (the old PIN is not left in the field) - **PASSED** ([screenshot](SCREENSHOTS/07-VALIDATION-ERROR-PIN-LENGTH.png))
8. `OP000001` + `123` - `PIN MUST CONTAIN 4 DIGITS` - **PASSED**
9. After B3-B8, CECI shows `OP000001` fail count still `00` - format errors are not counted - **PASSED**

### C. File lookup

1. `OP999999` + `1234` - `INVALID OPERATOR ID`, fields cleared, cursor on `OPRID` - **PASSED** ([screenshot](SCREENSHOTS/08-INVALID-OPERATOR-ID.png))
2. `OP1` (short key) + `1111` - `ACCESS GRANTED - WELCOME SHORT ID USER` - key is padded with spaces - **PASSED**
3. `op000001` (lowercase) + `1234` - input is translated to uppercase by the terminal, login works - **PASSED**

### D. Login, fail counter and lock

| # | Input | Expected message | Screen after | File after (CECI) | Result |
|---|---|---|---|---|---|
| 1 | `OP000001` / `1234` | `ACCESS GRANTED - WELCOME JOHN SMITH` (green) | cleared | `A00` | **PASSED** ([screenshot](SCREENSHOTS/09-ACCESS-GRANTED.png)) |
| 2 | `OP000002` / `5678` | `ACCESS GRANTED` | cleared | `A01` → `A00` | **PASSED** ([before](SCREENSHOTS/18-CECI-BEFORE-SUCCESS-RESET.png), [after](SCREENSHOTS/19-CECI-AFTER-SUCCESS-RESET.png)) |
| 3 | `OP000005` / `0000` | `INVALID PIN CODE` (red) | ID kept, cursor on PIN | `A00` → `A01` | **PASSED** ([screenshot](SCREENSHOTS/10-INVALID-PIN.png), [before](SCREENSHOTS/15-CECI-BEFORE.png), [after](SCREENSHOTS/16-CECI-AFTER-FAIL.png)) |
| 4 | (ID on screen) / `1111` | `INVALID PIN CODE` | ID kept | `A02` | **PASSED** |
| 5 | (ID on screen) / `2222` | `ACCOUNT LOCKED` (red) | ID kept, cursor on ID | `L03` | **PASSED** ([CECI](SCREENSHOTS/17-CECI-LOCKED-AFTER-3ATTEMPTS.png)) |
| 6 | `OP000005` / `5555` (correct PIN) | `ACCOUNT LOCKED` | ID kept | `L03` (no change) | **PASSED** |
| 7 | `OP000007` / `0000` | `ACCOUNT LOCKED` on the first wrong PIN | ID kept | `A02` → `L03` | **PASSED** |
| 8 | `OP000003` / `9999` | `ACCOUNT LOCKED` | ID kept | `L03` (no change) | **PASSED** ([screenshot](SCREENSHOTS/11-ACCOUNT-LOCKED.png)) |
| 9 | `OP000004` / `1234` | `ACCOUNT LOCKED` | ID kept | `L03`, not `L04` | **PASSED** |
| 10 | `OP000001`: wrong, wrong, then `1234` | `ACCESS GRANTED` | cleared | `00` (not `02`) | **PASSED** |
| 11 | `OP000001` wrong PIN after D10 | `INVALID PIN CODE` | ID kept | `01` - count starts again | **PASSED** |
| 12 | `OP000006` / `0123` | `ACCESS GRANTED - WELCOME ALEXANDER KONST` (name cut) | cleared | `A00` | **PASSED** ([screenshot](SCREENSHOTS/12-NAME-TRUNCATED.png)) |
| 13 | `OP000006` / `123` | `PIN MUST CONTAIN 4 DIGITS` (not a login with `0123`) | ID kept | no change | **PASSED** |
| 14 | After D5 (`OP000005` on screen), type `OP1` over it + `1111` | `INVALID OPERATOR ID` - field contains `OP1000005` | cleared | - | **PASSED** (terminal behavior, see Notes) |
| 15 | Same as D14, but clear the field with `ERASE EOF` first | `ACCESS GRANTED - WELCOME SHORT ID USER` | cleared | `A00` | **PASSED** |

### E. File state

1. `CEMT SET FILE(ATMTASK2) CLOSED`, then `OP000001` / `1234` - `FILE IS CLOSED`, ID kept, cursor on PIN - **PASSED** ([screenshot](SCREENSHOTS/13-FILE-CLOSED.png))
2. `CEMT SET FILE(ATMTASK2) OPEN DISABLED`, then the same input - `FILE IS DISABLED` - **PASSED** ([screenshot](SCREENSHOTS/14-FILE-DISABLED.png))
3. `CEMT SET FILE(ATMTASK2) ENABLED`, then the same input - login works again - **PASSED**
4. File defined with `UPDATE(NO)` - `READ UPDATE` returns `INVREQ` - `VSAM ERROR` - **PASSED**

In E1-E2 the file is not read, so the fail counter does not change.

### F. Screen transitions and terminal

1. `ENTER` again after an error without changes - error is shown again correctly - **PASSED**
2. Error (red) → success (green) → error (red) - message color is correct each time - **PASSED**
3. Long success message, then a short error - no part of the old message is left - **PASSED**
4. Wrong key (yellow), then `ENTER` with an error - red, no yellow left - **PASSED**
5. `PINCODE` is hidden while typing (`DRK`) - **PASSED**
6. More than 8 chars in ID / more than 4 in PIN - blocked by the terminal - **PASSED**

The `REWRITE` error branch (`FILE UPDATE FAILED`) is handled in the code but was not tested manually - it is hard to cause in normal conditions.

## How to Run

1. **Mapset** - `JOB1SET` from Task 1 is used. If it is not installed yet, run [`MAPCOMP.jcl`](JCL/MAPCOMP.jcl).
2. **Copybook** - put [`OPERREC.cpy`](COPYBOOK/OPERREC.cpy) into the copybook library from `SYSLIB` in `CICSCOB2.jcl`.
3. **Compile the program** - run [`CICSCOB2.jcl`](JCL/CICSCOB2.jcl) to compile [`ATMPGM2.cbl`](COBOL/ATMPGM2.cbl) for CICS.
4. **Create and load the VSAM file** - close the file in CICS if it is already defined (`CEMT SET FILE(ATMTASK2) CLOSED`), then run [`DEFKSDS.jcl`](JCL/DEFKSDS.jcl). Check the loaded records in [`SYSOUT.STEP040.txt`](OUTPUT/SYSOUT.STEP040.txt).
5. **Define and install resources** - follow [`CICS-COMMANDS.md`](RDO/CICS-COMMANDS.md) to define the program, transaction (`ATM2`) and file (`ATMTASK2`).
6. **Open the file** - `CEMT SET FILE(ATMTASK2) OPEN ENABLED`.
7. **Run the transaction** - clear the screen, type `ATM2` and press ENTER.

After each recompile: `CEMT SET PROGRAM(ATMPGM2) NEWCOPY`. After reloading the file with `DEFKSDS.jcl`, CEDA definitions do not need to change - just open the file again.

## Key CICS/COBOL Concepts Used

- `EXEC CICS READ ... UPDATE` - read a record and lock it for update
- `EXEC CICS REWRITE` - update the locked record (fail counter, status)
- `EXEC CICS UNLOCK` - release the lock when the record is not changed
- `RESP` handling for `NORMAL`, `NOTFND`, `NOTOPEN`, `DISABLED`, `MAPFAIL` and other conditions
- `RIDFLD` with an 8-byte key, padding short keys with spaces
- CICS file definition (`CEDA DEFINE FILE`) - RDO equivalent of an FCT entry
- `SEND MAP ... ERASE` vs `SEND MAP DATAONLY` - full redisplay vs message-only refresh
- Saving input from `JOB1MAPI` before clearing `JOB1MAPO` (the two maps redefine the same storage)
- Symbolic cursor positioning (`MOVE -1 TO fieldL` + `CURSOR`)
- BMS `NUM` field - right-justified and zero-filled, so PIN length is checked with `PINCODEL`
- `RETURN TRANSID('ATM2') COMMAREA` for pseudo-conversational processing
- CECI for checking VSAM records and CEMT for file state and `NEWCOPY`
- IDCAMS `DELETE` / `DEFINE CLUSTER` / `REPRO` / `PRINT`, SORT to build fixed 100-byte records

## Notes

- **Name length limit** - `MSG` is 40 characters, and `ACCESS GRANTED - WELCOME ` takes 25 of them, so only the first 15 characters of `OPER-NAME` are shown (see D12). The mapset is shared with Task 1, so the field was not made longer.
- **Operator ID after `ACCOUNT LOCKED`** - the ID stays on screen so the operator can see which account is locked. If a shorter ID is typed over it, the end of the old ID stays in the field (D14). Use `ERASE EOF` before typing a new ID.
- **Fail counter** is stored in the VSAM file, not in the COMMAREA - it is kept between sessions and terminals. The COMMAREA is a 1-byte placeholder that only makes `EIBCALEN` non-zero.
- **File must be closed in CICS** before running `DEFKSDS.jcl`, otherwise `DELETE` fails with "allocated to another job or user" and `DEFINE` fails with "duplicate data set name".
- **AFTER data** depends on the order of test steps - [`OPERATOR.MASTER.AFTER.txt`](DATA/OPERATOR.MASTER.AFTER.txt) shows the result of running scenarios A-F once, in order.
- Tested manually on a 3270 terminal emulator connected to a z/OS CICS region.
