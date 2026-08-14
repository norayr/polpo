MODULE termios;

IMPORT Kernel, Linux0, SYSTEM;

CONST
  (* ioctl request codes *)
  TCGETS*  = 5401H;  (* read current terminal settings  — tcgetattr(3) *)
  TCSETS*  = 5402H;  (* write settings immediately      — tcsetattr TCSANOW *)
  TCSETSW* = 5403H;  (* write after draining output     — TCSADRAIN *)
  TCSETSF* = 5404H;  (* write after flushing input      — TCSAFLUSH *)

  (* c_lflag bit numbers — use with INCL / EXCL on Termios.lflag *)
  ISIG*   = 0;   (* generate signals for Ctrl+C, Ctrl+Z *)
  ICANON* = 1;   (* canonical (line-buffered) input mode *)
  ECHO*   = 3;   (* echo input characters back to terminal *)
  ECHOE*  = 4;   (* echo erase as backspace-space-backspace *)
  ECHOK*  = 5;   (* echo newline after kill character *)
  IEXTEN* = 15;  (* enable implementation-defined input processing *)

  (* c_cc array indices *)
  VINTR*  = 0;   (* interrupt character (Ctrl+C) *)
  VQUIT*  = 1;   (* quit character (Ctrl+\) *)
  VERASE* = 2;   (* erase character (Backspace / Del) *)
  VKILL*  = 3;   (* kill-line character (Ctrl+U) *)
  VEOF*   = 4;   (* end-of-file character (Ctrl+D) *)
  VTIME*  = 5;   (* read timeout in tenths of a second (0 = none) *)
  VMIN*   = 6;   (* minimum characters before read returns *)
  VSTART* = 8;   (* XON resume character (Ctrl+Q) *)
  VSTOP*  = 9;   (* XOFF pause character (Ctrl+S) *)
  VSUSP*  = 10;  (* suspend character (Ctrl+Z) *)

TYPE
  (* Maps directly onto Linux struct termios (36 bytes total):
       4 × SET  (iflag/oflag/cflag/lflag, each 4 bytes)
       1 × CHAR (line discipline, 1 byte)
      19 × CHAR (c_cc control characters, 19 bytes)            *)
  Termios* = RECORD
    iflag*, oflag*, cflag*, lflag*: SET;
    line*: CHAR;
    cc*: ARRAY 19 OF CHAR
  END;

VAR
  savedTerminal: Termios;
  cbreak: BOOLEAN;

(* Read terminal settings for file descriptor fd into t.
   Returns 0 on success, negative errno on failure. *)
PROCEDURE Get*(fd: LONGINT; VAR t: Termios): LONGINT;
BEGIN RETURN Linux0.IOCtl0(fd, TCGETS, SYSTEM.ADR(t))
END Get;

(* Write terminal settings for file descriptor fd from t (takes effect immediately).
   Returns 0 on success, negative errno on failure. *)
PROCEDURE Set*(fd: LONGINT; VAR t: Termios): LONGINT;
BEGIN RETURN Linux0.IOCtl0(fd, TCSETS, SYSTEM.ADR(t))
END Set;

(* Kernel.Shutdown also invokes this after signals and traps. *)
PROCEDURE Restore;
VAR r: LONGINT;
BEGIN
  IF cbreak THEN
    r := Set(0, savedTerminal); cbreak := FALSE
  END
END Restore;

(* Switch fd to cbreak mode: characters delivered one at a time, no echo.
   ISIG (Ctrl+C / Ctrl+Z) is preserved.
   Saves the original settings in 'saved'; call Leave to restore.
   Returns 0 on success, negative errno on failure. *)
PROCEDURE EnterCbreak*(fd: LONGINT; VAR saved: Termios): LONGINT;
VAR t: Termios; r: LONGINT;
BEGIN
  r := Get(fd, saved);
  IF r = 0 THEN
    t := saved;
    EXCL(t.lflag, ICANON);  (* no line buffering *)
    EXCL(t.lflag, ECHO);    (* no automatic echo *)
    t.cc[VMIN]  := 1X;      (* return after every character *)
    t.cc[VTIME] := 0X;      (* no read timeout *)
    r := Set(fd, t);
    IF r = 0 THEN
      savedTerminal := saved; cbreak := TRUE;
      Kernel.InstallTermHandler(Restore)
    END
  END;
  RETURN r
END EnterCbreak;

(* Restore terminal settings previously saved by EnterCbreak.
   Returns 0 on success, negative errno on failure. *)
PROCEDURE Leave*(fd: LONGINT; VAR saved: Termios): LONGINT;
VAR r: LONGINT;
BEGIN
  r := Set(fd, saved);
  IF r = 0 THEN cbreak := FALSE END;
  RETURN r
END Leave;

BEGIN
  cbreak := FALSE
END termios.
