�TextDocs.NewDoc     �� � e   Oberon10.Scn.Fnt  �   Syntax10.Scn.Fnt                           6   *  (* ETH Oberon, Copyright 2000 ETH Z�rich Institut f�r Computersysteme, ETH Zentrum, CH-8092 Z�rich.
Refer to the general ETH Oberon System license contract available at: http://www.oberon.ethz.ch/ *)

MODULE Shapes; (** portable **)	(* eos   *)

	(**
		Legacy support for figures created with Leonardo 0.x and 1.x
	**)
	
	IMPORT
		Files, Objects, Attributes, Gadgets, Leonardo, LeoBasic, LeoPaths;
		
	
	(*--- Points ---*)
	
	PROCEDURE HandlePoint (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR p: LeoPaths.Point; ver: LONGINT;
	BEGIN
		IF msg IS Objects.FileMsg THEN
			WITH msg: Objects.FileMsg DO
				ASSERT(msg.id = Objects.load, 110);
				p := obj(LeoPaths.Point);
				Files.ReadNum(msg.R, ver);
				Files.ReadReal(msg.R, p.x); Files.ReadReal(msg.R, p.y);
				p.llx := p.x - 0.5; p.lly := p.y - 0.5; p.urx := p.x + 0.5; p.ury := p.y + 0.5;
				p.handle := LeoPaths.HandlePoint
			END
		ELSE
			LeoPaths.HandlePoint(obj, msg)
		END
	END HandlePoint;
	
	PROCEDURE NewPoint*;
		VAR p: LeoPaths.Point;
	BEGIN
		NEW(p); LeoPaths.InitPoint(p, 0, 0); p.handle := HandlePoint;
		Objects.NewObj := p
	END NewPoint;
	
	
	(*--- Container ---*)
	
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
		
	
	(*--- Group ---*)
	
	PROCEDURE HandleGroup* (obj: Objects.Object; VAR msg: Objects.ObjMsg);
	BEGIN
		IF msg IS Objects.FileMsg THEN
			WITH msg: Objects.FileMsg DO
				ASSERT(msg.id = Objects.load, 110);
				ReadContainer(msg.R, obj(LeoBasic.Group));
				obj.handle := LeoBasic.HandleGroup
			END
		ELSE
			LeoBasic.HandleGroup(obj, msg)
		END
	END HandleGroup;
	
	PROCEDURE NewGroup*;
		VAR group: LeoBasic.Group;
	BEGIN
		NEW(group); LeoBasic.InitGroup(group, NIL, NIL); group.handle := HandleGroup;
		Objects.NewObj := group
	END NewGroup;
	
	
	(*--- Figure Container (Layer) ---*)
	
	PROCEDURE HandleFigureContainer (obj: Objects.Object; VAR msg: Objects.ObjMsg);
	BEGIN
		IF msg IS Objects.FileMsg THEN
			WITH msg: Objects.FileMsg DO
				ASSERT(msg.id = Objects.load, 110);
				ReadContainer(msg.R, obj(Leonardo.Layer));
				obj.handle := Leonardo.HandleLayer
			END
		ELSE
			Leonardo.HandleLayer(obj, msg)
		END
	END HandleFigureContainer;
	
	PROCEDURE NewFigureContainer*;
		VAR layer: Leonardo.Layer;
	BEGIN
		NEW(layer); Leonardo.InitLayer(layer, "Main", TRUE, TRUE, TRUE); layer.handle := HandleFigureContainer;
		Objects.NewObj := layer
	END NewFigureContainer;
	
	
	(*--- Figures ---*)
	
	PROCEDURE HandleFigure (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR
			fig: Leonardo.Figure; ver, len: LONGINT; ref, int: INTEGER; id: CHAR; lib: Objects.Library;
			layer: Leonardo.Layer; real: REAL;
	BEGIN
		IF msg IS Objects.FileMsg THEN
			WITH msg: Objects.FileMsg DO
				ASSERT(msg.id = Objects.load, 110);
				fig := obj(Leonardo.Figure);
				Files.ReadNum(msg.R, ver);
				IF ver IN {1, 2} THEN
					Files.ReadInt(msg.R, ref); Files.Read(msg.R, id);
					NEW(lib); Objects.OpenLibrary(lib);
					Objects.LoadLibrary(lib, Files.Base(msg.R), Files.Pos(msg.R), len);
					Files.Set(msg.R, Files.Base(msg.R), Files.Pos(msg.R) + len);
					lib.GetObj(lib, ref, obj);
					layer := obj(Leonardo.Layer); layer.fig := fig;
					fig.bottom := layer; fig.top := layer; fig.active := layer;
					IF ver = 2 THEN
						Files.ReadInt(msg.R, int); Attributes.SetInt(fig, "UndoLimit", int);
						Files.ReadReal(msg.R, real); Files.ReadReal(msg.R, real)
					END
				END;
				fig.handle := Leonardo.HandleFigure
			END
		ELSE
			Leonardo.HandleFigure(obj, msg)
		END
	END HandleFigure;
	
	PROCEDURE NewFigure*;
		VAR fig: Leonardo.Figure;
	BEGIN
		NEW(fig); Leonardo.InitFigure(fig); fig.handle := HandleFigure;
		Objects.NewObj := fig
	END NewFigure;
	

END Shapes.
�BIER�  
   �    :       Z 
 ��    ��C  Oberon10.Scn.Fnt 10.05.00  17:00:24  TimeStamps.New  �