MODULE linker;  (** RISC-V: linker.Link is the RISC-V boot linker (see rlinker) *)
  IMPORT rlinker;

  PROCEDURE Link*;
  BEGIN rlinker.Link
  END Link;

  PROCEDURE Help*;
  BEGIN rlinker.Help
  END Help;

END linker.
