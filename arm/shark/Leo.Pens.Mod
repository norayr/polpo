�TextDocs.NewDoc     �M� e   Oberon10.Scn.Fnt  �   Syntax10.Scn.Fnt                           �   �
  (* ETH Oberon, Copyright 2000 ETH Z�rich Institut f�r Computersysteme, ETH Zentrum, CH-8092 Z�rich.
Refer to the general ETH Oberon System license contract available at: http://www.oberon.ethz.ch/ *)

MODULE Pens; (** portable **)	(* eos   *)

	(**
		Legacy support for figures created with Leonardo 0.x and 1.x
	**)
	
	IMPORT
		Files, Objects, Gfx, LeoPens;
		
	
	VAR
		Empty*: LeoPens.Pen;
		
	
	PROCEDURE HandleEmpty (obj: Objects.Object; VAR msg: Objects.ObjMsg);
	BEGIN
		(* because BindMsg isn't handled, any references to an empty pen turn into NIL when stored *)
		IF msg IS Objects.CopyMsg THEN
			msg(Objects.CopyMsg).obj := obj
		END
	END HandleEmpty;
	
	PROCEDURE BeginEmpty (pen: LeoPens.Pen; ctxt: Gfx.Context);
	END BeginEmpty;
	
	PROCEDURE EndEmpty (pen: LeoPens.Pen);
	END EndEmpty;
	
	PROCEDURE EnterEmpty (pen: LeoPens.Pen; x, y, dx, dy, off: REAL);
	END EnterEmpty;
	
	PROCEDURE ExitEmpty (pen: LeoPens.Pen; dx, dy, off: REAL);
	END ExitEmpty;
	
	PROCEDURE LineEmpty (pen: LeoPens.Pen; x, y: REAL);
	END LineEmpty;
	
	PROCEDURE ArcEmpty (pen: LeoPens.Pen; x, y, x0, y0, x1, y1, x2, y2: REAL);
	END ArcEmpty;
	
	PROCEDURE BezierEmpty (pen: LeoPens.Pen; x, y, x1, y1, x2, y2: REAL);
	END BezierEmpty;
	
	PROCEDURE RenderEmpty (pen: LeoPens.Pen; ctxt: Gfx.Context; VAR bdist, edist: ARRAY OF REAL; n: LONGINT);
	END RenderEmpty;
	
	PROCEDURE InitEmpty;
	BEGIN
		NEW(Empty);
		Empty.handle := HandleEmpty;
		NEW(Empty.do);
		Empty.do.begin := BeginEmpty; Empty.do.end := EndEmpty;
		Empty.do.enter := EnterEmpty; Empty.do.exit := ExitEmpty;
		Empty.do.line := LineEmpty; Empty.do.arc := ArcEmpty; Empty.do.bezier := BezierEmpty;
		Empty.do.render := RenderEmpty;
		Empty.destructive := FALSE; Empty.needDist := FALSE; Empty.zeroDistOnly := FALSE
	END InitEmpty;
	
	PROCEDURE NewEmptyStrokePen*;
	BEGIN
		Objects.NewObj := Empty
	END NewEmptyStrokePen;
	
	PROCEDURE NewEmptyFillPen*;
	BEGIN
		Objects.NewObj := Empty
	END NewEmptyFillPen;
	
	PROCEDURE HandleColorFillPen (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR pen: LeoPens.Filler; ch: CHAR; int: INTEGER;
	BEGIN
		IF msg IS Objects.FileMsg THEN
			WITH msg: Objects.FileMsg DO
				ASSERT(msg.id = Objects.load);
				pen := obj(LeoPens.Filler);
				Files.Read(msg.R, ch); pen.col.r := ORD(ch);
				Files.Read(msg.R, ch); pen.col.g := ORD(ch);
				Files.Read(msg.R, ch); pen.col.b := ORD(ch);
				Files.ReadInt(msg.R, int);
				pen.handle := LeoPens.HandleFiller
			END
		ELSE
			LeoPens.HandleFiller(obj, msg)
		END
	END HandleColorFillPen;
	
	PROCEDURE NewColorFillPen*;
		VAR pen: LeoPens.Filler;
	BEGIN
		NEW(pen); LeoPens.InitFiller(pen, Gfx.White); pen.handle := HandleColorFillPen;
		Objects.NewObj := pen
	END NewColorFillPen;
	
	PROCEDURE HandleColorStrokePen (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR pen: LeoPens.Stroker; ch: CHAR; int: INTEGER;
	BEGIN
		IF msg IS Objects.FileMsg THEN
			WITH msg: Objects.FileMsg DO
				ASSERT(msg.id = Objects.load);
				pen := obj(LeoPens.Stroker);
				Files.Read(msg.R, ch); pen.col.r := ORD(ch);
				Files.Read(msg.R, ch); pen.col.g := ORD(ch);
				Files.Read(msg.R, ch); pen.col.b := ORD(ch);
				Files.ReadInt(msg.R, int);
				pen.handle := LeoPens.HandleStroker
			END
		ELSE
			LeoPens.HandleStroker(obj, msg)
		END
	END HandleColorStrokePen;
	
	PROCEDURE NewColorStrokePen*;
		VAR pen: LeoPens.Stroker;
	BEGIN
		NEW(pen); LeoPens.InitStroker(pen, Gfx.Black, 0); pen.handle := HandleColorStrokePen;
		Objects.NewObj := pen
	END NewColorStrokePen;
	

BEGIN
	InitEmpty
END Pens.
�BIER�  �   S    :       Z 
 ��    ��C  Oberon10.Scn.Fnt 10.05.00  16:59:47  TimeStamps.New  �