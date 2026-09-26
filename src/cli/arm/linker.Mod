MODULE linker;  (** ARM: linker.Link is the ARM boot linker (see alinker) *)
  IMPORT alinker;

  PROCEDURE Link*;
  BEGIN alinker.Link
  END Link;

  PROCEDURE Help*;
  BEGIN alinker.Help
  END Help;

END linker.
