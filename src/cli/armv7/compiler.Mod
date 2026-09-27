MODULE compiler;  (** ARMv7: compiler.Compile is the native ARMv7 compiler (see a7compiler) *)
  IMPORT a7compiler;

  PROCEDURE Compile*;
  BEGIN a7compiler.Compile
  END Compile;

  PROCEDURE Help*;
  BEGIN a7compiler.Help
  END Help;

END compiler.
