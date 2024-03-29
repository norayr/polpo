�TextDocs.NewDoc     �l�F   CColor    Flat  Locked  Controls  Org A'   �BIER`   b        �3 �#   Oberon10.Scn.Fnt  �)   �)  MODULE NCFSFiles;   (* OJ 28.6.99 *)

(* same as ARM.Files.Mod *)

IMPORT SYSTEM, Kernel, NCFSVolumes, FileDir := NCFSFileDir;

CONST
	Trace = FALSE;
	
TYPE
	File* = FileDir.File;
	Rider* = FileDir.Rider;
		
	Bytes4 = ARRAY 4 OF SYSTEM.BYTE;
	Bytes8 = ARRAY 8 OF SYSTEM.BYTE;

VAR root: File;	(* list of registered open files with dummy first node *)

(**--- Filesystem operations ----------------------------------------------------------------*)

PROCEDURE ShowList;
VAR f: File;
BEGIN
	IF Trace THEN
		f := root.next;
		WHILE f # NIL DO
			Kernel.WriteHex(SYSTEM.VAL(LONGINT, f), 8);
			Kernel.WriteChar(" "); Kernel.WriteString(f.name);  Kernel.WriteLn;
			f := f.next
		END
	END
END ShowList;

PROCEDURE Remove(fs: FileDir.Filesystem;  VAR fname: ARRAY OF CHAR);
VAR prev, cur: File;
BEGIN
	IF Trace THEN Kernel.WriteString(fname) END;
	prev := root;  cur := root.next;
	WHILE cur # NIL DO
		IF (cur.fs = fs) & (cur.name = fname) THEN
			IF Trace THEN Kernel.WriteString(" removed") END;
			prev.next := cur.next
		ELSE
			prev := cur
		END;
		cur := cur.next
	END;
	IF Trace THEN Kernel.WriteLn; ShowList END
END Remove;

(* Remove file handle from list of open files *)
PROCEDURE Cleanup(f: SYSTEM.PTR);
BEGIN
	WITH f: File DO
		IF Trace THEN Kernel.WriteString("Cleanup: ") END;
		Remove(f.fs, f.name)
	END
END Cleanup;

(* Return file handle of most recent or just opened file (NIL if not found) *)
PROCEDURE Open(fs: FileDir.Filesystem; fname: ARRAY OF CHAR): File;
VAR f: File;
BEGIN
	IF fname = "" THEN  f := NIL
	ELSE
		IF Trace THEN Kernel.WriteString("Open: "); Kernel.WriteString(fname) END;
		f := root.next;
		WHILE (f # NIL) & ((f.fs # fs) OR (f.name # fname)) DO  f := f.next  END;
		IF f = NIL THEN
			f := fs.Old(fs, fname);
			IF f # NIL THEN
				IF Trace THEN Kernel.WriteString(" added") END;
				f.next := root.next;  root.next := f;
				Kernel.RegisterObject(f, Cleanup, FALSE)
			ELSE
				IF Trace THEN Kernel.WriteString(" not found") END
			END
		ELSE
			IF Trace THEN Kernel.WriteString(" found") END
		END;
		IF Trace THEN Kernel.WriteLn; ShowList END
	END;
	RETURN f
END Open;

(** Open an existing file with given fullname *)
PROCEDURE Old*(fullname: ARRAY OF CHAR): File;
VAR
	vol: NCFSVolumes.Volume;  fs: FileDir.Filesystem;  f: File;
	vname: NCFSVolumes.VolName;  fname: ARRAY FileDir.RFnLength OF CHAR;
BEGIN
	f := NIL;
	FileDir.SplitName(fullname, vname, fname);
	IF vname = "" THEN
		fs := FileDir.FirstOfPath();
		WHILE (fs # NIL) & (f = NIL) DO
			f := Open(fs, fname);
			FileDir.StepPath(fs)
		END
	ELSE
		vol := NCFSVolumes.This(vname);
		IF (vol # NIL) & (vol.content # NIL) & (vol.content IS FileDir.Filesystem) THEN
			fs := vol.content(FileDir.Filesystem);
			f := Open(fs, fname);
		END
	END;
	RETURN f
END Old;

(** Create a new file with given fullname in corresponding filesystem *)
PROCEDURE New*(fullname: ARRAY OF CHAR): File;
VAR
	vol: NCFSVolumes.Volume;  fs: FileDir.Filesystem;  f: File;
	vname: NCFSVolumes.VolName;  fname: ARRAY FileDir.RFnLength OF CHAR;
BEGIN
	fs := NIL;
	FileDir.SplitName(fullname, vname, fname);
	IF vname = "" THEN
		fs := FileDir.FirstOfPath();
	ELSE
		vol := NCFSVolumes.This(vname);
		IF (vol # NIL) & (vol.content # NIL) & (vol.content IS FileDir.Filesystem) THEN
			fs := vol.content(FileDir.Filesystem)
		END
	END;
	IF fs = NIL THEN
		f := NIL
	ELSE
		f := fs.New(fs, fname)
	END;
	RETURN f
END New;

(** Delete a file. res = 0 indicates success. *)
PROCEDURE Delete*(fullname: ARRAY OF CHAR; VAR res: INTEGER);
VAR
	vol: NCFSVolumes.Volume;  fs: FileDir.Filesystem;  vname: NCFSVolumes.VolName;
	fname: ARRAY FileDir.RFnLength OF CHAR;
BEGIN
	fs := NIL; res := -1;
	FileDir.SplitName(fullname, vname, fname);
	IF vname = "" THEN
		fs := FileDir.FirstOfPath();
	ELSE
		vol := NCFSVolumes.This(vname);
		IF (vol # NIL) & (vol.content # NIL) & (vol.content IS FileDir.Filesystem) THEN
			fs := vol.content(FileDir.Filesystem)
		END
	END;
	IF fs = NIL THEN
		res := 2
	ELSE
		IF Trace THEN Kernel.WriteString("Delete: ") END;
		Remove(fs, fname);
		fs.Delete(fs, fname, res)
	END
END Delete;

(** Rename a file. res = 0 indicates success. *)
PROCEDURE Rename*(old, new: ARRAY OF CHAR; VAR res: INTEGER);
VAR
	vol: NCFSVolumes.Volume;  fs: FileDir.Filesystem;  f: File;
	vold, vnew: NCFSVolumes.VolName;  fold, fnew: ARRAY FileDir.RFnLength OF CHAR;
BEGIN
	fs := NIL; res := -1;
	FileDir.SplitName(old, vold, fold);
	FileDir.SplitName(new, vnew, fnew);
	IF vnew = vold THEN
		IF vold = "" THEN
			fs := FileDir.FirstOfPath();
		ELSE
			vol := NCFSVolumes.This(vold);
			IF (vol # NIL) & (vol.content # NIL) & (vol.content IS FileDir.Filesystem) THEN
				fs := vol.content(FileDir.Filesystem)
			END
		END
	END;
	IF fs = NIL THEN
		res := 2
	ELSE
		f := root.next;
		WHILE f # NIL DO
			IF (f.fs = fs) & (f.name = fold) THEN
				IF Trace THEN
					Kernel.WriteString("Rename: "); Kernel.WriteString(fold);
					Kernel.WriteString(" -> "); Kernel.WriteString(fnew); Kernel.WriteLn
				END;
				COPY(fnew, f.name)
			END;
			f := f.next
		END;
		IF Trace THEN ShowList END;
		fs.Rename(fs, fold, fnew, res)
	END
END Rename;

(**--- File operations -----------------------------------------------*)

(** Register a file created with New in the directory, replacing the previous file in the 
directory with the same name. The file is automatically closed. *)
PROCEDURE Register*(f: File);
BEGIN
	IF f # NIL THEN
		IF ~f.registered & (f.name # "") THEN
			IF Trace THEN Kernel.WriteString("Register: ") END;
			Remove(f.fs, f.name);
			f.next := root.next;  root.next := f;
			Kernel.RegisterObject(f, Cleanup, FALSE)
		END;
		IF Trace THEN ShowList END;
		f.fs.Register(f)
	END;
END Register;

(** Flushes the changes made to a file. Register will automatically close a file. *)
PROCEDURE Close*(f: File);
BEGIN
	IF f # NIL THEN  f.fs.Close(f)  END
END Close;

(** Returns the current length of a file. *)
PROCEDURE Length*(f: File): LONGINT;
BEGIN  RETURN f.fs.Length(f)
END Length;

(** Returns the time (t) and date (d) when a file was last modified. *)
PROCEDURE GetDate*(f: File; VAR t, d: LONGINT);
BEGIN  f.fs.GetDate(f, t,d)
END GetDate;

(** Sets the modification time (t) and date (d) of a file. *)
PROCEDURE SetDate*(f: File; t, d: LONGINT);
BEGIN  f.fs.SetDate(f, t,d)
END SetDate;

(** Returns the full name of a file. *)
PROCEDURE GetName*(f: File; VAR fullname: ARRAY OF CHAR);
VAR fname: ARRAY FileDir.RFnLength OF CHAR;
BEGIN
	f.fs.GetName(f, fname);
	FileDir.JoinName(f.fs.vol.name, fname, fullname)
END GetName;

(**--- Rider operations --------------------------------------------------*)

(** Set a rider to a certain position in a file *)
PROCEDURE Set*(VAR r: Rider; f: File; pos: LONGINT);
BEGIN
	r.eof := FALSE; r.res := 0;
	IF f # NIL THEN  f.Set(r, f, pos)
	ELSE r.file:= NIL
	END
END Set;

(** Return the position of the rider within its file *)
PROCEDURE Pos*(VAR r: Rider): LONGINT;
BEGIN  RETURN r.Pos(r)
END Pos;

(** Return the file the rider is based on *)
PROCEDURE Base*(VAR r: Rider): File;
BEGIN
	RETURN r.file
END Base;

(** Read a byte from a file, advancing the Rider one byte further.  R.eof indicates if the end 
of the file has been passed. *)
PROCEDURE Read*(VAR r: Rider; VAR x: SYSTEM.BYTE);
BEGIN
	r.Read(r, x)
END Read;

(** Reads a sequence of length n bytes into the buffer x, advancing the Rider. Less bytes 
will be read when reading over the length of the file. r.res indicates the number of unread bytes. 
x must be big enough to hold n bytes. *)
PROCEDURE ReadBytes*(VAR r: Rider; VAR x: ARRAY OF SYSTEM.BYTE; n: LONGINT);
BEGIN
	r.ReadBytes(r, x, n)
END ReadBytes;

(** Writes a byte into the file at the Rider position, advancing the Rider by one. *)
PROCEDURE Write*(VAR r: Rider; x: SYSTEM.BYTE);
BEGIN
	r.Write(r, x)
END Write;

(** Writes the buffer x containing n bytes into a file at the Rider position. *)
PROCEDURE WriteBytes*(VAR r: Rider; VAR x: ARRAY OF SYSTEM.BYTE; n: LONGINT);
BEGIN
	r.WriteBytes(r, x, n)
END WriteBytes;

(**--- Portable routines to read the standard Oberon types. ---*)

PROCEDURE ReadInt*(VAR r: Rider; VAR x: INTEGER);
VAR x0, x1: SHORTINT;
BEGIN
	r.Read(r, x0); r.Read(r, x1);
	x := LONG(x1) * 100H + LONG(x0) MOD 100H
END ReadInt;

PROCEDURE ReadLInt*(VAR r: Rider; VAR x: LONGINT);
BEGIN
	ReadBytes(r, SYSTEM.VAL(Bytes4, x), 4)
END ReadLInt;

PROCEDURE ReadSet*(VAR r: Rider; VAR x: SET);
BEGIN
	ReadBytes(r, SYSTEM.VAL(Bytes4, x), 4)
END ReadSet;

PROCEDURE ReadBool*(VAR r: Rider; VAR x: BOOLEAN);
VAR s: SHORTINT;
BEGIN
	r.Read(r, s); x := s # 0
END ReadBool;

PROCEDURE ReadReal*(VAR r: Rider; VAR x: REAL);
BEGIN
	ReadBytes(r, SYSTEM.VAL(Bytes4, x), 4)
END ReadReal;

PROCEDURE ReadLReal*(VAR r: Rider; VAR x: LONGREAL);
BEGIN
	ReadBytes(r, SYSTEM.VAL(Bytes8, x), 8)
END ReadLReal;

PROCEDURE ReadString*(VAR r: Rider; VAR x: ARRAY OF CHAR);
VAR i: INTEGER; ch: CHAR;
BEGIN i := 0;
	LOOP
		r.Read(r, ch); x[i] := ch; INC(i);
		IF ch = 0X THEN EXIT END;
		IF i = LEN(x) THEN x[i-1] := 0X;
			REPEAT r.Read(r, ch) UNTIL ch = 0X;
			EXIT
		END
	END
END ReadString;

(** Reads a number in compressed variable length notation using the minimum amount of bytes. *)
PROCEDURE ReadNum*(VAR r: Rider; VAR x: LONGINT);
VAR ch: CHAR; n: INTEGER; y: LONGINT;
BEGIN
	n := 0; y := 0; r.Read(r, ch);
	WHILE ch >= 80X DO INC(y, SYSTEM.LSH(LONG(ch) - 128, n)); INC(n, 7); r.Read(r, ch) END;
	x := ASH(SYSTEM.LSH(LONG(ch), 25), n-25) + y
END ReadNum;

(**--- Portable routines to write the standard Oberon types. ---*)

PROCEDURE WriteInt*(VAR r: Rider; x: INTEGER);
BEGIN
	r.Write(r, SHORT(x)); r.Write(r, SHORT(x DIV 100H))
END WriteInt;

PROCEDURE WriteLInt*(VAR r: Rider; x: LONGINT);
BEGIN
	WriteBytes(r, SYSTEM.VAL(Bytes4, x), 4)
END WriteLInt;

PROCEDURE WriteSet*(VAR r: Rider; x: SET);
BEGIN
	WriteBytes(r, SYSTEM.VAL(Bytes4, x), 4)
END WriteSet;

PROCEDURE WriteBool*(VAR r: Rider; x: BOOLEAN);
BEGIN
	IF x THEN r.Write(r, 1) ELSE r.Write(r, 0) END
END WriteBool;

PROCEDURE WriteReal*(VAR r: Rider; x: REAL);
BEGIN
	WriteBytes(r, SYSTEM.VAL(Bytes4, x), 4)
END WriteReal;

PROCEDURE WriteLReal*(VAR r: Rider; x: LONGREAL);
BEGIN
	WriteBytes(r, SYSTEM.VAL(Bytes8, x), 8)
END WriteLReal;

PROCEDURE WriteString*(VAR r: Rider; x: ARRAY OF CHAR);
VAR i: INTEGER; ch: CHAR;
BEGIN
	i := 0;
	LOOP ch := x[i]; r.Write(r, ch); INC(i);
		IF ch = 0X THEN EXIT END;
		IF i = LEN(x) THEN r.Write(r, 0X); EXIT END
	END
END WriteString;

(** Writes a number in a compressed format. *)
PROCEDURE WriteNum*(VAR r: Rider; x: LONGINT);
BEGIN
	WHILE (x < - 64) OR (x > 63) DO r.Write(r, CHR(x MOD 128 + 128)); x := x DIV 128 END;
	r.Write(r, CHR(x MOD 128))
END WriteNum;

BEGIN
	NEW(root);  root.next := NIL
END NCFSFiles.
