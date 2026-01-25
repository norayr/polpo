MODULE nOberon;
(* this version should not have dependency on graphics -- noch *)
  IMPORT Kernel, Texts := nTexts, Modules := nModules, nOut, Files;

  CONST
    OberonText = "Oberon.Text";

  TYPE
    ParList* = POINTER TO ParRec;
    ParRec* = RECORD
      text*: Texts.Text;
      pos*: LONGINT
    END;

  VAR
    Log*:        Texts.Text;
    Par*:        ParList;
    OptionChar*: CHAR;
    R: Texts.Reader;
    W: Texts.Writer;
    conftext: Texts.Text;
    conftime, confdate: LONGINT;

  (*clocks*)
  PROCEDURE GetClock* (VAR t, d: LONGINT);
  BEGIN Kernel.GetClock(t, d)
  END GetClock;

  (* Configuration =  Group.
    Group = { Entry }.
    Entry = [ Name "=" ] Value.
    Value = Token | "{" Group "}".
    Token = any token from Texts.Scanner, where "{" and "}" must occur pairwise.
    A named group is referred to as a "section". *)

  PROCEDURE SkipGroup (VAR S: Texts.Scanner);
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

  (** Open a scanner at a specific section of the Oberon Text. Scans the first symbol in the section.
      Returns S.class = Texts.Inval on error. *)
  PROCEDURE OpenScanner* (VAR S: Texts.Scanner; name: ARRAY OF CHAR);
    VAR i, j: INTEGER; done, eos: BOOLEAN; part: ARRAY 32 OF CHAR;
      f: Files.File; t, d: LONGINT;
  BEGIN
    f := Files.Old(OberonText);
    IF f = NIL THEN t := 0; d := 0 ELSE Files.GetDate(f, t, d) END;
    IF (t # conftime) OR (d # confdate) THEN
      conftime := t; confdate := d;
      Texts.Open(conftext, OberonText)
    END;
    Texts.OpenScanner(S, conftext, 0); Texts.Scan(S); done := TRUE;
    WHILE (name[0] # 0X) & ~S.eot & done DO
      (* extract name part *)
      i := 0;
      WHILE (name[i] # 0X) & (name[i] # ".") DO
        part[i] := name[i]; INC(i)
      END;
      part[i] := 0X;
      IF name[i] = "." THEN INC(i) END;
      j := 0;
      WHILE name[i] # 0X DO
        name[j] := name[i]; INC(i); INC(j)
      END;
      name[j] := 0X;
      done := FALSE; eos := FALSE;
      REPEAT
        IF (S.class IN {Texts.Name, Texts.String}) THEN
          Texts.Scan(S);
          IF ~S.eot THEN
            IF (S.class = Texts.Char) & (S.c = "=") THEN (* named entry *)
              IF S.s = part THEN
                Texts.Scan(S);
                IF ~S.eot & (S.class = Texts.Char) & (S.c = "{") THEN
                  Texts.Scan(S)
                END;
                done := TRUE
              ELSE
                Texts.Scan(S);
                IF ~S.eot & (S.class = Texts.Char) & (S.c = "{") THEN
                  SkipGroup(S)
                END;
                IF ~S.eot THEN Texts.Scan(S) ELSE eos := TRUE END
              END
            ELSE eos := TRUE
            END
          ELSE eos := TRUE
          END
        ELSIF (S.class = Texts.Char) & (S.c = "{") THEN (* unnamed entry *)
          SkipGroup(S);
          IF ~S.eot THEN Texts.Scan(S) ELSE eos := TRUE END
        ELSE eos := TRUE
        END
      UNTIL done OR eos
    END;
    IF ~done OR (conftext.len = 0) THEN S.class := Texts.Inval END
  END OpenScanner;

  (*command interpretation*)
  PROCEDURE Call* (name: ARRAY OF CHAR; par: ParList; new: BOOLEAN; VAR res: INTEGER);
    VAR Mod: Modules.Module; P: Modules.Command; i, j: LONGINT;
  BEGIN
    res := 1;
    i := 0; j := 0;
    WHILE name[j] # 0X DO
      IF name[j] = "." THEN i := j END;
      INC(j)
    END;
    IF i = 0 THEN i := j; name[j+1] := 0X END;
    name[i] := 0X;
    IF new THEN
      Modules.Free(name, FALSE);
      IF (Modules.res = 0) OR (Modules.res = 6) THEN
        Mod := Modules.ThisMod(name)
      END
    ELSE
      Mod := Modules.ThisMod(name)
    END;
    IF Modules.res = 0 THEN
      INC(i); j := i;
      WHILE name[j] # 0X DO
        name[j - i] := name[j]; INC(j)
      END;
      name[j - i] := 0X;
      P := Modules.ThisCommand(Mod, name);
      IF Modules.res = 0 THEN
        Par := par;
        P; res := 0;
      ELSE res := Modules.res
      END
    ELSE res := Modules.res
    END
  END Call;

  PROCEDURE PopulateParams;
    VAR W: Texts.Writer; i: INTEGER; str: ARRAY 256 OF CHAR;
  BEGIN
    Texts.OpenWriter(W);
    i := 2; (* skip program name and module.command *)
    WHILE i < Kernel.NoOfArgs DO
      Kernel.GetArg(i, str);
      Texts.WriteString(W, str); Texts.Write(W, " ");
      INC(i)
    END;
    Texts.Append(Par^.text, W.buf);
  END PopulateParams;

  PROCEDURE GetSelection*(VAR text: Texts.Text; VAR beg, end, time: LONGINT);
  BEGIN
    text := NIL; beg := 0; end := 0; time := 0
  END GetSelection;

  (* --- Notifier for echoing to the console all text appended to the log. --- *)
  PROCEDURE LogNotifier(Log: Texts.Text; op: INTEGER; beg, end: LONGINT);
    VAR ch: CHAR;
  BEGIN
    Texts.OpenReader(R, Log, beg);
    WHILE ~R.eot & (beg < end) DO
      Texts.Read(R, ch);
      IF ch = 0DX THEN nOut.Ln ELSE nOut.Char(ch) END;
      INC(beg)
    END
  END LogNotifier;

  (** Request a garbage collection to be done. The GC will take place immediately. *)
  PROCEDURE Collect*;
  BEGIN
    Kernel.GC
  END Collect;

BEGIN
   NEW(Par);
   NEW(Par.text);
   Par.pos := 0;
   OptionChar := '-';
   Texts.Open(Par.text, "");
   PopulateParams;
   NEW(Log);
   Texts.Open(Log, "");
   Log.notify := LogNotifier;
   conftime := -1;
   confdate := -1;
   NEW(conftext)
END nOberon.
