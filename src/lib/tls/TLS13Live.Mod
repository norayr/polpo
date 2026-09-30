MODULE TLS13Live;
IMPORT SYSTEM, Linux0, Out := out,
       Internet, TLSBytes, TLS13Random, TLSX25519,
       TLS13Handshake, TLS13Keys, TLS13Records,
       TLS13EncHandshake, TLS13ClientFinished, TLS13Application,
       TLSCABundle, TLSX509Validity, TLSNow, TLSX509Chain, TLSHKDF, TLSECDSA;

CONST
  MaxRecord = 16640;          (* 2^14 + 256, the longest TLSCiphertext (RFC 8446 5.2) *)
  MaxPlain = 16384;           (* 2^14 *)
  CloseNotify = 0; UserCanceled = 90;           (* alert descriptions *)
  NewSessionTicket = 4; KeyUpdate = 24;         (* post-handshake messages *)
  SecretLen = 32;             (* SHA-256 *)

TYPE
  Chain = POINTER TO ChainDesc;
  ChainDesc = RECORD
    certs: ARRAY 8 OF TLSBytes.Buffer;
    ca: TLSCABundle.Bundle
  END;

  State* = RECORD
    fd*: Internet.Socket;
    connected*: BOOLEAN;
    handshakeDone*: BOOLEAN;
    clientAppKey*, clientAppIV*, serverAppKey*, serverAppIV*: TLSBytes.Buffer;
    clientAppSeq*, serverAppSeq*: LONGINT;
    closeNotify*: BOOLEAN;  (** the server ended the connection properly (close_notify) *)
    clientAppSecret, serverAppSecret: TLSBytes.Buffer;  (* for KeyUpdate *)
    postHs: TLSBytes.Buffer;  (* post-handshake message bytes not yet complete *)
    pending: TLSBytes.Buffer;
    pendingPos: LONGINT
  END;

VAR
  verbose*: BOOLEAN;  (** hex dumps of the records and progress messages *)
  lastError*: ARRAY 128 OF CHAR;  (** why the last Connect failed *)
  (* on the heap: 1.3 MB of locals was too much for the stack of polpo (8 MB with the rest), and
     as module variables too far for the PC relative addresses of its ARMv7 compiler *)
  chain: Chain;

PROCEDURE Init*(VAR s: State);
BEGIN
  s.fd := -1;
  s.connected := FALSE;
  s.handshakeDone := FALSE;
  s.clientAppSeq := 0;
  s.serverAppSeq := 0;
  s.closeNotify := FALSE;
  TLSBytes.Init(s.clientAppSecret); TLSBytes.Init(s.serverAppSecret); TLSBytes.Init(s.postHs);
  TLSBytes.Init(s.pending);
  s.pendingPos := 0
END Init;

PROCEDURE HexDigit(n: LONGINT): CHAR;
BEGIN
  IF n < 10 THEN RETURN CHR(ORD("0") + n) END;
  RETURN CHR(ORD("A") + n - 10)
END HexDigit;

PROCEDURE DumpBuffer(label: ARRAY OF CHAR; VAR b: TLSBytes.Buffer);
VAR i, v: LONGINT;
BEGIN
  IF ~verbose THEN RETURN END;
  Out.String(label); Out.String(" len="); Out.Int(b.len, 0); Out.String(" hex=");
  i := 0;
  WHILE i < b.len DO
    v := ORD(b.data[i]);
    Out.Char(HexDigit(v DIV 16)); Out.Char(HexDigit(v MOD 16));
    INC(i)
  END;
  IF verbose THEN Out.Ln END;
END DumpBuffer;

PROCEDURE DumpRecordInfo(label: ARRAY OF CHAR; VAR rec: TLSBytes.Buffer);
VAR ct, ln, level, descr: LONGINT;
BEGIN
  IF ~verbose THEN RETURN END;
  DumpBuffer(label, rec);
  IF rec.len >= 5 THEN
    ct := ORD(rec.data[0]); ln := TLSBytes.GetBE16(rec, 3);
    IF verbose THEN Out.String("  content_type="); Out.Int(ct, 0) END;
    IF verbose THEN Out.String(" version="); Out.Int(ORD(rec.data[1]), 0); Out.Char("."); Out.Int(ORD(rec.data[2]), 0) END;
    IF verbose THEN Out.String(" length="); Out.Int(ln, 0); Out.Ln END;
    IF (ct = 21) & (rec.len >= 7) THEN
      level := ORD(rec.data[5]); descr := ORD(rec.data[6]);
      IF verbose THEN Out.String("  TLS alert level="); Out.Int(level, 0) END;
      IF verbose THEN Out.String(" description="); Out.Int(descr, 0); Out.Ln END;
    END
  END
END DumpRecordInfo;

PROCEDURE ReadExact(fd: Internet.Socket; VAR b: TLSBytes.Buffer; pos, n: LONGINT): BOOLEAN;
VAR got, r: LONGINT;
BEGIN
  got := 0;
  WHILE got < n DO
    r := Linux0.Read0(fd, SYSTEM.ADR(b.data[pos + got]), n - got);
    IF r <= 0 THEN RETURN FALSE END;
    INC(got, r)
  END;
  RETURN TRUE
END ReadExact;

PROCEDURE WriteAll(fd: Internet.Socket; VAR b: TLSBytes.Buffer): BOOLEAN;
BEGIN
  IF b.len = 0 THEN RETURN TRUE END;
  RETURN Internet.WriteBytes(fd, b.data, b.len)
END WriteAll;

PROCEDURE ReadRecord(fd: Internet.Socket; VAR rec: TLSBytes.Buffer): BOOLEAN;
VAR n: LONGINT;
BEGIN
  TLSBytes.SetLen(rec, 5);
  IF ~ReadExact(fd, rec, 0, 5) THEN RETURN FALSE END;
  n := TLSBytes.GetBE16(rec, 3);
  IF (n < 0) OR (n > MaxRecord) THEN COPY("a record longer than 2^14 + 256 bytes", lastError); RETURN FALSE END;
  TLSBytes.SetLen(rec, 5 + n);
  IF n > 0 THEN RETURN ReadExact(fd, rec, 5, n) END;
  RETURN TRUE
END ReadRecord;

PROCEDURE IsCCS(VAR rec: TLSBytes.Buffer): BOOLEAN;
BEGIN
  RETURN (rec.len = 6) & (ORD(rec.data[0]) = TLS13Records.ChangeCipherSpec) &
         (ORD(rec.data[1]) = 3) & (ORD(rec.data[2]) = 3) &
         (TLSBytes.GetBE16(rec, 3) = 1) & (ORD(rec.data[5]) = 1)
END IsCCS;

PROCEDURE NextNonCCS(fd: Internet.Socket; VAR rec: TLSBytes.Buffer): BOOLEAN;
BEGIN
  REPEAT
    IF ~ReadRecord(fd, rec) THEN RETURN FALSE END
  UNTIL ~IsCCS(rec);
  RETURN TRUE
END NextNonCCS;

PROCEDURE FillBufferRandom(VAR b: TLSBytes.Buffer; n: LONGINT): BOOLEAN;
BEGIN
  TLSBytes.SetLen(b, n);
  RETURN TLS13Random.Fill(b.data, n)
END FillBufferRandom;

PROCEDURE CopyArrayToBuffer(VAR a: ARRAY OF CHAR; n: LONGINT; VAR b: TLSBytes.Buffer);
BEGIN
  TLSBytes.Init(b);
  TLSBytes.AppendOpen(b, a, n)
END CopyArrayToBuffer;


PROCEDURE Wipe(VAR b: TLSBytes.Buffer);
VAR i: LONGINT;
BEGIN
  i := 0; WHILE i < b.len DO b.data[i] := 0X; INC(i) END;
  b.len := 0
END Wipe;

PROCEDURE Fail(why: ARRAY OF CHAR);
BEGIN
  COPY(why, lastError); Out.String("TLS13Live: "); Out.String(why); Out.Ln
END Fail;

(* rec is a plain alert of the server instead of its hello: fail with its reason *)
PROCEDURE RefusedByAlert(VAR rec: TLSBytes.Buffer): BOOLEAN;
BEGIN
  IF (rec.len # 7) OR (ORD(rec.data[0]) # TLS13Records.Alert) THEN RETURN FALSE END;
  IF ORD(rec.data[6]) = 70 THEN Fail("the server does not speak TLS 1.3 (alert protocol_version)")
  ELSIF ORD(rec.data[6]) = 40 THEN Fail("no parameters in common with the server (alert handshake_failure)")
  ELSIF ORD(rec.data[6]) = 112 THEN Fail("the server does not know this host name (alert unrecognized_name)")
  ELSE Fail("the server refused the handshake (an alert)")
  END;
  RETURN TRUE
END RefusedByAlert;

PROCEDURE CheckCapturedCertificateChain(host: ARRAY OF CHAR): BOOLEAN;
VAR
  i, n: LONGINT;
  now: TLSX509Validity.Time;
  res: TLSX509Chain.Result;
  ok: BOOLEAN;
BEGIN
  IF chain = NIL THEN NEW(chain) END;
  n := TLS13EncHandshake.CapturedCertCount();
  IF verbose THEN Out.String("TLS13Live: captured cert count="); Out.Int(n, 0); Out.Ln END;
  i := 0;
  WHILE i < LEN(chain.certs) DO TLSBytes.Init(chain.certs[i]); INC(i) END;
  i := 0;
  WHILE (i < n) & (i < LEN(chain.certs)) DO
    IF ~TLS13EncHandshake.GetCapturedCert(i, chain.certs[i]) THEN RETURN FALSE END;
    INC(i)
  END;

  IF verbose THEN Out.String("TLS13Live: hostname verified = ") END;
  IF verbose THEN IF TLS13EncHandshake.HostnameOK() THEN Out.String("OK") ELSE Out.String("FAIL") END END;
  IF verbose THEN Out.Ln END;

  IF ~TLSCABundle.LoadDefault(chain.ca) THEN
    Out.String("TLS13Live: could not load the CA bundle "); Out.String(TLSCABundle.DefaultPath); Out.Ln;
    RETURN FALSE
  END;
  IF verbose THEN Out.String("TLS13Live: loaded CA bundle bytes="); Out.Int(chain.ca.len, 0); Out.Ln END;

  TLSNow.Current(now);
  IF verbose THEN Out.String("TLS13Live: current time "); Out.Int(now.year, 0); Out.Char("-"); Out.Int(now.month, 0); Out.Char("-"); Out.Int(now.day, 0); Out.Char(" "); Out.Int(now.hour, 0); Out.Char(":"); Out.Int(now.minute, 0); Out.Char(":"); Out.Int(now.second, 0); Out.Ln END;

  ok := TLSX509Chain.CheckChainWithPEMBundle(chain.certs, n, chain.ca.text, now, res);
  IF verbose THEN Out.String("TLS13Live: chain trusted = "); IF ok THEN Out.String("OK") ELSE Out.String("FAIL") END; Out.Ln END;
  IF verbose THEN Out.String("TLS13Live: chain depth="); Out.Int(res.depth, 0) END;
  IF verbose THEN Out.String(" rootFound="); IF res.rootFound THEN Out.String("true") ELSE Out.String("false") END END;
  IF verbose THEN Out.String(" rootTrusted="); IF res.rootTrusted THEN Out.String("true") ELSE Out.String("false") END END;
  IF verbose THEN Out.String(" sigsOK="); IF res.allSignaturesOK THEN Out.String("true") ELSE Out.String("false") END END;
  IF verbose THEN Out.String(" timesOK="); IF res.allTimesOK THEN Out.String("true") ELSE Out.String("false") END END;
  IF verbose THEN Out.String(" namesOK="); IF res.allNamesOK THEN Out.String("true") ELSE Out.String("false") END END;
  IF verbose THEN Out.String(" failedAt="); Out.Int(res.failedAt, 0); Out.Ln END;

  IF ~ok THEN Fail("the certificate chain is not trusted"); RETURN FALSE END;
  IF ~TLS13EncHandshake.HostnameOK() THEN Fail("the certificate is not for this host name"); RETURN FALSE END;
  IF ~TLS13EncHandshake.CertificateVerifyOK() THEN Fail("CertificateVerify did not verify"); RETURN FALSE END;
  RETURN TRUE
END CheckCapturedCertificateChain;

PROCEDURE Handshake(host, port: ARRAY OF CHAR; VAR s: State): BOOLEAN;
VAR
  privArr, pubArr, sharedArr: ARRAY 32 OF CHAR;
  i: LONGINT;
  clientRandom, clientPub, clientHelloMsg, clientHelloRec: TLSBytes.Buffer;
  rec, serverHelloMsg, serverPub, shared, th, serverFrag: TLSBytes.Buffer;
  cHsKey, cHsIV, sHsKey, sHsIV, cFinKey, sFinKey: TLSBytes.Buffer;
  hsSecret, masterSecret, clientFinishedRec, clientFinishedMsg, thServerFinished: TLSBytes.Buffer;
  sawFinished, finishedOK, zero: BOOLEAN;
  group, tries: LONGINT; cookie, p256Priv, p256Pub, h: TLSBytes.Buffer;
  serverHSSeq, clientHSSeq: LONGINT;
  why: ARRAY 128 OF CHAR;
BEGIN
  Init(s); lastError := "";
  TLS13EncHandshake.verbose := verbose;
  TLS13EncHandshake.ResetState;
  TLS13EncHandshake.SetExpectedHost(host);
  IF ~Internet.Connect(host, port, s.fd) THEN RETURN FALSE END;
  s.connected := TRUE;

  IF ~TLS13Random.Fill(privArr, 32) THEN RETURN FALSE END;
  TLSX25519.ScalarMultBase(pubArr, privArr);
  IF ~FillBufferRandom(clientRandom, 32) THEN RETURN FALSE END;
  CopyArrayToBuffer(pubArr, 32, clientPub);

  TLS13Handshake.BuildClientHelloMessage(host, clientRandom, clientPub, clientHelloMsg);
  TLS13Handshake.BuildPlainHandshakeRecord(clientHelloMsg, clientHelloRec);
  DumpBuffer("client hello msg", clientHelloMsg);
  DumpRecordInfo("client hello rec", clientHelloRec);
  IF ~WriteAll(s.fd, clientHelloRec) THEN Out.String("TLS13Live: write ClientHello failed"); Out.Ln; RETURN FALSE END;

  TLSBytes.Copy(clientHelloMsg, th);  (* temporary transcript storage *)

  IF ~NextNonCCS(s.fd, rec) THEN Out.String("TLS13Live: failed reading first server record"); Out.Ln; RETURN FALSE END;
  DumpRecordInfo("first server record", rec);
  IF RefusedByAlert(rec) THEN RETURN FALSE END;
  IF ~TLS13Handshake.GetRecordPayload(rec, serverHelloMsg) THEN Out.String("TLS13Live: first server record is not plain handshake ServerHello"); Out.Ln; RETURN FALSE END;
  DumpBuffer("server hello msg", serverHelloMsg);
  group := TLS13Handshake.GroupX25519;
  IF TLS13Handshake.IsHelloRetryRequest(serverHelloMsg) THEN
    IF ~TLS13Handshake.CheckHelloRetryRequest(serverHelloMsg, clientRandom, group, group, cookie, why) THEN Fail(why); RETURN FALSE END;
    IF verbose THEN Out.String("TLS13Live: HelloRetryRequest, group="); Out.Int(group, 0); Out.Ln END;
    (* the transcript: message_hash with the hash of the first ClientHello, then the HelloRetryRequest (RFC 8446 4.4.1) *)
    TLS13Keys.HashMessages(clientHelloMsg, h);
    TLSBytes.Init(th); TLSBytes.AppendByte(th, 254); TLSBytes.PutBE24(th, h.len); TLSBytes.Append(th, h);
    TLSBytes.Append(th, serverHelloMsg);
    IF group = TLS13Handshake.GroupP256 THEN
      tries := 0;
      REPEAT
        INC(tries);
        IF ~FillBufferRandom(p256Priv, 32) THEN RETURN FALSE END
      UNTIL TLSECDSA.ECDHPublic(TLSECDSA.P256, p256Priv, p256Pub) OR (tries = 8);
      IF p256Pub.len # 65 THEN Fail("no P-256 key"); RETURN FALSE END;
      TLS13Handshake.BuildClientHello2(host, clientRandom, group, p256Pub, cookie, clientHelloMsg)
    ELSE  (* only a cookie: the same key share *)
      TLS13Handshake.BuildClientHello2(host, clientRandom, group, clientPub, cookie, clientHelloMsg)
    END;
    TLS13Handshake.BuildPlainHandshakeRecord(clientHelloMsg, clientHelloRec);
    TLSBytes.Append(th, clientHelloMsg);
    IF ~WriteAll(s.fd, clientHelloRec) THEN Fail("writing the second ClientHello failed"); RETURN FALSE END;
    IF ~NextNonCCS(s.fd, rec) OR RefusedByAlert(rec) OR ~TLS13Handshake.GetRecordPayload(rec, serverHelloMsg) THEN
      Fail("no ServerHello after the HelloRetryRequest"); RETURN FALSE
    END;
    DumpBuffer("server hello msg", serverHelloMsg)
  END;
  IF ~TLS13Handshake.CheckServerHelloGroup(serverHelloMsg, clientRandom, group, serverPub, why) THEN Fail(why); RETURN FALSE END;  (* the session id we sent is clientRandom *)
  TLSBytes.Append(th, serverHelloMsg);
  DumpBuffer("server pub", serverPub);

  IF group = TLS13Handshake.GroupP256 THEN
    IF ~TLSECDSA.ECDH(TLSECDSA.P256, p256Priv, serverPub, shared) THEN Fail("the P-256 key share of the server is not a point of the curve"); RETURN FALSE END;
    Wipe(p256Priv); i := 0; WHILE i < 32 DO privArr[i] := 0X; INC(i) END
  ELSE
    TLSX25519.ScalarMult(sharedArr, privArr, serverPub.data);
    CopyArrayToBuffer(sharedArr, 32, shared);
    i := 0; zero := TRUE; WHILE i < 32 DO IF sharedArr[i] # 0X THEN zero := FALSE END; INC(i) END;
    IF zero THEN Fail("the X25519 shared secret is zero (a small order point)"); RETURN FALSE END  (* RFC 7748 6.1 *)
  END;

  TLS13Keys.HashMessages(th, clientRandom); (* reusing clientRandom as transcript hash *)
  TLS13Keys.HandshakeKeys(shared, clientRandom, cHsKey, cHsIV, sHsKey, sHsIV, cFinKey, sFinKey);
  TLS13Keys.HandshakeSecret(shared, hsSecret);
  i := 0; WHILE i < 32 DO privArr[i] := 0X; sharedArr[i] := 0X; shared.data[i] := 0X; INC(i) END;  (* no longer needed *)

  serverHSSeq := 0;
  TLSBytes.Init(serverFrag);
  sawFinished := FALSE; finishedOK := FALSE;
  WHILE ~sawFinished DO
    IF ~NextNonCCS(s.fd, rec) THEN Out.String("TLS13Live: failed reading encrypted handshake record"); Out.Ln; RETURN FALSE END;
    DumpRecordInfo("encrypted server hs rec", rec);
    IF ~TLS13EncHandshake.OpenServerHandshakeRecordBuf(sHsKey, sHsIV, serverHSSeq, rec, serverFrag, th, sFinKey, sawFinished, finishedOK) THEN
      IF (TLS13EncHandshake.CapturedCertCount() > 0) & ~TLS13EncHandshake.CertificateVerifyOK() THEN Fail("CertificateVerify did not verify")
      ELSE Fail("the encrypted handshake failed (decryption, order of messages or Finished)")
      END;
      RETURN FALSE
    END;
    IF verbose THEN Out.String("  buffered hs fragment bytes="); Out.Int(serverFrag.len, 0); Out.Ln END;
    INC(serverHSSeq)
  END;
  IF ~finishedOK THEN Out.String("TLS13Live: server Finished verification failed"); Out.Ln; RETURN FALSE END;

  IF verbose THEN Out.String("TLS13Live: server Finished OK, transcript len="); Out.Int(th.len, 0); Out.Ln END;

  IF ~CheckCapturedCertificateChain(host) THEN RETURN FALSE END;

  (* TLS 1.3 application traffic secrets are derived from the
     transcript ending at the server Finished.  The client Finished is
     built using this transcript too, but it is not included in
     client/server_application_traffic_secret_0. *)
  TLSBytes.Copy(th, thServerFinished);

  clientHSSeq := 0;
  IF verbose THEN Out.String("TLS13Live: building client Finished"); Out.Ln END;
  TLS13ClientFinished.BuildClientFinishedRecord(cHsKey, cHsIV, clientHSSeq, thServerFinished, cFinKey, clientFinishedRec, clientFinishedMsg);
  DumpBuffer("client finished msg", clientFinishedMsg);
  DumpRecordInfo("client finished rec", clientFinishedRec);

  IF verbose THEN Out.String("TLS13Live: deriving master secret"); Out.Ln END;
  TLS13Keys.MasterSecret(hsSecret, masterSecret);
  IF verbose THEN Out.String("TLS13Live: deriving application keys from server-Finished transcript"); Out.Ln END;
  TLS13Application.ApplicationTrafficSecrets(masterSecret, thServerFinished, s.clientAppSecret, s.serverAppSecret);
  TLS13Keys.TrafficKey(s.clientAppSecret, s.clientAppKey); TLS13Keys.TrafficIV(s.clientAppSecret, s.clientAppIV);
  TLS13Keys.TrafficKey(s.serverAppSecret, s.serverAppKey); TLS13Keys.TrafficIV(s.serverAppSecret, s.serverAppIV);
  Wipe(hsSecret); Wipe(masterSecret);
  IF verbose THEN Out.String("TLS13Live: application keys ready"); Out.Ln END;

  IF verbose THEN Out.String("TLS13Live: appending client Finished to transcript"); Out.Ln END;
  TLS13ClientFinished.AppendClientFinished(th, clientFinishedMsg);
  IF verbose THEN Out.String("TLS13Live: transcript len after client Finished="); Out.Int(th.len, 0); Out.Ln END;
  IF verbose THEN Out.String("TLS13Live: writing client Finished"); Out.Ln END;
  IF ~WriteAll(s.fd, clientFinishedRec) THEN Out.String("TLS13Live: write client Finished failed"); Out.Ln; RETURN FALSE END;
  s.clientAppSeq := 0;
  s.serverAppSeq := 0;
  TLSBytes.Init(s.pending); s.pendingPos := 0;
  s.handshakeDone := TRUE;
  RETURN TRUE
END Handshake;

(** a TLS 1.3 connection to host: the server authenticated (a trusted chain for the host name,
  CertificateVerify and Finished); FALSE and nothing open otherwise (lastError says why) *)
PROCEDURE Connect*(host, port: ARRAY OF CHAR; VAR s: State): BOOLEAN;
BEGIN
  IF Handshake(host, port, s) THEN RETURN TRUE END;
  IF lastError = "" THEN COPY("no connection", lastError) END;
  IF s.connected THEN Internet.Disconnect(s.fd) END;
  Init(s);
  RETURN FALSE
END Connect;

(* the alert close_notify to the server; FALSE if it could not be written *)
PROCEDURE SendCloseNotify(VAR s: State): BOOLEAN;
VAR alert, rec: TLSBytes.Buffer;
BEGIN
  TLSBytes.Init(alert); TLSBytes.AppendByte(alert, 1); TLSBytes.AppendByte(alert, CloseNotify);
  TLS13Records.ProtectRecord(s.clientAppKey, s.clientAppIV, s.clientAppSeq, TLS13Records.Alert, alert, rec);
  INC(s.clientAppSeq);
  RETURN WriteAll(s.fd, rec)
END SendCloseNotify;

(** close the connection, with close_notify after a handshake; the keys are cleared *)
PROCEDURE Disconnect*(VAR s: State);
BEGIN
  IF s.connected & s.handshakeDone & (s.clientAppSeq < MAX(LONGINT)) THEN
    IF ~SendCloseNotify(s) & verbose THEN Out.String("TLS13Live: close_notify not sent"); Out.Ln END
  END;
  IF s.connected THEN Internet.Disconnect(s.fd) END;
  Wipe(s.clientAppKey); Wipe(s.clientAppIV); Wipe(s.serverAppKey); Wipe(s.serverAppIV);
  Wipe(s.clientAppSecret); Wipe(s.serverAppSecret);
  Init(s)
END Disconnect;

(** plain to the server, in records of at most 2^14 bytes *)
PROCEDURE WriteAppBuffer*(VAR s: State; VAR plain: TLSBytes.Buffer): BOOLEAN;
VAR rec, part: TLSBytes.Buffer; pos, n: LONGINT;
BEGIN
  IF ~s.handshakeDone THEN RETURN FALSE END;
  pos := 0;
  REPEAT
    n := plain.len - pos; IF n > MaxPlain THEN n := MaxPlain END;
    IF s.clientAppSeq = MAX(LONGINT) THEN Fail("too many records with one key"); RETURN FALSE END;
    TLSBytes.Slice(plain, pos, n, part);
    IF verbose THEN Out.String("TLS13Live: protecting application data len="); Out.Int(n, 0); Out.String(" seq="); Out.Int(s.clientAppSeq, 0); Out.Ln END;
    TLS13Application.ProtectApplicationData(s.clientAppKey, s.clientAppIV, s.clientAppSeq, part, rec);
    DumpRecordInfo("application write rec", rec);
    IF ~WriteAll(s.fd, rec) THEN RETURN FALSE END;
    INC(s.clientAppSeq); INC(pos, n)
  UNTIL pos >= plain.len;
  RETURN TRUE
END WriteAppBuffer;

PROCEDURE WriteAppString*(VAR s: State; str: ARRAY OF CHAR): BOOLEAN;
VAR b: TLSBytes.Buffer;
BEGIN
  TLSBytes.Init(b);
  TLSBytes.AppendString(b, str);
  RETURN WriteAppBuffer(s, b)
END WriteAppString;

(* the next traffic secret (RFC 8446 7.2) *)
PROCEDURE NextSecret(VAR secret: TLSBytes.Buffer);
VAR empty, next: TLSBytes.Buffer;
BEGIN
  TLSBytes.Init(empty);
  TLSHKDF.ExpandLabel(secret, "traffic upd", empty, SecretLen, next);
  Wipe(secret); TLSBytes.Copy(next, secret); Wipe(next)
END NextSecret;

(* our KeyUpdate (update_not_requested), then our keys are the next ones *)
PROCEDURE SendKeyUpdate(VAR s: State): BOOLEAN;
VAR msg, rec: TLSBytes.Buffer;
BEGIN
  TLSBytes.Init(msg);
  TLSBytes.AppendByte(msg, KeyUpdate); TLSBytes.AppendByte(msg, 0); TLSBytes.AppendByte(msg, 0);
  TLSBytes.AppendByte(msg, 1); TLSBytes.AppendByte(msg, 0);
  TLS13Records.ProtectRecord(s.clientAppKey, s.clientAppIV, s.clientAppSeq, TLS13Records.Handshake, msg, rec);
  IF ~WriteAll(s.fd, rec) THEN Fail("writing KeyUpdate failed"); RETURN FALSE END;
  NextSecret(s.clientAppSecret);
  TLS13Keys.TrafficKey(s.clientAppSecret, s.clientAppKey); TLS13Keys.TrafficIV(s.clientAppSecret, s.clientAppIV);
  s.clientAppSeq := 0;
  RETURN TRUE
END SendKeyUpdate;

(* handshake messages after the handshake, from the record plain: NewSessionTicket is not used,
   KeyUpdate changes the keys of the server (and ours if asked); anything else is refused *)
PROCEDURE PostHandshake(VAR s: State; VAR plain: TLSBytes.Buffer): BOOLEAN;
VAR type, len: LONGINT; rest: TLSBytes.Buffer;
BEGIN
  IF plain.len = 0 THEN Fail("an empty handshake record"); RETURN FALSE END;
  IF s.postHs.len + plain.len > TLSBytes.MaxLen THEN Fail("a post-handshake message too long"); RETURN FALSE END;
  TLSBytes.Append(s.postHs, plain);
  WHILE s.postHs.len >= 4 DO
    type := ORD(s.postHs.data[0]); len := TLSBytes.GetBE24(s.postHs, 1);
    IF 4 + len > TLSBytes.MaxLen THEN Fail("a post-handshake message too long"); RETURN FALSE END;
    IF s.postHs.len < 4 + len THEN RETURN TRUE END;  (* continued in the next record *)
    IF type = NewSessionTicket THEN
      IF verbose THEN Out.String("TLS13Live: NewSessionTicket (not used)"); Out.Ln END
    ELSIF type = KeyUpdate THEN
      IF (len # 1) OR (ORD(s.postHs.data[4]) > 1) THEN Fail("a malformed KeyUpdate"); RETURN FALSE END;
      IF s.postHs.len # 5 THEN Fail("KeyUpdate not at the end of a record"); RETURN FALSE END;
      IF verbose THEN Out.String("TLS13Live: KeyUpdate, request="); Out.Int(ORD(s.postHs.data[4]), 0); Out.Ln END;
      NextSecret(s.serverAppSecret);
      TLS13Keys.TrafficKey(s.serverAppSecret, s.serverAppKey); TLS13Keys.TrafficIV(s.serverAppSecret, s.serverAppIV);
      s.serverAppSeq := 0;
      IF (ORD(s.postHs.data[4]) = 1) & ~SendKeyUpdate(s) THEN RETURN FALSE END
    ELSE
      Fail("an unexpected handshake message after the handshake"); RETURN FALSE
    END;
    TLSBytes.Slice(s.postHs, 4 + len, s.postHs.len - 4 - len, rest); TLSBytes.Copy(rest, s.postHs)
  END;
  RETURN TRUE
END PostHandshake;

(* the next application data of the server in s.pending; FALSE at the end (s.closeNotify if
   the server closed properly, else lastError says why) *)
PROCEDURE ReadNextApplicationPlain(VAR s: State): BOOLEAN;
VAR rec, plain: TLSBytes.Buffer; innerType: LONGINT;
BEGIN
  IF s.closeNotify THEN RETURN FALSE END;
  LOOP
    IF ~ReadRecord(s.fd, rec) THEN
      IF lastError = "" THEN Fail("the connection ended without close_notify (it may be cut)")
      ELSE Fail(lastError)
      END;
      RETURN FALSE
    END;
    DumpRecordInfo("application read rec", rec);
    IF IsCCS(rec) THEN Fail("change_cipher_spec after the handshake"); RETURN FALSE END;
    IF s.serverAppSeq = MAX(LONGINT) THEN Fail("too many records with one key"); RETURN FALSE END;
    IF ~TLS13Records.OpenRecord(s.serverAppKey, s.serverAppIV, s.serverAppSeq, rec, innerType, plain) THEN
      Fail("an application record did not decrypt"); RETURN FALSE
    END;
    IF plain.len > MaxPlain THEN Fail("a record longer than 2^14 bytes"); RETURN FALSE END;
    IF verbose THEN Out.String("TLS13Live: app inner type="); Out.Int(innerType, 0); Out.String(" plain len="); Out.Int(plain.len, 0); Out.Ln END;
    INC(s.serverAppSeq);
    IF (innerType # TLS13Records.Handshake) & (s.postHs.len > 0) THEN
      Fail("a handshake message interrupted by another record"); RETURN FALSE
    END;
    IF innerType = TLS13Records.ApplicationData THEN
      TLSBytes.Copy(plain, s.pending);
      s.pendingPos := 0;
      RETURN TRUE
    ELSIF innerType = TLS13Records.Handshake THEN
      IF ~PostHandshake(s, plain) THEN RETURN FALSE END
    ELSIF innerType = TLS13Records.Alert THEN
      IF plain.len # 2 THEN Fail("a malformed alert"); RETURN FALSE END;
      IF ORD(plain.data[1]) = CloseNotify THEN s.closeNotify := TRUE; RETURN FALSE
      ELSIF ORD(plain.data[1]) # UserCanceled THEN Fail("the server sent an alert"); RETURN FALSE
      END
    ELSE
      Fail("an unexpected record type"); RETURN FALSE
    END
  END
END ReadNextApplicationPlain;

PROCEDURE ReadAppMax*(VAR s: State; VAR out: ARRAY OF CHAR; max: LONGINT; VAR n: LONGINT): BOOLEAN;
VAR cap: LONGINT;
BEGIN
  n := 0;
  IF ~s.handshakeDone THEN RETURN FALSE END;
  cap := max;
  IF cap < 0 THEN cap := LEN(out) END;
  IF cap > LEN(out) THEN cap := LEN(out) END;
  WHILE n < cap DO
    IF s.pendingPos >= s.pending.len THEN
      IF n > 0 THEN
        IF n < LEN(out) THEN out[n] := 0X END;
        RETURN TRUE
      END;
      IF ~ReadNextApplicationPlain(s) THEN RETURN FALSE END
    END;
    WHILE (n < cap) & (s.pendingPos < s.pending.len) DO
      out[n] := s.pending.data[s.pendingPos];
      INC(n); INC(s.pendingPos)
    END
  END;
  IF n < LEN(out) THEN out[n] := 0X END;
  RETURN n > 0
END ReadAppMax;

PROCEDURE ReadApp*(VAR s: State; VAR out: ARRAY OF CHAR; VAR n: LONGINT): BOOLEAN;
BEGIN
  RETURN ReadAppMax(s, out, LEN(out), n)
END ReadApp;

BEGIN
  verbose := FALSE; chain := NIL
END TLS13Live.
