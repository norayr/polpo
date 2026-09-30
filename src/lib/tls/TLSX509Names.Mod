MODULE TLSX509Names;
IMPORT TLSBytes, TLSASN1, TLSX509;

CONST
  DNSNameTag* = 82H;      (* [2] dNSName, IA5String, primitive *)

PROCEDURE Lower(ch: CHAR): CHAR;
VAR o: LONGINT;
BEGIN
  o := ORD(ch);
  IF (o >= ORD("A")) & (o <= ORD("Z")) THEN ch := CHR(o + 32) END;
  RETURN ch
END Lower;

PROCEDURE HostLen(host: ARRAY OF CHAR): LONGINT;
VAR n: LONGINT;
BEGIN
  n := 0;
  WHILE (n < LEN(host)) & (host[n] # 0X) DO INC(n) END;
  RETURN n
END HostLen;

PROCEDURE OIDIsSubjectAltName(VAR oid: TLSBytes.Buffer): BOOLEAN;
BEGIN
  RETURN (oid.len = 3) &
         (ORD(oid.data[0]) = 55H) &
         (ORD(oid.data[1]) = 1DH) &
         (ORD(oid.data[2]) = 11H)
END OIDIsSubjectAltName;

PROCEDURE MatchExact(VAR name: TLSBytes.Buffer; host: ARRAY OF CHAR): BOOLEAN;
VAR i, hn: LONGINT; ok: BOOLEAN;
BEGIN
  hn := HostLen(host);
  ok := name.len = hn;
  i := 0;
  WHILE ok & (i < name.len) DO
    IF Lower(name.data[i]) # Lower(host[i]) THEN ok := FALSE END;
    INC(i)
  END;
  RETURN ok
END MatchExact;

PROCEDURE MatchWildcard(VAR name: TLSBytes.Buffer; host: ARRAY OF CHAR): BOOLEAN;
VAR hn, dot, i, j: LONGINT; ok: BOOLEAN;
BEGIN
  hn := HostLen(host);
  ok := FALSE;
  IF (name.len > 2) & (name.data[0] = "*") & (name.data[1] = ".") THEN
    dot := 0;
    WHILE (dot < hn) & (host[dot] # ".") DO INC(dot) END;
    IF (dot > 0) & (dot < hn - 1) THEN
      (* Host suffix after first dot must equal pattern after "*.". *)
      ok := (hn - dot - 1) = (name.len - 2);
      i := 2; j := dot + 1;
      WHILE ok & (i < name.len) DO
        IF Lower(name.data[i]) # Lower(host[j]) THEN ok := FALSE END;
        INC(i); INC(j)
      END
    END
  END;
  RETURN ok
END MatchWildcard;

PROCEDURE DNSNameMatches*(VAR name: TLSBytes.Buffer; host: ARRAY OF CHAR): BOOLEAN;
BEGIN
  RETURN MatchExact(name, host) OR MatchWildcard(name, host)
END DNSNameMatches;

PROCEDURE ExtractExtensionsFromTBS*(VAR tbs: TLSBytes.Buffer; VAR extensions: TLSBytes.Buffer): BOOLEAN;
VAR
  pos, lim, xp: LONGINT;
  t: TLSASN1.TLV;
  ok, found: BOOLEAN;
BEGIN
  TLSBytes.Init(extensions);
  pos := 0;
  ok := TLSASN1.EnterSequence(tbs, pos, tbs.len, pos, lim);

  IF ok THEN
    IF TLSASN1.PeekTLV(tbs, pos, lim, t) THEN
      IF t.tag = TLSASN1.Ctx0 THEN
        ok := TLSASN1.ExpectTag(tbs, pos, lim, TLSASN1.Ctx0, t)
      END
    ELSE
      ok := FALSE
    END
  END;

  IF ok THEN ok := TLSASN1.ExpectTag(tbs, pos, lim, TLSASN1.Integer, t) END;       (* serial *)
  IF ok THEN ok := TLSASN1.ExpectTag(tbs, pos, lim, TLSASN1.Sequence, t) END;      (* signature *)
  IF ok THEN ok := TLSASN1.ExpectTag(tbs, pos, lim, TLSASN1.Sequence, t) END;      (* issuer *)
  IF ok THEN ok := TLSASN1.ExpectTag(tbs, pos, lim, TLSASN1.Sequence, t) END;      (* validity *)
  IF ok THEN ok := TLSASN1.ExpectTag(tbs, pos, lim, TLSASN1.Sequence, t) END;      (* subject *)
  IF ok THEN ok := TLSASN1.ExpectTag(tbs, pos, lim, TLSASN1.Sequence, t) END;      (* spki *)

  found := FALSE;
  WHILE ok & (pos < lim) & ~found DO
    IF ~TLSASN1.ReadTLV(tbs, pos, lim, t) THEN
      ok := FALSE
    ELSE
      IF t.tag = TLSASN1.Ctx3 THEN
        (* Extensions is [3] EXPLICIT SEQUENCE OF Extension. *)
        xp := t.val;
        IF ~TLSASN1.ExpectTag(tbs, xp, t.next, TLSASN1.Sequence, t) THEN
          ok := FALSE
        ELSE
          TLSBytes.Slice(tbs, t.val, t.len, extensions);
          found := TRUE
        END
      END
    END
  END;
  RETURN ok & found
END ExtractExtensionsFromTBS;

PROCEDURE FindExtension*(VAR extensions: TLSBytes.Buffer; VAR wantOID: TLSBytes.Buffer; VAR extValue: TLSBytes.Buffer): BOOLEAN;
VAR
  pos, ep, elim: LONGINT;
  ext, oidTLV, valTLV: TLSASN1.TLV;
  oid: TLSBytes.Buffer;
  ok, found, dummy: BOOLEAN;
BEGIN
  TLSBytes.Init(extValue);
  pos := 0; found := FALSE; ok := TRUE;
  WHILE ok & (pos < extensions.len) & ~found DO
    IF ~TLSASN1.ExpectTag(extensions, pos, extensions.len, TLSASN1.Sequence, ext) THEN
      ok := FALSE
    ELSE
      ep := ext.val; elim := ext.next;
      IF ~TLSASN1.ExpectTag(extensions, ep, elim, TLSASN1.ObjectIdentifier, oidTLV) THEN
        ok := FALSE
      ELSE
        dummy := TLSASN1.CopyValue(extensions, oidTLV, oid);
        IF dummy & TLSBytes.EqualConstTime(oid, wantOID) THEN
          IF TLSASN1.PeekTLV(extensions, ep, elim, valTLV) THEN
            IF valTLV.tag = TLSASN1.Boolean THEN
              ok := TLSASN1.ExpectTag(extensions, ep, elim, TLSASN1.Boolean, valTLV)
            END
          ELSE
            ok := FALSE
          END;
          IF ok THEN
            IF ~TLSASN1.ExpectTag(extensions, ep, elim, TLSASN1.OctetString, valTLV) THEN
              ok := FALSE
            ELSE
              dummy := TLSASN1.CopyValue(extensions, valTLV, extValue);
              IF dummy THEN found := TRUE ELSE ok := FALSE END
            END
          END
        END
      END
    END
  END;
  RETURN ok & found
END FindExtension;

PROCEDURE SubjectAltNameValue*(VAR info: TLSX509.CertInfo; VAR sanValue: TLSBytes.Buffer): BOOLEAN;
VAR exts, oid: TLSBytes.Buffer;
BEGIN
  TLSBytes.Init(sanValue);
  TLSBytes.Init(oid);
  TLSBytes.AppendByte(oid, 55H); TLSBytes.AppendByte(oid, 1DH); TLSBytes.AppendByte(oid, 11H);
  IF ~ExtractExtensionsFromTBS(info.tbs, exts) THEN RETURN FALSE END;
  RETURN FindExtension(exts, oid, sanValue)
END SubjectAltNameValue;

PROCEDURE SubjectAltNameMatches*(VAR sanValue: TLSBytes.Buffer; host: ARRAY OF CHAR; VAR sawDNS: BOOLEAN): BOOLEAN;
VAR
  pos, lim: LONGINT;
  t: TLSASN1.TLV;
  name: TLSBytes.Buffer;
  ok, matched, dummy: BOOLEAN;
BEGIN
  sawDNS := FALSE; matched := FALSE; pos := 0;
  ok := TLSASN1.EnterSequence(sanValue, pos, sanValue.len, pos, lim);
  WHILE ok & (pos < lim) & ~matched DO
    IF ~TLSASN1.ReadTLV(sanValue, pos, lim, t) THEN
      ok := FALSE
    ELSE
      IF t.tag = DNSNameTag THEN
        sawDNS := TRUE;
        dummy := TLSASN1.CopyValue(sanValue, t, name);
        IF dummy & DNSNameMatches(name, host) THEN matched := TRUE END
      END
    END
  END;
  RETURN ok & matched
END SubjectAltNameMatches;

PROCEDURE CertMatchesHostname*(VAR der: TLSBytes.Buffer; host: ARRAY OF CHAR): BOOLEAN;
VAR info: TLSX509.CertInfo; san: TLSBytes.Buffer; sawDNS: BOOLEAN; ok: BOOLEAN;
BEGIN
  ok := TLSX509.ParseCertificate(der, info);
  IF ok THEN ok := SubjectAltNameValue(info, san) END;
  IF ok THEN ok := SubjectAltNameMatches(san, host, sawDNS) END;
  RETURN ok
END CertMatchesHostname;

END TLSX509Names.
