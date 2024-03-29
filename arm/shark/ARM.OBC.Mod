�TextDocs.NewDoc     �a�"  Oberon10.Scn.Fnt  �
   U       I    u   s    �   )    �
   4        
    �        �       S        �    m       {                             '       -       �       B       I       N       �       $       �        �    O    5                                        U        $       ;       �       �        N       	       �   �n  MODULE OBC;  (*NW 30.5.87 / 28.3.93 / as 23.02.99 *)

	IMPORT SYSTEM, Files, OBS, OBT, OC := OBM;

	CONST
		ObjMark = 0F5X; 
		CodeLength = 32768; (* 128K Code. Don't make it bigger (because of fixup list limits! *)
		ConstLength = 1024; (* in Words *)
		StrConstLength = 4096; (* in Bytes, ziemlich willk�rlich, kann ruhig VIEL groesser sein *)
		MaxConstDist = ConstLength-15; (* in Words including a safety range *)
		MaxUnknownProcs = 128;
		MaxPtrs = 512; MaxRecs = 128; MaxComs = 40; MaxExts = 15;
		
		(* Constants for Bit x set *)
		C22 = 400000H; C23 = 800000H; C24 = 1000000H; C25 = 2000000H;

		(* Op-Codes Single Data Transfer (SDT) *)
		LDR* = 51H; (* LDR, pre-indexed, no write-back *)
		STR* = 50H; (* STR, pre-indexed, no write-back *)
		LDRB* = 55H; (* LDRB, pre-indexed, no write-back *)
		STRB* = 54H; (* STRB, pre-indexed, no write-back *)
	
		LDRpost* = 41H; (* LDR, post-indexed, no write-back-bit *)
		STRpost* = 40H; (* STR, post-indexed, no write-back-bit *)
		LDRBpost* = 45H; (* LDRB, post-indexed, no write-back-bit *)
		STRBpost* = 44H; (* STRB, post-indexed, no write-back-bit *)
	
		(* Op-Codes Halfword Data Transfer (HDT) *)
		LDRSH* = 11000F0H; (* LDRSH, pre-indexed, no write-back *)
		STRH* = 10000B0H; (* STRH, pre-indexed, no write-back *)
		LDRSB* = 11000D0H; (* LDRSB, pre-indexed, no write-back *)

		(* Op-Codes Block Data Transfer (BDT) *)
		LDMIA* = 89H; STMIA* = 88H; STMDB* = 90H;
		
		(* Op-Codes Data Processing: S-Bit is always set (except for MOV and RSBnoflags ) ! *)
		AND* = 1; EOR* = 3; SUB* = 5; RSBnoflags* = 6; RSB* = 7; ADD* = 9; ADC = 11; SBC = 13; RSC = 15; TST* = 17;
		TEQ = 19;
		CMP* = 21; CMN* = 23;  ORR* = 25; MOV* = 26; MOVS* = 27; BIC* = 29; MVN* = 30; MVNS = 31;

		(* Op-Codes Branch Instructions *)
		B* = 10; BL* = 11;		

		(* Op-Codes Multiplication *)
		MUL* = 0; MLA* = 200000H;
		
		(* Op-Codes Long Multiplication *)
		SMULL* = 00C00090H; 
		
		(* Conditions *)
		EQ* = 0; NE* = 1; CS* = 2; CC* = 3;  MI* = 4; PL* = 5; VS* = 6; VC* = 7;
		HI* = 8; LS* = 9; GE* = 10; LT* = 11;  GT* = 12; LE* = 13; AL* = 14; NV* = 15;
		 
		(* Register Numbers *)
		PC* = 15; LR* = 14; SP* = 13; FP* = 12; FirstUniversalReg = 11;

		(* Const Types *)
		Constant = 0; StringAddr = 1; ProcAddr = 2; ExtAddr = 3; 
		
	TYPE
		Const = RECORD
			a : LONGINT;
			type : INTEGER; (* TRUE, if constant is an address *)
			b : INTEGER; (* index into unknownProcTab, if type=ProcAddr *)
		END;
													
	VAR	
		pc* : LONGINT;
		moduleBody* : LONGINT; (** entry point for module body *)
		level*: INTEGER;
		typchk* : BOOLEAN;
		wasderef*: OBT.Object;
		RegSet: SET;
		nofrecs: INTEGER;
		extcallfixlist: LONGINT; (* Calls of imported procs  *)
		extaddrfixlist: LONGINT; (* Addresses of imported procs/vars/type-descs *)
		fixlist : LONGINT; (* module local fixups *)
		strfixlist : LONGINT; (* fixups of string addr consts *)
		recTypesOffset : LONGINT;
		recTab: ARRAY MaxRecs OF OBT.Struct;
		code:  ARRAY CodeLength OF LONGINT;
		preferredReg : LONGINT;
			
		(* for constant handling *)
		constCnt : LONGINT;
		constBlock : ARRAY ConstLength OF Const;
		constRefChain : LONGINT;

		constDist : LONGINT; (* maximal distance between const and its usage *)
		allowConstFlushing* : LONGINT; (* >=0 -> const flushing allowed *)
		flushing : BOOLEAN;

		(* for string const handling *)
		strConstBlock : ARRAY StrConstLength OF CHAR;
		strConstBlockCnt : LONGINT;
	
		(* for Fixups of forwarded proc addresses *)
		unknownProcTab : ARRAY MaxUnknownProcs OF OBT.Object;
		unknownProcCnt : INTEGER;

		(* statistics *)
		constJumpOvers* : LONGINT; (* no. of jumps over constants (words) *)
		minConstBlock* : LONGINT; (* min. size of a const block (words) *)
		maxConstBlock* : LONGINT; (* max. size of a const block (words) *)
		nofConstBlocks* : LONGINT; (* Nr. of const blocks *)
		totConsts* : LONGINT; (* tot. nr. of consts (words) *)

				
		(* debug *)
		trapPos*  : LONGINT;	(*position where a trap happened*)

				
	PROCEDURE ^FlushConsts*;
	PROCEDURE ^PutSDT*(op, dest, base, offset : LONGINT);
	PROCEDURE ^PutDP1*(op, dest, reg1, const : LONGINT); (* Data Processing with shifted constant as 2nd operand *)
	PROCEDURE ^PutB*(op,target : LONGINT);
	PROCEDURE ^fixup*(loc: LONGINT);  (*enter pc at loc*)

	(* -------------------------------------------------------------------- *)
	
	PROCEDURE IncPC;
	BEGIN
		INC(pc);
		IF pc >= trapPos THEN OBS.Mark(355); trapPos := MAX(LONGINT) END
	END IncPC;
	
	(* -------------------------------------------------------------------- *)
	
	PROCEDURE AddAddrFixup(loc : LONGINT; VAR fixlist : LONGINT); (** Adds loc to the absolute fixup list fixlist *)
	BEGIN
		code[loc]:=code[loc] MOD 20000H + fixlist*20000H; fixlist:=loc; 
	END AddAddrFixup;
	
	PROCEDURE AddAbsFixup*(loc : LONGINT);
	BEGIN
		AddAddrFixup(loc,fixlist);
	END AddAbsFixup;

	(* ----------------- Private Procedures for Constant Handling ------------------- *)
	PROCEDURE EnterConst(c : LONGINT) : LONGINT;
	(* Enters a constant and returns the offset within the constant block *)
	VAR i : LONGINT;
	BEGIN
		(* Check if const is already entered *)
		i:=0;
		WHILE (i<constCnt) & ((constBlock[i].a#c) OR (constBlock[i].type#Constant)) DO INC(i) END;
		IF i<constCnt THEN
			(* Constant already in memory *)
			RETURN i*4;
		END;
		
		(* Constant not in memory. Enter it. Constant block WILL NEVER overflow because we flush it before that happens! *)
		constBlock[constCnt].a:=c; constBlock[constCnt].type:=Constant;
		IF constCnt>constDist THEN constDist:=constCnt END;	
		INC(constCnt);
		RETURN (constCnt-1)*4;
	END EnterConst;
	
	PROCEDURE CheckConstReachability;
	VAR L : LONGINT;
	BEGIN
		IF allowConstFlushing<0 THEN RETURN END;
		IF constDist>=MaxConstDist THEN
			INC(constJumpOvers); (* statistics *)
			DEC(allowConstFlushing);
			L:=pc;
			PutB(B,0);
			FlushConsts;
			fixup(L);
			INC(allowConstFlushing)
		END
	END CheckConstReachability;	
		
	PROCEDURE EnterExtAddress(mno, eno : LONGINT) : LONGINT;
	(* Enters a address and returns the offset within the constant block *)
	VAR i : INTEGER; exta : LONGINT;
	BEGIN	
		exta := mno * 100H + eno;
		
		(* Check if const is already entered *)
		i:=0;
		WHILE (i<constCnt) & ~((constBlock[i].a=exta) & (constBlock[i].type=ExtAddr)) DO INC(i) END;
		IF i<constCnt THEN
			(* Constant already in memory *)
			RETURN i*4;
		END;
	
		(* Not in memory. Enter it *)
		constBlock[constCnt].a:=exta; constBlock[constCnt].type:=ExtAddr;
		IF constCnt>constDist THEN constDist:=constCnt END;	
		INC(constCnt);
		RETURN (constCnt-1)*4;
	END EnterExtAddress;
		
	PROCEDURE EnterUnknownProcAddress(proc : OBT.Object) : LONGINT;
	(* Enters a address and returns the offset within the constant block *)
	VAR i : INTEGER;
	BEGIN
		(* Find procedure in unknownProcTab *)
		i:=0;
		WHILE (i<unknownProcCnt) &  (unknownProcTab[i]#proc) DO INC(i) END;
		IF i=unknownProcCnt THEN (* not found *)
			IF unknownProcCnt=MaxUnknownProcs THEN OBS.Mark(252); unknownProcCnt:=0; i:=0 END;
			unknownProcTab[unknownProcCnt]:=proc;
			INC(unknownProcCnt)
		END;
		
		(* Enter Procedure Address *)
		constBlock[constCnt].a:=0; constBlock[constCnt].b:=i; constBlock[constCnt].type:=ProcAddr;
		IF constCnt>constDist THEN constDist:=constCnt END;	
		INC(constCnt);
		RETURN (constCnt-1)*4;
	END EnterUnknownProcAddress;
		
	PROCEDURE EnterStringConstAddr(a : LONGINT) : LONGINT;
	BEGIN
		constBlock[constCnt].a:=a; constBlock[constCnt].type:=StringAddr;
		IF constCnt>constDist THEN constDist:=constCnt END;
		INC(constCnt); 
		RETURN (constCnt-1)*4;
	END EnterStringConstAddr;
	
	(* ----------------- Public Procedures for Constant Handling ------------------- *)
	
	PROCEDURE EnterStringConst*(VAR x : OBT.Item);
	(* Enters a string constant and returns the offset within the constant block *)
	VAR l, i  : LONGINT;
	BEGIN
		l:=0; WHILE x.obj.ext.str[l]#0X DO INC(l) END; INC(l);
		x.obj.a0:=strConstBlockCnt;  x.a:=x.obj.a0;
		x.b:=l;
		IF strConstBlockCnt+l >= StrConstLength THEN 
			OBS.Mark(230)
		ELSE
			(*String eintragen *)
			FOR i:=0 TO l-1 DO strConstBlock[strConstBlockCnt+i]:=x.obj.ext.str[i] END;
			INC(strConstBlockCnt,(l+3) DIV 4 * 4 );
		END
	END EnterStringConst;
		
	PROCEDURE FlushConsts*;
	(* Writes the constants and fixes all offsets *)
	VAR tmp, tmp2, next, destreg, ofs, cnt : LONGINT;
	BEGIN
		flushing:=TRUE; 
		constDist:=-1; (* reset here so that we dont get recursive calls (because of PutSDT later on), 
								    if we are already in the "safety range" *)
								    
		(* Fix all references to a constant *)
		tmp:=constRefChain;
		IF tmp#-1 THEN INC(nofConstBlocks) END;
		cnt:=0;
		WHILE tmp#-1 DO
			INC(cnt);
			(* Extract dest reg, offset and next position that needs fixup *)
			next:=tmp-SYSTEM.LSH(code[tmp],-16); 
			
			destreg:=SYSTEM.LSH(code[tmp],-12) MOD 10H; ofs:=code[tmp] MOD 1000H;
			
			(* Adjust ofs and generate an LDR *)
			tmp2:=pc; pc:=tmp;
			PutSDT(LDR,destreg,PC, (tmp2*4+ofs)); 
			pc:=tmp2;
			
			tmp:=next;
		END;
		
		(* Emit all constants *)
		FOR tmp:=0 TO constCnt-1 DO
			code[pc]:=constBlock[tmp].a;
			CASE constBlock[tmp].type OF
				Constant: (* nothing to do *)
				|ProcAddr: AddAddrFixup(pc,unknownProcTab[constBlock[tmp].b].a2); 
				|StringAddr: AddAddrFixup(pc,strfixlist); 
				|ExtAddr: AddAddrFixup(pc,extaddrfixlist)
			END;
			IncPC
		END;
		
		constCnt:=0;
		constRefChain:=-1;
		constDist:=-1;
		flushing:=FALSE;
		
		IF cnt#0 THEN
			IF cnt<minConstBlock THEN minConstBlock:=cnt END;
			IF cnt>maxConstBlock THEN maxConstBlock:=cnt END;
			INC(totConsts,cnt)
		END
	END FlushConsts;
	
	PROCEDURE DecomposeConst*(const : LONGINT; VAR imm, rot : LONGINT) : BOOLEAN;
	(* Tries to decompose a constant into a 8bit unsigned immediate and a rotation, so that imm>>(2*rot)=const *)
	(* returns TRUE if such a combination of (imm,rot) exists *)
	BEGIN
		imm:=const; rot:=0;
		WHILE (rot<15) & ((imm<0) OR (imm>255)) DO imm:=SYSTEM.ROT(imm,2); INC(rot) END;
		RETURN (imm>=0) & (imm<=255)
	END DecomposeConst;
		
	PROCEDURE LoadConst*(reg, const : LONGINT);
	VAR ofs, imm, rot : LONGINT;
	BEGIN
		IF DecomposeConst(const,imm,rot) THEN PutDP1(MOV,reg,0,const);
		ELSE
			ofs:=EnterConst(const); 
			code[pc]:=(pc-constRefChain)*10000H + reg*1000H + ofs;
			IF constDist>=0 THEN INC(constDist) END;
			constRefChain:=pc; IncPC;
		END
	END LoadConst;
	
	PROCEDURE LoadStringConst*(reg, addr : LONGINT);
	VAR ofs : LONGINT;
	BEGIN
		ofs:=EnterStringConstAddr(addr);
		code[pc]:=(pc-constRefChain)*10000H + reg*1000H + ofs;
		IF constDist>=0 THEN INC(constDist) END;
		constRefChain:=pc; IncPC;
	END LoadStringConst;

	PROCEDURE LoadUnknownProcAddr*(reg : LONGINT; proc : OBT.Object);
	VAR ofs : LONGINT;
	BEGIN
		ofs:=EnterUnknownProcAddress(proc);
		code[pc]:=(pc-constRefChain)*10000H + reg*1000H + ofs; 
		IF constDist>=0 THEN INC(constDist) END;
		constRefChain:=pc; IncPC;
	END LoadUnknownProcAddr;
	
	PROCEDURE LoadExtAddr*(reg, mno, eno : LONGINT);
	VAR ofs : LONGINT;
	BEGIN
		ofs:=EnterExtAddress(mno,eno);
		ASSERT(eno>=0);
		code[pc]:=(pc-constRefChain)*10000H + reg*1000H + ofs;
		IF constDist>=0 THEN INC(constDist) END;
		constRefChain:=pc; IncPC;
	END LoadExtAddr;
	
	(* -------------------------------------------------------------------- *)	
	PROCEDURE SetRecTypesOffset*(o : LONGINT);
	BEGIN recTypesOffset:=o;
	END SetRecTypesOffset;
	
	PROCEDURE GetReg*(VAR r: LONGINT);
	VAR i: INTEGER;
	BEGIN 
		IF (preferredReg#-1) & ~(preferredReg IN RegSet) THEN
			r:=preferredReg; preferredReg:=-1; INCL(RegSet,r); RETURN
		END;
		i := FirstUniversalReg; 
		LOOP
			IF ~(i IN RegSet) THEN r := i; INCL(RegSet,i); EXIT END ;
			IF i < 0 THEN r := 0; OBS.Mark(215); (* Out Of Registers *) EXIT ELSE DEC(i) END ;
		END
	END GetReg;
	
	PROCEDURE GetRegNoPref*(VAR r: LONGINT);
	VAR i: INTEGER; oldpreferred : LONGINT;
	BEGIN 
		oldpreferred:=preferredReg; preferredReg:=-1; GetReg(r); preferredReg:=oldpreferred;
	END GetRegNoPref;

	PROCEDURE UsedRegisters*(): SET;
	BEGIN RETURN RegSet
	END UsedRegisters;

	PROCEDURE FreeReg*(r : LONGINT);
	BEGIN 
		EXCL(RegSet,r) 
	END FreeReg;
	
	PROCEDURE SetPreferredReg*(r : LONGINT);
	BEGIN
		preferredReg:=r
	END SetPreferredReg;
			
	PROCEDURE FreeRegs*(keep: SET);
	BEGIN RegSet := keep; 
	END FreeRegs;

	PROCEDURE Release*(VAR x: OBT.Item);
	BEGIN
		IF ~(x.mode IN {OC.Const, OC.CC}) THEN 
			FreeReg(x.r); IF (x.mode = OC.Var1) OR (x.mode = OC.RegX) THEN FreeReg(x.a) END
		END
	END Release;

	PROCEDURE CheckCodeSize*;
	BEGIN
		IF pc+constCnt > CodeLength - 64 (* safety range *) THEN OBS.Mark(210); pc := 0 END
	END CheckCodeSize;
	
	PROCEDURE PutSDT1*(op, dest, base, rm, shift : LONGINT); (* SDT with Reg as Offset, rm is always added *)
	BEGIN
		ASSERT( (dest>=0) & (dest<=15) & (base>=0) & (base<=15) & (rm>=0) & (rm<=15) );
		ASSERT( (base#rm)  ); (* not really wrong, but the compiler SHOULD NOT generate such code *) 
		CheckConstReachability;
		code[pc]:=(((op*10H+base)*10H+dest)*100H+shift)*10H+rm + C25 + C23 - 20000000H; IncPC;
		IF constDist>=0 THEN INC(constDist) END;
	END PutSDT1;
	
	PROCEDURE PutSDT*(op, dest, base, offset : LONGINT); (* Single Data Transfer: op = LDR/STR *)
	VAR r: LONGINT; up : BOOLEAN;
	BEGIN
		ASSERT( (dest>=0) & (dest<=15) & (base>=0) & (base<=15));
		CheckConstReachability;
		IF (base = PC)  & (offset # 0) THEN offset := offset - pc*4 - 8 END ;
		IF ABS(offset)>=4096 THEN 
			IF flushing THEN HALT(100) END;
			DEC(allowConstFlushing);
			IF base = PC THEN DEC(offset,4) END;
			GetReg(r); LoadConst(r,offset);
			PutSDT1(op,dest,base,r,0);
			FreeReg(r);
			INC(allowConstFlushing);
		ELSE
			up:=offset>=0;
			IF offset < 0 THEN offset := -offset END;
			IF up THEN INC(offset, C23) (* Set direction up = add offset to base*) END;
			code[pc] := ((op*10H + base)*10H + dest)*1000H + offset - 20000000H; IncPC;
			IF constDist>=0 THEN INC(constDist) END;
		END
	END PutSDT;
	
	PROCEDURE PutHDT1*(op, dest, base, rm : LONGINT); (* HDT with Reg as Offset, rm is always added *)
	BEGIN
		ASSERT ( (dest>=0) & (dest<=15) & (base>=0) & (base<=15) & (rm>=0) & (rm<=15) );
		ASSERT( (base#rm) ); (* not really wrong, but the compiler SHOULD NOT generate such code *)
		CheckConstReachability;
		code[pc]:= op + base*10000H + dest*1000H + rm + C23 - 20000000H; IncPC;
		IF constDist>=0 THEN INC(constDist) END;
	END PutHDT1;
	
	PROCEDURE PutHDT*(op, dest, base, offset : LONGINT); (* Halfword Data Transfer: LDRSx/STRSx *)
	VAR r: LONGINT; up : BOOLEAN;
	BEGIN
		ASSERT( (dest>=0) & (dest<=15) & (base>=0) & (base<=15));
		CheckConstReachability;
		IF (base = PC)  & (offset # 0) THEN offset := offset - pc*4 - 8 END ;
		IF ABS(offset)>=256 THEN
			DEC(allowConstFlushing);
			IF base = PC THEN DEC(offset,4) END;
			GetReg(r); LoadConst(r,offset);
			PutHDT1(op,dest,base,r);
			FreeReg(r);
			INC(allowConstFlushing);
		ELSE
			up:=offset>=0;
			IF offset < 0 THEN offset := -offset END;
			INC(op,C22);
			IF up THEN INC(op, C23) (* Set direction up = add offset to base*) END;
			offset:=(offset MOD 16) + (offset DIV 16 * 256);
			code[pc] := op + base*10000H + dest*1000H + offset - 20000000H; IncPC;
			IF constDist>=0 THEN INC(constDist) END;
		END
	END PutHDT;

	PROCEDURE PutBDT*(op, base : LONGINT; regs : SET; writeback : BOOLEAN);
	BEGIN
		ASSERT( (base>=0) & (base<=15) );
		CheckConstReachability;
		code[pc]:=(op*10H+base)*10000H+SYSTEM.VAL(LONGINT,regs) - 20000000H; 
		IF writeback THEN INC(code[pc],200000H) END;
		IncPC;
		IF constDist>=0 THEN INC(constDist) END;
	END PutBDT;
	
	PROCEDURE PutDP*(op, dest, reg1, reg2, shift : LONGINT); (* Data Processing with Register as 2nd operand *)
	BEGIN
		ASSERT( (reg1>=0) & (reg1<=15) & (reg2>=0) & (reg2<=15));
		CheckConstReachability;
		code[pc]:=(((op*10H+reg1)*10H+dest)*100H+shift)*10H+reg2 - 20000000H; IncPC;
		IF constDist>=0 THEN INC(constDist) END;
	END PutDP;
	
	PROCEDURE PutDP1*(op, dest, reg1, const : LONGINT); (* Data Processing with constant as 2nd operand *)
	VAR imm, r : LONGINT;
	BEGIN
		ASSERT( (reg1>=0) & (reg1<=15));
		IF (op=ADD) & (const<0) THEN op:=SUB; const:=-const 
		ELSIF (op=SUB) & (const<0) THEN op:=ADD; const:=-const
		END;
		CheckConstReachability;
		IF DecomposeConst(const,imm,r) THEN 
			code[pc]:=(((op*10H+reg1)*10H+dest)*10H+r)*100H+imm+C25 - 20000000H; IncPC;
			IF constDist>=0 THEN INC(constDist) END;
		ELSE 
			DEC(allowConstFlushing);
			GetReg(r);
			IF reg1 = PC THEN 
				IF op=ADD THEN DEC(const,4)
				ELSIF op=SUB THEN INC(const,4)
				ELSE HALT(211)
				END
			END;
			LoadConst(r,const);
			PutDP(op,dest,reg1,r,0);
			FreeReg(r);
			INC(allowConstFlushing);
		END; 
	END PutDP1;

	PROCEDURE PutB*(op, target : LONGINT); (** Branch instruction. Target is an absolute word address *)
	BEGIN
		CheckConstReachability;
		target:=(target-pc-2) MOD C24;
		code[pc]:=op*1000000H+target - 20000000H; IncPC; 
		IF constDist>=0 THEN INC(constDist) END;
	END PutB;
	
	PROCEDURE PutBabs*(op, target : LONGINT); (** Branch instruction. Target is an absolute word address *)
	BEGIN
		CheckConstReachability;
		code[pc]:=op*C24+(target MOD C24)- 20000000H; IncPC; 
		IF constDist>=0 THEN INC(constDist) END;
	END PutBabs;

	PROCEDURE PutBext*(mno, pno : LONGINT); (** Branch to imported procedure *)
	BEGIN
		ASSERT((mno >= 0) & (mno < OC.MaxImps));
		ASSERT((pno >= 0) & (pno < 256));
		CheckConstReachability;
		code[pc]:=extcallfixlist*20000H+mno*100H+pno (*- 20000000H*); extcallfixlist:=pc; IncPC;
		(*code[pc]:=extcallfixlist*2000H+mno*100H+pno - 20000000H; extcallfixlist:=pc; INC(pc);*)
		IF constDist>=0 THEN INC(constDist) END
	END PutBext;
	
	PROCEDURE PutMUL*(op, dest, r1, r2, add : LONGINT); (** Multiplication *)
	BEGIN
		ASSERT(dest#r1); 
		ASSERT(~(PC IN {dest,r1,r2})); 
		CheckConstReachability;
		code[pc]:=op+100000H+((dest*10H+add)*10H+r2)*100H+90H+r1- 20000000H; IncPC; 
		IF constDist>=0 THEN INC(constDist) END;		
	END PutMUL;	
	
	PROCEDURE PutMULL*(op, rhi,rlo, r1, r2 : LONGINT); (** Long Multiplication *)
	BEGIN
		ASSERT((rlo#r1) & (rhi#r1) & (rlo#rhi)); 
		ASSERT(~(PC IN {rhi,rlo,r1,r2})); 
		CheckConstReachability;
		code[pc]:=op+((rhi*10H+rlo)*10H+r2)*100H+r1- 20000000H; IncPC; 
		IF constDist>=0 THEN INC(constDist) END;		
	END PutMULL;	
	
	PROCEDURE SetCondition*(pc,cc : LONGINT); (** Sets condition of code[pc] to cc *)
	BEGIN
		code[pc]:=SYSTEM.VAL(LONGINT,SYSTEM.VAL(SET,code[pc]) * {0..28} + SYSTEM.VAL(SET,SYSTEM.LSH(cc,28)));
	END SetCondition;

	PROCEDURE PutSWI*(cond, nr : LONGINT);
	BEGIN
		CheckConstReachability;
		code[pc]:=0F000000H+(nr MOD C24); SetCondition(pc,cond); IncPC;
		IF constDist>=0 THEN INC(constDist) END;
	END PutSWI;

	PROCEDURE PutWord*(word : LONGINT);
	BEGIN
		CheckConstReachability; code[pc]:=word; IncPC; IF constDist>=0 THEN INC(constDist) END;
	END PutWord;
	
	PROCEDURE PutWordAt*(loc, word : LONGINT);
	BEGIN
		code[loc]:=word;
	END PutWordAt;

	PROCEDURE InvertedCC*(cc : LONGINT) : LONGINT; (*inverted sense of condition code*)
	BEGIN
		IF ODD(cc) THEN RETURN cc-1 ELSE RETURN cc+1 END
	END InvertedCC;

	PROCEDURE RegisterRecType*(typ: OBT.Struct);
	BEGIN
		IF typ.extlev > MaxExts THEN OBS.Mark(233)
		ELSIF nofrecs < MaxRecs THEN
			recTab[nofrecs] := typ; INC(nofrecs); 
			IF level > 0 THEN INC(recTypesOffset,4); typ.adr:=-recTypesOffset; END
		ELSE OBS.Mark(223)
		END
	END RegisterRecType;

	PROCEDURE SaveRegisters*(VAR gR: SET; VAR x: OBT.Item);
		VAR t: SET;
	BEGIN
		t := RegSet;
		IF x.mode IN {OC.Reg, OC.Var, OC.RegX, OC.Var1, OC.Par} THEN EXCL(RegSet, x.r) END ;
		IF x.mode IN {OC.RegX} THEN EXCL(RegSet, x.a) END ;
		gR := RegSet; 
		IF RegSet # {} THEN PutBDT(STMDB,SP,RegSet,TRUE) END;
		RegSet := t - RegSet;
	END SaveRegisters;
	
	PROCEDURE RestoreRegisters*(gR: SET; VAR x: OBT.Item);
	VAR r : LONGINT; 
	BEGIN
		RegSet := gR; 
		(*set result mode*)
		x.mode := OC.Reg; x.r:=0; INCL(RegSet,0);
		IF x.typ.form = OC.LReal THEN 
			x.mode := OC.RegX; x.a:=1; INCL(RegSet,1);
			IF 1 IN gR THEN GetReg(r); PutDP(MOV,r,0,x.a,0); x.a := r END; 
		END;
		IF 0 IN gR THEN GetReg(r); PutDP(MOV,r,0,x.r,0); x.r := r END;  		
		IF gR # {} THEN PutBDT(LDMIA,SP,gR,TRUE) END
	END RestoreRegisters;

	PROCEDURE fixup*(loc: LONGINT);  (*enter pc at loc*)
	BEGIN
 		code[loc] := code[loc] DIV C24 * C24 + ((pc - loc - 2) MOD C24)
	END fixup;

	PROCEDURE FixLink*(L: LONGINT);
		VAR L1: LONGINT;
	BEGIN 
		WHILE L # 0 DO
			L1 := code[L] MOD C24;
			fixup(L); L := L1
		END
	END FixLink;

	PROCEDURE FixAddr*(L, addr : LONGINT);
	VAR L1 : LONGINT;
	BEGIN
		WHILE L # 0 DO
			L1 := code[L] DIV 20000H MOD 8000H; code[L]:=code[L] MOD 20000H + addr; AddAbsFixup(L); L := L1
		END
	END FixAddr;
	
	PROCEDURE FixupWith*(L, val: LONGINT);
	BEGIN 
		IF ABS(val) >= C24 THEN OBS.Mark(1002) END ;
		code[L] := (code[L] DIV C24) * C24 + (val MOD C24)
	END FixupWith;
	
	PROCEDURE FixLinkWith*(L, val: LONGINT);
		VAR L1: LONGINT;
	BEGIN 
		WHILE L # 0 DO
			L1 := code[L] MOD C24;
			FixupWith(L, val -L -2); L := L1
		END
	END FixLinkWith;

	PROCEDURE MergedLinks*(L0, L1: LONGINT): LONGINT;
	VAR L2, L3: LONGINT;
	BEGIN (*merge chains of the two operands of AND and OR *)
		IF L0 # 0 THEN L2 := L0;
			LOOP
				L3 := code[L2] MOD C24;
				IF L3 = 0 THEN EXIT END ;
				L2 := L3
			END ;
			code[L2] := (code[L2] DIV C24) * C24 + L1;
			RETURN L0
		ELSE RETURN L1
		END
	END MergedLinks;

	PROCEDURE Init*;
	BEGIN 
		pc := 0; level := 0; nofrecs := 0; RegSet := {};   
		strConstBlockCnt:=0; unknownProcCnt:=0; strfixlist:=0; fixlist:=0;
		constCnt := 0; constRefChain := -1; allowConstFlushing := 0; constDist := -1;
		extcallfixlist:=0; extaddrfixlist:=0; preferredReg:=-1; flushing:=FALSE;
		constJumpOvers:=0; 
		minConstBlock := MAX(LONGINT); 
		maxConstBlock := MIN(LONGINT); 
		nofConstBlocks:=0;
		totConsts:=0;
	END Init;

	PROCEDURE FindPtrs(typ: OBT.Struct; badr: LONGINT; VAR ptab: ARRAY OF LONGINT; VAR n: LONGINT);
		(*find all pointers in typ and enter their offsets (+badr) in ptab*)
	VAR fld: OBT.Object; btyp: OBT.Struct; i, m, s: LONGINT;
	BEGIN
		IF typ.form IN {OC.Pointer, OC.SysPtr} THEN
			IF n < MaxPtrs THEN ptab[n] := badr; INC(n) ELSE OBS.Mark(222) END
		ELSIF typ.form = OC.Record THEN
			btyp := typ.BaseTyp;
			IF btyp # NIL THEN FindPtrs(btyp, badr, ptab, n) END ;
			fld := typ.link;
			WHILE fld # NIL DO
				IF fld.name # "" THEN FindPtrs(fld.typ, fld.a0 + badr, ptab, n)
				ELSIF n < MaxPtrs THEN ptab[n] := fld.a0 + badr; INC(n)
				ELSE OBS.Mark(222)
				END ;
				fld := fld.next
			END
		ELSIF typ.form = OC.Array THEN
			btyp := typ.BaseTyp; m := typ.size DIV btyp.size;
			WHILE btyp.form = OC.Array DO
				m := btyp.size DIV btyp.BaseTyp.size * m; btyp := btyp.BaseTyp
			END ;
			IF btyp.form IN {OC.Pointer, OC.SysPtr, OC.Record} THEN
				i := 0; s := btyp.size;
				WHILE i < m DO FindPtrs(btyp, i*s + badr, ptab, n); INC(i) END
			END
		END
	END FindPtrs;


	PROCEDURE OutCode*(VAR name, progid: ARRAY OF CHAR; key: LONGINT);
		VAR
			f, i, m, np : LONGINT;
			tmp : LONGINT;
			refpos: LONGINT;
			nofcom, nofptrs: LONGINT;
			obj:    OBT.Object;
			typ:    OBT.Struct;
			ObjFile:   Files.File;
			out:    Files.Rider;
			PtrTab: ARRAY MaxPtrs OF LONGINT;
			ComTab: ARRAY MaxComs OF OBT.Object;

		PROCEDURE Collect; (*collect commands, and pointers*)
		VAR obj, par: OBT.Object; 
		BEGIN 
			obj := OBT.topScope.next;
			WHILE obj # NIL DO
				IF obj.mode = OC.LProc THEN
					IF obj.a0 = -1 THEN OBS.Mark(129)
					ELSIF obj.marked & (obj.typ.form = OC.NoTyp) THEN
						par := obj.dsc;
						IF ~OBT.IsParam(par) THEN (*command*)
							IF nofcom < MaxComs THEN ComTab[nofcom] := obj; INC(nofcom)
							ELSE OBS.Mark(232); nofcom := 0
							END
						END
					END
				ELSIF obj.mode = OC.Var THEN FindPtrs(obj.typ, obj.a0, PtrTab, nofptrs)
				END ;
				obj := obj.next
			END
		END Collect;

		PROCEDURE OutBaseTypes(typ: OBT.Struct);
		BEGIN
			IF typ.BaseTyp # NIL THEN
				OutBaseTypes(typ.BaseTyp);
				IF typ.BaseTyp.adr<0 THEN Files.WriteLInt(out,typ.BaseTyp.adr)
				ELSE Files.WriteLInt(out,typ.BaseTyp.mno*100H+typ.BaseTyp.adr)
				END
			END
		END OutBaseTypes;

		PROCEDURE OutRefBlk(first: OBT.Object; pc: LONGINT; name: ARRAY OF CHAR);
			VAR obj: OBT.Object; offset : LONGINT; dim : LONGINT; mode : INTEGER;
		BEGIN 
			obj := first;
			WHILE obj # NIL DO
				IF obj.mode = OC.LProc THEN OutRefBlk(obj.dsc, obj.a0, obj.name) END ;
				obj := obj.next
			END ;
			Files.Write(out, 0F8X); Files.WriteNum(out, pc*4); Files.WriteString(out, name);
			obj := first;
			WHILE obj # NIL DO
				mode := obj.mode;
				IF (mode = OC.Var) OR (mode = OC.Par) THEN
					f := obj.typ.form;
					IF f IN {OC.Array, OC.DynArr} THEN
						offset:=128; 
						IF f = OC.Array THEN dim:=obj.typ.size DIV obj.typ.BaseTyp.size
						ELSE dim:=0; mode := OC.Par (* open arrays always indirect *)
						END;
						f := obj.typ.BaseTyp.form;
					ELSE
						offset:=0
					END;
					IF (f IN {OC.Byte .. OC.Set, OC.Pointer}) THEN
						Files.Write(out, CHR(mode)); Files.Write(out, CHR(f+offset));
						IF offset#0 THEN Files.WriteNum(out,dim) END;
						Files.WriteNum(out, obj.a0); Files.WriteString(out, obj.name)
					END
				END ;
				obj:= obj.next
			END
		END OutRefBlk;

	BEGIN
		ObjFile := Files.New(name);
		IF ObjFile # NIL THEN
			Files.Set(out, ObjFile, 0);
			nofcom := 0; nofptrs := 0;
			(* WHILE nofptrs < nofrecs DO PtrTab[nofptrs] := recTab[nofptrs].adr; INC(nofptrs) END ; *)
			Collect; 
		(*header block*)
			Files.Write(out, ObjMark); Files.Write(out, "0"); 
			Files.WriteLInt(out, refpos); (* will be fixed at the end of OutCode *)
			Files.WriteLInt(out, moduleBody*4); (* not necessary, but we don't want to scan RefBlks to get the entry point! *)
			Files.WriteInt(out, OBT.nofGmod); 
			Files.WriteInt(out, OBT.entno);
			Files.WriteInt(out, SHORT(nofptrs)); 
			Files.WriteInt(out, SHORT(nofcom));
			Files.WriteLInt(out, strConstBlockCnt); 
			Files.WriteLInt(out, recTypesOffset); (* data size *)
			Files.WriteLInt(out, pc*4);  (* code size *)
			Files.WriteInt(out, nofrecs);
			Files.WriteLInt(out, key); 
			Files.WriteString(out, progid);
		(*import block*)
			Files.Write(out,085X);
			i := 0;
			WHILE i < OBT.nofGmod DO
				obj := OBT.GlbMod[i];
				Files.WriteLInt(out, obj.a1);  (* key *)
				Files.WriteString(out, obj.name); 
				INC(i)
			END ;
		(*entry block*)
			Files.Write(out,082X);
			Files.WriteBytes(out, OBT.entry, 4*OBT.entno);  
		(*pointer block*) 
			Files.Write(out,084X);
			i := 0; WHILE i < nofptrs DO Files.WriteLInt(out, PtrTab[i]); INC(i) END ;
		(*command block*) 
			Files.Write(out,083X);
			i := 0;
			WHILE i < nofcom DO
				obj := ComTab[i]; Files.WriteString(out, obj.name);
				Files.WriteLInt(out, obj.a0*4); INC(i) (* proc addrs are treated as word-addrs in sym-files and the compiler, so we multiply by 4 *)
			END ;
		(*code block*)
			Files.Write(out,088X);
			WHILE strfixlist#0 DO (* fixup string addr locations *)
				tmp:=code[strfixlist] DIV 20000H MOD 8000H; code[strfixlist]:=code[strfixlist] MOD 20000H+pc*4; AddAbsFixup(strfixlist);
				strfixlist:=tmp
			END;
			Files.WriteBytes(out, code, pc*4);
		(*string constants block*) 
			Files.Write(out,087X);
			Files.WriteBytes(out, strConstBlock,strConstBlockCnt);
		(*fixups*) 
			Files.Write(out,086X);
			Files.WriteLInt(out, extcallfixlist*4); (* Now byte address! *)
			Files.WriteLInt(out, extaddrfixlist*4); (* Now byte address! *)
			Files.WriteLInt(out, fixlist*4); (* Now byte address! *)
		(*typdesc block*) 
			Files.Write(out,089X);
			i := 0;
			WHILE i < nofrecs DO
				typ := recTab[i]; recTab[i] := NIL; INC(i);
				np := 0; 
				FindPtrs(typ, 0, PtrTab, np); 
				Files.WriteLInt(out, typ.adr);   						  (* addr of tag (tag=ptr to Type Desc) *)
				Files.WriteInt(out,SHORT(np));						(* #pointers *)
				Files.WriteLInt(out,typ.size);  							(* Record size *)
				IF typ.strobj#NIL THEN Files.WriteString(out,typ.strobj.name)  (* Type name *)
				ELSE Files.WriteString(out,"");
				END;
				Files.Write(out, CHR(typ.extlev));					(* Nr of BaseTypes *)
				OutBaseTypes(typ);
				m := 0;
				WHILE m < np DO Files.WriteLInt(out, PtrTab[m]); INC(m) END
			END ;
		(*ref block*)
			refpos := Files.Pos(out);
			Files.Write(out,08BX);
			OutRefBlk(OBT.topScope.next, moduleBody, "$$");
			Files.Set(out, ObjFile, 2); Files.WriteLInt(out, refpos);
  	  	IF ~OBS.scanerr THEN Files.Register(ObjFile) END
		ELSE OBS.Mark(153)
		END
	END OutCode;

BEGIN
	NEW(wasderef)
END OBC.
