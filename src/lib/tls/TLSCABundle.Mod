MODULE TLSCABundle;
IMPORT SYSTEM, Linux0, TLSBytes;  (* Linux0: polpo's, or the one of the voc Internet module *)

CONST
  MaxBundle* = 1048576;
  DefaultPath* = "/etc/ssl/certs/ca-certificates.crt";

TYPE
  Bundle* = RECORD
    len*: LONGINT;
    text*: ARRAY MaxBundle OF CHAR
  END;

PROCEDURE Init*(VAR b: Bundle);
BEGIN
  b.len := 0; b.text[0] := 0X
END Init;

PROCEDURE Load*(path: ARRAY OF CHAR; VAR b: Bundle): BOOLEAN;
VAR fd, n, total, want, r: LONGINT; name: ARRAY 512 OF CHAR;
BEGIN
  Init(b);
  COPY(path, name);
  fd := Linux0.Openat0(Linux0.ATFDCWD, SYSTEM.ADR(name[0]), Linux0.ORDonly, 0);
  IF fd < 0 THEN RETURN FALSE END;
  total := 0;
  REPEAT
    want := MaxBundle - 1 - total;
    IF want > 8192 THEN want := 8192 END;
    IF want <= 0 THEN n := 0
    ELSE n := Linux0.Read0(fd, SYSTEM.ADR(b.text[total]), want)
    END;
    IF n > 0 THEN INC(total, n) END
  UNTIL (n <= 0) OR (total >= MaxBundle - 1);
  r := Linux0.Close0(fd);
  IF (n < 0) OR (total >= MaxBundle - 1) THEN RETURN FALSE END;
  b.len := total; b.text[total] := 0X;
  RETURN TRUE
END Load;

PROCEDURE LoadDefault*(VAR b: Bundle): BOOLEAN;
BEGIN
  RETURN Load(DefaultPath, b)
END LoadDefault;

END TLSCABundle.
