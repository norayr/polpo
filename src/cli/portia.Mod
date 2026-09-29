MODULE portia;  (** polpo's package manager; reads the package tree arden *)

(* portia.List              the packages, i: all its files are here
   portia.Info name         a package: description, dependencies, provides, conflicts
   portia.Files name        the files of a package on this architecture
   portia.Owner file        the package a file belongs to (sources, objects, data)
   portia.Check             every file present, every import satisfied by the package
                            itself or its dependencies

   The tree: Portia.Tree in Oberon.Text, or <polpo root>/../arden/. Package descriptions
   are TOML (shared reader with vipak): <tree>/<name>/<name>-<version>.arden. *)

IMPORT Linux0, F := Files, Root, Texts := texts, Oberon := Oberon0, TOML, out;

CONST
  NameLen = 256;
  SYS = "SYSTEM";

TYPE
  Name = ARRAY NameLen OF CHAR;
  Buf = POINTER TO ARRAY OF CHAR;
  Item = POINTER TO ItemDesc;
  ItemDesc = RECORD s: Name; next: Item END;

  Package = POINTER TO PackageDesc;
  PackageDesc = RECORD
    name, version, desc: Name;
    deps, provides, conflicts, sources, files, modules: Item;  (* modules: names of sources *)
    next: Package
  END;

VAR
  tree: Name;  (* with trailing / *)
  arch: ARRAY 16 OF CHAR;
  packages: Package;
  imports: Item;  (* of the last source parsed *)
  installed: Item; haveDb: BOOLEAN;  (* the installed packages of this architecture, portia.<arch> *)

(* ----- strings and lists ----- *)

PROCEDURE Append(VAR s: ARRAY OF CHAR; t: ARRAY OF CHAR);
VAR i, j: LONGINT;
BEGIN
  i := 0; WHILE s[i] # 0X DO INC(i) END;
  j := 0; WHILE (t[j] # 0X) & (i < LEN(s) - 1) DO s[i] := t[j]; INC(i); INC(j) END;
  s[i] := 0X
END Append;

PROCEDURE Add(VAR list: Item; s: ARRAY OF CHAR);  (* at the end *)
VAR it, p: Item;
BEGIN
  NEW(it); COPY(s, it.s); it.next := NIL;
  IF list = NIL THEN list := it ELSE p := list; WHILE p.next # NIL DO p := p.next END; p.next := it END
END Add;

PROCEDURE Has(list: Item; s: ARRAY OF CHAR): BOOLEAN;
BEGIN
  WHILE (list # NIL) & (list.s # s) DO list := list.next END;
  RETURN list # NIL
END Has;

(* add the blank separated words of s to list *)
PROCEDURE AddWords(VAR list: Item; VAR s: ARRAY OF CHAR);
VAR i, j: LONGINT; w: Name;
BEGIN
  i := 0;
  WHILE s[i] # 0X DO
    WHILE (s[i] = " ") OR (s[i] = 09X) OR (s[i] = 0AX) OR (s[i] = 0DX) DO INC(i) END;
    j := 0;
    WHILE (s[i] # 0X) & (s[i] # " ") & (s[i] # 09X) & (s[i] # 0AX) & (s[i] # 0DX) DO
      IF j < NameLen - 1 THEN w[j] := s[i]; INC(j) END; INC(i)
    END;
    w[j] := 0X;
    IF w # "" THEN Add(list, w) END
  END
END AddWords;

(* ----- reading Oberon sources: the module name and its imports ----- *)

(* the MODULE name of the source path and its imports (in imports); FALSE if unreadable *)
PROCEDURE Header(VAR path: ARRAY OF CHAR; VAR mod: ARRAY OF CHAR): BOOLEAN;
VAR T: Texts.Text; R: Texts.Reader; ch, pend: CHAR; havePend: BOOLEAN; tok, last: Name;

  PROCEDURE Get;
  BEGIN
    IF havePend THEN ch := pend; havePend := FALSE ELSE Texts.Read(R, ch) END
  END Get;

  PROCEDURE Comment;  (* after the start of a comment; comments nest *)
  VAR depth: INTEGER;
  BEGIN
    depth := 1; Get;
    WHILE ~R.eot & (depth > 0) DO
      IF ch = "(" THEN Get; IF ch = "*" THEN INC(depth); Get END
      ELSIF ch = "*" THEN Get; IF ch = ")" THEN DEC(depth); Get END
      ELSE Get
      END
    END
  END Comment;

  (* the next token: a name, or a symbol of one or two characters *)
  PROCEDURE Token;
  VAR i: INTEGER;
  BEGIN
    LOOP
      WHILE ~R.eot & (ch <= " ") DO Get END;
      IF (ch = "(") & ~R.eot THEN
        Get;
        IF ch = "*" THEN Comment ELSE pend := ch; havePend := TRUE; ch := "("; EXIT END
      ELSE EXIT
      END
    END;
    i := 0;
    IF R.eot THEN tok := ""
    ELSIF (CAP(ch) >= "A") & (CAP(ch) <= "Z") OR (ch = "_") THEN
      WHILE (CAP(ch) >= "A") & (CAP(ch) <= "Z") OR (ch >= "0") & (ch <= "9") OR (ch = "_") DO
        IF i < NameLen - 1 THEN tok[i] := ch; INC(i) END; Get
      END;
      tok[i] := 0X
    ELSIF ch = ":" THEN Get; IF ch = "=" THEN tok := ":="; Get ELSE tok := ":" END
    ELSE tok[0] := ch; tok[1] := 0X; Get
    END
  END Token;

BEGIN
  imports := NIL; mod[0] := 0X;
  IF F.Old(path) = NIL THEN RETURN FALSE END;
  NEW(T); Texts.Open(T, path); Texts.OpenReader(R, T, 0); havePend := FALSE; Get;
  Token; WHILE (tok # "") & (tok # "MODULE") DO Token END;
  IF tok = "" THEN RETURN FALSE END;
  Token; COPY(tok, mod);
  Token; IF tok = "*" THEN Token END;  (* MODULE *Name in some sources *)
  Token;  (* after ";" *)
  IF tok = "IMPORT" THEN
    last := "";
    LOOP
      Token;
      IF (tok = ";") OR (tok = "") THEN EXIT
      ELSIF tok = "," THEN IF last # "" THEN Add(imports, last); last := "" END
      ELSIF tok = ":=" THEN  (* alias := module: the module follows *)
      ELSIF (CAP(tok[0]) >= "A") & (CAP(tok[0]) <= "Z") OR (tok[0] = "_") THEN COPY(tok, last)  (* after := the real name *)
      END
    END;
    IF last # "" THEN Add(imports, last) END
  END;
  RETURN TRUE
END Header;

(* ----- the tree ----- *)

PROCEDURE ReadFile(VAR path: ARRAY OF CHAR; VAR buf: Buf): BOOLEAN;
VAR f: F.File; R: F.Rider; n, i: LONGINT; c: CHAR;
BEGIN
  f := F.Old(path);
  IF f = NIL THEN RETURN FALSE END;
  n := F.Length(f); NEW(buf, n + 1);
  F.Set(R, f, 0); i := 0;
  WHILE i < n DO F.Read(R, c); buf[i] := c; INC(i) END;
  buf[n] := 0X; F.ReleaseRead(f);
  RETURN TRUE
END ReadFile;

PROCEDURE Field(doc: TOML.Doc; sec, key: ARRAY OF CHAR; VAR val: ARRAY OF CHAR): BOOLEAN;
VAR s: TOML.Section;
BEGIN
  s := TOML.GetSection(doc, sec);
  IF s = NIL THEN val[0] := 0X; RETURN FALSE END;
  RETURN TOML.GetField(s, key, val)
END Field;

(* the keys of section sec as a list (deps, provides, conflicts) *)
PROCEDURE Keys(doc: TOML.Doc; sec: ARRAY OF CHAR; VAR list: Item);
VAR s: TOML.Section; f: TOML.Field;
BEGIN
  s := TOML.GetSection(doc, sec);
  IF s # NIL THEN f := s.first; WHILE f # NIL DO Add(list, f.key); f := f.next END END
END Keys;

PROCEDURE Load(VAR name, version: ARRAY OF CHAR): Package;
VAR path: Name; buf: Buf; doc: TOML.Doc; p: Package; v: ARRAY 4096 OF CHAR; it: Item; mod: Name;
BEGIN
  COPY(tree, path); Append(path, name); Append(path, "/"); Append(path, name); Append(path, "-");
  Append(path, version); Append(path, ".arden");
  IF ~ReadFile(path, buf) THEN out.String("portia: cannot read "); out.String(path); out.Ln; RETURN NIL END;
  doc := TOML.Parse(buf^);
  NEW(p); COPY(name, p.name); COPY(version, p.version);
  IF ~Field(doc, "PACKAGE", "description", p.desc) THEN p.desc := "" END;
  Keys(doc, "DEPS", p.deps); Keys(doc, "PROVIDES", p.provides); Keys(doc, "CONFLICTS", p.conflicts);
  IF Field(doc, "MODULES", "all", v) THEN AddWords(p.sources, v) END;
  IF Field(doc, "MODULES", arch, v) THEN AddWords(p.sources, v) END;
  IF Field(doc, "FILES", "all", v) THEN AddWords(p.files, v) END;
  IF Field(doc, "FILES", arch, v) THEN AddWords(p.files, v) END;
  it := p.sources;
  WHILE it # NIL DO
    IF Header(it.s, mod) THEN Add(p.modules, mod) ELSE Add(p.modules, "?") END;
    it := it.next
  END;
  RETURN p
END Load;

PROCEDURE ^LoadDb;

PROCEDURE LoadTree(): BOOLEAN;
VAR path: Name; buf: Buf; i, j: LONGINT; name, version: Name; p, last: Package;
BEGIN
  LoadDb;
  IF packages # NIL THEN RETURN TRUE END;
  COPY(tree, path); Append(path, "INDEX");
  IF ~ReadFile(path, buf) THEN
    out.String("portia: no package tree at "); out.String(tree);
    out.String(" (Portia.Tree in Oberon.Text)"); out.Ln; RETURN FALSE
  END;
  i := 0; last := NIL;
  WHILE buf[i] # 0X DO
    j := 0; WHILE (buf[i] > " ") DO name[j] := buf[i]; INC(i); INC(j) END; name[j] := 0X;
    WHILE (buf[i] = " ") OR (buf[i] = 09X) DO INC(i) END;
    j := 0; WHILE (buf[i] > " ") DO version[j] := buf[i]; INC(i); INC(j) END; version[j] := 0X;
    WHILE (buf[i] # 0X) & (buf[i] # 0AX) DO INC(i) END;
    IF buf[i] = 0AX THEN INC(i) END;
    IF name # "" THEN
      p := Load(name, version);
      IF p # NIL THEN IF last = NIL THEN packages := p ELSE last.next := p END; last := p END
    END
  END;
  RETURN TRUE
END LoadTree;

PROCEDURE Find(VAR name: ARRAY OF CHAR): Package;
VAR p: Package;
BEGIN
  p := packages; WHILE (p # NIL) & (p.name # name) DO p := p.next END;
  RETURN p
END Find;

(* the object files of module mod on this architecture *)
PROCEDURE ObjFile(VAR mod: ARRAY OF CHAR; sym: BOOLEAN; VAR path: ARRAY OF CHAR);
BEGIN
  COPY("obj/", path); Append(path, arch); Append(path, "/"); Append(path, mod);
  IF sym THEN Append(path, ".Sym") ELSE Append(path, ".Obj") END
END ObjFile;

(* opened read-only: a running binary cannot be opened for writing *)
PROCEDURE Exists(VAR path: ARRAY OF CHAR): BOOLEAN;
VAR full: Name;
BEGIN
  IF Root.Exists(path) THEN RETURN TRUE END;
  Root.Join(path, full); RETURN Root.Exists(full)
END Exists;

PROCEDURE Installed(p: Package): BOOLEAN;  (* all sources, objects and files here *)
VAR it: Item; path: Name;
BEGIN
  it := p.sources; WHILE it # NIL DO IF ~Exists(it.s) THEN RETURN FALSE END; it := it.next END;
  it := p.modules; WHILE it # NIL DO ObjFile(it.s, FALSE, path); IF ~Exists(path) THEN RETURN FALSE END; it := it.next END;
  it := p.files; WHILE it # NIL DO IF ~Exists(it.s) THEN RETURN FALSE END; it := it.next END;
  RETURN TRUE
END Installed;

(* ----- the installed packages: <root>portia.<arch>, lines "name version" ----- *)

PROCEDURE DbName(VAR path: ARRAY OF CHAR);
VAR n: Name;
BEGIN n := "portia."; Append(n, arch); Root.Join(n, path)
END DbName;

PROCEDURE LoadDb;
VAR path: Name; buf: Buf; i, j: LONGINT; name: Name;
BEGIN
  installed := NIL; DbName(path); haveDb := ReadFile(path, buf);
  IF haveDb THEN
    i := 0;
    WHILE buf[i] # 0X DO
      j := 0; WHILE buf[i] > " " DO name[j] := buf[i]; INC(i); INC(j) END; name[j] := 0X;
      WHILE (buf[i] # 0X) & (buf[i] # 0AX) DO INC(i) END;
      IF buf[i] = 0AX THEN INC(i) END;
      IF name # "" THEN Add(installed, name) END
    END
  END
END LoadDb;

PROCEDURE SaveDb;
VAR path: Name; f: F.File; R: F.Rider; it: Item; p: Package; i: LONGINT;

  PROCEDURE W(s: ARRAY OF CHAR);
  BEGIN i := 0; WHILE s[i] # 0X DO F.Write(R, s[i]); INC(i) END
  END W;

BEGIN
  DbName(path); f := F.New(path);
  IF f = NIL THEN out.String("portia: cannot write "); out.String(path); out.Ln; RETURN END;
  F.Set(R, f, 0); it := installed;
  WHILE it # NIL DO
    p := Find(it.s); W(it.s); W(" "); IF p # NIL THEN W(p.version) END; F.Write(R, 0AX);
    it := it.next
  END;
  F.Register(f); haveDb := TRUE
END SaveDb;

PROCEDURE Remove(VAR list: Item; s: ARRAY OF CHAR);
VAR p: Item;
BEGIN
  IF list # NIL THEN
    IF list.s = s THEN list := list.next
    ELSE p := list; WHILE (p.next # NIL) & (p.next.s # s) DO p := p.next END; IF p.next # NIL THEN p.next := p.next.next END
    END
  END
END Remove;

(* installed: in the record, or without a record, all its files here *)
PROCEDURE IsInstalled(p: Package): BOOLEAN;
BEGIN
  IF haveDb THEN RETURN Has(installed, p.name) END;
  RETURN Installed(p)
END IsInstalled;

(* ----- commands ----- *)

PROCEDURE Arg(VAR s: ARRAY OF CHAR): BOOLEAN;
VAR A: Texts.Reader;
BEGIN Texts.OpenArgs(A); RETURN Texts.Arg(A, s)
END Arg;

PROCEDURE ListItems(label: ARRAY OF CHAR; it: Item);
BEGIN
  IF it # NIL THEN
    out.String(label); WHILE it # NIL DO out.Char(" "); out.String(it.s); it := it.next END; out.Ln
  END
END ListItems;

(** portia.List -- the packages of the tree; i: installed here *)
PROCEDURE List*;
VAR p: Package; n: LONGINT;
BEGIN
  IF ~LoadTree() THEN RETURN END;
  p := packages;
  WHILE p # NIL DO
    IF IsInstalled(p) THEN out.String("i ") ELSE out.String("  ") END;
    out.String(p.name); n := 0; WHILE p.name[n] # 0X DO INC(n) END;
    WHILE n < 24 DO out.Char(" "); INC(n) END;
    out.String(p.version); out.String("  "); out.String(p.desc); out.Ln;
    p := p.next
  END
END List;

(** portia.Info name -- a package *)
PROCEDURE Info*;
VAR name: Name; p: Package; n: LONGINT; it: Item;
BEGIN
  IF ~Arg(name) THEN out.String("usage: portia.Info name"); out.Ln; RETURN END;
  IF ~LoadTree() THEN RETURN END;
  p := Find(name);
  IF p = NIL THEN out.String("portia: no package "); out.String(name); out.Ln; RETURN END;
  out.String(p.name); out.Char(" "); out.String(p.version); out.String(": "); out.String(p.desc); out.Ln;
  ListItems("depends on:", p.deps); ListItems("provides:", p.provides); ListItems("conflicts with:", p.conflicts);
  ListItems("modules:", p.modules);
  n := 0; it := p.files; WHILE it # NIL DO INC(n); it := it.next END;
  out.String("files: "); out.Int(n, 0); out.String(", installed: ");
  IF IsInstalled(p) THEN out.String("yes") ELSE out.String("no") END; out.Ln
END Info;

(** portia.Files name -- the files of a package on this architecture *)
PROCEDURE FilesCmd(p: Package);
VAR it: Item; path: Name;
BEGIN
  it := p.sources; WHILE it # NIL DO out.String(it.s); out.Ln; it := it.next END;
  it := p.modules;
  WHILE it # NIL DO
    ObjFile(it.s, FALSE, path); out.String(path); out.Ln;
    ObjFile(it.s, TRUE, path); IF Exists(path) THEN out.String(path); out.Ln END;
    it := it.next
  END;
  it := p.files; WHILE it # NIL DO out.String(it.s); out.Ln; it := it.next END
END FilesCmd;

PROCEDURE Files*;
VAR name: Name; p: Package;
BEGIN
  IF ~Arg(name) THEN out.String("usage: portia.Files name"); out.Ln; RETURN END;
  IF ~LoadTree() THEN RETURN END;
  p := Find(name);
  IF p = NIL THEN out.String("portia: no package "); out.String(name); out.Ln ELSE FilesCmd(p) END
END Files;

(** portia.Owner file -- the package the file belongs to *)
PROCEDURE Owner*;
VAR file, path: Name; p: Package; it: Item; i, j: LONGINT; found: BOOLEAN;
BEGIN
  IF ~Arg(file) THEN out.String("usage: portia.Owner file"); out.Ln; RETURN END;
  IF ~LoadTree() THEN RETURN END;
  (* relative to the polpo root *)
  i := 0; WHILE (Root.path[i] # 0X) & (file[i] = Root.path[i]) DO INC(i) END;
  IF Root.path[i] # 0X THEN i := 0 END;
  IF (file[i] = ".") & (file[i+1] = "/") THEN INC(i, 2) END;
  j := 0; WHILE file[i] # 0X DO file[j] := file[i]; INC(i); INC(j) END; file[j] := 0X;
  found := FALSE; p := packages;
  WHILE p # NIL DO
    IF ~IsInstalled(p) THEN  (* installed packages first *)
    ELSIF Has(p.sources, file) OR Has(p.files, file) THEN found := TRUE
    ELSE
      it := p.modules;
      WHILE it # NIL DO
        ObjFile(it.s, FALSE, path); IF path = file THEN found := TRUE END;
        ObjFile(it.s, TRUE, path); IF path = file THEN found := TRUE END;
        it := it.next
      END
    END;
    IF found THEN out.String(file); out.String(": "); out.String(p.name); out.Ln; RETURN END;
    p := p.next
  END;
  out.String(file); out.String(": no package"); out.Ln
END Owner;

(* the packages p needs: its dependencies, transitively; virtual ones through PROVIDES *)
PROCEDURE Closure(p: Package; VAR set: Item);
VAR it: Item; q: Package;
BEGIN
  IF Has(set, p.name) THEN RETURN END;
  Add(set, p.name);
  it := p.deps;
  WHILE it # NIL DO
    q := Find(it.s);
    IF q # NIL THEN Closure(q, set)
    ELSE  (* virtual: every package providing it counts *)
      q := packages;
      WHILE q # NIL DO IF Has(q.provides, it.s) THEN Closure(q, set) END; q := q.next END
    END;
    it := it.next
  END
END Closure;

(* is module mod in one of the packages of set *)
PROCEDURE Provided(set: Item; VAR mod: ARRAY OF CHAR): BOOLEAN;
VAR q: Package;
BEGIN
  WHILE set # NIL DO
    q := Find(set.s);
    IF (q # NIL) & Has(q.modules, mod) THEN RETURN TRUE END;
    set := set.next
  END;
  RETURN FALSE
END Provided;

(** portia.Check -- every file present and every import satisfied, on this architecture *)
PROCEDURE Check*;
VAR p: Package; it, im, set: Item; path, mod: Name; problems: LONGINT;
BEGIN
  IF ~LoadTree() THEN RETURN END;
  problems := 0; p := packages;
  WHILE p # NIL DO
   IF IsInstalled(p) THEN
    it := p.files;
    WHILE it # NIL DO
      IF ~Exists(it.s) THEN out.String(p.name); out.String(": missing "); out.String(it.s); out.Ln; INC(problems) END;
      it := it.next
    END;
    set := NIL; Closure(p, set);
    it := p.sources;
    WHILE it # NIL DO
      IF ~Header(it.s, mod) THEN out.String(p.name); out.String(": missing "); out.String(it.s); out.Ln; INC(problems)
      ELSE
        im := imports;
        WHILE im # NIL DO
          IF (im.s # SYS) & ~Provided(set, im.s) THEN
            out.String(p.name); out.String(": "); out.String(mod); out.String(" imports ");
            out.String(im.s); out.String(", not in the package or its dependencies"); out.Ln; INC(problems)
          END;
          im := im.next
        END;
        ObjFile(mod, FALSE, path);
        IF ~Exists(path) THEN out.String(p.name); out.String(": not compiled "); out.String(path); out.Ln; INC(problems) END
      END;
      it := it.next
    END
   END;
    p := p.next
  END;
  out.Int(problems, 0); out.String(" problems ("); out.String(arch); out.String(")"); out.Ln
END Check;

(** portia.Record -- record the packages whose files are here as installed; of alternatives
  sharing files (display-x11, display-sixel) the first; see portia.Mark *)
PROCEDURE Record*;
VAR p, q: Package; it: Item; skip: BOOLEAN;
BEGIN
  IF ~LoadTree() THEN RETURN END;
  installed := NIL; p := packages;
  WHILE p # NIL DO
    IF Installed(p) THEN
      skip := FALSE; it := p.conflicts;
      WHILE it # NIL DO IF Has(installed, it.s) THEN skip := TRUE END; it := it.next END;
      IF skip THEN
        out.String("not recorded "); out.String(p.name); out.String(", it conflicts with a recorded package (portia.Mark "); out.String(p.name); out.String(" switches)"); out.Ln
      ELSE Add(installed, p.name)
      END
    END;
    p := p.next
  END;
  SaveDb; q := NIL; List
END Record;

(** portia.Mark name -- record the package as installed; its conflicts are unmarked *)
PROCEDURE Mark*;
VAR name: Name; p: Package; it: Item;
BEGIN
  IF ~Arg(name) THEN out.String("usage: portia.Mark name"); out.Ln; RETURN END;
  IF ~LoadTree() THEN RETURN END;
  p := Find(name);
  IF p = NIL THEN out.String("portia: no package "); out.String(name); out.Ln; RETURN END;
  it := p.conflicts; WHILE it # NIL DO Remove(installed, it.s); it := it.next END;
  IF ~Has(installed, name) THEN Add(installed, name) END;
  SaveDb; out.String(name); out.String(" marked installed"); out.Ln
END Mark;

(** portia.Unmark name -- record the package as not installed (the files stay) *)
PROCEDURE Unmark*;
VAR name: Name;
BEGIN
  IF ~Arg(name) THEN out.String("usage: portia.Unmark name"); out.Ln; RETURN END;
  IF ~LoadTree() THEN RETURN END;
  Remove(installed, name); SaveDb; out.String(name); out.String(" unmarked"); out.Ln
END Unmark;

PROCEDURE Init;
VAR S: Texts.Scanner; i: LONGINT;
BEGIN
  IF Linux0.ARCH = "X86" THEN arch := "x86" ELSIF Linux0.ARCH = "ARM" THEN arch := "arm"
  ELSIF Linux0.ARCH = "RISC-V" THEN arch := "riscv" ELSIF Linux0.ARCH = "MIPS" THEN arch := "mips"
  ELSE arch := "armv7"
  END;
  Oberon.OpenScanner(S, "Portia.Tree");
  IF S.class IN {Texts.Name, Texts.String} THEN COPY(S.s, tree)
  ELSE Root.Join("../arden/", tree)
  END;
  i := 0; WHILE tree[i] # 0X DO INC(i) END;
  IF (i > 0) & (tree[i-1] # "/") THEN Append(tree, "/") END;
  packages := NIL
END Init;

BEGIN
  Init
END portia.
