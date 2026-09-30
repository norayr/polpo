MODULE TLSX509Trust;
IMPORT TLSBytes, TLSPEM, TLSX509, TLSX509Validity, TLSRSAVerify;

TYPE
  Result* = RECORD
    leafParsed*, issuerFound*, issuerNameOK*, issuerSelfIssued*, leafTimeOK*, issuerTimeOK*: BOOLEAN;
    signaturesOK*: BOOLEAN;
    trustedByNameAndTime*: BOOLEAN;
    trusted*: BOOLEAN;
    issuerDer*: TLSBytes.Buffer
  END;

PROCEDURE EqualDER*(VAR a, b: TLSBytes.Buffer): BOOLEAN;
BEGIN
  RETURN TLSBytes.EqualConstTime(a, b)
END EqualDER;

PROCEDURE SubjectEqualsIssuer*(VAR subjectCert, issuerCert: TLSX509.CertInfo): BOOLEAN;
BEGIN
  RETURN EqualDER(subjectCert.issuer, issuerCert.subject)
END SubjectEqualsIssuer;

PROCEDURE IsSelfIssued*(VAR info: TLSX509.CertInfo): BOOLEAN;
BEGIN
  RETURN EqualDER(info.issuer, info.subject)
END IsSelfIssued;

PROCEDURE ResetResult(VAR res: Result);
BEGIN
  res.leafParsed := FALSE; res.issuerFound := FALSE; res.issuerNameOK := FALSE;
  res.issuerSelfIssued := FALSE; res.leafTimeOK := FALSE; res.issuerTimeOK := FALSE;
  res.signaturesOK := FALSE; res.trustedByNameAndTime := FALSE; res.trusted := FALSE;
  TLSBytes.Init(res.issuerDer)
END ResetResult;

PROCEDURE FindIssuerInPEMBundle*(VAR leafInfo: TLSX509.CertInfo; VAR bundle: ARRAY OF CHAR; VAR issuerDER: TLSBytes.Buffer; VAR issuerInfo: TLSX509.CertInfo): BOOLEAN;
VAR from: LONGINT; der: TLSBytes.Buffer; ok, found: BOOLEAN;
BEGIN
  from := 0; found := FALSE; TLSBytes.Init(issuerDER);
  WHILE (~found) & TLSPEM.NextCertificateDER(bundle, from, der) DO
    ok := TLSX509.ParseCertificate(der, issuerInfo);
    IF ok THEN
      IF EqualDER(leafInfo.issuer, issuerInfo.subject) THEN
        TLSBytes.Copy(der, issuerDER);
        found := TRUE
      END
    END
  END;
  RETURN found
END FindIssuerInPEMBundle;

PROCEDURE CheckLeafWithIssuerNameTimeSig*(VAR leafDER, issuerDER: TLSBytes.Buffer; VAR now: TLSX509Validity.Time; VAR res: Result): BOOLEAN;
VAR leaf, issuer: TLSX509.CertInfo;
BEGIN
  ResetResult(res);
  TLSBytes.Copy(issuerDER, res.issuerDer);
  res.leafParsed := TLSX509.ParseCertificate(leafDER, leaf);
  IF res.leafParsed THEN
    res.leafTimeOK := TLSX509Validity.ValidAt(leaf, now);
    res.issuerFound := TLSX509.ParseCertificate(issuerDER, issuer);
    IF res.issuerFound THEN
      res.issuerNameOK := SubjectEqualsIssuer(leaf, issuer);
      res.issuerSelfIssued := IsSelfIssued(issuer);
      res.issuerTimeOK := TLSX509Validity.ValidAt(issuer, now);
      res.signaturesOK := TLSRSAVerify.VerifyCertSignatureSHA256RSA(leafDER, issuerDER)
    END
  END;
  res.trustedByNameAndTime := res.leafParsed & res.issuerFound & res.issuerNameOK & res.issuerSelfIssued & res.leafTimeOK & res.issuerTimeOK;
  res.trusted := res.trustedByNameAndTime & res.signaturesOK;
  RETURN res.trusted
END CheckLeafWithIssuerNameTimeSig;

PROCEDURE CheckLeafWithBundleNameTime*(VAR leafDER: TLSBytes.Buffer; VAR bundle: ARRAY OF CHAR; VAR now: TLSX509Validity.Time; VAR res: Result): BOOLEAN;
VAR leaf, issuer: TLSX509.CertInfo;
BEGIN
  ResetResult(res);
  res.leafParsed := TLSX509.ParseCertificate(leafDER, leaf);
  IF res.leafParsed THEN
    res.leafTimeOK := TLSX509Validity.ValidAt(leaf, now);
    res.issuerFound := FindIssuerInPEMBundle(leaf, bundle, res.issuerDer, issuer);
    IF res.issuerFound THEN
      res.issuerNameOK := SubjectEqualsIssuer(leaf, issuer);
      res.issuerSelfIssued := IsSelfIssued(issuer);
      res.issuerTimeOK := TLSX509Validity.ValidAt(issuer, now)
    END
  END;
  res.trustedByNameAndTime := res.leafParsed & res.issuerFound & res.issuerNameOK & res.issuerSelfIssued & res.leafTimeOK & res.issuerTimeOK;
  RETURN res.trustedByNameAndTime
END CheckLeafWithBundleNameTime;

PROCEDURE CheckLeafWithBundle*(VAR leafDER: TLSBytes.Buffer; VAR bundle: ARRAY OF CHAR; VAR now: TLSX509Validity.Time; VAR res: Result): BOOLEAN;
VAR leaf, issuer: TLSX509.CertInfo;
BEGIN
  ResetResult(res);
  res.leafParsed := TLSX509.ParseCertificate(leafDER, leaf);
  IF res.leafParsed THEN
    res.leafTimeOK := TLSX509Validity.ValidAt(leaf, now);
    res.issuerFound := FindIssuerInPEMBundle(leaf, bundle, res.issuerDer, issuer);
    IF res.issuerFound THEN
      res.issuerNameOK := SubjectEqualsIssuer(leaf, issuer);
      res.issuerSelfIssued := IsSelfIssued(issuer);
      res.issuerTimeOK := TLSX509Validity.ValidAt(issuer, now);
      res.signaturesOK := TLSRSAVerify.VerifyCertSignatureSHA256RSA(leafDER, res.issuerDer)
    END
  END;
  res.trustedByNameAndTime := res.leafParsed & res.issuerFound & res.issuerNameOK & res.issuerSelfIssued & res.leafTimeOK & res.issuerTimeOK;
  res.trusted := res.trustedByNameAndTime & res.signaturesOK;
  RETURN res.trusted
END CheckLeafWithBundle;

END TLSX509Trust.
