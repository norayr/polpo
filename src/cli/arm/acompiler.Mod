MODULE acompiler;  (** command-line frontend of the ARM compiler *)
  IMPORT
    OBS, OBP, OC := OBM, Texts := texts, Oberon := Oberon0, Out := out;

  PROCEDURE SignOn;
  BEGIN
    Out.String("ARM Compiler  NW 14.12.93 / as 2.12.98 / prk 09.12.99 / pm / polpo"); Out.Ln
  END SignOn;

  (* Print what the compiler appended to Oberon.Log since position pos. *)
  PROCEDURE ShowLog(pos: LONGINT);
    VAR R: Texts.Reader; ch: CHAR;
  BEGIN
    IF Oberon.Log.len > pos THEN
      Texts.OpenReader(R, Oberon.Log, pos);
      Texts.Read(R, ch);
      WHILE ~R.eot DO
        IF ch = 0DX THEN Out.Ln ELSE Out.Char(ch) END;
        Texts.Read(R, ch)
      END
    END
  END ShowLog;

  PROCEDURE CompileFile(name, opt: ARRAY OF CHAR; VAR error: BOOLEAN);
    VAR t: Texts.Text; pos: LONGINT;
  BEGIN
    NEW(t); Texts.Open(t, name);
    Out.String(name);
    IF t.len # 0 THEN
      OBP.SetDefaults; OBP.ParseOptions(opt);
      pos := Oberon.Log.len;
      OBP.CompilationUnit(t, 0);
      ShowLog(pos);
      error := OBS.scanerr
    ELSE
      Out.String(" not found"); Out.Ln;
      error := TRUE
    END;
    Oberon.Collect
  END CompileFile;

  PROCEDURE Help*;
  BEGIN
    Out.String("USAGE:"); Out.Ln;
    Out.String("  acompiler.Compile [options] file1.Mod [file2.Mod ...]"); Out.Ln;
    Out.Ln;
    Out.String("Options (prefix with / or \, each toggles its default):"); Out.Ln;
    Out.String("  /x       index checks (on)"); Out.Ln;
    Out.String("  /t       type checks (on)"); Out.Ln;
    Out.String("  /z       clear local pointers (on)"); Out.Ln;
    Out.String("  /v       overflow checks (off)"); Out.Ln;
    Out.String("  /s       allow new symbol file"); Out.Ln;
    Out.String("  /n       do not write output files"); Out.Ln;
    Out.String("  /a       constant block statistics"); Out.Ln;
    Out.String("  /Pdir/   symbol and object file prefix (default obj/arm/)"); Out.Ln;
    Out.Ln;
    Out.String("Options apply to the files that follow them."); Out.Ln
  END Help;

  PROCEDURE Compile*;
    VAR
      S: Texts.Scanner;
      name: ARRAY 64 OF CHAR;
      opt: ARRAY 64 OF CHAR;
      error: BOOLEAN;
      i, j: INTEGER;
  BEGIN
    error := FALSE; opt[0] := 0X;
    Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos);
    Texts.Scan(S);
    IF S.class # Texts.Name THEN Help; RETURN END;
    WHILE (S.class = Texts.Name) & ~error DO
      COPY(S.s, name);
      IF (name = "/h") OR (name = "-h") OR (name = "--help") OR (name = "/help") THEN
        Help; RETURN
      ELSIF (name[0] = "/") OR (name[0] = "\") THEN
        j := 0; WHILE opt[j] # 0X DO INC(j) END;
        i := 1;
        WHILE (name[i] # 0X) & (j < LEN(opt)-2) DO opt[j] := name[i]; INC(i); INC(j) END;
        opt[j] := " "; opt[j+1] := 0X
      ELSE
        CompileFile(name, opt, error)
      END;
      Texts.Scan(S)
    END;
    OC.prefix := ""
  END Compile;

BEGIN
  SignOn
END acompiler.
