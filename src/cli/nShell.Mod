MODULE nShell;

(** loksh — Linux Oberon Kommand Shell.
    Three modes decided at startup:
      args given  → run one command and exit  (loksh Module.Proc [params])
      no args, tty → cbreak with per-keypress echo and Tab completion
      no args, pipe → line-buffered batch mode *)

IMPORT nIn, nOut, nTermios, Kernel, nOberon, nTexts, ooc2Strings;

CONST
  TAB = 9X;
  LF  = 0AX;
  CR  = 0DX;
  BS  = 8X;
  DEL = 7FX;
  ETX = 3X;  (* Ctrl+C: cancel current line *)
  EOT = 4X;  (* Ctrl+D: exit if buffer empty *)

PROCEDURE Erase;
BEGIN nOut.Char(BS); nOut.Char(' '); nOut.Char(BS)
END Erase;

(* Complete a module name prefix in buf[0..len-1].
   Unique match: appends remaining chars + '.' to buf and screen.
   Multiple matches: prints candidates, reprints prompt + current buf. *)
PROCEDURE TryComplete(VAR buf: ARRAY OF CHAR; VAR len: INTEGER);
VAR
  m: Kernel.Module;
  i, matched: INTEGER;
  first: Kernel.Name;
BEGIN
  matched := 0;
  m := Kernel.modules;
  WHILE m # NIL DO
    i := 0;
    WHILE (i < len) & (buf[i] = m.name[i]) DO INC(i) END;
    IF i = len THEN
      INC(matched);
      IF matched = 1 THEN COPY(m.name, first) END
    END;
    m := m.next
  END;
  IF matched = 1 THEN
    i := len;
    WHILE (first[i] # 0X) & (len < LEN(buf) - 2) DO
      nOut.Char(first[i]); buf[len] := first[i]; INC(len); INC(i)
    END;
    IF len < LEN(buf) - 1 THEN
      nOut.Char('.'); buf[len] := '.'; INC(len)
    END
  ELSIF matched > 1 THEN
    nOut.Char(LF);
    m := Kernel.modules;
    WHILE m # NIL DO
      i := 0;
      WHILE (i < len) & (buf[i] = m.name[i]) DO INC(i) END;
      IF i = len THEN nOut.String(m.name); nOut.Char(' ') END;
      m := m.next
    END;
    nOut.Char(LF);
    nOut.String("> ");
    i := 0; WHILE i < len DO nOut.Char(buf[i]); INC(i) END
  END
END TryComplete;

(* Read one line character by character (cbreak mode).
   Sets quit=TRUE on Ctrl+D with empty buffer. *)
PROCEDURE ReadLine(VAR buf: ARRAY OF CHAR; VAR len: INTEGER; VAR quit: BOOLEAN);
VAR ch: CHAR; ok: BOOLEAN;
BEGIN
  len := 0; quit := FALSE;
  LOOP
    ok := nIn.ReadRaw(ch);
    IF ~ok OR (ch = EOT) THEN
      IF len = 0 THEN quit := TRUE END;
      nOut.Char(LF); EXIT
    ELSIF ch = ETX THEN
      len := 0; nOut.Char(LF); EXIT
    ELSIF (ch = CR) OR (ch = LF) THEN
      nOut.Char(LF); EXIT
    ELSIF (ch = BS) OR (ch = DEL) THEN
      IF len > 0 THEN DEC(len); Erase END
    ELSIF ch = TAB THEN
      buf[len] := 0X;
      TryComplete(buf, len)
    ELSIF ch >= 20X THEN
      IF len < LEN(buf) - 1 THEN
        buf[len] := ch; INC(len); nOut.Char(ch)
      END
    END
  END;
  buf[len] := 0X
END ReadLine;

(* Parse and execute one command line: "Module.Proc [params]". *)
PROCEDURE Exec(VAR buf: ARRAY OF CHAR);
VAR
  cmd, name: ARRAY 64 OF CHAR;
  params: ARRAY 256 OF CHAR;
  par: nOberon.ParList;
  W: nTexts.Writer;
  i, j: INTEGER;
  res: INTEGER;
BEGIN
  IF (buf[0] = 0X) OR (buf[0] = '#') THEN RETURN END;
  i := 0;
  WHILE (buf[i] # 0X) & (buf[i] # ' ') DO INC(i) END;
  j := 0; WHILE j < i DO cmd[j] := buf[j]; INC(j) END; cmd[j] := 0X;
  WHILE buf[i] = ' ' DO INC(i) END;
  j := 0; WHILE buf[i] # 0X DO params[j] := buf[i]; INC(j); INC(i) END; params[j] := 0X;
  NEW(par); NEW(par.text); nTexts.Open(par.text, ""); par.pos := 0;
  IF params[0] # 0X THEN
    nTexts.OpenWriter(W); nTexts.WriteString(W, params); nTexts.Append(par.text, W.buf)
  END;
  COPY(cmd, name);
  nOberon.Call(name, par, FALSE, res);
  IF res # 0 THEN nOut.String("error "); nOut.Int(res, 0); nOut.Ln END
END Exec;

(* Line-buffered loop: used when stdin is a pipe or for batch input. *)
PROCEDURE LineLoop;
VAR
  line: ARRAY 256 OF CHAR;
  quit: BOOLEAN;
BEGIN
  nIn.Open;
  quit := FALSE;
  WHILE ~quit DO
    nOut.String("> ");
    nIn.Line(line);
    IF ~nIn.Done THEN quit := TRUE
    ELSIF ooc2Strings.Equal(line, "quit") OR ooc2Strings.Equal(line, "exit") THEN
      quit := TRUE
    ELSE
      Exec(line)
    END
  END
END LineLoop;

PROCEDURE Run*;
VAR
  saved: nTermios.Termios;
  buf: ARRAY 256 OF CHAR;
  arg: ARRAY 256 OF CHAR;
  cmd, name: ARRAY 64 OF CHAR;
  par: nOberon.ParList;
  W: nTexts.Writer;
  len: INTEGER;
  i: LONGINT;
  r: LONGINT;
  res: INTEGER;
  quit: BOOLEAN;
BEGIN
  IF Kernel.NoOfArgs >= 2 THEN
    Kernel.GetArg(1, cmd);
    IF ooc2Strings.Equal(cmd, "--help") OR ooc2Strings.Equal(cmd, "-h") THEN
      nOut.String("loksh - Linux Oberon Kommand Shell"); nOut.Ln;
      nOut.Ln;
      nOut.String("Usage:"); nOut.Ln;
      nOut.String("  loksh                     interactive shell with Tab completion"); nOut.Ln;
      nOut.String("  loksh Module.Proc [args]  run one command and exit"); nOut.Ln;
      nOut.String("  loksh < script            run commands from a file"); nOut.Ln;
      nOut.Ln;
      nOut.String("Interactive keys:"); nOut.Ln;
      nOut.String("  Tab     complete module name"); nOut.Ln;
      nOut.String("  Ctrl+C  cancel current line"); nOut.Ln;
      nOut.String("  Ctrl+D  exit"); nOut.Ln;
      nOut.String("  quit / exit"); nOut.Ln;
      Kernel.Shutdown(0)
    END;
    (* single-command mode: loksh Module.Proc [param ...] *)
    nTexts.OpenWriter(W);
    i := 2;
    WHILE i < Kernel.NoOfArgs DO
      Kernel.GetArg(i, arg);
      nTexts.WriteString(W, arg);
      IF i < Kernel.NoOfArgs - 1 THEN nTexts.Write(W, " ") END;
      INC(i)
    END;
    NEW(par); NEW(par.text); nTexts.Open(par.text, ""); par.pos := 0;
    nTexts.Append(par.text, W.buf);
    COPY(cmd, name);
    nOberon.Call(name, par, FALSE, res);
    IF res # 0 THEN nOut.String("error "); nOut.Int(res, 0); nOut.Ln END;
    Kernel.Shutdown(0)
  ELSE
    r := nTermios.EnterCbreak(0, saved);
    IF r # 0 THEN
      (* stdin is not a tty: use line-buffered batch mode *)
      LineLoop;
      Kernel.Shutdown(0)
    END;
    (* cbreak interactive mode *)
    quit := FALSE;
    WHILE ~quit DO
      nOut.String("> ");
      ReadLine(buf, len, quit);
      IF ~quit & (len > 0) THEN
        IF ooc2Strings.Equal(buf, "quit") OR ooc2Strings.Equal(buf, "exit") THEN
          quit := TRUE
        ELSE
          Exec(buf)
        END
      END
    END;
    r := nTermios.Leave(0, saved);
    Kernel.Shutdown(0)
  END
END Run;

END nShell.
