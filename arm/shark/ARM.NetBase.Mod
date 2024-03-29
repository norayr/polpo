�TextDocs.NewDoc     �l�w   Oberon10.Scn.Fnt             N        `        M    +    X    �   f    �   �"  (* OBERON System 3, Release 2.3.

Copyright 1999 ETH Z�rich Institute for Computer Systems, 
ETH Center, CH-8092 Z�rich. e-mail: oberon@inf.ethz.ch.

This module may be used under the conditions of the general Oberon 
System 3 license contract. The full text can be downloaded from

	"ftp://ftp.inf.ethz.ch/pub/software/Oberon/System3/license.txt;A"

Under the license terms stated it is in particular (a) prohibited to modify
the interface of this module in any way that disagrees with the style
or content of the system and (b) requested to provide all conversions
of the source code to another platform with the name OBERON. *)

MODULE NetBase;	(** non-portable *)	(* 12.09.96 mg / January 9, 1999 as *)

IMPORT SYSTEM, Kernel;
	
CONST
	closed* = 0; open* = 1; pending* = 2;

	MaxDevices* = 2; MaxProtocols = 4; MaxTimers = 2;

	MacAdrLen* = 6;	(* must be 6 for NetIP.ArpDesc *)
	
	MaxDataLen* = 1514;

	(* broadcast capability *)
	nobroadcast* = 0; broadcast* = 1;
	
	Trace = FALSE;
	
	DebugQueues = FALSE;	(* warning: can influence performance *)
	
TYPE
	MacAdr* = ARRAY MacAdrLen OF SYSTEM.BYTE;

	Item* = POINTER TO ItemDesc;	(** basic network data item *)

	ItemDesc* = RECORD
		data*: ARRAY MaxDataLen OF SYSTEM.BYTE;
		padding: CHAR;	(* temporary until UDP/TCP chksum fixed *)
		ofs*, len*: INTEGER;	(** item.data[ofs..ofs+len-1] is current item data *)
		next: Item
	END ;
	(* The data management in Item changed! Current item data is item.data[item.ofs..item.ofs+item.len-1], but ofs is 
		always 0. If headers have to be inserted, one has to call MakeRoom(size). Of course, this results in lots of copy
		operations, and it's just a better-than-nothing-solution. The reason for this overhead is that StrongARM can't 
		read Words or Halfwords from non-aligned addresses. If I find the time, I'll implement a more efficient solution to this problem.  
	*)
	
	
	Queue* = RECORD	(** Queue of items *)
		len*: INTEGER;
		first, last: Item
	END;

	Device* = POINTER TO DeviceDesc;
	DeviceDesc* = RECORD
		typ*, state*, num*: INTEGER;	(* broadcast/nobroadcast, close/open, index *)
		sndCnt*, recCnt*: LONGINT;	(* send/receive counters *)
		hostAdr*, castAdr*: MacAdr;
		Receive*: PROCEDURE (dev: Device; VAR prno: INTEGER; VAR src: ARRAY OF SYSTEM.BYTE; VAR item: Item);
		Send*: PROCEDURE (dev: Device; prno: INTEGER; VAR dest: ARRAY OF SYSTEM.BYTE; item: Item);
		Available*: PROCEDURE (dev: Device): BOOLEAN
	END;

	ProtocolProc* = PROCEDURE(item: Item);
	
	TaskProc* = PROCEDURE(time: LONGINT);

	Entry = RECORD
		prno: INTEGER;
		proc: ProtocolProc
	END;

VAR
	anyadr*: MacAdr;

	device: ARRAY MaxDevices OF Device;
	protocols: ARRAY MaxProtocols OF Entry;
	tasks: ARRAY MaxTimers OF TaskProc;
	nofProtocols, nofDevices, nofTasks: SHORTINT;

	freeList: Queue;

PROCEDURE Move(src, dest, len : LONGINT);
(* SYSTEM.MOVE doesnt work if ranges are overlapping and dest>src! *)
CODE
	LDMFD	SP!,{R0,R1,R2}	(* R0 = len	R1 = dest	R2 = src *)
	CMP	R0,0
	MOVEQ	PC,LR	(* if len=0 then return *)
loop
	SUBS	R0,R0,1
	LDRB	R3,[R2,R0]
	STRB	R3,[R1,R0]
	BNE	loop
	MOV	PC,LR
END Move;

(** MakeRoom - Allocate data space for "size" bytes in front of current data. "size" MOD 4 must be 0 if item is not empty *)	
PROCEDURE MakeRoom*(i : Item; size : LONGINT);	
BEGIN
	ASSERT((size MOD 4 = 0) OR (i.len=0)); (* if the size is not a multiple of 4, all previously inserted headers are misaligned! *)
	Move(SYSTEM.ADR(i.data[0]),SYSTEM.ADR(i.data[size]),i.len);
	INC(i.len, SHORT(size));
END MakeRoom;

PROCEDURE CheckSum* (VAR data: ARRAY OF SYSTEM.BYTE; len, base: LONGINT): LONGINT;
CODE
	LDMFD	SP!,{R0,R1,R2,R3}	(* R0 = base	R1 = len	R2 = ptr to data[0]	R3 = LEN(data) *)
	MOV	R1,R1,ASR 1
loop
	LDRB	R3, [R2],1	(* LSB *)
	LDRB	R4, [R2],1	(* MSB *)
	ORR	R3,R3,R4,LSL 8
	ADD	R0,R0,R3
	SUBS	R1,R1,1
	BNE	loop
	MOV	R1,R0, ASR 16
	MVN	R3,0	(* R3 = 0FFFFFFFFH *)
	AND	R0,R0,R3, LSR 16	(* R0 := R0 AND 0FFFFH *)
	ADD	R0,R0,R1
	MOV	R1,R0, ASR 16
	ADD	R0,R0,R1
	MVN	R0,R0
	AND	R0,R0,R3, LSR 16
	MOV	PC,LR
END CheckSum;

PROCEDURE ByteSum* (VAR data: ARRAY OF SYSTEM.BYTE; len: LONGINT): LONGINT;
CODE
	LDMFD	SP!,{R2,R3,R4}	(* R2 = len	R3 = ptr to data[0]	R4 = LEN(data) *)
	MOV	R0,0
	MOV	R2,R2,ASR 1
loop
	LDRB	R4,[R3],1	(* LSB *)
	LDRB	R5,[R3],1	(* MSB *)
	ORR	R4,R4,R5,LSL 8
	ADD	R0,R0,R4
	SUBS	R2,R2,1
	BNE	loop
	MOV	PC,LR
END ByteSum;

PROCEDURE NetToHost* (VAR i: INTEGER);
BEGIN i := SYSTEM.ROT(i, 8)
END NetToHost;

PROCEDURE HostToNet* (VAR i: INTEGER);
BEGIN i := SYSTEM.ROT(i, 8)
END HostToNet;

PROCEDURE NetLToHost* (VAR l: ARRAY OF SYSTEM.BYTE);
VAR
	b: SYSTEM.BYTE;
BEGIN b := l[3]; l[3] := l[0]; l[0] := b; b := l[2]; l[2] := l[1]; l[1] := b
END NetLToHost;

PROCEDURE HostLToNet* (VAR l: ARRAY OF SYSTEM.BYTE);
VAR
	b: SYSTEM.BYTE;
BEGIN b := l[3]; l[3] := l[0]; l[0] := b; b := l[2]; l[2] := l[1]; l[1] := b
END HostLToNet;

PROCEDURE ^ GetItem* (VAR Q: Queue; VAR item: Item);

(** NewItem - Allocate a new item.  item.ofs and item.len are set to 0 *)

PROCEDURE NewItem* (VAR item: Item);
BEGIN
	IF freeList.len = 0 THEN NEW(item)
	ELSE GetItem(freeList, item)
	END;
	item.padding := 0X;	(* temporary *)
	item.ofs := 0; item.len := 0
END NewItem;

(** GetItem - Take an item from the front of a queue *)

PROCEDURE GetItem* (VAR Q: Queue; VAR item: Item);
BEGIN
	IF Q.len <= 0 THEN HALT(100) END;
	item := Q.first; Q.first := Q.first.next; DEC(Q.len);
	IF Q.first = NIL THEN Q.last := NIL END;
	(*item.len := 0*)
END GetItem;

(** PutItem - Put an item at the end of a queue *)

PROCEDURE PutItem* (VAR Q: Queue; item: Item);
VAR p: Item;
BEGIN
	IF DebugQueues THEN
		p := Q.first;
		WHILE p # NIL DO
			IF p = item THEN
				HALT(MAX(INTEGER))	(* error: item already in list *)
			END;
			p := p.next
		END
	END;
    IF Q.last # NIL THEN Q.last.next := item ELSE Q.first := item END;
    Q.last := item; item.next := NIL; INC(Q.len);
END PutItem;

(** RecycleItem - Recycle an item that is no longer used *)

PROCEDURE RecycleItem* (item: Item);
BEGIN
	PutItem(freeList, item)
END RecycleItem;

(** Reset - Initialise a queue *)

PROCEDURE Reset* (VAR Q: Queue);
BEGIN
	Q.len := 0; Q.first := NIL; Q.last := NIL
END Reset;

(** FindDevice - Find the device with the specified number (0..).  Returns NIL if no such device. *)

PROCEDURE FindDevice* (num: LONGINT): Device;
VAR dev: Device;
BEGIN
	IF (num >= 0) & (num < nofDevices) THEN dev := device[num] ELSE dev := NIL END;
	RETURN dev
END FindDevice;

(** InstallDevice - Install a new device.  Devices are numbered 0, 1, ... in installation order. *)

PROCEDURE InstallDevice*(dev: Device);
BEGIN
	dev.state := closed;  dev.sndCnt := 0;  dev.recCnt := 0;  dev.num := nofDevices;
	device[nofDevices] := dev;  INC(nofDevices)
END InstallDevice;

(** Poll - Poll all installed devices for packets and deliver them upstream. *)

PROCEDURE Poll*;
VAR item: Item;  src: MacAdr;  prno: INTEGER;  i, j: SHORTINT;
BEGIN
	FOR i := 0 TO nofDevices-1 DO
		IF device[i].state = open THEN
			WHILE device[i].Available(device[i]) DO
				NewItem(item);  item.ofs := 0;
				device[i].Receive(device[i], prno, src, item); j := 0;
				WHILE (j < nofProtocols) & (protocols[j].prno # prno) DO INC(j) END;
				IF j < nofProtocols THEN
					IF Trace THEN
						Kernel.WriteString("Recv:");  Kernel.WriteHex(prno, 9);  Kernel.WriteLn;
						(*Kernel.WriteMemory(SYSTEM.ADR(item.data[item.ofs-14]), 14);*)	(* peek into ethernet header *)
						Kernel.WriteMemory(SYSTEM.ADR(item.data[item.ofs]), item.len)
					END;
					protocols[j].proc(item)
				ELSE
					IF Trace THEN Kernel.WriteString("Drop: "); Kernel.WriteHex(prno, 8); Kernel.WriteLn END;
					PutItem(freeList, item)
				END;
				INC(device[i].recCnt)
			END
		END
	END;
	FOR i := 0 TO nofTasks-1 DO tasks[i](Kernel.GetTimer()) END
END Poll;

(** InstallProtocol - Install a handler for the specified protocol *)

PROCEDURE InstallProtocol* (P: ProtocolProc; prno: INTEGER);
VAR i: INTEGER;
BEGIN
	i := 0; WHILE (i # nofProtocols) & (protocols[i].prno # prno) DO INC(i) END;
	IF i = nofProtocols THEN
		IF Trace THEN Kernel.WriteString("InstallProtocol ");  Kernel.WriteHex(prno, 8);  Kernel.WriteLn END;
		protocols[nofProtocols].prno := prno; protocols[nofProtocols].proc := P;
		INC(nofProtocols)
	END
END InstallProtocol;

(** InstallTimer - Install a polling task. *)

PROCEDURE InstallTask*(p: TaskProc);
BEGIN
	tasks[nofTasks] := p;  INC(nofTasks)
END InstallTask;

(** Start - Initialise the polling task *)

PROCEDURE Start*;
VAR i: SHORTINT;
BEGIN
	Reset(freeList);
	FOR i := 0 TO nofDevices-1 DO
		IF device[i].state = closed THEN device[i].state := open END
	END
END Start;

(** Stop - Stop the polling task *)

PROCEDURE Stop*;
BEGIN
	Reset(freeList);
	nofDevices := 0; nofProtocols := 0; nofTasks := 0
END Stop;

BEGIN
	anyadr[0] := 0X; anyadr[1] := 0X; anyadr[2] := 0X;
	anyadr[3] := 0X; anyadr[4] := 0X; anyadr[5] := 0X;
	Stop
END NetBase.
