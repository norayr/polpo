MODULE TLSTestRSAVerify;
IMPORT Out := out, TLSBytes, TLSSHA256, TLSRSAVerify, TLSBigInt;

VAR modulus, exponent, tbs, sig, badsig: TLSBytes.Buffer;

PROCEDURE PrintResult(name: ARRAY OF CHAR; ok: BOOLEAN);
BEGIN
  Out.String(name);
  IF ok THEN Out.String(" OK") ELSE Out.String(" FAIL") END;
  Out.Ln
END PrintResult;

PROCEDURE BuildSyntheticKey;
VAR i: LONGINT;
BEGIN
  TLSBytes.Init(modulus);
  i := 0;
  WHILE i < 64 DO TLSBytes.AppendByte(modulus, 255); INC(i) END;
  TLSBytes.Init(exponent); TLSBytes.AppendByte(exponent, 1)
END BuildSyntheticKey;

PROCEDURE BuildTBS;
BEGIN
  TLSBytes.Init(tbs);
  TLSBytes.AppendByte(tbs, ORD("a"));
  TLSBytes.AppendByte(tbs, ORD("b"));
  TLSBytes.AppendByte(tbs, ORD("c"))
END BuildTBS;

PROCEDURE BuildSignature;
VAR digest, di: TLSBytes.Buffer; d: TLSSHA256.Digest; i, ffCount: LONGINT;
BEGIN
  TLSSHA256.DigestBuffer(tbs, d);
  TLSSHA256.DigestToBuffer(d, digest);
  (* DigestInfo for SHA256. *)
  TLSBytes.Init(di);
  TLSBytes.AppendByte(di, 030H); TLSBytes.AppendByte(di, 031H);
  TLSBytes.AppendByte(di, 030H); TLSBytes.AppendByte(di, 00DH);
  TLSBytes.AppendByte(di, 006H); TLSBytes.AppendByte(di, 009H);
  TLSBytes.AppendByte(di, 060H); TLSBytes.AppendByte(di, 086H); TLSBytes.AppendByte(di, 048H);
  TLSBytes.AppendByte(di, 001H); TLSBytes.AppendByte(di, 065H); TLSBytes.AppendByte(di, 003H);
  TLSBytes.AppendByte(di, 004H); TLSBytes.AppendByte(di, 002H); TLSBytes.AppendByte(di, 001H);
  TLSBytes.AppendByte(di, 005H); TLSBytes.AppendByte(di, 000H);
  TLSBytes.AppendByte(di, 004H); TLSBytes.AppendByte(di, 020H);
  TLSBytes.Append(di, digest);

  TLSBytes.Init(sig);
  TLSBytes.AppendByte(sig, 0); TLSBytes.AppendByte(sig, 1);
  ffCount := 64 - 3 - di.len;
  i := 0; WHILE i < ffCount DO TLSBytes.AppendByte(sig, 255); INC(i) END;
  TLSBytes.AppendByte(sig, 0);
  TLSBytes.Append(sig, di);
  TLSBytes.Copy(sig, badsig);
  badsig.data[badsig.len-1] := TLSBytes.Byte(ORD(badsig.data[badsig.len-1]) + 1)
END BuildSignature;

BEGIN
  BuildSyntheticKey;
  BuildTBS;
  BuildSignature;
  Out.String("sig len = "); Out.Int(sig.len, 0); Out.Ln;
  PrintResult("rsa pkcs1 sha256", TLSRSAVerify.VerifyPKCS1SHA256(modulus, exponent, tbs, sig));
  PrintResult("bad signature", ~TLSRSAVerify.VerifyPKCS1SHA256(modulus, exponent, tbs, badsig));
END TLSTestRSAVerify.
