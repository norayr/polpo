MODULE Versions;  (** version numbers like 1.2.10 or 0.3.0-rc1; no imports, for voc and polpo *)

(* A version is numbers separated by dots, each optionally followed by a suffix:
   1.2.10 < 1.10.0; 0.3.0-rc1 < 0.3.0 (a suffix marks a pre-release); a missing part is 0:
   1.2 = 1.2.0. *)

(* the number at s[i] and the suffix up to the next dot; i moves past the dot *)
PROCEDURE Part(VAR s: ARRAY OF CHAR; VAR i: LONGINT; VAR n: LONGINT; VAR suffix: ARRAY OF CHAR);
VAR j: LONGINT;
BEGIN
  n := 0; j := 0;
  WHILE (i < LEN(s)) & (s[i] >= "0") & (s[i] <= "9") DO
    IF n < 100000000 THEN n := n * 10 + ORD(s[i]) - ORD("0") END; INC(i)
  END;
  WHILE (i < LEN(s)) & (s[i] # 0X) & (s[i] # ".") DO
    IF j < LEN(suffix) - 1 THEN suffix[j] := s[i]; INC(j) END; INC(i)
  END;
  suffix[j] := 0X;
  IF (i < LEN(s)) & (s[i] = ".") THEN INC(i) END
END Part;

(** -1 if a is older than b, 0 if the same, 1 if newer *)
PROCEDURE Compare*(a, b: ARRAY OF CHAR): INTEGER;
VAR i, j, na, nb: LONGINT; sa, sb: ARRAY 32 OF CHAR;
BEGIN
  i := 0; j := 0;
  WHILE ((i < LEN(a)) & (a[i] # 0X)) OR ((j < LEN(b)) & (b[j] # 0X)) DO
    Part(a, i, na, sa); Part(b, j, nb, sb);
    IF na < nb THEN RETURN -1 ELSIF na > nb THEN RETURN 1 END;
    IF sa # sb THEN
      IF sa = "" THEN RETURN 1 ELSIF sb = "" THEN RETURN -1  (* a release is newer than its pre-release *)
      ELSIF sa < sb THEN RETURN -1 ELSE RETURN 1
      END
    END
  END;
  RETURN 0
END Compare;

(** a is at least b *)
PROCEDURE AtLeast*(a, b: ARRAY OF CHAR): BOOLEAN;
BEGIN RETURN Compare(a, b) >= 0
END AtLeast;

(** s is a version: starts with a digit, only digits, dots and suffix characters *)
PROCEDURE Valid*(s: ARRAY OF CHAR): BOOLEAN;
VAR i: LONGINT;
BEGIN
  IF (s[0] < "0") OR (s[0] > "9") THEN RETURN FALSE END;
  i := 0;
  WHILE (i < LEN(s)) & (s[i] # 0X) DO
    IF (s[i] <= " ") OR (s[i] = "=") OR (s[i] = 22X) THEN RETURN FALSE END;
    INC(i)
  END;
  RETURN TRUE
END Valid;

END Versions.
