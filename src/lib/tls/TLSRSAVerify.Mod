MODULE TLSRSAVerify;
IMPORT TLSBytes, TLSASN1, TLSX509, TLSBigInt, TLSSHA256;

PROCEDURE IsRSAEncryptionOID*(VAR oid: TLSBytes.Buffer): BOOLEAN;
BEGIN
  RETURN (oid.len = 9) &
    (ORD(oid.data[0]) = 02AH) & (ORD(oid.data[1]) = 086H) & (ORD(oid.data[2]) = 048H) &
    (ORD(oid.data[3]) = 086H) & (ORD(oid.data[4]) = 0F7H) & (ORD(oid.data[5]) = 00DH) &
    (ORD(oid.data[6]) = 001H) & (ORD(oid.data[7]) = 001H) & (ORD(oid.data[8]) = 001H)
END IsRSAEncryptionOID;

PROCEDURE IsSHA256WithRSAOID*(VAR oid: TLSBytes.Buffer): BOOLEAN;
BEGIN
  RETURN (oid.len = 9) &
    (ORD(oid.data[0]) = 02AH) & (ORD(oid.data[1]) = 086H) & (ORD(oid.data[2]) = 048H) &
    (ORD(oid.data[3]) = 086H) & (ORD(oid.data[4]) = 0F7H) & (ORD(oid.data[5]) = 00DH) &
    (ORD(oid.data[6]) = 001H) & (ORD(oid.data[7]) = 001H) & (ORD(oid.data[8]) = 00BH)
END IsSHA256WithRSAOID;

PROCEDURE CopyIntegerValue(VAR der: TLSBytes.Buffer; VAR t: TLSASN1.TLV; VAR out: TLSBytes.Buffer): BOOLEAN;
VAR raw: TLSBytes.Buffer;
BEGIN
  IF ~TLSASN1.CopyValue(der, t, raw) THEN RETURN FALSE END;
  TLSBigInt.StripLeadingZero(raw, out);
  RETURN TRUE
END CopyIntegerValue;

PROCEDURE ParseRSAPublicKeyFromSPKI*(VAR spki: TLSBytes.Buffer; VAR modulus, exponent: TLSBytes.Buffer): BOOLEAN;
VAR pos, lim, keyPos, keyLim: LONGINT; t: TLSASN1.TLV; algOID, keyDer: TLSBytes.Buffer; ok: BOOLEAN;
BEGIN
  ok := TRUE; TLSBytes.Init(modulus); TLSBytes.Init(exponent);
  pos := 0;
  IF ~TLSASN1.EnterSequence(spki, pos, spki.len, pos, lim) THEN ok := FALSE END;
  IF ok THEN
    IF ~TLSX509.ParseAlgorithmIdentifier(spki, pos, lim, algOID) THEN ok := FALSE END
  END;
  IF ok THEN
    IF ~IsRSAEncryptionOID(algOID) THEN ok := FALSE END
  END;
  IF ok THEN
    IF ~TLSASN1.ExpectTag(spki, pos, lim, TLSASN1.BitString, t) THEN ok := FALSE END
  END;
  IF ok THEN
    IF t.len < 2 THEN ok := FALSE END
  END;
  IF ok THEN
    IF spki.data[t.val] # 0X THEN ok := FALSE END
  END;
  IF ok THEN
    TLSBytes.Slice(spki, t.val + 1, t.len - 1, keyDer);
    keyPos := 0;
    IF ~TLSASN1.EnterSequence(keyDer, keyPos, keyDer.len, keyPos, keyLim) THEN ok := FALSE END
  END;
  IF ok THEN
    IF ~TLSASN1.ExpectTag(keyDer, keyPos, keyLim, TLSASN1.Integer, t) THEN ok := FALSE END;
    IF ok THEN IF ~CopyIntegerValue(keyDer, t, modulus) THEN ok := FALSE END END
  END;
  IF ok THEN
    IF ~TLSASN1.ExpectTag(keyDer, keyPos, keyLim, TLSASN1.Integer, t) THEN ok := FALSE END;
    IF ok THEN IF ~CopyIntegerValue(keyDer, t, exponent) THEN ok := FALSE END END
  END;
  RETURN ok
END ParseRSAPublicKeyFromSPKI;

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

PROCEDURE VerifyPKCS1SHA256*(VAR modulus, exponent, tbs, signature: TLSBytes.Buffer): BOOLEAN;
VAR decoded, padded, digest, di: TLSBytes.Buffer; d: TLSSHA256.Digest; i, ffEnd: LONGINT; ok: BOOLEAN;
BEGIN
  ok := TRUE;
  IF modulus.len < 64 THEN ok := FALSE END;
  IF ok THEN
    TLSSHA256.DigestBuffer(tbs, d);
    TLSSHA256.DigestToBuffer(d, digest);
    AppendDigestInfoSHA256(digest, di);
    TLSBigInt.ModExp(signature, exponent, modulus, decoded);
    IF ~TLSBigInt.LeftPad(decoded, modulus.len, padded) THEN ok := FALSE END
  END;
  IF ok THEN
    IF padded.len # modulus.len THEN ok := FALSE END
  END;
  IF ok THEN
    IF padded.data[0] # 0X THEN ok := FALSE END;
    IF padded.data[1] # 1X THEN ok := FALSE END
  END;
  IF ok THEN
    ffEnd := padded.len - di.len - 1;
    IF ffEnd < 10 THEN ok := FALSE END
  END;
  IF ok THEN
    i := 2;
    WHILE ok & (i < ffEnd) DO
      IF ORD(padded.data[i]) # 255 THEN ok := FALSE END;
      INC(i)
    END;
    IF ok THEN IF padded.data[ffEnd] # 0X THEN ok := FALSE END END
  END;
  IF ok THEN
    i := 0;
    WHILE ok & (i < di.len) DO
      IF padded.data[ffEnd + 1 + i] # di.data[i] THEN ok := FALSE END;
      INC(i)
    END
  END;
  RETURN ok
END VerifyPKCS1SHA256;

PROCEDURE VerifyCertSignatureSHA256RSA*(VAR leafDER, issuerDER: TLSBytes.Buffer): BOOLEAN;
VAR leaf, issuer: TLSX509.CertInfo; modulus, exponent: TLSBytes.Buffer; ok: BOOLEAN;
BEGIN
  ok := TRUE;
  IF ~TLSX509.ParseCertificate(leafDER, leaf) THEN ok := FALSE END;
  IF ok THEN IF ~TLSX509.ParseCertificate(issuerDER, issuer) THEN ok := FALSE END END;
  IF ok THEN IF ~IsSHA256WithRSAOID(leaf.sigAlgOID) THEN ok := FALSE END END;
  IF ok THEN IF ~ParseRSAPublicKeyFromSPKI(issuer.spki, modulus, exponent) THEN ok := FALSE END END;
  IF ok THEN ok := VerifyPKCS1SHA256(modulus, exponent, leaf.tbs, leaf.signature) END;
  RETURN ok
END VerifyCertSignatureSHA256RSA;

END TLSRSAVerify.
