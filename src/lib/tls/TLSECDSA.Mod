MODULE TLSECDSA;
(* ECDSA signature verification over NIST P-256 and P-384 (FIPS 186-4, SEC 1), for certificates
   and CertificateVerify. Field arithmetic modulo p and n in Montgomery form with TLSNum (32 bit
   integers only); Jacobian coordinates with the a = -3 doubling (dbl-2001-b) and add-2007-bl;
   u1*G + u2*Q in one pass (Shamir). Verification only: nothing here is secret, so no care is
   taken about timing. *)
IMPORT TLSBytes, TLSNum;

CONST
  P256* = 1; P384* = 2;  (** curves *)

TYPE
  Num = TLSNum.Num;
  Curve = RECORD
    bytes: LONGINT;          (* 32 or 48 *)
    p, n: TLSNum.Modulus;
    b, gx, gy, three: Num    (* Montgomery form modulo p *)
  END;
  Point = RECORD x, y, z: Num; inf: BOOLEAN END;

VAR
  curves: ARRAY 3 OF Curve;

PROCEDURE HexVal(ch: CHAR): LONGINT;
BEGIN
  IF ch <= "9" THEN RETURN ORD(ch) - ORD("0") ELSE RETURN ORD(ch) - ORD("a") + 10 END
END HexVal;

(* the big endian hex number h in n *)
PROCEDURE HexNum(h: ARRAY OF CHAR; VAR n: Num);
VAR b: TLSBytes.Buffer; i: LONGINT;
BEGIN
  TLSBytes.Init(b); i := 0;
  WHILE (i < LEN(h) - 1) & (h[i] # 0X) DO TLSBytes.AppendByte(b, HexVal(h[i]) * 16 + HexVal(h[i+1])); INC(i, 2) END;
  TLSNum.FromBytes(b.data, 0, b.len, 0, n)
END HexNum;

PROCEDURE InitCurve(VAR c: Curve; bytes: LONGINT; p, n, b, gx, gy: ARRAY OF CHAR);
VAR t: Num;
BEGIN
  c.bytes := bytes;
  HexNum(p, t); TLSNum.InitModulus(t, c.p);
  HexNum(n, t); TLSNum.InitModulus(t, c.n);
  HexNum(b, t); t.len := c.p.m.len; TLSNum.ToMont(t, c.p, c.b);
  HexNum(gx, t); t.len := c.p.m.len; TLSNum.ToMont(t, c.p, c.gx);
  HexNum(gy, t); t.len := c.p.m.len; TLSNum.ToMont(t, c.p, c.gy);
  TLSNum.SetSmall(t, c.p.m.len, 3); TLSNum.ToMont(t, c.p, c.three)
END InitCurve;

(* ----- the field modulo p, in Montgomery form ----- *)

PROCEDURE Mul(VAR c: Curve; VAR a, b, out: Num);
BEGIN TLSNum.MontMul(a, b, c.p, out)
END Mul;

PROCEDURE Add(VAR c: Curve; VAR a, b, out: Num);
BEGIN TLSNum.ModAdd(a, b, c.p, out)
END Add;

PROCEDURE Sub(VAR c: Curve; VAR a, b, out: Num);
BEGIN TLSNum.ModSub(a, b, c.p, out)
END Sub;

(* ----- points ----- *)

(* r := 2 p *)
PROCEDURE Double(VAR c: Curve; VAR p, r: Point);
VAR delta, gamma, beta, alpha, t1, t2, t3, x3, y3, z3: Num;
BEGIN
  IF p.inf OR TLSNum.IsZero(p.y) THEN r.inf := TRUE; RETURN END;
  Mul(c, p.z, p.z, delta); Mul(c, p.y, p.y, gamma); Mul(c, p.x, gamma, beta);
  Sub(c, p.x, delta, t1); Add(c, p.x, delta, t2); Mul(c, t1, t2, t3);
  Add(c, t3, t3, alpha); Add(c, alpha, t3, alpha);                 (* alpha = 3 (x - delta)(x + delta) *)
  Mul(c, alpha, alpha, x3);
  Add(c, beta, beta, t1); Add(c, t1, t1, t1);                      (* 4 beta *)
  Add(c, t1, t1, t2); Sub(c, x3, t2, x3);                          (* x3 = alpha^2 - 8 beta *)
  Add(c, p.y, p.z, t2); Mul(c, t2, t2, z3); Sub(c, z3, gamma, z3); Sub(c, z3, delta, z3);
  Sub(c, t1, x3, t2); Mul(c, alpha, t2, y3);
  Mul(c, gamma, gamma, t3); Add(c, t3, t3, t3); Add(c, t3, t3, t3); Add(c, t3, t3, t3);  (* 8 gamma^2 *)
  Sub(c, y3, t3, y3);
  r.x := x3; r.y := y3; r.z := z3; r.inf := FALSE
END Double;

(* r := p + q *)
PROCEDURE AddPoints(VAR c: Curve; VAR p, q, r: Point);
VAR z1z1, z2z2, u1, u2, s1, s2, h, i, j, rr, v, t, x3, y3, z3: Num;
BEGIN
  IF p.inf THEN r := q; RETURN END;
  IF q.inf THEN r := p; RETURN END;
  Mul(c, p.z, p.z, z1z1); Mul(c, q.z, q.z, z2z2);
  Mul(c, p.x, z2z2, u1); Mul(c, q.x, z1z1, u2);
  Mul(c, p.y, q.z, t); Mul(c, t, z2z2, s1);
  Mul(c, q.y, p.z, t); Mul(c, t, z1z1, s2);
  Sub(c, u2, u1, h); Sub(c, s2, s1, rr);
  IF TLSNum.IsZero(h) THEN
    IF TLSNum.IsZero(rr) THEN Double(c, p, r) ELSE r.inf := TRUE END;
    RETURN
  END;
  Add(c, rr, rr, rr);                                              (* r = 2 (s2 - s1) *)
  Add(c, h, h, t); Mul(c, t, t, i);                                (* i = (2h)^2 *)
  Mul(c, h, i, j); Mul(c, u1, i, v);
  Mul(c, rr, rr, x3); Sub(c, x3, j, x3); Sub(c, x3, v, x3); Sub(c, x3, v, x3);
  Sub(c, v, x3, t); Mul(c, rr, t, y3);
  Mul(c, s1, j, t); Add(c, t, t, t); Sub(c, y3, t, y3);
  Add(c, p.z, q.z, t); Mul(c, t, t, z3); Sub(c, z3, z1z1, z3); Sub(c, z3, z2z2, z3); Mul(c, z3, h, z3);
  r.x := x3; r.y := y3; r.z := z3; r.inf := FALSE
END AddPoints;

PROCEDURE Bit(VAR a: Num; k: LONGINT): BOOLEAN;
VAR limb, s: LONGINT;
BEGIN
  IF k DIV TLSNum.Bits >= a.len THEN RETURN FALSE END;
  limb := a.d[k DIV TLSNum.Bits]; s := k MOD TLSNum.Bits;
  RETURN ODD(limb DIV ASH(1, s))
END Bit;

(* r := u1 G + u2 q (u1, u2 plain, below n) *)
PROCEDURE Shamir(VAR c: Curve; VAR u1, u2: Num; VAR q, r: Point);
VAR g, gq, acc: Point; k: LONGINT; b1, b2: BOOLEAN;
BEGIN
  g.x := c.gx; g.y := c.gy; TLSNum.MontOne(c.p, g.z); g.inf := FALSE;
  AddPoints(c, g, q, gq);
  acc.inf := TRUE;
  k := c.bytes * 8 - 1;
  WHILE k >= 0 DO
    Double(c, acc, acc);
    b1 := Bit(u1, k); b2 := Bit(u2, k);
    IF b1 & b2 THEN AddPoints(c, acc, gq, acc)
    ELSIF b1 THEN AddPoints(c, acc, g, acc)
    ELSIF b2 THEN AddPoints(c, acc, q, acc)
    END;
    DEC(k)
  END;
  r := acc
END Shamir;

(* x, y (plain, below p) on the curve: y^2 = x^3 - 3x + b *)
PROCEDURE OnCurve(VAR c: Curve; VAR x, y: Num): BOOLEAN;
VAR l, r, t: Num;
BEGIN
  Mul(c, y, y, l);
  Mul(c, x, x, t); Mul(c, t, x, r);
  Mul(c, c.three, x, t); Sub(c, r, t, r); Add(c, r, c.b, r);
  RETURN TLSNum.Compare(l, r) = 0
END OnCurve;

(* v := the big endian bytes b[0..len) as a number below m, FALSE if it is not *)
PROCEDURE Scalar(VAR b: TLSBytes.Buffer; VAR mod: TLSNum.Modulus; maxBytes: LONGINT; VAR v: Num): BOOLEAN;
VAR i: LONGINT;
BEGIN
  i := 0; WHILE (i < b.len) & (b.data[i] = 0X) DO INC(i) END;  (* leading zeros *)
  IF b.len - i > maxBytes THEN RETURN FALSE END;
  TLSNum.FromBytes(b.data, i, b.len - i, mod.m.len, v);
  RETURN TLSNum.Compare(v, mod.m) < 0
END Scalar;

(** the signature (r, s) of the hash by the public key pub (04 x y, uncompressed) on the curve *)
PROCEDURE Verify*(curve: LONGINT; VAR pub, hash, r, s: TLSBytes.Buffer): BOOLEAN;
VAR
  e, rn, sn, w, u1, u2, t, x, y, zinv, z2: Num; q, res: Point; eb: TLSBytes.Buffer; n: LONGINT;
BEGIN
  IF (curve # P256) & (curve # P384) THEN RETURN FALSE END;
  n := curves[curve].bytes;
  (* the public key *)
  IF (pub.len # 1 + 2 * n) OR (pub.data[0] # 4X) THEN RETURN FALSE END;
  TLSNum.FromBytes(pub.data, 1, n, curves[curve].p.m.len, x);
  TLSNum.FromBytes(pub.data, 1 + n, n, curves[curve].p.m.len, y);
  IF (TLSNum.Compare(x, curves[curve].p.m) >= 0) OR (TLSNum.Compare(y, curves[curve].p.m) >= 0) THEN RETURN FALSE END;
  TLSNum.ToMont(x, curves[curve].p, q.x); TLSNum.ToMont(y, curves[curve].p, q.y);
  TLSNum.MontOne(curves[curve].p, q.z); q.inf := FALSE;
  IF ~OnCurve(curves[curve], q.x, q.y) THEN RETURN FALSE END;
  (* 0 < r, s < n *)
  IF ~Scalar(r, curves[curve].n, n, rn) OR ~Scalar(s, curves[curve].n, n, sn) THEN RETURN FALSE END;
  IF TLSNum.IsZero(rn) OR TLSNum.IsZero(sn) THEN RETURN FALSE END;
  (* e: the leftmost bits of the hash, as many as n has (256 or 384: whole bytes) *)
  TLSBytes.Init(eb);
  IF hash.len > n THEN TLSBytes.AppendOpen(eb, hash.data, n) ELSE TLSBytes.Append(eb, hash) END;
  TLSNum.FromBytes(eb.data, 0, eb.len, 0, t);
  TLSNum.ModReduce(t, curves[curve].n, e);
  (* w = 1/s, u1 = e w, u2 = r w (mod n) *)
  TLSNum.ToMont(sn, curves[curve].n, t); TLSNum.MontInvPrime(t, curves[curve].n, w);
  TLSNum.ToMont(e, curves[curve].n, t); TLSNum.MontMul(t, w, curves[curve].n, t); TLSNum.FromMont(t, curves[curve].n, u1);
  TLSNum.ToMont(rn, curves[curve].n, t); TLSNum.MontMul(t, w, curves[curve].n, t); TLSNum.FromMont(t, curves[curve].n, u2);
  Shamir(curves[curve], u1, u2, q, res);
  IF res.inf THEN RETURN FALSE END;
  (* the affine x = X / Z^2, mod n, must be r *)
  TLSNum.MontInvPrime(res.z, curves[curve].p, zinv);
  Mul(curves[curve], zinv, zinv, z2); Mul(curves[curve], res.x, z2, t);
  TLSNum.FromMont(t, curves[curve].p, x);
  TLSNum.ModReduce(x, curves[curve].n, t);
  RETURN TLSNum.Compare(t, rn) = 0
END Verify;

(** r and s of a DER signature: SEQUENCE { INTEGER r, INTEGER s } *)
PROCEDURE ParseSignature*(VAR der: TLSBytes.Buffer; VAR r, s: TLSBytes.Buffer): BOOLEAN;
VAR pos, len: LONGINT;

  PROCEDURE Length(VAR len: LONGINT): BOOLEAN;
  VAR k: LONGINT;
  BEGIN
    IF pos >= der.len THEN RETURN FALSE END;
    len := ORD(der.data[pos]); INC(pos);
    IF len >= 128 THEN
      k := len - 128; len := 0;
      IF (k < 1) OR (k > 2) OR (pos + k > der.len) THEN RETURN FALSE END;
      WHILE k > 0 DO len := len * 256 + ORD(der.data[pos]); INC(pos); DEC(k) END
    END;
    RETURN pos + len <= der.len
  END Length;

  PROCEDURE Integer(VAR v: TLSBytes.Buffer): BOOLEAN;
  VAR l: LONGINT;
  BEGIN
    IF (pos >= der.len) OR (der.data[pos] # 2X) THEN RETURN FALSE END;
    INC(pos);
    IF ~Length(l) OR (l < 1) THEN RETURN FALSE END;
    TLSBytes.Slice(der, pos, l, v); INC(pos, l);
    RETURN TRUE
  END Integer;

BEGIN
  pos := 0;
  IF (der.len < 8) OR (der.data[0] # 30X) THEN RETURN FALSE END;
  pos := 1;
  IF ~Length(len) OR (pos + len # der.len) THEN RETURN FALSE END;
  RETURN Integer(r) & Integer(s) & (pos = der.len)
END ParseSignature;

BEGIN
  InitCurve(curves[P256], 32,
    "ffffffff00000001000000000000000000000000ffffffffffffffffffffffff",
    "ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632551",
    "5ac635d8aa3a93e7b3ebbd55769886bc651d06b0cc53b0f63bce3c3e27d2604b",
    "6b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296",
    "4fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f5");
  InitCurve(curves[P384], 48,
    "fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffeffffffff0000000000000000ffffffff",
    "ffffffffffffffffffffffffffffffffffffffffffffffffc7634d81f4372ddf581a0db248b0a77aecec196accc52973",
    "b3312fa7e23ee7e4988e056be3f82d19181d9c6efe8141120314088f5013875ac656398d8a2ed19d2a85c8edd3ec2aef",
    "aa87ca22be8b05378eb1c71ef320ad746e1d3b628ba79b9859f741e082542a385502f25dbf55296c3a545e3872760ab7",
    "3617de4a96262c6f5d9e98bf9292dc29f8f41dbd289a147ce9da3113b5f0b8c00a60b1ce1d7e819d7a431d7c90ea0e5f");
END TLSECDSA.
