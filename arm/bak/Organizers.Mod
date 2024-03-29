�_   Oberon10.Scn.Fnt  W  Oberon10b.Scn.Fnt      F        
        �   �'  (* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE Organizers;	(** portable *) (* jm 8.12.94 *)

(*
	This is an example of a Panel extension. It uses simple constraints attached as attributes to its direct contents
	to calculate a new layout when the panel is resized. It uses a strategy by Luca Cardelli, and described
	in his paper "Building User Interfaces by Direct Manipulation", DEC, 1987.
	
	Four wires are strung between the four sides of a descendant and an edge of the panel. The horizontal sides
	of the child gadget are attached to the top or bottom of the panel, and the vertical sides to the left or the right.
	The length of the four wires are given as four numbers in the "Constraint" attribute. Positive numbers strung the
	wire "outward" and negative numbers "over the gadget".
	
	That is
	
		Gadgets.ChangeAttr Constraints "10 20 10 10" ~
		
	sets a constraint where the left edge of the gadget is 10 pixels from the left of the panel, the top edge 20 pixels
	from the panel top, the right edge 10 pixels from the panel right, and the bottom edge 10 pixels from the panel
	bottom. Thus the sequence of numbers are left, top, right, and bottom distances.
	
	Changing the 20 to -20 attaches the top edge of the gadget 20 pixels from the bottom of the panel.
	Get the idea? The mechanism is quite flexible, although I am sure you will want more!
	
	Gadgets.Exchange flips the marked panel between an organizer and a normal panel. This works on panel
	documents too. An example document built with Organizers is "TestOrganizer.Panel".
	
	Hannes Marais, 9.12.94
*)
	
IMPORT Objects, Display, Effects, Gadgets, Panels, Oberon, Strings;

CONST
	outofboundsmodify = 3;
	DontCare = MAX(LONGINT);

VAR
	methods: Panels.Methods;
	
PROCEDURE Parse(s: ARRAY OF CHAR; VAR l, t, r, b: LONGINT);
VAR p: ARRAY 64 OF CHAR; i, j: INTEGER;

	PROCEDURE ReadNum(): LONGINT;
	VAR x: LONGINT;
	BEGIN
		WHILE (s[i] # 0X) & (s[i] <= " ") DO INC(i) END;
		IF s[i] = 0X THEN RETURN 0
		ELSIF ((s[i] < "0") OR (s[i] > "9")) & (s[i] # "-") THEN INC(i); RETURN DontCare
		END;
		j := 0; WHILE (s[i] # 0X) & (s[i] > " ") DO p[j] := s[i]; INC(i); INC(j) END;
		p[j] := 0X; Strings.StrToInt(p, x); RETURN x
	END ReadNum;
	
BEGIN
	i := 0;
	l := ReadNum(); t := ReadNum(); r := ReadNum(); b := ReadNum()
END Parse;

PROCEDURE HasConstraints*(f: Display.Frame; VAR l, t, r, b: LONGINT): BOOLEAN;
VAR A: Objects.AttrMsg;
BEGIN
	A.id := Objects.get; A.name := "Constraints"; A.res := -1; f.handle(f, A);
	IF (A.res >= 0) & (A.class = Objects.String) & (A.s # "") THEN Parse(A.s, l, t, r, b); RETURN TRUE
	ELSE RETURN FALSE
	END
END HasConstraints;

PROCEDURE SolveGadget*(PW, PH: INTEGER; f: Display.Frame; l, t, r, b: LONGINT; VAR X, Y, W, H: INTEGER);
VAR ll, tt, rr, bb: LONGINT;
BEGIN
	IF l = DontCare THEN ll := f.X ELSIF l >= 0 THEN ll := l ELSE ll := PW  + l END;
	IF r = DontCare THEN rr := f.X + f.W - 1 ELSIF r >= 0 THEN rr := PW - 1 - r ELSE rr := ABS(r) END;
	IF t = DontCare THEN tt := f.Y + f.H - 1 ELSIF t >= 0 THEN tt := - t ELSE tt := -PH - t END;
	IF b = DontCare THEN bb := f.Y ELSIF b >= 0 THEN bb := -PH + 1 + b ELSE bb := b END;

	IF (l = DontCare) & (r # DontCare) THEN ll := rr - f.W + 1
	ELSIF (l # DontCare) & (r = DontCare) THEN rr := ll + f.W - 1
	END;
	IF (t = DontCare) & (b # DontCare) THEN tt := bb + f.H - 1
	ELSIF (t # DontCare) & (b = DontCare) THEN bb := tt - f.H + 1
	END;
	X := SHORT(ll); Y := SHORT(bb);
	
	IF Gadgets.lockedsize IN f(Gadgets.Frame).state THEN W := f.W; H := f.H
	ELSE W := SHORT(rr) - X + 1; H := SHORT(tt) - Y + 1
	END
END SolveGadget;

PROCEDURE Solve*(F: Panels.Panel; dX, dY, W, H: INTEGER; mode: INTEGER);
VAR f: Display.Frame; l, t, r, b: LONGINT; M: Display.ModifyMsg;
BEGIN
	f := F.dsc;
	WHILE f # NIL DO
		IF HasConstraints(f, l, t, r, b) THEN
			SolveGadget(W, H, f, l, t, r, b, M.X, M.Y, M.W, M.H);
			IF (M.W > 0) & (M.H > 0) THEN INC(M.X, dX); INC(M.Y, dY);
				M.id := outofboundsmodify; M.F := f; M.mode := Display.state;
				M.dX := M.X - f.X; M.dY := M.Y - f.Y; M.dW := M.W - f.W; M.dH := M.H - f.H;
				Objects.Stamp(M); M.res := -1; M.dlink := NIL; M.x := 0; M.y := 0;
				f.handle(f, M)
			END
		END;
		f := f.next
	END;
END Solve;

PROCEDURE Handler*(F: Objects.Object; VAR M: Objects.ObjMsg);
VAR l, t, r, b: LONGINT; oX, oY, oW, oH, mode: INTEGER; f: Objects.Object; A: Display.ModifyMsg;
BEGIN
	WITH F: Panels.Panel DO
		IF M IS Display.ModifyMsg THEN
			WITH M: Display.ModifyMsg DO
				IF (M.F = F) & ((M.W # F.W) OR (M.H # F.H)) THEN
					IF ((M.dH = 0) OR (M.Y + M.H = F.Y + F.H)) & ((M.dW = 0) OR (M.X = F.X)) THEN
						Solve(F, M.X - F.X,  M.Y + M.H - F.Y - F.H, M.W, M.H, M.mode);
						Panels.PanelHandler(F, M)
					ELSE
						mode := M.mode; M.mode := Display.state;
						Panels.PanelHandler(F, M);
						Solve(F, M.X - F.X,  M.Y + M.H - F.Y - F.H, M.W, M.H, M.mode);
						IF mode = Display.display THEN Gadgets.Update(F) END
					END
				ELSIF Panels.IsChild(F, M.F) & (M.id # outofboundsmodify) THEN (* not send to self *)
					IF HasConstraints(M.F, l, t, r, b) THEN
						oX := M.F.X; oY := M.F.Y; oW := M.F.W; oH := M.F.H;
						M.F.X := M.X; M.F.Y := M.Y; M.F.W := M.W; M.F.H := M.H;
						SolveGadget(F.W, F.H, M.F, l, t, r, b, M.X, M.Y, M.W, M.H);
						M.F.X := oX; M.F.Y := oY; M.F.W := oW; M.F.H := oH;
						M.dX := M.X - M.F.X; M.dY := M.Y - M.F.Y; M.dW := M.W - M.F.W; M.dH := M.H - M.F.H;
					END;
					Panels.PanelHandler(F, M)
				ELSE Panels.PanelHandler(F, M)
				END;
			END
		ELSIF M IS Gadgets.UpdateMsg THEN (* when an attribute changes *)
			WITH M: Gadgets.UpdateMsg DO
				Panels.PanelHandler(F, M); (* forward *)
				f := M.obj;
				IF (f IS Gadgets.Frame) & Panels.IsChild(F, f(Gadgets.Frame)) THEN
					WITH f: Gadgets.Frame DO
						IF HasConstraints(f, l, t, r, b) THEN
							SolveGadget(F.W, F.H, f, l, t, r, b, A.X, A.Y, A.W, A.H);
							IF (A.X # f.X) OR (A.Y # f.Y) OR (A.W # f.W) OR (A.H # f.H) THEN
								A.id := outofboundsmodify; A.F := f; A.mode := Display.display;
								A.dX := A.X - f.X; A.dY := A.Y - f.Y; A.dW := A.W - f.W; A.dH := A.H - f.H;
								Display.Broadcast(A)
							END
						END
					END
				END
			END
		ELSIF M IS Objects.AttrMsg THEN
			WITH M: Objects.AttrMsg DO
				IF (M.id = Objects.get) & (M.name = "Gen") THEN M.s := "Organizers.NewPanel"; M.class := Objects.String; M.res := 0
				ELSIF (M.id = Objects.set) & (M.name = "Locked") THEN
					Panels.PanelHandler(F, M); EXCL(F.state, Gadgets.lockedsize)
				ELSE Panels.PanelHandler(F, M)
				END
			END
		ELSE Panels.PanelHandler(F, M)
		END
	END
END Handler;

(*PROCEDURE RestoreBackGround(F: Panels.Panel; x, y: INTEGER; R: Display3.Mask);
BEGIN
	Panels.methods.RestoreBackGround(F, x, y, R);
	Display3.Line(R, Display.FG, Display.solid, x + 1, y + F.H - 11, x + 10, y + F.H - 2, 1, Display.replace);
	Display3.Line(R, Display.BG, Display.solid, x + 1, y + F.H - 12, x + 10, y + F.H - 3, 1, Display.replace)
END RestoreBackGround;*)
	
PROCEDURE InsertChild(F: Panels.Panel; f: Display.Frame; u, v: INTEGER);
VAR l, t, r, b: LONGINT; x, y, w, h: INTEGER;
BEGIN
	IF HasConstraints(f, l, t, r, b) THEN
		SolveGadget(F.W, F.H, f, l, t, r, b, x, y, w, h);
		IF (w > 0) & (h > 0) THEN
			u := x; v := y; f.W := w; f.H := h;
		END
	END;
	Panels.methods.InsertChild(F, f, u, v)
END InsertChild;

PROCEDURE TrackMouse(F: Panels.Panel; VAR M: Oberon.InputMsg);
VAR T: Display.Frame; x, y, t, u, v: INTEGER; d: LONGINT; Fdlink, Mdlink: Objects.Object; flags: SET;
BEGIN
	x := M.x + F.X; y := M.y + F.Y; t := y + F.H - 1;
	T := Panels.ThisChild(F, x, y, M.X, M.Y);
	
	IF T # NIL THEN
		Effects.SetSnap(x, t, F.grid, F.grid);
		IF HasConstraints(T, d, d, d, d) THEN (* simulated a locked environment *)
			flags := F.state;
			INCL(F.state, Gadgets.lockedcontents);
			Panels.ToChild(F, T, x, y, M);
			F.state := flags
		ELSE
			Panels.ToChild(F, T, x, y, M)
		END;
		Effects.SetSnap(0, 0, 1, 1)
	END;
	
	IF M.res < 0 THEN
		Effects.SetSnap(x, t, F.grid, F.grid);
		IF 2 IN M.keys THEN (* left *)
			IF ~(Panels.noinsert IN F.state0) THEN F.do.TrackCaret(F, M) END
		ELSIF 1 IN M.keys THEN (* middle *)
			IF (T # NIL) & (Gadgets.selected IN T(Gadgets.Frame).state) THEN
				WITH T: Gadgets.Frame DO
					IF Effects.InCorner(M.X, M.Y, x + T.X, t + T.Y, T.W, T.H) & ~(Gadgets.lockedsize IN T.state) THEN
						u := M.x; v := M.y; M.x := x; M.y := t; 
						Fdlink := F.dlink; Mdlink := M.dlink; F.dlink := M.dlink; M.dlink := F;
						Gadgets.SizeFrame(T, M);
						F.dlink := Fdlink; M.dlink := Mdlink;
						M.x := u; M.y := v; M.res := 0
					ELSE F.do.DragSelection(F, M)
					END
				END
			END
		ELSIF 0 IN M.keys THEN (* right *)
			IF ~(Panels.noselect IN F.state0) THEN
				IF T = NIL THEN F.do.TrackSelection(F, M)
				ELSE F.do.TrackSelectChild(F, M, T(Gadgets.Frame))
				END
			END
		END;
		Effects.SetSnap(0, 0, 1, 1)
	END
END TrackMouse;

PROCEDURE InitPanel*(F: Panels.Panel);
BEGIN Panels.InitPanel(F); F.handle := Handler; F.do := methods;
END InitPanel;

PROCEDURE NewPanel*;
VAR p: Panels.Panel;
BEGIN
	NEW(p); InitPanel(p); Objects.NewObj := p
END NewPanel;

(* Make a normal panel into a organizer, and vice versa *)
PROCEDURE Exchange*;
VAR F: Display.Frame;
BEGIN
	IF Oberon.Pointer.on THEN
		F := Oberon.MarkedFrame();
		IF (F # NIL) & (F IS Panels.Panel) THEN
			WITH F: Panels.Panel DO
				IF F.do # methods THEN
					F.handle := Handler; F.do := methods;
					Solve(F, 0, 0, F.W, F.H, Display.state); Gadgets.Update(F)
				ELSE F.handle := Panels.PanelHandler; F.do := Panels.methods; Gadgets.Update(F)
				END
			END
		END
	END
END Exchange;

BEGIN NEW(methods); methods^ := Panels.methods^;
	(*methods.RestoreBackGround := RestoreBackGround;*) methods.InsertChild := InsertChild;
	methods.TrackMouse := TrackMouse
END Organizers.

System.Free Organizers ~
Gadgets.Insert Organizers.NewPanel ~
Gadgets.Insert Button ~

Organizers.Exchange 
Gadgets.ChangeAttr Constraints "10 x 10 10" ~

Gadgets.ChangeAttr Constraints "10 50 10 10" ~
