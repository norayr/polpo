�TextDocs.NewDoc     �� � e   Oberon10.Scn.Fnt  �   Syntax10.Scn.Fnt                           �   �  (* ETH Oberon, Copyright 2000 ETH Z�rich Institut f�r Computersysteme, ETH Zentrum, CH-8092 Z�rich.
Refer to the general ETH Oberon System license contract available at: http://www.oberon.ethz.ch/ *)

MODULE FancyPens; (** portable **)	(* eos   *)

	(**
		Legacy support for figures created with Leonardo 0.x and 1.x
	**)
	
	IMPORT
		Files, Objects, Gadgets, Gfx, LeoPens, LeoOutliners, Pens;
		
	
	TYPE
		Style = POINTER TO StyleDesc;
		StyleDesc = RECORD (Objects.ObjDesc)
			len, width: REAL;
		END;
		
	
	(*
		Dasher Pens: only problem is converting the pattern from the old set based representation to an array of reals
		when loading
	*)
	
	PROCEDURE HandleDashPen (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR pen: LeoPens.Dasher; ver, i: LONGINT; set: SET; len: INTEGER; period, beg, end: REAL;
	BEGIN
		IF msg IS Objects.FileMsg THEN
			WITH msg: Objects.FileMsg DO
				ASSERT(msg.id = Objects.load);
				pen := obj(LeoPens.Dasher);
				Gadgets.ReadRef(msg.R, pen.lib, obj);
				IF (obj # NIL) OR (obj IS LeoPens.Pen) THEN
					pen.base := obj(LeoPens.Pen)
				END;
				pen.destructive := ~(pen.base IS LeoPens.Stroker);
				Files.ReadNum(msg.R, ver);
				ASSERT(ver = 1);
				Files.ReadSet(msg.R, set); Files.ReadInt(msg.R, len); Files.ReadReal(msg.R, period);
				Files.ReadBool(msg.R, pen.continuous);
				pen.continuous := ~pen.continuous;	(* used to have inverted semantics *)
				IF (set = {}) OR (len = 0) OR (set = {0..len-1}) THEN	(* use solid pattern *)
					pen.phase := 0; pen.len := 0
				ELSE
					i := 0; WHILE ~(i IN set) DO INC(i) END;	(* find first element in set *)
					beg := i * period/len; pen.len := 0; pen.phase := beg;
					WHILE i < len DO
						WHILE (i < len) & (i IN set) DO INC(i) END;
						end := i * period/len; pen.on[pen.len] := end - beg;
						WHILE (i < len) & ~(i IN set) DO INC(i) END;
						beg := i * period/len; pen.off[pen.len] := beg - end;
						INC(pen.len)
					END;
					pen.off[pen.len-1] := pen.off[pen.len-1] + pen.phase
				END;
				pen.handle := LeoPens.HandleDasher
			END
		ELSE
			LeoPens.HandleDasher(obj, msg)
		END
	END HandleDashPen;
	
	PROCEDURE NewDashPen*;
		VAR pen: LeoPens.Dasher; onoff: ARRAY 1 OF REAL;
	BEGIN
		NEW(pen); LeoPens.InitDasher(pen, LeoPens.Default, onoff, onoff, 0); pen.handle := HandleDashPen;
		Objects.NewObj := pen
	END NewDashPen;
	
	
	(*
		Bevel Pens: The tricky bit is that the old pen implementation supported two base pens: one for filling
		and one for stroking the outline, basically requiring a forker pen. However, if one of the forker's base
		pens is a default pen, the forker forwards all messages to its other base. As a consequence, the forker
		will be replaced by its active pen when it is stored and loaded again.
	*)
	
	PROCEDURE HandleBevelPen (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR pen: LeoPens.Forker; width: REAL; ol: LeoOutliners.Outliner; ss: LeoPens.Stroker;
	BEGIN
		pen := obj(LeoPens.Forker);
		IF (msg IS Objects.FileMsg) & (msg(Objects.FileMsg).id = Objects.load) THEN
			WITH msg: Objects.FileMsg DO
				Files.ReadReal(msg.R, width);
				Gadgets.ReadRef(msg.R, pen.lib, obj);
				IF (obj # NIL) & (obj IS LeoPens.Pen) THEN
					NEW(ol); LeoOutliners.InitOutliner(ol, obj(LeoPens.Pen), width, LeoOutliners.outlined);
					ol.joinstyle := Gfx.BevelJoin;
					pen.upper := ol
				END;
				Gadgets.ReadRef(msg.R, pen.lib, obj);
				IF (obj # NIL) & (obj IS LeoPens.Pen) THEN
					IF obj IS LeoPens.Filler THEN
						NEW(ss); LeoPens.InitStroker(ss, obj(LeoPens.Filler).col, width);
						ss.joinstyle := Gfx.BevelJoin;
						pen.lower := ss
					ELSE	(* will probably never happen *)
						NEW(ol); LeoOutliners.InitOutliner(ol, obj(LeoPens.Pen), width, LeoOutliners.outlined);
						ol.joinstyle := Gfx.BevelJoin;
						pen.lower := ol
					END
				END
			END
		ELSIF pen.upper = Pens.Empty THEN
			IF msg IS Objects.BindMsg THEN
				Gadgets.BindObj(pen, msg(Objects.BindMsg).lib)
			ELSE
				pen.lower.handle(pen.lower, msg)
			END
		ELSIF pen.lower = Pens.Empty THEN
			IF msg IS Objects.BindMsg THEN
				Gadgets.BindObj(pen, msg(Objects.BindMsg).lib)
			ELSE
				pen.upper.handle(pen.upper, msg)
			END
		ELSE
			LeoPens.HandleForker(pen, msg)
		END
	END HandleBevelPen;
	
	PROCEDURE NewBevelPen*;
		VAR pen: LeoPens.Forker;
	BEGIN
		NEW(pen); LeoPens.InitForker(pen, Pens.Empty, Pens.Empty); pen.handle := HandleBevelPen;
		Objects.NewObj := pen
	END NewBevelPen;
	
	
	(*
		Style Pens: only arrow styles were ever implemented, which is why an arrow pen is used. The style objects
		are local to this module and only used for loading.
	*)
	
	PROCEDURE HandleStylePen* (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR pen: LeoOutliners.Arrow; stroke, fill: Objects.Object; forker: LeoPens.Forker; beg, end: Style;
	BEGIN
		IF msg IS Objects.FileMsg THEN
			WITH msg: Objects.FileMsg DO
				ASSERT(msg.id = Objects.load);
				pen := obj(LeoOutliners.Arrow);
				Gadgets.ReadRef(msg.R, pen.lib, obj);
				Files.ReadReal(msg.R, pen.width);
				Gadgets.ReadRef(msg.R, pen.lib, stroke);
				Gadgets.ReadRef(msg.R, pen.lib, fill);
				IF (stroke = NIL) OR (stroke = Pens.Empty) THEN obj := fill
				ELSIF (fill = NIL) OR (fill = Pens.Empty) THEN obj := stroke
				ELSIF (stroke IS LeoPens.Pen) & (fill IS LeoPens.Pen) THEN
					NEW(forker); LeoPens.InitForker(forker, fill(LeoPens.Pen), stroke(LeoPens.Pen));
					obj := forker
				END;
				IF (obj # NIL) & (obj IS LeoPens.Pen) THEN
					pen.base := obj(LeoPens.Pen)
				END;
				
				beg := NIL; end := NIL;
				Gadgets.ReadRef(msg.R, pen.lib, obj);
				IF (obj # NIL) & (obj IS Style) THEN beg := obj(Style) END;
				Gadgets.ReadRef(msg.R, pen.lib, obj);
				IF (obj # NIL) & (obj IS Style) THEN end := obj(Style) END;
				IF (beg # NIL) & (end = NIL) THEN
					pen.dir := LeoOutliners.backwards; pen.len := beg.len; pen.coff := pen.len; pen.cdist := beg.width
				ELSIF (beg = NIL) & (end # NIL) THEN
					pen.dir := LeoOutliners.forwards; pen.len := end.len; pen.coff := pen.len; pen.cdist := end.width
				ELSIF (beg # NIL) & (end # NIL) THEN
					pen.dir := LeoOutliners.both; pen.len := end.len; pen.coff := pen.len; pen.cdist := end.width
				END;
				pen.handle := LeoOutliners.HandleArrow
			END
		ELSE
			LeoOutliners.HandleArrow(obj, msg)
		END
	END HandleStylePen;
	
	PROCEDURE NewStylePen*;
		VAR pen: LeoOutliners.Arrow;
	BEGIN
		NEW(pen); LeoOutliners.InitArrow(pen, LeoPens.Default, 0, 0, 10, 10, 5, 1); pen.handle := HandleStylePen;
		Objects.NewObj := pen
	END NewStylePen;
	
	
	(*
		Arrows: used to be separate type, not a pen. Just read dimensions from file and let the style pen use them
	*)
	
	PROCEDURE HandleArrowStyle (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR style: Style;
	BEGIN
		IF msg IS Objects.FileMsg THEN
			WITH msg: Objects.FileMsg DO
				ASSERT(msg.id = Objects.load);
				style := obj(Style);
				Files.ReadReal(msg.R, style.len);
				Files.ReadReal(msg.R, style.width)
			END
		END
	END HandleArrowStyle;
	
	PROCEDURE NewArrowStyle*;
		VAR style: Style;
	BEGIN
		NEW(style); style.handle := HandleArrowStyle;
		Objects.NewObj := style
	END NewArrowStyle;
	

END FancyPens.
�BIER�  �   h    :       Z 
 ��    ��C  Oberon10.Scn.Fnt 10.05.00  16:59:59  TimeStamps.New  �