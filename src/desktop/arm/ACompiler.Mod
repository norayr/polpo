(*
  Peter Matthias
  2015-02-12  set default prefix to arm/
  2015-12-28  adapted to OBC.SaveRegisters/OBC.RestoreRegisters with FP register set
  polpo: UI frontend over the shared OBP parser (console frontend: acompiler).
*)

MODULE ACompiler;   (*NW 7.6.87 / 21.8.92 / 14.12.93*)  (** UI frontend of the ARM compiler *)

  IMPORT Texts, Oberon, OBS, OBC, OBE, OBH, OBP, OC := OBM;

  VAR W: Texts.Writer;

  PROCEDURE ShowStats;
  VAR txt : Texts.Text;
  BEGIN
    IF OBP.statsEmpty THEN RETURN END;
    NEW(txt); Texts.Open(txt,"");
    Texts.Append(txt, OBP.statW.buf);
    Oberon.OpenText("Statistics", txt, 600, 300);
  END ShowStats;

  PROCEDURE Compile*;
    VAR beg, end, time: LONGINT;
      T: Texts.Text;
      S: Texts.Scanner;
      global, local: ARRAY 32 OF CHAR;
    
    PROCEDURE ReadOptions(VAR opt: ARRAY OF CHAR);
    VAR i, j: LONGINT;
    BEGIN
      i := 0;
      WHILE (S.class=Texts.Char) & (S.c = "\") DO
        Texts.Scan(S);
        IF S.class=Texts.Name THEN 
          j := 0;
          WHILE S.s[j] # 0X DO  opt[i] := S.s[j]; INC(i); INC(j)  END;
          opt[i] := " ";  INC(i); Texts.Scan(S)
        END
      END;
      opt[i] := 0X;
    END ReadOptions;
    
    PROCEDURE ParseOptions(opt: ARRAY OF CHAR);
    VAR i, k: LONGINT;  fs: Texts.Scanner;  t: Texts.Text;  beg, end, time: LONGINT;
    BEGIN
      i := 0;
      WHILE opt[i] # 0X DO
        IF opt[i] = "x" THEN OBE.inxchk := ~OBE.inxchk
        ELSIF opt[i] = "t" THEN OBC.typchk:= ~OBC.typchk
        ELSIF opt[i] = "z" THEN OBH.clrchk := ~OBH.clrchk 
        ELSIF opt[i] = "v" THEN OBE.ovfchk := ~OBE.ovfchk
        ELSIF opt[i] = "s" THEN OBP.newSF := ~OBP.newSF
        ELSIF opt[i] = "a" THEN OBP.statistics := ~OBP.statistics
        ELSIF opt[i] = "f"  THEN
          Oberon.GetSelection(t, beg, end, time);
          IF time # -1 THEN
            Texts.OpenScanner(fs, t, beg); Texts.Scan(fs);
            end := S.line;
            WHILE (fs.class # Texts.Int) & (fs.line = end) & ~fs.eot DO  Texts.Scan(fs)  END;
            IF (fs.class = Texts.Int) THEN  OBC.trapPos := fs.i DIV 4
            ELSE
              Texts.WriteString(W, "no pc found"); Texts.WriteLn(W);
              Texts.Append(Oberon.Log, W.buf);
              OBC.trapPos := MAX(LONGINT)
            END
          END;
          OBP.noFiles := TRUE
        ELSIF opt[i] = "P" THEN
          INC(i);  k := 0;
          WHILE (opt[i] # 0X) & (opt[i] # " ") DO
            OC.prefix[k] := opt[i];  INC(k);  INC(i)
          END;
          OC.prefix[k] := 0X;  INC(k);  DEC(i)
        END;
        INC(i)
      END
    END ParseOptions;
    
    PROCEDURE ApplyOptions;
    BEGIN
      OBP.SetDefaults;
      ParseOptions(global);  ParseOptions(local);
    END ApplyOptions;

  BEGIN    
    Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
    ReadOptions(global);
    
    IF S.class = Texts.Char THEN
      IF S.c = "*" THEN
        T := Oberon.MarkedText();
        Texts.Scan(S);  ReadOptions(local);  ApplyOptions;
        IF T # NIL THEN OBP.CompilationUnit(Oberon.MarkedText(), 0) END
      ELSIF S.c = "^" THEN
        Oberon.GetSelection(T, beg, end, time);
        IF time >= 0 THEN
          Texts.OpenScanner(S, T, beg); Texts.Scan(S);
          IF S.class = Texts.Name THEN
            Texts.WriteString(W, S.s); NEW(T); Texts.Open(T, S.s);
            Texts.Scan(S);  ReadOptions(local);  ApplyOptions;
            IF T.len # 0 THEN OBP.CompilationUnit(T, 0)
            ELSE Texts.WriteString(W, " not found");
              Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
            END
          END
        END
      ELSIF S.c = "@" THEN
        Texts.Scan(S);  ReadOptions(local);  ApplyOptions;
        Oberon.GetSelection(T, beg, end, time);
        IF time >= 0 THEN OBP.CompilationUnit(T, beg) END
      END
    ELSE 
      NEW(T); OBS.scanerr := FALSE;
      WHILE (S.class = Texts.Name) & ~OBS.scanerr DO
        Texts.WriteString(W, S.s); Texts.Open(T, S.s);
        Texts.Scan(S);  ReadOptions(local);  ApplyOptions;
        IF T.len # 0 THEN OBP.CompilationUnit(T, 0)
        ELSE Texts.WriteString(W, " not found");
          Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf);
          OBS.scanerr := TRUE
        END ;
        Oberon.Collect
      END
    END ;
    OC.prefix := "";
    ShowStats;
    Oberon.Collect
  END Compile;

BEGIN
  Texts.OpenWriter(W);
  Texts.WriteString(W, "Compiler  NW 14.12.93 / as 2.12.98 / prk 09.12.99 / polpo"); Texts.WriteLn(W);
  Texts.Append(Oberon.Log, W.buf)
END ACompiler.
