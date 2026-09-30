MODULE TLSRSA;
(* RSA signature verification (RFC 8017) with TLSNum: PKCS#1 v1.5 (certificates) and PSS
   (TLS 1.3 CertificateVerify), with SHA-256, SHA-384 and SHA-512.
   PKCS#1 v1.5 is checked by building the whole expected encoding and comparing it byte for byte
   (no parsing of the padding). Moduli below 2048 bits are refused. *)
IMPORT TLSBytes, TLSNum, TLSSHA256, TLSSHA512, TLSASN1, TLSX509;

CONST
  SHA256* = 1; SHA384* = 2; SHA512* = 3;  (** hash algorithms *)
  MinBits* = 2048;

(** out := the hash alg of msg; FALSE for an unknown alg *)
PROCEDURE Hash*(alg: LONGINT; VAR msg, out: TLSBytes.Buffer): BOOLEAN;
VAR d: TLSSHA256.Digest;
BEGIN
  IF alg = SHA256 THEN TLSSHA256.DigestBuffer(msg, d); TLSSHA256.DigestToBuffer(d, out)
  ELSIF alg = SHA384 THEN TLSSHA512.Digest384(msg, out)
  ELSIF alg = SHA512 THEN TLSSHA512.Digest512(msg, out)
  ELSE RETURN FALSE
  END;
  RETURN TRUE
END Hash;

PROCEDURE HashLen*(alg: LONGINT): LONGINT;
BEGIN
  IF alg = SHA256 THEN RETURN 32 ELSIF alg = SHA384 THEN RETURN 48 ELSIF alg = SHA512 THEN RETURN 64 END;
  RETURN 0
END HashLen;

(* the DER prefix of DigestInfo for alg (RFC 8017, 9.2 note 1) *)
PROCEDURE DigestInfoPrefix(alg: LONGINT; VAR b: TLSBytes.Buffer);
VAR last, len: LONGINT;
BEGIN
  IF alg = SHA256 THEN last := 1; len := 32 ELSIF alg = SHA384 THEN last := 2; len := 48 ELSE last := 3; len := 64 END;
  TLSBytes.Init(b);
  TLSBytes.AppendByte(b, 30H); TLSBytes.AppendByte(b, 11H + len);   (* SEQUENCE: 15 + 2 + len *)
  TLSBytes.AppendByte(b, 30H); TLSBytes.AppendByte(b, 0DH);         (* AlgorithmIdentifier *)
  TLSBytes.AppendByte(b, 06H); TLSBytes.AppendByte(b, 09H);         (* 2.16.840.1.101.3.4.2.x *)
  TLSBytes.AppendByte(b, 60H); TLSBytes.AppendByte(b, 86H); TLSBytes.AppendByte(b, 48H);
  TLSBytes.AppendByte(b, 01H); TLSBytes.AppendByte(b, 65H); TLSBytes.AppendByte(b, 03H);
  TLSBytes.AppendByte(b, 04H); TLSBytes.AppendByte(b, 02H); TLSBytes.AppendByte(b, last);
  TLSBytes.AppendByte(b, 05H); TLSBytes.AppendByte(b, 00H);         (* NULL parameters *)
  TLSBytes.AppendByte(b, 04H); TLSBytes.AppendByte(b, len)          (* OCTET STRING *)
END DigestInfoPrefix;

(* the value bytes of the INTEGER at pos, without leading zeros *)
PROCEDURE IntegerBytes(VAR der: TLSBytes.Buffer; VAR pos: LONGINT; limit: LONGINT; VAR out: TLSBytes.Buffer): BOOLEAN;
VAR t: TLSASN1.TLV; i: LONGINT;
BEGIN
  IF ~TLSASN1.ExpectTag(der, pos, limit, TLSASN1.Integer, t) OR (t.len < 1) THEN RETURN FALSE END;
  IF ORD(der.data[t.val]) >= 128 THEN RETURN FALSE END;  (* negative *)
  i := t.val; WHILE (i < t.val + t.len - 1) & (der.data[i] = 0X) DO INC(i) END;
  TLSBytes.Slice(der, i, t.val + t.len - i, out);
  RETURN TRUE
END IntegerBytes;

(** n and e of an RSA SubjectPublicKeyInfo (rsaEncryption) *)
PROCEDURE PublicKey*(VAR spki: TLSBytes.Buffer; VAR n, e: TLSBytes.Buffer): BOOLEAN;
VAR pos, lim, kpos, klim: LONGINT; t: TLSASN1.TLV; oid, key: TLSBytes.Buffer;
BEGIN
  pos := 0;
  IF ~TLSASN1.EnterSequence(spki, pos, spki.len, pos, lim) THEN RETURN FALSE END;
  IF ~TLSX509.ParseAlgorithmIdentifier(spki, pos, lim, oid) THEN RETURN FALSE END;
  IF ~((oid.len = 9) & (ORD(oid.data[0]) = 2AH) & (ORD(oid.data[1]) = 86H) & (ORD(oid.data[2]) = 48H) &
      (ORD(oid.data[3]) = 86H) & (ORD(oid.data[4]) = 0F7H) & (ORD(oid.data[5]) = 0DH) &
      (ORD(oid.data[6]) = 1) & (ORD(oid.data[7]) = 1) & (ORD(oid.data[8]) = 1)) THEN RETURN FALSE END;
  IF ~TLSASN1.ExpectTag(spki, pos, lim, TLSASN1.BitString, t) OR (t.len < 2) OR (spki.data[t.val] # 0X) THEN RETURN FALSE END;
  TLSBytes.Slice(spki, t.val + 1, t.len - 1, key);
  kpos := 0;
  IF ~TLSASN1.EnterSequence(key, kpos, key.len, kpos, klim) THEN RETURN FALSE END;
  RETURN IntegerBytes(key, kpos, klim, n) & IntegerBytes(key, kpos, klim, e) & (kpos = klim)
END PublicKey;

(* out := sig^e mod n as k bytes, k = the length of n; FALSE if sig is not k bytes below n *)
PROCEDURE PublicOp(VAR n, e, sig: TLSBytes.Buffer; VAR out: TLSBytes.Buffer): BOOLEAN;
VAR nn, s, sm, r, rm: TLSNum.Num; mod: TLSNum.Modulus; k, bits, top: LONGINT;
BEGIN
  k := n.len;
  IF (k < 1) OR (n.data[0] = 0X) OR ~ODD(ORD(n.data[k - 1])) THEN RETURN FALSE END;
  top := ORD(n.data[0]); bits := (k - 1) * 8;
  WHILE top > 0 DO INC(bits); top := top DIV 2 END;
  IF (bits < MinBits) OR (k * 8 > TLSNum.MaxLimbs * TLSNum.Bits - 32) THEN RETURN FALSE END;
  IF (e.len < 1) OR (e.len > 4) THEN RETURN FALSE END;       (* e fits in 32 bits (65537 in practice) *)
  IF sig.len # k THEN RETURN FALSE END;
  TLSNum.FromBytes(n.data, 0, k, 0, nn);
  TLSNum.FromBytes(sig.data, 0, k, nn.len, s);
  IF TLSNum.Compare(s, nn) >= 0 THEN RETURN FALSE END;
  TLSNum.InitModulus(nn, mod);
  TLSNum.ToMont(s, mod, sm);
  TLSNum.MontPow(sm, e.data, 0, e.len, mod, rm);
  TLSNum.FromMont(rm, mod, r);
  TLSNum.ToBytes(r, k, out);
  RETURN TRUE
END PublicOp;

(** the PKCS#1 v1.5 signature sig of hash (made with alg) by the key (n, e) *)
PROCEDURE VerifyPKCS1*(VAR n, e: TLSBytes.Buffer; alg: LONGINT; VAR hash, sig: TLSBytes.Buffer): BOOLEAN;
VAR em, want, prefix: TLSBytes.Buffer; k, ps, i: LONGINT;
BEGIN
  IF (HashLen(alg) = 0) OR (hash.len # HashLen(alg)) THEN RETURN FALSE END;
  IF ~PublicOp(n, e, sig, em) THEN RETURN FALSE END;
  k := n.len;
  DigestInfoPrefix(alg, prefix);
  ps := k - 3 - prefix.len - hash.len;
  IF ps < 8 THEN RETURN FALSE END;
  TLSBytes.Init(want);
  TLSBytes.AppendByte(want, 0); TLSBytes.AppendByte(want, 1);
  i := 0; WHILE i < ps DO TLSBytes.AppendByte(want, 255); INC(i) END;
  TLSBytes.AppendByte(want, 0);
  TLSBytes.Append(want, prefix); TLSBytes.Append(want, hash);
  RETURN TLSBytes.EqualConstTime(em, want)
END VerifyPKCS1;

(* mask := MGF1 with alg of seed, len bytes *)
PROCEDURE MGF1(alg: LONGINT; VAR seed: TLSBytes.Buffer; len: LONGINT; VAR mask: TLSBytes.Buffer);
VAR c: LONGINT; t, h: TLSBytes.Buffer; ok: BOOLEAN;
BEGIN
  TLSBytes.Init(mask); c := 0;
  WHILE mask.len < len DO
    TLSBytes.Copy(seed, t); TLSBytes.PutBE32(t, c);
    ok := Hash(alg, t, h);
    TLSBytes.AppendOpen(mask, h.data, h.len);
    INC(c)
  END;
  mask.len := len
END MGF1;

(** the PSS signature sig of hash by (n, e): MGF1 and hash alg, salt of the hash length *)
PROCEDURE VerifyPSS*(VAR n, e: TLSBytes.Buffer; alg: LONGINT; VAR hash, sig: TLSBytes.Buffer): BOOLEAN;
VAR
  em, masked, h, mask, db, m, h2: TLSBytes.Buffer;
  k, bits, emBits, emLen, hLen, sLen, dbLen, top, i, zeroBits, start: LONGINT; ok: BOOLEAN;
BEGIN
  hLen := HashLen(alg); sLen := hLen;
  IF (hLen = 0) OR (hash.len # hLen) THEN RETURN FALSE END;
  IF ~PublicOp(n, e, sig, em) THEN RETURN FALSE END;
  k := n.len; top := ORD(n.data[0]); bits := (k - 1) * 8;
  WHILE top > 0 DO INC(bits); top := top DIV 2 END;
  emBits := bits - 1; emLen := (emBits + 7) DIV 8;
  start := k - emLen;                          (* em has k bytes; EM is its last emLen *)
  IF (start = 1) & (em.data[0] # 0X) THEN RETURN FALSE END;
  IF emLen < hLen + sLen + 2 THEN RETURN FALSE END;
  IF ORD(em.data[k - 1]) # 0BCH THEN RETURN FALSE END;
  dbLen := emLen - hLen - 1;
  TLSBytes.Slice(em, start, dbLen, masked);
  TLSBytes.Slice(em, start + dbLen, hLen, h);
  zeroBits := 8 * emLen - emBits;              (* the leftmost bits of EM must be zero *)
  IF ORD(masked.data[0]) DIV ASH(1, 8 - zeroBits) # 0 THEN RETURN FALSE END;
  MGF1(alg, h, dbLen, mask);
  TLSBytes.Init(db); i := 0;
  WHILE i < dbLen DO TLSBytes.AppendByte(db, TLSBytes.XorByte(ORD(masked.data[i]), ORD(mask.data[i]))); INC(i) END;
  db.data[0] := CHR(ORD(db.data[0]) MOD ASH(1, 8 - zeroBits));
  i := 0; ok := TRUE;                          (* DB = zeros, 01, salt *)
  WHILE i < dbLen - sLen - 1 DO IF db.data[i] # 0X THEN ok := FALSE END; INC(i) END;
  IF ~ok OR (db.data[dbLen - sLen - 1] # 1X) THEN RETURN FALSE END;
  TLSBytes.Init(m); i := 0; WHILE i < 8 DO TLSBytes.AppendByte(m, 0); INC(i) END;
  TLSBytes.Append(m, hash);
  i := dbLen - sLen;
  WHILE i < dbLen DO TLSBytes.AppendChar(m, db.data[i]); INC(i) END;
  RETURN Hash(alg, m, h2) & TLSBytes.EqualConstTime(h, h2)
END VerifyPSS;

END TLSRSA.
