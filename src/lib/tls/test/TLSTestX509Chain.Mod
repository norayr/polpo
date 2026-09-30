MODULE TLSTestX509Chain;
IMPORT Out := out, TLSBytes, TLSSHA256, TLSX509Validity, TLSX509Chain;

VAR
  leafDER, interDER, rootDER, badLeafDER: TLSBytes.Buffer;
  certs: ARRAY 2 OF TLSBytes.Buffer;
  roots: ARRAY 1 OF TLSBytes.Buffer;
  now: TLSX509Validity.Time;
  res: TLSX509Chain.Result;

PROCEDURE PrintResult(name: ARRAY OF CHAR; ok: BOOLEAN);
BEGIN
  Out.String(name);
  IF ok THEN Out.String(" OK") ELSE Out.String(" FAIL") END;
  Out.Ln
END PrintResult;

PROCEDURE PutLen(VAR b: TLSBytes.Buffer; n: LONGINT);
BEGIN
  IF n < 128 THEN
    TLSBytes.AppendByte(b, n)
  ELSIF n < 256 THEN
    TLSBytes.AppendByte(b, 081H); TLSBytes.AppendByte(b, n)
  ELSE
    TLSBytes.AppendByte(b, 082H); TLSBytes.AppendByte(b, n DIV 256); TLSBytes.AppendByte(b, n MOD 256)
  END
END PutLen;

PROCEDURE Wrap(tag: LONGINT; VAR body, out: TLSBytes.Buffer);
BEGIN
  TLSBytes.Init(out); TLSBytes.AppendByte(out, tag); PutLen(out, body.len); TLSBytes.Append(out, body)
END Wrap;

PROCEDURE AppendAlgSHA256RSA(VAR b: TLSBytes.Buffer);
BEGIN
  TLSBytes.AppendByte(b, 030H); TLSBytes.AppendByte(b, 00DH);
  TLSBytes.AppendByte(b, 006H); TLSBytes.AppendByte(b, 009H);
  TLSBytes.AppendByte(b, 02AH); TLSBytes.AppendByte(b, 086H); TLSBytes.AppendByte(b, 048H);
  TLSBytes.AppendByte(b, 086H); TLSBytes.AppendByte(b, 0F7H); TLSBytes.AppendByte(b, 00DH);
  TLSBytes.AppendByte(b, 001H); TLSBytes.AppendByte(b, 001H); TLSBytes.AppendByte(b, 00BH);
  TLSBytes.AppendByte(b, 005H); TLSBytes.AppendByte(b, 000H)
END AppendAlgSHA256RSA;

PROCEDURE AppendAlgRSA(VAR b: TLSBytes.Buffer);
BEGIN
  TLSBytes.AppendByte(b, 030H); TLSBytes.AppendByte(b, 00DH);
  TLSBytes.AppendByte(b, 006H); TLSBytes.AppendByte(b, 009H);
  TLSBytes.AppendByte(b, 02AH); TLSBytes.AppendByte(b, 086H); TLSBytes.AppendByte(b, 048H);
  TLSBytes.AppendByte(b, 086H); TLSBytes.AppendByte(b, 0F7H); TLSBytes.AppendByte(b, 00DH);
  TLSBytes.AppendByte(b, 001H); TLSBytes.AppendByte(b, 001H); TLSBytes.AppendByte(b, 001H);
  TLSBytes.AppendByte(b, 005H); TLSBytes.AppendByte(b, 000H)
END AppendAlgRSA;

PROCEDURE AppendName(VAR b: TLSBytes.Buffer; ch: CHAR);
BEGIN
  (* Name ::= SEQUENCE { SET { SEQUENCE { commonName OID, PrintableString ch } } } *)
  TLSBytes.AppendByte(b, 030H); TLSBytes.AppendByte(b, 00CH);
  TLSBytes.AppendByte(b, 031H); TLSBytes.AppendByte(b, 00AH);
  TLSBytes.AppendByte(b, 030H); TLSBytes.AppendByte(b, 008H);
  TLSBytes.AppendByte(b, 006H); TLSBytes.AppendByte(b, 003H);
  TLSBytes.AppendByte(b, 055H); TLSBytes.AppendByte(b, 004H); TLSBytes.AppendByte(b, 003H);
  TLSBytes.AppendByte(b, 013H); TLSBytes.AppendByte(b, 001H); TLSBytes.AppendByte(b, ORD(ch))
END AppendName;

PROCEDURE AppendValidity(VAR b: TLSBytes.Buffer);
BEGIN
  TLSBytes.AppendByte(b, 030H); TLSBytes.AppendByte(b, 01EH);
  TLSBytes.AppendByte(b, 017H); TLSBytes.AppendByte(b, 00DH);
  TLSBytes.AppendByte(b, ORD("2")); TLSBytes.AppendByte(b, ORD("4")); TLSBytes.AppendByte(b, ORD("0")); TLSBytes.AppendByte(b, ORD("1"));
  TLSBytes.AppendByte(b, ORD("0")); TLSBytes.AppendByte(b, ORD("1")); TLSBytes.AppendByte(b, ORD("0")); TLSBytes.AppendByte(b, ORD("0"));
  TLSBytes.AppendByte(b, ORD("0")); TLSBytes.AppendByte(b, ORD("0")); TLSBytes.AppendByte(b, ORD("0")); TLSBytes.AppendByte(b, ORD("0")); TLSBytes.AppendByte(b, ORD("Z"));
  TLSBytes.AppendByte(b, 017H); TLSBytes.AppendByte(b, 00DH);
  TLSBytes.AppendByte(b, ORD("3")); TLSBytes.AppendByte(b, ORD("0")); TLSBytes.AppendByte(b, ORD("0")); TLSBytes.AppendByte(b, ORD("1"));
  TLSBytes.AppendByte(b, ORD("0")); TLSBytes.AppendByte(b, ORD("1")); TLSBytes.AppendByte(b, ORD("0")); TLSBytes.AppendByte(b, ORD("0"));
  TLSBytes.AppendByte(b, ORD("0")); TLSBytes.AppendByte(b, ORD("0")); TLSBytes.AppendByte(b, ORD("0")); TLSBytes.AppendByte(b, ORD("0")); TLSBytes.AppendByte(b, ORD("Z"))
END AppendValidity;

PROCEDURE AppendIntegerFF64(VAR b: TLSBytes.Buffer);
VAR i: LONGINT;
BEGIN
  TLSBytes.AppendByte(b, 002H); TLSBytes.AppendByte(b, 041H); TLSBytes.AppendByte(b, 000H);
  i := 0; WHILE i < 64 DO TLSBytes.AppendByte(b, 255); INC(i) END
END AppendIntegerFF64;

PROCEDURE AppendIntegerOne(VAR b: TLSBytes.Buffer);
BEGIN
  TLSBytes.AppendByte(b, 002H); TLSBytes.AppendByte(b, 001H); TLSBytes.AppendByte(b, 001H)
END AppendIntegerOne;

PROCEDURE BuildSPKI(VAR spki: TLSBytes.Buffer);
VAR pkBody, pkSeq, bsBody, spkiBody: TLSBytes.Buffer;
BEGIN
  TLSBytes.Init(pkBody); AppendIntegerFF64(pkBody); AppendIntegerOne(pkBody); Wrap(030H, pkBody, pkSeq);
  TLSBytes.Init(bsBody); TLSBytes.AppendByte(bsBody, 0); TLSBytes.Append(bsBody, pkSeq);
  TLSBytes.Init(spkiBody); AppendAlgRSA(spkiBody); TLSBytes.AppendByte(spkiBody, 003H); PutLen(spkiBody, bsBody.len); TLSBytes.Append(spkiBody, bsBody);
  Wrap(030H, spkiBody, spki)
END BuildSPKI;

PROCEDURE BuildTBS(subject, issuer: CHAR; VAR tbs: TLSBytes.Buffer);
VAR body, spki: TLSBytes.Buffer;
BEGIN
  TLSBytes.Init(body);
  TLSBytes.AppendByte(body, 0A0H); TLSBytes.AppendByte(body, 003H); TLSBytes.AppendByte(body, 002H); TLSBytes.AppendByte(body, 001H); TLSBytes.AppendByte(body, 002H);
  TLSBytes.AppendByte(body, 002H); TLSBytes.AppendByte(body, 001H); TLSBytes.AppendByte(body, ORD(subject));
  AppendAlgSHA256RSA(body);
  AppendName(body, issuer);
  AppendValidity(body);
  AppendName(body, subject);
  BuildSPKI(spki); TLSBytes.Append(body, spki);
  Wrap(030H, body, tbs)
END BuildTBS;

PROCEDURE AppendDigestInfoSHA256(VAR digest: TLSBytes.Buffer; VAR out: TLSBytes.Buffer);
BEGIN
  TLSBytes.Init(out);
  TLSBytes.AppendByte(out, 030H); TLSBytes.AppendByte(out, 031H);
  TLSBytes.AppendByte(out, 030H); TLSBytes.AppendByte(out, 00DH);
  TLSBytes.AppendByte(out, 006H); TLSBytes.AppendByte(out, 009H);
  TLSBytes.AppendByte(out, 060H); TLSBytes.AppendByte(out, 086H); TLSBytes.AppendByte(out, 048H);
  TLSBytes.AppendByte(out, 001H); TLSBytes.AppendByte(out, 065H); TLSBytes.AppendByte(out, 003H);
  TLSBytes.AppendByte(out, 004H); TLSBytes.AppendByte(out, 002H); TLSBytes.AppendByte(out, 001H);
  TLSBytes.AppendByte(out, 005H); TLSBytes.AppendByte(out, 000H);
  TLSBytes.AppendByte(out, 004H); TLSBytes.AppendByte(out, 020H);
  TLSBytes.Append(out, digest)
END AppendDigestInfoSHA256;

PROCEDURE BuildSignatureForTBS(VAR tbs, sig: TLSBytes.Buffer);
VAR digest, di: TLSBytes.Buffer; d: TLSSHA256.Digest; i, ffCount: LONGINT;
BEGIN
  TLSSHA256.DigestBuffer(tbs, d); TLSSHA256.DigestToBuffer(d, digest); AppendDigestInfoSHA256(digest, di);
  TLSBytes.Init(sig); TLSBytes.AppendByte(sig, 0); TLSBytes.AppendByte(sig, 1);
  ffCount := 64 - 3 - di.len;
  i := 0; WHILE i < ffCount DO TLSBytes.AppendByte(sig, 255); INC(i) END;
  TLSBytes.AppendByte(sig, 0); TLSBytes.Append(sig, di)
END BuildSignatureForTBS;

PROCEDURE BuildCert(subject, issuer: CHAR; VAR cert: TLSBytes.Buffer);
VAR tbs, sig, body, sigBody: TLSBytes.Buffer;
BEGIN
  BuildTBS(subject, issuer, tbs); BuildSignatureForTBS(tbs, sig);
  TLSBytes.Init(body); TLSBytes.Append(body, tbs); AppendAlgSHA256RSA(body);
  TLSBytes.Init(sigBody); TLSBytes.AppendByte(sigBody, 0); TLSBytes.Append(sigBody, sig);
  TLSBytes.AppendByte(body, 003H); PutLen(body, sigBody.len); TLSBytes.Append(body, sigBody);
  Wrap(030H, body, cert)
END BuildCert;

BEGIN
  BuildCert("L", "I", leafDER);
  BuildCert("I", "R", interDER);
  BuildCert("R", "R", rootDER);
  TLSBytes.Copy(leafDER, badLeafDER);
  badLeafDER.data[badLeafDER.len-1] := TLSBytes.Byte(ORD(badLeafDER.data[badLeafDER.len-1]) + 1);
  TLSBytes.Copy(leafDER, certs[0]); TLSBytes.Copy(interDER, certs[1]); TLSBytes.Copy(rootDER, roots[0]);
  TLSX509Validity.SetTime(now, 2026, 1, 1, 0, 0, 0);

  PrintResult("chain trust", TLSX509Chain.CheckChainWithTrustAnchors(certs, 2, roots, 1, now, res));
  PrintResult("root found", res.rootFound);
  PrintResult("root trusted", res.rootTrusted);
  PrintResult("sigs ok", res.allSignaturesOK);
  PrintResult("times ok", res.allTimesOK);
  PrintResult("depth two", res.depth = 2);

  TLSBytes.Copy(badLeafDER, certs[0]);
  PrintResult("bad leaf reject", ~TLSX509Chain.CheckChainWithTrustAnchors(certs, 2, roots, 1, now, res));
  PrintResult("bad sig false", ~res.allSignaturesOK);

  TLSBytes.Copy(leafDER, certs[0]);
  PrintResult("missing root reject", ~TLSX509Chain.CheckChainWithTrustAnchors(certs, 2, roots, 0, now, res))
END TLSTestX509Chain.
