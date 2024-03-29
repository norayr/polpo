�TextDocs.NewDoc     ���   Oberon10.Scn.Fnt  �       L        @       �        ?        �        ?        �        ?        �        ?        O       C        �   P    S       2    X  (* OBERON System 3, Release 2.3.

Copyright 1998 Institute of Computer Systems of ETH Z�rich, ETH Center, CH-8092 Z�rich, 
e-mail: oberon@inf.ethz.ch.

This module may be used under the conditions of the general Oberon 
System 3 license contract.  The full text can be downloaded from

	"ftp://ftp.inf.ethz.ch/pub/software/Oberon/System3/license.txt;A"

Under the license terms stated it is in particular (a) prohibited to modify
the interface of this module in any way that disagrees with the style
or content of the system and (b) requested to provide all conversions
of the source code to another platform with the name OBERON. *)

MODULE Disk;	(** non-portable *)	(* as *)

(* RAMDisk "driver" for SharkOberon *)

IMPORT SYSTEM, Kernel;

CONST
	SectorSize* = 2048;
	DefaultSectors = 4096; (* Default RAM-Disk Size (8 MByte) *)
	
TYPE
	Sector* = RECORD END; (** 2k Byte Oberon Sector *)
	FullSector = RECORD (Sector) data : ARRAY SectorSize OF CHAR END; (* So we can allocate Sectors dynamically *)
	SectorPtr = POINTER TO Sector;
	FullSectorPtr = POINTER TO FullSector;

CONST
	Reserved = 0;	(* sectors reserved for writing during trap handling *)

VAR		
	disk : POINTER TO ARRAY OF SectorPtr;
	numused: LONGINT;	(* number of used Sectors *)
	nummax: LONGINT;	(* total number of Sectors *)
	init, trapped: BOOLEAN;
	
(* InitTable - Initialise sector reservation table *)
PROCEDURE InitTable;
VAR i : LONGINT;
BEGIN
	NEW(disk,nummax);
	FOR i:=0 TO nummax-1 DO disk[i]:=NIL END
END InitTable;

PROCEDURE NewSector(VAR s : SectorPtr);
VAR s2 : FullSectorPtr;
BEGIN
	NEW(s2); Kernel.Fill4(SYSTEM.VAL(LONGINT,s2),SectorSize DIV 4, 0);
	s:=s2
END NewSector;

(* ---- Ceres-like interface ---- *)

(** AllocSector - Allocate a new Sector.  "hint" can be previously allocated
	Sector to preserve adjacency, or 0 if previous Sector not known *)

PROCEDURE AllocSector*(hint: LONGINT; VAR sec: LONGINT);
VAR i: LONGINT;
BEGIN
	i := hint+29;
	IF ~init OR (i < 29) OR (i MOD 29 # 0) THEN SYSTEM.HALT(15) END;
	IF ~trapped & (nummax - numused <= Reserved) THEN
		trapped := TRUE; SYSTEM.HALT(16)	(* Disk almost full *)
	END;
	i := i DIV 29;  hint := i-1;
	IF hint > nummax THEN hint := 0 END;
	LOOP
		IF i > nummax THEN i := 0 END;
		IF disk[i-1]#NIL THEN INC(i)	(* in use *)
		ELSE
			sec := i;  NewSector(disk[i-1]); INC(numused);
			sec := sec*29;	(* "Encode" sector number. *)
			EXIT
		END;
		IF i = hint THEN SYSTEM.HALT(16) (* Disk full *) END
	END
END AllocSector;

(** MarkSector - Mark an unused Sector as used.  Do not mark already marked sectors. *)

PROCEDURE MarkSector*(sec: LONGINT);
BEGIN
	IF ~init OR (sec MOD 29 # 0) THEN SYSTEM.HALT(15) END;
	sec := sec DIV 29;
	IF (sec < 1) OR (sec > nummax) THEN SYSTEM.HALT(15) END;
	NewSector(disk[sec-1]);  
	INC(numused)
END MarkSector;

(** FreeSector - Mark a used Sector as unused.  Do not unmark already unmarked sectors. *)

PROCEDURE FreeSector*(sec: LONGINT);
BEGIN
	IF ~init OR (sec MOD 29 # 0) THEN SYSTEM.HALT(15) END;
	sec := sec DIV 29;
	IF (sec < 1) OR (sec > nummax) THEN SYSTEM.HALT(15) END;
	disk[sec-1]:=NIL;
	DEC(numused)
END FreeSector;

(** Marked - Test if a sector is marked as used. *)

PROCEDURE Marked*(sec: LONGINT): BOOLEAN;
BEGIN
	IF ~init OR (sec MOD 29 # 0) THEN SYSTEM.HALT(15) END;
	sec := sec DIV 29;
	IF (sec < 1) OR (sec > nummax) THEN SYSTEM.HALT(15) END;
	RETURN disk[sec-1]#NIL
END Marked;

(** GetSector - Read a 2k Sector from disk *)

PROCEDURE GetSector*(src: LONGINT; VAR dest: Sector);
BEGIN
	IF ~init OR (src MOD 29 # 0) THEN SYSTEM.HALT(15) END;
	src := src DIV 29;
	IF (src < 1) OR (src > nummax) THEN SYSTEM.HALT(15) END;
	IF disk[src-1]=NIL THEN (* allow FileDir to access directory pages *)
		MarkSector(src * 29);
	END;	
	SYSTEM.MOVE(SYSTEM.ADR(disk[src-1]^),SYSTEM.ADR(dest), SectorSize);
END GetSector;

(** PutSector - Write a 2k Sector to disk *)

PROCEDURE PutSector*(dest: LONGINT; VAR src: Sector);
BEGIN
	IF ~init OR (dest MOD 29 # 0) THEN SYSTEM.HALT(15) END;
	dest := dest DIV 29;
	IF (dest < 1) OR (dest > nummax) THEN SYSTEM.HALT(15) END;
	SYSTEM.MOVE(SYSTEM.ADR(src), SYSTEM.ADR(disk[dest-1]^),SectorSize);
END PutSector;

(** ResetDisk - Reset the disk driver, re-reading all structures.  Use must be coordinated with filesystem. *)
PROCEDURE ResetDisk*;
VAR s: ARRAY 20 OF CHAR;  i: LONGINT;  rdin: BOOLEAN;
BEGIN
	IF ~init THEN
		Kernel.GetConfig("DiskSize",s); nummax:=Kernel.StrToInt(s)*1024*1024 DIV SectorSize;
		IF nummax=0 THEN nummax:=DefaultSectors END;
		Kernel.WriteString("Disk: nummax="); Kernel.WriteInt(nummax,1); Kernel.WriteLn;
		numused := 0;  
		InitTable;
		init := TRUE;
	END
END ResetDisk;

(** Available - Return number of 2k Sectors available (unmarked) on disk *)
PROCEDURE Available*(): LONGINT;
BEGIN
	RETURN nummax - numused
END Available;

(** Size - Return total number of 2k Sectors on disk *)
PROCEDURE Size*(): LONGINT;
BEGIN
	RETURN nummax
END Size;

BEGIN
	init := FALSE;  trapped := FALSE
END Disk.
