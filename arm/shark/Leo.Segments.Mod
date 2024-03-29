�TextDocs.NewDoc     �� � e   Oberon10.Scn.Fnt  �   Syntax10.Scn.Fnt                              �  (* ETH Oberon, Copyright 2000 ETH Z�rich Institut f�r Computersysteme, ETH Zentrum, CH-8092 Z�rich.
Refer to the general ETH Oberon System license contract available at: http://www.oberon.ethz.ch/ *)

MODULE Segments; (** portable **)	(* eos   *)

	(**
		Legacy support for figures created with Leonardo 0.x and 1.x
	**)
	
	IMPORT
		Files, Objects, Attributes, Gadgets, GfxMatrix, Leonardo, LeoPens, LeoPaths;
		
	
	PROCEDURE ReadContainer (VAR r: Files.Rider; cont: Leonardo.Container);
		VAR
			ver: LONGINT; int: INTEGER; real: REAL; obj: Objects.Object; cm: Objects.CopyMsg; s: Leonardo.Shape;
			bool: BOOLEAN;
	BEGIN
		(* shape part *)
		Files.ReadNum(r, ver);
		ASSERT(ver IN {1, 2}, 110);
		IF ver = 1 THEN
			Files.ReadInt(r, int); Files.ReadInt(r, int);
			Files.ReadInt(r, int); Files.ReadInt(r, int);
			Files.ReadReal(r, real)
		END;
		
		(* container part *)
		Files.ReadNum(r, ver);
		ASSERT(ver IN {1, 2}, 111);
		REPEAT
			Gadgets.ReadRef(r, cont.lib, obj)
		UNTIL (obj = NIL) OR (obj IS Leonardo.Shape);
		IF obj # NIL THEN
			Objects.Stamp(cm); cm.id := Objects.shallow; cm.obj := obj; obj.handle(obj, cm);
			s := cm.obj(Leonardo.Shape); s.cont := cont; cont.bottom := s; cont.top := s;
			Gadgets.ReadRef(r, cont.lib, obj);
			WHILE (obj # NIL) & (obj IS Leonardo.Shape) DO
				Objects.Stamp(cm); cm.id := Objects.shallow; cm.obj := obj; obj.handle(obj, cm);
				s := cm.obj(Leonardo.Shape); s.cont := cont; s.down := cont.top; cont.top.up := s; cont.top := s;
				Gadgets.ReadRef(r, cont.lib, obj)
			END
		END;
		Leonardo.GetComponentsBox(cont.bottom, cont.llx, cont.lly, cont.urx, cont.ury, cont.bw);
		IF ver = 1 THEN
			Files.ReadBool(r, bool)
		END
	END ReadContainer;
	
	
	(*--- Curves ---*)
	
	PROCEDURE HandleCurve (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR path: LeoPaths.Path;
	BEGIN
		IF msg IS Objects.FileMsg THEN
			WITH msg: Objects.FileMsg DO
				ASSERT(msg.id = Objects.load);
				path := obj(LeoPaths.Path);
				ReadContainer(msg.R, path);
				path.handle := LeoPaths.HandlePath
			END
		ELSE
			LeoPaths.HandlePath(obj, msg)
		END
	END HandleCurve;
	
	PROCEDURE NewCurve*;
		VAR path: LeoPaths.Path;
	BEGIN
		NEW(path); LeoPaths.InitPath(path, NIL, NIL, LeoPens.Default); path.handle := HandleCurve;
		Objects.NewObj := path
	END NewCurve;
	
	
	(*--- Segments ---*)
	
	PROCEDURE NewLine*;
	BEGIN
		Objects.NewObj := Gadgets.CreateObject("LeoCurves.NewPolygon")
	END NewLine;
	
	PROCEDURE HandleArc (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR arc: LeoPaths.Arc; p: Leonardo.Shape; x0, y0, x1, y1, x2, y2: REAL; ver: LONGINT;
	BEGIN
		IF msg IS Objects.FileMsg THEN
			WITH msg: Objects.FileMsg DO
				ASSERT(msg.id = Objects.load, 110);
				arc := obj(LeoPaths.Arc);
				ReadContainer(msg.R, arc);
				p := arc.bottom.up; arc.bottom.up := arc.top; arc.top.down := arc.bottom;
				x0 := 0; y0 := 0; x1 := 10; y1 := 0; x2 := 0; y2 := 10;
				IF p # arc.top THEN
					Attributes.GetReal(p, "X", x0); Attributes.GetReal(p, "Y", y0);
					x1 := x0 + x1; y1 := x0 + y1; x2 := x0 + x2; y2 := y0 + y2;
					p := p.up;
					IF p # arc.top THEN
						Attributes.GetReal(p, "X", x2); Attributes.GetReal(p, "Y", y2); p := p.up;
						IF p # arc.top THEN
							Attributes.GetReal(p, "X", x1); Attributes.GetReal(p, "Y", y1)
						END
					END
				END;
				GfxMatrix.Init(arc.mat, x1 - x0, y1 - y0, x2 - x0, y2 - y0, x0, y0);
				Files.ReadNum(msg.R, ver);
				ASSERT(ver = 1, 111);
				Gadgets.ReadRef(msg.R, arc.lib, obj);
				IF (obj # NIL) & (obj IS LeoPens.Pen) THEN
					arc.pen := obj(LeoPens.Pen)
				END;
				LeoPaths.CalcArcBox(arc, GfxMatrix.Identity);
				arc.handle := LeoPaths.HandleArc
			END
		ELSE
			LeoPaths.HandleArc(arc, msg)
		END
	END HandleArc;
	
	PROCEDURE NewArc*;
		VAR arc: LeoPaths.Arc;
	BEGIN
		NEW(arc); arc.handle := HandleArc;
		Objects.NewObj := arc
	END NewArc;
	
	PROCEDURE NewBezier*;
	BEGIN
		Objects.NewObj := Gadgets.CreateObject("LeoCurves.NewBezier")
	END NewBezier;
	
	PROCEDURE NewSpline*;
	BEGIN
		Objects.NewObj := Gadgets.CreateObject("LeoSplines.NewSpline")
	END NewSpline;
	

END Segments.
�BIER�  �   �    :       Z 
 ��    ��C  Oberon10.Scn.Fnt 10.05.00  17:00:36  TimeStamps.New  �