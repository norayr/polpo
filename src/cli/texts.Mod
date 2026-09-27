MODULE texts;

IMPORT Kernel, Files, Objects := objects, Texts0, Oberon := Oberon0, out;

CONST
  Inval* = Texts0.Inval; Name* = Texts0.Name; String* = Texts0.String;
  Int* = Texts0.Int; Real* = Texts0.Real; LongReal* = Texts0.LongReal;
  Char* = Texts0.Char; Object* = Texts0.Object; ElemChar* = 1CX;
  ESC = 1BX;

TYPE
  Text* = Texts0.Text;
  Buffer* = Texts0.Buffer;
  Reader* = Texts0.Reader;
  Scanner* = Texts0.Scanner;
  Writer* = Texts0.Writer;
  Finder* = Texts0.Finder;

PROCEDURE OpenBuf*(B: Buffer);
BEGIN Texts0.OpenBuf(B) END OpenBuf;

PROCEDURE Copy*(SB, DB: Buffer);
BEGIN Texts0.Copy(SB, DB) END Copy;

PROCEDURE Recall*(VAR B: Buffer);
BEGIN Texts0.Recall(B) END Recall;

PROCEDURE Save*(T: Text; beg, end: LONGINT; B: Buffer);
BEGIN Texts0.Save(T, beg, end, B) END Save;

PROCEDURE Insert*(T: Text; pos: LONGINT; B: Buffer);
BEGIN Texts0.Insert(T, pos, B) END Insert;

PROCEDURE Append*(T: Text; B: Buffer);
BEGIN Texts0.Append(T, B) END Append;

PROCEDURE Delete*(T: Text; beg, end: LONGINT);
BEGIN Texts0.Delete(T, beg, end) END Delete;

PROCEDURE ChangeLooks*(T: Text; beg, end: LONGINT; sel: SET; lib: Objects.Library; col, voff: SHORTINT);
BEGIN Texts0.ChangeLooks(T, beg, end, sel, lib, col, voff) END ChangeLooks;

PROCEDURE OpenReader*(VAR R: Reader; T: Text; pos: LONGINT);
BEGIN Texts0.OpenReader(R, T, pos) END OpenReader;

PROCEDURE Read*(VAR R: Reader; VAR ch: CHAR);
BEGIN Texts0.Read(R, ch) END Read;

PROCEDURE Pos*(VAR R: Reader): LONGINT;
BEGIN RETURN Texts0.Pos(R) END Pos;

PROCEDURE FontName*(VAR R: Reader; VAR name: ARRAY OF CHAR);
BEGIN
  IF R.lib = NIL THEN name[0] := 0X ELSE COPY(R.lib.name, name) END
END FontName;

PROCEDURE IsCharacterLibrary*(lib: Objects.Library): BOOLEAN;
BEGIN RETURN Texts0.IsCharacterLibrary(lib) END IsCharacterLibrary;

PROCEDURE OpenScanner*(VAR S: Scanner; T: Text; pos: LONGINT);
BEGIN Texts0.OpenScanner(S, T, pos) END OpenScanner;

PROCEDURE Scan*(VAR S: Scanner);
BEGIN Texts0.Scan(S) END Scan;

PROCEDURE OpenWriter*(VAR W: Writer);
BEGIN Texts0.OpenWriter(W) END OpenWriter;

PROCEDURE SetFont*(VAR W: Writer; lib: Objects.Library);
BEGIN Texts0.SetFont(W, lib) END SetFont;

PROCEDURE SetColor*(VAR W: Writer; col: SHORTINT);
BEGIN Texts0.SetColor(W, col) END SetColor;

PROCEDURE SetOffset*(VAR W: Writer; voff: SHORTINT);
BEGIN Texts0.SetOffset(W, voff) END SetOffset;

PROCEDURE Write*(VAR W: Writer; ch: CHAR);
BEGIN Texts0.Write(W, ch) END Write;

PROCEDURE WriteLn*(VAR W: Writer);
BEGIN Texts0.WriteLn(W) END WriteLn;

PROCEDURE WriteString*(VAR W: Writer; s: ARRAY OF CHAR);
BEGIN Texts0.WriteString(W, s) END WriteString;

PROCEDURE WriteInt*(VAR W: Writer; x, n: LONGINT);
BEGIN Texts0.WriteInt(W, x, n) END WriteInt;

PROCEDURE WriteHex*(VAR W: Writer; x: LONGINT);
BEGIN Texts0.WriteHex(W, x) END WriteHex;

PROCEDURE WriteReal*(VAR W: Writer; x: REAL; n: LONGINT);
BEGIN Texts0.WriteReal(W, x, n) END WriteReal;

PROCEDURE WriteLongReal*(VAR W: Writer; x: LONGREAL; n: LONGINT);
BEGIN Texts0.WriteLongReal(W, x, n) END WriteLongReal;

PROCEDURE WriteDate*(VAR W: Writer; t, d: LONGINT);
BEGIN Texts0.WriteDate(W, t, d) END WriteDate;

PROCEDURE Open*(T: Text; name: ARRAY OF CHAR);
BEGIN Texts0.Open(T, name) END Open;

PROCEDURE Store*(VAR R: Files.Rider; T: Text);
VAR len: LONGINT;
BEGIN Texts0.Store(T, Files.Base(R), Files.Pos(R), len); Files.Set(R, Files.Base(R), Files.Pos(R) + len) END Store;

PROCEDURE OpenFinder*(VAR F: Finder; T: Text; pos: LONGINT);
BEGIN Texts0.OpenFinder(F, T, pos) END OpenFinder;

PROCEDURE FindObj*(VAR F: Finder; VAR obj: Objects.Object);
BEGIN Texts0.FindObj(F, obj) END FindObj;

PROCEDURE WriteObj*(VAR W: Writer; obj: Objects.Object);
BEGIN Texts0.WriteObj(W, obj) END WriteObj;

PROCEDURE DefaultLibrary(): Objects.Library;
BEGIN RETURN NIL END DefaultLibrary;

(* ----- showing texts on the terminal ----- *)

(* Fonts are not loaded on the console, so a font of a text is a library with its name
   only: enough to show its style. The Fonts module replaces this when it is loaded. *)
PROCEDURE LoadNameOnly(L: Objects.Library);
END LoadNameOnly;

PROCEDURE NewNameOnly(): Objects.Library;
VAR L: Objects.Library;
BEGIN NEW(L); Objects.OpenLibrary(L); L.Load := LoadNameOnly; RETURN L
END NewNameOnly;

PROCEDURE Loaded(name: ARRAY OF CHAR): BOOLEAN;
VAR m: Kernel.Module;
BEGIN
  m := Kernel.modules; WHILE (m # NIL) & (m.name # name) DO m := m.next END;
  RETURN m # NIL
END Loaded;

(* size and style of a font name: Syntax10b.Scn.Fnt is 10, bold; Oberon10i.Scn.Fnt 10, italic *)
PROCEDURE ParseFont(lib: Objects.Library; VAR size: INTEGER; VAR bold, italic: BOOLEAN);
VAR i: INTEGER;
BEGIN
  size := 0; bold := FALSE; italic := FALSE;
  IF lib # NIL THEN
    i := 0;
    WHILE (lib.name[i] # 0X) & ((lib.name[i] < "0") OR (lib.name[i] > "9")) DO INC(i) END;
    WHILE (lib.name[i] >= "0") & (lib.name[i] <= "9") DO
      IF size < 1000 THEN size := size * 10 + ORD(lib.name[i]) - ORD("0") END; INC(i)
    END;
    WHILE (lib.name[i] # 0X) & (lib.name[i] # ".") DO
      IF CAP(lib.name[i]) = "B" THEN bold := TRUE ELSIF CAP(lib.name[i]) = "I" THEN italic := TRUE END;
      INC(i)
    END
  END
END ParseFont;

(* the size most characters of T have: larger sizes are headings *)
PROCEDURE MainSize(T: Text): INTEGER;
VAR R: Reader; ch: CHAR; n: ARRAY 100 OF LONGINT; size, i, main: INTEGER; bold, italic: BOOLEAN;
BEGIN
  i := 0; WHILE i < LEN(n) DO n[i] := 0; INC(i) END;
  OpenReader(R, T, 0); Read(R, ch);
  WHILE ~R.eot DO
    ParseFont(R.lib, size, bold, italic);
    IF (size < LEN(n)) & (ch > " ") THEN INC(n[size]) END;
    Read(R, ch)
  END;
  main := 0; i := 1;
  WHILE i < LEN(n) DO IF n[i] > n[main] THEN main := i END; INC(i) END;
  RETURN main
END MainSize;

(* VT100 attribute: ESC [ n m *)
PROCEDURE Attr(n: INTEGER);
BEGIN
  out.Char(ESC); out.Char("[");
  IF n >= 10 THEN out.Char(CHR(ORD("0") + n DIV 10)) END;
  out.Char(CHR(ORD("0") + n MOD 10)); out.Char("m")
END Attr;

(* Oberon palette: 0-7 are ANSI 30-37, 8-14 bright 90-97, 15 is the default colour *)
PROCEDURE Color(col: SHORTINT);
BEGIN
  IF (col >= 0) & (col < 8) THEN Attr(30 + col)
  ELSIF (col >= 8) & (col < 15) THEN Attr(90 + col - 8)
  END
END Color;

(** Write the text file name to standard output, plain ASCII files too. rich: fonts and
  colours as VT100 attributes, bold and italic fonts bold and italic, sizes above the main
  size of the text (headings) bold and underlined; else the characters only. Objects in
  the text are left out. *)
PROCEDURE ShowFile*(name: ARRAY OF CHAR; rich: BOOLEAN);
VAR f: Files.File; T: Text; R: Reader; ch: CHAR;
  size, main: INTEGER; bold, italic, under, curBold, curItalic, curUnder: BOOLEAN; col, curCol: SHORTINT;
BEGIN
  f := Files.Old(name);
  IF f = NIL THEN out.String(name); out.String(" not found"); out.Ln; RETURN END;
  Files.ReleaseRead(f);
  NEW(T); Open(T, name);
  IF rich THEN main := MainSize(T) END;
  OpenReader(R, T, 0); Read(R, ch);
  curBold := FALSE; curItalic := FALSE; curUnder := FALSE; curCol := 15;
  WHILE ~R.eot DO
    IF rich & (ch > " ") THEN  (* attributes change at visible characters only *)
      ParseFont(R.lib, size, bold, italic); col := R.col;
      under := (main > 0) & (size > main);
      IF under THEN bold := TRUE END;
      IF (bold # curBold) OR (italic # curItalic) OR (under # curUnder) OR (col # curCol) THEN
        Attr(0); curBold := bold; curItalic := italic; curUnder := under; curCol := col;
        IF bold THEN Attr(1) END;
        IF italic THEN Attr(3) END;
        IF under THEN Attr(4) END;
        Color(col)
      END
    END;
    IF IsCharacterLibrary(R.lib) THEN
      IF (ch >= " ") OR (ch = 09X) THEN out.Char(ch)
      ELSIF ch = 0DX THEN
        IF curUnder THEN Attr(0); curBold := FALSE; curItalic := FALSE; curUnder := FALSE; curCol := 15 END;
        out.Ln
      END
    END;
    Read(R, ch)
  END;
  IF rich & (curBold OR curItalic OR curUnder OR (curCol # 15)) THEN Attr(0) END
END ShowFile;

(* ----- editing texts from the console ----- *)

(* position of the first occurrence of pat at or after pos in T, or -1 *)
PROCEDURE Find(T: Text; pos: LONGINT; VAR pat: ARRAY OF CHAR): LONGINT;
VAR R, R1: Reader; ch, ch1: CHAR; i: INTEGER;
BEGIN
  IF pat[0] = 0X THEN RETURN -1 END;
  OpenReader(R, T, pos); Read(R, ch);
  WHILE ~R.eot DO
    IF ch = pat[0] THEN
      OpenReader(R1, T, pos + 1); i := 1; Read(R1, ch1);
      WHILE (pat[i] # 0X) & ~R1.eot & (ch1 = pat[i]) DO INC(i); Read(R1, ch1) END;
      IF pat[i] = 0X THEN RETURN pos END
    END;
    INC(pos); Read(R, ch)
  END;
  RETURN -1
END Find;

(* does T contain only characters, no objects that the console cannot store *)
PROCEDURE OnlyCharacters(T: Text): BOOLEAN;
VAR R: Reader; ch: CHAR;
BEGIN
  OpenReader(R, T, 0); Read(R, ch);
  WHILE ~R.eot & IsCharacterLibrary(R.lib) DO Read(R, ch) END;
  RETURN R.eot
END OnlyCharacters;

(* open the text name for editing; plain: the file is ASCII, not an Oberon text *)
PROCEDURE OpenEdit(VAR name: ARRAY OF CHAR; VAR T: Text; VAR plain: BOOLEAN): BOOLEAN;
VAR f: Files.File; R: Files.Rider; ch: CHAR;
BEGIN
  f := Files.Old(name);
  IF f = NIL THEN out.String(name); out.String(" not found"); out.Ln; RETURN FALSE END;
  Files.Set(R, f, 0); Files.Read(R, ch); Files.ReleaseRead(f);
  plain := (Files.Length(f) = 0) OR (ch # 0F0X) & (ch # 0F7X) & (ch # 01X);
  NEW(T); Open(T, name);
  IF ~OnlyCharacters(T) THEN
    out.String(name); out.String(" contains objects, edit it in Oberon"); out.Ln; RETURN FALSE
  END;
  RETURN TRUE
END OpenEdit;

(* store T as name, the old file as name.Bak; a plain text stays plain *)
PROCEDURE StoreEdit(VAR name: ARRAY OF CHAR; T: Text; plain: BOOLEAN);
VAR f: Files.File; W: Files.Rider; R: Reader; ch: CHAR; bak: ARRAY 256 OF CHAR; i, res: INTEGER;
BEGIN
  f := Files.New(name);
  IF f = NIL THEN out.String(name); out.String(" cannot be written"); out.Ln; RETURN END;
  Files.Set(W, f, 0);
  IF plain THEN
    OpenReader(R, T, 0); Read(R, ch);
    WHILE ~R.eot DO
      IF ch = 0DX THEN ch := 0AX END;  (* texts hold line ends as CR *)
      Files.Write(W, ch); Read(R, ch)
    END
  ELSE Store(W, T)
  END;
  i := 0; WHILE (name[i] # 0X) & (i < LEN(bak) - 5) DO bak[i] := name[i]; INC(i) END;
  bak[i] := "."; bak[i+1] := "B"; bak[i+2] := "a"; bak[i+3] := "k"; bak[i+4] := 0X;
  Files.Rename(name, bak, res);
  Files.Register(f)
END StoreEdit;

(** texts.Replace file "old" "new" ~ -- replace every occurrence of old by new in the text
  file, "" as new deletes. The new text gets the font and colour of the old. The file is
  stored, its old version kept as .Bak; a plain ASCII file stays plain. *)
PROCEDURE Replace*;
VAR S: Scanner; name, old, new: ARRAY 64 OF CHAR; T: Text; R: Reader; W: Writer;
  ch: CHAR; plain: BOOLEAN; pos, oldlen, newlen, n: LONGINT;
BEGIN
  OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Scan(S);
  IF ~(S.class IN {Name, String}) THEN out.String("usage: texts.Replace file old new ~"); out.Ln; RETURN END;
  COPY(S.s, name); Scan(S);
  IF ~(S.class IN {Name, String}) THEN
    out.String("texts.Replace: old text missing, quote texts with spaces or digits"); out.Ln; RETURN
  END;
  COPY(S.s, old); Scan(S);
  IF ~(S.class IN {Name, String}) THEN  (* deleting needs an explicit "" *)
    out.String("texts.Replace: new text missing, quote texts with spaces or digits"); out.Ln; RETURN
  END;
  COPY(S.s, new);
  IF OpenEdit(name, T, plain) THEN
    oldlen := 0; WHILE old[oldlen] # 0X DO INC(oldlen) END;
    newlen := 0; WHILE new[newlen] # 0X DO INC(newlen) END;
    n := 0; pos := Find(T, 0, old);
    WHILE pos >= 0 DO
      OpenReader(R, T, pos); Read(R, ch);
      OpenWriter(W); SetFont(W, R.lib); SetColor(W, R.col); SetOffset(W, R.voff);
      Delete(T, pos, pos + oldlen);
      IF newlen > 0 THEN WriteString(W, new); Insert(T, pos, W.buf) END;
      INC(n); pos := Find(T, pos + newlen, old)
    END;
    out.String(name); out.Char(" "); out.Int(n, 0); out.String(" replaced"); out.Ln;
    IF n > 0 THEN StoreEdit(name, T, plain) END
  END
END Replace;

(** texts.DeleteLines file "text" ~ -- delete every line of the text file that contains
  text. The file is stored like with texts.Replace. *)
PROCEDURE DeleteLines*;
VAR S: Scanner; name, pat: ARRAY 64 OF CHAR; T: Text; R: Reader; ch: CHAR; plain: BOOLEAN;
  beg, end, m, n: LONGINT;
BEGIN
  OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Scan(S);
  IF ~(S.class IN {Name, String}) THEN out.String("usage: texts.DeleteLines file text ~"); out.Ln; RETURN END;
  COPY(S.s, name); Scan(S);
  IF ~(S.class IN {Name, String}) THEN
    out.String("texts.DeleteLines: text missing, quote texts with spaces or digits"); out.Ln; RETURN
  END;
  COPY(S.s, pat);
  IF OpenEdit(name, T, plain) THEN
    n := 0; beg := 0; m := Find(T, 0, pat);
    WHILE m >= 0 DO
      (* the line around m: from beg, the start of a line before m *)
      OpenReader(R, T, beg); end := beg; Read(R, ch);
      WHILE ~R.eot & ((end < m) OR (ch # 0DX) & (ch # 0AX)) DO
        INC(end); IF (ch = 0DX) OR (ch = 0AX) THEN beg := end END; Read(R, ch)
      END;
      IF ~R.eot THEN INC(end) END;  (* with its line end *)
      Delete(T, beg, end); INC(n); m := Find(T, beg, pat)
    END;
    out.String(name); out.Char(" "); out.Int(n, 0); out.String(" lines deleted"); out.Ln;
    IF n > 0 THEN StoreEdit(name, T, plain) END
  END
END DeleteLines;

PROCEDURE ShowFiles(rich: BOOLEAN);
VAR S: Scanner;
BEGIN
  OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Scan(S);
  WHILE S.class IN {Name, String} DO ShowFile(S.s, rich); Scan(S) END
END ShowFiles;

(** texts.Show file... -- show texts with their fonts and colours *)
PROCEDURE Show*;
BEGIN ShowFiles(TRUE) END Show;

(** texts.ShowPlain file... -- show the characters of texts only *)
PROCEDURE ShowPlain*;
BEGIN ShowFiles(FALSE) END ShowPlain;

BEGIN
  IF ~Loaded("Fonts") THEN Objects.Register("Fnt", NewNameOnly) END;
  Texts0.DefaultLibrary := DefaultLibrary;
  Texts0.Update := NIL
END texts.
