MODULE linker;  (** MIPS: linker.Link is the MIPS boot linker (see rlinker) *)
  IMPORT rlinker;

  PROCEDURE Link*;
  BEGIN rlinker.Link
  END Link;

  PROCEDURE Help*;
  BEGIN rlinker.Help
  END Help;

END linker.
