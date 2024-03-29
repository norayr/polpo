�TextDocs.NewDoc     ��e   Oberon10.Scn.Fnt  x  Syntax10.Scn.Fnt  �       k    �              u  (* OBERON System 3, Release 2.3.

Copyright 1999 ETH Z�rich Institute for Computer Systems, 
ETH Center, CH-8092 Z�rich. e-mail: oberon@inf.ethz.ch.

This module may be used under the conditions of the general Oberon 
System 3 license contract. The full text can be downloaded from

	"ftp://ftp.inf.ethz.ch/pub/software/Oberon/System3/license.txt;A"

Under the license terms stated it is in particular (a) prohibited to modify
the interface of this module in any way that disagrees with the style
or content of the system and (b) requested to provide all conversions
of the source code to another platform with the name OBERON. *)

MODULE StreamCompress;	(* as - based on Compress by ejz *)

(** Decompresses all files from a archive in a "streaming manner" *)

IMPORT CompressUtil, Files, SYSTEM;

CONST
	DocId0 = 0F7X;
	DocId1 = 07X;
	EOFName = "~ ";
	Done *= 0;
	ArchiveNotFound *= 1;
	ErrorInArchive *= 2;
	EntryNotFound *= 3;
	ArchiveExists *= 4;
	FileError *= 5;
	KeyNeeded* = 6;
	EncryptionNotSupported* = 7;
	xx = 32768;
	encryption = 0;
	BufSize = 4096;

TYPE
	Notifier* = PROCEDURE(name : ARRAY OF CHAR);
	
	Name = ARRAY 32 OF CHAR;
	Bytes4 = ARRAY 4 OF CHAR;
	Header = RECORD
		name*: Name;
		length*, check: LONGINT;
		date*, time*: LONGINT;
		ratio: REAL;
		extensions*: SET (* encryption *)
	END;
	
VAR
	Ro : Files.Rider; (* Output-Rider *)
	buf : ARRAY BufSize OF CHAR;
	Eof : BOOLEAN;
	Read : CompressUtil.InputProc;

	testR : Files.Rider; (* TEST ONLY! *)
	
PROCEDURE ReadBytes(VAR b : ARRAY OF CHAR; n : LONGINT);
VAR i : LONGINT;
BEGIN
	i := 0; WHILE n>0 DO Read(b[i],Eof); INC(i); DEC(n) END
END ReadBytes;
	
PROCEDURE ReadInt*(VAR x: INTEGER);
VAR x0, x1: CHAR;
BEGIN Read(x0,Eof); Read(x1,Eof);
	x := LONG(SYSTEM.VAL(SHORTINT,x1)) * 100H + LONG(SYSTEM.VAL(SHORTINT,x0)) MOD 100H
END ReadInt;

PROCEDURE ReadLInt(VAR x: LONGINT);
BEGIN ReadBytes(SYSTEM.VAL(Bytes4, x), 4)
END ReadLInt;
	
PROCEDURE ReadReal(VAR x: REAL);
BEGIN ReadBytes(SYSTEM.VAL(Bytes4, x), 4)
END ReadReal;
	
PROCEDURE ReadSet(VAR x: SET);
BEGIN ReadBytes(SYSTEM.VAL(Bytes4, x), 4)
END ReadSet;

PROCEDURE ReadString(VAR x: ARRAY OF CHAR);
VAR i: INTEGER; ch: CHAR;
BEGIN i := 0;
	LOOP
		Read(ch,Eof); x[i] := ch; INC(i);
		IF ch = 0X THEN EXIT END;
		IF i = LEN(x) THEN x[i-1] := 0X;
			REPEAT Read(ch,Eof) UNTIL ch = 0X;
			EXIT
		END
	END
END ReadString;

PROCEDURE ReadHeader(VAR h: Header; VAR err: BOOLEAN);
VAR c1, c2 : CHAR; chk : LONGINT; i: INTEGER;
BEGIN
	Read(c1,Eof); Read(c2,Eof);
	IF (c1 = DocId0) & (c2 = DocId1) THEN
		(* new doc-format skip header *)
		ReadString(h.name);
		ReadInt(i);
		ReadInt(i);
		ReadInt(i);
		ReadInt(i);
		ReadHeader(h, err)
	ELSE
		IF Eof THEN h.name := EOFName; err := FALSE; RETURN END;
		h.name[0]:=c1; h.name[1]:=c2; 
		FOR i:=2 TO 31 DO Read(h.name[i],Eof) END;
		ReadLInt(h.length);
		ReadLInt(h.check);
		ReadLInt(h.date);
		ReadLInt(h.time);
		ReadReal(h.ratio);
		IF h.length < 0 THEN ReadSet(h.extensions); h.length := -h.length
		ELSE h.extensions := {} 
		END;
		IF (h.ratio > 0.0) & (h.ratio < 1000000.0) THEN
			i := 0; chk := 0;
			WHILE i < 32 DO chk := chk+ORD(h.name[i]); INC(i) END;
			h.name[31] := 0X;
			chk := chk+h.length+ENTIER(h.ratio)+(h.time MOD xx)+(h.date MOD xx);
			err := chk # h.check
		ELSE err := TRUE
		END
	END
END ReadHeader;

(* Expand a maximum of len Bytes from Ri to Ro.
	res:
		Done
		ErrorInArchive: error in compressed data *)
	PROCEDURE CopyFromArc(VAR h: Header; VAR res: INTEGER);
	VAR outLen : LONGINT;
	BEGIN
		res := Done; 
		IF encryption IN h.extensions THEN res := EncryptionNotSupported
		ELSE 
			CompressUtil.InitExpand(Read);
			REPEAT
				CompressUtil.ExpandBlock(buf, BufSize, outLen, Eof); 
				IF outLen = -1 THEN res := ErrorInArchive; RETURN END;
				Files.WriteBytes(Ro,buf,outLen)
			UNTIL outLen < BufSize;
		END
	END CopyFromArc;

(** Extract all entries in archive.
		res:
			Done
			EncryptionNotSupported: archive is encrypted and can't be decompressed
			ErrorInArchive: internal error in archive-file
			FileError: an entry file could not be created *)
	PROCEDURE ExtractAllFiles*(read : CompressUtil.InputProc; fileDone : Notifier; VAR res: INTEGER);
	VAR AddF: Files.File; h: Header; err: BOOLEAN; 
	BEGIN
		Read := read;
		ReadHeader(h, err);
		WHILE (h.name # EOFName) & ~err DO
			AddF := Files.New(h.name);
			IF AddF # NIL THEN
				Files.Set(Ro, AddF, 0);
				CopyFromArc(h, res);
				IF res = Done THEN Files.Register(AddF); Files.SetDate(AddF, h.time, h.date)
				ELSE RETURN
				END
			ELSE res := FileError; RETURN
			END;
			IF fileDone # NIL THEN fileDone(h.name) END;
			ReadHeader(h, err)
		END;
		IF err THEN res := ErrorInArchive
		ELSE res := Done
		END
	END ExtractAllFiles;

END StreamCompress.

