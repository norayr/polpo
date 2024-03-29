�I  Oberon10.Scn.Fnt  v   #    '   z               S    >        }        S       �    5                '    '    9    d        u    "    �        
        .        #    $    z    ,        !    �  �     6,   b    �   EQ  MODULE Linux0;	(* rc/ard/nm/jm/devil/pjm/rml*)

(* common Kernel for MIPS 32 and ARM6T2 *)

(* OBERON System 3, Release 2.2.

Copyright 1997 Team of the Institute of Computer Systems of ETH Zuerich,
ETH Center, CH-8092 Zuerich, e-mail: oberon@inf.ethz.ch.

This module may be used under the conditions of the general Oberon 
System 3 license contract.  The full text can be requested from the 
above-mentioned address, or downloaded from

	"ftp://ftp.inf.ethz.ch/pub/software/Oberon/System3/license.txt;A"

Under the license terms stated it is in particular (a) prohibited to modify
the interface of this module in any way that disagrees with the style
or content of the system and (b) requested to provide all conversions
of the source code to another platform with the name OBERON. *)

(*	Peter Matthias
	2015-12-09	split OLR.Kernel.Mod to OLR.ARM.Linux0.Mod and OLR.MIPS.Linux0.Mod

ToDo: MIPS: save r7 during syscall

	SetClock not implemented ( only superuser can change time)
	reboot does not work
	
Wrapper Procedure for SYSCALL:

PROCEDURE SysCall( a, b, c, d, e, f, g: LONGINT): LONGINT;
BEGIN
	SYSTEM.PUTREG( 2, 4009);				(* Syscall nr to R2 *)
	SYSTEM.CODE( 12);							(* SYSCALL *)
	SYSTEM.CODE( 10070004H);			(* BEQ R7, R0, +16*)
	SYSTEM.CODE( 0);							(* NOP , branch delay slot*)	(*  MOVZ/MOVN would not be faster *)
	SYSTEM.CODE( 10000002H);				(* B +8 *)
	SYSTEM.CODE( 00021022H);				(* SUB R2, 0, R2, branch delay slot	*)
END SysCall;

Error is in R7.

The call of a PROCEDURE- marks the calling procedure as non-leaf, so the obvious solution 

PROCEDURE- SYSCALL	
	0CH, 0, 0, 0,	04H, 0, 07H, 10H,	0, 0, 0, 0,	02H, 0, 0, 10H,	22H, 10H, 02H, 0;
(*	SYSCALL;		BEQ  r0, r7,+16;		NOP;		BEQ  r0, r0,+8;		SUB  r2, r0, r2;*)

PROCEDURE Open0*( name, flags, mode: LONGINT): LONGINT;
BEGIN
	SYSTEM.PUTREG( 2, 4005);				(* Syscall nr to R2 *)
	SYSCALL
END Open0;

is currently is not possible, because arguments on stack are changed for argnum>4!

Not fixed for MOP2 compiler; prolog and epilog still written

*)

IMPORT SYSTEM;

CONST
	ARCH*="MIPST";
	ObjPrefix*="mipst/";
	ObjTag*=36FAH;	(* arm: 36FBH; mips: 36F9H; mipst: 36FAH *)

	(* registers for MIPS *)
	SP*=29; FP*=30; LR*=31;

	(** Open( .. ) flags *)
	RDonly*= 0;	WRonly*= 1;	RDWR*=2;	OCREAT*= 100H;	OEXCL*= 400H;	OTRUNC*= 200H;	OAPPEND*=8H;	(* from MIPS *)
	(** FLock( .. ) *)
	LOCKEX*= 2;	LOCKNB*= 4;	LOCKUN*= 8;
	(** LSeek *)
	SEEKSET*=0;	SEEKCURRENT*=1;	SEEKEND*=2;
	(** Mmap *)
	MAPSHARED*=1; MAPPRIVATE*=2; MAPANONYMOUS*=800H;	(* ARM: 20H; MIPS: 800H *)

(*	PROTEXEC= PROTREAD=	; PROTWRITE=	PROTNONE=	*)

	(* Termios used in Input (FB) *)
(* MIPS *)
	VMIN*=4;
	TCGETS*= 540DH;
	TCSETSF*=5410H;

	(** Socket *)
	SOCKSTREAM*=2;		(* was 1 for X86 and ARM, 2 for MIPS *)

(* Common *)
	SIGHUP= 1;		(* Hang up ; X11 quits *)
	SIGINT*= 2;			(* interrupt	 ctrl-c *)
	SIGQUIT= 3;		(* quit	ctrl-# , ctrl-4 ?, PrintScreen? *)
	SIGILL* = 4;			(* invalid instruction ?*)
	SIGTRAP*= 5;		(* HALT( x) *)
	SIGFPE* = 8;		(* DIV 0 *)
	SIGKILL= 9;	(* kill *)
	SIGSEGV*= 11;	(* segmentation fault *)
	SIGPIPE*= 13;	(* in KDE alt-F4 *)
	SIGALRM= 14;	(* signal  from alarm(1) *)
	SIGTERM = 15;	(* ctrl-alt-del *)
	SIGPROF= 29;
	SIGXCPU= 30;
	SIGXFSZ= 31;

	SIGIOT= 6;
	SIGEMT = 7;	(* unused *)
	SIGBUS*= 10;	(*  *)
	SIGSYS= 12;	(* used by DisplayLinuxFB for console switching *)
	SIGUSR1*= 16;	(* floating point stack error *)
	SIGUSR2*= 17;	(* child quit *)
	SIGCHLD= 18;
	SIGPWR= 19;
	SIGWINCH= 20;		(* tty stop *)
	SIGURG= 21;		(* tty *)
	SIGIO= 22;	(* tty *)
	SIGSTOP= 23;	(* io error *)
	SIGTSTP= 24;	(* cpu time limit *)
	SIGCONT= 25;	(* file size limit *)
	SIGTTIN= 26;	(* virtual alarm ?? *)
	SIGTTOU= 27;	(* profile signal *)
	SIGVTALRM= 28;	(* window changed *)

	IGNSigs*={ SIGWINCH, SIGSTOP, SIGCONT, SIGKILL, SIGCHLD};	(* Ignore *)
	QUITSigs*={ SIGHUP, SIGTSTP, SIGQUIT, SIGTERM};				(* Quit *)
	TRAPSigs*= -{} -IGNSigs-QUITSigs ;	(* Trap *)

TYPE
	SigHandler*= PROCEDURE;

	SigContext*= POINTER TO RECORD
		sp, signal*, pcl*, pch: LONGINT;		(* regmask and status is unused, store sp and signal there... *)
		regs*: ARRAY 64 OF LONGINT;
		fpregs*: ARRAY 64 OF LONGINT;
		acx, fpccsr, fpceir, usedmath, dsp: LONGINT;
		mdhil, mdhih, mdlol, mdloh: LONGINT;
		hi1, lo1, hi2, lo2, hi3, lo3: LONGINT;		(* hi1 might be sc_cause, lo1 sc_badvaddr	*)
	END;
	SigInfo*= POINTER TO RECORD
		signo*, code*, errno*, adr*, instr*: LONGINT;
	END;

	Status* = RECORD
		stdev, pad10, pad11, pad12: LONGINT;
		stino: LONGINT;
		stmode, stnlinl, stuid, stgid, rdev, pad20, pad21: LONGINT;
		size*, pad30, 
		atime*, atimens,
		mtime*, mtimens,
		ctime*, ctimens, 
		blksize*, blocks*: LONGINT;
		pad4: ARRAY 14 OF LONGINT;
	END;

	SockAddrUn*= RECORD
		pf*: INTEGER;
		path*: ARRAY 64 OF CHAR;	(* was 30 for MIPS; 64 for ARM *)
	END;

	Timeval = RECORD sec, usec: LONGINT END;

VAR
	regs*, fpregs*: ARRAY 32 OF LONGINT;

PROCEDURE Open0*( name, flags, mode: LONGINT): LONGINT;
BEGIN
	SYSTEM.CODE( 8C000000H+29*200000H+4*10000H+ 0);
	SYSTEM.CODE( 8C000000H+29*200000H+5*10000H+ 4);
	SYSTEM.CODE( 8C000000H+29*200000H+6*10000H+ 8);
	SYSTEM.PUTREG( 2, 4005);				(* Syscall nr to R2 *)
	SYSTEM.CODE( 12);							(* SYSCALL *)
	SYSTEM.CODE( 10070004H);			(* BEQ R7, R0, +16*)
	SYSTEM.CODE( 0);							(* NOP , branch delay slot*)
	SYSTEM.CODE( 10000002H);				(* B +8 *)
	SYSTEM.CODE( 00021022H);				(* SUB R2, 0, R2, branch delay slot	*)
END Open0;

PROCEDURE Close0*( fd: LONGINT): LONGINT;
BEGIN
	SYSTEM.CODE( 8C000000H+29*200000H+4*10000H+ 0);
	SYSTEM.PUTREG( 2, 4006);				(* close *)
	SYSTEM.CODE( 12);							(* SYSCALL *)
	SYSTEM.CODE( 10070004H);			(* BEQ R7, R0, +16*)
	SYSTEM.CODE( 0);							(* NOP , branch delay slot*)
	SYSTEM.CODE( 10000002H);				(* B +8 *)
	SYSTEM.CODE( 00021022H);				(* SUB R2, 0, R2, branch delay slot	*)
END Close0;

PROCEDURE Read0*( fd, buf, num: LONGINT): LONGINT;
BEGIN
	SYSTEM.CODE( 8C000000H+29*200000H+4*10000H+ 0);
	SYSTEM.CODE( 8C000000H+29*200000H+5*10000H+ 4);
	SYSTEM.CODE( 8C000000H+29*200000H+6*10000H+ 8);
	SYSTEM.PUTREG( 2, 4003);				(* Syscall nr to R2 *)
	SYSTEM.CODE( 12);							(* SYSCALL *)
	SYSTEM.CODE( 10070004H);			(* BEQ R7, R0, +16*)
	SYSTEM.CODE( 0);							(* NOP , branch delay slot*)
	SYSTEM.CODE( 10000002H);				(* B +8 *)
	SYSTEM.CODE( 00021022H);				(* SUB R2, 0, R2, branch delay slot	*)
END Read0;

PROCEDURE Readv0*( fd, vect, cnt: LONGINT): LONGINT;
BEGIN
	SYSTEM.CODE( 8C000000H+29*200000H+4*10000H+ 0);
	SYSTEM.CODE( 8C000000H+29*200000H+5*10000H+ 4);
	SYSTEM.CODE( 8C000000H+29*200000H+6*10000H+ 8);
	SYSTEM.PUTREG( 2, 4145);				(* Syscall nr to R2 *)
	SYSTEM.CODE( 12);							(* SYSCALL *)
	SYSTEM.CODE( 10070004H);			(* BEQ R7, R0, +16*)
	SYSTEM.CODE( 0);							(* NOP , branch delay slot*)
	SYSTEM.CODE( 10000002H);				(* B +8 *)
	SYSTEM.CODE( 00021022H);				(* SUB R2, 0, R2, branch delay slot	*)
END Readv0;

PROCEDURE Write0*( fd, buf, num: LONGINT): LONGINT;	
BEGIN
	SYSTEM.CODE( 8C000000H+29*200000H+4*10000H+ 0);
	SYSTEM.CODE( 8C000000H+29*200000H+5*10000H+ 4);
	SYSTEM.CODE( 8C000000H+29*200000H+6*10000H+ 8);
	SYSTEM.PUTREG( 2, 4004);		(* write *)
	SYSTEM.CODE( 12);							(* SYSCALL *)
	SYSTEM.CODE( 10070004H);			(* BEQ R7, R0, +16*)
	SYSTEM.CODE( 0);							(* NOP , branch delay slot*)
	SYSTEM.CODE( 10000002H);				(* B +8 *)
	SYSTEM.CODE( 00021022H);				(* SUB R2, 0, R2, branch delay slot	*)
END Write0;

PROCEDURE Writev0*( fd, vect, cnt: LONGINT): LONGINT;	
BEGIN
	SYSTEM.CODE( 8C000000H+29*200000H+4*10000H+ 0);
	SYSTEM.CODE( 8C000000H+29*200000H+5*10000H+ 4);
	SYSTEM.CODE( 8C000000H+29*200000H+6*10000H+ 8);
	SYSTEM.PUTREG( 2, 4146);		(* writev *)
	SYSTEM.CODE( 12);							(* SYSCALL *)
	SYSTEM.CODE( 10070004H);			(* BEQ R7, R0, +16*)
	SYSTEM.CODE( 0);							(* NOP , branch delay slot*)
	SYSTEM.CODE( 10000002H);				(* B +8 *)
	SYSTEM.CODE( 00021022H);				(* SUB R2, 0, R2, branch delay slot	*)
END Writev0;

PROCEDURE Brk0*( adr: LONGINT):LONGINT;
BEGIN
	SYSTEM.CODE( 8C000000H+29*200000H+4*10000H+ 0);
	SYSTEM.PUTREG( 2, 4045);		(* brk *)
	SYSTEM.CODE( 12);							(* SYSCALL *)
	SYSTEM.CODE( 10070004H);			(* BEQ R7, R0, +16*)
	SYSTEM.CODE( 0);							(* NOP , branch delay slot*)
	SYSTEM.CODE( 10000002H);				(* B +8 *)
	SYSTEM.CODE( 00021022H);				(* SUB R2, 0, R2, branch delay slot	*)
END Brk0;

PROCEDURE Exit0*(arg: LONGINT): LONGINT;
BEGIN
	SYSTEM.CODE( 8C000000H+29*200000H+4*10000H+ 0);
	SYSTEM.PUTREG( 2, 4001);		(* exit *)
	SYSTEM.CODE( 12);							(* SYSCALL *)
	SYSTEM.CODE( 10070004H);			(* BEQ R7, R0, +16*)
	SYSTEM.CODE( 0);							(* NOP , branch delay slot*)
	SYSTEM.CODE( 10000002H);				(* B +8 *)
	SYSTEM.CODE( 00021022H);				(* SUB R2, 0, R2, branch delay slot	*)
END Exit0;

PROCEDURE Creat0*( name, mode: LONGINT): LONGINT;
BEGIN
	SYSTEM.CODE( 8C000000H+29*200000H+4*10000H+ 0);
	SYSTEM.CODE( 8C000000H+29*200000H+5*10000H+ 4);
	SYSTEM.PUTREG( 2, 4008);		(* creat *)
	SYSTEM.CODE( 12);							(* SYSCALL *)
	SYSTEM.CODE( 10070004H);			(* BEQ R7, R0, +16*)
	SYSTEM.CODE( 0);							(* NOP , branch delay slot*)
	SYSTEM.CODE( 10000002H);				(* B +8 *)
	SYSTEM.CODE( 00021022H);				(* SUB R2, 0, R2, branch delay slot	*)
END Creat0;

PROCEDURE MProtect0*( adr, len, prot: LONGINT): LONGINT;
BEGIN
	SYSTEM.CODE( 8C000000H+29*200000H+4*10000H+ 0);
	SYSTEM.CODE( 8C000000H+29*200000H+5*10000H+ 4);
	SYSTEM.CODE( 8C000000H+29*200000H+6*10000H+ 8);
	SYSTEM.PUTREG( 2, 4125);		(* mprotect *)
	SYSTEM.CODE( 12);							(* SYSCALL *)
	SYSTEM.CODE( 10070004H);			(* BEQ R7, R0, +16*)
	SYSTEM.CODE( 0);							(* NOP , branch delay slot*)
	SYSTEM.CODE( 10000002H);				(* B +8 *)
	SYSTEM.CODE( 00021022H);				(* SUB R2, 0, R2, branch delay slot	*)
END MProtect0;

PROCEDURE SIGAction0*( signum, act, oldact: LONGINT): LONGINT;	
BEGIN
	SYSTEM.CODE( 8C000000H+29*200000H+4*10000H+ 0);
	SYSTEM.CODE( 8C000000H+29*200000H+5*10000H+ 4);
	SYSTEM.CODE( 8C000000H+29*200000H+6*10000H+ 8);
	SYSTEM.PUTREG( 2, 4067);		(* sigaction was 4067*)
	SYSTEM.CODE( 12);							(* SYSCALL *)
	SYSTEM.CODE( 10070004H);			(* BEQ R7, R0, +16*)
	SYSTEM.CODE( 0);							(* NOP , branch delay slot*)
	SYSTEM.CODE( 10000002H);				(* B +8 *)
	SYSTEM.CODE( 00021022H);				(* SUB R2, 0, R2, branch delay slot	*)
END SIGAction0;

PROCEDURE FStat0*( fd, stat: LONGINT): LONGINT;
BEGIN
	SYSTEM.CODE( 8C000000H+29*200000H+4*10000H+ 0);
	SYSTEM.CODE( 8C000000H+29*200000H+5*10000H+ 4);
	SYSTEM.PUTREG( 2, 4108);				(* Syscall nr to R2 fxstat*)
	SYSTEM.CODE( 12);							(* SYSCALL *)
	SYSTEM.CODE( 10070004H);			(* BEQ R7, R0, +16*)
	SYSTEM.CODE( 0);							(* NOP , branch delay slot*)
	SYSTEM.CODE( 10000002H);				(* B +8 *)
	SYSTEM.CODE( 00021022H);				(* SUB R2, 0, R2, branch delay slot	*)
END FStat0;

PROCEDURE Mmap20*( addr, len, prot, flags, fd, off: LONGINT):LONGINT;
BEGIN
	SYSTEM.CODE( 8C000000H+29*200000H+4*10000H+ 0);
	SYSTEM.CODE( 8C000000H+29*200000H+5*10000H+ 4);
	SYSTEM.CODE( 8C000000H+29*200000H+6*10000H+ 8);
	SYSTEM.CODE( 8C000000H+29*200000H+7*10000H+ 12);
	SYSTEM.PUTREG( 2, 4090);				(* Syscall nr to R2 mmap64: 4210, mmap: 4090*)
	SYSTEM.CODE( 12);							(* SYSCALL *)
	SYSTEM.CODE( 10070004H);			(* BEQ R7, R0, +16*)
	SYSTEM.CODE( 0);							(* NOP , branch delay slot*)
	SYSTEM.CODE( 10000002H);				(* B +8 *)
	SYSTEM.CODE( 00021022H);				(* SUB R2, 0, R2, branch delay slot	*)
END Mmap20;

PROCEDURE Munmap0*( addr, len: LONGINT): LONGINT;
BEGIN
	SYSTEM.CODE( 8C000000H+29*200000H+4*10000H+ 0);
	SYSTEM.CODE( 8C000000H+29*200000H+5*10000H+ 4);
	SYSTEM.PUTREG( 2, 4091);				(* Syscall nr to R2 *)
	SYSTEM.CODE( 12);							(* SYSCALL *)
	SYSTEM.CODE( 10070004H);			(* BEQ R7, R0, +16*)
	SYSTEM.CODE( 0);							(* NOP , branch delay slot*)
	SYSTEM.CODE( 10000002H);				(* B +8 *)
	SYSTEM.CODE( 00021022H);				(* SUB R2, 0, R2, branch delay slot	*)
END Munmap0;

PROCEDURE CacheFlush0*( adr, bytes: LONGINT): LONGINT;
BEGIN
	SYSTEM.CODE( 8C000000H+29*200000H+4*10000H+ 0);
	SYSTEM.CODE( 8C000000H+29*200000H+5*10000H+ 4);
	SYSTEM.PUTREG( 2, 4147);
	SYSTEM.PUTREG( 6, 3);					(* third argument always 3 *)
	SYSTEM.CODE( 12);							(* SYSCALL *)
	SYSTEM.CODE( 10070004H);			(* BEQ R7, R0, +16*)
	SYSTEM.CODE( 0);							(* NOP , branch delay slot*)
	SYSTEM.CODE( 10000002H);				(* B +8 *)
	SYSTEM.CODE( 00021022H);				(* SUB R2, 0, R2, branch delay slot	*)
END CacheFlush0;

(* Files *)
PROCEDURE LSeek0*( fd, pos, whence: LONGINT): LONGINT;
BEGIN
	SYSTEM.CODE( 8C000000H+29*200000H+4*10000H+ 0);
	SYSTEM.CODE( 8C000000H+29*200000H+5*10000H+ 4);
	SYSTEM.CODE( 8C000000H+29*200000H+6*10000H+ 8);
	SYSTEM.PUTREG( 2, 4019);				(* Syscall nr to R2 *)
	SYSTEM.CODE( 12);							(* SYSCALL *)
	SYSTEM.CODE( 10070004H);			(* BEQ R7, R0, +16*)
	SYSTEM.CODE( 0);							(* NOP , branch delay slot*)
	SYSTEM.CODE( 10000002H);				(* B +8 *)
	SYSTEM.CODE( 00021022H);				(* SUB R2, 0, R2, branch delay slot	*)
END LSeek0;

PROCEDURE FLock0*( fd, arg: LONGINT): LONGINT;
BEGIN
	SYSTEM.CODE( 8C000000H+29*200000H+4*10000H+ 0);
	SYSTEM.CODE( 8C000000H+29*200000H+5*10000H+ 4);
	SYSTEM.PUTREG( 2, 4143);				(* Syscall nr to R2 *)
	SYSTEM.CODE( 12);							(* SYSCALL *)
	SYSTEM.CODE( 10070004H);			(* BEQ R7, R0, +16*)
	SYSTEM.CODE( 0);							(* NOP , branch delay slot*)
	SYSTEM.CODE( 10000002H);				(* B +8 *)
	SYSTEM.CODE( 00021022H);				(* SUB R2, 0, R2, branch delay slot	*)
END FLock0;

PROCEDURE Ftruncate0*( fd, len: LONGINT): LONGINT;
BEGIN
	SYSTEM.CODE( 8C000000H+29*200000H+4*10000H+ 0);
	SYSTEM.CODE( 8C000000H+29*200000H+5*10000H+ 4);
	SYSTEM.PUTREG( 2, 4093);				(* Syscall nr to R2 *)
	SYSTEM.CODE( 12);							(* SYSCALL *)
	SYSTEM.CODE( 10070004H);			(* BEQ R7, R0, +16*)
	SYSTEM.CODE( 0);							(* NOP , branch delay slot*)
	SYSTEM.CODE( 10000002H);				(* B +8 *)
	SYSTEM.CODE( 00021022H);				(* SUB R2, 0, R2, branch delay slot	*)
END Ftruncate0;

PROCEDURE UTime0*( name, utimebuf: LONGINT):LONGINT;
BEGIN
	SYSTEM.CODE( 8C000000H+29*200000H+4*10000H+ 0);
	SYSTEM.CODE( 8C000000H+29*200000H+5*10000H+ 4);
	SYSTEM.PUTREG( 2, 4030);				(* Syscall nr to R2 *)
	SYSTEM.CODE( 12);							(* SYSCALL *)
	SYSTEM.CODE( 10070004H);			(* BEQ R7, R0, +16*)
	SYSTEM.CODE( 0);							(* NOP , branch delay slot*)
	SYSTEM.CODE( 10000002H);				(* B +8 *)
	SYSTEM.CODE( 00021022H);				(* SUB R2, 0, R2, branch delay slot	*)
END UTime0;

PROCEDURE GetTimeOfDay*(tv, tz: LONGINT): LONGINT;
BEGIN
	SYSTEM.CODE( 8C000000H+29*200000H+4*10000H+ 0);
	SYSTEM.CODE( 8C000000H+29*200000H+5*10000H+ 4);
	SYSTEM.PUTREG( 2, 4078);	(* GETTIMEOFDAY= 4078; TIME = 13 *)
	SYSTEM.CODE( 12);							(* SYSCALL *)
	SYSTEM.CODE( 10070004H);			(* BEQ R7, R0, +16*)
	SYSTEM.CODE( 0);							(* NOP , branch delay slot*)
	SYSTEM.CODE( 10000002H);				(* B +8 *)
	SYSTEM.CODE( 00021022H);				(* SUB R2, 0, R2, branch delay slot	*)
END GetTimeOfDay;

PROCEDURE Rename0*( old, new: LONGINT): LONGINT;
BEGIN
	SYSTEM.CODE( 8C000000H+29*200000H+4*10000H+ 0);
	SYSTEM.CODE( 8C000000H+29*200000H+5*10000H+ 4);
	SYSTEM.PUTREG( 2, 4038);				(* Syscall nr to R2 *)
	SYSTEM.CODE( 12);							(* SYSCALL *)
	SYSTEM.CODE( 10070004H);			(* BEQ R7, R0, +16*)
	SYSTEM.CODE( 0);							(* NOP , branch delay slot*)
	SYSTEM.CODE( 10000002H);				(* B +8 *)
	SYSTEM.CODE( 00021022H);				(* SUB R2, 0, R2, branch delay slot	*)
END Rename0;

PROCEDURE UnLink0*( name: LONGINT): LONGINT;
BEGIN
	SYSTEM.CODE( 8C000000H+29*200000H+4*10000H+ 0);
	SYSTEM.PUTREG( 2, 4010);				(* Syscall nr to R2 *)
	SYSTEM.CODE( 12);							(* SYSCALL *)
	SYSTEM.CODE( 10070004H);			(* BEQ R7, R0, +16*)
	SYSTEM.CODE( 0);							(* NOP , branch delay slot*)
	SYSTEM.CODE( 10000002H);				(* B +8 *)
	SYSTEM.CODE( 00021022H);				(* SUB R2, 0, R2, branch delay slot	*)
END UnLink0;

PROCEDURE Mremap0*( oldaddr, oldsize, newsize, flags, naddr: LONGINT): LONGINT;
(* MREMAP_MAYMOVE=1 *)
BEGIN
	SYSTEM.CODE( 8C000000H+29*200000H+4*10000H+ 0);
	SYSTEM.CODE( 8C000000H+29*200000H+5*10000H+ 4);
	SYSTEM.CODE( 8C000000H+29*200000H+6*10000H+ 8);
	SYSTEM.CODE( 8C000000H+29*200000H+7*10000H+ 12);
	SYSTEM.PUTREG( 2, 4167);				(* Syscall nr to R2 *)
	SYSTEM.CODE( 12);							(* SYSCALL *)
	SYSTEM.CODE( 10070004H);			(* BEQ R7, R0, +16*)
	SYSTEM.CODE( 0);							(* NOP , branch delay slot*)
	SYSTEM.CODE( 10000002H);				(* B +8 *)
	SYSTEM.CODE( 00021022H);				(* SUB R2, 0, R2, branch delay slot	*)
END Mremap0;

PROCEDURE Stat0*( name, stat: LONGINT): LONGINT;
BEGIN
	SYSTEM.CODE( 8C000000H+29*200000H+4*10000H+ 0);
	SYSTEM.CODE( 8C000000H+29*200000H+5*10000H+ 4);
	SYSTEM.PUTREG( 2, 4106);				(* Syscall nr to R2 xstat *)
	SYSTEM.CODE( 12);							(* SYSCALL *)
	SYSTEM.CODE( 10070004H);			(* BEQ R7, R0, +16*)
	SYSTEM.CODE( 0);							(* NOP , branch delay slot*)
	SYSTEM.CODE( 10000002H);				(* B +8 *)
	SYSTEM.CODE( 00021022H);				(* SUB R2, 0, R2, branch delay slot	*)
END Stat0;

PROCEDURE GetDents0*( fd, bufptr, count: LONGINT): LONGINT;
BEGIN
	SYSTEM.CODE( 8C000000H+29*200000H+4*10000H+ 0);
	SYSTEM.CODE( 8C000000H+29*200000H+5*10000H+ 4);
	SYSTEM.CODE( 8C000000H+29*200000H+6*10000H+ 8);
	SYSTEM.PUTREG( 2, 4141);				(* Syscall nr to R2 *)
	SYSTEM.CODE( 12);							(* SYSCALL *)
	SYSTEM.CODE( 10070004H);			(* BEQ R7, R0, +16*)
	SYSTEM.CODE( 0);							(* NOP , branch delay slot*)
	SYSTEM.CODE( 10000002H);				(* B +8 *)
	SYSTEM.CODE( 00021022H);				(* SUB R2, 0, R2, branch delay slot	*)
END GetDents0;

PROCEDURE Socket0*( n1, n2, n3: LONGINT): LONGINT;
BEGIN
	SYSTEM.CODE( 8C000000H+29*200000H+4*10000H+ 0);
	SYSTEM.CODE( 8C000000H+29*200000H+5*10000H+ 4);
	SYSTEM.CODE( 8C000000H+29*200000H+6*10000H+ 8);
	SYSTEM.PUTREG( 2, 4183);				(* Syscall nr to R2 *)
	SYSTEM.CODE( 12);							(* SYSCALL *)
	SYSTEM.CODE( 10070004H);			(* BEQ R7, R0, +16*)
	SYSTEM.CODE( 0);							(* NOP , branch delay slot*)
	SYSTEM.CODE( 10000002H);				(* B +8 *)
	SYSTEM.CODE( 00021022H);				(* SUB R2, 0, R2, branch delay slot	*)
END Socket0;

PROCEDURE Connect0*( sockfd, servaddr, addrlen: LONGINT): LONGINT;
BEGIN
	SYSTEM.CODE( 8C000000H+29*200000H+4*10000H+ 0);
	SYSTEM.CODE( 8C000000H+29*200000H+5*10000H+ 4);
	SYSTEM.CODE( 8C000000H+29*200000H+6*10000H+ 8);
	SYSTEM.PUTREG( 2, 4170);				(* Syscall nr to R2 *)
	SYSTEM.CODE( 12);							(* SYSCALL *)
	SYSTEM.CODE( 10070004H);			(* BEQ R7, R0, +16*)
	SYSTEM.CODE( 0);							(* NOP , branch delay slot*)
	SYSTEM.CODE( 10000002H);				(* B +8 *)
	SYSTEM.CODE( 00021022H);				(* SUB R2, 0, R2, branch delay slot	*)
END Connect0;

PROCEDURE Ipc0( call, first, second, third, ptr, fifth: LONGINT): LONGINT;
BEGIN
	SYSTEM.CODE( 8C000000H+29*200000H+4*10000H+ 0);
	SYSTEM.CODE( 8C000000H+29*200000H+5*10000H+ 4);
	SYSTEM.CODE( 8C000000H+29*200000H+6*10000H+ 8);
	SYSTEM.CODE( 8C000000H+29*200000H+7*10000H+ 12);
	SYSTEM.PUTREG( 2, 4117);				(* Syscall nr to R2 *)
	SYSTEM.CODE( 12);							(* SYSCALL *)
	SYSTEM.CODE( 10070004H);			(* BEQ R7, R0, +16*)
	SYSTEM.CODE( 0);							(* NOP , branch delay slot*)
	SYSTEM.CODE( 10000002H);				(* B +8 *)
	SYSTEM.CODE( 00021022H);				(* SUB R2, 0, R2, branch delay slot	*)
END Ipc0;

PROCEDURE Shmget0*( key, size, shmflag: LONGINT): LONGINT;
BEGIN
	RETURN Ipc0( 23, key, size, shmflag, 0, 0);
END Shmget0;

PROCEDURE Shmat0*(shmid, addr, flags: LONGINT): LONGINT;
VAR res: LONGINT;
BEGIN
	res:= Ipc0( 21, shmid, flags, SYSTEM.ADR(addr), addr,  0);
	RETURN addr;
END Shmat0;

PROCEDURE Shmdt0*(addr: LONGINT): LONGINT;
BEGIN
	RETURN Ipc0( 22, 0, 0, 0, addr, 0);
END Shmdt0;

PROCEDURE ShmCtl0*(buf, cmd, shmid: LONGINT): LONGINT;
BEGIN
	RETURN Ipc0( 24, buf, SYSTEM.VAL(LONGINT, SYSTEM.VAL(SET,cmd)+{8}), 0, shmid, 0);
END ShmCtl0;

PROCEDURE IOCtl0*( d, r1, r2: LONGINT): LONGINT;
BEGIN
	SYSTEM.CODE( 8C000000H+29*200000H+4*10000H+ 0);
	SYSTEM.CODE( 8C000000H+29*200000H+5*10000H+ 4);
	SYSTEM.CODE( 8C000000H+29*200000H+6*10000H+ 8);
	SYSTEM.PUTREG( 2, 4054);				(* Syscall nr to R2 *)
	SYSTEM.CODE( 12);							(* SYSCALL *)
	SYSTEM.CODE( 10070004H);			(* BEQ R7, R0, +16*)
	SYSTEM.CODE( 0);							(* NOP , branch delay slot*)
	SYSTEM.CODE( 10000002H);				(* B +8 *)
	SYSTEM.CODE( 00021022H);				(* SUB R2, 0, R2, branch delay slot	*)
END IOCtl0;

PROCEDURE Select0*( n, reafds, writefds, execptfds, timeout: LONGINT): LONGINT;
BEGIN
	SYSTEM.CODE( 8C000000H+29*200000H+4*10000H+ 0);
	SYSTEM.CODE( 8C000000H+29*200000H+5*10000H+ 4);
	SYSTEM.CODE( 8C000000H+29*200000H+6*10000H+ 8);
	SYSTEM.CODE( 8C000000H+29*200000H+7*10000H+ 12);
	SYSTEM.PUTREG( 2, 4142);				(* Syscall nr to R2 *)
	SYSTEM.CODE( 12);							(* SYSCALL *)
	SYSTEM.CODE( 10070004H);			(* BEQ R7, R0, +16*)
	SYSTEM.CODE( 0);							(* NOP , branch delay slot*)
	SYSTEM.CODE( 10000002H);				(* B +8 *)
	SYSTEM.CODE( 00021022H);				(* SUB R2, 0, R2, branch delay slot	*)
END Select0;

(* MIPS*)
PROCEDURE SetSignal*( nr: LONGINT; handler: SigHandler): LONGINT;
CONST SARESTART= 10000000H;
TYPE
	SigAction = RECORD
		flags: SET;
		handler: SigHandler;
		mask: SET;
	END;
VAR h, d: SigAction;
BEGIN
	h.flags:= {3};	(* SA_SIGINFO *)
	h.handler:= handler;
	h.mask:= {};
	RETURN SIGAction0( nr, SYSTEM.ADR(h), SYSTEM.ADR(d));
END SetSignal;

END Linux0.

