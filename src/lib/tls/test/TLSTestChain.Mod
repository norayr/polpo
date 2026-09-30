MODULE TLSTestChain;  (* path validation with chains made by tools/gentestcerts.py: the directory
  is the environment variable TLS_TEST_CERTS (default test/certs); now is 2026-06-01 *)

IMPORT Linux0, Kernel, SYSTEM, TLSBytes, TLSCABundle, TLSX509Validity, TLSX509Chain, TLSX509Names, Out := out;

TYPE
  BundlePtr = POINTER TO TLSCABundle.Bundle;
  Chain = POINTER TO ChainDesc;
  ChainDesc = RECORD certs, roots: ARRAY 4 OF TLSBytes.Buffer END;

VAR
  fails, checks: LONGINT;
  dir: ARRAY 256 OF CHAR;
  now: TLSX509Validity.Time;
  bundle, rsaBundle: BundlePtr;
  c: Chain;

PROCEDURE Check(what: ARRAY OF CHAR; ok: BOOLEAN);
BEGIN
  INC(checks);
  IF ~ok THEN INC(fails); Out.String("FAIL "); Out.String(what); Out.Ln END
END Check;

PROCEDURE Path(name: ARRAY OF CHAR; VAR path: ARRAY OF CHAR);
VAR i, j: LONGINT;
BEGIN
  i := 0; WHILE dir[i] # 0X DO path[i] := dir[i]; INC(i) END;
  path[i] := "/"; INC(i); j := 0;
  WHILE name[j] # 0X DO path[i] := name[j]; INC(i); INC(j) END;
  path[i] := 0X
END Path;

PROCEDURE Load(name: ARRAY OF CHAR; VAR b: TLSBytes.Buffer);
VAR path: ARRAY 512 OF CHAR; fd, n, r: LONGINT;
BEGIN
  Path(name, path); TLSBytes.Init(b);
  fd := Linux0.Openat0(Linux0.ATFDCWD, SYSTEM.ADR(path[0]), Linux0.ORDonly, 0);
  IF fd < 0 THEN Out.String("cannot open "); Out.String(path); Out.Ln; RETURN END;
  n := Linux0.Read0(fd, SYSTEM.ADR(b.data[0]), TLSBytes.MaxLen);
  IF n > 0 THEN b.len := n END;
  r := Linux0.Close0(fd)
END Load;

(* the chain of the files leaf, int (or "") against rootFile (or "") and against the PEM bundle *)
PROCEDURE Case(what, leaf, int, rootFile: ARRAY OF CHAR; want: BOOLEAN);
VAR n, nr: LONGINT; r: TLSX509Chain.Result; ok: BOOLEAN;
BEGIN
  Load(leaf, c.certs[0]); n := 1;
  IF int # "" THEN Load(int, c.certs[1]); n := 2 END;
  nr := 0; IF rootFile # "" THEN Load(rootFile, c.roots[0]); nr := 1 END;
  ok := TLSX509Chain.CheckChainWithTrustAnchors(c.certs, n, c.roots, nr, now, r);
  Check(what, ok = want);
  IF nr > 0 THEN
    ok := TLSX509Chain.CheckChainWithPEMBundle(c.certs, n, bundle.text, now, r);
    Check(what, ok = want)
  END
END Case;

PROCEDURE Host(what, leaf, host: ARRAY OF CHAR; want: BOOLEAN);
BEGIN
  Load(leaf, c.certs[0]);
  Check(what, TLSX509Names.CertMatchesHostname(c.certs[0], host) = want)
END Host;

PROCEDURE Run;
VAR r: TLSX509Chain.Result; path: ARRAY 512 OF CHAR; ok: BOOLEAN;
BEGIN
  NEW(c); NEW(bundle); NEW(rsaBundle);
  Path("roots.pem", path); Check("load roots.pem", TLSCABundle.Load(path, bundle^));
  Path("rsa_roots.pem", path); Check("load rsa_roots.pem", TLSCABundle.Load(path, rsaBundle^));
  Case("RSA chain", "rsa_leaf.der", "rsa_int.der", "rsa_root.der", TRUE);
  Case("EC chain (P-384 root, P-256 intermediate)", "ec_leaf.der", "ec_int.der", "ec_root.der", TRUE);
  Load("ec_leaf.der", c.certs[0]); Load("ec_int.der", c.certs[1]); Load("rsa_root.der", c.roots[0]);
  Check("missing root", ~TLSX509Chain.CheckChainWithTrustAnchors(c.certs, 2, c.roots, 1, now, r));
  Load("ec_leaf.der", c.certs[0]); Load("ec_int.der", c.certs[1]);
  Check("EC chain against RSA roots only", ~TLSX509Chain.CheckChainWithPEMBundle(c.certs, 2, rsaBundle.text, now, r));
  Case("missing intermediate", "rsa_leaf.der", "", "rsa_root.der", FALSE);
  Case("intermediate not a CA", "noca_leaf.der", "noca_int.der", "rsa_root.der", FALSE);
  Case("CA without keyCertSign", "nokcs_leaf.der", "nokcs_int.der", "rsa_root.der", FALSE);
  Load("sub_leaf.der", c.certs[0]); Load("sub_int.der", c.certs[1]); Load("rsa_int.der", c.certs[2]);
  Load("rsa_root.der", c.roots[0]);
  Check("pathLenConstraint 0 with a CA below", ~TLSX509Chain.CheckChainWithTrustAnchors(c.certs, 3, c.roots, 1, now, r));
  Case("leaf for clients only", "client_leaf.der", "rsa_int.der", "rsa_root.der", FALSE);
  Case("unknown critical extension", "crit_leaf.der", "rsa_int.der", "rsa_root.der", FALSE);
  Case("expired leaf", "expired_leaf.der", "rsa_int.der", "rsa_root.der", FALSE);
  Load("byleaf_leaf.der", c.certs[0]); Load("rsa_leaf.der", c.certs[1]); Load("rsa_int.der", c.certs[2]);
  Check("signed by a leaf", ~TLSX509Chain.CheckChainWithTrustAnchors(c.certs, 3, c.roots, 1, now, r));
  Load("rsa_leaf.der", c.certs[0]); Load("rsa_int.der", c.certs[1]);
  c.certs[0].data[c.certs[0].len - 1] := CHR((ORD(c.certs[0].data[c.certs[0].len - 1]) + 1) MOD 256);
  Check("changed signature", ~TLSX509Chain.CheckChainWithTrustAnchors(c.certs, 2, c.roots, 1, now, r));
  Load("rsa_leaf.der", c.certs[0]);
  c.certs[0].data[40] := CHR((ORD(c.certs[0].data[40]) + 1) MOD 256);
  Check("changed certificate", ~TLSX509Chain.CheckChainWithTrustAnchors(c.certs, 2, c.roots, 1, now, r));
  TLSX509Validity.SetTime(now, 2036, 1, 1, 0, 0, 0);
  Case("everything expired", "rsa_leaf.der", "rsa_int.der", "rsa_root.der", FALSE);
  TLSX509Validity.SetTime(now, 2026, 6, 1, 0, 0, 0);
  Host("host name", "rsa_leaf.der", "www.example.test", TRUE);
  Host("host name, other case", "rsa_leaf.der", "WWW.Example.TEST", TRUE);
  Host("wrong host name", "rsa_leaf.der", "example.test", FALSE);
  Host("wildcard", "rsa_leaf.der", "a.shop.example.test", TRUE);
  Host("wildcard, one label only", "rsa_leaf.der", "a.b.shop.example.test", FALSE);
  Host("wildcard, not the bare domain", "rsa_leaf.der", "shop.example.test", FALSE);
  Host("no wildcard for a top level domain", "tld_leaf.der", "example.test", FALSE);
  ok := TRUE
END Run;

BEGIN
  fails := 0; checks := 0;
  Kernel.GetConfig("TLS_TEST_CERTS", dir);
  IF dir = "" THEN dir := "test/certs" END;
  TLSX509Validity.SetTime(now, 2026, 6, 1, 0, 0, 0);
  Run;
  Out.String("TLSTestChain: "); Out.Int(checks, 0); Out.String(" checks, "); Out.Int(fails, 0); Out.String(" failed"); Out.Ln
END TLSTestChain.
