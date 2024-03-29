�TextDocs.NewDoc     ���#   Oberon10.Scn.Fnt  FE   FE  (* OBERON System 3, Release 2.3.

Copyright 1999 ETH Z�rich Institute for Computer Systems, 
ETH Center, CH-8092 Z�rich. e-mail: oberon@inf.ethz.ch.

This module may be used under the conditions of the general Oberon 
System 3 license contract. The full text can be downloaded from

	"ftp://ftp.inf.ethz.ch/pub/software/Oberon/System3/license.txt;A"

Under the license terms stated it is in particular (a) prohibited to modify
the interface of this module in any way that disagrees with the style
or content of the system and (b) requested to provide all conversions
of the source code to another platform with the name OBERON. *)

MODULE NetSystem;	(** portable *)	(* mg 16.08.96 *)	(* pjm *)

(* A Portable Oberon Interface to Internet Protocols *)

IMPORT SYSTEM, Kernel, Modules, NetBase, NetIP, NetDNS, NetSystem0, Input, Texts, Oberon, Fonts;

CONST
	anyport* = NetSystem0.anyport;	(** any port value *)

(** result values *)
	done* = NetSystem0.done;	(** everything went ok *)
	error* = NetSystem0.error;	(** failure occured *)

(** return values of procedure State *)
	closed* = NetSystem0.closed;	(** connection is closed (neither sending nor receiving) *)
	listening* = NetSystem0.listening;	(** passive connection is listening for a request *)
	in* = NetSystem0.in;	(** receiving only *)
	out* = NetSystem0.out;	(** sending only *)
	inout* = NetSystem0.inout;	(** sending and receiving is possible *)
	waitCon* =  NetSystem0.waitCon;	(** still waiting to be connected *)
	errorCon* =  NetSystem0.errorCon;	(** connecting failed *)

TYPE
	Connection* = NetSystem0.Connection;	(** handle for TCP connections *)
	ConnectionDesc* = NetSystem0.ConnectionDesc;

	IPAdr* = NetSystem0.IPAdr; (** IP address in network byte order *)

	Socket* = NetSystem0.Socket;	(** handle for UDP "connections" *)
	SocketDesc* = NetSystem0.SocketDesc;

VAR
	anyIP*: NetSystem0.IPAdr;	(** "NIL" ip-number *)
	allIP*: NetSystem0.IPAdr;	(** broadcast ip-number *)
	hostIP*: NetSystem0.IPAdr;	(** main ip-number of local machine *)
	hostName*: ARRAY 64 OF CHAR;	(** main name of local machine *)
	W: Texts.Writer;
	hex: ARRAY 17 OF CHAR;
	task: Oberon.Task;

PROCEDURE AdrToStr(netAdr: ARRAY OF SYSTEM.BYTE;  VAR net: ARRAY OF CHAR);
VAR i, j: LONGINT;
BEGIN
	j := 0;
	FOR i := 0 TO NetBase.MacAdrLen-1 DO
		net[j] := hex[ORD(netAdr[i]) DIV 10H MOD 10H];
		net[j+1] := hex[ORD(netAdr[i]) MOD 10H];
		net[j+2] := ":";  INC(j, 3)
	END;
	DEC(j);  net[j] := 0X
END AdrToStr;

(** -- Adressing/Naming section. *)

(** Convert a dotted IP address string (e.g. "1.2.3.4") to an IPAdr value. *)

PROCEDURE ToHost* (num: ARRAY OF CHAR; VAR adr: IPAdr; VAR done: BOOLEAN);
BEGIN
	NetSystem0.ToHost(num, adr, done)
END ToHost;

(** Convert an IPAdr value to a dotted IP address string *)

PROCEDURE ToNum*(adr: IPAdr; VAR num: ARRAY OF CHAR);
BEGIN
	NetSystem0.ToNum(adr, num)
END ToNum;

(** Procedure delivers the ip-number of a named host. If a symbolic name is given, it will be resolved by use of domain name
	servers. *)

PROCEDURE GetIP* (name: ARRAY OF CHAR; VAR IP: IPAdr);
BEGIN
	NetSystem0.GetIP(name, IP)
END GetIP;

(** GetName is the reverse of GetIP. Given an ip-number, it delivers the name of a host. *)

PROCEDURE GetName* (IP: IPAdr; VAR name: ARRAY OF CHAR);
BEGIN
	NetSystem0.GetName(IP, name)
END GetName;

(** -- TCP section. *)

(* Stream oriented communication *)

(** Procedure opens a connection. locPort, remPort, remIP are contained in the quadrupel <locIP, remIP, locPort, remPort>
	which determines a connection uniquely. As locIP is always the current machine, it is omitted. If remPort is equal to
	anyport or remIP is equal to anyIP, a passive connection will be opened. After execution, C is a brand new connection.
	res indicates any error. *)

PROCEDURE OpenConnection* (VAR C: Connection; locPort: INTEGER; remIP: IPAdr; remPort: INTEGER; VAR res: INTEGER);
BEGIN
	NetSystem0.OpenConnection(C, locPort, remIP, remPort, res)
END OpenConnection;

(** Like OpenConnection, but this procedure may return immediately and delay the actual opening of the connection.  
	In this case State() should be checked to wait for the connection status to change from waitCon. *)

PROCEDURE AsyncOpenConnection*(VAR C: Connection; locPort: INTEGER; remIP: IPAdr; remPort:INTEGER; VAR res: INTEGER);
BEGIN
	NetSystem0.AsyncOpenConnection(C, locPort, remIP, remPort, res)
END AsyncOpenConnection;

(** Procedure closes the connection. Connection can not be used for send operations afterwards. *)

PROCEDURE CloseConnection* (C: Connection);
BEGIN
	NetSystem0.CloseConnection(C)
END CloseConnection;

(** Indicates whether there exists a remote machine which wants to connect to the local one. This Procedure is only useful
	on passive connections. For active connections (State(C) # listen), it always delivers FALSE. *)

PROCEDURE Requested* (C: Connection): BOOLEAN;
BEGIN
	RETURN NetSystem0.Requested(C)
END Requested;

(** Procedure accepts a new waiting, active connection (newC) on a passive one (State(C) = listen). If no connection is 
	waiting, accept blocks until there is one or an error occurs. If C is not a passive connection, Accept does nothing
	but res is set to Done. *)

PROCEDURE Accept* (C: Connection; VAR newC: Connection; VAR res: INTEGER);
BEGIN
	NetSystem0.Accept(C, newC, res)
END Accept;

(** Procedure returns the state of a connection (see constant section). *)

PROCEDURE State* (C: Connection): INTEGER;
BEGIN
	RETURN NetSystem0.State(C)
END State;

(** Returns the number of bytes which may be read without blocking. *)

PROCEDURE Available* (C: Connection): LONGINT;
BEGIN
	RETURN NetSystem0.Available(C)
END Available;

(** Blocking read a single byte. *)

PROCEDURE Read* (C: Connection; VAR ch: CHAR);
BEGIN
	NetSystem0.Read(C, ch)
END Read;

(** Blocking read len bytes of data (beginning at pos in buf) to buf. *)

PROCEDURE ReadBytes* (C: Connection; pos, len: LONGINT; VAR buf: ARRAY OF SYSTEM.BYTE);
BEGIN
	NetSystem0.ReadBytes(C, pos, len, buf)
END ReadBytes;

(** Blocking read two bytes in network byte ordering. *)

PROCEDURE ReadInt* (C: Connection; VAR x: INTEGER);
BEGIN
	NetSystem0.ReadInt(C, x)
END ReadInt;

(** Blocking read four bytes in network byte ordering. *)

PROCEDURE ReadLInt* (C: Connection; VAR x: LONGINT);
BEGIN
	NetSystem0.ReadLInt(C, x)
END ReadLInt;

(** Blocking read a string terminated by ( [CR]LF | 0X ). *)

PROCEDURE ReadString* (C: Connection; VAR s: ARRAY OF CHAR);
BEGIN
	NetSystem0.ReadString(C, s)
END ReadString;

(** Blocking write a single byte to C. *)

PROCEDURE Write* (C: Connection; ch: CHAR);
BEGIN
	NetSystem0.Write(C, ch)
END Write;

(** Blocking write len bytes of data (beginning at pos in buf) to C. *)

PROCEDURE WriteBytes* (C: Connection; pos, len: LONGINT; VAR buf: ARRAY OF SYSTEM.BYTE);
BEGIN
	NetSystem0.WriteBytes(C, pos, len, buf)
END WriteBytes;

(** Blocking write two bytes in network byte ordering to C. *)

PROCEDURE WriteInt* (C: Connection; x: INTEGER);
BEGIN
	NetSystem0.WriteInt(C, x)
END WriteInt;

(** Blocking write four bytes in network byte ordering to C. *)

PROCEDURE WriteLInt* (C: Connection; x: LONGINT);
BEGIN
	NetSystem0.WriteLInt(C, x)
END WriteLInt;

(** Blocking write a string without "0X" and terminated by "CRLF" to C. *)

PROCEDURE WriteString* (C: Connection; s: ARRAY OF CHAR);
BEGIN
	NetSystem0.WriteString(C, s)
END WriteString;

(** Procedure delivers the ip-number and port number of a connection's remote partner. *)

PROCEDURE GetPartner* (C: Connection; VAR remIP: IPAdr; VAR remPort: INTEGER);
BEGIN
	NetSystem0.GetPartner(C, remIP, remPort)
END GetPartner;

(** -- UDP section. *)

(* Datagram oriented communication *)

(** Opens a socket which is dedicated to datagram services. locPort is registered to receive datagrams
	from any port and any host. *)

PROCEDURE OpenSocket* (VAR S: Socket; locPort: INTEGER; VAR res: INTEGER);
BEGIN
	NetSystem0.OpenSocket(S, locPort, res)
END OpenSocket;

(** Closes the socket. You can not receive datagrams anymore. *)

PROCEDURE CloseSocket* (S: Socket);
BEGIN
	NetSystem0.CloseSocket(S)
END CloseSocket;

(** Sends len bytes of data (beginning at pos in buf) to the host specified by remIP and remPort. *)

PROCEDURE SendDG* (S: Socket; remIP: IPAdr; remPort: INTEGER; pos, len: LONGINT; VAR buf: ARRAY OF SYSTEM.BYTE);
BEGIN
	NetSystem0.SendDG(S, remIP, remPort, pos, len, buf)
END SendDG;

(** Stores an entire datagram in buf beginning at pos. On success (S.res = done), remIP and remPort indicate the sender,
	len indicate the length of valid data. *)

PROCEDURE ReceiveDG*(S: Socket; VAR remIP: IPAdr; VAR remPort: INTEGER; pos: LONGINT; VAR len: LONGINT;
	VAR buf: ARRAY OF SYSTEM.BYTE);
BEGIN
	NetSystem0.ReceiveDG(S, remIP, remPort, pos, len, buf)
END ReceiveDG;

(** Returns the size of the first available datagram on the socket. *)

PROCEDURE AvailableDG* (S: Socket): LONGINT;
BEGIN
	RETURN NetSystem0.AvailableDG(S)
END AvailableDG;

(* Conversions *)

(** Write 2 bytes in network byte ordering to buf[pos]. *)

PROCEDURE PutInt* (VAR buf: ARRAY OF SYSTEM.BYTE; pos: INTEGER; x: INTEGER);
BEGIN
	NetSystem0.PutInt(buf, pos, x)
END PutInt;

(** Write 4 bytes in network byte ordering to buf[pos]. *)

PROCEDURE PutLInt* (VAR buf: ARRAY OF SYSTEM.BYTE; pos: INTEGER; x: LONGINT);
BEGIN
	NetSystem0.PutLInt(buf, pos, x)
END PutLInt;

(** Read 2 bytes in network byte ordering from buf[pos]. *)

PROCEDURE GetInt* (VAR buf: ARRAY OF SYSTEM.BYTE; pos: INTEGER; VAR x: INTEGER);
BEGIN
	NetSystem0.GetInt(buf, pos, x)
END GetInt;

(** Read 4 bytes in network byte ordering from buf[pos]. *)

PROCEDURE GetLInt* (VAR buf: ARRAY OF SYSTEM.BYTE; pos: INTEGER; VAR x: LONGINT);
BEGIN
	NetSystem0.GetLInt(buf, pos, x)
END GetLInt;

(** -- Passwords section. *)

PROCEDURE WriteURL(VAR service, user, host: ARRAY OF CHAR);
BEGIN
	Texts.WriteString(W, "NetSystem.SetUser ");  Texts.WriteString(W, service);  
	Texts.Write(W, ":");  Texts.WriteString(W, user);  Texts.Write(W, "@");  
	Texts.WriteString(W, host);  Texts.WriteString(W, " ~"); Texts.WriteLn(W)
END WriteURL;

(** Retrieve the password for user using service on host.  Parameters service, host and user must be specified. 
Parameter user is in/out.  If empty, it returns the first (user,password) pair found, otherwise it returns the
specified user's password. *)

PROCEDURE GetPassword*(service, host: ARRAY OF CHAR;  VAR user, password: ARRAY OF CHAR);
VAR r: Texts.Reader;  ch: CHAR;
BEGIN
	NetSystem0.GetPassword(service, host, user, password);
	IF (password = "") & (service # "") & (user # "") THEN
		IF Oberon.Log.len > 0 THEN
			Texts.OpenReader(r, Oberon.Log, Oberon.Log.len-1);
			Texts.Read(r, ch);
			IF ch # CHR(13) THEN Texts.WriteLn(W) END
		END;
		WriteURL(service, user, host);  Texts.Append(Oberon.Log, W.buf)
	END
END GetPassword;

(** Remove password for user using service on host. *)

PROCEDURE DelPassword*(service, user, host: ARRAY OF CHAR);
BEGIN
	NetSystem0.DelPassword(service, user, host)
END DelPassword;

PROCEDURE Reboot;
VAR cmd: Modules.Command;  m: Modules.Module;
BEGIN
	m := Modules.ThisMod("System");
	IF m # NIL THEN
		cmd := Modules.ThisCommand(m, "Reboot");
		IF cmd # NIL THEN cmd END
	END
END Reboot;

PROCEDURE InputRead(VAR ch: CHAR);	(* not really clean *)
BEGIN
	WHILE Input.Available() = 0 DO NetBase.Poll END;
	Input.Read(ch);
	IF ch = 0FFX THEN Reboot END
END InputRead;

(** Command NetSystem.SetUser { service ":" ["//"] [ user [ ":" password ] "@" ] host [ "/" ] } "~" <enter password>
		If password is not specified in-line, prompts for the password for the (service, host, user) triple. 
		The (service, host, user, password) 4-tuple is stored in memory for retrieval with GetPassword. 
		Multiple identical passwords may be set with one command. *)
		
PROCEDURE SetUser*;
	VAR
		R: Texts.Reader;
		service, usr, host, pwd, entered: ARRAY 64 OF CHAR;
		ok: BOOLEAN;
		ch: CHAR;

	PROCEDURE Next(VAR str: ARRAY OF CHAR);
		VAR i: LONGINT;
	BEGIN
		Texts.Read(R, ch);
		WHILE ~R.eot & ((ch <= " ") OR (ch = ":") OR (ch = "@") OR (ch = "/") OR ~(R.lib IS Fonts.Font)) DO
			Texts.Read(R, ch)
		END;
		i := 0;
		WHILE ~R.eot & (ch > " ") & (ch # ":") & (ch # "@") & (ch # "/") & (ch # "~") & (R.lib IS Fonts.Font) DO
			str[i] := ch; INC(i); Texts.Read(R, ch)
		END;
		str[i] := 0X
	END Next;
	
	PROCEDURE InputStr(prompt: ARRAY OF CHAR; show: BOOLEAN; VAR str: ARRAY OF CHAR);
		VAR i: LONGINT; ch: CHAR;
	BEGIN
		Texts.SetColor(W, 1); Texts.WriteString(W, prompt); Texts.SetColor(W, 15);
		Texts.Append(Oberon.Log, W.buf);
		InputRead(ch); i := 0;
		WHILE (ch # 0DX) & (ch # 1AX)  DO
			IF ch = 7FX THEN
				IF i > 0 THEN
					Texts.Delete(Oberon.Log, Oberon.Log.len-1, Oberon.Log.len);
					DEC(i)
				END
			ELSE
				IF show THEN Texts.Write(W, ch) ELSE Texts.Write(W, "*") END;
				Texts.Append(Oberon.Log, W.buf);
				str[i] := ch;  INC(i)
			END;
			InputRead(ch)
		END;
		IF ch # 0DX THEN i := 0 END;
		str[i] := 0X;
		Texts.WriteLn(W);  Texts.Append(Oberon.Log, W.buf)
	END InputStr;
		
BEGIN
	Texts.OpenReader(R, Oberon.Par.text, Oberon.Par.pos);
	ok := TRUE;  entered[0] := 0X;
	WHILE ~R.eot & ok DO
		ok := FALSE;  Next(service);
		IF service = "\v" THEN Next(service) END;
		NetSystem0.Lower(service, service);
		IF ch = ":" THEN
			Next(usr);
			IF ch = ":" THEN	(* password specified in-line *)
				Next(pwd);
				IF ch = "@" THEN Next(host) ELSE COPY(pwd, host); pwd[0] := 0X END
			ELSIF ch = "@" THEN	(* no password specified in-line *)
				pwd[0] := 0X; Next(host)
			ELSE	(* no user or password specified *)
				COPY(usr, host); usr[0] := 0X; pwd[0] := 0X
			END;
			NetSystem0.Lower(host, host);
			IF host[0] # 0X THEN
				IF (usr[0] = 0X) OR ((pwd[0] = 0X) & (entered[0] = 0X)) THEN
					Texts.WriteString(W, service);  Texts.WriteString(W, "://");
					Texts.WriteString(W, host);  Texts.WriteLn(W)
				END;
				IF usr[0] = 0X THEN	(* no user specified, prompt *)
					InputStr("Enter user name: ", TRUE, usr);
					IF usr[0] = 0X THEN RETURN END
				END;
				IF pwd[0] = 0X THEN	(* no pwd specified *)
					IF entered[0] = 0X THEN	(* prompt first time *)
						InputStr("Enter password: ", FALSE, entered);
						IF entered[0] = 0X THEN RETURN END	(* esc *)
					END;
					pwd := entered
				END;
				NetSystem0.ReplPassword(service, host, usr, pwd);
				Texts.WriteString(W, service);  Texts.Write(W, ":");  
				Texts.WriteString(W, usr);  Texts.Write(W, "@");  Texts.WriteString(W, host);
				Texts.WriteString(W, " password set");
				Texts.WriteLn(W);  Texts.Append(Oberon.Log, W.buf);
				ok := TRUE
			END
		END
	END
END SetUser;

(** Command NetSystem.ClearUser ~  Clear all passwords from memory. *)

PROCEDURE ClearUser*;
BEGIN
	NetSystem0.ClearPasswords
END ClearUser;

PROCEDURE PollDevices(me: Oberon.Task);
BEGIN
	NetBase.Poll
END PollDevices;

(** -- Initialisation section. *)

(** Command NetSystem.Start ~  Start up NetSystem (assume NetSystem0 already started). *)

PROCEDURE Start*;
BEGIN
	IF task = NIL THEN
		NEW(task);  task.safe := TRUE; task.time := Oberon.Time();  task.handle := PollDevices;
		Oberon.Install(task);
		(*Texts.WriteString(W, "NetSystem started");
		Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)*)
	END;
	hostIP := NetSystem0.hostIP;
	COPY(NetSystem0.hostName, hostName)
END Start;

(** Command NetSystem.Stop ~  Shut down NetSystem (but not NetSystem0). *)

PROCEDURE Stop*;
BEGIN
	IF task # NIL THEN Oberon.Remove(task); task := NIL END;
	hostName := "";
	(*Texts.WriteString(W, "NetSystem stopped");
	Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)*)
END Stop;

(** Command NetSystem.Show ~  Display status. *)

PROCEDURE Show*;
VAR s: ARRAY 32 OF CHAR;  r: NetIP.Route;  dev: NetBase.Device;  i: LONGINT;  (*p: Password;*)
BEGIN
(*
	p := passwords;  WHILE p # NIL DO WriteURL(p.service, p.user, p.host); p := p.next END;
	Texts.WriteString(W, "Host: ");  ToNum(hostIP, s);  Texts.WriteString(W, s);  
	Texts.WriteString(W, " / ");  Texts.WriteString(W, hostName);
	Texts.WriteString(W, " / ");  Texts.WriteString(W, NetDNS.dom[0]);
	Texts.WriteLn(W);
*)
	i := 0;
	LOOP
		dev := NetBase.FindDevice(i);
		IF dev = NIL THEN EXIT END;
		Texts.WriteString(W, "Device");  Texts.WriteInt(W, i, 1);
		Texts.WriteString(W, ": ");
		CASE dev.state OF
			NetBase.closed: Texts.WriteString(W, "closed")
			|NetBase.open: Texts.WriteString(W, "open")
			|NetBase.pending: Texts.WriteString(W, "pending")
			ELSE Texts.WriteInt(W, dev.state, 1)
		END;
		Texts.Write(W, " ");
		AdrToStr(dev.hostAdr, s);  Texts.WriteString(W, s);  Texts.WriteString(W, " / ");
		AdrToStr(dev.castAdr, s);  Texts.WriteString(W, s);
		Texts.WriteLn(W);
		INC(i)
	END;
	FOR i := 0 TO NetIP.nofRoutes-1 DO
		r := NetIP.routes[i];
		Texts.WriteString(W, "Route");  Texts.WriteInt(W, i, 1);  Texts.WriteString(W, ": ");
		ToNum(SYSTEM.VAL(IPAdr, r.adr), s);  Texts.WriteString(W, s);  Texts.WriteString(W, " / ");
		ToNum(SYSTEM.VAL(IPAdr, r.subnet), s);  Texts.WriteString(W, s);  Texts.WriteString(W, " / ");
		ToNum(SYSTEM.VAL(IPAdr, r.gway), s);  Texts.WriteString(W, s);  Texts.WriteString(W, " -> ");
		Texts.WriteInt(W, r.dev.num, 1);
		IF NetIP.arpopt IN r.options THEN Texts.WriteString(W, " arp")
		ELSE Texts.WriteString(W, " noarp")
		END;
		Texts.WriteLn(W)
	END;
	Texts.WriteString(W, "DNS: ");
	FOR i := 0 TO NetDNS.nofdns-1 DO
		ToNum(SYSTEM.VAL(IPAdr, NetDNS.server[i].adr), s);  Texts.WriteString(W, s);
		IF i = NetDNS.dns THEN Texts.Write(W, "*") END;
		IF i # NetDNS.nofdns-1 THEN Texts.WriteString(W, " / ") END
	END;
	Texts.WriteLn(W);
	Texts.Append(Oberon.Log, W.buf)
END Show;

BEGIN
	task := NIL;
	anyIP := NetSystem0.anyIP;
	allIP := NetSystem0.allIP;
	hostName := "";
	hex := "0123456789ABCDEF";
	Texts.OpenWriter(W);
	Start;  Kernel.InstallTermHandler(Stop)
END NetSystem.
