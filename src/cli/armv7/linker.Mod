MODULE linker;  (** ARMv7: linker.Link is the ARMv7 boot linker (see rlinker) *)
  IMPORT rlinker;

  PROCEDURE Link*;
  BEGIN rlinker.Link
  END Link;

  PROCEDURE Help*;
  BEGIN rlinker.Help
  END Help;

END linker.
