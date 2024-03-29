�_   Oberon10.Scn.Fnt    Oberon10b.Scn.Fnt      �       �       �	   �  (* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE Configuration;	(** portable *)	(* jm, Configuration module/code borrowed from ET by uh **)

(*
	contains a lot of code borrowed from ET
*)

IMPORT Modules, Display, Input, Viewers, Texts, Oberon;

CONST
	CR = 0DX;
	Default = "Configuration.Text";

VAR
	W: Texts.Writer;
	sX, sY: INTEGER;	(* saved coordinates for newm viewer [used in Marker ] *)

PROCEDURE OpenScanner(VAR S: Texts.Scanner);
	VAR
		text: Texts.Text;
		beg, end, time: LONGINT;
BEGIN
	Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos);
	Texts.Scan(S);
	IF (S.class = Texts.Char) & (S.c = "^") THEN
		text := NIL; time := 0; Oberon.GetSelection(text, beg, end, time);
		IF (text = NIL) OR (time <= 0) THEN S.class := Texts.Inval; RETURN END;
		Texts.OpenScanner(S, text, beg); Texts.Scan(S)
	END
END OpenScanner;

(** Execute commands contained in the text. Each command must be on a separate line. *)
PROCEDURE do*(T: Texts.Text; beg, end: LONGINT);
VAR S: Texts.Scanner; pos: LONGINT; res: INTEGER;
	
	PROCEDURE NextCmd();
		VAR tR: Texts.Reader; ch: CHAR;
	BEGIN
		IF pos < end THEN 
			Texts.OpenReader(tR, T, pos); Texts.Read(tR, ch);
			LOOP
				WHILE ~tR.eot & (ch # CR) DO Texts.Read(tR, ch) END;
				Texts.Read(tR, ch);
				IF tR.eot THEN
					EXIT
				ELSIF (ch > " ") & (ch # "!") & (ch # "#") THEN
					pos := Texts.Pos(tR)-1;
					Texts.OpenScanner(S, T, pos); Texts.Scan(S);
					RETURN
				END
			END
		END;
		S.class := Texts.Inval
	END NextCmd;

	PROCEDURE FirstCmd();
		VAR tR: Texts.Reader; ch: CHAR;
	BEGIN
		IF pos < end THEN 
			Texts.OpenReader(tR, T, pos); Texts.Read(tR, ch);
			IF ~tR.eot & (ch > " ") & (ch # "!") & (ch # "#") THEN
				pos := Texts.Pos(tR)-1;
				Texts.OpenScanner(S, T, pos); Texts.Scan(S);
				RETURN
			END
		END;
		NextCmd()
	END FirstCmd;
	
	PROCEDURE UserInterrupt(): BOOLEAN;
	VAR ch: CHAR;
	BEGIN
		WHILE Input.Available() # 0 DO
			Input.Read(ch);
			IF ch = CHR(27) THEN RETURN TRUE END
		END;
		RETURN FALSE
	END UserInterrupt;

BEGIN
	pos := beg; FirstCmd();
	WHILE (S.class = Texts.Name) & (pos < end) & ~UserInterrupt() DO
		pos := Texts.Pos(S) - 1; 
		Oberon.Par.vwr := Oberon.MarkedViewer();
		Oberon.Par.frame := Oberon.MarkedFrame();
		Oberon.Par.text := T; Oberon.Par.pos := pos;
		Oberon.Call(S.s, Oberon.Par, FALSE, res);
		IF res # 0 THEN
			Texts.WriteString(W, "Call error: ");  Texts.WriteString(W, Modules.resMsg);
			Texts.WriteLn(W);  Texts.Append(Oberon.Log, W.buf)
		END;
		NextCmd()
	END
END do;

(** Configuration.DoText ( "*" | "^" | textfile { textfile } "~" )
		Execute the commands in textfile . Each command must be written on a separate line. *)
	PROCEDURE DoText*;
	VAR S: Texts.Scanner; T: Texts.Text;
	BEGIN
		OpenScanner(S);
		IF (S.class = Texts.Char) & (S.c = "*") THEN
			T := Oberon.MarkedText()
		ELSIF S.class IN {Texts.Name, Texts.String} THEN
			NEW(T); Texts.Open(T, S.s)
		ELSE
			T := NIL
		END;
		IF T # NIL THEN
			do(T, 0, T.len)
		END
	END DoText;

(** Configuration.DoCommands ( "^" | cmd { cmd } "~" )
		Execute the commands. Each command must be written on a separate line. *)
PROCEDURE DoCommands*;
	VAR
		S: Texts.Scanner; T: Texts.Text;
		beg, end, time: LONGINT;
BEGIN
	Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos);
	Texts.Scan(S);
	IF (S.class = Texts.Char) & (S.c = "^") THEN
		T := NIL; time := -1; Oberon.GetSelection(T, beg, end, time);
	ELSE
		T := Oberon.Par.text; beg := Oberon.Par.pos; end := T.len
	END;
	IF T # NIL THEN
		do(T, beg, end)
	END
END DoCommands;

PROCEDURE ValidX(X: INTEGER): BOOLEAN;
BEGIN
	RETURN (Display.Left <= X) & (X < Display.Left + Display.Width)
			OR (Display.ColLeft <= X) & (X < Display.ColLeft + Display.Width)
END ValidX;

PROCEDURE ValidY(Y: INTEGER): BOOLEAN;
BEGIN
	RETURN (Display.Bottom <= Y) & (Y < Display.Bottom + Display.Height)
END ValidY;

(** Set the star marker under program control:
	Configuration.Marker set save		(* set at saved position *)
	Configuration.Marker set this		(* set to current viewer *)
	Configuration.Marker set system		(* in system track *)
	Configuration.Marker set user		(* in user track *)
	Configuration.Marker set X Y		(* at absolute pixel position X, Y *)
	Configuration.Marker set X% Y%		(* at relative pixel position X, Y *)
	Configuration.Marker save system		(* save marker in system track *)
	Configuration.Marker save user		(* save marker in user track *)
*)
PROCEDURE Marker*;
	VAR S: Texts.Scanner;	V : Viewers.Viewer;	cM: Oberon.ControlMsg;
BEGIN
	Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos);  Texts.Scan(S);
	IF S.class # Texts.Name THEN RETURN END;
	IF S.s = "set" THEN
		Texts.Scan(S); cM.id := Oberon.mark + 999;
		IF (S.class = Texts.Name) & (S.s = "saved") THEN
			V := Viewers.This(sX + 1, sY - 1);
			IF (V # NIL) & (V.X = sX) & (V.Y + V.H = sY) THEN
				cM.id := Oberon.mark; cM.X := V.X + V.W DIV 2; cM.Y := V.Y + V.H DIV 2
			END
		ELSIF (S.class = Texts.Name) & (S.s = "this") THEN
			IF Oberon.Par.vwr # NIL THEN
				cM.id := Oberon.mark; cM.X := Oberon.Par.vwr.X + Oberon.Par.vwr.W DIV 2; 
				cM.Y := Oberon.Par.vwr.Y + Oberon.Par.vwr.H DIV 2
			END
		ELSIF (S.class = Texts.Name) & (S.s = "system") THEN
			Oberon.AllocateSystemViewer(Oberon.SystemTrack(Oberon.Par.vwr.X), cM.X, cM.Y);
			cM.id := Oberon.mark;
		ELSIF (S.class = Texts.Name) & (S.s = "user") THEN
			Oberon.AllocateUserViewer(Oberon.UserTrack(Oberon.Par.vwr.X), cM.X, cM.Y);
			cM.id := Oberon.mark;
		ELSIF (S.class = Texts.Int) & (S.i >= 0) THEN
			cM.X := SHORT(S.i); Texts.Scan(S);
			IF (S.class = Texts.Int) & (S.i >= 0) THEN
				cM.Y := SHORT(S.i);
				IF ValidX(cM.X) & ValidY(cM.Y) THEN cM.id := Oberon.mark END
			ELSIF (S.class = Texts.Char) & (S.c = "%") THEN
				Texts.Scan(S);
				IF (S.class = Texts.Int) & (S.i >= 0) THEN
					cM.Y := SHORT(S.i*Display.Height DIV 100);
					cM.X := SHORT(LONG(Display.Width)*cM.X DIV 100);
					IF ValidX(cM.X) & ValidY(cM.Y) THEN cM.id := Oberon.mark END
				END
			END
		END;
		IF cM.id = Oberon.mark THEN
			IF cM.Y >= Display.Width THEN cM.Y := Display.Width-1 END;
			V := Viewers.This(cM.X, cM.Y); IF V # NIL THEN V.handle(V, cM) END	(* set marker *)
		END
	ELSIF S.s = "save" THEN
		Texts.Scan(S);
		IF S.class = Texts.Name THEN
			IF S.s = "system" THEN
				Oberon.AllocateSystemViewer(Oberon.SystemTrack(Oberon.Par.vwr.X), sX, sY)
			ELSIF S.s = "user" THEN
				Oberon.AllocateUserViewer(Oberon.UserTrack(Oberon.Par.vwr.X), sX, sY)
			ELSE sX := -1; sY := -1
			END
		END
	END
END Marker;

PROCEDURE Init();
	VAR
		s: Texts.Scanner;
		T: Texts.Text;
		x, y: INTEGER;
BEGIN
	Oberon.OpenScanner(s, "System.Configuration");
	IF ~(s.class IN {Texts.Name, Texts.String}) THEN
		COPY(Default, s.s)
	END;
	NEW(T); Texts.Open(T, s.s);
	IF T.len > 0 THEN
		Oberon.AllocateSystemViewer(Display.Left, x, y);
		NEW(Oberon.Par);
		Oberon.Par.vwr := Viewers.This(x+1, y-1); NEW(Oberon.Par.frame);
		do(T, 0, T.len)
	END
END Init;

BEGIN Texts.OpenWriter(W); Init()
END Configuration.
