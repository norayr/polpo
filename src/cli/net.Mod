MODULE net;  (** minimal network tools over Sockets; addresses only until DNS *)

(* net.Get address port [path]    HTTP/1.0 GET, prints the answer
   net.Send address port text     sends text, prints what comes back
   net.Echo port [count]          echoes count connections (default 1), IPv6 and IPv4
   net.UDP address port text      sends a datagram, prints the answer
   net.Address text ...           the addresses in normal form *)

IMPORT Texts := texts, Sockets, out;

PROCEDURE Number(VAR s: ARRAY OF CHAR; VAR n: LONGINT): BOOLEAN;
VAR i: LONGINT;
BEGIN
  n := 0; i := 0;
  IF (s[0] < "0") OR (s[0] > "9") THEN RETURN FALSE END;
  WHILE (s[i] >= "0") & (s[i] <= "9") DO n := n * 10 + ORD(s[i]) - ORD("0"); INC(i) END;
  RETURN s[i] = 0X
END Number;

PROCEDURE Error(what: ARRAY OF CHAR; res: LONGINT);
BEGIN out.String("net: "); out.String(what); out.String(" failed, error "); out.Int(-res, 0); out.Ln
END Error;

(* print everything s receives until the other side closes *)
PROCEDURE Print(s: Sockets.Socket);
VAR buf: ARRAY 4096 OF CHAR; n, i: LONGINT;
BEGIN
  n := Sockets.Receive(s, buf, LEN(buf));
  WHILE n > 0 DO
    i := 0; WHILE i < n DO IF buf[i] # 0DX THEN out.Char(buf[i]) END; INC(i) END;  (* CR LF: out.Char(0DX) is a line end *)
    n := Sockets.Receive(s, buf, LEN(buf))
  END;
  IF n < 0 THEN Error("receive", n) END
END Print;

(* the address and port arguments *)
PROCEDURE Target(VAR A: Texts.Reader; VAR a: Sockets.Address; VAR port: LONGINT): BOOLEAN;
VAR s: ARRAY 256 OF CHAR;
BEGIN
  IF ~Texts.Arg(A, s) OR ~Sockets.ParseAddress(s, a) THEN out.String("net: an IPv4 or IPv6 address expected"); out.Ln; RETURN FALSE END;
  IF ~Texts.Arg(A, s) OR ~Number(s, port) THEN out.String("net: a port expected"); out.Ln; RETURN FALSE END;
  RETURN TRUE
END Target;

(** net.Get address port [path] -- HTTP/1.0 GET *)
PROCEDURE Get*;
VAR A: Texts.Reader; a: Sockets.Address; port, r: LONGINT; path, host, req: ARRAY 512 OF CHAR; s: Sockets.Socket; i, j: LONGINT;
BEGIN
  Texts.OpenArgs(A);
  IF ~Target(A, a, port) THEN RETURN END;
  IF ~Texts.Arg(A, path) THEN path := "/" END;
  s := Sockets.Connect(a, port);
  IF s = NIL THEN Error("connect", Sockets.res); RETURN END;
  Sockets.AddressToString(a, host);
  req := "GET "; i := 4; j := 0; WHILE path[j] # 0X DO req[i] := path[j]; INC(i); INC(j) END;

  req[i] := 0X;
  r := Sockets.SendString(s, req); r := Sockets.SendString(s, " HTTP/1.0");
  req[0] := 0DX; req[1] := 0AX; req[2] := 0X;
  r := Sockets.SendString(s, req); r := Sockets.SendString(s, "Host: "); r := Sockets.SendString(s, host);
  r := Sockets.SendString(s, req); r := Sockets.SendString(s, req);
  IF r < 0 THEN Error("send", r) ELSE Print(s) END;
  Sockets.Close(s)
END Get;

(** net.Send address port text -- send text and print what comes back *)
PROCEDURE Send*;
VAR A: Texts.Reader; a: Sockets.Address; port, r: LONGINT; text: ARRAY 1024 OF CHAR; s: Sockets.Socket;
BEGIN
  Texts.OpenArgs(A);
  IF ~Target(A, a, port) THEN RETURN END;
  IF ~Texts.Arg(A, text) THEN text := "" END;
  s := Sockets.Connect(a, port);
  IF s = NIL THEN Error("connect", Sockets.res); RETURN END;
  r := Sockets.SendString(s, text);
  IF r < 0 THEN Error("send", r) ELSE Sockets.Shutdown(s, 1); Print(s) END;
  Sockets.Close(s)
END Send;

(** net.Echo port [count] -- echo count connections, then stop *)
PROCEDURE Echo*;
VAR A: Texts.Reader; arg, peer: ARRAY 256 OF CHAR; port, count, pport, n, r: LONGINT;
  l, c: Sockets.Socket; a: Sockets.Address; buf: ARRAY 4096 OF CHAR;
BEGIN
  Texts.OpenArgs(A);
  IF ~Texts.Arg(A, arg) OR ~Number(arg, port) THEN out.String("usage: net.Echo port [count]"); out.Ln; RETURN END;
  IF ~Texts.Arg(A, arg) OR ~Number(arg, count) THEN count := 1 END;
  l := Sockets.Listen(Sockets.Inet6, port, 8);
  IF l = NIL THEN Error("listen", Sockets.res); RETURN END;
  out.String("net: echoing on port "); out.Int(port, 0); out.Ln;
  WHILE count > 0 DO
    c := Sockets.Accept(l, a, pport);
    IF c = NIL THEN Error("accept", l.res); count := 0
    ELSE
      Sockets.AddressToString(a, peer);
      out.String("net: connection from "); out.String(peer); out.String(" port "); out.Int(pport, 0); out.Ln;
      n := Sockets.Receive(c, buf, LEN(buf));
      WHILE n > 0 DO r := Sockets.Send(c, buf, n); n := Sockets.Receive(c, buf, LEN(buf)) END;
      Sockets.Close(c); DEC(count)
    END
  END;
  Sockets.Close(l)
END Echo;

(** net.UDP address port text -- send a datagram, print the answer and who sent it *)
PROCEDURE UDP*;
VAR A: Texts.Reader; a, from: Sockets.Address; port, fport, n, i: LONGINT; text, t: ARRAY 1024 OF CHAR; s: Sockets.Socket;
BEGIN
  Texts.OpenArgs(A);
  IF ~Target(A, a, port) THEN RETURN END;
  IF ~Texts.Arg(A, text) THEN text := "" END;
  s := Sockets.OpenUDP(a.family, 0);
  IF s = NIL THEN Error("socket", Sockets.res); RETURN END;
  n := 0; WHILE text[n] # 0X DO INC(n) END;
  n := Sockets.SendTo(s, a, port, text, n);
  IF n < 0 THEN Error("send", n)
  ELSE
    n := Sockets.ReceiveFrom(s, text, LEN(text), from, fport);
    IF n < 0 THEN Error("receive", n)
    ELSE
      Sockets.AddressToString(from, t); out.String(t); out.String(" port "); out.Int(fport, 0); out.String(": ");
      i := 0; WHILE i < n DO out.Char(text[i]); INC(i) END; out.Ln
    END
  END;
  Sockets.Close(s)
END UDP;

(** net.Address text -- the address in normal form, or "invalid" *)
PROCEDURE Address*;
VAR A: Texts.Reader; arg, t: ARRAY 256 OF CHAR; a: Sockets.Address;
BEGIN
  Texts.OpenArgs(A);
  WHILE Texts.Arg(A, arg) DO
    out.String(arg); out.String(" -> ");
    IF Sockets.ParseAddress(arg, a) THEN Sockets.AddressToString(a, t); out.String(t) ELSE out.String("invalid") END;
    out.Ln
  END
END Address;

END net.
