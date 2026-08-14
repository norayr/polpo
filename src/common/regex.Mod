MODULE regex;

(** Small regular-expression engine for console tools.
    Supported syntax: ., ^, $, [], [^], ranges, *, +, ?, and backslash escapes. *)

CONST
  noerror* = 0;
  patternTooLong* = -1;
  missingBracket* = -2;
  trailingEscape* = -3;
  misplacedRepeat* = -4;

TYPE
  Pattern* = POINTER TO PatternDesc;
  PatternDesc* = RECORD
    source: ARRAY 256 OF CHAR;
    ignoreCase: BOOLEAN
  END;

PROCEDURE Upper(ch: CHAR): CHAR;
BEGIN
  IF ("a" <= ch) & (ch <= "z") THEN RETURN CAP(ch) ELSE RETURN ch END
END Upper;

PROCEDURE Equal(a, b: CHAR; ignoreCase: BOOLEAN): BOOLEAN;
BEGIN
  IF ignoreCase THEN RETURN Upper(a) = Upper(b) ELSE RETURN a = b END
END Equal;

PROCEDURE AtomEnd(source: ARRAY OF CHAR; pos: INTEGER): INTEGER;
BEGIN
  IF source[pos] = 5CX THEN
    IF source[pos+1] # 0X THEN RETURN pos + 2 ELSE RETURN pos + 1 END
  ELSIF source[pos] = "[" THEN
    INC(pos);
    IF source[pos] = "^" THEN INC(pos) END;
    WHILE (source[pos] # 0X) & (source[pos] # "]") DO
      IF (source[pos] = 5CX) & (source[pos+1] # 0X) THEN INC(pos) END;
      INC(pos)
    END;
    IF source[pos] = "]" THEN INC(pos) END;
    RETURN pos
  ELSE
    RETURN pos + 1
  END
END AtomEnd;

PROCEDURE InClass(source: ARRAY OF CHAR; pos: INTEGER; ch: CHAR; ignoreCase: BOOLEAN): BOOLEAN;
VAR first, last: CHAR; negate, found: BOOLEAN;
BEGIN
  INC(pos); negate := source[pos] = "^";
  IF negate THEN INC(pos) END;
  found := FALSE;
  WHILE (source[pos] # 0X) & (source[pos] # "]") DO
    IF source[pos] = 5CX THEN INC(pos) END;
    first := source[pos]; INC(pos);
    IF (source[pos] = "-") & (source[pos+1] # 0X) & (source[pos+1] # "]") THEN
      INC(pos);
      IF source[pos] = 5CX THEN INC(pos) END;
      last := source[pos]; INC(pos);
      IF ignoreCase THEN
        found := found OR ((Upper(first) <= Upper(ch)) & (Upper(ch) <= Upper(last)))
      ELSE
        found := found OR ((first <= ch) & (ch <= last))
      END
    ELSE
      found := found OR Equal(first, ch, ignoreCase)
    END
  END;
  IF negate THEN RETURN ~found ELSE RETURN found END
END InClass;

PROCEDURE AtomMatches(P: Pattern; pos: INTEGER; ch: CHAR): BOOLEAN;
BEGIN
  IF P.source[pos] = "." THEN RETURN ch # 0X
  ELSIF P.source[pos] = "[" THEN RETURN InClass(P.source, pos, ch, P.ignoreCase)
  ELSIF P.source[pos] = 5CX THEN RETURN Equal(P.source[pos+1], ch, P.ignoreCase)
  ELSE RETURN Equal(P.source[pos], ch, P.ignoreCase)
  END
END AtomMatches;

PROCEDURE MatchHere(P: Pattern; ppos: INTEGER; VAR text: ARRAY OF CHAR; tpos: INTEGER; VAR end: INTEGER): BOOLEAN;
VAR next, max, min, i: INTEGER; quant: CHAR;
BEGIN
  IF P.source[ppos] = 0X THEN end := tpos; RETURN TRUE END;
  IF P.source[ppos] = "$" THEN
    IF text[tpos] = 0X THEN end := tpos; RETURN TRUE ELSE RETURN FALSE END
  END;
  next := AtomEnd(P.source, ppos); quant := P.source[next];
  IF (quant = "*") OR (quant = "+") THEN
    max := tpos;
    WHILE (text[max] # 0X) & AtomMatches(P, ppos, text[max]) DO INC(max) END;
    IF quant = "+" THEN min := tpos + 1 ELSE min := tpos END;
    i := max;
    WHILE i >= min DO
      IF MatchHere(P, next + 1, text, i, end) THEN RETURN TRUE END;
      DEC(i)
    END;
    RETURN FALSE
  ELSIF quant = "?" THEN
    IF (text[tpos] # 0X) & AtomMatches(P, ppos, text[tpos]) THEN
      IF MatchHere(P, next + 1, text, tpos + 1, end) THEN RETURN TRUE END
    END;
    RETURN MatchHere(P, next + 1, text, tpos, end)
  ELSE
    IF (text[tpos] # 0X) & AtomMatches(P, ppos, text[tpos]) THEN
      RETURN MatchHere(P, next, text, tpos + 1, end)
    END;
    RETURN FALSE
  END
END MatchHere;

PROCEDURE Validate(source: ARRAY OF CHAR; VAR error, pos: INTEGER);
VAR i: INTEGER;
BEGIN
  error := noerror; pos := 0; i := 0;
  WHILE (source[i] # 0X) & (error = noerror) DO
    IF source[i] = 5CX THEN
      IF source[i+1] = 0X THEN error := trailingEscape; pos := i ELSE INC(i, 2) END
    ELSIF source[i] = "[" THEN
      pos := i; INC(i);
      IF source[i] = "^" THEN INC(i) END;
      WHILE (source[i] # 0X) & (source[i] # "]") DO
        IF (source[i] = 5CX) & (source[i+1] # 0X) THEN INC(i) END;
        INC(i)
      END;
      IF source[i] # "]" THEN error := missingBracket ELSE INC(i) END
    ELSIF (source[i] = "*") OR (source[i] = "+") OR (source[i] = "?") THEN
      error := misplacedRepeat; pos := i
    ELSE
      INC(i);
      IF (source[i] = "*") OR (source[i] = "+") OR (source[i] = "?") THEN INC(i) END
    END
  END
END Validate;

PROCEDURE Compile*(source: ARRAY OF CHAR; ignoreCase: BOOLEAN; VAR P: Pattern; VAR error, pos: INTEGER);
VAR i: INTEGER;
BEGIN
  i := 0;
  WHILE (i < LEN(source)) & (source[i] # 0X) DO INC(i) END;
  IF i >= 256 THEN
    P := NIL; error := patternTooLong; pos := i; RETURN
  END;
  Validate(source, error, pos);
  IF error = noerror THEN NEW(P); COPY(source, P.source); P.ignoreCase := ignoreCase ELSE P := NIL END
END Compile;

PROCEDURE CompileLiteral*(source: ARRAY OF CHAR; ignoreCase: BOOLEAN; VAR P: Pattern; VAR error, pos: INTEGER);
VAR quoted: ARRAY 256 OF CHAR; i, j: INTEGER; ch: CHAR;
BEGIN
  i := 0; j := 0;
  WHILE (i < LEN(source)) & (source[i] # 0X) & (j < LEN(quoted)-2) DO
    ch := source[i];
    IF (ch = ".") OR (ch = "^") OR (ch = "$") OR (ch = "[") OR
       (ch = 5CX) OR (ch = "*") OR (ch = "+") OR (ch = "?") THEN
      quoted[j] := 5CX; INC(j)
    END;
    quoted[j] := ch; INC(j); INC(i)
  END;
  IF source[i] # 0X THEN P := NIL; error := patternTooLong; pos := i
  ELSE quoted[j] := 0X; Compile(quoted, ignoreCase, P, error, pos)
  END
END CompileLiteral;

PROCEDURE Search*(P: Pattern; text: ARRAY OF CHAR; VAR beg, end: INTEGER);
VAR i: INTEGER;
BEGIN
  beg := 0; end := -1;
  IF P = NIL THEN RETURN END;
  IF P.source[0] = "^" THEN
    IF MatchHere(P, 1, text, 0, end) THEN beg := 0 END;
    RETURN
  END;
  i := 0;
  REPEAT
    IF MatchHere(P, 0, text, i, end) THEN beg := i; RETURN END;
    INC(i)
  UNTIL text[i-1] = 0X;
  beg := 0; end := -1
END Search;

END regex.
