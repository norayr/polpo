MODULE compiler;  (** RISC-V: compiler.Compile is the native RISC-V compiler (see rvcompiler) *)
  IMPORT rvcompiler;

  PROCEDURE Compile*;
  BEGIN rvcompiler.Compile
  END Compile;

  PROCEDURE Help*;
  BEGIN rvcompiler.Help
  END Help;

END compiler.
