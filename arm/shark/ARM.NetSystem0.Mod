�TextDocs.NewDoc     ���?   Oberon10.Scn.Fnt  �#              l.   zW  (* OBERON System 3, Release 2.3.

Copyright 1999 ETH Z�rich Institute for Computer Systems, 
ETH Center, CH-8092 Z�rich. e-mail: oberon@inf.ethz.ch.

This module may be used under the conditions of the general Oberon 
System 3 license contract. The full text can be downloaded from

	"ftp://ftp.inf.ethz.ch/pub/software/Oberon/System3/license.txt;A"

Under the license terms stated it is in particular (a) prohibited to modify
the interface of this module in any way that disagrees with the style
or content of the system and (b) requested to provide all conversions
of the source code to another platform with the name OBERON. *)

MODULE NetSystem0;	(** portable *)	(* mg 16.08.96 *)	(* pjm *)

(* A Portable Oberon Interface to Internet Protocols *)

IMPORT SYSTEM, Kernel, NetBase, NetPorts, NetIP, NetUDP, NetTCP, NetDNS, OFW, CS8900;

CONST
	anyport* = 0;	(** any port value *)

(** result values *)
	done* = 0;	(** everything went ok *)
	error* = 1;	(** failure occured *)

(** return values of procedure State *)
	closed* = 0;	(** connection is closed (neither sending nor receiving) *)
	listening* = 1;	(** passive connection is listening for a request *)
	in* = 2;	(** receiving only *)
	out* = 3;	(** sending only *)
	inout* = 4;	(** sending and receiving is possible *)
	waitCon* =  5;	(** still waiting to be connected *)
	errorCon* =  6;	(** connecting failed *)

	CR = 0DX;  LF = 0AX;

	Trace = FALSE;

TYPE
	Connection* = POINTER TO ConnectionDesc;	(** handle for TCP connections *)
	ConnectionDesc* = RECORD
		port: NetPorts.Port;
		res*: INTEGER;	(** result of last operation on a connection (error indication) *)
		state: INTEGER;
		Available: PROCEDURE (C: Connection; VAR res: INTEGER): LONGINT;
		Receive: PROCEDURE (C: Connection; VAR buf: ARRAY OF SYSTEM.BYTE; beg, len: LONGINT; VAR res: INTEGER);
		Send: PROCEDURE (C: Connection; VAR buf: ARRAY OF SYSTEM.BYTE; beg, len: LONGINT; VAR res: INTEGER);
	END;

	IPAdr* = LONGINT; (** IP address in network byte order *)

	Socket* = POINTER TO SocketDesc;	(** handle for UDP "connections" *)
	SocketDesc* = RECORD
		C: NetUDP.Connection;
		res*: INTEGER;	(** result of last operation on a connection (error indication) *)
		state: INTEGER
	END;

	Password = POINTER TO PasswordDesc;
	PasswordDesc = RECORD
		service, user, host, passwd: ARRAY 64 OF CHAR;
		next: Password
	END;

VAR
	anyIP*: IPAdr;	(** "NIL" ip-number *)
	allIP*: IPAdr;	(** broadcast ip-number *)
	hostIP*: IPAdr;	(** main ip-number of local machine *)
	hostName*: ARRAY 64 OF CHAR;	(** main name of local machine *)
	started: BOOLEAN;
	passwords: Password;

(* String support section *)

(* Convert str to all lower-case letters. *)
PROCEDURE Lower*(VAR str(* in *), lstr(* out *): ARRAY OF CHAR);
	VAR i: LONGINT; ch: CHAR;
BEGIN
	i := 0;
	REPEAT
		ch := str[i];
		IF (ch >= "A") & (ch <= "Z") THEN ch := CHR(ORD(ch)-ORD("A")+ORD("a")) END;
		lstr[i] := ch;
		INC(i)
	UNTIL ch = 0X
END Lower;

PROCEDURE ToNum0 (num: ARRAY OF CHAR; VAR n: LONGINT; VAR done: BOOLEAN);
VAR i: LONGINT;
BEGIN
	n := 0; i := 0;
	WHILE ("0" <= num[i]) & (num[i] <= "9") DO
		n := n * 10 + ORD(num[i]) - ORD("0"); INC(i)
	END;
	done := num[i] = 0X
END ToNum0;

PROCEDURE ToHost0 (num: ARRAY OF CHAR; VAR adr: NetIP.Adr; VAR done: BOOLEAN);
VAR addr: IPAdr; buf: ARRAY 32 OF CHAR; i, j, k, n: LONGINT;
BEGIN done := TRUE;
	addr := 0; i := 0; j := 0; 
	WHILE done & (j < 4) & (num[i] # 0X) DO
		k := 0;
		WHILE (num[i] # ".") & (num[i] # 0X) DO
			buf[k] := num[i]; INC(k); INC(i)
		END;
		buf[k] := 0X; ToNum0(buf, n, done);
		addr := ASH(addr, 8) + n; done := done & (n <= 256);
		IF num[i] = "." THEN INC(i) END;
		INC(j)
	END;
	adr := SYSTEM.VAL(NetIP.Adr, addr);
	NetBase.HostLToNet(adr);
	done := done & (j = 4) & (num[i] = 0X)
END ToHost0;

(** -- Adressing/Naming section. *)

(** Convert a dotted IP address string (e.g. "1.2.3.4") to an IPAdr value. *)

PROCEDURE ToHost* (num: ARRAY OF CHAR; VAR adr: IPAdr; VAR done: BOOLEAN);
BEGIN
	ToHost0(num, SYSTEM.VAL(NetIP.Adr, adr), done);
	IF ~done THEN adr := anyIP END
END ToHost;

(** Convert an IPAdr value to a dotted IP address string *)

PROCEDURE ToNum*(adr: IPAdr; VAR num: ARRAY OF CHAR);
	VAR i, j, n: LONGINT;
	PROCEDURE Digit(d: LONGINT);
	BEGIN
		num[j] := CHR(ORD("0")+d); INC(j)
	END Digit;
BEGIN
	j := 0;
	FOR i := 0 TO 3 DO
		n := adr MOD 256; adr := adr DIV 256;
		IF n >= 100 THEN
			Digit(n DIV 100); Digit((n DIV 10) MOD 10)
		ELSIF n >= 10 THEN
			Digit(n DIV 10)
		END;
		Digit(n MOD 10);
		num[j] := "."; INC(j)
	END;
	num[j-1] := 0X
END ToNum;

(** Procedure delivers the ip-number of a named host. If a symbolic name is given, it will be resolved by use of domain name
	servers. *)

PROCEDURE GetIP* (name: ARRAY OF CHAR; VAR IP: IPAdr);
VAR res: INTEGER; done: BOOLEAN;
BEGIN
	IF (CAP(name[0]) >= "A") & (CAP(name[0]) <= "Z") THEN
		IF started THEN
			NetDNS.HostByName(name, SYSTEM.VAL(NetIP.Adr, IP), res);
			done := (res = NetDNS.Done)
		ELSE
			done := FALSE
		END
	ELSIF (name[0] >= "0") & (name[0] <= "9") THEN
		ToHost0(name, SYSTEM.VAL(NetIP.Adr, IP), done)
	ELSE done := FALSE
	END;
	IF ~done THEN IP := anyIP END
END GetIP;

(** GetName is the reverse of GetIP. Given an ip-number, it delivers the name of a host. *)

PROCEDURE GetName* (IP: IPAdr; VAR name: ARRAY OF CHAR);
VAR adr: NetIP.Adr; res: INTEGER;
BEGIN
	IF started THEN
		adr := SYSTEM.VAL(NetIP.Adr, IP);
		NetDNS.HostByNumber(adr, name, res)
	END;
	IF ~started OR (res # NetDNS.Done) THEN COPY("", name) END
END GetName;

(** -- TCP section. *)

(* Stream oriented communication *)

(*
PROCEDURE TCPSetState (C: Connection);
BEGIN
	IF C.state IN {in, inout} THEN
		IF ~NetTCP.Connected(C.port(NetTCP.Connection)) THEN
			IF C.state = inout THEN C.state := out
			ELSIF C.state = in THEN C.state := closed
			END
		END
	END
END TCPSetState;
*)

PROCEDURE TCPAvailable (C: Connection; VAR res: INTEGER): LONGINT;
VAR
	len: LONGINT;
BEGIN len := NetTCP.Available(C.port(NetTCP.Connection));
	IF len < 0 THEN len := 0; res := error ELSE res := done END;
	(*TCPSetState(C);*) RETURN len
END TCPAvailable;

PROCEDURE TCPReceive (C: Connection; VAR buf: ARRAY OF SYSTEM.BYTE; beg, len: LONGINT; VAR res: INTEGER);
VAR
	l: LONGINT;
BEGIN l := 0;
	REPEAT l := len;
		NetTCP.Receive(C.port(NetTCP.Connection), buf, beg, l);
		IF l > 0 THEN beg := beg + l; len := len - l END
	UNTIL (len = 0) OR (l < 0);
	IF l < 0 THEN res := error ELSE res := done END;
	(*TCPSetState(C)*)
END TCPReceive;

PROCEDURE TCPSend (C: Connection; VAR buf: ARRAY OF SYSTEM.BYTE; beg, len: LONGINT; VAR res: INTEGER);
BEGIN NetTCP.Send(C.port(NetTCP.Connection), buf, beg, len);
	IF len < 0 THEN res := error ELSE res := done END;
	(*TCPSetState(C)*)
END TCPSend;

PROCEDURE DmyAvailable (C: Connection; VAR res: INTEGER): LONGINT;
BEGIN res := error; RETURN 0
END DmyAvailable;

PROCEDURE DmyReceive (C: Connection; VAR buf: ARRAY OF SYSTEM.BYTE; beg, len: LONGINT; VAR res: INTEGER);
BEGIN res := error
END DmyReceive;

PROCEDURE DmySend (C: Connection; VAR buf: ARRAY OF SYSTEM.BYTE; beg, len: LONGINT; VAR res: INTEGER);
BEGIN res := error
END DmySend;

PROCEDURE ^Cleanup(c: SYSTEM.PTR);

(** Procedure opens a connection. locPort, remPort, remIP are contained in the quadrupel <locIP, remIP, locPort, remPort>
	which determines a connection uniquely. As locIP is always the current machine, it is omitted. If remPort is equal to
	anyport or remIP is equal to anyIP, a passive connection will be opened. After execution, C is a brand new connection.
	res indicates any error. *)

PROCEDURE OpenConnection* (VAR C: Connection; locPort: INTEGER; remIP: IPAdr; remPort: INTEGER; VAR res: INTEGER);
VAR
	conC: NetTCP.Connection;
	listC: NetTCP.Listener;
	remAdr: NetIP.Adr;
BEGIN
	IF started THEN
		remAdr := SYSTEM.VAL(NetIP.Adr, remIP);
		 NEW(C);
		IF (remIP = anyIP) OR (remPort = NetPorts.anyport) THEN
			NetTCP.Listen(listC, locPort, remAdr, remPort, C.res);
			IF C.res = NetTCP.Done THEN C.port := listC;
				C.state := listening; C.Available := DmyAvailable;
				C.Send := DmySend; C.Receive := DmyReceive;
				Kernel.RegisterObject(C, Cleanup, FALSE)
			ELSIF C.res # NetTCP.Timeout THEN C.res := error
			END;
			res := C.res
		ELSIF ~NetIP.IsBroadcast(remAdr) THEN
			NetTCP.Connect(conC, locPort, remAdr, remPort, C.res);
			IF C.res = NetTCP.Done THEN C.port := conC;
				C.state := inout; C.Available := TCPAvailable;
				C.Send := TCPSend; C.Receive := TCPReceive;
				Kernel.RegisterObject(C, Cleanup, FALSE)
			ELSIF C.res # NetTCP.Timeout THEN C.res := error
			END;
			res := C.res
		ELSE res := error
		END
	ELSE res := error
	END
END OpenConnection;

(** Like OpenConnection, but this procedure may return immediately and delay the actual opening of the connection.  
	In this case State() should be checked to wait for the connection status to change from waitCon. *)

PROCEDURE AsyncOpenConnection*(VAR C: Connection; locPort: INTEGER; remIP: IPAdr; remPort:INTEGER; VAR res: INTEGER);
VAR conC: NetTCP.Connection; remAdr: NetIP.Adr;
BEGIN
	IF ~started OR (remIP = anyIP) OR (remPort = NetPorts.anyport) OR NetIP.IsBroadcast(remAdr) THEN
		OpenConnection(C, locPort, remIP, remPort, res)	(* same as synchronous case *)
	ELSE	(* to do: make truly asynchronous.  current same as OpenConnection. *)
		remAdr := SYSTEM.VAL(NetIP.Adr, remIP);
		NEW(C);
		NetTCP.Connect(conC, locPort, remAdr, remPort, C.res);
		IF C.res = NetTCP.Done THEN C.port := conC;
			C.state := inout; C.Available := TCPAvailable;
			C.Send := TCPSend; C.Receive := TCPReceive;
			Kernel.RegisterObject(C, Cleanup, FALSE)
		ELSIF C.res # NetTCP.Timeout THEN C.res := error
		END;
		res := C.res
	END
END AsyncOpenConnection;

(** Procedure closes the connection. Connection can not be used for send operations afterwards. *)

PROCEDURE CloseConnection* (C: Connection);
BEGIN
	IF C # NIL THEN
		IF C.port IS NetTCP.Listener THEN C.state := closed;
			NetTCP.Close(C.port(NetTCP.Listener))
		ELSIF C.port IS NetTCP.Connection THEN
			IF C.state = inout THEN C.state := in
			ELSIF C.state = out THEN C.state := closed
			END;
			NetTCP.Disconnect(C.port(NetTCP.Connection))
		ELSE HALT(99)
		END;
		C.res := done
	END
END CloseConnection;

PROCEDURE Cleanup(c: SYSTEM.PTR);
VAR s: ARRAY 20 OF CHAR;
BEGIN
	WITH c: Connection DO
		IF c.state # closed THEN
			IF Trace THEN
				Kernel.WriteString("NetSystem: Cleanup ");
				ToNum(SYSTEM.VAL(IPAdr, c.port.rip), s);  Kernel.WriteString(s);
				Kernel.WriteChar(":");  Kernel.WriteInt(c.port.rport, 1); Kernel.WriteLn
			END;
			CloseConnection(c)
		END
	END
END Cleanup;

(** Indicates whether there exists a remote machine which wants to connect to the local one. This Procedure is only useful
	on passive connections. For active connections (State(C) # listen), it always delivers FALSE. *)

PROCEDURE Requested* (C: Connection): BOOLEAN;
BEGIN RETURN (C.port IS NetTCP.Listener) & NetTCP.Requested(C.port(NetTCP.Listener))
END Requested;

(** Procedure accepts a new waiting, active connection (newC) on a passive one (State(C) = listen). If no connection is 
	waiting, accept blocks until there is one or an error occurs. If C is not a passive connection, Accept does nothing
	but res is set to Done. *)

PROCEDURE Accept* (C: Connection; VAR newC: Connection; VAR res: INTEGER);
VAR
	conC: NetTCP.Connection;
BEGIN res := NetTCP.NotDone;
	IF C.port IS NetTCP.Listener THEN
		NetTCP.Accept(C.port(NetTCP.Listener), conC, res);
		IF res = NetTCP.Done THEN NEW(newC);
			newC.port := conC; newC.state := inout;
			newC.Available := TCPAvailable;
			newC.Send := TCPSend; newC.Receive := TCPReceive
		END
	END;
	C.res := res
END Accept;

(** Procedure returns the state of a connection (see constant section). *)

PROCEDURE State* (C: Connection): INTEGER;
BEGIN
	IF C.state IN {in, inout} THEN
		IF NetTCP.Connected(C.port(NetTCP.Connection)) THEN
		ELSE
			IF C.state = inout THEN C.state := out
			ELSIF C.state = in THEN C.state := closed
			END
		END
	END;
	RETURN C.state
END State;

(** Returns the number of bytes which may be read without blocking. *)

PROCEDURE Available* (C: Connection): LONGINT;
BEGIN RETURN C.Available(C, C.res)
END Available;

(** Blocking read a single byte. *)

PROCEDURE Read* (C: Connection; VAR ch: CHAR);
BEGIN C.Receive(C, ch, 0, 1, C.res)
END Read;

(** Blocking read len bytes of data (beginning at pos in buf) to buf. *)

PROCEDURE ReadBytes* (C: Connection; pos, len: LONGINT; VAR buf: ARRAY OF SYSTEM.BYTE);
BEGIN C.Receive(C, buf, pos, len, C.res);
END ReadBytes;

(** Blocking read two bytes in network byte ordering. *)

PROCEDURE ReadInt* (C: Connection; VAR x: INTEGER);
BEGIN C.Receive(C, x, 0, 2, C.res); NetBase.NetToHost(x)
END ReadInt;

(** Blocking read four bytes in network byte ordering. *)

PROCEDURE ReadLInt* (C: Connection; VAR x: LONGINT);
BEGIN C.Receive(C, x, 0, 4, C.res); NetBase.NetLToHost(x);
END ReadLInt;

(** Blocking read a string terminated by ( [CR]LF | 0X ). *)

PROCEDURE ReadString* (C: Connection; VAR s: ARRAY OF CHAR);
VAR
	ch, ch0: CHAR;
	i: INTEGER;
BEGIN i := -1; ch := 0X;
	REPEAT INC(i);
		ch0 := ch; C.Receive(C, ch, 0, 1, C.res); s[i] := ch;
	UNTIL (C.res = error) OR (ch = 0X) OR (ch = LF);
	IF (ch = LF) & (ch0 = CR) THEN
		s[i - 1] := 0X ELSE s[i] := 0X
	END
END ReadString;

(** Blocking write a single byte to C. *)

PROCEDURE Write* (C: Connection; ch: CHAR);
BEGIN C.Send(C, ch, 0, 1, C.res)
END Write;

(** Blocking write len bytes of data (beginning at pos in buf) to C. *)

PROCEDURE WriteBytes* (C: Connection; pos, len: LONGINT; VAR buf: ARRAY OF SYSTEM.BYTE);
BEGIN C.Send(C, buf, pos, len, C.res)
END WriteBytes;

(** Blocking write two bytes in network byte ordering to C. *)

PROCEDURE WriteInt* (C: Connection; x: INTEGER);
BEGIN NetBase.HostToNet(x); C.Send(C, x, 0, 2, C.res)
END WriteInt;

(** Blocking write four bytes in network byte ordering to C. *)

PROCEDURE WriteLInt* (C: Connection; x: LONGINT);
BEGIN NetBase.HostLToNet(x); C.Send(C, x, 0, 4, C.res)
END WriteLInt;

(** Blocking write a string without "0X" and terminated by "CRLF" to C. *)

PROCEDURE WriteString* (C: Connection; s: ARRAY OF CHAR);
VAR
	cs: ARRAY 2 OF CHAR;
	i: INTEGER;
BEGIN  i := 0;
	WHILE s[i] # 0X DO INC(i) END;
	C.Send(C, s, 0, i, C.res);
	cs[0] := CR; cs[1] := LF;
	C.Send(C, cs, 0, 2, C.res)
END WriteString;

(** Procedure delivers the ip-number and port number of a connection's remote partner. *)

PROCEDURE GetPartner* (C: Connection; VAR remIP: IPAdr; VAR remPort: INTEGER);
BEGIN
	remPort := C.port.rport;
	remIP := SYSTEM.VAL(IPAdr, C.port.rip)
END GetPartner;

(** -- UDP section. *)

(* Datagram oriented communication *)

(** Opens a socket which is dedicated to datagram services. locPort is registered to receive datagrams
	from any port and any host. *)

PROCEDURE OpenSocket* (VAR S: Socket; locPort: INTEGER; VAR res: INTEGER);
BEGIN
	IF started THEN NEW(S);
		NetUDP.Open(S.C, locPort, NetIP.IPany, NetPorts.anyport, S.res);
		IF S.res = NetUDP.Done THEN S.state := inout
		ELSE S.C := NIL; S.res := error
		END;
		res := S.res
	ELSE res := error
	END
END OpenSocket;

(** Closes the socket. You can not receive datagrams anymore. *)

PROCEDURE CloseSocket* (S: Socket);
BEGIN S.state := closed; NetUDP.Close(S.C); S.C := NIL; S.res := done
END CloseSocket;

(** Sends len bytes of data (beginning at pos in buf) to the host specified by remIP and remPort. *)

PROCEDURE SendDG* (S: Socket; remIP: IPAdr; remPort: INTEGER; pos, len: LONGINT; VAR buf: ARRAY OF SYSTEM.BYTE);
BEGIN
	NetUDP.Send(S.C, SYSTEM.VAL(NetIP.Adr, remIP), remPort, buf, pos, len); S.res := done
END SendDG;

(** Stores an entire datagram in buf beginning at pos. On success (S.res = done), remIP and remPort indicate the sender,
	len indicate the length of valid data. *)

PROCEDURE ReceiveDG*(S: Socket; VAR remIP: IPAdr; VAR remPort: INTEGER; pos: LONGINT; VAR len: LONGINT;
	VAR buf: ARRAY OF SYSTEM.BYTE);
BEGIN
	NetUDP.Receive(S.C, SYSTEM.VAL(NetIP.Adr, remIP), remPort, buf, pos, len);
	IF len >= 0 THEN S.res := done ELSE S.res := error END
END ReceiveDG;

(** Returns the size of the first available datagram on the socket. *)

PROCEDURE AvailableDG* (S: Socket): LONGINT;
BEGIN RETURN NetUDP.Available(S.C)
END AvailableDG;

(* Conversions *)

(** Write 2 bytes in network byte ordering to buf[pos]. *)

PROCEDURE PutInt* (VAR buf: ARRAY OF SYSTEM.BYTE; pos: INTEGER; x: INTEGER);
BEGIN NetBase.HostToNet(x);
	SYSTEM.PUT(SYSTEM.ADR(buf[pos]), x)
END PutInt;

(** Write 4 bytes in network byte ordering to buf[pos]. *)

PROCEDURE PutLInt* (VAR buf: ARRAY OF SYSTEM.BYTE; pos: INTEGER; x: LONGINT);
BEGIN NetBase.HostLToNet(x);
	SYSTEM.PUT(SYSTEM.ADR(buf[pos]), x)
END PutLInt;

(** Read 2 bytes in network byte ordering from buf[pos]. *)

PROCEDURE GetInt* (VAR buf: ARRAY OF SYSTEM.BYTE; pos: INTEGER; VAR x: INTEGER);
BEGIN SYSTEM.GET(SYSTEM.ADR(buf[pos]), x);
	NetBase.NetToHost(x)
END GetInt;

(** Read 4 bytes in network byte ordering from buf[pos]. *)

PROCEDURE GetLInt* (VAR buf: ARRAY OF SYSTEM.BYTE; pos: INTEGER; VAR x: LONGINT);
BEGIN SYSTEM.GET(SYSTEM.ADR(buf[pos]), x);
	NetBase.NetLToHost(x)
END GetLInt;

(** -- Passwords section. *)

(** Retrieve the password for user using service on host.  Parameters service, host and user must be specified. 
Parameter user is in/out.  If empty, it returns the first (user,password) pair found, otherwise it returns the
specified user's password. *)

PROCEDURE GetPassword*(service, host: ARRAY OF CHAR;  VAR user, password: ARRAY OF CHAR);
VAR pass: Password;
BEGIN
	Lower(service, service);  Lower(host, host);
	pass := passwords;
	WHILE (pass # NIL) & ~((pass.service = service) & (pass.host = host) & ((user = "") OR (pass.user = user))) DO
		pass := pass.next
	END;
	IF pass # NIL THEN
		COPY(pass.user, user);  COPY(pass.passwd, password)
	ELSE
		password[0] := 0X
	END
END GetPassword;

(** Remove password for user using service on host. *)

PROCEDURE DelPassword*(service, user, host: ARRAY OF CHAR);
	VAR ppass, pass: Password;
BEGIN
	Lower(service, service);  Lower(host, host);
	ppass := NIL; pass := passwords;
	WHILE (pass # NIL) & ((pass.service # service) & (pass.host # host) & (pass.user # user)) DO
		ppass := pass; pass := pass.next
	END;
	IF pass # NIL THEN
		IF ppass # NIL THEN
			ppass.next := pass.next
		ELSE
			passwords := pass.next
		END
	END
END DelPassword;

(** Replace password *)

PROCEDURE ReplPassword*(service, host, user, password: ARRAY OF CHAR);
VAR p, q, prev: Password;
BEGIN
	q := passwords;  prev := NIL;
	WHILE (q # NIL) & ~((q.service = service) & (q.host = host) & (q.user = user)) DO
		prev := q;  q := q.next
	END;
	IF q # NIL THEN	(* password exists, delete old one first *)
		IF prev = NIL THEN passwords := passwords.next
		ELSE prev.next := q.next
		END
	END;
	NEW(p); COPY(service, p.service); COPY(host, p.host); COPY(user, p.user); COPY(password, p.passwd);
	p.next := passwords;  passwords := p
END ReplPassword;

(** Clear all passwords from memory. *)

PROCEDURE ClearPasswords*;
BEGIN
	passwords := NIL
END ClearPasswords;

(** -- Initialisation section. *)

PROCEDURE SetDevices;
BEGIN
	CS8900.InstallDevice()
END SetDevices;

PROCEDURE SetRoutes;
VAR route: NetIP.Route; j, chosen: LONGINT;  s: ARRAY 32 OF CHAR; dev: NetBase.Device;
BEGIN
	chosen := OFW.FindDevice("/chosen");
	dev := NetBase.FindDevice(0); ASSERT(dev # NIL);
	NEW(route);  route.dev := dev;
	INCL(route.options, NetIP.arpopt);
	IF OFW.GetProp(chosen, "client-ip", route.adr) # NetIP.AdrLen THEN HALT(99) END;
	(*COPY(hostname, hostName);*)
	hostIP := SYSTEM.VAL(IPAdr, route.adr);
		(* Get gateway from Open Firmware *)
	IF OFW.GetProp(chosen, "gateway-ip", route.gway) # NetIP.AdrLen THEN route.gway := NetIP.IPany END;
		(* Get netmask from Open Firmware *)
	IF OFW.GetProp(chosen, "netmask-ip", route.subnet) # NetIP.AdrLen THEN route.subnet := NetIP.IPany END;
	IF (anyIP = SYSTEM.VAL(LONGINT, route.gway)) & (anyIP # SYSTEM.VAL(LONGINT, route.adr)) THEN
			(* gateway not set, but host adr set - attempt auto setting *)
		FOR j := 0 TO NetIP.AdrLen-1 DO	(* take host address AND subnet mask *)
			route.gway[j] := SYSTEM.VAL(CHAR, SYSTEM.VAL(SET, LONG(ORD(route.adr[j]))) * 
					SYSTEM.VAL(SET, LONG(ORD(route.subnet[j]))))
		END;
			(* add .1 at end (common convention) *)
		route.gway[3] := SYSTEM.VAL(CHAR, SYSTEM.VAL(SET, LONG(ORD(route.gway[3]))) + {0})
	END;
	ToNum(SYSTEM.VAL(IPAdr, route.adr), s);
	Kernel.WriteString("IP: ");  Kernel.WriteString(s);
	ToNum(SYSTEM.VAL(IPAdr, route.subnet), s);
	Kernel.WriteString(", Subnet: ");  Kernel.WriteString(s);
	ToNum(SYSTEM.VAL(IPAdr, route.gway), s);
	Kernel.WriteString(", Gateway: ");  Kernel.WriteString(s);
	Kernel.WriteLn;
	NetIP.InstallRoute(route)
END SetRoutes;

PROCEDURE SetDNS;
VAR adr: NetIP.Adr; done: BOOLEAN;
BEGIN
	ToHost0("129.132.98.12", adr, done); ASSERT(done);
	NetDNS.InstallDNS("dns1.ethz.ch", adr);
	ToHost0("129.132.250.220", adr, done); ASSERT(done);
	NetDNS.InstallDNS("dns2.ethz.ch", adr);
	ToHost0("129.132.250.2", adr, done); ASSERT(done);
	NetDNS.InstallDNS("dns3.ethz.ch", adr)
END SetDNS;

(** Command NetSystem0.Start ~  Start up NetSystem. *)

PROCEDURE Start*;
VAR name, num: ARRAY 64 OF CHAR;  pos: LONGINT;  ch: CHAR;
BEGIN
	IF ~started THEN
		SetDevices;
		IF NetBase.FindDevice(0) # NIL THEN
			SetRoutes;
			NetDNS.Init;
			NetDNS.InstallDom("ethz.ch");
			SetDNS;
			started := NetIP.nofRoutes > 0;
			IF started THEN
				NetIP.SetDirectedCast(NetIP.routes[0]);
				NetBase.Start; NetIP.Start; NetPorts.Init; NetUDP.Start; NetTCP.Start;
				IF (hostName = "") & (anyIP # hostIP) THEN
					GetName(hostIP, hostName);
					Lower(hostName, hostName);
					IF hostName[0] = 0X THEN hostName := "x.oberon.ethz.ch" END
				END;
				Kernel.WriteString("NetSystem started: "); Kernel.WriteString(hostName); Kernel.WriteLn
			ELSE
				Kernel.WriteString("NetSystem not configured"); Kernel.WriteLn
			END
		ELSE
			Kernel.WriteString("No network driver configured"); Kernel.WriteLn
		END
	END
END Start;

(** Command NetSystem0.Stop ~  Shut down NetSystem. *)

PROCEDURE Stop*;
BEGIN
	NetTCP.Stop; NetUDP.Stop; NetIP.Stop; NetBase.Stop;
	hostName := ""; started := FALSE;
	Kernel.WriteString("NetSystem stopped"); Kernel.WriteLn
END Stop;

BEGIN
	anyIP := SYSTEM.VAL(IPAdr, NetIP.IPany);
	allIP := SYSTEM.VAL(IPAdr, NetIP.IPall);
	hostName := "";
	started := FALSE; passwords := NIL;
	Start;
	Kernel.InstallTermHandler(Stop)
END NetSystem0.
