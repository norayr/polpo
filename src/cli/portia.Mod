MODULE portia;  (** polpo's package manager; reads the package tree arden *)

(* portia.List              the packages, i: all its files are here
   portia.Info name         a package: description, dependencies, provides, conflicts
   portia.Files name        the files of a package on this architecture
   portia.Owner file        the package a file belongs to (sources, objects, data)
   portia.Check             every file present, every import satisfied by the package
                            itself or its dependencies
   portia.Build [/arch] [name ...]  compile the packages and their dependencies in order
                            (modules ordered by their imports), then link; without names
                            every installed package; /arm, /riscv ... for another one
   Install, Upgrade, Build and Remove show what they will do and ask; /y does not ask.
   portia.Install [/arch] name ...  build, link and record packages; dependencies only when
                            missing or older than needed
   portia.Upgrade [/arch] [name ...]  the installed packages with newer versions in the tree
   When the interface of a module changes (its symbol file), the installed packages
   depending on its package are recompiled, and so on.
   portia.Remove [/arch] name ...   delete their objects and unrecord them, if nothing needs them
   portia.Graph [name]      the dependencies as a Graphviz (.dot) graph
   portia.Record, portia.Mark name, portia.Unmark name   the record of installed packages

   The tree: the environment variable PORTIA_TREE, Portia.Tree in Oberon.Text, or
   <polpo root>/../arden/. Package descriptions
   are TOML (shared reader with vipak): <tree>/<name>/<name>-<version>.arden. *)

IMPORT Kernel, Linux0, SYSTEM, F := Files, Root, Texts := texts, Oberon := Oberon0, TOML, Versions, termios, out;

CONST
  NameLen = 256;
  SYS = "SYSTEM";

TYPE
  Name = ARRAY NameLen OF CHAR;
  Buf = POINTER TO ARRAY OF CHAR;
  Item = POINTER TO ItemDesc;
  ItemDesc = RECORD
    s: Name;
    v: ARRAY 32 OF CHAR;  (* a version: of a dependency the least needed, of an installed package its own *)
    flags: ARRAY 16 OF CHAR;  (* compiler options of a source *)
    next: Item
  END;

  Package = POINTER TO PackageDesc;
  PackageDesc = RECORD
    name, version, desc: Name;
    deps, provides, conflicts, sources, files, modules, build: Item;  (* modules: names of sources *)
    next: Package
  END;

VAR
  tree: Name;  (* with trailing / *)
  arch, hostArch: ARRAY 16 OF CHAR;  (* the architecture packages are read for, the one running *)
  packages: Package;
  imports: Item;  (* of the last source parsed *)
  installed: Item; haveDb: BOOLEAN;  (* the installed packages of this architecture, portia.<arch> *)
  assumeYes: BOOLEAN;  (* /y: do not ask *)

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

(* the sources of a MODULES value: paths, each after its compiler options ("/x path") *)
PROCEDURE AddSources(VAR list: Item; VAR s: ARRAY OF CHAR);
VAR words, w, it: Item; flags: ARRAY 16 OF CHAR;
BEGIN
  words := NIL; AddWords(words, s); flags := ""; w := words;
  WHILE w # NIL DO
    IF w.s[0] = "/" THEN Append(flags, " "); Append(flags, w.s)
    ELSE Add(list, w.s); it := list; WHILE it.next # NIL DO it := it.next END; COPY(flags, it.flags); flags := ""
    END;
    w := w.next
  END
END AddSources;

(* the commands of a BUILD value, separated by ";" *)
PROCEDURE AddCommands(VAR list: Item; VAR s: ARRAY OF CHAR);
VAR i, j: LONGINT; c: Name;
BEGIN
  i := 0;
  WHILE s[i] # 0X DO
    WHILE s[i] = " " DO INC(i) END;
    j := 0; WHILE (s[i] # 0X) & (s[i] # ";") DO IF j < NameLen - 1 THEN c[j] := s[i]; INC(j) END; INC(i) END;
    WHILE (j > 0) & (c[j-1] = " ") DO DEC(j) END;
    c[j] := 0X; IF c # "" THEN Add(list, c) END;
    IF s[i] = ";" THEN INC(i) END
  END
END AddCommands;

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
VAR s: TOML.Section; f: TOML.Field; it: Item;
BEGIN
  s := TOML.GetSection(doc, sec);
  IF s # NIL THEN
    f := s.first;
    WHILE f # NIL DO
      Add(list, f.key); it := list; WHILE it.next # NIL DO it := it.next END; COPY(f.value, it.v);
      f := f.next
    END
  END
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
  IF Field(doc, "MODULES", "all", v) THEN AddSources(p.sources, v) END;
  IF Field(doc, "MODULES", arch, v) THEN AddSources(p.sources, v) END;
  IF Field(doc, "BUILD", arch, v) THEN AddCommands(p.build, v) END;
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
VAR path: Name; buf: Buf; i, j: LONGINT; name, ver: Name; it: Item;
BEGIN
  installed := NIL; DbName(path); haveDb := ReadFile(path, buf);
  IF haveDb THEN
    i := 0;
    WHILE buf[i] # 0X DO
      j := 0; WHILE buf[i] > " " DO name[j] := buf[i]; INC(i); INC(j) END; name[j] := 0X;
      WHILE (buf[i] = " ") OR (buf[i] = 09X) DO INC(i) END;
      j := 0; WHILE buf[i] > " " DO ver[j] := buf[i]; INC(i); INC(j) END; ver[j] := 0X;
      WHILE (buf[i] # 0X) & (buf[i] # 0AX) DO INC(i) END;
      IF buf[i] = 0AX THEN INC(i) END;
      IF name # "" THEN
        Add(installed, name); it := installed; WHILE it.next # NIL DO it := it.next END; COPY(ver, it.v)
      END
    END
  END
END LoadDb;

PROCEDURE SaveDb;
VAR path: Name; f: F.File; R: F.Rider; it: Item; i: LONGINT;

  PROCEDURE W(s: ARRAY OF CHAR);
  BEGIN i := 0; WHILE s[i] # 0X DO F.Write(R, s[i]); INC(i) END
  END W;

BEGIN
  DbName(path); f := F.New(path);
  IF f = NIL THEN out.String("portia: cannot write "); out.String(path); out.Ln; RETURN END;
  F.Set(R, f, 0); it := installed;
  WHILE it # NIL DO
    W(it.s); W(" "); W(it.v); F.Write(R, 0AX);
    it := it.next
  END;
  F.Register(f); haveDb := TRUE
END SaveDb;

PROCEDURE Drop(VAR list: Item; s: ARRAY OF CHAR);
VAR p: Item;
BEGIN
  IF list # NIL THEN
    IF list.s = s THEN list := list.next
    ELSE p := list; WHILE (p.next # NIL) & (p.next.s # s) DO p := p.next END; IF p.next # NIL THEN p.next := p.next.next END
    END
  END
END Drop;

(* record name as installed in version v *)
PROCEDURE SetInstalled(name, v: ARRAY OF CHAR);
VAR it: Item;
BEGIN
  it := installed; WHILE (it # NIL) & (it.s # name) DO it := it.next END;
  IF it = NIL THEN Add(installed, name); it := installed; WHILE it.next # NIL DO it := it.next END END;
  COPY(v, it.v)
END SetInstalled;

(* the installed version of p; FALSE if it is not recorded *)
PROCEDURE InstVer(p: Package; VAR v: ARRAY OF CHAR): BOOLEAN;
VAR it: Item;
BEGIN
  it := installed; WHILE (it # NIL) & (it.s # p.name) DO it := it.next END;
  IF it = NIL THEN v[0] := 0X; RETURN FALSE END;
  COPY(it.v, v); RETURN TRUE
END InstVer;

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

(** portia.List -- the packages of the tree; i: installed here, u: a newer version in the tree *)
PROCEDURE List*;
VAR p: Package; n: LONGINT; v: ARRAY 32 OF CHAR;
BEGIN
  IF ~LoadTree() THEN RETURN END;
  p := packages;
  WHILE p # NIL DO
    IF ~IsInstalled(p) THEN out.String("  ")
    ELSIF haveDb & InstVer(p, v) & ~Versions.AtLeast(v, p.version) THEN out.String("u ")  (* upgradable *)
    ELSE out.String("i ")
    END;
    out.String(p.name); n := 0; WHILE p.name[n] # 0X DO INC(n) END;
    WHILE n < 24 DO out.Char(" "); INC(n) END;
    IF haveDb & InstVer(p, v) & (Versions.Compare(v, p.version) # 0) THEN
      out.String(v); out.String(" -> "); out.String(p.version)
    ELSE out.String(p.version)
    END;
    out.String("  "); out.String(p.desc); out.Ln;
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
PROCEDURE ^Resolve(VAR name: ARRAY OF CHAR): Package;

PROCEDURE Check*;
VAR p, q: Package; it, im, set: Item; path, mod: Name; problems: LONGINT; v: ARRAY 32 OF CHAR;
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
    it := p.deps;
    WHILE it # NIL DO
      q := Resolve(it.s);
      IF q = NIL THEN out.String(p.name); out.String(": needs "); out.String(it.s); out.String(", not in the tree"); out.Ln; INC(problems)
      ELSIF ~IsInstalled(q) THEN out.String(p.name); out.String(": needs "); out.String(it.s); out.String(", not installed"); out.Ln; INC(problems)
      ELSIF haveDb & InstVer(q, v) & (it.v # "") & ~Versions.AtLeast(v, it.v) THEN
        out.String(p.name); out.String(": needs "); out.String(q.name); out.String(" "); out.String(it.v);
        out.String(", installed is "); out.String(v); out.Ln; INC(problems)
      END;
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

(* ----- building ----- *)

(* path as it is found: in the current directory, else in the polpo root *)
PROCEDURE Local(VAR path: ARRAY OF CHAR);
VAR full: Name;
BEGIN
  IF ~Root.Exists(path) THEN Root.Join(path, full); IF Root.Exists(full) THEN COPY(full, path) END END
END Local;

PROCEDURE Compiler(VAR cmd: ARRAY OF CHAR);  (* for arch *)
BEGIN
  IF arch = "x86" THEN COPY("compiler.Compile", cmd) ELSIF arch = "arm" THEN COPY("acompiler.Compile", cmd)
  ELSIF arch = "riscv" THEN COPY("rvcompiler.Compile", cmd) ELSIF arch = "mips" THEN COPY("mcompiler.Compile", cmd)
  ELSE COPY("a7compiler.Compile", cmd)
  END
END Compiler;

(* run "Module.Command parameters", or "mv from to" *)
PROCEDURE Run(VAR line: ARRAY OF CHAR): BOOLEAN;
VAR cmd, a, b: Name; i, j: LONGINT; par: Oberon.ParList; W: Texts.Writer; res: INTEGER;
BEGIN
  i := 0; WHILE (line[i] # 0X) & (line[i] # " ") DO cmd[i] := line[i]; INC(i) END; cmd[i] := 0X;
  WHILE line[i] = " " DO INC(i) END;
  IF cmd = "mv" THEN
    j := 0; WHILE (line[i] # 0X) & (line[i] # " ") DO a[j] := line[i]; INC(i); INC(j) END; a[j] := 0X;
    WHILE line[i] = " " DO INC(i) END;
    j := 0; WHILE (line[i] # 0X) & (line[i] # " ") DO b[j] := line[i]; INC(i); INC(j) END; b[j] := 0X;
    F.Rename(a, b, res);
    IF res # 0 THEN out.String("portia: cannot move "); out.String(a); out.String(" to "); out.String(b); out.Ln; RETURN FALSE END;
    RETURN TRUE
  END;
  NEW(par); NEW(par.text); Texts.Open(par.text, ""); par.pos := 0;
  Texts.OpenWriter(W); j := i; WHILE line[j] # 0X DO Texts.Write(W, line[j]); INC(j) END;
  Texts.Append(par.text, W.buf);
  Oberon.Call(cmd, par, FALSE, res);
  IF res # 0 THEN out.String("portia: cannot run "); out.String(cmd); out.Ln; RETURN FALSE END;
  RETURN TRUE
END Run;

(* the date of a file, 0 if there is none *)
PROCEDURE Stamp(VAR path: ARRAY OF CHAR): LONGINT;
VAR f: F.File; t, d: LONGINT;
BEGIN
  f := F.Old(path); IF f = NIL THEN RETURN 0 END;
  F.GetDate(f, t, d); F.ReleaseRead(f); RETURN d * 1000000H + t  (* d:t, only compared *)
END Stamp;

(* a checksum of the interface of module mod: its symbol file, on x86 the symbol part of the
   object file (tag, format, size, then the symbols); len 0 if there is none *)
PROCEDURE SymKey(VAR mod: ARRAY OF CHAR; VAR len, s1, s2: LONGINT);
VAR path: Name; f: F.File; R: F.Rider; c, tag: CHAR; n: LONGINT;
BEGIN
  len := 0; s1 := 0; s2 := 0;
  ObjFile(mod, arch # "x86", path); Local(path);
  f := F.Old(path); IF f = NIL THEN RETURN END;
  F.Set(R, f, 0);
  IF arch = "x86" THEN
    F.Read(R, tag); F.Read(R, c);
    IF tag # 0BBX THEN F.ReleaseRead(f); len := -1; RETURN END;
    F.ReadNum(R, n)
  ELSE n := F.Length(f)
  END;
  WHILE (len < n) & ~R.eof DO
    F.Read(R, c); s1 := (s1 * 31 + ORD(c)) MOD 999983; s2 := (s2 + ORD(c) * (len MOD 97 + 1)) MOD 1000003; INC(len)
  END;
  F.ReleaseRead(f)
END SymKey;

(* compile the sources of p, each after the modules of p it imports; changed: the interface
   of a module that existed before changed, its importers must be recompiled *)
PROCEDURE BuildPackage(p: Package; VAR changed: BOOLEAN): BOOLEAN;
CONST Max = 256;
VAR src, modn: ARRAY Max OF Item; imp: ARRAY Max OF Item; done: ARRAY Max OF BOOLEAN;
  n, i, k, left: LONGINT; it: Item; ready, progress, had: BOOLEAN; mod, cmd, line, obj, old: Name; res: INTEGER;
  l0, a0, b0, l1, a1, b1: LONGINT;
BEGIN
  changed := FALSE; n := 0; it := p.sources;
  WHILE (it # NIL) & (n < Max) DO
    src[n] := it; IF Header(it.s, mod) THEN END;
    NEW(modn[n]); COPY(mod, modn[n].s); imp[n] := imports; done[n] := FALSE; INC(n); it := it.next
  END;
  Compiler(cmd); left := n;
  WHILE left > 0 DO
    progress := FALSE; i := 0;
    WHILE i < n DO
      IF ~done[i] THEN
        ready := TRUE; it := imp[i];
        WHILE it # NIL DO  (* an import from this package not compiled yet *)
          k := 0; WHILE k < n DO IF ~done[k] & (k # i) & (modn[k].s = it.s) THEN ready := FALSE END; INC(k) END;
          it := it.next
        END;
        IF ready THEN
          (* the old object aside: a new one must appear; back if the compilation fails *)
          SymKey(modn[i].s, l0, a0, b0);
          ObjFile(modn[i].s, FALSE, obj); Local(obj); COPY(obj, old); Append(old, ".old");
          had := Root.Exists(obj); IF had THEN F.Rename(obj, old, res) END;
          COPY(cmd, line); Append(line, " /s"); Append(line, src[i].flags); Append(line, " "); Append(line, src[i].s);
          IF ~Run(line) OR ~Root.Exists(obj) THEN
            IF had THEN F.Rename(old, obj, res) END;
            out.String("portia: "); out.String(src[i].s); out.String(" did not compile"); out.Ln; RETURN FALSE
          END;
          IF had THEN F.Delete(old, res) END;
          SymKey(modn[i].s, l1, a1, b1);
          IF (l0 > 0) & ((l1 # l0) OR (a1 # a0) OR (b1 # b0)) THEN
            out.String("portia: the interface of "); out.String(modn[i].s); out.String(" changed"); out.Ln; changed := TRUE
          END;
          done[i] := TRUE; DEC(left); progress := TRUE
        END
      END;
      INC(i)
    END;
    IF ~progress THEN out.String("portia: modules of "); out.String(p.name); out.String(" import each other in a cycle"); out.Ln; RETURN FALSE END
  END;
  RETURN TRUE
END BuildPackage;

(* the packages to build in order, dependencies first; virtual ones: the installed provider *)
PROCEDURE Order(p: Package; VAR list: Item);
VAR it: Item; q, r: Package;
BEGIN
  IF Has(list, p.name) THEN RETURN END;
  Add(list, "?");  (* placeholder against cycles, replaced below *)
  it := p.deps;
  WHILE it # NIL DO
    q := Find(it.s);
    IF q = NIL THEN  (* virtual *)
      r := packages; q := NIL;
      WHILE r # NIL DO IF Has(r.provides, it.s) & ((q = NIL) OR IsInstalled(r)) THEN q := r END; r := r.next END
    END;
    IF q # NIL THEN Order(q, list) END;
    it := it.next
  END;
  Drop(list, "?"); IF ~Has(list, p.name) THEN Add(list, p.name) END
END Order;

PROCEDURE SetArch(a: ARRAY OF CHAR);
BEGIN
  IF a # arch THEN COPY(a, arch); packages := NIL END
END SetArch;

(** portia.Record -- record the packages whose files are here as installed; of alternatives
  sharing files (display-x11, display-sixel) the first; see portia.Mark *)
(* the record from the files present; of alternatives the first *)
PROCEDURE RecordAll(verbose: BOOLEAN);
VAR p: Package; it: Item; skip: BOOLEAN;
BEGIN
  installed := NIL; p := packages;
  WHILE p # NIL DO
    IF Installed(p) THEN
      skip := FALSE; it := p.conflicts;
      WHILE it # NIL DO IF Has(installed, it.s) THEN skip := TRUE END; it := it.next END;
      IF skip THEN
        IF verbose THEN
          out.String("not recorded "); out.String(p.name); out.String(", it conflicts with a recorded package (portia.Mark "); out.String(p.name); out.String(" switches)"); out.Ln
        END
      ELSE SetInstalled(p.name, p.version)
      END
    END;
    p := p.next
  END;
  SaveDb
END RecordAll;

PROCEDURE Record*;
BEGIN
  IF ~LoadTree() THEN RETURN END;
  RecordAll(TRUE); List
END Record;

(** portia.Mark name -- record the package as installed; its conflicts are unmarked *)
PROCEDURE Mark*;
VAR name: Name; p: Package; it: Item;
BEGIN
  IF ~Arg(name) THEN out.String("usage: portia.Mark name"); out.Ln; RETURN END;
  IF ~LoadTree() THEN RETURN END;
  p := Find(name);
  IF p = NIL THEN out.String("portia: no package "); out.String(name); out.Ln; RETURN END;
  it := p.conflicts; WHILE it # NIL DO Drop(installed, it.s); it := it.next END;
  SetInstalled(name, p.version);
  SaveDb; out.String(name); out.String(" marked installed"); out.Ln
END Mark;

(** portia.Unmark name -- record the package as not installed (the files stay) *)
PROCEDURE Unmark*;
VAR name: Name;
BEGIN
  IF ~Arg(name) THEN out.String("usage: portia.Unmark name"); out.Ln; RETURN END;
  IF ~LoadTree() THEN RETURN END;
  Drop(installed, name); SaveDb; out.String(name); out.String(" unmarked"); out.Ln
END Unmark;

(* ----- installing and removing ----- *)

(* delete the objects of the modules of p that no other installed package has *)
PROCEDURE DeleteObjects(p: Package);
VAR it: Item; q: Package; shared: BOOLEAN; path, full: Name; res: INTEGER; i: INTEGER;
BEGIN
  it := p.modules;
  WHILE it # NIL DO
    shared := FALSE; q := packages;
    WHILE q # NIL DO IF (q # p) & IsInstalled(q) & Has(q.modules, it.s) THEN shared := TRUE END; q := q.next END;
    IF ~shared THEN
      i := 0;
      WHILE i < 2 DO
        ObjFile(it.s, i = 1, path);
        IF Root.Exists(path) THEN F.Delete(path, res)
        ELSE Root.Join(path, full); IF Root.Exists(full) THEN F.Delete(full, res) END
        END;
        INC(i)
      END
    END;
    it := it.next
  END
END DeleteObjects;

(* the installed packages that need p: depend on it, or on something only p provides *)
PROCEDURE Needers(p: Package; VAR list: Item);
VAR q, r: Package; it: Item; other: BOOLEAN;
BEGIN
  q := packages;
  WHILE q # NIL DO
    IF (q # p) & IsInstalled(q) THEN
      it := q.deps;
      WHILE it # NIL DO
        IF it.s = p.name THEN Add(list, q.name)
        ELSIF Has(p.provides, it.s) THEN
          other := FALSE; r := packages;
          WHILE r # NIL DO IF (r # p) & IsInstalled(r) & Has(r.provides, it.s) THEN other := TRUE END; r := r.next END;
          IF ~other THEN Add(list, q.name) END
        END;
        it := it.next
      END
    END;
    q := q.next
  END
END Needers;

(* the arguments: /arch and package names *)
PROCEDURE Args(VAR names: Item);
VAR A: Texts.Reader; name: Name; n: LONGINT;
BEGIN
  Texts.OpenArgs(A); names := NIL; SetArch(hostArch); assumeYes := FALSE;
  WHILE Texts.Arg(A, name) DO
    IF (name = "/y") OR (name = "/Y") THEN assumeYes := TRUE
    ELSIF name[0] = "/" THEN
      n := 0; WHILE name[n+1] # 0X DO name[n] := name[n+1]; INC(n) END; name[n] := 0X; SetArch(name)
    ELSE Add(names, name)
    END
  END
END Args;

(* ask to proceed with n packages; /y does not ask, without a terminal /y is needed *)
PROCEDURE Confirm(n: LONGINT; what: ARRAY OF CHAR): BOOLEAN;
VAR t: termios.Termios; c, answer: CHAR; r: LONGINT; echo: BOOLEAN;
BEGIN
  IF assumeYes THEN RETURN TRUE END;
  IF termios.Get(0, t) # 0 THEN
    out.String("portia: not asking without a terminal; add /y to proceed"); out.Ln; RETURN FALSE
  END;
  echo := ~(termios.ECHO IN t.lflag);  (* the shell may have turned echo off *)
  out.String("Proceed "); out.String(what); out.String(" "); out.Int(n, 0);
  IF n = 1 THEN out.String(" package? [Y/n] ") ELSE out.String(" packages? [Y/n] ") END;
  answer := 0X;
  LOOP
    r := Linux0.Read0(0, SYSTEM.ADR(c), 1);
    IF r <= 0 THEN answer := "n"; EXIT END;
    IF (c = 0DX) OR (c = 0AX) THEN EXIT END;
    IF c = 3X THEN answer := "n"; EXIT END;  (* ^C *)
    IF c > " " THEN IF answer = 0X THEN answer := c END; IF echo THEN out.Char(c) END END
  END;
  IF echo THEN out.Ln END;
  RETURN (answer = 0X) OR (answer = "y") OR (answer = "Y")
END Confirm;

(* ----- versions: what to build ----- *)

(* the package for a dependency: itself, or for a virtual one the installed provider (else
   the first one in the tree) *)
PROCEDURE Resolve(VAR name: ARRAY OF CHAR): Package;
VAR q, r: Package;
BEGIN
  q := Find(name);
  IF q = NIL THEN
    r := packages;
    WHILE r # NIL DO IF Has(r.provides, name) & ((q = NIL) OR IsInstalled(r)) THEN q := r END; r := r.next END
  END;
  RETURN q
END Resolve;

(* add to set the dependencies of p that are missing or older than p needs, recursively *)
PROCEDURE AddNeeded(p: Package; VAR set: Item): BOOLEAN;
VAR it: Item; q: Package; v: ARRAY 32 OF CHAR;
BEGIN
  it := p.deps;
  WHILE it # NIL DO
    q := Resolve(it.s);
    IF q = NIL THEN out.String("portia: "); out.String(p.name); out.String(" needs "); out.String(it.s); out.String(", not in the tree"); out.Ln; RETURN FALSE END;
    IF (it.v # "") & ~Versions.AtLeast(q.version, it.v) THEN
      out.String("portia: "); out.String(p.name); out.String(" needs "); out.String(q.name); out.String(" "); out.String(it.v);
      out.String(", the tree has "); out.String(q.version); out.Ln; RETURN FALSE
    END;
    IF ~Has(set, q.name) & (~IsInstalled(q) OR haveDb & InstVer(q, v) & (it.v # "") & ~Versions.AtLeast(v, it.v)) THEN
      Add(set, q.name);
      IF ~AddNeeded(q, set) THEN RETURN FALSE END
    END;
    it := it.next
  END;
  RETURN TRUE
END AddNeeded;

(* build the packages of set in dependency order, link, record them; replace conflicts *)
PROCEDURE Execute(set: Item; verb: ARRAY OF CHAR);
VAR order, it, c, cf, d: Item; p, q, r: Package; ok, changed: BOOLEAN; line: Name; n: LONGINT; v: ARRAY 32 OF CHAR;
BEGIN
  order := NIL; it := set; WHILE it # NIL DO p := Find(it.s); Order(p, order); it := it.next END;
  q := packages; WHILE q # NIL DO IF IsInstalled(q) THEN Order(q, order) END; q := q.next END;  (* for importers *)
  out.String("portia: "); out.String(verb); out.String(" for "); out.String(arch); out.String(":"); out.Ln;
  it := order; n := 0;
  WHILE it # NIL DO
    IF Has(set, it.s) THEN
      p := Find(it.s); out.String("  "); out.String(p.name); out.Char(" "); out.String(p.version); out.String("  ");
      c := set; WHILE c.s # p.name DO c := c.next END;
      IF c.v # "" THEN out.String("recompiled for the new "); out.String(c.v)
      ELSIF ~IsInstalled(p) THEN out.String("new")
      ELSIF InstVer(p, v) & (Versions.Compare(v, p.version) # 0) THEN out.String("upgrade from "); out.String(v)
      ELSE out.String("rebuilt")
      END;
      out.Ln; INC(n)
    END;
    it := it.next
  END;
  out.String("  (installed packages importing an interface that changes are recompiled too)"); out.Ln;
  IF ~Confirm(n, verb) THEN out.String("portia: nothing done"); out.Ln; RETURN END;
  n := 0;
  ok := TRUE; it := order;
  WHILE ok & (it # NIL) DO
    p := Find(it.s);
    IF Has(set, p.name) THEN
      ok := BuildPackage(p, changed); INC(n);
      IF ok & changed THEN  (* its importers are recompiled when their turn comes *)
        q := packages;
        WHILE q # NIL DO
          IF IsInstalled(q) & ~Has(set, q.name) THEN
            d := q.deps;
            WHILE d # NIL DO
              r := Resolve(d.s);
              IF (r = p) & ~Has(set, q.name) THEN
                Add(set, q.name); out.String("portia: recompiling "); out.String(q.name);
                out.String(" for the new interface of "); out.String(p.name); out.Ln
              END;
              d := d.next
            END
          END;
          q := q.next
        END
      END;
      c := p.build; WHILE ok & (c # NIL) DO COPY(c.s, line); ok := Run(line); c := c.next END;
      IF ok THEN
        SetInstalled(p.name, p.version);  (* first: its objects are not deleted below *)
        cf := p.conflicts;
        WHILE cf # NIL DO
          q := Find(cf.s);
          IF (q # NIL) & IsInstalled(q) THEN
            Drop(installed, q.name); DeleteObjects(q); out.String("portia: replaced "); out.String(q.name); out.Ln
          END;
          cf := cf.next
        END;
        SaveDb
      END
    END;
    it := it.next
  END;
  IF ok THEN out.String("portia: done, "); out.Int(n, 0); out.String(" packages") ELSE out.String("portia: stopped") END; out.Ln
END Execute;

PROCEDURE Start(VAR names: Item): BOOLEAN;  (* arguments, the tree and the record *)
BEGIN
  Args(names);
  IF ~LoadTree() THEN SetArch(hostArch); RETURN FALSE END;
  IF ~haveDb THEN RecordAll(FALSE) END;
  RETURN TRUE
END Start;

(** portia.Install [/arch] name ... -- install the packages: build them, and the dependencies
  that are missing or older than needed; packages already installed in the tree's version
  are left alone. Installed packages they conflict with are replaced *)
PROCEDURE Install*;
VAR names, set, it: Item; p: Package; v: ARRAY 32 OF CHAR; ok: BOOLEAN;
BEGIN
  IF ~Start(names) THEN RETURN END;
  IF names = NIL THEN out.String("usage: portia.Install [/arch] name ..."); out.Ln; SetArch(hostArch); RETURN END;
  set := NIL; ok := TRUE; it := names;
  WHILE ok & (it # NIL) DO
    p := Find(it.s);
    IF p = NIL THEN out.String("portia: no package "); out.String(it.s); out.Ln; ok := FALSE
    ELSIF IsInstalled(p) & haveDb & InstVer(p, v) & Versions.AtLeast(v, p.version) THEN
      out.String("portia: "); out.String(p.name); out.Char(" "); out.String(v); out.String(" is installed"); out.Ln
    ELSE Add(set, p.name); ok := AddNeeded(p, set)
    END;
    it := it.next
  END;
  IF ok & (set # NIL) THEN Execute(set, "installing") END;
  SetArch(hostArch)
END Install;

(** portia.Upgrade [/arch] [name ...] -- build the installed packages with a newer version in
  the tree (all, or the named ones), what they need, and the packages depending on them *)
PROCEDURE Upgrade*;
VAR names, set: Item; p: Package; v: ARRAY 32 OF CHAR; ok: BOOLEAN;
BEGIN
  IF ~Start(names) THEN RETURN END;
  set := NIL; ok := TRUE; p := packages;
  WHILE ok & (p # NIL) DO
    IF IsInstalled(p) & ((names = NIL) OR Has(names, p.name)) & InstVer(p, v) & ~Versions.AtLeast(v, p.version) THEN
      Add(set, p.name); ok := AddNeeded(p, set)
    END;
    p := p.next
  END;
  IF ~ok THEN
  ELSIF set = NIL THEN out.String("portia: everything is up to date"); out.Ln
  ELSE Execute(set, "upgrading")
  END;
  SetArch(hostArch)
END Upgrade;

(** portia.Build [/arch] [name ...] -- rebuild the packages (and dependencies missing or too
  old); without names every installed package *)
PROCEDURE Build*;
VAR names, set, it: Item; p: Package; ok: BOOLEAN;
BEGIN
  IF ~Start(names) THEN RETURN END;
  set := NIL; ok := TRUE;
  IF names = NIL THEN
    p := packages; WHILE p # NIL DO IF IsInstalled(p) THEN Add(set, p.name) END; p := p.next END
  ELSE
    it := names;
    WHILE ok & (it # NIL) DO
      p := Find(it.s);
      IF p = NIL THEN out.String("portia: no package "); out.String(it.s); out.Ln; ok := FALSE
      ELSE Add(set, p.name); ok := AddNeeded(p, set)
      END;
      it := it.next
    END
  END;
  IF ok THEN Execute(set, "building") END;
  SetArch(hostArch)
END Build;

(* ----- the dependency graph ----- *)

(** portia.Graph [name] -- the dependencies as a Graphviz graph on the standard output, of
  one package and what it needs, or of the whole tree; installed packages filled, virtual
  ones (display) dashed with their providers:  loksh portia.Graph > deps.dot; dot -Tsvg ... *)
PROCEDURE Graph*;
VAR name: Name; set, it, d, virt: Item; p, q: Package;

  PROCEDURE Q(s: ARRAY OF CHAR);
  BEGIN out.Char(22X); out.String(s); out.Char(22X)
  END Q;

BEGIN
  IF ~LoadTree() THEN RETURN END;
  set := NIL;
  IF Arg(name) THEN
    p := Find(name);
    IF p = NIL THEN out.String("portia: no package "); out.String(name); out.Ln; RETURN END;
    Closure(p, set)
  ELSE p := packages; WHILE p # NIL DO Add(set, p.name); p := p.next END
  END;
  out.String("digraph arden {"); out.Ln;
  out.String("  rankdir=LR; node [shape=box, fontname=sans];"); out.Ln;
  virt := NIL; it := set;
  WHILE it # NIL DO
    p := Find(it.s);
    IF p # NIL THEN
      out.String("  "); Q(p.name); out.String(" [label="); out.Char(22X); out.String(p.name); out.String("\n"); out.String(p.version); out.Char(22X);
      IF IsInstalled(p) THEN out.String(", style=filled, fillcolor=lightgrey") END;
      out.String("];"); out.Ln;
      d := p.deps;
      WHILE d # NIL DO
        out.String("  "); Q(p.name); out.String(" -> "); Q(d.s);
        IF d.v # "" THEN out.String(" [label="); Q(d.v); out.String("]") END;
        out.String(";"); out.Ln;
        IF (Find(d.s) = NIL) & ~Has(virt, d.s) THEN Add(virt, d.s) END;
        d := d.next
      END
    END;
    it := it.next
  END;
  it := virt;
  WHILE it # NIL DO  (* a virtual package and its providers *)
    out.String("  "); Q(it.s); out.String(" [style=dashed, shape=ellipse];"); out.Ln;
    q := packages;
    WHILE q # NIL DO
      IF Has(q.provides, it.s) THEN out.String("  "); Q(q.name); out.String(" -> "); Q(it.s); out.String(" [style=dashed, dir=back];"); out.Ln END;
      q := q.next
    END;
    it := it.next
  END;
  out.String("}"); out.Ln
END Graph;

(** portia.Remove [/arch] name ... -- delete the objects of the packages and unrecord them;
  not while installed packages need them. Sources and data of the base system stay *)
PROCEDURE Remove*;
VAR names, it, needers, n2: Item; p: Package; ok: BOOLEAN; n: LONGINT;
BEGIN
  Args(names);
  IF names = NIL THEN out.String("usage: portia.Remove [/arch] [/y] name ..."); out.Ln; SetArch(hostArch); RETURN END;
  IF ~LoadTree() THEN SetArch(hostArch); RETURN END;
  IF ~haveDb THEN RecordAll(FALSE) END;
  ok := TRUE; it := names;
  WHILE it # NIL DO
    p := Find(it.s);
    IF p = NIL THEN out.String("portia: no package "); out.String(it.s); out.Ln; ok := FALSE
    ELSIF ~IsInstalled(p) THEN out.String("portia: "); out.String(it.s); out.String(" is not installed"); out.Ln; ok := FALSE
    ELSE
      needers := NIL; Needers(p, needers);
      n2 := needers; WHILE n2 # NIL DO IF Has(names, n2.s) THEN Drop(needers, n2.s); n2 := needers ELSE n2 := n2.next END END;
      IF needers # NIL THEN  (* needed by a package that stays *)
        out.String("portia: "); out.String(p.name); out.String(" is needed by");
        n2 := needers; WHILE n2 # NIL DO out.Char(" "); out.String(n2.s); n2 := n2.next END; out.Ln; ok := FALSE
      END
    END;
    it := it.next
  END;
  IF ok THEN
    out.String("portia: removing for "); out.String(arch); out.String(" (objects; sources and data of the base system stay):"); out.Ln;
    n := 0; it := names; WHILE it # NIL DO p := Find(it.s); out.String("  "); out.String(p.name); out.Char(" "); out.String(p.version); out.Ln; INC(n); it := it.next END;
    IF Confirm(n, "removing") THEN
      it := names;
      WHILE it # NIL DO p := Find(it.s); DeleteObjects(p); Drop(installed, p.name); it := it.next END;
      SaveDb; out.String("portia: removed "); out.Int(n, 0); IF n = 1 THEN out.String(" package") ELSE out.String(" packages") END; out.Ln
    ELSE out.String("portia: nothing done"); out.Ln
    END
  END;
  SetArch(hostArch)
END Remove;

PROCEDURE Init;
VAR S: Texts.Scanner; i: LONGINT;
BEGIN
  IF Linux0.ARCH = "X86" THEN hostArch := "x86" ELSIF Linux0.ARCH = "ARM" THEN hostArch := "arm"
  ELSIF Linux0.ARCH = "RISC-V" THEN hostArch := "riscv" ELSIF Linux0.ARCH = "MIPS" THEN hostArch := "mips"
  ELSE hostArch := "armv7"
  END;
  COPY(hostArch, arch);
  Kernel.GetConfig("PORTIA_TREE", tree);  (* first: Oberon.Text strings have at most 63 characters *)
  IF tree = "" THEN
    Oberon.OpenScanner(S, "Portia.Tree");
    IF S.class IN {Texts.Name, Texts.String} THEN COPY(S.s, tree)
    ELSE Root.Join("../arden/", tree)
    END
  END;
  i := 0; WHILE tree[i] # 0X DO INC(i) END;
  IF (i > 0) & (tree[i-1] # "/") THEN Append(tree, "/") END;
  packages := NIL
END Init;

BEGIN
  Init
END portia.
