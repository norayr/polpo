MODULE TLSBigInt;
IMPORT TLSBytes;

PROCEDURE Normalize*(VAR a, out: TLSBytes.Buffer);
VAR i, j: LONGINT;
BEGIN
  i := 0;
  WHILE (i < a.len-1) & (a.data[i] = 0X) DO INC(i) END;
  out.len := a.len - i;
  IF out.len <= 0 THEN
    out.len := 1; out.data[0] := 0X
  ELSE
    j := 0;
    WHILE j < out.len DO out.data[j] := a.data[i+j]; INC(j) END
  END
END Normalize;

PROCEDURE SetZero*(VAR out: TLSBytes.Buffer);
BEGIN
  out.len := 1; out.data[0] := 0X
END SetZero;

PROCEDURE SetOne*(VAR out: TLSBytes.Buffer);
BEGIN
  out.len := 1; out.data[0] := 1X
END SetOne;

PROCEDURE StripLeadingZero*(VAR a, out: TLSBytes.Buffer);
BEGIN
  Normalize(a, out)
END StripLeadingZero;

PROCEDURE Compare*(VAR a, b: TLSBytes.Buffer): LONGINT;
VAR aa, bb: TLSBytes.Buffer; i: LONGINT;
BEGIN
  Normalize(a, aa); Normalize(b, bb);
  IF aa.len < bb.len THEN RETURN -1 END;
  IF aa.len > bb.len THEN RETURN 1 END;
  i := 0;
  WHILE i < aa.len DO
    IF ORD(aa.data[i]) < ORD(bb.data[i]) THEN RETURN -1 END;
    IF ORD(aa.data[i]) > ORD(bb.data[i]) THEN RETURN 1 END;
    INC(i)
  END;
  RETURN 0
END Compare;

PROCEDURE Sub*(VAR a, b: TLSBytes.Buffer; VAR out: TLSBytes.Buffer);
(* Requires a >= b. *)
VAR i, ai, bi, av, bv, borrow, v: LONGINT; tmp: TLSBytes.Buffer;
BEGIN
  tmp.len := a.len;
  i := 0;
  WHILE i < tmp.len DO tmp.data[i] := 0X; INC(i) END;
  borrow := 0;
  ai := a.len - 1; bi := b.len - 1; i := tmp.len - 1;
  WHILE i >= 0 DO
    av := ORD(a.data[ai]);
    IF bi >= 0 THEN bv := ORD(b.data[bi]) ELSE bv := 0 END;
    v := av - bv - borrow;
    IF v < 0 THEN v := v + 256; borrow := 1 ELSE borrow := 0 END;
    tmp.data[i] := TLSBytes.Byte(v);
    DEC(ai); DEC(bi); DEC(i)
  END;
  Normalize(tmp, out)
END Sub;

PROCEDURE ModReduce*(VAR a, m: TLSBytes.Buffer; VAR out: TLSBytes.Buffer);
VAR tmp, next: TLSBytes.Buffer;
BEGIN
  Normalize(a, tmp);
  WHILE Compare(tmp, m) >= 0 DO
    Sub(tmp, m, next);
    TLSBytes.Copy(next, tmp)
  END;
  TLSBytes.Copy(tmp, out)
END ModReduce;

PROCEDURE ModAdd*(VAR a, b, m: TLSBytes.Buffer; VAR out: TLSBytes.Buffer);
VAR max, i, ai, bi, av, bv, carry, v: LONGINT; tmp, reduced: TLSBytes.Buffer;
BEGIN
  IF a.len > b.len THEN max := a.len ELSE max := b.len END;
  tmp.len := max + 1;
  i := 0; WHILE i < tmp.len DO tmp.data[i] := 0X; INC(i) END;
  carry := 0; ai := a.len - 1; bi := b.len - 1; i := tmp.len - 1;
  WHILE i >= 0 DO
    IF ai >= 0 THEN av := ORD(a.data[ai]) ELSE av := 0 END;
    IF bi >= 0 THEN bv := ORD(b.data[bi]) ELSE bv := 0 END;
    v := av + bv + carry;
    tmp.data[i] := TLSBytes.Byte(v);
    carry := v DIV 256;
    DEC(ai); DEC(bi); DEC(i)
  END;
  ModReduce(tmp, m, reduced);
  TLSBytes.Copy(reduced, out)
END ModAdd;

PROCEDURE ModDouble*(VAR a, m: TLSBytes.Buffer; VAR out: TLSBytes.Buffer);
BEGIN
  ModAdd(a, a, m, out)
END ModDouble;

PROCEDURE BitLength*(VAR a: TLSBytes.Buffer): LONGINT;
VAR aa: TLSBytes.Buffer; first, bits: LONGINT;
BEGIN
  Normalize(a, aa);
  IF (aa.len = 1) & (aa.data[0] = 0X) THEN RETURN 0 END;
  first := ORD(aa.data[0]); bits := 0;
  WHILE first > 0 DO INC(bits); first := first DIV 2 END;
  RETURN (aa.len - 1) * 8 + bits
END BitLength;

PROCEDURE GetBitLSB*(VAR a: TLSBytes.Buffer; bit: LONGINT): BOOLEAN;
VAR byteIndex, mask: LONGINT;
BEGIN
  byteIndex := a.len - 1 - bit DIV 8;
  IF byteIndex < 0 THEN RETURN FALSE END;
  mask := 1;
  WHILE bit MOD 8 > 0 DO mask := mask * 2; DEC(bit) END;
  RETURN (ORD(a.data[byteIndex]) MOD (mask * 2)) >= mask
END GetBitLSB;

PROCEDURE ModMul*(VAR a, b, m: TLSBytes.Buffer; VAR out: TLSBytes.Buffer);
VAR result, temp, next: TLSBytes.Buffer; i, bits: LONGINT;
BEGIN
  SetZero(result);
  ModReduce(b, m, temp);
  bits := BitLength(a);
  i := 0;
  WHILE i < bits DO
    IF GetBitLSB(a, i) THEN
      ModAdd(result, temp, m, next);
      TLSBytes.Copy(next, result)
    END;
    ModDouble(temp, m, next);
    TLSBytes.Copy(next, temp);
    INC(i)
  END;
  TLSBytes.Copy(result, out)
END ModMul;

PROCEDURE ModExp*(VAR base, exp, m: TLSBytes.Buffer; VAR out: TLSBytes.Buffer);
VAR result, b, next: TLSBytes.Buffer; i, bits: LONGINT;
BEGIN
  SetOne(result);
  ModReduce(base, m, b);
  bits := BitLength(exp);
  i := 0;
  WHILE i < bits DO
    IF GetBitLSB(exp, i) THEN
      ModMul(result, b, m, next);
      TLSBytes.Copy(next, result)
    END;
    ModMul(b, b, m, next);
    TLSBytes.Copy(next, b);
    INC(i)
  END;
  ModReduce(result, m, out)
END ModExp;

PROCEDURE LeftPad*(VAR a: TLSBytes.Buffer; len: LONGINT; VAR out: TLSBytes.Buffer): BOOLEAN;
VAR aa: TLSBytes.Buffer; i, pad: LONGINT;
BEGIN
  Normalize(a, aa);
  IF aa.len > len THEN RETURN FALSE END;
  out.len := len;
  pad := len - aa.len;
  i := 0; WHILE i < pad DO out.data[i] := 0X; INC(i) END;
  i := 0; WHILE i < aa.len DO out.data[pad+i] := aa.data[i]; INC(i) END;
  RETURN TRUE
END LeftPad;

END TLSBigInt.
