MODULE xxs;  (** a small nano-like editor for the console, the size that fits every terminal *)

(* xxs.Open file   edit a file, a new one when it does not exist
   xxs.Fit file    the same

   Plain files stay plain, Oberon texts keep their fonts and colours; in the Write Out
   prompt (^O), ^T switches between storing as Oberon text and as plain text.
   Keys as in nano: ^O write out, ^X exit, ^K cut line, ^U paste, ^W where is, ^C location,
   ^G help, ^A/^E line start/end, ^Y/^V page up/down, arrows, Home, End, PgUp, PgDn. *)

IMPORT Kernel, Linux0, Files, Objects := objects, Texts := texts, termios, SYSTEM;

CONST
  ESC = 1BX; CR = 0DX; LF = 0AX; TAB = 09X;
  (* keys above the characters *)
  KUp = 1001; KDown = 1002; KRight = 1003; KLeft = 1004;
  KHome = 1005; KEnd = 1006; KPgUp = 1007; KPgDn = 1008; KDel = 1009; KNone = 1010;

VAR
  T: Texts.Text;
  name: ARRAY 256 OF CHAR;
  plain, modified, running, raw: BOOLEAN;
  cur, top, hcol, goalCol: LONGINT;  (* caret, first line shown, first column shown, column for up/down *)
  rows, cols, height: LONGINT;  (* terminal size, lines of text shown *)
  cutBuf: Texts.Buffer; lastCut: BOOLEAN;
  msg, search: ARRAY 256 OF CHAR;
  saved: termios.Termios;
  obuf: ARRAY 65536 OF CHAR; opos: LONGINT;
  W: Texts.Writer;

(* ----- terminal ----- *)

PROCEDURE Flush;
VAR r: LONGINT;
BEGIN
  IF opos > 0 THEN r := Linux0.Write0(1, SYSTEM.ADR(obuf[0]), opos); opos := 0 END
END Flush;

PROCEDURE Ch(c: CHAR);
BEGIN
  IF opos >= LEN(obuf) THEN Flush END;
  obuf[opos] := c; INC(opos)
END Ch;

PROCEDURE Str(s: ARRAY OF CHAR);
VAR i: LONGINT;
BEGIN i := 0; WHILE (i < LEN(s)) & (s[i] # 0X) DO Ch(s[i]); INC(i) END
END Str;

PROCEDURE Int(n: LONGINT);
VAR a: ARRAY 12 OF CHAR; i: LONGINT;
BEGIN
  IF n < 0 THEN Ch("-"); n := -n END;
  i := 0; REPEAT a[i] := CHR(ORD("0") + n MOD 10); n := n DIV 10; INC(i) UNTIL n = 0;
  WHILE i > 0 DO DEC(i); Ch(a[i]) END
END Int;

PROCEDURE CSI(s: ARRAY OF CHAR);
BEGIN Ch(ESC); Ch("["); Str(s)
END CSI;

PROCEDURE Goto(row, col: LONGINT);  (* 1-based *)
BEGIN Ch(ESC); Ch("["); Int(row); Ch(";"); Int(col); Ch("H")
END Goto;

PROCEDURE Attr(n: LONGINT);
BEGIN Ch(ESC); Ch("["); Int(n); Ch("m")
END Attr;

PROCEDURE GetSize;
BEGIN
  IF ~termios.WinSize(1, rows, cols) OR (rows < 5) OR (cols < 10) THEN rows := 24; cols := 80 END;
  height := rows - 4;  (* title, message and two help lines *)
  IF height < 1 THEN height := 1 END
END GetSize;

PROCEDURE Restore;  (* also run at Kernel.Shutdown, after traps *)
VAR r: LONGINT;
BEGIN
  IF raw THEN
    raw := FALSE;
    Attr(0); CSI("?1049l"); Flush;  (* leave the alternate screen *)
    r := termios.Set(0, saved)
  END
END Restore;

PROCEDURE Raw(): BOOLEAN;
VAR t: termios.Termios;
BEGIN
  IF termios.Get(0, saved) # 0 THEN RETURN FALSE END;
  t := saved; termios.MakeRaw(t);
  IF termios.Set(0, t) # 0 THEN RETURN FALSE END;
  raw := TRUE; Kernel.InstallTermHandler(Restore);
  CSI("?1049h"); Flush;  (* the alternate screen, the old contents come back at the end *)
  RETURN TRUE
END Raw;

PROCEDURE ReadByte(): LONGINT;
VAR c: CHAR; r: LONGINT;
BEGIN
  r := Linux0.Read0(0, SYSTEM.ADR(c), 1);
  IF r <= 0 THEN RETURN -1 END;
  RETURN ORD(c)
END ReadByte;

(* a key: a character, or KUp .. KDel; escape sequences of xterm and the Linux console *)
PROCEDURE ReadKey(): LONGINT;
VAR c, n: LONGINT;
BEGIN
  c := ReadByte();
  IF c # ORD(ESC) THEN RETURN c END;
  c := ReadByte();
  IF c = ORD("O") THEN
    c := ReadByte();
    IF c = ORD("A") THEN RETURN KUp ELSIF c = ORD("B") THEN RETURN KDown
    ELSIF c = ORD("C") THEN RETURN KRight ELSIF c = ORD("D") THEN RETURN KLeft
    ELSIF c = ORD("H") THEN RETURN KHome ELSIF c = ORD("F") THEN RETURN KEnd
    END;
    RETURN KNone
  ELSIF c = ORD("[") THEN
    n := 0; c := ReadByte();
    WHILE (c >= ORD("0")) & (c <= ORD("9")) DO n := n * 10 + c - ORD("0"); c := ReadByte() END;
    WHILE c = ORD(";") DO  (* modifiers are ignored *)
      c := ReadByte(); WHILE (c >= ORD("0")) & (c <= ORD("9")) DO c := ReadByte() END
    END;
    IF c = ORD("A") THEN RETURN KUp ELSIF c = ORD("B") THEN RETURN KDown
    ELSIF c = ORD("C") THEN RETURN KRight ELSIF c = ORD("D") THEN RETURN KLeft
    ELSIF c = ORD("H") THEN RETURN KHome ELSIF c = ORD("F") THEN RETURN KEnd
    ELSIF c = ORD("~") THEN
      IF (n = 1) OR (n = 7) THEN RETURN KHome ELSIF (n = 4) OR (n = 8) THEN RETURN KEnd
      ELSIF n = 3 THEN RETURN KDel ELSIF n = 5 THEN RETURN KPgUp ELSIF n = 6 THEN RETURN KPgDn
      END
    END;
    RETURN KNone
  END;
  RETURN KNone  (* Meta keys are not used *)
END ReadKey;

(* ----- text ----- *)

PROCEDURE CharAt(pos: LONGINT): CHAR;
VAR R: Texts.Reader; c: CHAR;
BEGIN
  IF (pos < 0) OR (pos >= T.len) THEN RETURN 0X END;
  Texts.OpenReader(R, T, pos); Texts.Read(R, c); RETURN c
END CharAt;

PROCEDURE IsEol(c: CHAR): BOOLEAN;
BEGIN RETURN (c = CR) OR (c = LF)
END IsEol;

PROCEDURE LineStart(pos: LONGINT): LONGINT;
BEGIN
  WHILE (pos > 0) & ~IsEol(CharAt(pos - 1)) DO DEC(pos) END;
  RETURN pos
END LineStart;

PROCEDURE LineEnd(pos: LONGINT): LONGINT;  (* position of the line end, or T.len *)
VAR R: Texts.Reader; c: CHAR;
BEGIN
  IF pos >= T.len THEN RETURN T.len END;
  Texts.OpenReader(R, T, pos); Texts.Read(R, c);
  WHILE ~R.eot & ~IsEol(c) DO INC(pos); Texts.Read(R, c) END;
  RETURN pos
END LineEnd;

PROCEDURE NextLine(pos: LONGINT): LONGINT;  (* start of the next line, or -1 *)
BEGIN
  pos := LineEnd(pos);
  IF pos >= T.len THEN RETURN -1 END;
  RETURN pos + 1
END NextLine;

PROCEDURE Cont(c: CHAR): BOOLEAN;  (* a UTF-8 continuation byte, no column of its own *)
BEGIN RETURN (ORD(c) >= 80H) & (ORD(c) < 0C0H)
END Cont;

PROCEDURE NextPos(pos: LONGINT): LONGINT;
BEGIN
  IF pos < T.len THEN INC(pos) END;
  WHILE (pos < T.len) & Cont(CharAt(pos)) DO INC(pos) END;
  RETURN pos
END NextPos;

PROCEDURE PrevPos(pos: LONGINT): LONGINT;
BEGIN
  IF pos > 0 THEN DEC(pos) END;
  WHILE (pos > 0) & Cont(CharAt(pos)) DO DEC(pos) END;
  RETURN pos
END PrevPos;

(* the screen column of pos in its line; tabs every 8 columns *)
PROCEDURE Col(pos: LONGINT): LONGINT;
VAR R: Texts.Reader; p, col: LONGINT; c: CHAR;
BEGIN
  p := LineStart(pos); col := 0;
  IF p < pos THEN
    Texts.OpenReader(R, T, p);
    WHILE p < pos DO
      Texts.Read(R, c);
      IF c = TAB THEN col := col + 8 - col MOD 8 ELSIF ~Cont(c) THEN INC(col) END;
      INC(p)
    END
  END;
  RETURN col
END Col;

(* the position in the line starting at ls nearest to column col *)
PROCEDURE PosAtCol(ls, col: LONGINT): LONGINT;
VAR R: Texts.Reader; p, c0, w: LONGINT; c: CHAR;
BEGIN
  p := ls; c0 := 0;
  IF p >= T.len THEN RETURN T.len END;
  Texts.OpenReader(R, T, p); Texts.Read(R, c);
  WHILE ~R.eot & ~IsEol(c) DO
    IF c = TAB THEN w := 8 - c0 MOD 8 ELSIF Cont(c) THEN w := 0 ELSE w := 1 END;
    IF (w > 0) & (c0 + w > col) THEN RETURN p END;
    c0 := c0 + w; INC(p); Texts.Read(R, c)
  END;
  RETURN p
END PosAtCol;

PROCEDURE LineNo(pos: LONGINT): LONGINT;  (* 1-based *)
VAR R: Texts.Reader; p, n: LONGINT; c: CHAR;
BEGIN
  n := 1; p := 0; Texts.OpenReader(R, T, 0);
  WHILE p < pos DO Texts.Read(R, c); IF IsEol(c) THEN INC(n) END; INC(p) END;
  RETURN n
END LineNo;

PROCEDURE Newline(): CHAR;  (* line end of this text: LF in plain files, CR in Oberon texts *)
BEGIN
  IF plain THEN RETURN LF ELSE RETURN CR END
END Newline;

(* insert c at the caret, in the looks of the character before *)
PROCEDURE Insert(c: CHAR);
VAR R: Texts.Reader; ch: CHAR; lib: Objects.Library;
BEGIN
  IF cur > 0 THEN Texts.OpenReader(R, T, cur - 1) ELSE Texts.OpenReader(R, T, 0) END;
  Texts.Read(R, ch); lib := R.lib;
  IF (T.len = 0) OR R.eot THEN lib := NIL; R.col := 15; R.voff := 0 END;
  IF (lib = NIL) & ~plain THEN lib := Objects.ThisLibrary("Oberon10.Scn.Fnt") END;
  Texts.SetFont(W, lib); Texts.SetColor(W, R.col); Texts.SetOffset(W, R.voff);
  Texts.Write(W, c); Texts.Insert(T, cur, W.buf);
  INC(cur); modified := TRUE
END Insert;

PROCEDURE Delete(beg, end: LONGINT);
BEGIN
  IF end > beg THEN Texts.Delete(T, beg, end); modified := TRUE END
END Delete;

(* ----- screen ----- *)

(* terminal attributes for the looks of R: colours, bold and italic fonts (Oberon texts) *)
PROCEDURE Looks(VAR R: Texts.Reader);
VAR i, r, g, b: LONGINT; bold, italic: BOOLEAN;
BEGIN
  Attr(0); bold := FALSE; italic := FALSE;
  IF R.lib # NIL THEN
    i := 0;
    WHILE (R.lib.name[i] # 0X) & ((R.lib.name[i] < "0") OR (R.lib.name[i] > "9")) DO INC(i) END;
    WHILE (R.lib.name[i] >= "0") & (R.lib.name[i] <= "9") DO INC(i) END;
    WHILE (R.lib.name[i] # 0X) & (R.lib.name[i] # ".") DO
      IF CAP(R.lib.name[i]) = "B" THEN bold := TRUE ELSIF CAP(R.lib.name[i]) = "I" THEN italic := TRUE END;
      INC(i)
    END
  END;
  IF bold THEN Attr(1) END;
  IF italic THEN Attr(3) END;
  IF Texts.PaletteRGB(R.col, r, g, b) THEN  (* true colour, the Oberon palette *)
    Ch(ESC); Str("[38;2;"); Int(r); Ch(";"); Int(g); Ch(";"); Int(b); Ch("m")
  END
END Looks;

PROCEDURE DrawLine(pos: LONGINT);
VAR R: Texts.Reader; c: CHAR; col, n: LONGINT; show: BOOLEAN; lib: Objects.Library; lcol: SHORTINT;
BEGIN
  col := 0; show := FALSE; lib := NIL; lcol := 15;
  IF pos < T.len THEN
    Texts.OpenReader(R, T, pos); Texts.Read(R, c);
    WHILE ~R.eot & ~IsEol(c) & (col < hcol + cols) DO
      IF ~plain & ((R.lib # lib) OR (R.col # lcol)) THEN lib := R.lib; lcol := R.col; Looks(R) END;
      IF ~Texts.IsCharacterLibrary(R.lib) THEN  (* an object *)
        IF col >= hcol THEN Ch("?") END; INC(col)
      ELSIF c = TAB THEN
        n := 8 - col MOD 8;
        WHILE n > 0 DO IF (col >= hcol) & (col < hcol + cols) THEN Ch(" ") END; INC(col); DEC(n) END
      ELSIF Cont(c) THEN
        IF show THEN Ch(c) END
      ELSIF c < " " THEN
        show := FALSE; IF col >= hcol THEN Ch("?") END; INC(col)
      ELSE
        show := (col >= hcol) & (col < hcol + cols);
        IF show THEN Ch(c) END;
        INC(col)
      END;
      Texts.Read(R, c)
    END;
    IF ~plain THEN Attr(0) END
  END;
  CSI("K")
END DrawLine;

PROCEDURE Append(VAR s: ARRAY OF CHAR; t: ARRAY OF CHAR);
VAR i, j: LONGINT;
BEGIN
  i := 0; WHILE s[i] # 0X DO INC(i) END;
  j := 0; WHILE (t[j] # 0X) & (i < LEN(s) - 1) DO s[i] := t[j]; INC(i); INC(j) END;
  s[i] := 0X
END Append;

PROCEDURE Help(k, label: ARRAY OF CHAR);
BEGIN Attr(7); Str(k); Attr(0); Ch(" "); Str(label); Str("  ")
END Help;

(* keep the caret on the screen *)
PROCEDURE Follow;
VAR ls, p, n, c: LONGINT;
BEGIN
  ls := LineStart(cur);
  IF ls < top THEN top := ls
  ELSE
    n := 0; p := top;
    WHILE (p # ls) & (p >= 0) DO p := NextLine(p); INC(n) END;
    WHILE n >= height DO top := NextLine(top); DEC(n) END
  END;
  c := Col(cur);
  IF c < hcol THEN hcol := c - c MOD (cols DIV 2)
  ELSIF c >= hcol + cols - 1 THEN hcol := c - cols DIV 2
  END;
  IF hcol < 0 THEN hcol := 0 END
END Follow;

PROCEDURE Draw;
VAR i, p: LONGINT;
BEGIN
  GetSize; Follow;
  CSI("?25l"); Goto(1, 1);
  Attr(7); Str("  xxs  "); Str(name);
  IF plain THEN Str("  [plain text]") ELSE Str("  [Oberon text]") END;
  IF modified THEN Str("  Modified") END;
  CSI("K"); Attr(0);
  i := 0; p := top;
  WHILE i < height DO
    Goto(i + 2, 1);
    IF p >= 0 THEN DrawLine(p); p := NextLine(p) ELSE CSI("K") END;
    INC(i)
  END;
  Goto(rows - 2, 1); IF msg # "" THEN Attr(7); Str(" "); Str(msg); Str(" "); Attr(0) END; CSI("K");
  Goto(rows - 1, 1);
  Help("^G", "Help"); Help("^O", "Write Out"); Help("^W", "Where Is"); Help("^K", "Cut"); Help("^U", "Paste"); Help("^C", "Location");
  CSI("K"); Goto(rows, 1);
  Help("^X", "Exit"); Help("^A", "Line Start"); Help("^E", "Line End"); Help("^Y", "Prev Page"); Help("^V", "Next Page");
  CSI("K");
  Goto(LineNo(cur) - LineNo(top) + 2, Col(cur) - hcol + 1); CSI("?25h");
  Flush
END Draw;

(* ask on the message line; ^C cancels (FALSE); tab: ^T toggles the storing format *)
PROCEDURE Prompt(q: ARRAY OF CHAR; VAR s: ARRAY OF CHAR; toggle: BOOLEAN; VAR asPlain: BOOLEAN): BOOLEAN;
VAR k, i: LONGINT;
BEGIN
  LOOP
    GetSize;
    Goto(rows - 2, 1); Attr(7); Str(q);
    IF toggle THEN IF asPlain THEN Str(" [plain text]") ELSE Str(" [Oberon text]") END END;
    Str(": "); Str(s); CSI("K"); Attr(0);
    Goto(rows - 1, 1); Help("Enter", "Accept"); Help("^C", "Cancel");
    IF toggle THEN IF asPlain THEN Help("^T", "As Oberon text") ELSE Help("^T", "As plain text") END END;
    CSI("K"); Goto(rows, 1); CSI("K");
    i := 0; WHILE s[i] # 0X DO INC(i) END;
    Goto(rows - 2, 1); Flush;
    k := ReadKey();
    IF (k = 0DH) OR (k = 0AH) THEN RETURN TRUE
    ELSIF (k = 3) OR (k = -1) THEN RETURN FALSE
    ELSIF (k = 14H) & toggle THEN asPlain := ~asPlain
    ELSIF (k = 7FH) OR (k = 8) THEN IF i > 0 THEN s[i-1] := 0X END
    ELSIF (k >= 20H) & (k < 100H) & (i < LEN(s) - 1) THEN s[i] := CHR(k); s[i+1] := 0X
    END
  END
END Prompt;

PROCEDURE WriteOut(): BOOLEAN;
VAR fname: ARRAY 256 OF CHAR; asPlain: BOOLEAN;
BEGIN
  COPY(name, fname); asPlain := plain;
  IF ~Prompt("File Name to Write", fname, TRUE, asPlain) THEN msg := "Cancelled"; RETURN FALSE END;
  IF fname = "" THEN msg := "Cancelled"; RETURN FALSE END;
  IF ~asPlain & ~Texts.OnlyCharacters(T) THEN msg := "The text contains objects, store it in Oberon"; RETURN FALSE END;
  Texts.StoreFile(fname, T, asPlain);
  COPY(fname, name); plain := asPlain; modified := FALSE;
  msg := "Wrote "; Append(msg, fname);
  IF plain THEN Append(msg, " as plain text") ELSE Append(msg, " as Oberon text") END;
  RETURN TRUE
END WriteOut;

PROCEDURE Find;
VAR s: ARRAY 256 OF CHAR; dummy: BOOLEAN; R, R1: Texts.Reader; p, start, i: LONGINT; c, c1: CHAR; wrapped: BOOLEAN;
BEGIN
  COPY(search, s); dummy := FALSE;
  IF ~Prompt("Search", s, FALSE, dummy) OR (s = "") THEN msg := "Cancelled"; RETURN END;
  COPY(s, search);
  start := cur + 1; IF start > T.len THEN start := 0 END;
  p := start; wrapped := FALSE;
  LOOP
    IF p >= T.len THEN
      IF wrapped THEN EXIT END;
      p := 0; wrapped := TRUE
    END;
    IF wrapped & (p >= start) THEN EXIT END;
    Texts.OpenReader(R, T, p); Texts.Read(R, c);
    IF c = s[0] THEN
      i := 1; Texts.OpenReader(R1, T, p + 1); Texts.Read(R1, c1);
      WHILE (s[i] # 0X) & ~R1.eot & (c1 = s[i]) DO INC(i); Texts.Read(R1, c1) END;
      IF s[i] = 0X THEN cur := p; goalCol := -1; IF wrapped THEN msg := "Search Wrapped" END; RETURN END
    END;
    INC(p)
  END;
  msg := "Not found"
END Find;

PROCEDURE ShowHelp;
VAR k: LONGINT;
BEGIN
  Goto(1, 1); CSI("2J"); Goto(1, 1);
  Str("xxs - a nano-like editor for Oberon texts and plain files"); Ch(CR); Ch(LF); Ch(CR); Ch(LF);
  Str("^O  Write Out: store the file; in the prompt ^T stores as plain or Oberon text"); Ch(CR); Ch(LF);
  Str("^X  Exit, asking to store changes"); Ch(CR); Ch(LF);
  Str("^K  Cut the line; ^K again adds the next line to the cut"); Ch(CR); Ch(LF);
  Str("^U  Paste the cut lines at the caret"); Ch(CR); Ch(LF);
  Str("^W  Where Is: search forward, from the top again at the end"); Ch(CR); Ch(LF);
  Str("^C  Location: line, column and character position"); Ch(CR); Ch(LF);
  Str("^A  Line Start   ^E  Line End   (also Home, End)"); Ch(CR); Ch(LF);
  Str("^Y  Prev Page    ^V  Next Page  (also PgUp, PgDn)"); Ch(CR); Ch(LF);
  Str("^L  Refresh the screen"); Ch(CR); Ch(LF); Ch(CR); Ch(LF);
  Str("Plain files stay plain; Oberon texts keep their fonts and colours, new text"); Ch(CR); Ch(LF);
  Str("gets the looks of the character before it."); Ch(CR); Ch(LF); Ch(CR); Ch(LF);
  Attr(7); Str(" Press any key "); Attr(0); Flush;
  k := ReadKey()
END ShowHelp;

PROCEDURE Key(k: LONGINT);
VAR p, ls, ln, n: LONGINT; buf: Texts.Buffer; cut: BOOLEAN;
BEGIN
  cut := FALSE; msg := "";
  IF (k # KUp) & (k # KDown) & (k # KPgUp) & (k # KPgDn) & (k # 19H) & (k # 16H) THEN goalCol := -1 END;
  IF (k = KUp) OR (k = KDown) THEN
    IF goalCol < 0 THEN goalCol := Col(cur) END;
    ls := LineStart(cur);
    IF k = KUp THEN IF ls > 0 THEN cur := PosAtCol(LineStart(ls - 1), goalCol) END
    ELSE p := NextLine(cur); IF p >= 0 THEN cur := PosAtCol(p, goalCol) END
    END
  ELSIF (k = KPgUp) OR (k = 19H) OR (k = KPgDn) OR (k = 16H) THEN
    IF goalCol < 0 THEN goalCol := Col(cur) END;
    n := height - 1; IF n < 1 THEN n := 1 END;
    p := LineStart(cur);
    WHILE n > 0 DO
      IF (k = KPgUp) OR (k = 19H) THEN
        IF p > 0 THEN p := LineStart(p - 1); IF top > 0 THEN top := LineStart(top - 1) END END
      ELSE
        ls := NextLine(p); IF ls >= 0 THEN p := ls; ls := NextLine(top); IF ls >= 0 THEN top := ls END END
      END;
      DEC(n)
    END;
    cur := PosAtCol(p, goalCol)
  ELSIF k = KLeft THEN cur := PrevPos(cur)
  ELSIF k = KRight THEN cur := NextPos(cur)
  ELSIF (k = KHome) OR (k = 1) THEN cur := LineStart(cur)
  ELSIF (k = KEnd) OR (k = 5) THEN cur := LineEnd(cur)
  ELSIF (k = 7FH) OR (k = 8) THEN  (* Backspace *)
    IF cur > 0 THEN p := PrevPos(cur); Delete(p, cur); cur := p END
  ELSIF k = KDel THEN
    IF cur < T.len THEN Delete(cur, NextPos(cur)) END
  ELSIF (k = 0DH) OR (k = 0AH) THEN Insert(Newline())
  ELSIF k = 9 THEN Insert(TAB)
  ELSIF k = 0BH THEN  (* ^K cut the line *)
    ls := LineStart(cur); p := NextLine(cur); IF p < 0 THEN p := T.len END;
    IF p > ls THEN
      IF ~lastCut OR (cutBuf = NIL) THEN NEW(cutBuf); Texts.OpenBuf(cutBuf) END;
      NEW(buf); Texts.OpenBuf(buf); Texts.Save(T, ls, p, buf); Texts.Copy(buf, cutBuf);
      Delete(ls, p); cur := ls
    END;
    cut := TRUE
  ELSIF k = 15H THEN  (* ^U paste *)
    IF cutBuf # NIL THEN
      NEW(buf); Texts.OpenBuf(buf); Texts.Copy(cutBuf, buf);
      n := buf.len; Texts.Insert(T, cur, buf); cur := cur + n; modified := TRUE
    END
  ELSIF k = 0FH THEN IF WriteOut() THEN END
  ELSIF k = 17H THEN Find
  ELSIF k = 3 THEN  (* ^C again: the location was shown by Edit *)
  ELSIF k = 7 THEN ShowHelp
  ELSIF k = 0CH THEN (* ^L refresh *) Goto(1, 1); CSI("2J")
  ELSIF k = 18H THEN  (* ^X exit *)
    IF modified THEN
      Goto(rows - 2, 1); Attr(7); Str("Save modified buffer?  Y Yes  N No  ^C Cancel"); Attr(0); CSI("K"); Flush;
      LOOP
        n := ReadKey();
        IF (n = ORD("y")) OR (n = ORD("Y")) THEN IF WriteOut() THEN running := FALSE END; EXIT
        ELSIF (n = ORD("n")) OR (n = ORD("N")) THEN running := FALSE; EXIT
        ELSIF (n = 3) OR (n = -1) THEN msg := "Cancelled"; EXIT
        END
      END
    ELSE running := FALSE
    END
  ELSIF (k >= 20H) & (k < 100H) THEN Insert(CHR(k))
  ELSIF k = -1 THEN running := FALSE  (* end of input *)
  END;
  lastCut := cut
END Key;

(* the location for ^C: line, column and position *)
PROCEDURE Location;
VAR ln, lines, p: LONGINT;
BEGIN
  ln := LineNo(cur); lines := LineNo(T.len);
  Goto(rows - 2, 1); Attr(7);
  Str(" line "); Int(ln); Ch("/"); Int(lines);
  Str(", col "); Int(Col(cur) + 1);
  Str(", char "); Int(cur); Ch("/"); Int(T.len); Ch(" ");
  Attr(0); CSI("K");
  p := 0
END Location;

PROCEDURE Edit(VAR fname: ARRAY OF CHAR);
VAR f: Files.File; R: Files.Rider; c: CHAR; k: LONGINT;
BEGIN
  COPY(fname, name); NEW(T);
  f := Files.Old(name);
  IF f # NIL THEN
    Files.Set(R, f, 0); Files.Read(R, c); Files.ReleaseRead(f);
    plain := (Files.Length(f) = 0) OR (c # 0F0X) & (c # 0F7X) & (c # 01X);
    Texts.Open(T, name); msg := ""
  ELSE Texts.Open(T, name); plain := TRUE; msg := "New File"
  END;
  cur := 0; top := 0; hcol := 0; goalCol := -1; modified := FALSE; lastCut := FALSE; cutBuf := NIL;
  Texts.OpenWriter(W);
  IF ~Raw() THEN RETURN END;
  running := TRUE;
  WHILE running DO
    Draw;
    k := ReadKey();
    IF k = 3 THEN Draw; Location; Flush; k := ReadKey() END;  (* ^C shows the location until the next key *)
    Key(k)
  END;
  Restore
END Edit;

(** xxs.Open file -- edit file, a new one when it does not exist *)
PROCEDURE Open*;
VAR A: Texts.Reader; fname: ARRAY 256 OF CHAR; r: LONGINT;
BEGIN
  Texts.OpenArgs(A);
  IF Texts.Arg(A, fname) THEN Edit(fname)
  ELSE
    fname := "usage: xxs.Open file"; fname[20] := LF; fname[21] := 0X;
    r := Linux0.Write0(1, SYSTEM.ADR(fname[0]), 21)
  END
END Open;

(** xxs.Fit file -- the same, the size that fits *)
PROCEDURE Fit*;
BEGIN Open
END Fit;

BEGIN
  raw := FALSE; opos := 0; search := ""
END xxs.
