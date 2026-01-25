MODULE Shell;
IMPORT nOut, Kernel, nModules, nOberon, nTexts,
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

PROCEDURE Run*;
VAR
  cmd: ARRAY 64 OF CHAR;
  mod, proc: ARRAY 32 OF CHAR;
  Command: Kernel.Proc;
  par: nOberon.ParList;
BEGIN
  IF Kernel.NoOfArgs < 2 THEN
    nOut.String("Usage: shell Module.Procedure [arguments...]");
    nOut.Ln;
    nOut.String("Example: shell nXCompiler.Compile Test.Mod \\s");
    nOut.Ln;
    Kernel.Shutdown(1);
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
