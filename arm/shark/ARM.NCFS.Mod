�TextDocs.NewDoc     �a�#   Oberon10.Scn.Fnt  l   l  MODULE NCFS;

IMPORT NCFSVolumes, FileDir, Files, Modules, Texts, Oberon, Display, TextFrames, NetSystem;

CONST
	GenVol = "NCFSNetVolumes.New";

VAR
	S: Texts.Scanner;
	T: Texts.Text;
	W: Texts.Writer;
	res: INTEGER;
	count, total: LONGINT;


(**--- Volume management ------------------------------------------*)

PROCEDURE showPath();
VAR fs: FileDir.Filesystem;
BEGIN
	fs := FileDir.FirstOfPath();
	IF fs # NIL THEN
		Texts.WriteString(W, "Search path is ");
		WHILE fs # NIL DO
			Texts.WriteString(W, fs.vol.name);
			FileDir.StepPath(fs);
			IF fs # NIL THEN  Texts.WriteString(W, " -> ")  END
		END;
		Texts.WriteLn(W)
	END
END showPath;

PROCEDURE CreateVolume(volName, genCmd, Par: ARRAY OF CHAR; VAR ok: BOOLEAN);
VAR vol: NCFSVolumes.Volume; ch: CHAR;
BEGIN
	ok := FALSE;
	Texts.WriteString(W, volName); Texts.Write(W, " "); Texts.Append(Oberon.Log, W.buf);
	IF NCFSVolumes.This(volName) # NIL THEN
		Texts.WriteString(W, "already exists")
	ELSE
		NCFSVolumes.SetPar(Par);
		Oberon.Call(genCmd, Oberon.Par, FALSE, res);
		IF res # 0 THEN
			Texts.WriteString(W, Modules.resMsg)
		ELSIF NCFSVolumes.NewVol = NIL THEN
			NCFSVolumes.ReadPar(ch);
			IF ch # 0X THEN
				REPEAT Texts.Write(W, ch); NCFSVolumes.ReadPar(ch) UNTIL ch = 0X
			ELSE
				Texts.WriteString(W, "Cannot create volume")
			END
		ELSE
			vol := NCFSVolumes.NewVol;
			NCFSVolumes.Mount(vol, volName, res);
			IF ~(NCFSVolumes.writable IN vol.flags) THEN
				Texts.WriteString(W, "(read-only) ")
			ELSIF vol.content = NIL THEN
				Texts.WriteString(W, "(unformatted) ")
			END;
			IF res # NCFSVolumes.done THEN
				Texts.WriteString(W, "mounting failed")
			ELSE
				IF (vol.content # NIL) & (vol.content IS FileDir.Filesystem) THEN
					FileDir.SetDefault(vol.content(FileDir.Filesystem))
				END;
				Texts.WriteString(W, "volume mounted");
				ok := TRUE
			END
		END
	END;
	Texts.WriteLn(W);
	Texts.Append(Oberon.Log, W.buf)
END CreateVolume;


PROCEDURE RemoveVolume(volName: ARRAY OF CHAR);
VAR vol: NCFSVolumes.Volume;
BEGIN
	Texts.WriteString(W, volName);
	vol := NCFSVolumes.This(volName);
	IF vol = NIL THEN
		Texts.WriteString(W, " not found")
	ELSE
		NCFSVolumes.Unmount(vol);
		Texts.WriteString(W, " volume unmounted")
	END;
	Texts.WriteLn(W);  Texts.Append(Oberon.Log, W.buf)
END RemoveVolume;


PROCEDURE FormatVolume(volName, fmtCmd: ARRAY OF CHAR);
VAR vol: NCFSVolumes.Volume;  res: INTEGER;  wasCurrent: BOOLEAN;
BEGIN
	Texts.WriteString(W, volName); Texts.Write(W, " ");
	Texts.Append(Oberon.Log, W.buf);
	vol := NCFSVolumes.This(volName);
	IF vol = NIL THEN
		Texts.WriteString(W, "not found")
	ELSE
		wasCurrent := (vol.content # NIL) & (vol.content = FileDir.FirstOfPath());
		NCFSVolumes.FmtVol := vol;
		Oberon.Call(fmtCmd, Oberon.Par, FALSE, res);
		IF res # 0 THEN
			Texts.WriteString(W, Modules.resMsg)
		ELSE
			IF wasCurrent & (vol.content # NIL) & (vol.content IS FileDir.Filesystem) THEN
				FileDir.SetDefault(vol.content(FileDir.Filesystem))
			END;
			Texts.WriteString(W, "formatted")
		END
	END;
	Texts.WriteLn(W);  Texts.Append(Oberon.Log, W.buf)
END FormatVolume;


(**--- Filesystem control ---------------------------------------------*)

PROCEDURE SetCurFS(volName: ARRAY OF CHAR);
VAR vol: NCFSVolumes.Volume;
BEGIN
	Texts.WriteString(W, volName);
	vol := NCFSVolumes.This(volName);
	IF vol = NIL THEN
		Texts.WriteString(W, " not found")
	ELSE
		IF (vol.content = NIL) OR ~(vol.content IS FileDir.Filesystem) THEN
			Texts.WriteString(W, " has no filesystem")
		ELSE
			FileDir.SetDefault(vol.content(FileDir.Filesystem));
			Texts.WriteString(W, " set as default")
		END
	END;
	Texts.WriteLn(W);
	showPath();
	Texts.Append(Oberon.Log, W.buf)
END SetCurFS;


(**--- Commands ---------------------------------------------*)

PROCEDURE showVol(vol: NCFSVolumes.Volume);
BEGIN
	Texts.WriteString(W, vol.name);  Texts.WriteString(W, ": ");
	IF ~(NCFSVolumes.writable IN vol.flags) THEN
		Texts.WriteInt(W, vol.size*NCFSVolumes.BS DIV 1024, 1);  Texts.WriteString(W, "K (read-only)")
	ELSIF vol.content = NIL THEN
		Texts.WriteInt(W, vol.size*NCFSVolumes.BS DIV 1024, 1);  Texts.WriteString(W, "K (unformatted)")
	ELSE
		Texts.WriteInt(W, vol.Available(vol)*NCFSVolumes.BS DIV 1024, 1);  Texts.WriteString(W, "K of ");
		Texts.WriteInt(W, vol.size*NCFSVolumes.BS DIV 1024, 1);  Texts.WriteString(W, "K free");
	END;
	Texts.WriteString(W, " on "); Texts.WriteString(W, vol.desc); Texts.WriteLn(W)
END showVol;

PROCEDURE Watch*;
BEGIN
	Texts.WriteString(W, "NCFS.Watch");  Texts.WriteLn(W);
	NCFSVolumes.Enumerate(showVol);
	showPath();
	Texts.Append(Oberon.Log, W.buf)
END Watch;

PROCEDURE StartScan(VAR S: Texts.Scanner);
VAR beg, end, time: LONGINT;
BEGIN
	Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos);
	Texts.Scan(S);
	IF (S.class = Texts.Char) & (S.c = "^") OR (S.line # 0) THEN
		Oberon.GetSelection(T, beg, end, time);
		IF time >= 0 THEN Texts.OpenScanner(S, T, beg); Texts.Scan(S) END
	END;
END StartScan;

(* Read and split URL parameter of the form ( "ncfs://" [ user "@" ] server "/" [fname] ) . *)
PROCEDURE ReadURL(VAR user, server, fname: ARRAY OF CHAR);
VAR service: ARRAY 8 OF CHAR; i: LONGINT;
BEGIN
	user[0] := 0X; server[0] := 0X; fname[0] := 0X;
	WHILE S.nextCh = " " DO Texts.Read(S, S.nextCh) END;
	i := 0;
	WHILE (S.nextCh > " ") & (i # 7) DO
		service[i] := S.nextCh;  INC(i);
		Texts.Read(S, S.nextCh)
	END;
	service[i] := 0X;
	IF service = "ncfs://" THEN
		i := 0;
		WHILE (S.nextCh > " ") & (S.nextCh # "@") & (S.nextCh # "/") DO
			user[i] := S.nextCh; server[i] := S.nextCh; INC(i);
			Texts.Read(S, S.nextCh)
		END;
		user[i] := 0X; server[i] := 0X;
		IF S.nextCh = "@" THEN
			Texts.Read(S, S.nextCh); i := 0;
			WHILE (S.nextCh > " ") & (S.nextCh # "/") DO
				server[i] := S.nextCh; INC(i);
				Texts.Read(S, S.nextCh)
			END;
			server[i] := 0X
		ELSE
			user[0] := 0X
		END;
		IF S.nextCh = "/" THEN
			Texts.Read(S, S.nextCh);
			i := 0;
			WHILE (S.nextCh > " ") & (S.nextCh # "~") DO
				fname[i] := S.nextCh; INC(i);
				Texts.Read(S, S.nextCh)
			END;
			fname[i] := 0X
		END
	END
END ReadURL;

PROCEDURE AppendStr(from: ARRAY OF CHAR;  VAR to: ARRAY OF CHAR);
VAR i, j, m: LONGINT;
BEGIN
	j := 0;  WHILE to[j] # 0X DO INC(j) END;
	m := LEN(to)-1;
	i := 0;  WHILE (from[i] # 0X) & (j # m) DO to[j] := from[i];  INC(i);  INC(j) END;
	to[j] := 0X
END AppendStr;

PROCEDURE Mount*;	(** vol url *)
VAR
	volName, usr, pwd, server, fname: ARRAY 64 OF CHAR; par: ARRAY 256 OF CHAR; ok: BOOLEAN;
BEGIN
	StartScan(S);
	IF S.class = Texts.Name THEN  COPY(S.s, volName);
		ReadURL(usr, server, fname);
		IF server[0] # 0X THEN
			NetSystem.GetPassword("ncfs", server, usr, pwd); (* if usr = "", get first pwd *)
			COPY(usr, par); AppendStr(" ", par);
			AppendStr(pwd, par); AppendStr(" ", par);
			AppendStr(server, par); AppendStr(" ", par);
			AppendStr(fname, par);
			CreateVolume(volName, GenVol, par, ok);
			IF ok THEN Watch END
		ELSE
			Texts.WriteString(W, "usage: Mount volName 'ncfs://' [ user '@' ] server '/' [fname]");
			Texts.WriteLn(W);  Texts.Append(Oberon.Log, W.buf)
		END
	END
END Mount;

PROCEDURE Unmount*;
VAR volName: ARRAY 64 OF CHAR;
BEGIN
	StartScan(S);
	IF S.class = Texts.Name THEN  COPY(S.s, volName);
		RemoveVolume(volName);
		showPath();
		Texts.Append(Oberon.Log, W.buf)
	END
END Unmount;

PROCEDURE Format*;
VAR fmtCmd, volName: ARRAY 64 OF CHAR;
BEGIN
	StartScan(S);
	IF S.class = Texts.Name THEN  COPY(S.s, volName);
		Texts.Scan(S);
		IF S.class = Texts.Name THEN  COPY(S.s, fmtCmd);
			FormatVolume(volName, fmtCmd);
		END
	END
END Format;

PROCEDURE SetDefault*;
VAR i: LONGINT;
BEGIN
	StartScan(S);
	IF S.class = Texts.Name THEN
		i := 0; WHILE (S.s[i] # 0X) & (S.s[i] # ":") DO INC(i) END;
		S.s[i] := 0X;
		SetCurFS(S.s);
	END
END SetDefault;

BEGIN
	Texts.OpenWriter(W)
END NCFS.
