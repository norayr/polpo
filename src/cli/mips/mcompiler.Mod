MODULE mcompiler;  (** command-line MIPS compiler, see rcompiler *)
  IMPORT rcompiler;

  PROCEDURE Compile*;
  BEGIN
    rcompiler.SetTarget("MIPS", "MOPV", "mips", rcompiler.mipstag); rcompiler.CompileTarget
  END Compile;

  PROCEDURE Help*;
  BEGIN rcompiler.Help
  END Help;

END mcompiler.
