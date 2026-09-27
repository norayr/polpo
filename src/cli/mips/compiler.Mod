MODULE compiler;  (** MIPS: compiler.Compile is the native MIPS compiler (see mcompiler) *)
  IMPORT mcompiler;

  PROCEDURE Compile*;
  BEGIN mcompiler.Compile
  END Compile;

  PROCEDURE Help*;
  BEGIN mcompiler.Help
  END Help;

END compiler.
