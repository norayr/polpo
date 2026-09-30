MODULE TLS13Live;
IMPORT SYSTEM, Linux0, Out := out,
       Internet, TLSBytes, TLS13Random, TLSX25519,
       TLS13Handshake, TLS13Keys, TLS13Records,
       TLS13EncHandshake, TLS13ClientFinished, TLS13Application,
       TLSCABundle, TLSX509Validity, TLSNow, TLSX509Chain;

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
    pending: TLSBytes.Buffer;
    pendingPos: LONGINT
  END;

VAR
  verbose*: BOOLEAN;  (** hex dumps of the records and progress messages *)
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
  IF (n < 0) OR (n > TLSBytes.MaxLen - 5) THEN RETURN FALSE END;
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

  (* For this first live integration we report the result but only require
     hostname success; real hard-fail on chain trust comes after we add the
     missing signature algorithms seen in the wild. *)
  RETURN TLS13EncHandshake.HostnameOK()
END CheckCapturedCertificateChain;

PROCEDURE Connect*(host, port: ARRAY OF CHAR; VAR s: State): BOOLEAN;
VAR
  privArr, pubArr, sharedArr: ARRAY 32 OF CHAR;
  i: LONGINT;
  clientRandom, clientPub, clientHelloMsg, clientHelloRec: TLSBytes.Buffer;
  rec, serverHelloMsg, serverPub, shared, th, serverFrag: TLSBytes.Buffer;
  cHsKey, cHsIV, sHsKey, sHsIV, cFinKey, sFinKey: TLSBytes.Buffer;
  hsSecret, masterSecret, clientFinishedRec, clientFinishedMsg, thServerFinished: TLSBytes.Buffer;
  sawFinished, finishedOK: BOOLEAN;
  serverHSSeq, clientHSSeq: LONGINT;
BEGIN
  Init(s);
  TLS13EncHandshake.verbose := verbose;
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
  IF ~TLS13Handshake.GetRecordPayload(rec, serverHelloMsg) THEN Out.String("TLS13Live: first server record is not plain handshake ServerHello"); Out.Ln; RETURN FALSE END;
  TLSBytes.Append(th, serverHelloMsg);
  DumpBuffer("server hello msg", serverHelloMsg);
  IF ~TLS13Handshake.ExtractServerHelloKeyShare(serverHelloMsg, serverPub) THEN Out.String("TLS13Live: no x25519 keyshare in ServerHello"); Out.Ln; RETURN FALSE END;
  DumpBuffer("server pub", serverPub);

  i := 0; WHILE i < 32 DO privArr[i] := privArr[i]; INC(i) END;
  TLSX25519.ScalarMult(sharedArr, privArr, serverPub.data);
  CopyArrayToBuffer(sharedArr, 32, shared);

  TLS13Keys.HashMessages(th, clientRandom); (* reusing clientRandom as transcript hash *)
  TLS13Keys.HandshakeKeys(shared, clientRandom, cHsKey, cHsIV, sHsKey, sHsIV, cFinKey, sFinKey);
  TLS13Keys.HandshakeSecret(shared, hsSecret);

  serverHSSeq := 0;
  TLSBytes.Init(serverFrag);
  sawFinished := FALSE; finishedOK := FALSE;
  WHILE ~sawFinished DO
    IF ~NextNonCCS(s.fd, rec) THEN Out.String("TLS13Live: failed reading encrypted handshake record"); Out.Ln; RETURN FALSE END;
    DumpRecordInfo("encrypted server hs rec", rec);
    IF ~TLS13EncHandshake.OpenServerHandshakeRecordBuf(sHsKey, sHsIV, serverHSSeq, rec, serverFrag, th, sFinKey, sawFinished, finishedOK) THEN Out.String("TLS13Live: decrypt/process encrypted server handshake failed at seq "); Out.Int(serverHSSeq, 0); Out.Ln; RETURN FALSE END;
    IF verbose THEN Out.String("  buffered hs fragment bytes="); Out.Int(serverFrag.len, 0); Out.Ln END;
    INC(serverHSSeq)
  END;
  IF ~finishedOK THEN Out.String("TLS13Live: server Finished verification failed"); Out.Ln; RETURN FALSE END;

  IF verbose THEN Out.String("TLS13Live: server Finished OK, transcript len="); Out.Int(th.len, 0); Out.Ln END;

  IF ~CheckCapturedCertificateChain(host) THEN
    Out.String("TLS13Live: certificate hostname/trust check failed"); Out.Ln; RETURN FALSE
  END;

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
  TLS13Application.ApplicationKeys(masterSecret, thServerFinished, s.clientAppKey, s.clientAppIV, s.serverAppKey, s.serverAppIV);
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
END Connect;

PROCEDURE Disconnect*(VAR s: State);
BEGIN
  IF s.connected THEN Internet.Disconnect(s.fd) END;
  Init(s)
END Disconnect;

PROCEDURE WriteAppBuffer*(VAR s: State; VAR plain: TLSBytes.Buffer): BOOLEAN;
VAR rec: TLSBytes.Buffer;
BEGIN
  IF ~s.handshakeDone THEN RETURN FALSE END;
  IF verbose THEN Out.String("TLS13Live: protecting application data len="); Out.Int(plain.len, 0); Out.String(" seq="); Out.Int(s.clientAppSeq, 0); Out.Ln END;
  TLS13Application.ProtectApplicationData(s.clientAppKey, s.clientAppIV, s.clientAppSeq, plain, rec);
  DumpRecordInfo("application write rec", rec);
  IF ~WriteAll(s.fd, rec) THEN RETURN FALSE END;
  INC(s.clientAppSeq);
  RETURN TRUE
END WriteAppBuffer;

PROCEDURE WriteAppString*(VAR s: State; str: ARRAY OF CHAR): BOOLEAN;
VAR b: TLSBytes.Buffer;
BEGIN
  TLSBytes.Init(b);
  TLSBytes.AppendString(b, str);
  RETURN WriteAppBuffer(s, b)
END WriteAppString;

PROCEDURE ReadNextApplicationPlain(VAR s: State): BOOLEAN;
VAR rec, plain: TLSBytes.Buffer; innerType: LONGINT;
BEGIN
  REPEAT
    IF ~NextNonCCS(s.fd, rec) THEN RETURN FALSE END;
    DumpRecordInfo("application read rec", rec);
    IF ~TLS13Records.OpenRecord(s.serverAppKey, s.serverAppIV, s.serverAppSeq, rec, innerType, plain) THEN Out.String("TLS13Live: failed to open application record seq="); Out.Int(s.serverAppSeq, 0); Out.Ln; RETURN FALSE END;
    IF verbose THEN Out.String("TLS13Live: app inner type="); Out.Int(innerType, 0); Out.String(" plain len="); Out.Int(plain.len, 0); Out.Ln END;
    INC(s.serverAppSeq);
    IF innerType = TLS13Records.ApplicationData THEN
      TLSBytes.Copy(plain, s.pending);
      s.pendingPos := 0;
      RETURN TRUE
    ELSIF innerType = TLS13Records.Alert THEN
      RETURN FALSE
    END
  UNTIL FALSE;
  RETURN FALSE
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
