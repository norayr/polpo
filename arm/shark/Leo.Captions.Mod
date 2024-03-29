�TextDocs.NewDoc     �� � e   Oberon10.Scn.Fnt  �   Syntax10.Scn.Fnt                           ?   5
  (* ETH Oberon, Copyright 2000 ETH Z�rich Institut f�r Computersysteme, ETH Zentrum, CH-8092 Z�rich.
Refer to the general ETH Oberon System license contract available at: http://www.oberon.ethz.ch/ *)

MODULE Captions; (** portable **)	(* eos   *)

	(**
		Legacy support for figures created with Leonardo 0.x and 1.x
	**)
	
	IMPORT
		Files, Objects, Display, Texts, Attributes, Strings, Gadgets, GfxMatrix, GfxFonts, Gfx, LeoCaptions;
		
	
	PROCEDURE HandleCaption (obj: Objects.Object; VAR msg: Objects.ObjMsg);
		VAR
			cap: LeoCaptions.Caption; ver: LONGINT; i, size: INTEGER; real, x, y: REAL; r: Texts.Reader; text: ARRAY 128 OF CHAR;
			ch: CHAR; name: ARRAY 64 OF CHAR; font: GfxFonts.Font; col: Gfx.Color; mat: GfxMatrix.Matrix;
	BEGIN
		IF msg IS Objects.FileMsg THEN
			WITH msg: Objects.FileMsg DO
				ASSERT(msg.id = Objects.load, 110);
				cap := obj(LeoCaptions.Caption);
				
				(* shape part *)
				Files.ReadNum(msg.R, ver);
				ASSERT(ver IN {1, 2}, 111);
				IF ver = 1 THEN
					Files.ReadInt(msg.R, i); Files.ReadInt(msg.R, i); Files.ReadInt(msg.R, i); Files.ReadInt(msg.R, i);
					Files.ReadReal(msg.R, real)
				END;
				
				(* caption part *)
				Files.ReadNum(msg.R, ver);
				ASSERT(ver = 1, 112);
				Gadgets.ReadRef(msg.R, cap.lib, obj);
				IF (obj # NIL) & (obj IS Texts.Text) THEN
					Texts.OpenReader(r, obj(Texts.Text), 0);
					Texts.Read(r, text[0]);
					IF ~r.eot THEN
						i := 0; ch := r.lib.name[0];
						WHILE ("A" <= CAP(ch)) & (CAP(ch) <= "Z") DO name[i] := ch; INC(i); ch := r.lib.name[i] END;
						name[i] := 0X;
						IF ("0" <= ch) & (ch <= "9") THEN
							size := 0;
							REPEAT
								size := 10*size + ORD(ch) - ORD("0");
								INC(i); ch := r.lib.name[i]
							UNTIL (ch < "0") OR ("9" < ch)
						ELSE
							size := 10
						END;
						IF ch = "i" THEN Strings.Append(name, "-Italic")
						ELSIF ch = "b" THEN Strings.Append(name, "-Bold")
						ELSIF ch = "m" THEN Strings.Append(name, "-Medium")
						ELSIF ch = "j" THEN Strings.Append(name, "-BoldItalic")
						END;
						font := GfxFonts.OpenSize(name, size);
						IF font = NIL THEN font := GfxFonts.Default END;
						
						Display.GetColor(r.col, col.r, col.g, col.b);
						
						i := 0; ch := text[0];
						WHILE (i < LEN(text)-1) & ~r.eot & (ch >= " ") DO
							text[i] := ch; INC(i);
							Texts.Read(r, ch)
						END;
						text[i] := 0X;
						
						LeoCaptions.Init(cap, 0, 0, text, font, col)
					END
				END;
				
				Gadgets.ReadRef(msg.R, cap.lib, obj);
				Attributes.GetReal(obj, "X", x); Attributes.GetReal(obj, "Y", y);
				Files.ReadInt(msg.R, i); Files.ReadInt(msg.R, i);	(* alignment, never used *)
				FOR i := 0 TO 2 DO
					Files.ReadReal(msg.R, mat[i, 0]); Files.ReadReal(msg.R, mat[i, 1]); Files.ReadReal(msg.R, real)
				END;
				mat[2, 0] := mat[2, 0] + x; mat[2, 1] := mat[2, 1] + y;
				GfxMatrix.Concat(cap.mat, mat, cap.mat);
				GfxMatrix.ApplyToRect(mat, cap.llx, cap.lly, cap.urx, cap.ury, cap.llx, cap.lly, cap.urx, cap.ury);
				GfxMatrix.ApplyToDist(mat, cap.bw, cap.bw);
				
				cap.handle := LeoCaptions.Handle
			END
		ELSE
			LeoCaptions.Handle(obj, msg)
		END
	END HandleCaption;
	
	PROCEDURE NewCaption*;
		VAR cap: LeoCaptions.Caption;
	BEGIN
		NEW(cap); LeoCaptions.Init(cap, 0, 0, "", GfxFonts.Default, Gfx.Black); cap.handle := HandleCaption;
		Objects.NewObj := cap
	END NewCaption;
	

END Captions.
�BIER     �
    :       Z 
 ��    ��C  Oberon10.Scn.Fnt 10.05.00  17:01:01  TimeStamps.New  �