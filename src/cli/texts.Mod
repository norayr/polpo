MODULE texts;

IMPORT Files, Objects := objects, Texts0, Oberon := Oberon0, out;

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

(* bold and italic from a font name: the letter after the size, Syntax10b.Scn.Fnt *)
PROCEDURE ParseFont(VAR name: ARRAY OF CHAR; VAR bold, italic: BOOLEAN);
VAR i: INTEGER;
BEGIN
  i := 0;
  WHILE (name[i] # 0X) & ((name[i] < "0") OR (name[i] > "9")) DO INC(i) END;
  WHILE (name[i] >= "0") & (name[i] <= "9") DO INC(i) END;
  bold := (name[i] = "b") OR (name[i] = "B");
  italic := (name[i] = "i") OR (name[i] = "I")
END ParseFont;

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
  colours as VT100 bold, italic and colour; else the characters only. Objects in the text
  are left out. *)
PROCEDURE ShowFile*(name: ARRAY OF CHAR; rich: BOOLEAN);
VAR f: Files.File; T: Text; R: Reader; ch: CHAR; fname: ARRAY 64 OF CHAR;
  bold, italic, curBold, curItalic: BOOLEAN; col, curCol: SHORTINT;
BEGIN
  f := Files.Old(name);
  IF f = NIL THEN out.String(name); out.String(" not found"); out.Ln; RETURN END;
  Files.ReleaseRead(f);
  NEW(T); Open(T, name);
  OpenReader(R, T, 0); Read(R, ch);
  curBold := FALSE; curItalic := FALSE; curCol := 15;
  WHILE ~R.eot DO
    IF rich THEN
      FontName(R, fname); ParseFont(fname, bold, italic); col := R.col;
      IF (bold # curBold) OR (italic # curItalic) OR (col # curCol) THEN
        Attr(0); curBold := bold; curItalic := italic; curCol := col;
        IF bold THEN Attr(1) END;
        IF italic THEN Attr(3) END;
        Color(col)
      END
    END;
    IF IsCharacterLibrary(R.lib) THEN
      IF (ch >= " ") OR (ch = 09X) THEN out.Char(ch)
      ELSIF ch = 0DX THEN out.Ln
      END
    END;
    Read(R, ch)
  END;
  IF rich & (curBold OR curItalic OR (curCol # 15)) THEN Attr(0) END
END ShowFile;

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
  Texts0.DefaultLibrary := DefaultLibrary;
  Texts0.Update := NIL
END texts.
