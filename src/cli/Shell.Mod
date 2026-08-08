MODULE Shell;
IMPORT nIn, nOut, Kernel, nModules, nOberon, nTexts,
   ooc2Strings;

PROCEDURE extractModandProc(VAR cmd, mod, proc: ARRAY OF CHAR);
VAR
  pos: INTEGER;
  found: BOOLEAN;
  dot: ARRAY 2 OF CHAR;
BEGIN
  COPY(".", dot);
  ooc2Strings.FindNext(dot, cmd, 0, found, pos);
  IF found THEN
    ooc2Strings.Extract(cmd, 0, pos, mod);
    ooc2Strings.Extract(cmd, pos+1, ooc2Strings.Length(cmd)-pos-1, proc);
  ELSE
    nOut.String("Error: Command must be in format Module.Procedure");
    nOut.Ln;
    Kernel.Shutdown(1);
  END;
END extractModandProc;

PROCEDURE BuildParamText(VAR text: nTexts.Text);
VAR
  W: nTexts.Writer;
  i: LONGINT;
  arg: ARRAY 256 OF CHAR;
BEGIN
  nTexts.OpenWriter(W);

  (* Start from arg 2 - skip program name and command *)
  i := 2;
  WHILE i < Kernel.NoOfArgs DO
    Kernel.GetArg(i, arg);
    nTexts.WriteString(W, arg);
    IF i < Kernel.NoOfArgs - 1 THEN
      nTexts.Write(W, " ")  (* Add space between arguments *)
    END;
    INC(i)
  END;

  nTexts.Append(text, W.buf);
END BuildParamText;

PROCEDURE Interactive*;
VAR
  line: ARRAY 256 OF CHAR;
  cmd, name: ARRAY 64 OF CHAR;
  params: ARRAY 256 OF CHAR;
  par: nOberon.ParList;
  W: nTexts.Writer;
  i, j: INTEGER;
  res: INTEGER;
  quit: BOOLEAN;
BEGIN
  nIn.Open;
  quit := FALSE;
  WHILE ~quit DO
    nOut.String("> ");
    nIn.Line(line);
    IF ~nIn.Done THEN quit := TRUE
    ELSIF line[0] = 0X THEN (* skip empty line *)
    ELSIF line[0] = '#' THEN (* skip comment line *)
    ELSIF ooc2Strings.Equal(line, "quit") OR ooc2Strings.Equal(line, "exit") THEN
      quit := TRUE
    ELSE
      (* split at first space: before = command, after = params *)
      i := 0;
      WHILE (line[i] # 0X) & (line[i] # ' ') DO INC(i) END;
      j := 0; WHILE j < i DO cmd[j] := line[j]; INC(j) END; cmd[j] := 0X;
      WHILE line[i] = ' ' DO INC(i) END;
      j := 0; WHILE line[i] # 0X DO params[j] := line[i]; INC(j); INC(i) END; params[j] := 0X;

      NEW(par); NEW(par.text); nTexts.Open(par.text, ""); par.pos := 0;
      IF params[0] # 0X THEN
        nTexts.OpenWriter(W);
        nTexts.WriteString(W, params);
        nTexts.Append(par.text, W.buf)
      END;

      COPY(cmd, name);  (* nOberon.Call modifies name in place *)
      nOberon.Call(name, par, FALSE, res);
      IF res # 0 THEN
        nOut.String("error "); nOut.Int(res, 0); nOut.Ln
      END
    END
  END
END Interactive;

PROCEDURE Run*;
VAR
  cmd: ARRAY 64 OF CHAR;
  mod, proc: ARRAY 32 OF CHAR;
  Command: Kernel.Proc;
  par: nOberon.ParList;
BEGIN
  IF Kernel.NoOfArgs < 2 THEN
    Interactive;
    Kernel.Shutdown(0)
  END;

  (* Get the command from arg 1 *)
  Kernel.GetArg(1, cmd);

  (* Extract module and procedure names *)
  extractModandProc(cmd, mod, proc);

  (* Build parameter list for the command *)
  NEW(par);
  NEW(par.text);
  nTexts.Open(par.text, "");
  par.pos := 0;

  (* Populate parameter text with remaining arguments *)
  BuildParamText(par.text);

  (* Set up the global parameter *)
  nOberon.Par := par;

  (* Execute the command *)
  Command := nModules.ThisCommand(nModules.ThisMod(mod), proc);
  IF Command # NIL THEN
    Command
  ELSE
    nOut.String("Error: Command not found");
    nOut.Ln;
    Kernel.Shutdown(1);
  END;

  Kernel.Shutdown(0);
END Run;

END Shell.
