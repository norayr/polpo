MODULE gemini;  (** Gemini downloads (gemini://, port 1965) over the TLS 1.3 of src/lib/tls *)

(* gemini.Get url [file]   saves the body in file (default: the last part of the path, index.gmi)
   gemini.Show url         prints the body
   A server verified by a CA (TLSCABundle) is trusted; one with a self-signed certificate is
   trusted on first use, as the Gemini specification recommends: the SHA-256 of its key is kept in
   $HOME/.gemini_hosts (lines "host:port key"), and a later key that differs is refused.
   Redirects (3x) are followed, up to 5 and to gemini:// only; a body is complete only when the
   server ended with TLS close_notify, an incomplete one is not saved. *)

IMPORT Texts := texts, Files, Kernel, TLS13Live, out;

CONST
  DefaultPort = "1965";
  MaxRedirects = 5;

TYPE
  State = POINTER TO TLS13Live.State;  (* 300 KB: on the heap *)

VAR
  s: State;

PROCEDURE Len(VAR a: ARRAY OF CHAR): LONGINT;
VAR i: LONGINT;
BEGIN i := 0; WHILE (i < LEN(a)) & (a[i] # 0X) DO INC(i) END; RETURN i
END Len;

PROCEDURE Append(VAR a: ARRAY OF CHAR; b: ARRAY OF CHAR);
VAR i, j: LONGINT;
BEGIN
  i := Len(a); j := 0;
  WHILE (j < LEN(b)) & (b[j] # 0X) & (i < LEN(a) - 1) DO a[i] := b[j]; INC(i); INC(j) END;
  a[i] := 0X
END Append;

PROCEDURE StartsWith(VAR a: ARRAY OF CHAR; b: ARRAY OF CHAR): BOOLEAN;
VAR i: LONGINT;
BEGIN
  i := 0;
  WHILE (i < LEN(b)) & (b[i] # 0X) DO
    IF (i >= LEN(a)) OR (CAP(a[i]) # CAP(b[i])) THEN RETURN FALSE END;
    INC(i)
  END;
  RETURN TRUE
END StartsWith;

(* host, port and path of a gemini:// url; url is made complete (a path "/" at least) *)
PROCEDURE Split(VAR url, host, port, path: ARRAY OF CHAR): BOOLEAN;
VAR i, j: LONGINT;
BEGIN
  IF ~StartsWith(url, "gemini://") THEN out.String("gemini: gemini:// expected: "); out.String(url); out.Ln; RETURN FALSE END;
  i := 9; j := 0;
  IF url[i] = "[" THEN  (* [IPv6] *)
    INC(i);
    WHILE (url[i] # 0X) & (url[i] # "]") & (j < LEN(host) - 1) DO host[j] := url[i]; INC(i); INC(j) END;
    IF url[i] = "]" THEN INC(i) END
  ELSE
    WHILE (url[i] # 0X) & (url[i] # ":") & (url[i] # "/") & (j < LEN(host) - 1) DO host[j] := url[i]; INC(i); INC(j) END
  END;
  host[j] := 0X; j := 0;
  IF url[i] = ":" THEN
    INC(i); WHILE (url[i] >= "0") & (url[i] <= "9") & (j < LEN(port) - 1) DO port[j] := url[i]; INC(i); INC(j) END
  END;
  port[j] := 0X; IF j = 0 THEN COPY(DefaultPort, port) END;
  j := 0;
  WHILE (url[i] # 0X) & (j < LEN(path) - 1) DO path[j] := url[i]; INC(i); INC(j) END;
  path[j] := 0X;
  IF path[0] = 0X THEN COPY("/", path); Append(url, "/") END;
  RETURN host[0] # 0X
END Split;

(* ----- trust on first use: $HOME/.gemini_hosts ----- *)

PROCEDURE HostsFile(VAR name: ARRAY OF CHAR);
BEGIN
  Kernel.GetConfig("HOME", name);
  IF name[0] = 0X THEN COPY(".", name) END;
  Append(name, "/.gemini_hosts")
END HostsFile;

(* the key kept for hostport ("host:port"), "" if none *)
PROCEDURE LoadPin(VAR hostport, pin: ARRAY OF CHAR);
VAR name, line: ARRAY 256 OF CHAR; f: Files.File; R: Files.Rider; c: CHAR; i, k: LONGINT;
BEGIN
  pin[0] := 0X; HostsFile(name);
  f := Files.Old(name);
  IF f = NIL THEN RETURN END;
  Files.Set(R, f, 0);
  LOOP
    i := 0; Files.Read(R, c);
    WHILE ~R.eof & (c # 0AX) DO IF i < LEN(line) - 1 THEN line[i] := c; INC(i) END; Files.Read(R, c) END;
    line[i] := 0X;
    k := 0; WHILE (line[k] # 0X) & (line[k] # " ") DO INC(k) END;
    IF (line[k] = " ") & (k = Len(hostport)) & StartsWith(line, hostport) THEN
      i := 0; INC(k);
      WHILE (line[k] # 0X) & (i < LEN(pin) - 1) DO pin[i] := line[k]; INC(i); INC(k) END;
      pin[i] := 0X; EXIT
    END;
    IF R.eof THEN EXIT END
  END;
  Files.ReleaseRead(f)
END LoadPin;

(* add "hostport pin" to the hosts file *)
PROCEDURE SavePin(VAR hostport, pin: ARRAY OF CHAR);
VAR name: ARRAY 256 OF CHAR; old, f: Files.File; R, W: Files.Rider; c: CHAR; line: ARRAY 160 OF CHAR;
BEGIN
  HostsFile(name);
  f := Files.New(name); Files.Set(W, f, 0);
  old := Files.Old(name);
  IF old # NIL THEN
    Files.Set(R, old, 0); Files.Read(R, c);
    WHILE ~R.eof DO Files.Write(W, c); Files.Read(R, c) END;
    Files.ReleaseRead(old)
  END;
  COPY(hostport, line); Append(line, " "); Append(line, pin);
  Files.WriteBytes(W, line, Len(line)); Files.Write(W, 0AX);
  Files.Register(f)
END SavePin;

(* ----- a request ----- *)

(* the request url to its server; status and meta of the answer; the body to the file f (Get) or
   to out (f = NIL); n: its length, complete: the server ended it with close_notify *)
PROCEDURE Request(VAR url: ARRAY OF CHAR; VAR status: LONGINT; VAR meta: ARRAY OF CHAR; name: ARRAY OF CHAR;
  VAR f: Files.File; VAR n: LONGINT; VAR complete: BOOLEAN): BOOLEAN;
VAR host, port, path, hostport, pin, req: ARRAY 1100 OF CHAR; buf: ARRAY 4096 OF CHAR;
  got, i, j, hlen: LONGINT; header: ARRAY 1100 OF CHAR; inHeader, ok: BOOLEAN; R: Files.Rider;
BEGIN
  status := 0; meta[0] := 0X; n := 0; complete := FALSE; f := NIL;
  IF Len(url) > 1024 THEN out.String("gemini: the url is longer than 1024 bytes"); out.Ln; RETURN FALSE END;
  IF ~Split(url, host, port, path) THEN RETURN FALSE END;
  COPY(host, hostport); Append(hostport, ":"); Append(hostport, port);
  LoadPin(hostport, pin);
  IF s = NIL THEN NEW(s); TLS13Live.Init(s^) END;
  IF ~TLS13Live.ConnectPinned(host, port, s^, pin) THEN
    out.String("gemini: no connection to "); out.String(hostport); out.String(": "); out.String(TLS13Live.lastError); out.Ln;
    RETURN FALSE
  END;
  IF TLS13Live.pinned & (pin[0] = 0X) THEN
    out.String("gemini: trusting the key of "); out.String(hostport); out.String(" on first use: ");
    out.String(TLS13Live.keyPin); out.Ln;
    COPY(TLS13Live.keyPin, pin); SavePin(hostport, pin)
  END;
  COPY(url, req); i := Len(req); req[i] := 0DX; req[i+1] := 0AX; req[i+2] := 0X;
  IF ~TLS13Live.WriteAppString(s^, req) THEN
    out.String("gemini: the request could not be sent"); out.Ln; TLS13Live.Disconnect(s^); RETURN FALSE
  END;
  inHeader := TRUE; hlen := 0;
  WHILE TLS13Live.ReadAppMax(s^, buf, LEN(buf), got) DO
    i := 0;
    IF inHeader THEN  (* <STATUS><SPACE><META><CR><LF> *)
      WHILE (i < got) & inHeader DO
        IF buf[i] = 0AX THEN inHeader := FALSE
        ELSIF hlen < LEN(header) - 1 THEN header[hlen] := buf[i]; INC(hlen)
        END;
        INC(i)
      END;
      IF ~inHeader THEN
        IF (hlen > 0) & (header[hlen - 1] = 0DX) THEN DEC(hlen) END;
        header[hlen] := 0X;
        IF (hlen < 2) OR (header[0] < "1") OR (header[0] > "6") OR (header[1] < "0") OR (header[1] > "9") THEN
          out.String("gemini: a malformed answer: "); out.String(header); out.Ln; TLS13Live.Disconnect(s^); RETURN FALSE
        END;
        status := (ORD(header[0]) - ORD("0")) * 10 + ORD(header[1]) - ORD("0");
        j := 2; IF header[j] = " " THEN INC(j) END;
        hlen := 0; WHILE (header[j] # 0X) & (hlen < LEN(meta) - 1) DO meta[hlen] := header[j]; INC(hlen); INC(j) END;
        meta[hlen] := 0X;
        IF status DIV 10 # 2 THEN TLS13Live.Disconnect(s^); RETURN TRUE END;
        IF name[0] # 0X THEN f := Files.New(name); Files.Set(R, f, 0) END
      END
    END;
    IF ~inHeader & (i < got) THEN  (* the body *)
      IF f # NIL THEN
        WHILE i < got DO Files.Write(R, buf[i]); INC(i); INC(n) END
      ELSE
        WHILE i < got DO IF buf[i] # 0DX THEN out.Char(buf[i]) END; INC(i); INC(n) END
      END
    END
  END;
  complete := s.closeNotify; ok := ~inHeader;
  TLS13Live.Disconnect(s^);
  IF ~ok THEN out.String("gemini: no answer"); out.Ln END;
  RETURN ok
END Request;

(* url := target, relative to url (RFC 3986, enough for Gemini): FALSE if it is not gemini:// *)
PROCEDURE Resolve(VAR url, target: ARRAY OF CHAR): BOOLEAN;
VAR host, port, path, base: ARRAY 1100 OF CHAR; i: LONGINT;
BEGIN
  IF StartsWith(target, "gemini://") THEN COPY(target, url); RETURN TRUE END;
  IF (target[0] = "/") & (target[1] = "/") THEN COPY("gemini:", url); Append(url, target); RETURN TRUE END;
  i := 0; WHILE (target[i] # 0X) & (target[i] # ":") & (target[i] # "/") DO INC(i) END;
  IF target[i] = ":" THEN RETURN FALSE END;  (* another scheme *)
  IF ~Split(url, host, port, path) THEN RETURN FALSE END;
  COPY("gemini://", base); Append(base, host);
  IF port # DefaultPort THEN Append(base, ":"); Append(base, port) END;
  IF target[0] = "/" THEN COPY(base, url); Append(url, target)
  ELSE  (* relative to the directory of path *)
    i := Len(path); WHILE (i > 0) & (path[i - 1] # "/") DO DEC(i) END;
    path[i] := 0X; COPY(base, url); Append(url, path); Append(url, target)
  END;
  RETURN TRUE
END Resolve;

(* the file name for url: the last part of the path, index.gmi for a directory *)
PROCEDURE DefaultName(VAR url, name: ARRAY OF CHAR);
VAR host, port, path: ARRAY 1100 OF CHAR; i, j: LONGINT;
BEGIN
  IF ~Split(url, host, port, path) THEN COPY("index.gmi", name); RETURN END;
  i := Len(path); WHILE (i > 0) & (path[i - 1] # "/") DO DEC(i) END;
  j := 0; WHILE (path[i] # 0X) & (path[i] # "?") & (j < LEN(name) - 1) DO name[j] := path[i]; INC(i); INC(j) END;
  name[j] := 0X; IF j = 0 THEN COPY("index.gmi", name) END
END DefaultName;

(* fetch url, following redirects; to the file name, or to out if name = "" *)
PROCEDURE Fetch(VAR url: ARRAY OF CHAR; name: ARRAY OF CHAR; given: BOOLEAN);
VAR status, n, redirects: LONGINT; meta: ARRAY 1100 OF CHAR; f: Files.File; complete: BOOLEAN;
BEGIN
  redirects := 0;
  LOOP
    IF ~given & (name[0] # 0X) THEN DefaultName(url, name) END;
    IF ~Request(url, status, meta, name, f, n, complete) THEN EXIT END;
    IF status DIV 10 = 3 THEN
      INC(redirects);
      IF redirects > MaxRedirects THEN out.String("gemini: too many redirects"); out.Ln; EXIT END;
      IF ~Resolve(url, meta) THEN out.String("gemini: a redirect away from Gemini: "); out.String(meta); out.Ln; EXIT END;
      out.String("gemini: redirected to "); out.String(url); out.Ln
    ELSE
      IF status DIV 10 = 2 THEN
        IF name[0] = 0X THEN
          IF ~complete THEN out.Ln; out.String("gemini: the body is incomplete (no close_notify)"); out.Ln END
        ELSE
          out.Int(status, 0); out.Char(" "); out.String(meta); out.String(", "); out.Int(n, 0); out.String(" bytes");
          IF complete THEN Files.Register(f); out.String(" in "); out.String(name)
          ELSE out.String(", incomplete (no close_notify): not saved")
          END;
          out.Ln
        END
      ELSIF status DIV 10 = 1 THEN out.String("gemini: the server asks for input: "); out.String(meta); out.Ln
      ELSIF status DIV 10 = 6 THEN out.String("gemini: a client certificate is required (not supported): "); out.String(meta); out.Ln
      ELSE out.Int(status, 0); out.Char(" "); out.String(meta); out.Ln
      END;
      EXIT
    END
  END
END Fetch;

(** gemini.Get url [file] *)
PROCEDURE Get*;
VAR A: Texts.Reader; url, name: ARRAY 1100 OF CHAR; given: BOOLEAN;
BEGIN
  Texts.OpenArgs(A);
  IF ~Texts.Arg(A, url) THEN out.String("usage: gemini.Get gemini://host/path [file]"); out.Ln; RETURN END;
  given := Texts.Arg(A, name);
  IF ~given THEN name := "?" END;  (* a name is made from the url *)
  Fetch(url, name, given)
END Get;

(** gemini.Show url *)
PROCEDURE Show*;
VAR A: Texts.Reader; url: ARRAY 1100 OF CHAR;
BEGIN
  Texts.OpenArgs(A);
  IF ~Texts.Arg(A, url) THEN out.String("usage: gemini.Show gemini://host/path"); out.Ln; RETURN END;
  Fetch(url, "", TRUE)
END Show;

BEGIN
  s := NIL
END gemini.
