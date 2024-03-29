�TextDocs.NewDoc     �� �F   CColor    Flat  Locked  Controls  Org �   �BIER`   b        �3 � [   Oberon10.Scn.Fnt  d         �        �       5       �   �  MODULE NCFSFileDir;   (* OJ 28.6.99 *)

(* same as ARM.FileDir.Mod *)

IMPORT SYSTEM, NCFSVolumes;

 CONST
	RFnLength* = 128;	(** Max. length of a relative filename *)
	FnLength* = NCFSVolumes.VnLength + RFnLength;	(** Max. length of an absolute filename *)

TYPE
	FileName* = ARRAY FnLength OF CHAR;	(** Absolute filename = ( volname ":" filename ) . *)

	EntryHandler* = PROCEDURE (name: ARRAY OF CHAR; time, date, size: LONGINT; VAR continue: BOOLEAN);

	Filesystem* = POINTER TO FilesystemDesc;
	File* = POINTER TO FileDesc;

	RiderExt* = POINTER TO RiderExtDesc;
	RiderExtDesc* = RECORD  END;

	Rid* = RECORD  END;	(** Workaround for a ARMCompiler-Bug *)
	Rider* = RECORD (Rid)
		file*: File;
		apos*, bpos*: INTEGER;
		buf*: RiderExt;		(** Inner state of rider *)

		eof*: BOOLEAN;		(** End of file, true if last access of rider has failed *)
		res*: LONGINT;		(** Some operations set a result code *)

		Pos*: PROCEDURE (VAR r: Rid): LONGINT;
		Read*: PROCEDURE (VAR r: Rid; VAR x: SYSTEM.BYTE);
		Write*: PROCEDURE (VAR r: Rid; x: SYSTEM.BYTE);
		ReadBytes*: PROCEDURE (VAR r: Rid; VAR x: ARRAY OF SYSTEM.BYTE; n: LONGINT);
		WriteBytes*: PROCEDURE (VAR r: Rid; VAR x: ARRAY OF SYSTEM.BYTE; n: LONGINT);
	END;

	FileDesc* = RECORD
		next*[UNTRACED]: File;
		name*: ARRAY RFnLength OF CHAR;	(* Relative filename *)
		registered*: BOOLEAN;
		fs*: Filesystem;		(* Filesystem of this file *)

		Set*: PROCEDURE (VAR r: Rider; f: File; pos: LONGINT);		(* Rider generation *)
	END;

	FilesystemDesc* = RECORD  (NCFSVolumes.ContentDesc)
		next: Filesystem;

		New*: PROCEDURE (fs: Filesystem; name: ARRAY OF CHAR): File;
		Old*: PROCEDURE (fs: Filesystem; name: ARRAY OF CHAR): File;
		Delete*: PROCEDURE (fs: Filesystem; name: ARRAY OF CHAR; VAR res: INTEGER);
		Rename*: PROCEDURE (fs: Filesystem; old, new: ARRAY OF CHAR; VAR res: INTEGER);
		Enumerate*: PROCEDURE (fs: Filesystem; prefix: ARRAY OF CHAR; detail: BOOLEAN; proc: EntryHandler);

		Close*: PROCEDURE (f: File);
		Register*: PROCEDURE (f: File);
		Length*: PROCEDURE (f: File): LONGINT;
		GetDate*: PROCEDURE (f: File; VAR t, d: LONGINT);
		SetDate*: PROCEDURE (f: File; t, d: LONGINT);
		GetName*: PROCEDURE (f: File; VAR name: ARRAY OF CHAR);
	END;

VAR
	path: Filesystem;		(* first filesystem in search path *)
	PathChar*: CHAR;	(** for compatibility *)


(**--- Filesystems ----------------------------------------------------*)

(** Set fs to first/default file system. *)
PROCEDURE SetDefault*(fs: Filesystem);
VAR p: Filesystem;
BEGIN
	IF fs.vol # NIL THEN
		IF fs # path THEN
			p := path;
			WHILE (p # NIL) & (p.next # fs) DO  p := p.next  END;
			IF p # NIL THEN  p.next := fs.next  END;
			fs.next := path;  path := fs
		END
	END
END SetDefault;


(** Remove filessystem from system *)
PROCEDURE Finalize*(fs: NCFSVolumes.Content);
VAR p: Filesystem;
BEGIN
	IF (fs # NIL) & (fs IS Filesystem) THEN
		WITH fs: Filesystem DO
			fs.vol := NIL;
			IF fs = path THEN
				path := fs.next
			ELSE
				p := path;
				WHILE (p # NIL) & (p.next # fs) DO  p := p.next  END;
				IF p # NIL THEN  p.next := fs.next  END
			END
		END
	END
END Finalize;


(** Get first filesystem of search path (NIL if none) *)
PROCEDURE FirstOfPath*(): Filesystem;
BEGIN
	RETURN path
END FirstOfPath;

(** Step to next filesystem of search path (NIL at the end) *)
PROCEDURE StepPath*(VAR fs: Filesystem);
BEGIN
	fs := fs.next
END StepPath;


(**--- Files with fullnames ----------------------------------------------*)

(** Split fullname = ( vname ":" fname ) into vname and fname *)
PROCEDURE SplitName*(fullname: ARRAY OF CHAR; VAR vname, fname: ARRAY OF CHAR);
VAR i, j: INTEGER;
BEGIN
	i := 0;  WHILE (fullname[i] # ":") & (fullname[i] # 0X) DO  INC(i)  END;
	IF fullname[i] # ":"  THEN
		COPY("", vname);  COPY(fullname, fname);
	ELSE
		fullname[i] := 0X;  COPY(fullname, vname);
		j := 0;  REPEAT  INC(i);  fname[j] := fullname[i];  INC(j)  UNTIL fullname[i] = 0X
	END
END SplitName;


(** Join vname and fname to fullname = ( vname ":" fname ) *)
PROCEDURE JoinName*(vname, fname: ARRAY OF CHAR; VAR fullname: ARRAY OF CHAR);
VAR i, j: INTEGER;
BEGIN
	i := 0;  WHILE vname[i] # 0X DO  fullname[i] := vname[i];  INC(i)  END;
	fullname[i] := ":";  INC(i);
	j := 0;  WHILE fname[j] # 0X DO fullname[i] := fname[j];  INC(i);  INC(j)  END;
	fullname[i] := 0X
END JoinName;


(** Enumerates files matching fullprefix *)
PROCEDURE Enumerate*(VAR fullprefix: ARRAY OF CHAR; detail: BOOLEAN; proc: EntryHandler);
VAR vol: NCFSVolumes.Volume;  fs: Filesystem;  vname: NCFSVolumes.VolName;  prefix: ARRAY FnLength OF CHAR;
BEGIN
	SplitName(fullprefix, vname, prefix);
	IF vname = "" THEN
		fs := FirstOfPath();
		WHILE fs # NIL DO
			fs.Enumerate(fs, prefix, detail, proc);
			StepPath(fs)
		END
	ELSE
		vol := NCFSVolumes.This(vname);
		IF (vol # NIL) & (vol.content # NIL) & (vol.content IS Filesystem) THEN
			fs := vol.content(Filesystem);
			IF fs # NIL THEN  fs.Enumerate(fs, prefix, detail, proc)  END
		END
	END
END Enumerate;


BEGIN
	path := NIL;  PathChar := 0X;
END NCFSFileDir.
�BIER�  �   �    4   �� �     d	   # / ; G S _ (    d
 ��    ��C  TextGadgets.NewStyleProc  �