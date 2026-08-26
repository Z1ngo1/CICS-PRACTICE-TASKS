# Task 1 - Simple CICS Authorization Screen (ATM Banking System)

## Overview

First CICS screen of an ATM authorization module. The program displays a screen requesting Operator ID (8 chars) and PIN code (4 digits), validates the input on ENTER, and shows the result via a color-coded message field. Runs in pseudo-conversational mode with no file/DB access - validation is done entirely on the screen data.

## Files

| Folder | File | Description |
|---|---|---|
| [`BMS`](BMS) | [`JOB1SET.bms`](BMS/JOB1SET.bms) | Mapset source - map `JOB1MAP` with OPERID, PINCODE and MSG fields |
| [`COPYBOOK`](COPYBOOK) | [`JOB1SET.cpy`](COPYBOOK/JOB1SET.cpy) | Symbolic map copybook generated from the BMS mapset |
| [`COBOL`](COBOL) | [`ATMPGM1.cbl`](COBOL/ATMPGM1.cbl) | Transaction program (`AUTH`) - EIBCALEN check, RECEIVE MAP, validation, SEND MAP |
| [`JCL`](JCL) | [`MAPCOMP.jcl`](JCL/MAPCOMP.jcl) | Assembles/compiles the BMS mapset into a load module + copybook |
| [`JCL`](JCL) | [`CICSCOB2.jcl`](JCL/CICSCOB2.jcl) | Compiles the COBOL program for CICS |
| [`RDO`](RDO) | [`CEDA.md`](RDO/CEDA.md) | CEDA resource definitions (mapset, program, transaction) and install/verify commands |
| [`SCREENSHOTS`](SCREENSHOTS) | [`01`](SCREENSHOTS/01-INITIAL-SCREEN.png)-[`08`](SCREENSHOTS/08-AUTHORIZATION-SUCCESSFUL.png) `.png` | Terminal screenshots for each test scenario below |

## Screen Fields

| Field | Attribute | Length | Description |
|---|---|---|---|
| `OPRID` | UNPROT, FSET, IC | 8 | Operator ID - unprotected, cursor positioned here on first input |
| `PINCODE` | UNPROT, DRK, NUM | 4 | PIN code - numeric-only keyboard, dark (non-display) for privacy |
| `MSGO` | PROT, COLOR (RED/GREEN/YELLOW) | - | Output message line - color switches depending on result |

## Business Logic: Validation Rules

| Condition | Message | Cursor Position |
|---|---|---|
| First entry (`EIBCALEN=0`) | Blank screen sent once | `OPRID` |
| `OPRID` empty or all spaces | `OPERATOR ID IS REQUIRED` (red) | `OPRID` |
| `OPRID` filled, `PINCODE` empty/spaces | `PIN CODE MUST BE ENTERED` (red) | `PINCODE` |
| `PINCODE` contains non-numeric data (e.g. `!`) | `PIN CODE MUST BE NUMERIC` (red) | `PINCODE` |
| `PINCODE` numeric but not exactly 4 digits | `PIN CODE MUST CONTAIN 4 DIGITS` (red) | `PINCODE` |
| `OPRID` and `PINCODE` both valid | `AUTHORIZATION SUCCESSFUL` (green), fields cleared | `OPRID` |
| `CLEAR` pressed | Screen, message and COMMAREA reset | `OPRID` |
| `PF3` pressed | `END OF PROGRAM. PRESS CLEAR`, transaction ends | - |
| Any other `PF`/`PA` key | `INVALID KEY PRESSED` (yellow) | current field |

## Program Flow

1. **First entry** (`EIBCALEN=0`) - send the blank map once, set cursor to `OPRID`, return with `TRANSID(AUTH)` and empty COMMAREA.
2. **RECEIVE MAP** to read the operator's input (`OPRID`, `PINCODE`) and check `EIBAID`.
3. **CLEAR** - reset the map, message and COMMAREA, re-send blank screen.
4. **PF3** - send `END OF PROGRAM. PRESS CLEAR` message and terminate the transaction (no further RETURN with TRANSID).
5. **Other PF/PA keys** - send `INVALID KEY PRESSED` in yellow, keep entered data on screen.
6. **ENTER** - validate in order: `OPRID` not empty → `PINCODE` not empty → `PINCODE` numeric → `PINCODE` exactly 4 digits → on success send `AUTHORIZATION SUCCESSFUL` in green and clear the fields for the next operator.
7. Every SEND MAP after the first uses `DATAONLY` to refresh only `MSGO` and its color attribute without re-sending the whole map.

## Manual Test Scenarios

All scenarios below were executed manually on the 3270 terminal emulator; results are in English only, matching the actual test log.

### Basic flow

1. First entry (`EIBCALEN=0`) - blank screen, cursor on `OPRID`, map sent exactly once (no duplicate send) - **PASSED**
2. `CLEAR` - screen resets, fields and `MSGO` cleared, COMMAREA reset to zero - **PASSED**
3. `ENTER` with valid ID + PIN - `AUTHORIZATION SUCCESSFUL` in green, fields cleared - **PASSED**
4. `PF3` - `END OF PROGRAM. PRESS CLEAR` displayed, transaction ends - **PASSED**
5. Any key pressed again after `PF3` - CICS system message "transaction not recognized" (session is really closed) - **PASSED**
6. Any other `PF`/`PA` key - `INVALID KEY PRESSED` in yellow - on the very first execution of the transaction, `OPERATOR ID IS REQUIRED` fires first, then `INVALID KEY PRESSED` on the next key press; behaves normally afterwards

### Validation

1. Empty `OPRID` + empty `PINCODE` - `OPERATOR ID IS REQUIRED`, cursor on `OPRID` - **PASSED**
2. `OPRID` filled with spaces only - `OPERATOR ID IS REQUIRED`, cursor on `OPRID` - **PASSED**
3. `OPRID` filled, `PINCODE` empty - `PIN CODE MUST BE ENTERED`, cursor on `PINCODE` (not `OPRID`) - **PASSED**
4. `PINCODE` filled with spaces only - `PIN CODE MUST BE ENTERED`, cursor on `PINCODE` - **PASSED**
5. `PINCODE` with a special character (e.g. `!`) - `PIN CODE MUST BE NUMERIC`, cursor on `PINCODE` - **PASSED** (field is `PIC 9(4)` with `NUM` attribute in BMS, so letters cannot be typed, but special characters like `!` are handled correctly)
6. `PINCODE` exactly 4 digits - success - **PASSED**
7. `PINCODE` entered partially (e.g. 2 of 4 digits, field not FSET) - must be caught as an error (regression check - previously FSET protected this case, now it doesn't) - **PASSED**
8. `OPRID` shorter than 8 characters - **PASSED**
9. `OPRID` exactly 8 characters - **PASSED**
10. Tab through `PINCODE` without entering data (field untouched, FSET removed in BMS) - must still be caught as `PIN CODE MUST BE ENTERED`, not skipped as garbage - **PASSED**
11. Pressing `ENTER` again after an error, without changes - error is redisplayed correctly - **PASSED**
12. After a successful authorization, change `PINCODE` to an invalid value and press `ENTER` again - the new error overwrites correctly - **PASSED** (fields are fully cleared after a successful authorization)
13. After an `OPRID` error - previously entered `PINCODE` is not lost on screen - **PASSED**

### Cursor, color and terminal behavior

1. Cursor on `OPRID` error - positioned exactly on `OPRID` - **PASSED**
2. Cursor on `PINCODE` error - positioned exactly on `PINCODE` (the main bug being fixed) - **PASSED**
3. Cursor on successful authorization - positioned on `OPRID` (ready for the next operator) - **PASSED**
4. `MSGO` color switches RED -> GREEN -> RED correctly - **PASSED**
5. `PINCODE` is visually hidden while typing (`DRK`) - **PASSED**
6. `PINCODE` keyboard does not allow letters (`NUM`) - **PASSED**
7. `CLEAR` after an error - message and both fields are fully cleared - **PASSED**
8. `OPRID` longer than 8 characters - blocked by the terminal - **PASSED**
9. `PINCODE` longer than 4 digits - blocked by the terminal - **PASSED**
10. `DATAONLY` update actually shows the current `MSGO`/color (checked after the `FROM` fix), not stale/empty data - **PASSED**
11. Entered a correct `OPRID` and `PINCODE`, then pressed a wrong key - entered data remains on screen - **PASSED**

## How to Run

1. **Compile the mapset** - run [`MAPCOMP.jcl`](JCL/MAPCOMP.jcl) to assemble [`JOB1SET.bms`](BMS/JOB1SET.bms) into a load module and generate the [`JOB1SET.cpy`](COPYBOOK/JOB1SET.cpy) copybook.
2. **Compile the COBOL program** - run [`CICSCOB2.jcl`](JCL/CICSCOB2.jcl) to compile [`ATMPGM1.cbl`](COBOL/ATMPGM1.cbl) for CICS.
3. **Define and install resources** - follow [`CEDA.md`](RDO/CEDA.md) to define and install the mapset, program and transaction (`AUTH`) via CEDA.
4. **Run the transaction** - clear the terminal screen and type `AUTH`, then press ENTER.

## Key CICS/COBOL Concepts Used

- `EIBCALEN` check to distinguish first entry from a conversational return
- `RECEIVE MAP` / `SEND MAP` with `DATAONLY` for message-only screen refreshes
- `EIBAID` checks for `ENTER`, `CLEAR`, `PF3` and other PF/PA keys
- BMS attributes: `FSET`, `IC` (insert cursor), `DRK` (dark/non-display), `NUM` (numeric keyboard), `PROT`/`UNPROT`
- `RETURN TRANSID('AUTH')` for pseudo-conversational processing
- Color attribute switching (`RED`/`GREEN`/`YELLOW`) driven from COBOL on the same message field

## Notes

- No file or database access in this task - validation is done purely against the screen data in the COMMAREA.
- The program is designed to run in pseudo-conversational mode: it returns control to CICS between user interactions instead of looping internally.
- Tested manually on a 3270 terminal emulator connected to a z/OS CICS region.
