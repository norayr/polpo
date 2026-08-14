MODULE Oberon0;

IMPORT Kernel, Texts := texts, Modules, Files;

CONST OberonText = "Oberon.Text";

TYPE
  ParList* = POINTER TO ParRec;
  ParRec* = RECORD
    text*: Texts.Text;
    pos*: LONGINT
  END;
  ParHook* = PROCEDURE (par: ParList);

VAR
  Log*: Texts.Text;
  Par*: ParList;
  OptionChar*: CHAR;
  parHook: ParHook;
  conftext: Texts.Text;
  conftime, confdate: LONGINT;

PROCEDURE GetClock*(VAR t, d: LONGINT);
BEGIN Kernel.GetClock(t, d) END GetClock;

PROCEDURE Collect*;
BEGIN Kernel.GC END Collect;

PROCEDURE SetOptionChar*(ch: CHAR);
BEGIN OptionChar := ch END SetOptionChar;

PROCEDURE SetLog*(log: Texts.Text);
BEGIN Log := log END SetLog;

PROCEDURE SetParHook*(hook: ParHook);
BEGIN parHook := hook END SetParHook;

PROCEDURE SkipGroup(VAR S: Texts.Scanner);
VAR openBraces: INTEGER;
BEGIN
  openBraces := 1;
  REPEAT
    Texts.Scan(S);
    IF S.class = Texts.Char THEN
      IF S.c = "{" THEN INC(openBraces)
      ELSIF S.c = "}" THEN DEC(openBraces)
      END
    END
  UNTIL S.eot OR (openBraces = 0)
END SkipGroup;

PROCEDURE OpenScanner*(VAR S: Texts.Scanner; name: ARRAY OF CHAR);
VAR i, j: INTEGER; done, eos: BOOLEAN; part: ARRAY 32 OF CHAR;
  f: Files.File; t, d: LONGINT;
BEGIN
  f := Files.Old(OberonText);
  IF f = NIL THEN t := 0; d := 0
  ELSE Files.GetDate(f, t, d); Files.ReleaseRead(f)
  END;
  IF (t # conftime) OR (d # confdate) THEN
    conftime := t; confdate := d; Texts.Open(conftext, OberonText)
  END;
  Texts.OpenScanner(S, conftext, 0); Texts.Scan(S); done := TRUE;
  WHILE (name[0] # 0X) & ~S.eot & done DO
    i := 0;
    WHILE (name[i] # 0X) & (name[i] # ".") DO part[i] := name[i]; INC(i) END;
    part[i] := 0X;
    IF name[i] = "." THEN INC(i) END;
    j := 0;
    WHILE name[i] # 0X DO name[j] := name[i]; INC(i); INC(j) END;
    name[j] := 0X;
    done := FALSE; eos := FALSE;
    REPEAT
      IF S.class IN {Texts.Name, Texts.String} THEN
        Texts.Scan(S);
        IF ~S.eot THEN
          IF (S.class = Texts.Char) & (S.c = "=") THEN
            IF S.s = part THEN
              Texts.Scan(S);
              IF ~S.eot & (S.class = Texts.Char) & (S.c = "{") THEN Texts.Scan(S) END;
              done := TRUE
            ELSE
              Texts.Scan(S);
              IF ~S.eot & (S.class = Texts.Char) & (S.c = "{") THEN SkipGroup(S) END;
              IF ~S.eot THEN Texts.Scan(S) ELSE eos := TRUE END
            END
          ELSE eos := TRUE
          END
        ELSE eos := TRUE
        END
      ELSIF (S.class = Texts.Char) & (S.c = "{") THEN
        SkipGroup(S);
        IF ~S.eot THEN Texts.Scan(S) ELSE eos := TRUE END
      ELSE eos := TRUE
      END
    UNTIL done OR eos
  END;
  IF ~done OR (conftext.len = 0) THEN S.class := Texts.Inval END
END OpenScanner;

PROCEDURE Call*(name: ARRAY OF CHAR; par: ParList; new: BOOLEAN; VAR res: INTEGER);
VAR Mod: Modules.Module; P: Modules.Command; i, j: LONGINT;
BEGIN
  res := 1; i := 0; j := 0;
  WHILE name[j] # 0X DO IF name[j] = "." THEN i := j END; INC(j) END;
  IF i = 0 THEN i := j; name[j+1] := 0X END;
  name[i] := 0X;
  IF new THEN
    Modules.Free(name, FALSE);
    IF (Modules.res = 0) OR (Modules.res = 6) THEN Mod := Modules.ThisMod(name) END
  ELSE Mod := Modules.ThisMod(name)
  END;
  IF Modules.res = 0 THEN
    INC(i); j := i;
    WHILE name[j] # 0X DO name[j-i] := name[j]; INC(j) END;
    name[j-i] := 0X;
    P := Modules.ThisCommand(Mod, name);
    IF Modules.res = 0 THEN
      Par := par;
      IF parHook # NIL THEN parHook(par) END;
      P; res := 0
    ELSE res := Modules.res END
  ELSE res := Modules.res
  END
END Call;

PROCEDURE GetSelection*(VAR text: Texts.Text; VAR beg, end, time: LONGINT);
BEGIN text := NIL; beg := 0; end := 0; time := -1 END GetSelection;

BEGIN
  NEW(Par); NEW(Par.text); Par.pos := 0; Texts.Open(Par.text, "");
  NEW(Log); Texts.Open(Log, ""); OptionChar := '-';
  conftime := -1; confdate := -1; NEW(conftext)
END Oberon0.
