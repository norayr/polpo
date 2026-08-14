MODULE system;

IMPORT Kernel, Mods := Modules, Oberon0, Texts := texts, Out := out;

PROCEDURE Modules*;
VAR m: Kernel.Module;
BEGIN
  m := Kernel.modules;
  WHILE m # NIL DO
    Out.String(m.name); Out.String("  "); Out.Int(m.refcnt, 1); Out.Ln;
    m := m.next
  END
END Modules;

PROCEDURE Free*;
VAR S: Texts.Scanner; name: ARRAY 64 OF CHAR; all: BOOLEAN;
BEGIN
  Texts.OpenScanner(S, Oberon0.Par.text, Oberon0.Par.pos); Texts.Scan(S);
  IF S.class # Texts.Name THEN
    Out.String("usage: system.Free Module [*] ..."); Out.Ln; RETURN
  END;
  WHILE S.class = Texts.Name DO
    COPY(S.s, name); Texts.Scan(S); all := FALSE;
    IF (S.class = Texts.Char) & (S.c = "*") THEN all := TRUE; Texts.Scan(S) END;
    IF (name = "shell") OR (name = "system") THEN
      Out.String(name); Out.String(" is part of the active console"); Out.Ln
    ELSE
      Mods.Free(name, all);
      IF Mods.res = 0 THEN
        Out.String(name); Out.String(" unloaded")
      ELSE
        Out.String(Mods.resMsg)
      END;
      Out.Ln
    END
  END
END Free;

BEGIN
END system.
