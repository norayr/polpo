MODULE fetch;  (** HTTP downloads with the http module *)

(* fetch.Get url [file]   saves the body in file (default: the last part of the path)
   fetch.Show url         prints the body
   url: http://host[:port][/path]; host is a name, an IPv4 address or [an IPv6 address] *)

IMPORT Texts := texts, Files, http, strTypes, out;

(* scheme, host, port and path of url *)
PROCEDURE Split(VAR url, host, port, path: ARRAY OF CHAR): BOOLEAN;
VAR i, j: LONGINT;
BEGIN
  i := 0;
  WHILE (url[i] # 0X) & (url[i] # ":") DO INC(i) END;
  IF (url[i] = ":") & (url[i + 1] = "/") & (url[i + 2] = "/") THEN
    IF ~((i = 4) & (CAP(url[0]) = "H") & (CAP(url[1]) = "T") & (CAP(url[2]) = "T") & (CAP(url[3]) = "P")) THEN
      out.String("fetch: only http:// for now"); out.Ln; RETURN FALSE
    END;
    INC(i, 3)
  ELSE i := 0
  END;
  j := 0;
  IF url[i] = "[" THEN  (* [IPv6] *)
    INC(i);
    WHILE (url[i] # 0X) & (url[i] # "]") DO host[j] := url[i]; INC(i); INC(j) END;
    IF url[i] = "]" THEN INC(i) END
  ELSE
    WHILE (url[i] # 0X) & (url[i] # ":") & (url[i] # "/") DO host[j] := url[i]; INC(i); INC(j) END
  END;
  host[j] := 0X; j := 0;
  IF url[i] = ":" THEN
    INC(i); WHILE (url[i] >= "0") & (url[i] <= "9") DO port[j] := url[i]; INC(i); INC(j) END
  END;
  IF j = 0 THEN COPY("80", port) ELSE port[j] := 0X END;
  j := 0;
  IF url[i] # "/" THEN path[0] := "/"; j := 1 END;
  WHILE url[i] # 0X DO path[j] := url[i]; INC(i); INC(j) END;
  path[j] := 0X;
  RETURN host[0] # 0X
END Split;

PROCEDURE Fetch(VAR url: ARRAY OF CHAR; VAR h: http.Client): BOOLEAN;
VAR host, port, path: ARRAY 1024 OF CHAR; body: strTypes.pstring;
BEGIN
  IF ~Split(url, host, port, path) THEN out.String("fetch: bad url "); out.String(url); out.Ln; RETURN FALSE END;
  h := http.Create(host, port, path);
  body := h.Get(h);
  RETURN body # NIL
END Fetch;

(** fetch.Get url [file] *)
PROCEDURE Get*;
VAR A: Texts.Reader; url, name: ARRAY 1024 OF CHAR; h: http.Client; f: Files.File; R: Files.Rider; i: LONGINT;
BEGIN
  Texts.OpenArgs(A);
  IF ~Texts.Arg(A, url) THEN out.String("usage: fetch.Get url [file]"); out.Ln; RETURN END;
  IF ~Fetch(url, h) THEN RETURN END;
  out.String(h.rspnFirstLine^); out.String(", "); out.Int(h.rspnContentLength, 0); out.String(" bytes");
  IF Texts.Arg(A, name) THEN
    f := Files.New(name);
    IF f = NIL THEN out.String(", cannot create "); out.String(name)
    ELSE
      Files.Set(R, f, 0); i := 0;
      WHILE i < h.rspnContentLength DO Files.Write(R, h.rspnBody[i]); INC(i) END;
      Files.Register(f); out.String(" in "); out.String(name)
    END
  ELSE h.Save(h)
  END;
  out.Ln
END Get;

(** fetch.Show url *)
PROCEDURE Show*;
VAR A: Texts.Reader; url: ARRAY 1024 OF CHAR; h: http.Client; i: LONGINT;
BEGIN
  Texts.OpenArgs(A);
  IF ~Texts.Arg(A, url) THEN out.String("usage: fetch.Show url"); out.Ln; RETURN END;
  IF ~Fetch(url, h) THEN RETURN END;
  i := 0;
  WHILE i < h.rspnContentLength DO
    IF h.rspnBody[i] # 0DX THEN out.Char(h.rspnBody[i]) END;  (* out.Char(0DX) is a line end *)
    INC(i)
  END
END Show;

END fetch.
