MODULE loksh;

IMPORT Kernel, Modules0;

VAR
  arg, path: ARRAY 128 OF CHAR;
  i: INTEGER;
  loop: Modules0.Command;

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
  loop := Modules0.ThisCommand(Modules0.ThisMod("shell"), "Run");
  IF loop # NIL THEN loop END
END loksh.
