�   Oberon10.Scn.Fnt          �  Oberon10b.Scn.Fnt      B        �        �        9       �                       �        �       B        �       B        �    p        �    �  (* ETH Oberon, Copyright 1990-2003 Computer Systems Institute, ETH Zurich, CH-8092 Zurich.
Refer to the license.txt file provided with this distribution. *)
(*
	peter matthias
	2015-05-08	changes to compile on ARM
*)

MODULE ZlibBuffers;	(** Stefan Walthert   **)
(** AUTHOR "swalthert"; PURPOSE "Zlib buffering"; *)

IMPORT
	SYSTEM;
		(*
			should be portable even if SYSTEM is imported:
			- PUT and GET only with byte sized operands
			- no overlapping MOVEs (unless malignant client passes buffer memory to buffer operations)
		*)

TYPE
	(** input/output buffer **)
	Address = LONGINT;
	Buffer* = RECORD
		avail*: LONGINT;	(** number of bytes that can be produced/consumed **)
		size*: LONGINT;	(** total number of bytes in buffer memory **)
		totalOut*, totalIn*: LONGINT;	(** total number of bytes produced/consumed **)
		next: Address;	(* address of next byte to produce/consume **)
		adr: Address;	(* buffer memory *)
	END;


(** set buf.totalIn and buf.totalOut to zero **)
PROCEDURE Reset*(VAR buf: Buffer);
BEGIN
	buf.totalIn := 0; buf.totalOut := 0
END Reset;

(** initialize buffer on memory in client space **)
PROCEDURE Init* (VAR buf: Buffer; VAR mem: ARRAY OF CHAR; offset, size, avail: LONGINT);
BEGIN
	ASSERT((0 <= offset) & (0 < size) & (offset + size <= LEN(mem)), 100);
	ASSERT((0 <= avail) & (avail <= size),101);
	buf.avail := avail; buf.size := size; buf.adr := SYSTEM.ADR(mem[offset]); buf.next := buf.adr;
END Init;

(** read byte from (input) buffer **)
PROCEDURE Read* (VAR buf: Buffer; VAR ch: CHAR);
BEGIN
	ASSERT(buf.avail > 0, 100);
	SYSTEM.GET(buf.next, ch);
	INC(buf.next); DEC(buf.avail); INC(buf.totalIn)
END Read;

(** read len bytes from (input) buffer **)
PROCEDURE ReadBytes* (VAR buf: Buffer; VAR dst: ARRAY OF CHAR; offset, len: LONGINT);
BEGIN
	ASSERT((0 <= offset) & (0 < len) & (offset + len <= LEN(dst)) & (len <= buf.avail), 100);
	SYSTEM.MOVE(buf.next, SYSTEM.ADR(dst[offset]), len);
	 INC(buf.next, len); DEC(buf.avail, len); INC(buf.totalIn, len)
END ReadBytes;
	
(** write byte into (output) buffer **)
PROCEDURE Write* (VAR buf: Buffer; ch: CHAR);
BEGIN
	ASSERT(buf.avail > 0, 100);
	SYSTEM.PUT(buf.next, ch);
	INC(buf.next); DEC(buf.avail); INC(buf.totalOut)
END Write;

(** write len bytes into (output) buffer **)
PROCEDURE WriteBytes* (VAR buf: Buffer; VAR src: ARRAY OF CHAR; offset, len: LONGINT);
BEGIN
	ASSERT((0 <= offset) & (0 < len) & (offset + len <= LEN(src)) & (len <= buf.avail), 100);
	SYSTEM.MOVE(SYSTEM.ADR(src[offset]), buf.next, len);
	INC(buf.next, len); DEC(buf.avail, len); INC(buf.totalOut, len)
END WriteBytes;

(** rewind previously empty input buffer to first position after it has been filled with new input **)
PROCEDURE Rewind* (VAR buf: Buffer; avail: LONGINT);
BEGIN
	ASSERT(buf.avail = 0, 100);
	ASSERT((0 <= avail) & (avail <= buf.size), 101);
	buf.next := buf.adr; buf.avail := avail
END Rewind;

(** move position of next read for -offset bytes **)
PROCEDURE Reread* (VAR buf: Buffer; offset: LONGINT);
BEGIN
	ASSERT((0 <= offset) & (buf.avail + offset <= buf.size), 101);
	DEC(buf.next, offset); INC(buf.avail, offset)
END Reread;

(** restart writing at starting position of output buffer after it has been emptied **)
PROCEDURE Rewrite* (VAR buf: Buffer);
BEGIN
	buf.next := buf.adr; buf.avail := buf.size
END Rewrite;
	
(** fill input buffer with new bytes to consume **)
PROCEDURE Fill* (VAR buf: Buffer; VAR src: ARRAY OF CHAR; offset, size: LONGINT);
BEGIN
	ASSERT((0 <= offset) & (0 < size) & (offset + size <= LEN(src)), 100);
	ASSERT(buf.avail + size <= buf.size, 101);
	IF buf.avail # 0 THEN
		SYSTEM.MOVE(buf.next, buf.adr, buf.avail)
	END;
	buf.next := buf.adr + buf.avail;
	SYSTEM.MOVE(SYSTEM.ADR(src[offset]), buf.next, size);
	INC(buf.avail, size)
END Fill;

(** extract bytes from output buffer to make room for new bytes **)
PROCEDURE Drain* (VAR buf: Buffer; VAR dst: ARRAY OF CHAR; offset, size: LONGINT);
VAR i, s, d, n: LONGINT; c: CHAR;
BEGIN
	ASSERT((0 <= offset) & (0 < size) & (offset + size <= LEN(dst)), 100);
	ASSERT(buf.avail + size <= buf.size, 101);	(* can't consume more than is in buffer *)
	SYSTEM.MOVE(buf.adr, SYSTEM.ADR(dst[offset]), size);
	(*SYSTEM.MOVE(buf.adr + size, buf.adr, buf.size - buf.avail - size);   overlapping moves don't work on SPARC !*)
	n := buf.size - buf.avail - size;  s := buf.adr + size;  d := buf.adr; 
	FOR i := 0 TO n - 1 DO SYSTEM.GET( s + i, c );  SYSTEM.PUT( d + i, c ) END;
	INC(buf.avail, size); DEC(buf.next, size);
END Drain;

END ZlibBuffers.�BIER�  
   �    :       Z  ��    ��C  Oberon10.Scn.Fnt 08.05.15  20:10:42  TimeStamps.New  �