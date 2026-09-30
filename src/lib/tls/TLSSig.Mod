MODULE TLSSig;
(* Signature checks of certificates and of the TLS 1.3 CertificateVerify, with the keys of
   SubjectPublicKeyInfo: RSA (TLSRSA) and ECDSA on P-256 and P-384 (TLSECDSA). Algorithms not
   listed here are refused. *)
IMPORT TLSBytes, TLSASN1, TLSX509, TLSRSA, TLSECDSA;

CONST
  (** TLS 1.3 SignatureScheme values accepted for CertificateVerify (RFC 8446, 4.2.3) *)
  EcdsaP256Sha256* = 0403H; EcdsaP384Sha384* = 0503H;
  RsaPssRsaeSha256* = 0804H; RsaPssRsaeSha384* = 0805H; RsaPssRsaeSha512* = 0806H;

  RSA = 1; ECDSA = 2;

(* the OID bytes b equal oid *)
PROCEDURE Is(VAR oid: TLSBytes.Buffer; b0, b1, b2, b3, b4, b5, b6, b7, b8, len: LONGINT): BOOLEAN;
VAR b: ARRAY 9 OF LONGINT; i: LONGINT;
BEGIN
  IF oid.len # len THEN RETURN FALSE END;
  b[0] := b0; b[1] := b1; b[2] := b2; b[3] := b3; b[4] := b4; b[5] := b5; b[6] := b6; b[7] := b7; b[8] := b8;
  i := 0; WHILE i < len DO IF ORD(oid.data[i]) # b[i] THEN RETURN FALSE END; INC(i) END;
  RETURN TRUE
END Is;

(* the kind of key and the hash of a certificate signature algorithm *)
PROCEDURE CertAlgorithm(VAR oid: TLSBytes.Buffer; VAR kind, hash: LONGINT): BOOLEAN;
BEGIN
  kind := RSA;  (* 1.2.840.113549.1.1.11, 12, 13 *)
  IF Is(oid, 2AH, 86H, 48H, 86H, 0F7H, 0DH, 1, 1, 0BH, 9) THEN hash := TLSRSA.SHA256; RETURN TRUE END;
  IF Is(oid, 2AH, 86H, 48H, 86H, 0F7H, 0DH, 1, 1, 0CH, 9) THEN hash := TLSRSA.SHA384; RETURN TRUE END;
  IF Is(oid, 2AH, 86H, 48H, 86H, 0F7H, 0DH, 1, 1, 0DH, 9) THEN hash := TLSRSA.SHA512; RETURN TRUE END;
  kind := ECDSA;  (* 1.2.840.10045.4.3.2, 3, 4 *)
  IF Is(oid, 2AH, 86H, 48H, 0CEH, 3DH, 4, 3, 2, 0, 8) THEN hash := TLSRSA.SHA256; RETURN TRUE END;
  IF Is(oid, 2AH, 86H, 48H, 0CEH, 3DH, 4, 3, 3, 0, 8) THEN hash := TLSRSA.SHA384; RETURN TRUE END;
  IF Is(oid, 2AH, 86H, 48H, 0CEH, 3DH, 4, 3, 4, 0, 8) THEN hash := TLSRSA.SHA512; RETURN TRUE END;
  RETURN FALSE
END CertAlgorithm;

(** the curve (TLSECDSA.P256, P384) and the point (04 x y) of an EC SubjectPublicKeyInfo *)
PROCEDURE ECPublicKey*(VAR spki: TLSBytes.Buffer; VAR curve: LONGINT; VAR point: TLSBytes.Buffer): BOOLEAN;
VAR pos, lim, apos, alim: LONGINT; t: TLSASN1.TLV; oid, param: TLSBytes.Buffer;
BEGIN
  pos := 0;
  IF ~TLSASN1.EnterSequence(spki, pos, spki.len, pos, lim) THEN RETURN FALSE END;
  IF ~TLSASN1.EnterSequence(spki, pos, lim, apos, alim) THEN RETURN FALSE END;
  IF ~TLSASN1.ExpectTag(spki, apos, alim, TLSASN1.ObjectIdentifier, t) OR ~TLSASN1.CopyValue(spki, t, oid) THEN RETURN FALSE END;
  IF ~Is(oid, 2AH, 86H, 48H, 0CEH, 3DH, 2, 1, 0, 0, 7) THEN RETURN FALSE END;          (* id-ecPublicKey *)
  IF ~TLSASN1.ExpectTag(spki, apos, alim, TLSASN1.ObjectIdentifier, t) OR ~TLSASN1.CopyValue(spki, t, param) OR (apos # alim) THEN
    RETURN FALSE
  END;
  IF Is(param, 2AH, 86H, 48H, 0CEH, 3DH, 3, 1, 7, 0, 8) THEN curve := TLSECDSA.P256    (* prime256v1 *)
  ELSIF Is(param, 2BH, 81H, 4, 0, 22H, 0, 0, 0, 0, 5) THEN curve := TLSECDSA.P384      (* secp384r1 *)
  ELSE RETURN FALSE
  END;
  pos := alim;
  IF ~TLSASN1.ExpectTag(spki, pos, lim, TLSASN1.BitString, t) OR (t.len < 2) OR (spki.data[t.val] # 0X) OR (pos # lim) THEN
    RETURN FALSE
  END;
  TLSBytes.Slice(spki, t.val + 1, t.len - 1, point);
  RETURN TRUE
END ECPublicKey;

(* the signature sig (DER for ECDSA) of hash by the key in spki *)
PROCEDURE VerifyHash(kind, hash: LONGINT; pss: BOOLEAN; VAR spki, digest, sig: TLSBytes.Buffer): BOOLEAN;
VAR n, e, point, r, s: TLSBytes.Buffer; curve: LONGINT;
BEGIN
  IF kind = RSA THEN
    IF ~TLSRSA.PublicKey(spki, n, e) THEN RETURN FALSE END;
    IF pss THEN RETURN TLSRSA.VerifyPSS(n, e, hash, digest, sig)
    ELSE RETURN TLSRSA.VerifyPKCS1(n, e, hash, digest, sig)
    END
  ELSE
    RETURN ECPublicKey(spki, curve, point) & TLSECDSA.ParseSignature(sig, r, s) & TLSECDSA.Verify(curve, point, digest, r, s)
  END
END VerifyHash;

(** the certificate child is signed by the key of issuer *)
PROCEDURE CertSignedBy*(VAR child, issuer: TLSX509.CertInfo): BOOLEAN;
VAR kind, hash: LONGINT; digest: TLSBytes.Buffer;
BEGIN
  IF (child.signatureUnusedBits # 0) OR ~CertAlgorithm(child.sigAlgOID, kind, hash) THEN RETURN FALSE END;
  RETURN TLSRSA.Hash(hash, child.tbs, digest) & VerifyHash(kind, hash, FALSE, issuer.spki, digest, child.signature)
END CertSignedBy;

(** the CertificateVerify signature sig with scheme over content, by the key in spki (the leaf):
  ECDSA schemes need a key on their curve, RSA-PSS an RSA key; nothing else is accepted *)
PROCEDURE VerifyScheme*(scheme: LONGINT; VAR spki, content, sig: TLSBytes.Buffer): BOOLEAN;
VAR digest, point: TLSBytes.Buffer; curve, hash: LONGINT;
BEGIN
  IF (scheme = EcdsaP256Sha256) OR (scheme = EcdsaP384Sha384) THEN
    IF ~ECPublicKey(spki, curve, point) THEN RETURN FALSE END;
    IF (scheme = EcdsaP256Sha256) & (curve # TLSECDSA.P256) OR (scheme = EcdsaP384Sha384) & (curve # TLSECDSA.P384) THEN
      RETURN FALSE
    END;
    IF scheme = EcdsaP256Sha256 THEN hash := TLSRSA.SHA256 ELSE hash := TLSRSA.SHA384 END;
    RETURN TLSRSA.Hash(hash, content, digest) & VerifyHash(ECDSA, hash, FALSE, spki, digest, sig)
  ELSIF (scheme = RsaPssRsaeSha256) OR (scheme = RsaPssRsaeSha384) OR (scheme = RsaPssRsaeSha512) THEN
    IF scheme = RsaPssRsaeSha256 THEN hash := TLSRSA.SHA256
    ELSIF scheme = RsaPssRsaeSha384 THEN hash := TLSRSA.SHA384
    ELSE hash := TLSRSA.SHA512
    END;
    RETURN TLSRSA.Hash(hash, content, digest) & VerifyHash(RSA, hash, TRUE, spki, digest, sig)
  END;
  RETURN FALSE
END VerifyScheme;

END TLSSig.
