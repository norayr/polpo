MODULE a7compiler;  (** command-line ARMv7 compiler, see rcompiler *)
  IMPORT rcompiler;

  PROCEDURE Compile*;
  BEGIN
    rcompiler.SetTarget("ARMv7", "AOPV", "armv7", rcompiler.armv7tag); rcompiler.CompileTarget
  END Compile;

  PROCEDURE Help*;
  BEGIN rcompiler.Help
  END Help;

END a7compiler.
