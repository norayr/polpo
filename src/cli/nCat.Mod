MODULE nCat;
(** Cat-like utility for Oberon text files.
    Handles both plain ASCII files and binary Oberon .Text format.
    Default: renders font attributes (bold, italic) and color via VT100 escapes.
    -p / -plain: plain text output only, like ocat. *)

IMPORT Files, Texts := nTexts, Oberon := nOberon, nOut;

CONST
  ESC = 1BX;

PROCEDURE ParseFont(name: ARRAY OF CHAR; VAR bold, italic: BOOLEAN);
VAR i: INTEGER;
BEGIN
  (* skip alphabetic prefix, skip digits, then the next char encodes the variant *)
  i := 0;
  WHILE (name[i] # 0X) & ((name[i] < '0') OR (name[i] > '9')) DO INC(i) END;
  WHILE (name[i] >= '0') & (name[i] <= '9') DO INC(i) END;
  bold   := (name[i] = 'b') OR (name[i] = 'B');
  italic := (name[i] = 'i') OR (name[i] = 'I')
END ParseFont;

PROCEDURE EmitReset;
BEGIN nOut.Char(ESC); nOut.Char('['); nOut.Char('0'); nOut.Char('m') END EmitReset;

PROCEDURE EmitBold;
BEGIN nOut.Char(ESC); nOut.Char('['); nOut.Char('1'); nOut.Char('m') END EmitBold;

PROCEDURE EmitItalic;
BEGIN nOut.Char(ESC); nOut.Char('['); nOut.Char('3'); nOut.Char('m') END EmitItalic;

(* Oberon palette: 0-7 map to ANSI 30-37, 8-14 to bright 90-97, 15=white=default *)
PROCEDURE EmitColor(col: SHORTINT);
BEGIN
  IF (col >= 0) & (col < 8) THEN
    nOut.Char(ESC); nOut.Char('['); nOut.Char('3');
    nOut.Char(CHR(ORD('0') + col)); nOut.Char('m')
  ELSIF (col >= 8) & (col < 15) THEN
    nOut.Char(ESC); nOut.Char('['); nOut.Char('9');
    nOut.Char(CHR(ORD('0') + col - 8)); nOut.Char('m')
  END
END EmitColor;

PROCEDURE CatFile(path: ARRAY OF CHAR; plain: BOOLEAN);
VAR
  T: Texts.Text;
  R: Texts.Reader;
  ch: CHAR;
  fname: ARRAY 64 OF CHAR;
  bold, italic, curBold, curItalic: BOOLEAN;
  col, curCol: SHORTINT;
BEGIN
  IF Files.Old(path) = NIL THEN
    nOut.String("ncat: cannot open "); nOut.String(path); nOut.Ln;
    RETURN
  END;
  NEW(T); Texts.Open(T, path);
  Texts.OpenReader(R, T, 0); Texts.Read(R, ch);
  curBold := FALSE; curItalic := FALSE; curCol := 15;
  WHILE ~R.eot DO
    IF ~plain THEN
      Texts.FontName(R, fname);
      ParseFont(fname, bold, italic);
      col := R.col;
      IF (bold # curBold) OR (italic # curItalic) OR (col # curCol) THEN
        EmitReset; curBold := FALSE; curItalic := FALSE; curCol := 15;
        IF bold        THEN EmitBold;       curBold   := TRUE  END;
        IF italic      THEN EmitItalic;     curItalic := TRUE  END;
        IF col # 15    THEN EmitColor(col); curCol    := col   END
      END
    END;
    IF    ch >= ' '  THEN nOut.Char(ch)
    ELSIF ch = 09X   THEN nOut.Char(ch)   (* TAB preserved *)
    ELSIF ch = 0DX   THEN nOut.Ln         (* CR -> LF *)
    (* ElemChar 1CX and other controls skipped *)
    END;
    Texts.Read(R, ch)
  END;
  IF ~plain & (curBold OR curItalic OR (curCol # 15)) THEN EmitReset END
END CatFile;

PROCEDURE Cat*;
VAR S: Texts.Scanner; path: ARRAY 256 OF CHAR; plain: BOOLEAN; i: INTEGER;
BEGIN
  plain := FALSE;
  Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos);
  Texts.Scan(S);
  WHILE (S.class = Texts.Name) OR ((S.class = Texts.Char) & (S.c = '-')) DO
    IF (S.class = Texts.Char) & (S.c = '-') THEN
      Texts.Scan(S);
      IF (S.class = Texts.Name) & (S.s[0] = 'p') THEN plain := TRUE END;
      Texts.Scan(S)
    ELSE
      i := 0;
      WHILE (S.s[i] # 0X) & (i < LEN(path)-1) DO path[i] := S.s[i]; INC(i) END;
      path[i] := 0X;
      CatFile(path, plain);
      Texts.Scan(S)
    END
  END
END Cat;

END nCat.
