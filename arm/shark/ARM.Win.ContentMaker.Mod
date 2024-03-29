�TextDocs.NewDoc     �� ��   Syntax10.Scn.Fnt  L   Oberon10.Scn.Fnt     Oberon20.Scn.Fnt             Courier10.Scn.Fnt  L   0   {    K   �        4    �   G   &    	   +    `    `    �    .    �       �   R   �%  MODULE ContentMaker; (* as  20.02.99 *)

(* Creates a "RAMDisk.Content"-File. This is the Windows version 

Syntax:
  ContentDescription = CONTENTFILE [ string ]
                       PREFIX string
                       [ Files ]
                       [ Archive { Archive } ]
                       END CONTENTFILE.
  Archive            = ARCHIVE string Files .
  Files              = FILES string { string } [ "-" string { string } ] .
*)

IMPORT FileDir, Files, Texts, Fonts, Out, Gadgets, Strings, Oberon, CRC32, SYSTEM;

CONST
	(* scanner *)
	Null = 0; Prefix = 1; Archive = 2; SymFiles = 3; Except = 4; Contentfile = 5; End = 6; String = 7; Eof = 8;
	KW = 11;
	maxStrLen = 128;

TYPE
	ListElem = POINTER TO ListElemDesc;
	ListElemDesc = RECORD next : ListElem; name : ARRAY 64 OF CHAR END;
	
VAR
	anchor : ListElem;
	contentR : Files.Rider;
	prefix : ARRAY 64 OF CHAR;
	
	(* scanner *)
	name : ARRAY maxStrLen OF CHAR;
	R: Texts.Reader;
	ch, prev: CHAR;     (*current and previous  characters*)
	lastpos: LONGINT; (*error position in source file*)
	i: INTEGER;
	keyTab  : ARRAY KW OF RECORD symb, alt: INTEGER; id: ARRAY 12 OF CHAR END;
	err : BOOLEAN;
	sym : INTEGER;

(* ----------------- scanner ---------------------- *)
PROCEDURE GetCh;
BEGIN
	(* System3 get: skip embedded objects *)
	REPEAT Texts.Read(R, ch) UNTIL R.eot OR ((R.lib # NIL) & (R.lib IS Fonts.Font))
END GetCh;

PROCEDURE Mark*(msg : ARRAY OF CHAR);
VAR pos: LONGINT;
BEGIN 
	pos := Texts.Pos(R);
	IF lastpos + 8 < pos THEN
		Out.Ln; Out.String("  pos "); Out.Int(pos,1); 
		Out.String("  error: "); Out.String(msg);
		err := TRUE; lastpos := pos
	END
END Mark;

PROCEDURE GetSym(VAR sym: INTEGER);
VAR s, i, k: INTEGER;
BEGIN
	LOOP (*ignore control characters*)
		IF ch <= " " THEN
			IF ch = 0X THEN ch := " "; EXIT ELSE GetCh END
		ELSIF ch > 7FX THEN GetCh
		ELSE EXIT
		END
	END ;
	prev := ch; GetCh;
	CASE prev OF   (* " " <= prev <= 7FX *)
			" "  : s := Eof; ch := 0X (*eof*)
		| 22X  : 
				LOOP
					IF ch = 22X THEN EXIT END ;
					IF ch < " " THEN Mark("illegal character in string"); EXIT END ;
					IF i < maxStrLen-1 THEN name[i] := ch; INC(i) ELSE Mark("string too long"); i := 0 END ;
					GetCh;
				END ;
				GetCh;
				s := String; name[i] := 0X 
		| "A".."Z", "a".."z":
			name[0] := prev; i := 1; k := ORD(prev);
			WHILE (CAP(ch) >= "A") & (CAP(ch) <= "Z") OR (ch >= "0") & (ch <= "9") DO
				IF i < 31 THEN name[i] := ch; INC(i); INC(k, ORD(ch)) END ;
				GetCh
			END ;
			name[i] := 0X; 
			k := (k+i) MOD KW;  (*hash function*)
			IF (keyTab[k].symb # 0) & (keyTab[k].id = name) THEN s := keyTab[k].symb
			ELSE k := keyTab[k].alt;
				IF (keyTab[k].symb # 0) & (keyTab[k].id = name) THEN s := keyTab[k].symb
				ELSE s := Null (* unknown *)
				END
			END
		ELSE s := Null
	END;
	sym := s
END GetSym;

PROCEDURE InitScanner(source: Texts.Text; pos: LONGINT);
BEGIN
	ch := " "; err := FALSE; lastpos := -8;
	Texts.OpenReader(R, source, pos)
END InitScanner;

PROCEDURE EnterKW(sym: INTEGER; name: ARRAY OF CHAR);
	VAR j, k: INTEGER;
BEGIN j := 0; k := 0;
	REPEAT INC(k, ORD(name[j])); INC(j) UNTIL name[j] = 0X;
	k := (k+j) MOD KW;  (*hash function*)
	IF keyTab[k].symb # 0 THEN
		j := k;
		REPEAT INC(k) UNTIL keyTab[k].symb = 0; 
		keyTab[j].alt := k 
	END ;
	keyTab[k].symb := sym; COPY(name, keyTab[k].id)
END EnterKW;


(* --------------- list procedures -------------------------*)
PROCEDURE AddFile(name : ARRAY OF CHAR);
VAR e : ListElem;
BEGIN
	NEW(e); 
	e.next := anchor.next; anchor.next := e;
	COPY(name, e.name)
END AddFile;

PROCEDURE RemoveFile(name : ARRAY OF CHAR);
VAR cur, tmp : ListElem;
BEGIN
	cur := anchor;
	WHILE (cur.next # anchor) & (cur.next.name # name) DO cur := cur.next END;
	IF cur.next # anchor THEN
		tmp := cur.next;
		cur.next := cur.next.next;
		tmp.next := NIL
	END
END RemoveFile;

PROCEDURE ClearList;
BEGIN
	anchor.next := anchor
END ClearList;

PROCEDURE PrintAll;
VAR cur : ListElem;
BEGIN
	cur := anchor.next;
	WHILE cur # anchor DO Out.String(cur.name); Out.Ln; cur := cur.next END
END PrintAll;

(* ----------------- ContentMaker ------------------------ *)

PROCEDURE ws(s : ARRAY OF CHAR);
VAR i : INTEGER;
BEGIN
	i := 0; WHILE s[i] # 0X DO Files.Write(contentR,s[i]); INC(i) END
END ws;

PROCEDURE wh(l : LONGINT);
VAR buf: ARRAY 9 OF CHAR; i : LONGINT;
BEGIN
	FOR i := 7 TO 0 BY -1 DO
		buf[i] := CHR(l MOD 10H + 48);
		IF buf[i] > "9" THEN buf[i] := CHR(ORD(buf[i]) - 48 + 65 - 10) END;
		l := l DIV 10H
	END;
	buf[8] := 0X;
	ws("0"); ws(buf); ws("H")
END wh;

PROCEDURE wln;
BEGIN Files.Write(contentR,0DX); Files.Write(contentR,0AX)
END wln;

PROCEDURE RemovePrefix(prefix : ARRAY OF CHAR; VAR str : ARRAY OF CHAR);
VAR i, j : LONGINT;
BEGIN
	IF Strings.Prefix(prefix,str) THEN
		i := 0; j := Strings.Length(prefix);
		REPEAT str[i] := str[j]; INC(i); INC(j) UNTIL str[j-1]=0X
	END
END RemovePrefix;

PROCEDURE CalcCRC(fname : ARRAY OF CHAR) : LONGINT;
VAR r : Files.Rider; f : Files.File; crc : SET; c : CHAR;
BEGIN
	crc := CRC32.CRCInit;
	f:=Files.Old(fname); Files.Set(r,f,0);
	Files.Read(r,c);
	WHILE ~r.eof DO 
		crc := CRC32.CRC32(crc,c,1); Files.Read(r,c) 
	END;
	RETURN SYSTEM.VAL(LONGINT,crc)
END CalcCRC;

PROCEDURE AddFileEnumerator(path, name: ARRAY OF CHAR; time, date, size: LONGINT; isdir: BOOLEAN);
BEGIN
	IF isdir THEN RETURN END;
	AddFile(name)
END AddFileEnumerator;

PROCEDURE RemoveFileEnumerator(path, name: ARRAY OF CHAR; time, date, size: LONGINT; isdir: BOOLEAN);
BEGIN
	IF isdir THEN RETURN END;
	RemoveFile(name)
END RemoveFileEnumerator;

PROCEDURE FileSection;
BEGIN
	ClearList;
	WHILE sym = String DO
		FileDir.EnumerateFiles(".",name,FALSE,AddFileEnumerator);
		GetSym(sym)
	END;
	IF sym =Except THEN
		GetSym(sym);
		WHILE sym = String DO
			FileDir.EnumerateFiles(".",name,FALSE,RemoveFileEnumerator);
			GetSym(sym)
		END
	END;
END FileSection;

PROCEDURE ArchiveSection;
VAR 
	arcName : ARRAY 64 OF CHAR; 
	cmd, tmp : ARRAY 256 OF CHAR; 
	cur : ListElem; 
	res : INTEGER;
BEGIN
	WHILE sym = String DO
		COPY(name,arcName); GetSym(sym);
		IF sym # SymFiles THEN Mark("FILES expected"); RETURN END;
		GetSym(sym); ClearList;
		FileSection; 
	
		(* Now add all files *)
		Files.Delete(arcName,res);
		cur := anchor.next;
		WHILE cur # anchor DO
			cmd := "Compress.Add "; Strings.Append(cmd,arcName); 
			Strings.AppendCh(cmd," "); Strings.Append(cmd, cur.name); 
			Gadgets.Execute(cmd,NIL,NIL,NIL,NIL);
		
			COPY(cur.name,tmp); RemovePrefix(prefix,tmp);
			IF tmp # cur.name THEN
				cmd := "Compress.Rename "; Strings.Append(cmd,arcName);
				Strings.AppendCh(cmd," "); Strings.Append(cmd, cur.name); 
				Strings.Append(cmd," => "); Strings.Append(cmd, tmp);
				Gadgets.Execute(cmd,NIL,NIL,NIL,NIL)
			END;
			cur := cur.next
		END
	END;
	
	ws(arcName); ws(" [decompress] "); wh(CalcCRC(arcName)); wln
END ArchiveSection;

PROCEDURE WriteFileList;
VAR cur : ListElem; tmp : ARRAY 64 OF CHAR;
BEGIN
	cur := anchor.next;
	WHILE cur # anchor DO
		ws(cur.name);
		COPY(cur.name,tmp); RemovePrefix(prefix,tmp);
		IF tmp # cur.name THEN ws(" "); ws(tmp) END;
		ws(" "); wh(CalcCRC(cur.name)); wln;
		cur := cur.next
	END
END WriteFileList;

PROCEDURE CompilationUnit(source: Texts.Text; pos: LONGINT);
VAR f : Files.File; fname : ARRAY 32 OF CHAR;
BEGIN
	InitScanner(source,pos); GetSym(sym); Out.String(" compiling");
	IF sym # Contentfile THEN Mark("CONTENTFILE expected"); RETURN END;
	GetSym(sym); 
	IF sym = String THEN COPY(name,fname); GetSym(sym) ELSE COPY("RAMDisk.Content",fname) END;
	f := Files.New(fname); Files.Set(contentR,f,0);
	IF sym # Prefix THEN Mark("PREFIX expected"); RETURN END;
	GetSym(sym);
	IF sym # String THEN Mark("string expected"); RETURN END;
	COPY(name,prefix); GetSym(sym); 
	IF sym = SymFiles THEN GetSym(sym); FileSection; WriteFileList END;
	WHILE sym = Archive DO GetSym(sym); ArchiveSection END;
	IF sym # End THEN Mark("END expected"); RETURN END;
	GetSym(sym); IF sym # Contentfile THEN Mark("CONTENTFILE expected"); RETURN END;
	IF ~err THEN 
		Files.Register(f); 
		Out.Ln; Out.String(fname); Out.String(" created."); Out.Ln
	END
END CompilationUnit;

PROCEDURE Compile*;
VAR beg, end, time: LONGINT; T: Texts.Text;  S: Texts.Scanner;
BEGIN		
	Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
	IF S.class = Texts.Char THEN
		IF S.c = "*" THEN
			T := Oberon.MarkedText();
			CompilationUnit(Oberon.MarkedText(), 0)
		ELSIF S.c = "^" THEN
			Oberon.GetSelection(T, beg, end, time);
			IF time >= 0 THEN
				Texts.OpenScanner(S, T, beg); Texts.Scan(S);
				IF S.class = Texts.Name THEN
					Out.String(S.s); NEW(T); Texts.Open(T, S.s);
					IF T.len # 0 THEN CompilationUnit(T, 0)
					ELSE Out.String(" not found"); Out.Ln
					END
				END
			END
		ELSIF S.c = "@" THEN
			Oberon.GetSelection(T, beg, end, time);
			IF time >= 0 THEN CompilationUnit(T, beg) END
		END
	ELSE 
		NEW(T);
		WHILE S.class = Texts.Name DO
			Out.String(S.s); Texts.Open(T, S.s);
			IF T.len # 0 THEN CompilationUnit(T, 0)
			ELSE Out.String(" not found"); Out.Ln
			END;
			Texts.Scan(S)
		END
	END;
	ClearList
END Compile;

BEGIN
	(* init scanner *)
	i := KW;
	WHILE i > 0 DO
		DEC(i); keyTab[i].symb := 0; keyTab[i].alt := 0
	END ;
	keyTab[0].id := "";
	EnterKW(Prefix,"PREFIX");
	EnterKW(Archive, "ARCHIVE");
	EnterKW(SymFiles, "FILES");
	EnterKW(Except, "EXCEPT");
	EnterKW(Contentfile, "CONTENTFILE");
	EnterKW(End,"END");

	(* Init List of files *)
	NEW(anchor); anchor.next := anchor; anchor.name[0] := 0X;
END ContentMaker.Compile @

CONTENTFILE
PREFIX "ARM."
ARCHIVES
"ARM.ScnFonts2.Arc" FILES "*.Scn.Fnt" EXCEPT "Math*" "Greek*"
"ARM.SpecScnFonts.Arc" FILES "Math*.Scn.Fnt" "Greek*.Scn.Fnt"
END CONTENTFILE
