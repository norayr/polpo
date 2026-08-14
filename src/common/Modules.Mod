MODULE Modules;

IMPORT Modules0;

TYPE
  Command* = Modules0.Command;
  Module* = Modules0.Module;
  ModuleDesc* = Modules0.ModuleDesc;
  ModuleName* = Modules0.ModuleName;

VAR
  res*: INTEGER;
  resMsg*: ARRAY 256 OF CHAR;

PROCEDURE Sync;
BEGIN
  res := Modules0.res;
  COPY(Modules0.resMsg, resMsg)
END Sync;

PROCEDURE FindMod*(name: ARRAY OF CHAR): Module;
VAR M: Module;
BEGIN
  M := Modules0.FindMod(name); Sync;
  RETURN M
END FindMod;

PROCEDURE ThisMod*(name: ARRAY OF CHAR): Module;
VAR M: Module;
BEGIN
  M := Modules0.ThisMod(name); Sync;
  RETURN M
END ThisMod;

PROCEDURE ThisCommand*(M: Module; name: ARRAY OF CHAR): Command;
VAR P: Command;
BEGIN
  P := Modules0.ThisCommand(M, name); Sync;
  RETURN P
END ThisCommand;

PROCEDURE Free*(name: ARRAY OF CHAR; all: BOOLEAN);
BEGIN
  Modules0.Free(name, all); Sync
END Free;

PROCEDURE InstallTermHandler*(h: Modules0.Command);
BEGIN
  Modules0.InstallTermHandler(h)
END InstallTermHandler;

BEGIN
  Sync
END Modules.
