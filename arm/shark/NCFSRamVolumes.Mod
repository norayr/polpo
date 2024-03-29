�TextDocs.NewDoc     ��� ?   Oberon10.Scn.Fnt  x         �           �  MODULE NCFSRamVolumes;	(* OJ 3.6.99 *)
(** Driver for non-persistent volumes in memory *)

IMPORT SYSTEM, NCFSVolumes;

 TYPE
	Volume* = POINTER TO VolDesc;
	VolDesc* = RECORD (NCFSVolumes.VolDesc)
		blocks: POINTER TO ARRAY OF ARRAY NCFSVolumes.BS OF CHAR;
	END;


(** Get block from adr [1..size] of volume vol *)
PROCEDURE GetBlock*(vol: NCFSVolumes.Volume; adr: LONGINT; VAR blk: NCFSVolumes.Block);
VAR memAdr: LONGINT;
BEGIN
	WITH vol: Volume DO
		IF (adr < 1) OR (adr > vol.size) THEN SYSTEM.HALT(15) END;
		memAdr := SYSTEM.ADR(vol.blocks[adr-1]);
		SYSTEM.MOVE(memAdr, SYSTEM.ADR(blk.data), NCFSVolumes.BS)
	END
END GetBlock;


(** Put block to adr [1..size] of volume vol *)
PROCEDURE PutBlock*(vol: NCFSVolumes.Volume; adr: LONGINT; VAR blk: NCFSVolumes.Block);
VAR memAdr: LONGINT;
BEGIN
	WITH vol: Volume DO
		IF (adr < 1) OR (adr > vol.size) THEN SYSTEM.HALT(15) END;
		memAdr := SYSTEM.ADR(vol.blocks[adr-1]);
		SYSTEM.MOVE(SYSTEM.ADR(blk.data), memAdr, NCFSVolumes.BS)
	END
END PutBlock;


(* Fetch positive integer parameter passed in NCFSVolumes.Par *)
PROCEDURE FetchInt(VAR x: LONGINT);
VAR ch: CHAR;
BEGIN
	x := 0;
	NCFSVolumes.ReadPar(ch);
	WHILE (ch >= "0") & (ch <= "9") DO
		ASSERT(x < MAX(LONGINT) DIV 10);
		x := x*10 + (ORD(ch) - ORD("0"));
		NCFSVolumes.ReadPar(ch);
	END
END FetchInt;


(** Generate a new ram volume. Expecting in NCFSVolumes.Par: KByteSize = { "0" | ... | "9" } *)
PROCEDURE New*;
VAR vol: Volume;  kbytes: LONGINT;
BEGIN
	NCFSVolumes.NewVol := NIL;
	FetchInt(kbytes);
	IF kbytes > 0 THEN
		NEW(vol);
		vol.size := (kbytes*1024+NCFSVolumes.BS-1) DIV NCFSVolumes.BS;
		vol.flags := {NCFSVolumes.writable};
		vol.desc := "RAM volume";
		vol.content := NIL;
		vol.AllocBlock := NCFSVolumes.AllocBlock;  vol.FreeBlock := NCFSVolumes.FreeBlock;
		vol.MarkBlock := NCFSVolumes.MarkBlock;  vol.Marked := NCFSVolumes.Marked;
		vol.Available := NCFSVolumes.Available;
		vol.GetBlock := GetBlock;  vol.PutBlock := PutBlock;
		vol.Handle := NCFSVolumes.Handle;
		NEW(vol.blocks, vol.size);  ASSERT(vol.blocks # NIL);
		NCFSVolumes.Init(vol);
		NCFSVolumes.NewVol := vol;
		NCFSVolumes.SetPar("")
	ELSE
		HALT(99)
	END
END New;


END NCFSRamVolumes.
�BIER0	  K	   �    4   �� �     d	   # / ; G S _ (    d
 ��    ��C  TextGadgets.NewStyleProc  �