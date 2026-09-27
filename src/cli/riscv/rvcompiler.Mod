MODULE rvcompiler;  (** command-line RISC-V compiler, see rcompiler *)
  IMPORT rcompiler;

  PROCEDURE Compile*;
  BEGIN
    rcompiler.SetTarget("RISC-V", "VOPV", "obj/riscv/", rcompiler.riscvtag); rcompiler.CompileTarget
  END Compile;

  PROCEDURE Help*;
  BEGIN rcompiler.Help
  END Help;

END rvcompiler.
