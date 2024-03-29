�TextDocs.NewDoc     �l�T  Oberon10.Scn.Fnt  U        �                                -        2                        9            	        -         H        (        R       �        !        l                /       �        !                                        Q    q       3        G        j                
                �        E       �           !    c    A           +                        )                	        =    !        +            @         (    #    4        |        G                        l        l       �        j        �       �        '         )        -        �                                +        O                Z                         �                       +                H        #                                        ;    !    6            !    �   "    *        �             7                    H       �    )           V        /        P       F        &                        8        _        �               M            &        =                &        X        	                         �                        ,        `                �            >        )    5       9    
    L    +    L        #    $7  MODULE NCFSRemoteFileDir;	(*NW 12.1.86 / 23.8.90 / OJ 5.7.99 / pjm*)

(* same as ARM.NCFSRemoteFileDir.Mod *)

IMPORT SYSTEM, Kernel, NCFSVolumes, FileDir := NCFSFileDir;

(*File Directory is a B-tree with its root page at DirRootAdr.
	Each entry contains a file name and the address of the file's head sector*)

CONST
	FnLength* = 32;
	BlkTabSize* = 64;
	ExTabSize* = 12;
	BlockSize* = NCFSVolumes.BS;	BS = BlockSize;
	IndexSize* = BS DIV 4;
	HeaderSize* = 352;	HS = HeaderSize;
	IdBlockAdr* = 1;
	DirRootAdr* = 2;
	DirPgSize* = 24;
	N = DirPgSize DIV 2;
	FillerSize = 52;
	RemoteMark* = 9B1CA589H;
	DirMark* = 9B1EA38DH;
	HeaderMark* = 9BA71D86H;

TYPE
	Address = NCFSVolumes.Address;
	FileName* = ARRAY FnLength OF CHAR;
	BlockTable* = ARRAY BlkTabSize OF Address;
	ExtensionTable* = ARRAY ExTabSize OF Address;

	FileHeader* = RECORD (NCFSVolumes.Block)	(*allocated in the first page of each file on volume*)
		mark*: LONGINT;
		name*: FileName;
		aleng*, bleng*: INTEGER;
		date*, time*: LONGINT;
		ext*: ExtensionTable;
		sec*: BlockTable;
		fill: ARRAY BS - HS OF CHAR;
	END;

	IndexBlock* = RECORD (NCFSVolumes.Block)
		x*: ARRAY IndexSize OF Address
	END;

	DataBlock* = RECORD (NCFSVolumes.Block)
		B*: ARRAY BS OF SYSTEM.BYTE
	END;

	DirEntry* = RECORD (*B-tree node*)
		name*: FileName;
		adr*: Address;	(*sec no of file header*)
		p*: Address	(*sec no of descendant in directory*)
	END;

	DirPage* = RECORD (NCFSVolumes.Block)
		mark*: LONGINT;
		m*: INTEGER;
		p0*: Address;	(*sec no of left descendant in directory*)
		fill: ARRAY FillerSize OF CHAR;
		e*: ARRAY DirPgSize OF DirEntry
	END;

	IdBlock* = RECORD (NCFSVolumes.Block)
		mark*: LONGINT;
		fill: ARRAY BS - 4 OF CHAR;
	END;
(*
	MapIndex = RECORD (NCFSVolumes.Block)
		mark: LONGINT;
		index: ARRAY MapIndexSize OF Address
	END;

	MapBlock = RECORD (NCFSVolumes.Block)
		map: ARRAY MapSize OF SET
	END;
*)

VAR
	pat: FileDir.FileName;
	pos: INTEGER;


(**--- Directory operations --------------------------------------------------*)

PROCEDURE Search*(fs: FileDir.Filesystem; VAR name: ARRAY OF CHAR; VAR A: Address);
VAR i, L, R: INTEGER; dadr: Address;
	a: DirPage;  vol: NCFSVolumes.Volume;
BEGIN
	vol := fs.vol;  dadr := DirRootAdr;
	LOOP
		vol.GetBlock(vol, dadr, a);
		IF (a.mark # DirMark) & (NCFSVolumes.writable IN vol.flags) THEN HALT(99) END;
		L := 0; R := a.m; (*binary search*)
		WHILE L < R DO
			i := (L+R) DIV 2;
			IF name <= a.e[i].name THEN R := i ELSE L := i+1 END
		END;
		IF (R < a.m) & (name = a.e[R].name) THEN
			A := a.e[R].adr; EXIT (*found*)
		END;
		IF R = 0 THEN dadr := a.p0 ELSE dadr := a.e[R-1].p END;
		IF dadr = 0 THEN A := 0; EXIT  (*not found*) END
	END;
END Search;

PROCEDURE insert(fs: FileDir.Filesystem;
								 VAR name: ARRAY OF CHAR;
								 dpg0:  Address;
								 VAR h: BOOLEAN;
								 VAR v: DirEntry;
								 fad:     Address);
(*h = "tree has become higher and v is ascending element"*)
VAR ch: CHAR;
	i, j, L, R: INTEGER;
	dpg1: Address;
	u: DirEntry;
	a: DirPage;
	vol: NCFSVolumes.Volume;

BEGIN (*~h*)
	vol := fs.vol;
	vol.GetBlock(vol, dpg0, a);
	L := 0; R := a.m; (*binary search*)
	WHILE L < R DO
		i := (L+R) DIV 2;
		IF name <= a.e[i].name THEN R := i ELSE L := i+1 END
	END;
	IF (R < a.m) & (name = a.e[R].name) THEN
		a.e[R].adr := fad; vol.PutBlock(vol, dpg0, a)  (*replace*)
	ELSE (*not on this page*)
		IF R = 0 THEN dpg1 := a.p0 ELSE dpg1 := a.e[R-1].p END;
		IF dpg1 = 0 THEN (*not in tree, insert*)
			u.adr := fad; u.p := 0; h := TRUE; j := 0;
			REPEAT ch := name[j]; u.name[j] := ch; INC(j)
			UNTIL ch = 0X;
			WHILE j < FnLength DO u.name[j] := 0X; INC(j) END
		ELSE
			insert(fs, name, dpg1, h, u, fad)
		END;
		IF h THEN (*insert u to the left of e[R]*)
			IF a.m < DirPgSize THEN
				h := FALSE; i := a.m;
				WHILE i > R DO DEC(i); a.e[i+1] := a.e[i] END;
				a.e[R] := u; INC(a.m)
			ELSE (*split page and assign the middle element to v*)
				a.m := N; a.mark := DirMark;
				IF R < N THEN (*insert in left half*)
					v := a.e[N-1]; i := N-1;
					WHILE i > R DO DEC(i); a.e[i+1] := a.e[i] END;
					a.e[R] := u; vol.PutBlock(vol, dpg0, a);
					vol.AllocBlock(vol, dpg0, dpg0); i := 0;
					WHILE i < N DO a.e[i] := a.e[i+N]; INC(i) END
				ELSE (*insert in right half*)
					vol.PutBlock(vol, dpg0, a);
					vol.AllocBlock(vol, dpg0, dpg0); DEC(R, N); i := 0;
					IF R = 0 THEN v := u
					ELSE v := a.e[N];
						WHILE i < R-1 DO a.e[i] := a.e[N+1+i]; INC(i) END;
						a.e[i] := u; INC(i)
					END;
					WHILE i < N DO a.e[i] := a.e[N+i]; INC(i) END
				END;
				a.p0 := v.p; v.p := dpg0
			END;
			vol.PutBlock(vol, dpg0, a)
		END
	END
END insert;

PROCEDURE Insert*(fs: FileDir.Filesystem; VAR name: ARRAY OF CHAR; fad: Address);
VAR  oldroot: Address;
	h: BOOLEAN; U: DirEntry;
	a: DirPage;
	vol: NCFSVolumes.Volume;
BEGIN
	h := FALSE;  vol := fs.vol;
	insert(fs, name, DirRootAdr, h, U, fad);
	IF h THEN (*root overflow*)
		vol.GetBlock(vol, DirRootAdr, a);
		vol.AllocBlock(vol, DirRootAdr, oldroot);
		vol.PutBlock(vol, oldroot, a);
		a.mark := DirMark; a.m := 1; a.p0 := oldroot; a.e[0] := U;
		vol.PutBlock(vol, DirRootAdr, a)
	END
END Insert;


PROCEDURE underflow(fs: FileDir.Filesystem; 
										VAR c: DirPage;  (*ancestor page*)
										dpg0:  Address;
										s:     INTEGER;  (*insertion point in c*)
										VAR h: BOOLEAN); (*c undersize*)
VAR i, k: INTEGER;
		dpg1: Address;
		a, b: DirPage;  (*a := underflowing page, b := neighbouring page*)
		vol: NCFSVolumes.Volume;
BEGIN
	vol := fs.vol;
	vol.GetBlock(vol, dpg0, a);
	(*h & a.m = N-1 & dpg0 = c.e[s-1].p*)
	IF s < c.m THEN (*b := page to the right of a*)
		dpg1 := c.e[s].p; vol.GetBlock(vol, dpg1, b);
		k := (b.m-N+1) DIV 2; (*k = no. of items available on page b*)
		a.e[N-1] := c.e[s]; a.e[N-1].p := b.p0;
		IF k > 0 THEN
			(*move k-1 items from b to a, one to c*) i := 0;
			WHILE i < k-1 DO a.e[i+N] := b.e[i]; INC(i) END;
			c.e[s] := b.e[i]; b.p0 := c.e[s].p;
			c.e[s].p := dpg1; DEC(b.m, k); i := 0;
			WHILE i < b.m DO b.e[i] := b.e[i+k]; INC(i) END;
			vol.PutBlock(vol, dpg1, b); a.m := N-1+k; h := FALSE
		ELSE (*merge pages a and b, discard b*) i := 0;
			WHILE i < N DO a.e[i+N] := b.e[i]; INC(i) END;
			i := s; DEC(c.m);
			WHILE i < c.m DO c.e[i] := c.e[i+1]; INC(i) END;
			a.m := 2*N; h := c.m < N
		END;
		vol.PutBlock(vol, dpg0, a)
	ELSE (*b := page to the left of a*) DEC(s);
		IF s = 0 THEN dpg1 := c.p0 ELSE dpg1 := c.e[s-1].p END;
		vol.GetBlock(vol, dpg1, b);
		k := (b.m-N+1) DIV 2; (*k = no. of items available on page b*)
		IF k > 0 THEN
			i := N-1;
			WHILE i > 0 DO DEC(i); a.e[i+k] := a.e[i] END;
			i := k-1; a.e[i] := c.e[s]; a.e[i].p := a.p0;
			(*move k-1 items from b to a, one to c*) DEC(b.m, k);
			WHILE i > 0 DO DEC(i); a.e[i] := b.e[i+b.m+1] END;
			c.e[s] := b.e[b.m]; a.p0 := c.e[s].p;
			c.e[s].p := dpg0; a.m := N-1+k; h := FALSE;
			vol.PutBlock(vol, dpg0, a)
		ELSE (*merge pages a and b, discard a*)
			c.e[s].p := a.p0; b.e[N] := c.e[s]; i := 0;
			WHILE i < N-1 DO b.e[i+N+1] := a.e[i]; INC(i) END;
			b.m := 2*N; DEC(c.m); h := c.m < N
		END;
		vol.PutBlock(vol, dpg1, b)
	END
END underflow;

PROCEDURE delete(fs: FileDir.Filesystem;
								 VAR name: ARRAY OF CHAR;
								 dpg0: Address;
								 VAR h: BOOLEAN;
								 VAR fad: Address);
(*search and delete entry with key name; if a page underflow arises,
	balance with adjacent page or merge; h := "page dpg0 is undersize"*)

VAR i, L, R: INTEGER;
	dpg1: Address;
	a: DirPage;
	vol: NCFSVolumes.Volume;

	PROCEDURE del(dpg1: Address; VAR h: BOOLEAN);
		VAR dpg2: Address;  (*global: a, R*)
				b: DirPage;
	BEGIN vol.GetBlock(vol, dpg1, b); dpg2 := b.e[b.m-1].p;
		IF dpg2 # 0 THEN del(dpg2, h);
			IF h THEN underflow(fs, b, dpg2, b.m, h); vol.PutBlock(vol, dpg1, b) END
		ELSE
			b.e[b.m-1].p := a.e[R].p; a.e[R] := b.e[b.m-1];
			DEC(b.m); h := b.m < N; vol.PutBlock(vol, dpg1, b)
		END
	END del;

BEGIN (*~h*)
	vol := fs.vol;
	vol.GetBlock(vol, dpg0, a);
	L := 0; R := a.m; (*binary search*)
	WHILE L < R DO
		i := (L+R) DIV 2;
		IF name <= a.e[i].name THEN R := i ELSE L := i+1 END
	END;
	IF R = 0 THEN dpg1 := a.p0 ELSE dpg1 := a.e[R-1].p END;
	IF (R < a.m) & (name = a.e[R].name) THEN
		(*found, now delete*) fad := a.e[R].adr;
		IF dpg1 = 0 THEN  (*a is a leaf page*)
			DEC(a.m); h := a.m < N; i := R;
			WHILE i < a.m DO a.e[i] := a.e[i+1]; INC(i) END
		ELSE del(dpg1, h);
			IF h THEN underflow(fs, a, dpg1, R, h) END
		END;
		vol.PutBlock(vol, dpg0, a)
	ELSIF dpg1 # 0 THEN
		delete(fs, name, dpg1, h, fad);
		IF h THEN underflow(fs, a, dpg1, R, h); vol.PutBlock(vol, dpg0, a) END
	ELSE (*not in tree*) fad := 0
	END
END delete;

PROCEDURE Delete*(fs: FileDir.Filesystem; VAR name: ARRAY OF CHAR; VAR fad: Address);
VAR h: BOOLEAN; newroot: Address;  a: DirPage;  vol: NCFSVolumes.Volume;
BEGIN
	vol := fs.vol;
	h := FALSE;
	delete(fs, name, DirRootAdr, h, fad);
	IF h THEN (*root underflow*)
		vol.GetBlock(vol, DirRootAdr, a);
		IF (a.m = 0) & (a.p0 # 0) THEN
			newroot := a.p0; vol.GetBlock(vol, newroot, a);
			vol.PutBlock(vol, DirRootAdr, a); (*discard newroot*)
		END
	END
END Delete;


PROCEDURE match(VAR name: ARRAY OF CHAR): BOOLEAN;
VAR i0, i1, j0, j1: INTEGER;  f: BOOLEAN;
BEGIN
	i0 := pos;  j0 := pos;  f := TRUE;
	LOOP
		IF pat[i0] = "*" THEN
			INC(i0);
			IF pat[i0] = 0X THEN EXIT END
		ELSE
			IF name[j0] # 0X THEN f := FALSE END;
			EXIT
		END;
		f := FALSE;
		LOOP
			IF name[j0] = 0X THEN EXIT END;
			i1 := i0;  j1 := j0;
			LOOP
				IF (pat[i1] = 0X) OR (pat[i1] = "*") THEN f := TRUE; EXIT END;
				IF pat[i1] # name[j1] THEN EXIT END;
				INC(i1);  INC(j1)
			END;
			IF f THEN j0 := j1; i0 := i1; EXIT END;
			INC(j0)
		END;
		IF ~f THEN EXIT END
	END;
	RETURN f & (name[0] # 0X)
END match;

PROCEDURE enumerate(fs: FileDir.Filesystem;
										VAR prefix: ARRAY OF CHAR;
										dpg: Address;
										detail: BOOLEAN;
										proc: FileDir.EntryHandler;
										VAR continue: BOOLEAN);
VAR
	i, j, diff: INTEGER; dpg1: Address;
	a: DirPage;  hp: FileHeader;
	vol: NCFSVolumes.Volume;
	fullname: FileDir.FileName;
BEGIN
	vol := fs.vol;
	vol.GetBlock(vol, dpg, a); i := 0;
	WHILE (i < a.m) & continue DO
		j := 0;
		LOOP
			IF prefix[j] = 0X THEN diff := 0; EXIT END;
			diff := ORD(a.e[i].name[j]) - ORD(prefix[j]);
			IF diff # 0 THEN EXIT END;
			INC(j)
		END;
		IF i = 0 THEN dpg1 := a.p0 ELSE dpg1 := a.e[i-1].p END;
		IF diff >= 0 THEN (*matching prefix*)
			IF dpg1 # 0 THEN enumerate(fs, prefix, dpg1, detail, proc, continue) END;
			IF diff = 0 THEN
				IF continue & ((pos = -1) OR match(a.e[i].name)) THEN
					FileDir.JoinName(vol.name, a.e[i].name, fullname);
					IF detail THEN
						vol.GetBlock(vol, a.e[i].adr, hp);
						proc(fullname, hp.time, hp.date, LONG(hp.aleng)*BS + hp.bleng - HS, continue)
					ELSE
						proc(fullname, 0,0,0, continue)
					END
				END
			ELSE continue := FALSE
			END
		END;
		INC(i)
	END;
	IF continue & (i > 0) & (a.e[i-1].p # 0) THEN
		enumerate(fs, prefix, a.e[i-1].p, detail, proc, continue)
	END
END enumerate;

PROCEDURE Enumerate*(fs: FileDir.Filesystem; prefix: ARRAY OF CHAR; detail: BOOLEAN; proc: FileDir.EntryHandler);
VAR b: BOOLEAN;
BEGIN
	COPY(prefix, pat);
	pos := 0;  WHILE (pat[pos] # 0X) & (pat[pos] # "*") DO INC(pos) END;
	IF pat[pos] # "*" THEN	(* no * found *)
		pos := -1
	ELSIF (pat[pos] = "*") & (pat[pos+1] = 0X) THEN	(* found * at end *)
		prefix[pos] := 0X;  pos := -1
	ELSE
		prefix[pos] := 0X
	END;
	b := TRUE; enumerate(fs, prefix, DirRootAdr, detail, proc, b)
END Enumerate;


PROCEDURE Init*(fs: FileDir.Filesystem);
VAR k: INTEGER;
		A: ARRAY 2000 OF Address;
		vol: NCFSVolumes.Volume;
		files: LONGINT;  bad: BOOLEAN;

	PROCEDURE MarkBlocks;
	VAR L, R, i, j, n: INTEGER; x: Address;
		hd: FileHeader;
		B: IndexBlock;

		PROCEDURE sift(L, R: INTEGER);
		VAR i, j: INTEGER; x: Address;
		BEGIN j := L; x := A[j];
			LOOP i := j; j := 2*j + 1;
				IF (j+1 < R) & (A[j] < A[j+1]) THEN INC(j) END;
				IF (j >= R) OR (x > A[j]) THEN EXIT END;
				A[i] := A[j]
			END;
			A[i] := x
		END sift;

	BEGIN
		L := k DIV 2; R := k; (*heapsort*)
		WHILE L > 0 DO DEC(L); sift(L, R) END;
		WHILE R > 0 DO
			DEC(R); x := A[0]; A[0] := A[R]; A[R] := x; sift(L, R)
		END;
		WHILE L < k DO
			bad := FALSE; INC(files);
			vol.GetBlock(vol, A[L], hd);
			IF hd.aleng < BlkTabSize THEN j := hd.aleng + 1;
				REPEAT DEC(j);
					IF hd.sec[j] # 0 THEN  vol.MarkBlock(vol, hd.sec[j]) ELSE hd.aleng := j-1; bad := TRUE END
				UNTIL j = 0
			ELSE j := BlkTabSize;
				REPEAT DEC(j);
					IF hd.sec[j] # 0 THEN vol.MarkBlock(vol, hd.sec[j]) ELSE hd.aleng := j-1; bad := TRUE END
				UNTIL j = 0;
				n := (hd.aleng - BlkTabSize) DIV IndexSize; i := 0;
				WHILE (i <= n) & ~bad DO
					IF hd.ext[i] # 0 THEN
						vol.MarkBlock(vol, hd.ext[i]);
						vol.GetBlock(vol, hd.ext[i], B); (*index sector*)
						IF i < n THEN j := IndexSize ELSE j := (hd.aleng - BlkTabSize) MOD IndexSize + 1 END;
						REPEAT DEC(j);
							IF B.x[j] > 0 THEN vol.MarkBlock(vol, B.x[j]) ELSE j := 0; bad := TRUE END
						UNTIL j = 0;
						INC(i)
					ELSE bad := TRUE
					END;
					IF bad THEN
						IF i = 0 THEN hd.aleng := BlkTabSize-1 ELSE hd.aleng := BlkTabSize + (i-1) * IndexSize END
					END
				END
			END;
			IF bad THEN
				Kernel.WriteLn(); Kernel.WriteString(hd.name); Kernel.WriteString(" truncated");
				hd.bleng := BS;  IF hd.aleng < 0 THEN hd.aleng := 0 (* really bad *) END;
				vol.PutBlock(vol, A[L], hd)
			END;
			INC(L)
		END
	END MarkBlocks;

	PROCEDURE TraverseDir(dpg: Address);
	VAR i: INTEGER; a: DirPage;
	BEGIN
		vol.GetBlock(vol, dpg, a);
		vol.MarkBlock(vol, dpg); i := 0;
		WHILE i < a.m DO
			A[k] := a.e[i].adr; INC(k); INC(i);
			IF k = 2000 THEN MarkBlocks; k := 0 END
		END;
		IF a.p0 # 0 THEN
			TraverseDir(a.p0); i := 0;
			WHILE i < a.m DO
				TraverseDir(a.e[i].p); INC(i)
			END
		END
	END TraverseDir;

BEGIN
	vol := fs.vol;
	IF NCFSVolumes.writable IN vol.flags THEN
		k := 0;  files := 0;
		Kernel.WriteString("Scanning ");  Kernel.WriteString("...");
		TraverseDir(DirRootAdr); MarkBlocks();
		Kernel.WriteInt(files, 6); Kernel.WriteString(" files");  Kernel.WriteLn()
	END
END Init;


END NCFSRemoteFileDir.
