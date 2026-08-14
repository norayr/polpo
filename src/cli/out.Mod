MODULE out;

IMPORT Linux0, SYSTEM;

PROCEDURE Char*(c: CHAR);
VAR n: LONGINT;
BEGIN
  IF c = 0DX THEN c := 0AX END;
  n := Linux0.Write0(1, SYSTEM.ADR(c), 1)
END Char;

PROCEDURE String*(s: ARRAY OF CHAR);
VAR n, len: LONGINT;
BEGIN
  len := 0;
  WHILE (len < LEN(s)) & (s[len] # 0X) DO INC(len) END;
  n := Linux0.Write0(1, SYSTEM.ADR(s), len)
END String;

PROCEDURE Ln*;
BEGIN Char(0AX) END Ln;

PROCEDURE Int*(x, w: LONGINT);
VAR i, value: LONGINT; digits: ARRAY 12 OF CHAR; ch: ARRAY 2 OF CHAR;
BEGIN
  IF x < 0 THEN
    IF x = MIN(LONGINT) THEN String("-2147483648"); RETURN
    ELSE DEC(w); value := -x
    END
  ELSE value := x
  END;
  i := 0;
  REPEAT
    digits[i] := CHR(value MOD 10 + 30H); value := value DIV 10; INC(i)
  UNTIL value = 0;
  ch[0] := " "; ch[1] := 0X;
  WHILE w > i DO String(ch); DEC(w) END;
  ch[0] := "-"; IF x < 0 THEN String(ch) END;
  REPEAT DEC(i); ch[0] := digits[i]; String(ch) UNTIL i = 0
END Int;

PROCEDURE Hex*(x, w: LONGINT);
VAR buf: ARRAY 10 OF CHAR; i, j: LONGINT; ch: CHAR;
BEGIN
  ch := " ";
  IF w >= 0 THEN j := 8 ELSE j := 2; w := -w END;
  FOR i := j+1 TO w DO Char(ch) END;
  FOR i := j-1 TO 0 BY -1 DO
    buf[i] := CHR(x MOD 10H + 48);
    IF buf[i] > "9" THEN buf[i] := CHR(ORD(buf[i]) - 48 + 65 - 10) END;
    x := x DIV 10H
  END;
  buf[j] := 0X; String(buf)
END Hex;

END out.
