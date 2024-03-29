�TextDocs.NewDoc     ����   Oberon10.Scn.Fnt  f       �   �    �  Oberon10b.Scn.Fnt  @    �    O    �   c    �    l    �   <    	       �    f    r   ?    1    f    �    e    �       J        B   ,B  (* OBERON System 3, Release 2.3.

Copyright 1998 Institute of Computer Systems of ETH Z�rich, ETH Center, CH-8092 Z�rich, 
e-mail: oberon@inf.ethz.ch.

This module may be used under the conditions of the general Oberon 
System 3 license contract.  The full text can be downloaded from

	"ftp://ftp.inf.ethz.ch/pub/software/Oberon/System3/license.txt;A"

Under the license terms stated it is in particular (a) prohibited to modify
the interface of this module in any way that disagrees with the style
or content of the system and (b) requested to provide all conversions
of the source code to another platform with the name OBERON. *)

MODULE CS8900;	(** non-portable *)	(* january 7, 1999 as *)

(* CS8900 adapter driver *)


IMPORT SYSTEM, Kernel, NetBase;

CONST
	MaxPkt = 1514;
	BufSize = 8192 DIV 4;	(* receive buffer size *)

	LedPeriod = Kernel.TimeUnit DIV 10;
	
	TracePackets = FALSE;
	
		(* IO-Ports *)
	IoBase = 300H;
	PortPktPgPtr = IoBase+0AH;
	PortPktPgData0 = IoBase+0CH;
	PortPktPgData1 = IoBase+0EH;
		
	PktPgBase = 0D0000H;
	
		(* Misc registers *)
	IoBaseReg = PktPgBase+020H;
	IntNum = PktPgBase+022H;
	MemBase = PktPgBase+02CH; MemBasePort = 02CH;

	IndAddr = PktPgBase+0158H;
		
		(* Control and configuration registers (offsets into PacketPage) *)
	RxCFG = PktPgBase+0102H; RxCFGPort = 0102H;
	RxCTL = PktPgBase+0104H;
	TxCFG = PktPgBase+0106H; TxCFGPort = 0106H;
	TxCMDRead = PktPgBase+0108H;
	BufCFG = PktPgBase+010AH; BufCFGPort = 010AH;
	LineCTL = PktPgBase+0112H; LineCTLPort = 0112H;
	SelfCTL = PktPgBase+0114H; SelfCTLPort = 0114H;
	BusCTL =PktPgBase+0116H; BusCTLPort = 0116H;
	TestCTLPort = 0118H;
	EepromCMDPort = 040H;

		(* Status and event registers *)
	ISQ = PktPgBase+0120H;
	RxEvent = PktPgBase+0124H;
	TxEvent = PktPgBase+0128H;
	BufEvent = PktPgBase+012CH;
	RxMISS = PktPgBase+0130H;
	TxCOL = PktPgBase+0132H;
	LineST = PktPgBase+0134H;
	SelfST = PktPgBase+0136H; SelfSTPort = 0136H;
	BusST = PktPgBase+0138H;		

		(* Receive and Transmit *)
	TxCMD = PktPgBase+0144H;
	TxLength = PktPgBase + 0146H;
	TxBuffer = PktPgBase + 0A00H;
	RxStatus = PktPgBase + 0400H;
	RxLength = PktPgBase +  0402H;
	RxBuffer = PktPgBase + 0404H;
	
		(* misc *)
	CS8900Id = 630EH;
	IRQ = 5;
		
		(* Const for Led0 procedure *)
	NONE = 0;
	YELLOW = 1;
	GREEN = 2;
	RED = 3;

		(* SEQUOIA *)
	SEQINDEX = 24H;
	SEQDATA = 26H;
	
		(* SEQUOIA 1 *)
	FOMPCR = 9; (* Fully-On Mode Power Control Register *)

		(* BILED *)
	LED0R = {5}; 
	LED0G = {6};

TYPE 
	Adr = ARRAY 6 OF CHAR;	
	
	Header = POINTER TO HeaderDesc;
	HeaderDesc = RECORD
		dst, src: Adr;		(* 0, 6 *)
		type: INTEGER; 		(* 12 *)
	END;
	
	Data = POINTER TO DataDesc;
	DataDesc = RECORD
		data: ARRAY 1500 OF SYSTEM.BYTE	(* Note: SendPacket may access data[1500] & data[1501] *)
	END;

	Device = POINTER TO DeviceDesc;
	DeviceDesc = RECORD (NetBase.DeviceDesc)
	END;
	
VAR
	Nrunts, Nouterrors, Nsizeerrors, Nsplits, Nreceived, Nsent, Ndropped, Nlosscrs, Nsqeerrors, 
	Noutofwin, Njabbers, Nunderruns, Nmisses, Ncolls, Nextradatas, Ncrcerrors, Ndribblebits, Nalignerrs : LONGINT;
	
	buf: ARRAY BufSize OF LONGINT;
	bufhead, buftail: INTEGER;
	dbuf: ARRAY MaxPkt+3 OF CHAR;
	dev : Device;
	sendhdr: HeaderDesc;
	txbuf : ARRAY (MaxPkt-14) DIV 2 OF INTEGER; (* buffer for Send to make sure that data is halfword-aligned! *)
	
	transmitting : BOOLEAN;
	xmit, poll: BOOLEAN;
	ledcount: LONGINT;
	ledstate: INTEGER;

PROCEDURE GetInt(adr: LONGINT; VAR i:INTEGER);
BEGIN
	SYSTEM.GET(adr, i);
END GetInt;

PROCEDURE PutInt(adr: LONGINT; i:INTEGER);
BEGIN
	SYSTEM.PUT(adr, i);
END PutInt;

PROCEDURE SequoiaRead(regadr: INTEGER; VAR reg: SET);
VAR ireg: INTEGER; t: LONGINT;
BEGIN
	t := SYSTEM.DISABLEINTERRUPTS();
	PutInt(Kernel.IsaIoBase + SEQINDEX, regadr);
	GetInt(Kernel.IsaIoBase + SEQDATA, ireg);
	reg := SYSTEM.VAL(SET, LONG(ireg)) * {0..15};
	SYSTEM.RESTOREINTERRUPTS(t)
END SequoiaRead;

PROCEDURE SequoiaWrite(regadr: INTEGER; reg : SET);
VAR ireg : INTEGER; t: LONGINT;
BEGIN
	t := SYSTEM.DISABLEINTERRUPTS();
	ireg := SHORT(SYSTEM.VAL(LONGINT, reg * {0..15}));
	PutInt(Kernel.IsaIoBase + SEQINDEX,regadr);
	PutInt(Kernel.IsaIoBase + SEQDATA, ireg);
	SYSTEM.RESTOREINTERRUPTS(t)
END SequoiaWrite;

PROCEDURE Led0(state: INTEGER);
VAR led: SET;
BEGIN
	SequoiaRead(FOMPCR, led);
	CASE state OF
		NONE: led := led + (LED0R+LED0G)
		|YELLOW: led := led - (LED0R+LED0G)
		|GREEN: led := led - LED0G + LED0R
		|RED: led := led - LED0R + LED0G
	END;
	SequoiaWrite(FOMPCR, led);
END Led0;

PROCEDURE ReadIOReg(reg : INTEGER; VAR res : INTEGER);
BEGIN
	SYSTEM.PUT(Kernel.IsaIoBase+PortPktPgPtr, reg);
	SYSTEM.GET(Kernel.IsaIoBase+PortPktPgData0,res);
END ReadIOReg;

PROCEDURE WriteIOReg(reg, val : INTEGER);
BEGIN
	SYSTEM.PUT(Kernel.IsaIoBase+PortPktPgPtr, reg);
	SYSTEM.PUT(Kernel.IsaIoBase+PortPktPgData0,val);
END WriteIOReg;

PROCEDURE CopyFrame(from, to, bytes : LONGINT);
(* all reads and writes to the CS8900 must be done as 16-bit words! *)
CODE
	LDMFD	SP!,{R0,R1,R2}	(* R0 = bytes, R1 = to, R2 = from *)
	ADD	R0,R0,1
	BIC	R0,R0,1	(* Round bytes to a multiple of two *)
loop
	LDRH	R3,[R2],2
	STRH	R3,[R1],2
	SUBS	R0,R0,2
	BNE	loop
	MOV	PC,LR
END CopyFrame;

PROCEDURE WritePacket(code, hdradr: LONGINT;  dataadr, len: LONGINT);
BEGIN
	Kernel.WriteInt(Kernel.GetTimer(), 8);
	IF code = 0 THEN Kernel.WriteString(" snd ") ELSE Kernel.WriteString(" rcv ") END;
	Kernel.WriteMemory(hdradr, 14)
END WritePacket;

(* Send - Send a packet. May hang if a previous send is not yet finished and interrupts are disabled *)

PROCEDURE Send(dev : NetBase.Device; prno: INTEGER; VAR dest: ARRAY OF SYSTEM.BYTE; item : NetBase.Item);
VAR bufaddr : LONGINT;  s, u: SET;  len, t : INTEGER; 
BEGIN
	xmit := TRUE;
	
	len:=item.len;

	IF (len < 0) OR (len > 1500) THEN INC(Nouterrors); RETURN END;	(* packet too big *)
	SYSTEM.MOVE(SYSTEM.ADR(dest[0]), SYSTEM.ADR(sendhdr.dst[0]), 6);	(* set up sendhdr *)
	sendhdr.type := SYSTEM.ROT(prno, 8);	(* sendhdr.src remains our address *)

	(* Wait if there is a transmission underway *)
	WHILE transmitting DO END;

	transmitting:=TRUE;
	(* Copy data to Send-Buffer, if not aligned *)
	bufaddr:=SYSTEM.ADR(item.data[item.ofs]);
	IF ODD(bufaddr) THEN
		SYSTEM.MOVE(SYSTEM.ADR(item.data[item.ofs]),SYSTEM.ADR(txbuf[0]),len);
		bufaddr:=SYSTEM.ADR(txbuf[0]);
	END;
	
	(* Write "Start transmission" cmd and length *)
	SYSTEM.PUT(Kernel.IsaMemBase+TxCMD,SYSTEM.VAL(INTEGER,0C0H)); (* Start transmission after entire frame, pad if <60, add CRC *)
	SYSTEM.PUT(Kernel.IsaMemBase+TxLength,len+14);
	
	(* Wait until "Ready for transmission" *)
	REPEAT
		SYSTEM.GET(Kernel.IsaMemBase+BusST, t)
	UNTIL 8 IN SYSTEM.VAL(SET,LONG(t)); (* LONG is necessary. we get an alignment error if we dont use it! *)
	
	(* Write packet to CS8900 *)
	CopyFrame(SYSTEM.ADR(sendhdr),Kernel.IsaMemBase + TxBuffer, 14);
	CopyFrame(bufaddr,Kernel.IsaMemBase + TxBuffer + 14, len);
	
	INC(Nsent);
	
	IF TracePackets THEN
		WritePacket(0, SYSTEM.ADR(sendhdr), bufaddr, len)
	END
END Send;

(* Avail - Return TRUE iff a packet is available *)

PROCEDURE Avail(dev : NetBase.Device): BOOLEAN;
BEGIN
	poll := TRUE;
	RETURN bufhead # buftail
END Avail;

(* Receive - Remove a packet from the input buffer *)

PROCEDURE Receive(dev : NetBase.Device; VAR prno: INTEGER; VAR src: ARRAY OF SYSTEM.BYTE; VAR item : NetBase.Item);
VAR len, size, left, prno0, dlen: INTEGER; state : LONGINT;
BEGIN
	IF bufhead # buftail THEN
		SYSTEM.GET(SYSTEM.ADR(buf[bufhead]), size);  SYSTEM.GET(SYSTEM.ADR(buf[bufhead])+2, len);
		state:=SYSTEM.DISABLEINTERRUPTS(); 
		INC(bufhead);  IF bufhead = BufSize THEN bufhead := 0 END;
		SYSTEM.RESTOREINTERRUPTS(state);
		left := BufSize - bufhead;  dlen := len-14;
		IF size > left THEN	(* split packet - double copy *)
				(* first move to dbuf & unsplit *)
			SYSTEM.MOVE(SYSTEM.ADR(buf[bufhead]), SYSTEM.ADR(dbuf[0]), left*4);
			SYSTEM.MOVE(SYSTEM.ADR(buf[0]), SYSTEM.ADR(dbuf[left*4]), (size-left)*4);
				(* then move to buffer & split *)
			SYSTEM.MOVE(SYSTEM.ADR(dbuf[6]), SYSTEM.ADR(src[0]), 6);	(* source address *)
			SYSTEM.GET(SYSTEM.ADR(dbuf[12]), prno0);
			SYSTEM.MOVE(SYSTEM.ADR(dbuf[14]), SYSTEM.ADR(item.data[0]), dlen);
			IF TracePackets THEN
				WritePacket(1, SYSTEM.ADR(dbuf[0]), SYSTEM.ADR(item.data[0]), dlen)
			END
		ELSE	(* ~split *)
			SYSTEM.MOVE(SYSTEM.ADR(buf[bufhead])+6, SYSTEM.ADR(src[0]), 6);	(* source address *)
			SYSTEM.GET(SYSTEM.ADR(buf[bufhead])+12, prno0);
			SYSTEM.MOVE(SYSTEM.ADR(buf[bufhead])+14, SYSTEM.ADR(item.data[0]), dlen);
			IF TracePackets THEN
				WritePacket(1, SYSTEM.ADR(buf[bufhead]), SYSTEM.ADR(item.data[0]), dlen)
			END
		END;
		prno := SYSTEM.ROT(prno0, 8);
		state:=SYSTEM.DISABLEINTERRUPTS(); 
		bufhead := (bufhead+size) MOD BufSize;  
		SYSTEM.RESTOREINTERRUPTS(state);
		item.len := dlen;
	ELSE
		item.len := 0
	END
END Receive;

PROCEDURE SkipRxFrame;
VAR tmp : INTEGER;
BEGIN
	SYSTEM.GET(Kernel.IsaMemBase+RxLength,tmp); 
	SYSTEM.GET(Kernel.IsaMemBase+RxCFG,tmp); 
	SYSTEM.PUT(Kernel.IsaMemBase+RxCFG, tmp+64); (* set Skip1 bit *)
END SkipRxFrame;

(* InterruptHandler - Handle interrupts *)
PROCEDURE *InterruptHandler;
VAR len, size, left: INTEGER;  s: SET; isq : INTEGER;
BEGIN
	SYSTEM.GET(Kernel.IsaMemBase+ISQ,isq);
	WHILE isq#0 DO
		s:=SYSTEM.VAL(SET,LONG(isq)); (* If we don't make isq long, we get an alignment error!! *)
		CASE isq MOD 32 OF
		
			4: (* RxEvent *)
				IF 8 IN s THEN (*RxOK *)
					SYSTEM.GET(Kernel.IsaMemBase+RxLength,len); (* packet length *)
					IF (len < 60) OR (len > MaxPkt) THEN	(* too small or big *)
						INC(Nsizeerrors);
						SkipRxFrame
					ELSE
						size := (len+7) DIV 4;	(* 2 bytes for len, 2 bytes for size, 3 bytes for LDR padding *)
						IF size < (bufhead - buftail - 1) MOD BufSize THEN	(* there is space *)
							DEC(size); SYSTEM.PUT(SYSTEM.ADR(buf[buftail]), size);
							SYSTEM.PUT(SYSTEM.ADR(buf[buftail])+2, len);
							buftail := (buftail+1) MOD BufSize;  left := BufSize - buftail;  INC(Nreceived);
							IF size > left THEN	(* split *)
								CopyFrame(Kernel.IsaMemBase+RxBuffer, SYSTEM.ADR(buf[buftail]), left*4);  DEC(size, left);
								CopyFrame(Kernel.IsaMemBase+RxBuffer+left*4,SYSTEM.ADR(buf[0]), size*4);  buftail := size;
								INC(Nsplits)
							ELSE	(* ~split *)
								CopyFrame(Kernel.IsaMemBase+RxBuffer, SYSTEM.ADR(buf[buftail]), size*4);  INC(buftail, size);
								IF buftail = BufSize THEN buftail := 0 END
							END
						ELSE
							INC(Ndropped);	(* no space in local buffer *)
							SkipRxFrame
						END
					END
				ELSE
					IF 13 IN s THEN INC(Nrunts) END;
					IF 14 IN s THEN INC(Nextradatas) END;
					IF 12 IN s THEN
						IF 7 IN s THEN INC(Nalignerrs) ELSE INC(Ncrcerrors) END
					ELSE
						IF 7 IN s THEN INC(Ndribblebits) END
					END;
					SkipRxFrame
				END
				
			|8: (* TxEvent *)
				transmitting:=FALSE;
				IF 6 IN s THEN INC(Nlosscrs) END;
				IF 7 IN s THEN INC(Nsqeerrors) END;
				IF 9 IN s THEN INC(Noutofwin) END;
				IF 10 IN s THEN INC(Njabbers) END
								
			|12: (* BufEvent *)
				IF 9 IN SYSTEM.VAL(SET,LONG(isq)) THEN INC(Nunderruns) END
				
			|16: (* RxMiss *)
				INC(Nmisses, LONG(isq DIV 32))
				 
			|18: (* TxColl *)
				INC(Ncolls, LONG(isq DIV 32))
				
		END;
		SYSTEM.GET(Kernel.IsaMemBase+ISQ,isq)
	END
END InterruptHandler;

(* Delay - Delay for the specified time *)

PROCEDURE Delay(ms: LONGINT);
VAR desttime : LONGINT;
BEGIN
	desttime:=Kernel.GetTimer()+ Kernel.TimeUnit*ms DIV 1000;
	WHILE Kernel.GetTimer() < desttime DO END;
END Delay;

(* Cleanup - Clean up at module termination *)

PROCEDURE *Cleanup;
BEGIN
	Kernel.RemoveIP(InterruptHandler, Kernel.IRQ+IRQ)
END Cleanup;


(* Init - Initialise the CS8900 card.  Can handle only one card. *)

PROCEDURE Init;
VAR i : INTEGER; c : SHORTINT; x, state : LONGINT; s : SET;
BEGIN
	(* Check, if it's really a CS8900 *)
	ReadIOReg(0,i);
	IF i#CS8900Id THEN
		Kernel.WriteString("CS8900: No CS8900 found! ID="); Kernel.WriteHex(i,4); Kernel.WriteLn; HALT(99);
	END;
	
	state:=SYSTEM.DISABLEINTERRUPTS();
	(* We are now resetting the chip. A spurious interrupt is generated by the chip when it is reset. *)
	WriteIOReg(SelfCTLPort,040H); (* Set RESET bit *)
	SYSTEM.RESTOREINTERRUPTS(state);
		
	(* Transition SBHE to switch chip from 8-bit to 16-bit *)
	SYSTEM.GET(Kernel.IsaIoBase+PortPktPgPtr, c); SYSTEM.GET(Kernel.IsaIoBase+PortPktPgPtr+1, c);
	SYSTEM.GET(Kernel.IsaIoBase+PortPktPgPtr, c); SYSTEM.GET(Kernel.IsaIoBase+PortPktPgPtr+1, c);

	(* Wait until the EEPROM is not busy *)
	x:=0;
	LOOP
		IF x=010000H THEN EXIT END;
		ReadIOReg(SelfSTPort,i); s:=SYSTEM.VAL(SET,LONG(i)); (* LONG is necessary. we get an alignment error if we dont use it! *)
		IF ~(8 IN s) THEN EXIT END;
		INC(x)
	END;
	IF x=010000H THEN Kernel.WriteString("CS8900: Could not reset chip!"); Kernel.WriteLn; HALT(99) END;
	
	(* Wait until initialization is done *)
	x:=0;
	LOOP
		IF x=010000H THEN EXIT END;
		ReadIOReg(SelfSTPort,i); s:=SYSTEM.VAL(SET,LONG(i)); IF 7 IN s THEN EXIT END;
		INC(x)
	END;
	IF x=010000H THEN Kernel.WriteString("CS8900: Could not reset chip!"); Kernel.WriteLn; HALT(99) END;

	(* Disable reception and transmission of frames *)
	ReadIOReg(LineCTLPort,i); s:=SYSTEM.VAL(SET,LONG(i))-{6,7}; WriteIOReg(LineCTLPort,SYSTEM.VAL(INTEGER,s));
	
	(* Disable interrupt at the chip *)
	ReadIOReg(BusCTLPort,i); s:=SYSTEM.VAL(SET,LONG(i))-{15}; WriteIOReg(BusCTLPort,SYSTEM.VAL(INTEGER,s));

	(* Enable IOCHRDY *)
	ReadIOReg(BusCTLPort,i); s:=SYSTEM.VAL(SET,LONG(i))-{8}; WriteIOReg(BusCTLPort,SYSTEM.VAL(INTEGER,s));
	
	(* Set 10BaseT medium *)
	WriteIOReg(LineCTLPort,0);
	
	(* Set the BSTATUS/HC1 pin to be used as HC1 *)
	(* HC1 is used to enable the DC/DC converter *)
	WriteIOReg(SelfCTLPort, SYSTEM.VAL(INTEGER,{13}));	(* evtl. noch bit 15 *)
	
	(* throw it into full-duplex mode *)
	WriteIOReg(TestCTLPort,04000H);	(* EXPERIMENTAL!*) 
	
	(* enable all transmission interrupts *)
	WriteIOReg(TxCFGPort,SYSTEM.VAL(INTEGER,08FC0H));
	
	(* accept all receive interrupts *)
	WriteIOReg(RxCFGPort,07100H);
	
	(* Configure Operational Modes *)
	WriteIOReg(BufCFGPort,0200H); (* BUF_CFG_TX_UNDR_IE *)

	(* Program the external logic to decode address bits SA20-SA23 *)
	WriteIOReg(EepromCMDPort, 0400H); (* 0D0000H >> 20 | CMD_ELSEL *)

	(* Setup chip for memory mode. Write the packet page base physical address to the memory base register. *)
	WriteIOReg(MemBasePort+2, SYSTEM.VAL(INTEGER,SYSTEM.LSH(PktPgBase,-16)));
	WriteIOReg(MemBasePort, SYSTEM.VAL(INTEGER,PktPgBase));
	ReadIOReg(BusCTLPort,i); s:=SYSTEM.VAL(SET,LONG(i)) + {8,10} ; (* MemoryE, UseSA *)
	WriteIOReg(BusCTLPort, SYSTEM.VAL(INTEGER,s));
	
	(* wait 10ms for the chip to swap over *)
	Delay(10);

	(* No need to set Ethernet address on the chip. This is done by EEPROM *)
	FOR i:=0 TO 5 DO SYSTEM.GET(Kernel.IsaMemBase+IndAddr+i,sendhdr.src[i]) END;
    	
	(* Set Interrupt *)
	SYSTEM.PUT(Kernel.IsaMemBase+IntNum,SYSTEM.VAL(INTEGER,3)); (* using IRQ 5 *)
	
	(* set the accepted frames *)
	SYSTEM.PUT(Kernel.IsaMemBase+RxCTL, SYSTEM.VAL(INTEGER,00D00H)); (* RxOKA, BroadcastA, IndividualA *)

	(* Enable reception and transmission of frames *)
	SYSTEM.GET(Kernel.IsaMemBase+LineCTL,i); i:=SYSTEM.VAL(INTEGER, SYSTEM.VAL(SET,LONG(i))+{7,6});
	SYSTEM.PUT(Kernel.IsaMemBase+LineCTL, i);	(*SerTxOn, SerRxOn *)
	
	(* Install interrupt handler and enable interrupts *)
	Kernel.InstallIP(InterruptHandler, Kernel.IRQ+IRQ);
    
	(* Enable interrupt at the chip *)
	SYSTEM.GET(Kernel.IsaMemBase+BusCTL,i); i:=SYSTEM.VAL(INTEGER, SYSTEM.VAL(SET,LONG(i))+{15});
	SYSTEM.PUT(Kernel.IsaMemBase+BusCTL, i);	
	
	Kernel.InstallTermHandler(Cleanup)
END Init;

PROCEDURE InstallDevice*;
VAR i: LONGINT;
BEGIN
	transmitting:=FALSE;
	NEW(dev);  dev.typ := NetBase.broadcast;  dev.state := NetBase.closed;
	dev.sndCnt := 0;  dev.recCnt := 0;
	SYSTEM.MOVE(SYSTEM.ADR(sendhdr.src[0]), SYSTEM.ADR(dev.hostAdr[0]), 6);
	FOR i := 0 TO 5 DO dev.castAdr[i] := 0FFX END;
	dev.Receive := Receive;  dev.Send := Send;  dev.Available := Avail;
	NetBase.InstallDevice(dev)
END InstallDevice;

PROCEDURE Timer;
VAR newstate: INTEGER;
BEGIN
	IF ledcount = 0 THEN
		ledcount := LedPeriod;
		IF xmit THEN
			IF ledstate # YELLOW THEN newstate := YELLOW ELSE newstate := GREEN END
		ELSIF poll THEN
			newstate := GREEN
		ELSE
			newstate := RED
		END;
		IF newstate # ledstate THEN ledstate := newstate; Led0(ledstate) END;
		poll := FALSE; xmit := FALSE
	ELSE
		DEC(ledcount)
	END
END Timer;

BEGIN
	ASSERT(SIZE(INTEGER)=2); (* Make sure that our assumptions about INTEGERs are correct! *)
	Nrunts := 0;  Nouterrors := 0;  Nsizeerrors := 0;  Nsplits := 0;  Nreceived := 0;  Ndropped := 0;    Nsent := 0;
	Nlosscrs :=0; Nsqeerrors := 0; Noutofwin := 0; Njabbers := 0; Nunderruns := 0; Nmisses := 0; Ncolls := 0;
	Nextradatas := 0; Ncrcerrors := 0; Ndribblebits := 0; Nalignerrs := 0;

	bufhead := 0;  buftail := 0;
	xmit := FALSE; poll := FALSE;
	ledstate := NONE; Led0(NONE);
	ledcount := LedPeriod;
	Kernel.timer := Timer;
	
	Init
END CS8900.
