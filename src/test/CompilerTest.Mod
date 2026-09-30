MODULE CompilerTest;  (** loksh CompilerTest.Run: code generator bugs fixed in polpo, on this port *)

(* Each case failed on at least one port before its fix (2026-09-30):
   x86: a DIV/MOD result moved to its hinted register was lost (ASH(1, i MOD 15));
   ARM: a dividend with a DIV in its index (a[i DIV 15] DIV k); global arrays of records whose
   size is not a power of 2, indexed by a variable;
   MIPS: RETURN x DIV y, RETURN x MOD y, RETURN ODD(...);
   RISC-V: b := i = 5 destroyed i;
   ROP2 (RISC-V, MIPS, ARMv7): a record copy from a VAR parameter at an offset beyond the
   immediate range; 8 VAR record arguments in a frame over 512 KB;
   RISC-V, MIPS: the end of a block move loop computed from a register reused for its length
   (w.cur := w.issuer copied nothing, or ran over memory). *)

IMPORT out;

TYPE
  Small = RECORD a: LONGINT; pad: ARRAY 4 OF CHAR; b: LONGINT END;  (* 12 bytes *)
  N = RECORD len: LONGINT; d: ARRAY 280 OF LONGINT END;
  M = RECORD m: N; minv: LONGINT; r2: N; one: N END;  (* one at offset 2252 *)
  Big = RECORD len: LONGINT; data: ARRAY 32768 OF CHAR END;
  Info = RECORD a, b, c, d, e, f, g, h: Big; bits: LONGINT END;  (* as TLSX509.CertInfo *)
  Work = POINTER TO RECORD cur, issuer: Info END;

VAR
  fails, checks: LONGINT;
  g: ARRAY 3 OF Small;
  flag: BOOLEAN;

PROCEDURE Check(what: ARRAY OF CHAR; ok: BOOLEAN);
BEGIN
  INC(checks);
  IF ~ok THEN INC(fails); out.String("FAIL "); out.String(what); out.Ln END
END Check;

PROCEDURE Div(x, y: LONGINT): LONGINT;
BEGIN RETURN x DIV y
END Div;

PROCEDURE Mod(x, y: LONGINT): LONGINT;
BEGIN RETURN x MOD y
END Mod;

PROCEDURE OddBit(x, s: LONGINT): BOOLEAN;
BEGIN RETURN ODD(x DIV ASH(1, s))
END OddBit;

PROCEDURE CopyOne(VAR a: N; epos, elen: LONGINT; VAR mod: M; VAR res: N);
BEGIN res := mod.one
END CopyOne;

PROCEDURE Eight(VAR a, b, c, d, e, f, h, i: Big);
BEGIN a.len := 1; i.len := 8
END Eight;

PROCEDURE Frame;
VAR a, b, c, d, e, f, h, i, j, k, l, m, n, o, p, q: Big;
BEGIN
  Eight(a, b, c, d, e, f, h, i);
  Check("8 VAR records in a 512 KB frame", (a.len = 1) & (i.len = 8))
END Frame;

PROCEDURE BlockMove;
VAR w: Work;
BEGIN
  NEW(w); w.issuer.h.data[3] := "B"; w.issuer.bits := 5; w.cur.h.data[3] := "-";
  w.cur := w.issuer;
  Check("w.cur := w.issuer, 256 KB on the heap", (w.cur.h.data[3] = "B") & (w.cur.bits = 5))
END BlockMove;

PROCEDURE Run*;
VAR i, j, k, bit, x: LONGINT; arr: ARRAY 20 OF LONGINT; a, r: N; mm: M;
BEGIN
  fails := 0; checks := 0;
  i := 47;
  Check("ASH(1, i MOD 15)", ASH(1, i MOD 15) = 4);
  Check("ASH(i, i DIV 3)", ASH(LONG(3), i DIV 3) = 98304);
  bit := 50; k := 4; arr[3] := 100;
  Check("a[bit DIV 15] DIV k", arr[bit DIV 15] DIV k = 25);
  Check("a[bit MOD 47] DIV a[bit DIV 15]", arr[bit MOD 47] DIV arr[bit DIV 15] = 1);
  j := 1; g[0].a := 10; g[1].a := 11; g[2].a := 12; g[0].b := 20; g[1].b := 21; g[2].b := 22;
  Check("global array of 12 byte records", (g[j].a = 11) & (g[j].b = 21));
  Check("RETURN x DIV y", (Div(-7, 2) = -4) & (Div(7, 2) = 3));
  Check("RETURN x MOD y", (Mod(-7, 2) = 1) & (Mod(7, 3) = 1));
  Check("RETURN ODD(x DIV ASH(1, s))", OddBit(5, 2) & ~OddBit(5, 1));
  x := 5; flag := x = 5;
  Check("b := x = 5 keeps x", flag & (x = 5));
  x := 5; flag := x # 5;
  Check("b := x # 5 keeps x", ~flag & (x = 5));
  mm.one.len := 7; r.len := 0; CopyOne(a, 0, 1, mm, r);
  Check("record copy from a VAR parameter at offset 2252", r.len = 7);
  Frame;
  BlockMove;
  out.String("CompilerTest: "); out.Int(checks, 0); out.String(" checks, "); out.Int(fails, 0); out.String(" failed"); out.Ln
END Run;

END CompilerTest.
