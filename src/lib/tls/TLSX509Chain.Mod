MODULE TLSX509Chain;
IMPORT TLSBytes, TLSPEM, TLSX509, TLSX509Validity, TLSRSAVerify;

CONST
  MaxDepth* = 8;

TYPE
  Result* = RECORD
    leafParsed*, allTimesOK*, allNamesOK*, allSignaturesOK*: BOOLEAN;
    rootFound*, rootTrusted*, trusted*: BOOLEAN;
    depth*: LONGINT;
    failedAt*: LONGINT;
    rootDer*: TLSBytes.Buffer
  END;

PROCEDURE Reset(VAR r: Result);
BEGIN
  r.leafParsed := FALSE; r.allTimesOK := TRUE; r.allNamesOK := TRUE;
  r.allSignaturesOK := TRUE; r.rootFound := FALSE; r.rootTrusted := FALSE;
  r.trusted := FALSE; r.depth := 0; r.failedAt := -1; TLSBytes.Init(r.rootDer)
END Reset;

PROCEDURE SameName(VAR a, b: TLSBytes.Buffer): BOOLEAN;
BEGIN
  RETURN TLSBytes.EqualConstTime(a, b)
END SameName;

PROCEDURE FindIssuerInProvidedCerts(VAR cur: TLSX509.CertInfo; VAR certs: ARRAY OF TLSBytes.Buffer; certCount: LONGINT; VAR issuerDER: TLSBytes.Buffer; VAR issuerInfo: TLSX509.CertInfo): BOOLEAN;
VAR i: LONGINT; ok, found: BOOLEAN;
BEGIN
  found := FALSE; i := 1; TLSBytes.Init(issuerDER);
  WHILE (~found) & (i < certCount) & (i < LEN(certs)) DO
    ok := TLSX509.ParseCertificate(certs[i], issuerInfo);
    IF ok THEN
      IF SameName(cur.issuer, issuerInfo.subject) THEN
        TLSBytes.Copy(certs[i], issuerDER); found := TRUE
      END
    END;
    INC(i)
  END;
  RETURN found
END FindIssuerInProvidedCerts;

PROCEDURE FindIssuerInTrustAnchors(VAR cur: TLSX509.CertInfo; VAR roots: ARRAY OF TLSBytes.Buffer; rootCount: LONGINT; VAR rootDER: TLSBytes.Buffer; VAR rootInfo: TLSX509.CertInfo): BOOLEAN;
VAR i: LONGINT; ok, found: BOOLEAN;
BEGIN
  found := FALSE; i := 0; TLSBytes.Init(rootDER);
  WHILE (~found) & (i < rootCount) & (i < LEN(roots)) DO
    ok := TLSX509.ParseCertificate(roots[i], rootInfo);
    IF ok THEN
      IF SameName(cur.issuer, rootInfo.subject) THEN
        TLSBytes.Copy(roots[i], rootDER); found := TRUE
      END
    END;
    INC(i)
  END;
  RETURN found
END FindIssuerInTrustAnchors;

PROCEDURE FindIssuerInPEMBundle(VAR cur: TLSX509.CertInfo; VAR bundle: ARRAY OF CHAR; VAR rootDER: TLSBytes.Buffer; VAR rootInfo: TLSX509.CertInfo): BOOLEAN;
VAR from: LONGINT; der: TLSBytes.Buffer; ok, found: BOOLEAN;
BEGIN
  from := 0; found := FALSE; TLSBytes.Init(rootDER);
  WHILE (~found) & TLSPEM.NextCertificateDER(bundle, from, der) DO
    ok := TLSX509.ParseCertificate(der, rootInfo);
    IF ok THEN
      IF SameName(cur.issuer, rootInfo.subject) THEN
        TLSBytes.Copy(der, rootDER); found := TRUE
      END
    END
  END;
  RETURN found
END FindIssuerInPEMBundle;

PROCEDURE StepNameTimeOK(VAR child, issuer: TLSX509.CertInfo; VAR now: TLSX509Validity.Time): BOOLEAN;
VAR ok: BOOLEAN;
BEGIN
  ok := SameName(child.issuer, issuer.subject);
  IF ok THEN ok := TLSX509Validity.ValidAt(issuer, now) END;
  RETURN ok
END StepNameTimeOK;

PROCEDURE StepSignatureOK(VAR childDER, issuerDER: TLSBytes.Buffer): BOOLEAN;
BEGIN
  RETURN TLSRSAVerify.VerifyCertSignatureSHA256RSA(childDER, issuerDER)
END StepSignatureOK;

PROCEDURE CheckChainWithTrustAnchors*(VAR certs: ARRAY OF TLSBytes.Buffer; certCount: LONGINT; VAR roots: ARRAY OF TLSBytes.Buffer; rootCount: LONGINT; VAR now: TLSX509Validity.Time; VAR r: Result): BOOLEAN;
VAR
  curDER, issuerDER, anchorDER: TLSBytes.Buffer;
  cur, issuer, anchor: TLSX509.CertInfo;
  depth: LONGINT;
  found, ok, done, stepOK, sigOK: BOOLEAN;
BEGIN
  Reset(r);
  IF (certCount <= 0) OR (LEN(certs) <= 0) THEN RETURN FALSE END;
  TLSBytes.Copy(certs[0], curDER);
  r.leafParsed := TLSX509.ParseCertificate(curDER, cur);
  IF ~r.leafParsed THEN r.failedAt := 0; RETURN FALSE END;
  IF ~TLSX509Validity.ValidAt(cur, now) THEN r.allTimesOK := FALSE; r.failedAt := 0; RETURN FALSE END;

  depth := 0; done := FALSE; ok := TRUE;
  WHILE ok & ~done & (depth < MaxDepth) DO
    INC(depth); r.depth := depth;

    found := FindIssuerInProvidedCerts(cur, certs, certCount, issuerDER, issuer);
    IF ~found THEN found := FindIssuerInTrustAnchors(cur, roots, rootCount, issuerDER, issuer) END;

    IF found & TLSBytes.EqualConstTime(issuerDER, curDER) & ~FindIssuerInTrustAnchors(cur, roots, rootCount, anchorDER, anchor) THEN
      found := FALSE  (* self-signed and not a trust anchor: an unknown root *)
    END;
    IF found THEN
      stepOK := StepNameTimeOK(cur, issuer, now);
      IF ~stepOK THEN
        ok := FALSE; r.failedAt := depth;
        r.allNamesOK := SameName(cur.issuer, issuer.subject);
        r.allTimesOK := TLSX509Validity.ValidAt(issuer, now)
      ELSE
        sigOK := StepSignatureOK(curDER, issuerDER);
        IF ~sigOK THEN r.allSignaturesOK := FALSE END;
        (* separate variables: the search clears and overwrites its results, and issuerDER and
           issuer are needed for the next step (they came back empty, so the next signature failed) *)
        IF FindIssuerInTrustAnchors(cur, roots, rootCount, anchorDER, anchor) THEN
          (* The issuer we selected is a trust anchor. *)
          r.rootFound := TRUE; r.rootTrusted := TRUE; TLSBytes.Copy(anchorDER, r.rootDer); done := TRUE
        ELSE
          (* Continue with server-provided intermediate.  Signature failure is recorded but does not stop path discovery. *)
          TLSBytes.Copy(issuerDER, curDER); cur := issuer
        END
      END
    ELSE
      ok := FALSE; r.failedAt := depth; r.rootFound := FALSE
    END
  END;
  IF depth >= MaxDepth THEN ok := FALSE END;
  r.trusted := ok & done & r.rootTrusted & r.allTimesOK & r.allNamesOK & r.allSignaturesOK;
  RETURN r.trusted
END CheckChainWithTrustAnchors;

PROCEDURE CheckChainWithPEMBundle*(VAR certs: ARRAY OF TLSBytes.Buffer; certCount: LONGINT; VAR bundle: ARRAY OF CHAR; VAR now: TLSX509Validity.Time; VAR r: Result): BOOLEAN;
VAR
  curDER, issuerDER: TLSBytes.Buffer;
  cur, issuer, tmpIssuer: TLSX509.CertInfo;
  depth: LONGINT;
  foundInter, foundRoot, ok, done, stepOK, sigOK: BOOLEAN;
  tmpDER: TLSBytes.Buffer;
BEGIN
  Reset(r);
  IF (certCount <= 0) OR (LEN(certs) <= 0) THEN RETURN FALSE END;
  TLSBytes.Copy(certs[0], curDER);
  r.leafParsed := TLSX509.ParseCertificate(curDER, cur);
  IF ~r.leafParsed THEN r.failedAt := 0; RETURN FALSE END;
  IF ~TLSX509Validity.ValidAt(cur, now) THEN r.allTimesOK := FALSE; r.failedAt := 0; RETURN FALSE END;

  depth := 0; done := FALSE; ok := TRUE;
  WHILE ok & ~done & (depth < MaxDepth) DO
    INC(depth); r.depth := depth;

    foundInter := FindIssuerInProvidedCerts(cur, certs, certCount, issuerDER, issuer);
    foundRoot := FindIssuerInPEMBundle(cur, bundle, tmpDER, tmpIssuer);

    IF foundRoot THEN
      (* Prefer the trust anchor if it directly signs current certificate. *)
      TLSBytes.Copy(tmpDER, issuerDER); issuer := tmpIssuer;
      stepOK := StepNameTimeOK(cur, issuer, now);
      IF ~stepOK THEN
        ok := FALSE; r.failedAt := depth;
        r.allNamesOK := SameName(cur.issuer, issuer.subject);
        r.allTimesOK := TLSX509Validity.ValidAt(issuer, now)
      ELSE
        sigOK := StepSignatureOK(curDER, issuerDER);
        IF ~sigOK THEN r.allSignaturesOK := FALSE END;
        r.rootFound := TRUE; r.rootTrusted := TRUE; TLSBytes.Copy(issuerDER, r.rootDer); done := TRUE
      END
    ELSIF foundInter & TLSBytes.EqualConstTime(issuerDER, curDER) THEN
      (* self-signed and not in the bundle: an unknown root (it looped up to MaxDepth) *)
      ok := FALSE; r.failedAt := depth; r.rootFound := FALSE
    ELSIF foundInter THEN
      stepOK := StepNameTimeOK(cur, issuer, now);
      IF ~stepOK THEN
        ok := FALSE; r.failedAt := depth;
        r.allNamesOK := SameName(cur.issuer, issuer.subject);
        r.allTimesOK := TLSX509Validity.ValidAt(issuer, now)
      ELSE
        sigOK := StepSignatureOK(curDER, issuerDER);
        IF ~sigOK THEN r.allSignaturesOK := FALSE END;
        TLSBytes.Copy(issuerDER, curDER); cur := issuer
      END
    ELSE
      ok := FALSE; r.failedAt := depth; r.rootFound := FALSE
    END
  END;
  IF depth >= MaxDepth THEN ok := FALSE END;
  r.trusted := ok & done & r.rootTrusted & r.allTimesOK & r.allNamesOK & r.allSignaturesOK;
  RETURN r.trusted
END CheckChainWithPEMBundle;

END TLSX509Chain.
