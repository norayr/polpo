MODULE texts;

IMPORT Files, Objects, Texts0;

CONST
  Inval* = Texts0.Inval; Name* = Texts0.Name; String* = Texts0.String;
  Int* = Texts0.Int; Real* = Texts0.Real; LongReal* = Texts0.LongReal;
  Char* = Texts0.Char; Object* = Texts0.Object; ElemChar* = 1CX;

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

BEGIN
  Texts0.DefaultLibrary := DefaultLibrary;
  Texts0.Update := NIL
END texts.
