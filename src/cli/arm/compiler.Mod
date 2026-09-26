MODULE compiler;  (** ARM: compiler.Compile is the native ARM compiler (see acompiler) *)
  IMPORT acompiler;

  PROCEDURE Compile*;
  BEGIN acompiler.Compile
  END Compile;

  PROCEDURE Help*;
  BEGIN acompiler.Help
  END Help;

END compiler.
