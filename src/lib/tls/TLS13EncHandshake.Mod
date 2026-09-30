MODULE TLS13EncHandshake;
IMPORT Out := out, TLSBytes, TLS13Records, TLS13Keys, TLS13Finished, TLS13Certs, TLSX509, TLSX509Names;

CONST
  EncryptedExtensions* = 8;
  Certificate* = 11;
  CertificateVerify* = 15;
  Finished* = 20;

VAR
  verbose*: BOOLEAN;  (** the handshake messages and the leaf certificate, for debugging *)

VAR
  expectedHost: ARRAY 256 OF CHAR;
  expectedHostSet: BOOLEAN;
  capturedCerts: ARRAY 8 OF TLSBytes.Buffer;
  capturedCertCount: LONGINT;
  capturedHostOK: BOOLEAN;

PROCEDURE SetExpectedHost*(host: ARRAY OF CHAR);
BEGIN
  COPY(host, expectedHost);
  expectedHostSet := TRUE
END SetExpectedHost;

PROCEDURE ClearExpectedHost*;
BEGIN
  expectedHost[0] := 0X;
  expectedHostSet := FALSE
END ClearExpectedHost;

PROCEDURE ResetCapturedCerts*;
VAR i: LONGINT;
BEGIN
  capturedCertCount := 0;
  capturedHostOK := FALSE;
  i := 0;
  WHILE i < LEN(capturedCerts) DO
    TLSBytes.Init(capturedCerts[i]); INC(i)
  END
END ResetCapturedCerts;

PROCEDURE CapturedCertCount*(): LONGINT;
BEGIN
  RETURN capturedCertCount
END CapturedCertCount;

PROCEDURE GetCapturedCert*(i: LONGINT; VAR der: TLSBytes.Buffer): BOOLEAN;
BEGIN
  TLSBytes.Init(der);
  IF (i < 0) OR (i >= capturedCertCount) OR (i >= LEN(capturedCerts)) THEN RETURN FALSE END;
  TLSBytes.Copy(capturedCerts[i], der);
  RETURN TRUE
END GetCapturedCert;

PROCEDURE HostnameOK*(): BOOLEAN;
BEGIN
  RETURN capturedHostOK
END HostnameOK;


PROCEDURE MessageTotalLen*(VAR data: TLSBytes.Buffer; pos: LONGINT; VAR total: LONGINT): BOOLEAN;
VAR bodyLen: LONGINT;
BEGIN
  total := 0;
  IF pos + 4 > data.len THEN RETURN FALSE END;
  bodyLen := TLSBytes.GetBE24(data, pos + 1);
  total := 4 + bodyLen;
  IF pos + total > data.len THEN RETURN FALSE END;
  RETURN TRUE
END MessageTotalLen;

PROCEDURE MessageType*(VAR data: TLSBytes.Buffer; pos: LONGINT): LONGINT;
BEGIN
  IF pos >= data.len THEN RETURN -1 END;
  RETURN ORD(data.data[pos])
END MessageType;

PROCEDURE AppendOneMessage*(VAR transcript, data: TLSBytes.Buffer; pos, total: LONGINT);
VAR msg: TLSBytes.Buffer;
BEGIN
  TLSBytes.Slice(data, pos, total, msg);
  TLSBytes.Append(transcript, msg)
END AppendOneMessage;


PROCEDURE PrintOID(label: ARRAY OF CHAR; VAR oid: TLSBytes.Buffer);
VAR txt: ARRAY 128 OF CHAR;
BEGIN
  TLSX509.OIDText(oid, txt);
  Out.String(label); Out.String(txt); Out.Ln
END PrintOID;

PROCEDURE DebugCertificateMessage(VAR msg: TLSBytes.Buffer);
VAR leaf, der: TLSBytes.Buffer; info: TLSX509.CertInfo; pos, limit: LONGINT;
BEGIN
  ResetCapturedCerts;
  IF TLS13Certs.CertificateListStart(msg, pos, limit) THEN
    WHILE (capturedCertCount < LEN(capturedCerts)) & TLS13Certs.NextCertificate(msg, pos, limit, der) DO
      TLSBytes.Copy(der, capturedCerts[capturedCertCount]); INC(capturedCertCount)
    END
  END;
  IF verbose THEN Out.String("  certificate message: len="); Out.Int(msg.len, 0); Out.Ln END;
  IF TLS13Certs.FirstCertificate(msg, leaf) THEN
    IF verbose THEN Out.String("  leaf cert DER len="); Out.Int(leaf.len, 0); Out.Ln END;
    IF TLSX509.ParseCertificate(leaf, info) THEN
      IF verbose THEN Out.String("  leaf X509 parse OK"); Out.Ln END;
      IF verbose THEN Out.String("  tbs len="); Out.Int(info.tbs.len, 0); Out.Ln END;
      IF verbose THEN Out.String("  issuer len="); Out.Int(info.issuer.len, 0); Out.Ln END;
      IF verbose THEN Out.String("  subject len="); Out.Int(info.subject.len, 0); Out.Ln END;
      IF verbose THEN Out.String("  validity len="); Out.Int(info.validity.len, 0); Out.Ln END;
      IF verbose THEN Out.String("  spki len="); Out.Int(info.spki.len, 0); Out.Ln END;
      IF verbose THEN PrintOID("  cert sig alg OID=", info.sigAlgOID) END;
      IF verbose THEN PrintOID("  public key alg OID=", info.pubAlgOID) END;
      IF verbose THEN Out.String("  signature len="); Out.Int(info.signature.len, 0); Out.String(" unusedBits="); Out.Int(info.signatureUnusedBits, 0); Out.Ln END;
      IF expectedHostSet THEN
        IF verbose THEN Out.String("  hostname check for "); Out.String(expectedHost); Out.String(" = ") END;
        capturedHostOK := TLSX509Names.CertMatchesHostname(leaf, expectedHost);
        IF capturedHostOK THEN
          IF verbose THEN Out.String("OK") END
        ELSE
          IF verbose THEN Out.String("FAIL") END
        END;
        IF verbose THEN Out.Ln END
      END
    ELSE
      IF verbose THEN Out.String("  leaf X509 parse FAIL"); Out.Ln END
    END
  ELSE
    IF verbose THEN Out.String("  no leaf certificate extracted"); Out.Ln END
  END
END DebugCertificateMessage;

PROCEDURE DropPrefix(VAR b: TLSBytes.Buffer; n: LONGINT);
VAR i, newLen: LONGINT;
BEGIN
  IF n <= 0 THEN RETURN END;
  IF n >= b.len THEN TLSBytes.Init(b); RETURN END;
  newLen := b.len - n;
  i := 0;
  WHILE i < newLen DO
    b.data[i] := b.data[i + n]; INC(i)
  END;
  b.len := newLen
END DropPrefix;

PROCEDURE ProcessServerHandshakeBuffered*(VAR plain, partial, transcript, serverFinishedKey: TLSBytes.Buffer;
                                         VAR sawFinished, finishedOK: BOOLEAN): BOOLEAN;
VAR pos, total, typ, bodyLen: LONGINT; msg, th: TLSBytes.Buffer; parsing: BOOLEAN;
BEGIN
  sawFinished := FALSE; finishedOK := FALSE;

  (* Real TLS servers may split one handshake message across several TLS records.
     So we append decrypted plaintext to PARTIAL, parse only complete handshake
     messages, and leave incomplete bytes in PARTIAL for the next record. *)
  TLSBytes.Append(partial, plain);

  pos := 0;
  parsing := TRUE;
  WHILE parsing & (pos < partial.len) DO
    IF partial.len - pos < 4 THEN
      parsing := FALSE
    ELSE
      bodyLen := TLSBytes.GetBE24(partial, pos + 1);
      total := 4 + bodyLen;
      IF partial.len - pos < total THEN
        parsing := FALSE
      ELSE
        typ := MessageType(partial, pos);
        IF verbose THEN Out.String("  hs msg type="); Out.Int(typ, 0); Out.String(" total="); Out.Int(total, 0); Out.String(" transcript before="); Out.Int(transcript.len, 0); Out.Ln END;
        TLSBytes.Slice(partial, pos, total, msg);

        IF typ = Certificate THEN
          DebugCertificateMessage(msg)
        END;

        IF typ = Finished THEN
          TLS13Keys.HashMessages(transcript, th);
          finishedOK := TLS13Finished.VerifyFinishedMessage(msg, serverFinishedKey, th);
          sawFinished := TRUE;
          TLSBytes.Append(transcript, msg);
          IF verbose THEN Out.String("  server Finished verified="); IF finishedOK THEN Out.String("true") ELSE Out.String("false") END; Out.String(" transcript after="); Out.Int(transcript.len, 0); Out.Ln END;
          IF ~finishedOK THEN RETURN FALSE END
        ELSE
          TLSBytes.Append(transcript, msg);
          IF verbose THEN Out.String("  transcript after="); Out.Int(transcript.len, 0); Out.Ln END
        END;

        INC(pos, total)
      END
    END
  END;

  IF pos > 0 THEN DropPrefix(partial, pos) END;
  RETURN TRUE
END ProcessServerHandshakeBuffered;

PROCEDURE ProcessServerHandshakePlain*(VAR plain, transcript, serverFinishedKey: TLSBytes.Buffer;
                                      VAR sawFinished, finishedOK: BOOLEAN): BOOLEAN;
VAR scratch: TLSBytes.Buffer;
BEGIN
  TLSBytes.Init(scratch);
  RETURN ProcessServerHandshakeBuffered(plain, scratch, transcript, serverFinishedKey, sawFinished, finishedOK)
END ProcessServerHandshakePlain;

PROCEDURE OpenServerHandshakeRecord*(VAR serverKey, serverIV: TLSBytes.Buffer; seq: LONGINT;
                                    VAR record, transcript, serverFinishedKey: TLSBytes.Buffer;
                                    VAR sawFinished, finishedOK: BOOLEAN): BOOLEAN;
VAR innerType: LONGINT; plain, partial: TLSBytes.Buffer;
BEGIN
  sawFinished := FALSE; finishedOK := FALSE;
  IF ~TLS13Records.OpenRecord(serverKey, serverIV, seq, record, innerType, plain) THEN RETURN FALSE END;
  IF innerType # TLS13Records.Handshake THEN RETURN FALSE END;
  TLSBytes.Init(partial);
  RETURN ProcessServerHandshakeBuffered(plain, partial, transcript, serverFinishedKey, sawFinished, finishedOK)
END OpenServerHandshakeRecord;

PROCEDURE OpenServerHandshakeRecordBuf*(VAR serverKey, serverIV: TLSBytes.Buffer; seq: LONGINT;
                                            VAR record, partial, transcript, serverFinishedKey: TLSBytes.Buffer;
                                            VAR sawFinished, finishedOK: BOOLEAN): BOOLEAN;
VAR innerType: LONGINT; plain: TLSBytes.Buffer;
BEGIN
  sawFinished := FALSE; finishedOK := FALSE;
  IF ~TLS13Records.OpenRecord(serverKey, serverIV, seq, record, innerType, plain) THEN RETURN FALSE END;
  IF innerType # TLS13Records.Handshake THEN RETURN FALSE END;
  RETURN ProcessServerHandshakeBuffered(plain, partial, transcript, serverFinishedKey, sawFinished, finishedOK)
END OpenServerHandshakeRecordBuf;

PROCEDURE BuildEmptyEncryptedExtensions*(VAR msg: TLSBytes.Buffer);
BEGIN
  TLSBytes.Init(msg);
  TLSBytes.AppendByte(msg, EncryptedExtensions);
  TLSBytes.PutBE24(msg, 2);
  TLSBytes.PutBE16(msg, 0)
END BuildEmptyEncryptedExtensions;

BEGIN
  verbose := FALSE; ClearExpectedHost; ResetCapturedCerts
END TLS13EncHandshake.
