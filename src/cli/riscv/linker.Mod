MODULE linker;  (** RISC-V: linker.Link is the RISC-V boot linker (see rvlinker) *)
  IMPORT rvlinker;

  PROCEDURE Link*;
  BEGIN rvlinker.Link
  END Link;

  PROCEDURE Help*;
  BEGIN rvlinker.Help
  END Help;

END linker.
