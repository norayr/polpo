MODULE loksh;

IMPORT Kernel, Modules0, Linux0, Root, SYSTEM;

VAR
  arg, path: ARRAY 128 OF CHAR;
  i: INTEGER;
  mod: Modules0.Module;
  loop: Modules0.Command;

(* write s to standard error *)
PROCEDURE Err(s: ARRAY OF CHAR);
  VAR n, r: LONGINT;
BEGIN
  n := 0; WHILE (n < LEN(s)) & (s[n] # 0X) DO INC(n) END;
  r := Linux0.Write0(2, SYSTEM.ADR(s[0]), n)
END Err;

BEGIN
  IF Kernel.NoOfArgs > 1 THEN
    Kernel.GetArg(1, arg);
    IF (arg[0] = "-") & (arg[1] = "P") THEN
      i := 0;
      WHILE arg[i+2] # 0X DO path[i] := arg[i+2]; INC(i) END;
      path[i] := 0X;
      Modules0.SetPath(path)
    END
  END;
  mod := Modules0.ThisMod("shell");
  IF mod # NIL THEN
    loop := Modules0.ThisCommand(mod, "Run");
    IF loop # NIL THEN loop; Kernel.Shutdown(1) END
  END;
  arg[0] := 0AX; arg[1] := 0X;
  Err("loksh: cannot start the shell: "); Err(Modules0.resMsg); Err(arg);
  Err("loksh: polpo root ");
  IF Root.path # "" THEN Err(Root.path) ELSE Err("unknown") END;
  Err(", set POLPO to the polpo directory"); Err(arg);
  Kernel.Shutdown(2)  (* 1 means normal termination, exit code 0 *)
END loksh.
