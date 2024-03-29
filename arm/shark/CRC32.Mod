� 1   Oberon10.Scn.Fnt  �         D   #  (* ETH Oberon, Copyright 2000 ETH Z�rich Institut f�r Computersysteme, ETH Zentrum, CH-8092 Z�rich.
Refer to the general ETH Oberon System license contract available at: http://www.oberon.ethz.ch/ *)

MODULE CRC32; (* ejz   *)
	IMPORT SYSTEM;

	CONST
		CRCInit* = {};

	VAR
		crcTable: ARRAY 256 OF SET;

	PROCEDURE CRC32*(crc: SET; VAR buf: ARRAY OF SYSTEM.BYTE; len: LONGINT): SET;
		VAR i, j: LONGINT;
	BEGIN
		i := 0; crc := crc / {0 .. 31};
		WHILE len >= 8 DO
			j := 0;
			WHILE j < 8 DO
				crc := crcTable[SYSTEM.VAL(LONGINT, (crc / SYSTEM.VAL(SET, LONG(ORD(buf[i])))) * {0 .. 7})] / SYSTEM.LSH(crc, -8);
				INC(i); INC(j)
			END;
			DEC(len, 8)
		END;
		IF len > 0 THEN
			REPEAT
				crc := crcTable[SYSTEM.VAL(LONGINT, (crc / SYSTEM.VAL(SET, LONG(ORD(buf[i])))) * {0 .. 7})] / SYSTEM.LSH(crc, -8);
				INC(i); DEC(len)
			UNTIL len <= 0
		END;
		RETURN crc / {0 .. 31}
	END CRC32;

	PROCEDURE InitCRCTable();
		VAR
			p: ARRAY 14 OF LONGINT;
			poly, c: SET;
			k, n: LONGINT;
	BEGIN
		p[0] := 0; p[1] := 1; p[2] := 2; p[3] := 4; p[4] := 5; p[5] := 7; p[6] := 8; p[7] := 10;
		p[8] := 11; p[9] := 12; p[10] := 16; p[11] := 22; p[12] := 23; p[13] := 26;
		poly := {}; n := 0;
		WHILE n < 14 DO
			poly := poly + SYSTEM.LSH({0}, (31-p[n])); INC(n)
		END;
		n := 0;
		WHILE n < 256 DO
			c := SYSTEM.VAL(SET, n); k := 0;
			WHILE k < 8 DO
				IF 0 IN SYSTEM.VAL(SET, c) THEN
					c := poly / SYSTEM.LSH(c, -1)
				ELSE
					c := SYSTEM.LSH(c, -1)
				END;
				INC(k)
			END;
			crcTable[n] := c; INC(n)
		END
	END InitCRCTable;

BEGIN
	InitCRCTable()
END CRC32.
�BIER�  �   g    :       g 
 ��    ��C  Oberon10.Scn.Fnt 16.02.00  11:24:39  TimeStamps.New  �