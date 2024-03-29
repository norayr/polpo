�TextDocs.NewDoc     �� � e   Oberon10.Scn.Fnt  �   Syntax10.Scn.Fnt  
                         �   �  (* ETH Oberon, Copyright 2000 ETH Z�rich Institut f�r Computersysteme, ETH Zentrum, CH-8092 Z�rich.
Refer to the general ETH Oberon System license contract available at: http://www.oberon.ethz.ch/ *)

MODULE Areas; (** portable **)	(* eos   *)

	(**
		Legacy support for figures created with Leonardo 0.x and 1.x
	**)
	
	IMPORT
		Files, Objects, Attributes, Gadgets, GfxMatrix, Leonardo, LeoPens, LeoOutliners, LeoPaths, LeoBasic;
		
	
	(*--- Rectangles ---*)
	
	PROCEDURE HandleRect (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR
			rect: LeoBasic.Rectangle; ver: LONGINT; i: INTEGER; real: REAL; x, y: ARRAY 4 OF REAL; bool: BOOLEAN;
			fill, stroke: LeoPens.Pen; forker: LeoPens.Forker;
	BEGIN
		IF msg IS Objects.FileMsg THEN
			WITH msg: Objects.FileMsg DO
				rect := obj(LeoBasic.Rectangle);
				ASSERT(msg.id = Objects.load, 110);
				
				(* shape part *)
				Files.ReadNum(msg.R, ver);
				ASSERT(ver IN {1, 2}, 111);
				IF ver = 1 THEN
					Files.ReadInt(msg.R, i); Files.ReadInt(msg.R, i); Files.ReadInt(msg.R, i); Files.ReadInt(msg.R, i);
					Files.ReadReal(msg.R, real)
				END;
				
				(* container part *)
				Files.ReadNum(msg.R, ver);
				ASSERT(ver = 1, 112);
				FOR i := 0 TO 3 DO
					Gadgets.ReadRef(msg.R, rect.lib, obj);
					Attributes.GetReal(obj, "X", x[i]); Attributes.GetReal(obj, "Y", y[i])
				END;
				Gadgets.ReadRef(msg.R, rect.lib, obj);
				ASSERT(obj = NIL, 113);
				GfxMatrix.Init(rect.mat, x[1] - x[0], y[1] - y[0], x[3] - x[0], y[3] - y[0], x[0], y[0]);
				GfxMatrix.ApplyToRect(rect.mat, 0, 0, 1, 1, rect.llx, rect.lly, rect.urx, rect.ury);
				Files.ReadBool(msg.R, bool);
				
				(* rectangle part *)
				Files.ReadNum(msg.R, ver);
				ASSERT(ver = 1, 114);
				fill := NIL; stroke := NIL;
				Gadgets.ReadRef(msg.R, rect.lib, obj);
				IF (obj # NIL) & (obj IS LeoPens.Pen) THEN fill := obj(LeoPens.Pen) END;
				Gadgets.ReadRef(msg.R, rect.lib, obj);
				IF (obj # NIL) & (obj IS LeoPens.Pen) THEN
					stroke := obj(LeoPens.Pen);
					IF stroke IS LeoOutliners.Arrow THEN
						stroke := stroke(LeoOutliners.Arrow).base
					END
				END;
				IF (fill # NIL) & (stroke # NIL) THEN NEW(forker); LeoPens.InitForker(forker, fill, stroke); rect.pen := forker
				ELSIF (fill # NIL) & (stroke = NIL) THEN rect.pen := fill
				ELSIF (fill = NIL) & (stroke # NIL) THEN rect.pen := stroke
				END;
				Attributes.GetReal(rect.pen, "Border", rect.bw);
				
				(* constraints (ignored) *)
				REPEAT Gadgets.ReadRef(msg.R, rect.lib, obj) UNTIL obj = NIL;
				REPEAT Gadgets.ReadRef(msg.R, rect.lib, obj) UNTIL obj = NIL;
				
				rect.handle := LeoBasic.HandleRect
			END
		ELSE
			LeoBasic.HandleRect(obj, msg)
		END
	END HandleRect;
	
	PROCEDURE NewRectangle*;
		VAR rect: LeoBasic.Rectangle;
	BEGIN
		NEW(rect); LeoBasic.InitRect(rect, 0, 0, 1, 1, LeoPens.Default); rect.handle := HandleRect;
		Objects.NewObj := rect
	END NewRectangle;
	
	
	(*--- Ellipses ---*)
	
	PROCEDURE HandleEllipse (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR
			e: LeoBasic.Ellipse; ver: LONGINT; i: INTEGER; real: REAL; x, y: ARRAY 3 OF REAL; bool: BOOLEAN;
			fill, stroke: LeoPens.Pen; forker: LeoPens.Forker;
	BEGIN
		IF msg IS Objects.FileMsg THEN
			WITH msg: Objects.FileMsg DO
				e := obj(LeoBasic.Ellipse);
				ASSERT(msg.id = Objects.load, 110);
				
				(* shape part *)
				Files.ReadNum(msg.R, ver);
				ASSERT(ver IN {1, 2}, 111);
				IF ver = 1 THEN
					Files.ReadInt(msg.R, i); Files.ReadInt(msg.R, i); Files.ReadInt(msg.R, i); Files.ReadInt(msg.R, i);
					Files.ReadReal(msg.R, real)
				END;
				
				(* container part *)
				Files.ReadNum(msg.R, ver);
				ASSERT(ver = 1, 112);
				FOR i := 0 TO 2 DO
					Gadgets.ReadRef(msg.R, e.lib, obj);
					Attributes.GetReal(obj, "X", x[i]); Attributes.GetReal(obj, "Y", y[i])
				END;
				Gadgets.ReadRef(msg.R, e.lib, obj);
				ASSERT(obj = NIL, 113);
				GfxMatrix.Init(e.mat, x[1] - x[0], y[1] - y[0], x[2] - x[0], y[2] - y[0], x[0], y[0]);
				GfxMatrix.ApplyToRect(e.mat, -1, -1, 1, 1, e.llx, e.lly, e.urx, e.ury);
				Files.ReadBool(msg.R, bool);
				
				(* ellipse part *)
				Files.ReadNum(msg.R, ver);
				ASSERT(ver = 1, 114);
				fill := NIL; stroke := NIL;
				Gadgets.ReadRef(msg.R, e.lib, obj);
				IF (obj # NIL) & (obj IS LeoPens.Pen) THEN fill := obj(LeoPens.Pen) END;
				Gadgets.ReadRef(msg.R, e.lib, obj);
				IF (obj # NIL) & (obj IS LeoPens.Pen) THEN
					stroke := obj(LeoPens.Pen);
					IF stroke IS LeoOutliners.Arrow THEN
						stroke := stroke(LeoOutliners.Arrow).base
					END
				END;
				IF (fill # NIL) & (stroke # NIL) THEN NEW(forker); LeoPens.InitForker(forker, fill, stroke); e.pen := forker
				ELSIF (fill # NIL) & (stroke = NIL) THEN e.pen := fill
				ELSIF (fill = NIL) & (stroke # NIL) THEN e.pen := stroke
				END;
				Attributes.GetReal(e.pen, "Border", e.bw);
				
				(* constraints (ignored) *)
				REPEAT Gadgets.ReadRef(msg.R, e.lib, obj) UNTIL obj = NIL;
				REPEAT Gadgets.ReadRef(msg.R, e.lib, obj) UNTIL obj = NIL;
				
				e.handle := LeoBasic.HandleEllipse
			END
		ELSE
			LeoBasic.HandleEllipse(obj, msg)
		END
	END HandleEllipse;
	
	PROCEDURE NewEllipse*;
		VAR e: LeoBasic.Ellipse;
	BEGIN
		NEW(e); LeoBasic.InitEllipse(e, 0, 0, 1, 1, LeoPens.Default); e.handle := HandleEllipse;
		Objects.NewObj := e
	END NewEllipse;
	
	
	(*--- Areas ---*)
	
	PROCEDURE HandleArea (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR
			area: LeoPaths.Path; ver: LONGINT; i: INTEGER; real: REAL; cm: Objects.CopyMsg; s: Leonardo.Shape;
			pm: LeoPaths.ContourMsg; bool: BOOLEAN;
	BEGIN
		IF msg IS Objects.FileMsg THEN
			WITH msg: Objects.FileMsg DO
				ASSERT(msg.id = Objects.load, 110);
				area := obj(LeoPaths.Path);
				
				(* shape part *)
				Files.ReadNum(msg.R, ver);
				ASSERT(ver IN {1, 2}, 111);
				IF ver = 1 THEN
					Files.ReadInt(msg.R, i); Files.ReadInt(msg.R, i); Files.ReadInt(msg.R, i); Files.ReadInt(msg.R, i);
					Files.ReadReal(msg.R, real)
				END;
				
				(* container part *)
				Files.ReadNum(msg.R, ver);
				ASSERT(ver = 1, 112);
				REPEAT
					Gadgets.ReadRef(msg.R, area.lib, obj);
					IF (obj # NIL) & (obj IS Leonardo.Shape) THEN
						Objects.Stamp(cm); cm.id := Objects.shallow; cm.obj := obj; obj.handle(obj, cm);
						s := cm.obj(Leonardo.Shape);
						pm.done := FALSE; s.handle(s, pm);
						IF pm.done THEN
							s.cont := area;
							IF area.bottom = NIL THEN area.bottom := s ELSE area.top.up := s END;
							s.down := area.top; area.top := s
						END
					END
				UNTIL obj = NIL;
				Leonardo.GetComponentsBox(area.bottom, area.llx, area.lly, area.urx, area.ury, area.bw);
				Files.ReadBool(msg.R, bool);
				
				(* area part *)
				Files.ReadNum(msg.R, ver);
				ASSERT(ver = 1, 113);
				Gadgets.ReadRef(msg.R, area.lib, obj);
				IF (obj # NIL) & (obj IS LeoPens.Pen) THEN
					area.pen := obj(LeoPens.Pen)
				END;
				
				area.handle := LeoPaths.HandlePath
			END
		ELSE
			LeoPaths.HandlePath(obj, msg)
		END
	END HandleArea;
	
	PROCEDURE NewArea*;
		VAR area: LeoPaths.Path;
	BEGIN
		NEW(area); LeoPaths.InitPath(area, NIL, NIL, LeoPens.Default); area.handle := HandleArea;
		Objects.NewObj := area
	END NewArea;
	

END Areas.
�BIER�  �   w    :       Z 
 ��    ��C  Oberon10.Scn.Fnt 10.05.00  17:00:48  TimeStamps.New  �