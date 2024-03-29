�TextDocs.NewDoc     ���Q   Oberon10.Scn.Fnt     Oberon10b.Scn.Fnt  �    }   6   �	     MODULE OFW; (* as 10.12.98 *)
(*
	ATTENTION! KERNEL ISN'T INITIALIZED, SO DO NOT USE HEAP AND DIV OR MOD WHERE THE 2nd OPERAND IS NOT A 
	POWER OF TWO!!! 
*)

(* Access to the OpenFirmware on the DEC Shark NC *)

IMPORT SYSTEM;

TYPE
	Args* = ARRAY 14 OF LONGINT;
	
VAR
	entry* : LONGINT;
	
PROCEDURE Call*(VAR a : Args) : LONGINT;
CODE
	STMDB	SP!,{LR}
	LDR	R0,[SP,4]	(* Load Address of Data into R0 *)
	SWI	200H			(* Do the OFW call *)
	MOV	LR, PC
	LDR	PC,[SP],8 (* pop PC, remove addr *)
END Call;

PROCEDURE DecodeInt*(a : LONGINT) : LONGINT;
(* Big-Endian -> Little Endian *)
VAR i : LONGINT; ch : CHAR;
BEGIN
	SYSTEM.GET(SYSTEM.ADR(a)+0,ch); SYSTEM.PUT(SYSTEM.ADR(i)+3,ch);
	SYSTEM.GET(SYSTEM.ADR(a)+1,ch); SYSTEM.PUT(SYSTEM.ADR(i)+2,ch);
	SYSTEM.GET(SYSTEM.ADR(a)+2,ch); SYSTEM.PUT(SYSTEM.ADR(i)+1,ch);
	SYSTEM.GET(SYSTEM.ADR(a)+3,ch); SYSTEM.PUT(SYSTEM.ADR(i)+0,ch);
	RETURN i;
END DecodeInt;

PROCEDURE Open*(name : ARRAY OF CHAR) : LONGINT;
VAR args : Args;
BEGIN
	args[0]:=SYSTEM.ADR("open"); args[1]:=1; args[2]:=1; args[3]:=SYSTEM.ADR(name);
	IF Call(args)=-1 THEN RETURN -1
	ELSE RETURN args[4]
	END
END Open;

PROCEDURE Close*(handle : LONGINT);
VAR args : Args;
BEGIN
	args[0]:=SYSTEM.ADR("close"); args[1]:=1; args[2]:=0; args[3]:=handle;
	IF Call(args)=-1 THEN END;
END Close;

PROCEDURE GetProp*(handle : LONGINT; key : ARRAY OF CHAR; VAR res : ARRAY OF SYSTEM.BYTE) : LONGINT;
VAR args : Args;
BEGIN
	args[0]:=SYSTEM.ADR("getprop"); args[1]:=4; args[2]:=1; args[3]:=handle; args[4]:=SYSTEM.ADR(key);
	args[5]:=SYSTEM.ADR(res); args[6]:=LEN(res);

	IF Call(args)=-1 THEN RETURN -1
	ELSE RETURN args[7]
	END;
END GetProp;

PROCEDURE SetProp*(handle : LONGINT; key : ARRAY OF CHAR; VAR val : ARRAY OF SYSTEM.BYTE) : LONGINT;
VAR args : Args;
BEGIN
	args[0]:=SYSTEM.ADR("setprop"); args[1]:=4; args[2]:=1; args[3]:=handle; args[4]:=SYSTEM.ADR(key);
	args[5]:=SYSTEM.ADR(val); args[6]:=LEN(val);
	IF Call(args)=-1 THEN RETURN -1
	ELSE RETURN args[7]
	END;
END SetProp;

PROCEDURE GetPropLen*(handle : LONGINT; key : ARRAY OF CHAR) : LONGINT;
VAR args : Args;
BEGIN
	args[0]:=SYSTEM.ADR("getproplen"); args[1]:=2; args[2]:=1; args[3]:=handle; args[4]:=SYSTEM.ADR(key);
	IF Call(args)=-1 THEN RETURN -1
	ELSE RETURN args[5]
	END
END GetPropLen;

PROCEDURE GetIntProp*(node : LONGINT; key : ARRAY OF CHAR) : LONGINT;
VAR res : LONGINT; buf : LONGINT;
BEGIN
	res:=GetProp(node,key,buf);
	IF res#4 THEN RETURN -1 
	ELSE RETURN DecodeInt(buf)
	END; 
END GetIntProp;

PROCEDURE SetIntProp*(node : LONGINT; key : ARRAY OF CHAR; val : LONGINT) : LONGINT;
BEGIN
	val:=DecodeInt(val);
	RETURN SetProp(node,key,val);
END SetIntProp;

PROCEDURE FindDevice*(name : ARRAY OF CHAR) : LONGINT;
VAR args : Args;
BEGIN
	args[0]:=SYSTEM.ADR("finddevice"); args[1]:=1; args[2]:=1; args[3]:=SYSTEM.ADR(name);
	IF Call(args)=-1 THEN RETURN -1
	ELSE RETURN args[4]
	END
END FindDevice;

PROCEDURE InstanceToPackage*(ihandle : LONGINT) : LONGINT;
VAR args : Args;
BEGIN
	args[0]:=SYSTEM.ADR("instance-to-package");
	args[1]:=1; args[2]:=1; args[3]:=ihandle;
	IF Call(args)=-1 THEN RETURN -1
	ELSE RETURN args[4]
	END
END InstanceToPackage;

PROCEDURE Write*(handle : LONGINT; VAR s : ARRAY OF SYSTEM.BYTE) : LONGINT;
VAR args : Args;
BEGIN
	args[0]:=SYSTEM.ADR("write"); args[1]:=3; args[2]:=1; args[3]:=handle; args[4]:=SYSTEM.ADR(s); args[5]:=LEN(s);
	IF Call(args)=-1 THEN RETURN -1 
	ELSE RETURN args[6]
	END;
END Write;

PROCEDURE Claim*(virt, size, align : LONGINT) : LONGINT;
VAR args : Args;
BEGIN
	args[0]:=SYSTEM.ADR("claim"); args[1]:=3; args[2]:=1; args[3]:=virt; args[4]:=size; args[5]:=align;
	IF Call(args)=-1 THEN RETURN -1 
	ELSE RETURN args[6]
	END;
END Claim;

PROCEDURE Release*(virt, size : LONGINT);
VAR args : Args; res :LONGINT;
BEGIN
	args[0]:=SYSTEM.ADR("release"); args[1]:=2; args[2]:=0; args[3]:=virt; args[4]:=size;
	res:=Call(args);
END Release;

(* Hmmm, seems like this doesn't work... use Interpret("reset-all") instead 
PROCEDURE Boot*(bootspec : ARRAY OF CHAR);
VAR args : Args; res : LONGINT;
BEGIN
	args[0]:=SYSTEM.ADR("boot"); args[1]:=1; args[2]:=0; args[3]:=SYSTEM.ADR(bootspec[0]);
	res:=Call(args);
	LOOP END; (* just in case... *)
END Boot;
*)

PROCEDURE Interpret*(method : ARRAY OF CHAR) : LONGINT;
VAR args : Args;
BEGIN
	args[0]:=SYSTEM.ADR("interpret"); args[1]:=2; args[2]:=1; args[3]:=SYSTEM.ADR(method);
	IF Call(args)=-1 THEN RETURN -1
	ELSIF args[4]#0 THEN RETURN -1
	ELSE RETURN args[5]
	END
END Interpret;

PROCEDURE CallMethod0*(method : ARRAY OF CHAR; handle : LONGINT) : LONGINT;
VAR args : Args;
BEGIN
	args[0]:=SYSTEM.ADR("call-method"); args[1]:=2; args[2]:=2; args[3]:=SYSTEM.ADR(method);
	args[4]:=handle;
	IF Call(args)=-1 THEN RETURN -1
	ELSIF args[5]#0 THEN RETURN -1
	ELSE RETURN args[6]
	END
END CallMethod0;

PROCEDURE CallMethod1*(method : ARRAY OF CHAR; handle, arg : LONGINT) : LONGINT;
VAR args : Args;
BEGIN
	args[0]:=SYSTEM.ADR("call-method"); args[1]:=3; args[2]:=2; args[3]:=SYSTEM.ADR(method);
	args[4]:=handle; args[5]:=arg; 
	IF Call(args)=-1 THEN RETURN -1
	ELSIF args[6]#0 THEN RETURN -1
	ELSE RETURN args[7]
	END
END CallMethod1;

PROCEDURE CallMethod2*(method : ARRAY OF CHAR; handle, arg1, arg2 : LONGINT) : LONGINT;
VAR args : Args;
BEGIN
	args[0]:=SYSTEM.ADR("call-method"); args[1]:=4; args[2]:=2; args[3]:=SYSTEM.ADR(method);
	args[4]:=handle; args[5]:=arg2; args[6]:=arg1;
	IF Call(args)=-1 THEN RETURN -1
	ELSIF args[7]#0 THEN RETURN -1
	ELSE RETURN args[8]
	END
END CallMethod2;

PROCEDURE CallMethod3*(method : ARRAY OF CHAR; handle, arg1, arg2, arg3 : LONGINT) : LONGINT;
VAR args : Args;
BEGIN
	args[0]:=SYSTEM.ADR("call-method"); args[1]:=5; args[2]:=2; args[3]:=SYSTEM.ADR(method);
	args[4]:=handle; args[5]:=arg3; args[6]:=arg2; args[7]:=arg1;
	IF Call(args)=-1 THEN RETURN -1
	ELSIF args[8]#0 THEN RETURN -1
	ELSE RETURN args[9]
	END
END CallMethod3;

PROCEDURE CallMethod4*(method : ARRAY OF CHAR; handle, arg1, arg2, arg3, arg4 : LONGINT) : LONGINT;
VAR args : Args;
BEGIN
	args[0]:=SYSTEM.ADR("call-method"); args[1]:=6; args[2]:=2; args[3]:=SYSTEM.ADR(method);
	args[4]:=handle; args[5]:=arg4; args[6]:=arg3; args[7]:=arg2; args[8]:=arg1;
	IF Call(args)=-1 THEN RETURN -1
	ELSIF args[9]#0 THEN RETURN -1
	ELSE RETURN args[10]
	END
END CallMethod4;

PROCEDURE Enter*(dummy : LONGINT);
(* dummy is never used, but we don't want the user to invoke OFW.Enter as a command!! *)
VAR args : Args; res : LONGINT;
BEGIN
	args[0]:=SYSTEM.ADR("enter"); args[1]:=0; args[2]:=0;
	res:=Call(args)
END Enter;

BEGIN
	SYSTEM.GETREG(0,entry); (* Store address of OFW client service handler *)
	(* You better don't do anything that needs DIV/MOD/Heap/... here, because Kernel isn't initialized yet! *)
END OFW.