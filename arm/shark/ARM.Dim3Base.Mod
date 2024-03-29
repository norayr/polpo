�TextDocs.NewDoc     ����   Oberon10.Scn.Fnt  x  Oberon10b.Scn.Fnt      n   Oberon16b.Scn.Fnt  
    �        �        e        �        �        �    J  (* OBERON System 3, Release 2.3.

Copyright 1999 ETH Z�rich Institute for Computer Systems, 
ETH Center, CH-8092 Z�rich. e-mail: oberon@inf.ethz.ch.

This module may be used under the conditions of the general Oberon 
System 3 license contract. The full text can be downloaded from

	"ftp://ftp.inf.ethz.ch/pub/software/Oberon/System3/license.txt;A"

Under the license terms stated it is in particular (a) prohibited to modify
the interface of this module in any way that disagrees with the style
or content of the system and (b) requested to provide all conversions
of the source code to another platform with the name OBERON. *)

MODULE Dim3Base;	(** portable *)	(* David Ulrich Nov  95 - M�rz 96 *)
(* This module contains not portable procedures for the Shark version **)

IMPORT S := SYSTEM, Pictures;
CONST Black* = 15; White* = 0;	(** black and white of the windows color table **)
VAR
	baseAdr, lineW, height: LONGINT;

(** correct color table for Native version **)
PROCEDURE CheckColorTab*(VAR R, G, B: ARRAY OF INTEGER);
BEGIN
	(* nothing to do *)
END CheckColorTab;

(** convert color number to Dim3 color palette **)
PROCEDURE GetRealColor*(color: INTEGER):INTEGER;
BEGIN
	RETURN color
END GetRealColor;

(** calculate picture addresses **)
PROCEDURE SetPicture*(P: Pictures.Picture);
BEGIN
	baseAdr := P.address;
	lineW := P.width; height := P.height;
END SetPicture;

(** get address of position X in current scanline Y of actual picture **)
PROCEDURE GetAddress*(X, Y: INTEGER): LONGINT;
BEGIN
	RETURN baseAdr + lineW * Y + X;
END GetAddress;

(** ReplConst in previosly set picture with mode replace, H = 1 **)
PROCEDURE ReplConst*(col, X, Y, W: INTEGER);
VAR color: CHAR; pictAdr: LONGINT; 
BEGIN
	color := CHR(col);
	pictAdr := baseAdr + lineW * Y + X;
	WHILE W > 0 DO S.PUT(pictAdr, color); DEC(W); INC(pictAdr) END;
END ReplConst;

END Dim3Base.