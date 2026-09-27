MODULE rvcompiler;  (** command-line frontend of the RISC-V (RV32) compiler *)
(* after RCompiler (ROP2), RC 6.3.89 / 17.6.93, p.m. 2017-06-12 *)
  IMPORT
    OPM := ROPM, OPT := ROPT, OPP := ROPP, OPV := VOPV,
    Texts := texts, Oberon := Oberon0, Out := out;

  CONST
    riscvtag = 0FDX;
    (* compiler options *)
    inxchk = 0; ovflchk = 1; ranchk = 2; typchk = 3; newsf = 4; ptrinit = 5;
    intprinf = 6; assert = 7; findpc = 8; extsf = 9; softdiv = 10;
    defopt = {inxchk, typchk, ptrinit, assert};

  VAR dir*: ARRAY 64 OF CHAR;  (** object and symbol file directory, default obj/riscv/ *)

  PROCEDURE SignOn;
  BEGIN
    Out.String("RISC-V Compiler  ROP2 RC 10.2.94 / p.m. 2016-11-22 / polpo"); Out.Ln
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

  (** Compile the text read by source with the option characters in options. *)
  PROCEDURE Module*(VAR source: Texts.Reader; options: ARRAY OF CHAR; VAR error: BOOLEAN);
    VAR ch: CHAR; i: INTEGER; ext, new: BOOLEAN;
  BEGIN
    OPM.opt := defopt; OPM.OFtag := riscvtag; COPY(dir, OPM.Dir); i := 0;
    REPEAT
      ch := options[i]; INC(i);
      IF ch = "x" THEN OPM.opt := OPM.opt / {inxchk}
      ELSIF ch = "v" THEN OPM.opt := OPM.opt / {ovflchk}
      ELSIF ch = "r" THEN OPM.opt := OPM.opt / {ranchk}
      ELSIF ch = "t" THEN OPM.opt := OPM.opt / {typchk}
      ELSIF ch = "s" THEN OPM.opt := OPM.opt / {newsf}
      ELSIF ch = "p" THEN OPM.opt := OPM.opt / {ptrinit}
      ELSIF ch = "i" THEN OPM.opt := OPM.opt / {intprinf}
      ELSIF ch = "a" THEN OPM.opt := OPM.opt / {assert}
      ELSIF ch = "e" THEN OPM.opt := OPM.opt / {extsf}
      ELSIF ch = "d" THEN OPM.opt := OPM.opt / {softdiv}
      END
    UNTIL ch = 0X;
    OPM.Init(source, Oberon.Log);
    OPP.Module(OPT.prog, OPM.opt);
    IF OPM.noerr THEN
      OPV.Init; OPT.Export(ext, new);
      IF OPM.noerr THEN
        OPV.Module;
        IF OPM.noerr THEN
          IF new OR ext THEN OPM.RegisterNewSym END;
          IF new THEN OPM.LogWStr(" new symbol file")
          ELSIF ext THEN OPM.LogWStr(" extended symbol file")
          END;
          OPM.LogWNum(4*OPM.pc, 8); OPM.LogWNum(-OPM.sb, 8)
        ELSE OPM.DeleteNewSym
        END
      END
    END;
    OPT.Close;
    OPM.LogWLn; error := ~OPM.noerr
  END Module;

  PROCEDURE CompileFile(name, opt: ARRAY OF CHAR; VAR error: BOOLEAN);
    VAR t: Texts.Text; r: Texts.Reader; pos: LONGINT;
  BEGIN
    NEW(t); Texts.Open(t, name);
    Out.String(name);
    IF t.len # 0 THEN
      Out.String("  compiling  "); Out.String(dir);
      pos := Oberon.Log.len;
      Texts.OpenReader(r, t, 0);
      Module(r, opt, error);
      ShowLog(pos)
    ELSE
      Out.String(" not found"); Out.Ln; error := TRUE
    END;
    Oberon.Collect
  END CompileFile;

  PROCEDURE Help*;
  BEGIN
    Out.String("USAGE:"); Out.Ln;
    Out.String("  rvcompiler.Compile [options] file1.Mod [file2.Mod ...]"); Out.Ln;
    Out.Ln;
    Out.String("Options (prefix with / or \, each toggles its default):"); Out.Ln;
    Out.String("  /x       index checks (on)"); Out.Ln;
    Out.String("  /t       type checks (on)"); Out.Ln;
    Out.String("  /p       pointer initialization (on)"); Out.Ln;
    Out.String("  /a       assertions (on)"); Out.Ln;
    Out.String("  /v       overflow checks (off)"); Out.Ln;
    Out.String("  /r       range checks (off)"); Out.Ln;
    Out.String("  /s       allow new symbol file"); Out.Ln;
    Out.String("  /e       allow extended symbol file"); Out.Ln;
    Out.String("  /d       software division"); Out.Ln;
    Out.String("  /Pdir/   symbol and object file directory (default obj/riscv/)"); Out.Ln;
    Out.Ln;
    Out.String("Options apply to the files that follow them."); Out.Ln
  END Help;

  PROCEDURE Compile*;
    VAR
      S: Texts.Scanner;
      name, opt: ARRAY 64 OF CHAR;
      error: BOOLEAN;
      i, j: INTEGER;
  BEGIN
    error := FALSE; opt[0] := 0X; COPY("obj/riscv/", dir);
    Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos);
    Texts.Scan(S);
    IF S.class # Texts.Name THEN Help; RETURN END;
    WHILE (S.class = Texts.Name) & ~error DO
      COPY(S.s, name);
      IF (name = "/h") OR (name = "-h") OR (name = "--help") OR (name = "/help") THEN
        Help; RETURN
      ELSIF ((name[0] = "/") OR (name[0] = "\")) & (name[1] = "P") THEN
        i := 2; WHILE (name[i] # 0X) & (i-2 < LEN(dir)-1) DO dir[i-2] := name[i]; INC(i) END;
        dir[i-2] := 0X
      ELSIF (name[0] = "/") OR (name[0] = "\") THEN
        j := 0; WHILE opt[j] # 0X DO INC(j) END;
        i := 1;
        WHILE (name[i] # 0X) & (j < LEN(opt)-1) DO opt[j] := name[i]; INC(i); INC(j) END;
        opt[j] := 0X
      ELSE
        CompileFile(name, opt, error)
      END;
      Texts.Scan(S)
    END
  END Compile;

BEGIN
  COPY("obj/riscv/", dir);
  SignOn
END rvcompiler.
