�TextDocs.NewDoc     ��?   Oberon10.Scn.Fnt  )       �    A    g   d  MODULE Dhrystone;
	(* Ada:			Reinhold P. Weicker, 15-Apr-84
		 Modula-2: Werner Heiz, 27-Sep-87 
	Oberon: B. Heeb, 15-2-89
	Sparc-Oberon: J. Templ 28.1.91, Version 2.1 *)
	
	IMPORT Texts, SYSTEM, Oberon, Input;

	CONST
		Ident1 = 0; Ident2 = 1; Ident3 = 2; Ident4 = 3; Ident5 = 4;
		NumberOfRuns =	10*64000; 

	TYPE
	INTEGER = LONGINT;

		Enumeration			= INTEGER;
		OneToThirty			= INTEGER;
		OneToFifty			 = INTEGER;
		CapitalLetter		= CHAR;
		String30				 = ARRAY 31 OF CHAR;
		Array1DimInteger = ARRAY 50 OF INTEGER;
		Array2DimInteger = ARRAY 50, 50 OF INTEGER;
		RecordPointer		= POINTER TO RecordType;
		RecordType			 = RECORD
												 PointerComp: RecordPointer;
												 Discr: Enumeration;
												 EnumComp: Enumeration;
												 IntComp: OneToFifty;
												 StringComp: String30;
												 CharComp1, CharComp2: CHAR;
											 END;

	VAR
		IntGlob: INTEGER;
		BoolGlob: BOOLEAN;
		CharGlob1,
		CharGlob2: CHAR;
		ArrayGlob1: Array1DimInteger;
		ArrayGlob2: Array2DimInteger;
		PointerGlob,
		PointerGlobNext: RecordPointer;
		time, num: LONGINT;
		W: Texts.Writer;
	

	PROCEDURE Func1(CharParIn1, CharParIn2: CapitalLetter): Enumeration;
	VAR CharLoc1, CharLoc2: CapitalLetter;
	BEGIN
		CharLoc1 := CharParIn1;
		CharLoc2 := CharLoc1;
		IF CharLoc2 # CharParIn2 THEN RETURN Ident1
		ELSE RETURN Ident2 END;
	END Func1;

	PROCEDURE Func2(VAR StringParIn1, StringParIn2: String30): BOOLEAN;
	VAR IntLoc: OneToFifty; CharLoc: CapitalLetter;
	BEGIN
		IntLoc := 2;
		WHILE IntLoc <= 2 DO
			IF Func1(StringParIn1[IntLoc], StringParIn2[IntLoc+1]) = Ident1 THEN
				CharLoc := "A";
				INC(IntLoc);
			END;
		END;
		IF (CharLoc >= "W") & (CharLoc < "Z") THEN IntLoc := 7 END;
		IF CharLoc = "X" THEN RETURN TRUE
		ELSE
			IF StringParIn1 > StringParIn2 THEN (*IntLoc := IntLoc + 7*) INC(IntLoc, 7); RETURN TRUE
			ELSE RETURN FALSE END;
		END;
	END Func2;

	PROCEDURE Func3(EnumParIn: Enumeration): BOOLEAN;
	VAR EnumLoc: Enumeration;
	BEGIN
		EnumLoc := EnumParIn;
		RETURN EnumLoc = Ident3
	END Func3;

	PROCEDURE Proc6(EnumParIn: Enumeration; VAR EnumParOut: Enumeration);
	BEGIN
		EnumParOut := EnumParIn;
		IF ~ Func3(EnumParIn) THEN EnumParOut := Ident4 END;
		CASE EnumParIn OF
		| Ident1: EnumParOut := Ident1;
		| Ident2: IF IntGlob > 100 THEN EnumParOut := Ident1 ELSE EnumParOut := Ident4 END;
		| Ident3: EnumParOut := Ident2;
		| Ident4: ;
		| Ident5: EnumParOut := Ident3;
		END;
	END Proc6;

	PROCEDURE Proc7(IntParIn1, IntParIn2: OneToFifty; VAR IntParOut: OneToFifty);
	VAR IntLoc: OneToFifty;
	BEGIN
		IntLoc := IntParIn1 + 2;
		IntParOut := IntParIn2 + IntLoc;
	END Proc7;

	PROCEDURE Proc3(VAR PointerParOut: RecordPointer);
	BEGIN
		IF PointerGlob # NIL THEN PointerParOut := PointerGlob^.PointerComp;
		ELSE IntGlob := 100 END;
		Proc7(10, IntGlob, PointerGlob^.IntComp);
	END Proc3;

	PROCEDURE Proc1(PointerParIn: RecordPointer);
	VAR p: RecordPointer;
	BEGIN
		PointerParIn^.PointerComp^ := PointerGlob^;
		p := PointerParIn.PointerComp;
		PointerParIn.IntComp := 5;
		p.IntComp := PointerParIn.IntComp;
		p.PointerComp := PointerParIn.PointerComp;
		Proc3(p.PointerComp);
		IF p.Discr = Ident1 THEN
			p.IntComp := 6;
			Proc6(PointerParIn.EnumComp, p.EnumComp);
			p.PointerComp := PointerGlob^.PointerComp;
			Proc7(p.IntComp, 10, p.IntComp);
		ELSE PointerParIn^ := PointerParIn.PointerComp^ END
	END Proc1;

	PROCEDURE Proc2(VAR IntParInOut: OneToFifty);
	VAR IntLoc: OneToFifty; EnumLoc: Enumeration;
	BEGIN
		IntLoc := IntParInOut + 10;
		REPEAT
			IF CharGlob1 = "A" THEN
				DEC(IntLoc); IntParInOut := IntLoc - IntGlob;
				EnumLoc := Ident1;
			END;
		UNTIL EnumLoc = Ident1;
	END Proc2;

	PROCEDURE Proc4;
	VAR BoolLoc: BOOLEAN;
	BEGIN
		BoolLoc := CharGlob1 = "A";
		BoolLoc := BoolLoc OR BoolGlob;
		CharGlob2 := "B";
	END Proc4;

	PROCEDURE Proc5;
	BEGIN
		CharGlob1 := "A"; BoolGlob := FALSE
	END Proc5;

	PROCEDURE Proc8(VAR ArrayParInOut1: Array1DimInteger;
									VAR ArrayParInOut2: Array2DimInteger;
									IntParIn1, IntParIn2: INTEGER);
	VAR IntLoc: OneToFifty; IntIndex: INTEGER;
	BEGIN
		IntLoc := IntParIn1 + 5;
		ArrayParInOut1[IntLoc] := IntParIn2;
		ArrayParInOut1[IntLoc+1] := ArrayParInOut1[IntLoc];
		ArrayParInOut1[IntLoc+30] := IntLoc;
		IntIndex := IntLoc;
		WHILE IntIndex <= IntLoc+1 DO
			ArrayParInOut2[IntLoc, IntIndex] := IntLoc; INC(IntIndex)
		END;
		INC(ArrayParInOut2[IntLoc, IntLoc-1]);
		ArrayParInOut2[IntLoc+20, IntLoc] := ArrayParInOut1[IntLoc];
		IntGlob := 5
	END Proc8;

	PROCEDURE Proc0;
	VAR IntLoc1, IntLoc2, IntLoc3: OneToFifty;
			CharLoc: CHAR;
			EnumLoc: Enumeration;
			StringLoc1, StringLoc2: String30;
			CharIndex: INTEGER;
			t: LONGINT;
	BEGIN
		StringLoc1 := "DHRYSTONE PROGRAM, 1'ST STRING";
		ArrayGlob2[8, 7] := 10;	(*was missing in published program*)
		num := 0; t := Input.Time(); 
		REPEAT time := Input.Time() UNTIL time # t;
		WHILE num < NumberOfRuns DO
			Proc5;
			Proc4;
			IntLoc1 := 2;
			IntLoc2 := 3;
			StringLoc2 := "DHRYSTONE PROGRAM, 2'ND STRING";
			EnumLoc := Ident2;
			BoolGlob := ~ Func2(StringLoc1, StringLoc2);

			WHILE IntLoc1 < IntLoc2 DO
				IntLoc3 := 5 * IntLoc1 - IntLoc2;
				Proc7(IntLoc1, IntLoc2, IntLoc3);
				INC(IntLoc1);
			END;
			Proc8(ArrayGlob1, ArrayGlob2, IntLoc1, IntLoc3);
			Proc1(PointerGlob);
			CharIndex := ORD("A");

			WHILE CharIndex <= ORD(CharGlob2) DO
				IF EnumLoc = Func1(CHR(CharIndex), "C") THEN Proc6(Ident1, EnumLoc) END;
				INC(CharIndex)
			END;
			IntLoc2 := IntLoc2 * IntLoc1;
			IntLoc1 := IntLoc2 DIV IntLoc3;
			IntLoc2 := 7 * (IntLoc2 - IntLoc3) - IntLoc1;
			Proc2(IntLoc1);

			INC(num)
		END ;

		time := Input.Time() - time;
	IF (IntGlob = 5) &
			BoolGlob &
			(CharGlob1 = "A") &
			(CharGlob2 = "B") &
		(ArrayGlob1[8] = 7) &
		(ArrayGlob2[8, 7] MOD 32768 = (num + 10) MOD 32768) &
		(PointerGlob.Discr = 0) &
		(PointerGlob.EnumComp = 2) &
		(PointerGlob.IntComp = 17) &
		(PointerGlob.StringComp = "DHRYSTONE PROGRAM, SOME STRING") &
		(PointerGlobNext.Discr = 0) &
		(PointerGlobNext.EnumComp = 1) &
		(PointerGlobNext.IntComp = 18) &
		(PointerGlobNext.StringComp = "DHRYSTONE PROGRAM, SOME STRING") &
		(IntLoc1 = 5) &
		(IntLoc2 = 13) &
		(IntLoc3	= 7) &
		(EnumLoc = 1) &
		(StringLoc1 = "DHRYSTONE PROGRAM, 1'ST STRING") &
		(StringLoc2 = "DHRYSTONE PROGRAM, 2'ND STRING")
		THEN Texts.WriteString(W, "passed ");
	ELSE Texts.WriteString(W, "failed ")
	END

	END Proc0;

	PROCEDURE Do*;
	BEGIN
		Texts.WriteString(W, "Dhrystone: "); 
		Proc0;
		Texts.WriteInt(W, num * Input.TimeUnit DIV time, 8);
		Texts.WriteString(W, " / sec");
		Texts.WriteInt(W, time, 8);
		Texts.WriteLn(W);
		Texts.Append(Oberon.Log, W.buf);
	END Do;
	
BEGIN
	Texts.OpenWriter(W);
	NEW(PointerGlobNext);
	NEW(PointerGlob);
		PointerGlob.PointerComp := PointerGlobNext;
		PointerGlob.Discr := Ident1;
		PointerGlob.EnumComp := Ident3;
		PointerGlob.IntComp := 40;
		PointerGlob.StringComp := "DHRYSTONE PROGRAM, SOME STRING";
END Dhrystone.Do

Compiler.Compile ARM.Dhrystone.Mod\Nnoxt		Dhrystone: passed    40167 / sec