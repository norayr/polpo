MODULE shell;

(** loksh — Linux Oberon Kommand Shell.
    Three modes decided at startup:
      args given  → run one command and exit  (loksh Module.Proc [params])
      no args, tty → cbreak with per-keypress echo and Tab completion
      no args, pipe → line-buffered batch mode

    Tab completion scans x86/*.Obj on every keypress — no startup cache,
    no rehash needed; always reflects the latest compiled state. *)

IMPORT nIn := in, nOut := out, nTermios := termios, Kernel, Files, FATFiles,
  Modules, Oberon0, oberon, nTexts := texts, ooc2Strings := strings;

CONST
  TAB = 9X;
  LF  = 0AX;
  CR  = 0DX;
  BS  = 8X;
  DEL = 7FX;
  ESC = 1BX;  (* start of VT100 escape sequence *)
  ETX = 3X;   (* Ctrl+C: cancel current line *)
  EOT = 4X;   (* Ctrl+D: exit if buffer empty *)

  MaxHist = 64;

PROCEDURE Erase;
BEGIN nOut.Char(BS); nOut.Char(' '); nOut.Char(BS)
END Erase;

PROCEDURE CurLeft(n: INTEGER);
VAR i: INTEGER;
BEGIN i := 0; WHILE i < n DO nOut.Char(ESC); nOut.Char('['); nOut.Char('D'); INC(i) END
END CurLeft;

PROCEDURE CurRight(n: INTEGER);
VAR i: INTEGER;
BEGIN i := 0; WHILE i < n DO nOut.Char(ESC); nOut.Char('['); nOut.Char('C'); INC(i) END
END CurRight;

(* ---- .Obj parsing helpers ----------------------------------------- *)

PROCEDURE ObjReadStr(VAR R: Files.Rider; VAR s: ARRAY OF CHAR);
VAR i: INTEGER; ch: CHAR;
BEGIN
  i := 0;
  LOOP
    Files.Read(R, ch);
    IF ch = 0X THEN s[i] := 0X; RETURN
    ELSIF ch > 7FX THEN s[i] := CHR(ORD(ch) - 80H); s[i+1] := 0X; RETURN
    ELSE s[i] := ch; INC(i)
    END
  END
END ObjReadStr;

PROCEDURE ObjReadU16(VAR R: Files.Rider; VAR u: LONGINT);
VAR lo, hi: CHAR;
BEGIN
  Files.Read(R, lo); Files.Read(R, hi);
  u := 256 * LONG(ORD(hi)) + ORD(lo)
END ObjReadU16;

(* Position rider at start of CmdBlk; returns nofCmds, or -1 on error. *)
PROCEDURE ObjSeekCmds(VAR R: Files.Rider): INTEGER;
VAR
  tag: CHAR;
  symSize, refSize, dataSize, conSize, codeSize, n: LONGINT;
  nofEntries, nofCmds, nofPtrs, nofTds, nofImps, nofDL, nofLinks: INTEGER;
  dummy: ARRAY 64 OF CHAR;
  i: INTEGER;
BEGIN
  Files.Read(R, tag); IF tag # 0BBX THEN RETURN -1 END;
  Files.Read(R, tag); IF tag # 0AFX THEN RETURN -1 END;
  Files.ReadNum(R, symSize);
  Files.Set(R, Files.Base(R), Files.Pos(R) + symSize);
  Files.ReadLInt(R, refSize);
  Files.ReadInt(R, nofEntries); Files.ReadInt(R, nofCmds);
  Files.ReadInt(R, nofPtrs);   Files.ReadInt(R, nofTds);
  Files.ReadInt(R, nofImps);   Files.ReadInt(R, nofDL);
  Files.ReadInt(R, nofLinks);
  Files.ReadLInt(R, dataSize);
  ObjReadU16(R, conSize); ObjReadU16(R, codeSize);
  ObjReadStr(R, dummy);            (* module name *)
  Files.Read(R, tag); IF tag # 082X THEN RETURN -1 END;  (* EntryBlk *)
  i := 0; WHILE i < nofEntries DO ObjReadU16(R, n); INC(i) END;
  Files.Read(R, tag); IF tag # 083X THEN RETURN -1 END;  (* CmdBlk *)
  RETURN nofCmds
END ObjSeekCmds;

(* ---- procedure-name completion ------------------------------------- *)

PROCEDURE ReprintLine(VAR buf: ARRAY OF CHAR; len: INTEGER);
VAR i: INTEGER;
BEGIN
  nOut.Char(LF); nOut.String("> ");
  i := 0; WHILE i < len DO nOut.Char(buf[i]); INC(i) END
  (* caller must set cur := len after calling *)
END ReprintLine;

(* Complete proc name after dot from in-memory cmds of a loaded module. *)
PROCEDURE CompleteProcMem(m: Kernel.Module;
                           VAR buf: ARRAY OF CHAR; VAR len: INTEGER;
                           dotpos, pfxlen: INTEGER);
VAR
  first: ARRAY 64 OF CHAR;
  i, j, matched: INTEGER;
BEGIN
  matched := 0;
  i := 0;
  WHILE i < LEN(m.cmds^) DO
    j := 0;
    WHILE (j < pfxlen) & (buf[dotpos+1+j] = m.cmds[i].name[j]) DO INC(j) END;
    IF j = pfxlen THEN
      INC(matched);
      IF matched = 1 THEN COPY(m.cmds[i].name, first) END
    END;
    INC(i)
  END;
  IF matched = 1 THEN
    j := pfxlen;
    WHILE (first[j] # 0X) & (len < LEN(buf) - 1) DO
      nOut.Char(first[j]); buf[len] := first[j]; INC(len); INC(j)
    END
  ELSIF matched > 1 THEN
    nOut.Char(LF);
    i := 0;
    WHILE i < LEN(m.cmds^) DO
      j := 0;
      WHILE (j < pfxlen) & (buf[dotpos+1+j] = m.cmds[i].name[j]) DO INC(j) END;
      IF j = pfxlen THEN nOut.String(m.cmds[i].name); nOut.Char(' ') END;
      INC(i)
    END;
    ReprintLine(buf, len)
  END
END CompleteProcMem;

(* Complete proc name after dot by parsing x86/ModName.Obj CmdBlk. *)
PROCEDURE CompleteProcObj(modname: ARRAY OF CHAR;
                           VAR buf: ARRAY OF CHAR; VAR len: INTEGER;
                           dotpos, pfxlen: INTEGER);
VAR
  fname: ARRAY 64 OF CHAR;
  f: Files.File;
  R: Files.Rider;
  nofCmds, i, j, matched: INTEGER;
  n: LONGINT;
  cname, first: ARRAY 64 OF CHAR;
BEGIN
  fname[0]:='x'; fname[1]:='8'; fname[2]:='6'; fname[3]:='/';
  i := 0; WHILE modname[i] # 0X DO fname[4+i] := modname[i]; INC(i) END;
  fname[4+i]:='.'; fname[5+i]:='O'; fname[6+i]:='b'; fname[7+i]:='j'; fname[8+i]:=0X;
  f := Files.Old(fname);
  IF f = NIL THEN RETURN END;
  Files.Set(R, f, 0);
  nofCmds := ObjSeekCmds(R);
  IF nofCmds < 0 THEN Files.ReleaseRead(f); RETURN END;
  matched := 0;
  i := 0;
  WHILE i < nofCmds DO
    ObjReadStr(R, cname); ObjReadU16(R, n);
    j := 0;
    WHILE (j < pfxlen) & (buf[dotpos+1+j] = cname[j]) DO INC(j) END;
    IF j = pfxlen THEN
      INC(matched);
      IF matched = 1 THEN COPY(cname, first) END
    END;
    INC(i)
  END;
  IF matched = 1 THEN
    j := pfxlen;
    WHILE (first[j] # 0X) & (len < LEN(buf) - 1) DO
      nOut.Char(first[j]); buf[len] := first[j]; INC(len); INC(j)
    END
  ELSIF matched > 1 THEN
    nOut.Char(LF);
    Files.Set(R, f, 0);  (* rewind for second pass *)
    nofCmds := ObjSeekCmds(R);
    IF nofCmds >= 0 THEN
      i := 0;
      WHILE i < nofCmds DO
        ObjReadStr(R, cname); ObjReadU16(R, n);
        j := 0;
        WHILE (j < pfxlen) & (buf[dotpos+1+j] = cname[j]) DO INC(j) END;
        IF j = pfxlen THEN nOut.String(cname); nOut.Char(' ') END;
        INC(i)
      END
    END;
    ReprintLine(buf, len)
  END;
  Files.ReleaseRead(f)
END CompleteProcObj;

PROCEDURE TryCompleteProc(VAR buf: ARRAY OF CHAR; VAR len: INTEGER; dotpos: INTEGER);
VAR
  modname: Kernel.Name;
  m: Kernel.Module;
  i, pfxlen: INTEGER;
BEGIN
  i := 0; WHILE i < dotpos DO modname[i] := buf[i]; INC(i) END; modname[i] := 0X;
  pfxlen := len - dotpos - 1;
  m := Kernel.modules;
  WHILE (m # NIL) & (m.name # modname) DO m := m.next END;
  IF m # NIL THEN
    CompleteProcMem(m, buf, len, dotpos, pfxlen)
  ELSE
    CompleteProcObj(modname, buf, len, dotpos, pfxlen)
  END
END TryCompleteProc;

(* ---- module-name completion from x86/*.Obj ------------------------- *)

VAR
  (* shared state for all Tab completion callbacks *)
  cmpPfx:        ARRAY 64 OF CHAR;
  cmpPfxLen:     INTEGER;   (* length of name prefix already typed *)
  cmpFirst:      ARRAY 256 OF CHAR;
  cmpMatched:    INTEGER;
  cmpPrint:      BOOLEAN;
  cmpFirstIsDir: BOOLEAN;   (* used by path completion *)

PROCEDURE ObjHandler(name: ARRAY OF CHAR; time, date, size: LONGINT;
                     attr: SET; VAR continue: BOOLEAN);
VAR modname: ARRAY 64 OF CHAR; i, j: INTEGER;
BEGIN
  (* strip .Obj suffix — name must end exactly in ".Obj" *)
  i := 0; WHILE (name[i] # 0X) & (name[i] # '.') DO INC(i) END;
  IF (name[i]='.' ) & (name[i+1]='O') & (name[i+2]='b') &
     (name[i+3]='j') & (name[i+4]=0X) THEN
    j := 0; WHILE j < i DO modname[j] := name[j]; INC(j) END; modname[j] := 0X;
    j := 0;
    WHILE (j < cmpPfxLen) & (cmpPfx[j] = modname[j]) DO INC(j) END;
    IF j = cmpPfxLen THEN
      IF cmpPrint THEN nOut.String(modname); nOut.Char(' ')
      ELSE
        INC(cmpMatched);
        IF cmpMatched = 1 THEN COPY(modname, cmpFirst) END
      END
    END
  END
END ObjHandler;

PROCEDURE PathHandler(name: ARRAY OF CHAR; time, date, size: LONGINT;
                      attr: SET; VAR continue: BOOLEAN);
VAR i: INTEGER;
BEGIN
  i := 0;
  WHILE (i < cmpPfxLen) & (cmpPfx[i] = name[i]) DO INC(i) END;
  IF i = cmpPfxLen THEN
    IF cmpPrint THEN
      nOut.String(name);
      IF FATFiles.SubDir IN attr THEN nOut.Char('/') END;
      nOut.Char(' ')
    ELSE
      INC(cmpMatched);
      IF cmpMatched = 1 THEN
        COPY(name, cmpFirst);
        cmpFirstIsDir := FATFiles.SubDir IN attr
      END
    END
  END
END PathHandler;

(* Complete a Unix path argument starting at buf[argstart..len-1]. *)
PROCEDURE TryCompletePath(VAR buf: ARRAY OF CHAR; VAR len: INTEGER; argstart: INTEGER);
VAR
  pat: ARRAY 256 OF CHAR;
  i, j, namepfxstart: INTEGER;
  res: LONGINT;
BEGIN
  (* find start of the final filename component (after last '/') *)
  namepfxstart := argstart;
  i := argstart;
  WHILE i < len DO
    IF buf[i] = '/' THEN namepfxstart := i + 1 END;
    INC(i)
  END;
  i := namepfxstart; j := 0;
  WHILE i < len DO cmpPfx[j] := buf[i]; INC(i); INC(j) END;
  cmpPfx[j] := 0X; cmpPfxLen := j;

  (* pattern = everything the user typed + "*" *)
  i := argstart; j := 0;
  WHILE i < len DO pat[j] := buf[i]; INC(j); INC(i) END;
  pat[j] := '*'; pat[j+1] := 0X;

  cmpMatched := 0; cmpFirst[0] := 0X; cmpFirstIsDir := FALSE; cmpPrint := FALSE;
  FATFiles.Enumerate(pat, PathHandler, res);

  IF cmpMatched = 1 THEN
    i := cmpPfxLen;
    WHILE (cmpFirst[i] # 0X) & (len < LEN(buf) - 2) DO
      nOut.Char(cmpFirst[i]); buf[len] := cmpFirst[i]; INC(len); INC(i)
    END;
    IF cmpFirstIsDir & (len < LEN(buf) - 1) THEN
      nOut.Char('/'); buf[len] := '/'; INC(len)
    END
  ELSIF cmpMatched > 1 THEN
    nOut.Char(LF);
    cmpPrint := TRUE;
    FATFiles.Enumerate(pat, PathHandler, res);
    ReprintLine(buf, len)
  END
END TryCompletePath;

PROCEDURE TryComplete(VAR buf: ARRAY OF CHAR; VAR len: INTEGER);
VAR
  i, dotpos, spacepos: INTEGER;
  res: LONGINT;
BEGIN
  (* first space separates command from arguments *)
  spacepos := -1; dotpos := -1; i := 0;
  WHILE i < len DO
    IF (buf[i] = ' ') & (spacepos = -1) THEN spacepos := i END;
    IF buf[i] = '.' THEN dotpos := i END;
    INC(i)
  END;

  IF spacepos >= 0 THEN
    TryCompletePath(buf, len, spacepos + 1); RETURN
  END;
  IF dotpos >= 0 THEN TryCompleteProc(buf, len, dotpos); RETURN END;

  (* module name: scan x86/*.Obj fresh on every Tab press *)
  i := 0; WHILE i < len DO cmpPfx[i] := buf[i]; INC(i) END; cmpPfx[i] := 0X;
  cmpPfxLen := len; cmpMatched := 0; cmpFirst[0] := 0X; cmpPrint := FALSE;
  FATFiles.Enumerate("x86/*.Obj", ObjHandler, res);

  IF cmpMatched = 1 THEN
    i := cmpPfxLen;
    WHILE (cmpFirst[i] # 0X) & (len < LEN(buf) - 2) DO
      nOut.Char(cmpFirst[i]); buf[len] := cmpFirst[i]; INC(len); INC(i)
    END;
    IF len < LEN(buf) - 1 THEN
      nOut.Char('.'); buf[len] := '.'; INC(len)
    END
  ELSIF cmpMatched > 1 THEN
    nOut.Char(LF);
    cmpPrint := TRUE;
    FATFiles.Enumerate("x86/*.Obj", ObjHandler, res);
    ReprintLine(buf, len)
  END
END TryComplete;

(* ---- command history ----------------------------------------------- *)

VAR
  hist:         ARRAY MaxHist OF ARRAY 256 OF CHAR;
  histCount:    INTEGER;   (* number of stored entries *)
  histIdx:      INTEGER;   (* browse position; -1 = not browsing *)
  histSaved:    ARRAY 256 OF CHAR;  (* line saved when browsing starts *)
  histSavedLen: INTEGER;

PROCEDURE AddHist(VAR buf: ARRAY OF CHAR; len: INTEGER);
VAR i: INTEGER;
BEGIN
  IF len = 0 THEN RETURN END;
  (* skip duplicate of most recent entry *)
  IF (histCount > 0) & ooc2Strings.Equal(hist[histCount - 1], buf) THEN RETURN END;
  IF histCount < MaxHist THEN
    COPY(buf, hist[histCount]); INC(histCount)
  ELSE
    i := 0; WHILE i < MaxHist - 1 DO hist[i] := hist[i + 1]; INC(i) END;
    COPY(buf, hist[MaxHist - 1])
  END
END AddHist;

PROCEDURE HistReplace(VAR buf: ARRAY OF CHAR; VAR len, cur: INTEGER; VAR src: ARRAY OF CHAR);
VAR i: INTEGER;
BEGIN
  CurRight(len - cur);  (* move terminal cursor to end before erasing *)
  WHILE len > 0 DO DEC(len); Erase END;
  COPY(src, buf);
  len := 0; WHILE buf[len] # 0X DO INC(len) END;
  i := 0; WHILE i < len DO nOut.Char(buf[i]); INC(i) END;
  cur := len
END HistReplace;

PROCEDURE HistUp(VAR buf: ARRAY OF CHAR; VAR len, cur: INTEGER);
BEGIN
  IF histCount = 0 THEN RETURN END;
  IF histIdx = -1 THEN
    COPY(buf, histSaved); histSavedLen := len;
    histIdx := histCount - 1
  ELSIF histIdx > 0 THEN
    DEC(histIdx)
  ELSE
    RETURN
  END;
  HistReplace(buf, len, cur, hist[histIdx])
END HistUp;

PROCEDURE HistDown(VAR buf: ARRAY OF CHAR; VAR len, cur: INTEGER);
BEGIN
  IF histIdx = -1 THEN RETURN END;
  IF histIdx < histCount - 1 THEN
    INC(histIdx);
    HistReplace(buf, len, cur, hist[histIdx])
  ELSE
    histIdx := -1;
    HistReplace(buf, len, cur, histSaved)
  END
END HistDown;

(* ---- cbreak input -------------------------------------------------- *)

PROCEDURE ReadLine(VAR buf: ARRAY OF CHAR; VAR len: INTEGER; VAR quit: BOOLEAN);
VAR ch: CHAR; ok: BOOLEAN; cur, i: INTEGER;
BEGIN
  len := 0; cur := 0; buf[0] := 0X; quit := FALSE; histIdx := -1;
  LOOP
    ok := nIn.ReadRaw(ch);
    IF ~ok OR (ch = EOT) THEN
      IF len = 0 THEN quit := TRUE END;
      nOut.Char(LF); EXIT
    ELSIF ch = ETX THEN
      len := 0; cur := 0; buf[0] := 0X; nOut.Char(LF); EXIT
    ELSIF (ch = CR) OR (ch = LF) THEN
      buf[len] := 0X;
      AddHist(buf, len);
      nOut.Char(LF); EXIT
    ELSIF (ch = BS) OR (ch = DEL) THEN
      IF cur > 0 THEN
        DEC(cur); DEC(len);
        i := cur; WHILE i < len DO buf[i] := buf[i+1]; INC(i) END;
        buf[len] := 0X;
        nOut.Char(BS);
        i := cur; WHILE i < len DO nOut.Char(buf[i]); INC(i) END;
        nOut.Char(' ');
        CurLeft(len - cur + 1)
      END
    ELSIF ch = TAB THEN
      buf[len] := 0X;
      CurRight(len - cur); cur := len;
      TryComplete(buf, len);
      buf[len] := 0X;
      cur := len
    ELSIF ch = ESC THEN
      ok := nIn.ReadRaw(ch);
      IF ok & (ch = '[') THEN
        ok := nIn.ReadRaw(ch);
        IF ok THEN
          IF    ch = 'A' THEN HistUp(buf, len, cur)
          ELSIF ch = 'B' THEN HistDown(buf, len, cur)
          ELSIF ch = 'C' THEN IF cur < len THEN CurRight(1); INC(cur) END
          ELSIF ch = 'D' THEN IF cur > 0  THEN CurLeft(1);  DEC(cur) END
          END
        END
      END
    ELSIF ch >= 20X THEN
      IF len < LEN(buf) - 1 THEN
        IF cur = len THEN
          buf[len] := ch; INC(len); INC(cur); nOut.Char(ch)
        ELSE
          i := len; WHILE i > cur DO buf[i] := buf[i-1]; DEC(i) END;
          buf[cur] := ch; INC(len); INC(cur);
          i := cur - 1; WHILE i < len DO nOut.Char(buf[i]); INC(i) END;
          CurLeft(len - cur)
        END;
        buf[len] := 0X
      END
    END
  END;
  buf[len] := 0X
END ReadLine;

(* ---- command execution --------------------------------------------- *)

PROCEDURE ShowModCmds(modname: ARRAY OF CHAR);
VAR
  m: Kernel.Module;
  f: Files.File;
  R: Files.Rider;
  fname, cname: ARRAY 64 OF CHAR;
  nofCmds, i: INTEGER;
  n: LONGINT;
BEGIN
  m := Kernel.modules;
  WHILE (m # NIL) & (m.name # modname) DO m := m.next END;
  IF m # NIL THEN
    nOut.String(modname); nOut.String(": no procedure specified."); nOut.Ln;
    i := 0;
    WHILE i < LEN(m.cmds^) DO
      nOut.String("    "); nOut.String(modname); nOut.Char('.'); nOut.String(m.cmds[i].name); nOut.Ln;
      INC(i)
    END
  ELSE
    fname[0]:='x'; fname[1]:='8'; fname[2]:='6'; fname[3]:='/';
    i := 0; WHILE modname[i] # 0X DO fname[4+i] := modname[i]; INC(i) END;
    fname[4+i]:='.'; fname[5+i]:='O'; fname[6+i]:='b'; fname[7+i]:='j'; fname[8+i]:=0X;
    f := Files.Old(fname);
    IF f # NIL THEN
      nOut.String(modname); nOut.String(": no procedure specified."); nOut.Ln;
      Files.Set(R, f, 0); nofCmds := ObjSeekCmds(R);
      i := 0;
      WHILE i < nofCmds DO
        ObjReadStr(R, cname); ObjReadU16(R, n);
        nOut.String("    "); nOut.String(modname); nOut.Char('.'); nOut.String(cname); nOut.Ln;
        INC(i)
      END;
      Files.ReleaseRead(f)
    ELSE
      nOut.String(modname); nOut.String(": module not found"); nOut.Ln
    END
  END
END ShowModCmds;

PROCEDURE ShowCallError(cmd: ARRAY OF CHAR; res: INTEGER);
VAR modname: ARRAY 64 OF CHAR; i: INTEGER;
BEGIN
  nOut.String(Modules.resMsg); nOut.Ln;
  IF res = 5 THEN
    i := 0;
    WHILE (cmd[i] # 0X) & (cmd[i] # '.') DO modname[i] := cmd[i]; INC(i) END;
    modname[i] := 0X;
    ShowModCmds(modname)
  END
END ShowCallError;

PROCEDURE Exec(VAR buf: ARRAY OF CHAR);
VAR
  cmd, name: ARRAY 64 OF CHAR;
  params: ARRAY 256 OF CHAR;
  par: Oberon0.ParList;
  W: nTexts.Writer;
  i, j: INTEGER;
  res: INTEGER;
BEGIN
  IF (buf[0] = 0X) OR (buf[0] = '#') THEN RETURN END;
  i := 0;
  WHILE (buf[i] # 0X) & (buf[i] # ' ') DO INC(i) END;
  j := 0; WHILE j < i DO cmd[j] := buf[j]; INC(j) END; cmd[j] := 0X;
  (* no dot: show exported procedures instead of failing with error 5 *)
  j := 0; WHILE (cmd[j] # 0X) & (cmd[j] # '.') DO INC(j) END;
  IF cmd[j] = 0X THEN ShowModCmds(cmd); RETURN END;
  WHILE buf[i] = ' ' DO INC(i) END;
  j := 0; WHILE buf[i] # 0X DO params[j] := buf[i]; INC(j); INC(i) END; params[j] := 0X;
  NEW(par); NEW(par.text); nTexts.Open(par.text, ""); par.pos := 0;
  IF params[0] # 0X THEN
    nTexts.OpenWriter(W); nTexts.WriteString(W, params); nTexts.Append(par.text, W.buf)
  END;
  COPY(cmd, name);
  Oberon0.Call(name, par, FALSE, res);
  IF res # 0 THEN ShowCallError(cmd, res) END
END Exec;

PROCEDURE LineLoop;
VAR line: ARRAY 256 OF CHAR; quit: BOOLEAN;
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

(* ---- entry point --------------------------------------------------- *)

PROCEDURE Run*;
VAR
  saved: nTermios.Termios;
  buf: ARRAY 256 OF CHAR;
  arg: ARRAY 256 OF CHAR;
  cmd, name: ARRAY 64 OF CHAR;
  par: Oberon0.ParList;
  W: nTexts.Writer;
  len: INTEGER;
  i, firstArg: LONGINT;
  r: LONGINT;
  res: INTEGER;
  quit: BOOLEAN;
BEGIN
  firstArg := 1;
  IF Kernel.NoOfArgs > firstArg THEN
    Kernel.GetArg(firstArg, cmd);
    IF (cmd[0] = "-") & (cmd[1] = "P") THEN INC(firstArg); Kernel.GetArg(firstArg, cmd) END
  END;
  IF Kernel.NoOfArgs > firstArg THEN
    IF ooc2Strings.Equal(cmd, "--help") OR ooc2Strings.Equal(cmd, "-h") THEN
      nOut.String("loksh - Linux Oberon Kommand Shell"); nOut.Ln;
      nOut.Ln;
       nOut.String("Usage:"); nOut.Ln;
       nOut.String("  loksh                     interactive shell with Tab completion"); nOut.Ln;
       nOut.String("  loksh Module.Proc [args]  run one command and exit"); nOut.Ln;
       nOut.String("  loksh -Ppath/ Module.Proc load modules from path/"); nOut.Ln;
       nOut.String("  loksh < script            run commands from a file"); nOut.Ln;
      nOut.Ln;
      nOut.String("Interactive keys:"); nOut.Ln;
      nOut.String("  Tab     complete module name or procedure name"); nOut.Ln;
      nOut.String("  Ctrl+C  cancel current line"); nOut.Ln;
      nOut.String("  Ctrl+D  exit"); nOut.Ln;
      nOut.String("  quit / exit"); nOut.Ln;
       Kernel.Shutdown(0)
    ELSIF ooc2Strings.Equal(cmd, "shell.Run") THEN
      nOut.String("shell.Run is started automatically; omit it from the command line."); nOut.Ln;
      Kernel.Shutdown(1)
    END;
    nTexts.OpenWriter(W);
    i := firstArg + 1;
    WHILE i < Kernel.NoOfArgs DO
      Kernel.GetArg(i, arg);
      nTexts.WriteString(W, arg);
      IF i < Kernel.NoOfArgs - 1 THEN nTexts.Write(W, " ") END;
      INC(i)
    END;
    i := 0; WHILE (cmd[i] # 0X) & (cmd[i] # '.') DO INC(i) END;
    IF cmd[i] = 0X THEN ShowModCmds(cmd); Kernel.Shutdown(0) END;
    NEW(par); NEW(par.text); nTexts.Open(par.text, ""); par.pos := 0;
    nTexts.Append(par.text, W.buf);
    COPY(cmd, name);
    Oberon0.Call(name, par, FALSE, res);
    IF res # 0 THEN ShowCallError(cmd, res) END;
    Kernel.Shutdown(0)
  ELSE
    r := nTermios.EnterCbreak(0, saved);
    IF r # 0 THEN
      LineLoop;
      Kernel.Shutdown(0)
    END;
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

END shell.
