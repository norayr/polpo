�TextDocs.NewDoc     ��� 1   Oberon10.Scn.Fnt  5         �   
  MODULE NCFSVolumes;	(* OJ 1.6.99 *)

IMPORT SYSTEM;

 CONST
	VnLength* = 16;		(** Length of a volume name *)
	BS* = 1024;				(** Block size in bytes *)
	Reserved = 32;			(* Blocks reserved for writing during trap handling *)

	writable *= 0;  removable* = 1;	(** Volume property flags *)

	lock* = 1;  unlock* = 2;  eject* = 3;	(** Handler operation codes *)
	spindown* = 4;  spinup* = 5;

	done* = 0;  readonly* = 1;  failed* = 2;  unable* = 3;	(** Result codes *)


TYPE
	Address* = LONGINT;	(** Volume block address [1..size] *)

	Volume* = POINTER TO VolDesc;
	VolName* = ARRAY VnLength OF CHAR;
	Description* = ARRAY 128 OF CHAR;
	EnumProc* = PROCEDURE (vol: Volume);	(** Called to enumerate mounted volumes *)
	Content* = POINTER TO ContentDesc;	(** Volume content, e.g. a filesystem *)

	Message* = RECORD	(** Base type of messages sent to volumes *)
		crc, x1, x2, x3: LONGINT;	(* placeholders for NetVolumes.HS = 16 *)
		op*: SHORTINT;		(** Operation code *)
		res*: SHORTINT;		(** Result code *)
		vid*: INTEGER;			(** Volume id *)
	END;

	AddressMsg* = RECORD (Message)	(** Base type of messages sent to blocks *)
		adr*: Address;			(** Block address *)
	END;

	Block* = RECORD (AddressMsg)	(** Base type of blocks that can be sent as messages *)
		data*: RECORD END		(** Begin of generic data *)
	END;

	Handler* = PROCEDURE (vol: Volume; VAR msg: Message);	(** Volume message handler *)

	VolDesc* = RECORD	(** Base type of all volumes. *)
		map: POINTER TO ARRAY OF SET;		(* Block allocation table *)
		used: LONGINT;		(* Number of used blocks *)
		prev, next: Volume;
		
		size*: LONGINT;		(** Number of blocks *)
		flags*: SET;				(** Property flags *)
		name*: VolName;		(** Name of mounted volume *)
		desc*: Description;		(** Description of volume *)
		content*: Content;		(** E.g. filesystems or virtual memory managers *)
		
		AllocBlock*: PROCEDURE (vol: Volume; hint: Address; VAR adr: Address);
		FreeBlock*: PROCEDURE (vol: Volume; adr: Address);
		MarkBlock*: PROCEDURE (vol: Volume; adr: Address);
		Marked*: PROCEDURE (vol: Volume; adr: Address): BOOLEAN;
		Available*: PROCEDURE (vol: Volume): LONGINT;
		GetBlock*: PROCEDURE (vol: Volume; adr: LONGINT; VAR blk: Block);
		PutBlock*: PROCEDURE (vol: Volume; adr: LONGINT; VAR blk: Block);
		Handle*: Handler;
	END;

	ContentDesc* = RECORD
		vol*: Volume;
		Finalize*: PROCEDURE (c: Content);
	END;

	IdentProc* = PROCEDURE (vol: Volume; VAR c: Content);	(** Identifies a content of a volume *)
	Identifier = POINTER TO IdentifierDesc;
	IdentifierDesc = RECORD
		next: Identifier;
		Do: IdentProc;		(* Upcall to content provider *)
	END;


VAR
	last: Volume;			(* Double ring of mounted volumes *)
	idents: Identifier;		(* Simple list of content identifiers *)

	Par: ARRAY 256 OF CHAR;	(* Parameters for volume generators *)
	pos: INTEGER;			(* Read position within Par *)
	NewVol*: Volume;	(** Result of volume generators *)
	FmtVol*: Volume;	(** Parameter for filesystem generators *)


(**--- Content support -----------------------------------------------------------------*)

(** Announce identifier of a new content provider *)
PROCEDURE Announce*(identify: IdentProc);
VAR id: Identifier;
BEGIN
	id := idents;
	IF id = NIL THEN  NEW(idents);  idents.next := NIL;  idents.Do := identify
	ELSE
		WHILE (id.Do # identify) & (id.next # NIL) DO  id := id.next  END;
		IF id.Do # identify THEN
			NEW(id.next);  id.next.next := NIL;  id.next.Do := identify;
		END
	END
END Announce;


(** Find and install content of a volume *)
PROCEDURE Inspect*(vol: Volume);
VAR id: Identifier;  c: Content;
BEGIN
	id := idents;  c := NIL;
	WHILE (id # NIL) & (c = NIL) DO  id.Do(vol, c);  id := id.next  END;
	IF c # NIL THEN  c.vol := vol  END;
	vol.content := c
END Inspect;


(*--- Predefined volume methods --------------------------------------------------------*)

PROCEDURE AllocBlock*(vol: Volume; hint: Address; VAR adr: Address);
BEGIN
	IF ~(writable IN vol.flags) THEN HALT(21) END;
	IF vol.size - vol.used <= Reserved THEN  HALT(20)  END;
	IF hint < 0 THEN  HALT(99)  ELSIF hint > vol.size THEN hint := 0  END;
	adr := hint+1;
	LOOP
		IF adr > vol.size THEN adr := 0 END;
		IF (adr MOD 32) IN vol.map[adr DIV 32] THEN INC(adr)  (* Block in use *)
		ELSE
			INCL(vol.map[adr DIV 32], adr MOD 32);
			EXIT
		END;
		IF adr = hint THEN  HALT(20)  END
	END;
	INC(vol.used)
END AllocBlock;


PROCEDURE FreeBlock*(vol: Volume; adr: Address);
BEGIN
	IF (adr < 1) OR (adr > vol.size) THEN SYSTEM.HALT(15) END;
	IF ~(writable IN vol.flags) THEN HALT(21) END;
	EXCL(vol.map[adr DIV 32], adr MOD 32);
	DEC(vol.used)
END FreeBlock;


PROCEDURE MarkBlock*(vol: Volume; adr: Address);
BEGIN
	IF (adr < 1) OR (adr > vol.size) THEN SYSTEM.HALT(15) END;
	IF ~(writable IN vol.flags) THEN HALT(21) END;
	INCL(vol.map[adr DIV 32], adr MOD 32);
	INC(vol.used)
END MarkBlock;


PROCEDURE Marked*(vol: Volume; adr: Address): BOOLEAN;
BEGIN
	IF (adr < 1) OR (adr > vol.size) THEN SYSTEM.HALT(15) END;
	IF ~(writable IN vol.flags) THEN HALT(21) END;
	RETURN (adr MOD 32) IN vol.map[adr DIV 32]
END Marked;


PROCEDURE Available*(vol: Volume): LONGINT;
BEGIN
	RETURN vol.size-vol.used
END Available;


(** Default volume message handler *)
PROCEDURE Handle*(vol: Volume; VAR msg: Message);
BEGIN
	msg.res := unable
END Handle;


(**--- Volume management ----------------------------------------------------------------*)

(** Init private attributes and clear content of a volume *)
PROCEDURE Init*(vol: Volume);
VAR maplen: LONGINT;
BEGIN
	IF vol.content # NIL THEN
		vol.content.Finalize(vol.content);
		vol.content := NIL
	END;
	IF writable IN vol.flags THEN
		maplen := (vol.size+1+31) DIV 32;
		IF (vol.map = NIL) OR (LEN(vol.map^) # maplen) THEN  NEW(vol.map, maplen)  END;
		WHILE maplen > 0 DO  DEC(maplen);  vol.map[maplen] := {}  END;
		vol.used := 0
	ELSE
		vol.used := vol.size
	END
END Init;


(** Find a volume by its name (NIL if not found) *)
PROCEDURE This*(name: ARRAY OF CHAR): Volume;
VAR vol: Volume;
BEGIN
	IF last = NIL THEN  vol := NIL
	ELSE vol := last.next;
		WHILE (vol # last) & (vol.name # name) DO  vol := vol.next  END;
		IF vol.name # name THEN  vol := NIL  END
	END;
	RETURN vol
END This;


(** Install a volume under alias <name> *)
PROCEDURE Mount*(vol: Volume; name: ARRAY OF CHAR; VAR res: INTEGER);
BEGIN
	res := failed;
	IF This(name) = NIL THEN
		COPY(name, vol.name);
		IF last = NIL THEN  (* enter boot volume *)
			vol.next := vol;  vol.prev := vol;
			last := vol
		ELSE
			vol.next := last.next;  vol.prev := last;
			last.next.prev := vol;  last.next := vol
		END;
		Inspect(vol);
		res := done
	END
END Mount;


(** Remove a volume from system *)
PROCEDURE Unmount*(vol: Volume);
BEGIN
	IF vol.content # NIL THEN
		vol.content.Finalize(vol.content)
	END;
	IF vol = last THEN  last := last.prev;
		IF vol = last THEN  last := NIL  END
	END;
	vol.prev.next := vol.next;  vol.next.prev := vol.prev;
END Unmount;

(*
PROCEDURE UnmountAll();
VAR vol: Volume;
BEGIN
	IF last # NIL THEN
		vol := last.next;
		REPEAT
			IF vol.content # NIL THEN
				vol.content.Finalize(vol.content)
			END;
			vol := vol.next
		UNTIL vol = last.next;
		last := NIL
	END
END UnmountAll;
*)

(** Call a procedure for every mounted volume *)
PROCEDURE Enumerate*(Do: EnumProc);
VAR vol: Volume;
BEGIN
	IF last # NIL THEN
		vol := last;
		REPEAT  vol := vol.next;  Do(vol)  UNTIL  (vol = last) OR (last = NIL)
	END
END Enumerate;


(**--- Command parameter support -----------------------------------------------------------------*)

(** Set parameter string for a volume generator *)
PROCEDURE SetPar*(str: ARRAY OF CHAR);
BEGIN
	COPY(str, Par);  pos := 0;
END SetPar;


(** Read next character of parameter string. At the end (ch:=0X) the string is cleared *)
PROCEDURE ReadPar*(VAR ch: CHAR);
BEGIN
	ch := Par[pos];
	IF ch = 0X THEN  pos := 0;  Par[0] := 0X  ELSE  INC(pos)  END
END ReadPar;


BEGIN
	last := NIL;  idents := NIL;  pos := 0;  Par[0] := 0X
END NCFSVolumes.
�BIER�  �   k    4   �� �     d	   # / ; G S _ *    d
 ��    ��C  TextGadgets.NewStyleProc  �