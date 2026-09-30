MODULE TLSTestX509Trust;
IMPORT Out := out, TLSBytes, TLSPEM, TLSX509, TLSX509Validity, TLSX509Trust, TLSBase64;

VAR
  LeafPEM, BundlePEM: ARRAY 2048 OF CHAR;
  leafDER, caDER: TLSBytes.Buffer;
  leafInfo, caInfo: TLSX509.CertInfo;
  nb, na, now, old: TLSX509Validity.Time;
  res: TLSX509Trust.Result;
  ok: BOOLEAN;

PROCEDURE AppendText(VAR dst: ARRAY OF CHAR; VAR pos: LONGINT; s: ARRAY OF CHAR);
VAR i: LONGINT;
BEGIN
  i := 0;
  WHILE (s[i] # 0X) & (pos < LEN(dst)-1) DO
    dst[pos] := s[i]; INC(pos); INC(i)
  END;
  dst[pos] := 0X
END AppendText;

PROCEDURE AppendLF(VAR dst: ARRAY OF CHAR; VAR pos: LONGINT);
BEGIN
  IF pos < LEN(dst)-1 THEN
    dst[pos] := 0AX; INC(pos); dst[pos] := 0X
  END
END AppendLF;

PROCEDURE BuildLeafPEM;
VAR p: LONGINT;
BEGIN
  p := 0;
  AppendText(LeafPEM, p, "-----BEGIN CERTIFICATE-----"); AppendLF(LeafPEM, p);
  AppendText(LeafPEM, p, "MIGIMHKgAwIBAgIBAjANBgkqhkiG9w0BAQsFADASMRAwDgYDVQQDEwdUZXN0IENBMB4XDTI0MDEwMTAwMDAwMFoXDTMwMDEwMTAw");
  AppendText(LeafPEM, p, "MDAwMFowDzENMAsGA1UEAxMETGVhZjAUMA0GCSqGSIb3DQEBAQUAAwMAMAAwDQYJKoZIhvcNAQELBQADAwCquw=="); AppendLF(LeafPEM, p);
  AppendText(LeafPEM, p, "-----END CERTIFICATE-----"); AppendLF(LeafPEM, p)
END BuildLeafPEM;

PROCEDURE BuildBundlePEM;
VAR p: LONGINT;
BEGIN
  p := 0;
  AppendText(BundlePEM, p, "-----BEGIN CERTIFICATE-----"); AppendLF(BundlePEM, p);
  AppendText(BundlePEM, p, "MIGLMHWgAwIBAgIBATANBgkqhkiG9w0BAQsFADASMRAwDgYDVQQDEwdUZXN0IENBMB4XDTI0MDEwMTAwMDAwMFoXDTMwMDEwMTAw");
  AppendText(BundlePEM, p, "MDAwMFowEjEQMA4GA1UEAxMHVGVzdCBDQTAUMA0GCSqGSIb3DQEBAQUAAwMAMAAwDQYJKoZIhvcNAQELBQADAwCquw=="); AppendLF(BundlePEM, p);
  AppendText(BundlePEM, p, "-----END CERTIFICATE-----"); AppendLF(BundlePEM, p)
END BuildBundlePEM;

PROCEDURE Say(name: ARRAY OF CHAR; ok: BOOLEAN);
BEGIN
  Out.String(name);
  IF ok THEN Out.String(" OK") ELSE Out.String(" FAIL") END;
  Out.Ln
END Say;

PROCEDURE PrintTime(prefix: ARRAY OF CHAR; VAR t: TLSX509Validity.Time);
BEGIN
  Out.String(prefix); Out.Int(t.year, 0); Out.Char("-"); Out.Int(t.month, 0); Out.Char("-"); Out.Int(t.day, 0);
  Out.Char(" "); Out.Int(t.hour, 0); Out.Char(":"); Out.Int(t.minute, 0); Out.Char(":"); Out.Int(t.second, 0); Out.Ln
END PrintTime;

BEGIN
  BuildLeafPEM;
  BuildBundlePEM;

  ok := TLSPEM.FirstCertificateDER(LeafPEM, leafDER);
  Say("leaf pem", ok);
  ok := TLSPEM.FirstCertificateDER(BundlePEM, caDER);
  Say("ca pem", ok);

  ok := TLSX509.ParseCertificate(leafDER, leafInfo);
  Say("leaf parse", ok);
  ok := TLSX509.ParseCertificate(caDER, caInfo);
  Say("ca parse", ok);

  ok := TLSX509Validity.ExtractValidity(leafInfo, nb, na);
  Say("leaf validity parse", ok);
  IF ok THEN PrintTime("notBefore ", nb); PrintTime("notAfter  ", na) END;

  TLSX509Validity.SetTime(now, 2026, 6, 1, 0, 0, 0);
  Say("leaf valid at 2026", TLSX509Validity.ValidAt(leafInfo, now));
  TLSX509Validity.SetTime(old, 2020, 1, 1, 0, 0, 0);
  Say("leaf invalid at 2020", ~TLSX509Validity.ValidAt(leafInfo, old));

  Say("issuer name matches", TLSX509Trust.SubjectEqualsIssuer(leafInfo, caInfo));
  Say("ca self-issued", TLSX509Trust.IsSelfIssued(caInfo));

  TLSX509Validity.SetTime(now, 2026, 6, 1, 0, 0, 0);
  ok := TLSX509Trust.CheckLeafWithBundleNameTime(leafDER, BundlePEM, now, res);
  Say("bundle name+time trust", ok);
  Say("issuer found", res.issuerFound);
  Say("issuer self", res.issuerSelfIssued);
  Say("signatures still TODO", ~res.signaturesOK)
END TLSTestX509Trust.
