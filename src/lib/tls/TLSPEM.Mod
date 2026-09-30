MODULE TLSPEM;
IMPORT Base64 := TLSBase64, TLSBytes;

CONST
  BeginCert = "-----BEGIN CERTIFICATE-----";
  EndCert = "-----END CERTIFICATE-----";

PROCEDURE MatchAt(VAR s: ARRAY OF CHAR; pos: LONGINT; pat: ARRAY OF CHAR): BOOLEAN;
VAR i: LONGINT;
BEGIN
  i := 0;
  WHILE (i < LEN(pat)) & (pat[i] # 0X) DO
    IF (pos + i >= LEN(s)) OR (s[pos + i] # pat[i]) THEN RETURN FALSE END;
    INC(i)
  END;
  RETURN TRUE
END MatchAt;

PROCEDURE Find(VAR s: ARRAY OF CHAR; pat: ARRAY OF CHAR; from: LONGINT): LONGINT;  (* VAR: s is a whole CA bundle *)
VAR p: LONGINT;
BEGIN
  p := from;
  WHILE (p < LEN(s)) & (s[p] # 0X) DO
    IF MatchAt(s, p, pat) THEN RETURN p END;
    INC(p)
  END;
  RETURN -1
END Find;

PROCEDURE StrLen(s: ARRAY OF CHAR): LONGINT;
VAR i: LONGINT;
BEGIN
  i := 0;
  WHILE (i < LEN(s)) & (s[i] # 0X) DO INC(i) END;
  RETURN i
END StrLen;

PROCEDURE IsWhite(ch: CHAR): BOOLEAN;
BEGIN
  RETURN (ch = 0AX) OR (ch = 0DX) OR (ch = " ") OR (ch = 09X)
END IsWhite;

(* Extracts and decodes the next PEM certificate in text, starting at FROM.
   On success FROM is advanced past the END CERTIFICATE line. *)
PROCEDURE NextCertificateDER*(VAR pem: ARRAY OF CHAR; VAR from: LONGINT; VAR der: TLSBytes.Buffer): BOOLEAN;
VAR
  p, q, i, j: LONGINT;
  b64: ARRAY TLSBytes.MaxLen OF CHAR;
BEGIN
  TLSBytes.Init(der);
  p := Find(pem, BeginCert, from);
  IF p < 0 THEN RETURN FALSE END;
  p := p + StrLen(BeginCert);
  q := Find(pem, EndCert, p);
  IF q < 0 THEN RETURN FALSE END;

  i := p; j := 0;
  WHILE i < q DO
    IF ~IsWhite(pem[i]) THEN
      IF j >= LEN(b64)-1 THEN RETURN FALSE END;
      b64[j] := pem[i]; INC(j)
    END;
    INC(i)
  END;
  b64[j] := 0X;
  from := q + StrLen(EndCert);
  RETURN Base64.DecodeToBuffer(b64, der)
END NextCertificateDER;

PROCEDURE FirstCertificateDER*(VAR pem: ARRAY OF CHAR; VAR der: TLSBytes.Buffer): BOOLEAN;
VAR from: LONGINT;
BEGIN
  from := 0;
  RETURN NextCertificateDER(pem, from, der)
END FirstCertificateDER;

END TLSPEM.
