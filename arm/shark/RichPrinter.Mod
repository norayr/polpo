�TextDocs.NewDoc     �/�#   Oberon10.Scn.Fnt  c   c  MODULE RichPrinter;
	
IMPORT Fonts, Strings, Texts, Oberon;

VAR
	W: Texts.Writer;
	
	PROCEDURE Val(ch: CHAR): INTEGER;
	BEGIN
		IF ("0" <= ch) & (ch <= "9") THEN
			RETURN ORD(ch) - ORD("0")
		ELSIF ("A" <= ch) & (ch <= "Z") THEN
			RETURN (ORD(ch) - ORD("A"))+ (ORD("9") - ORD("0") + 1)
		ELSIF ("a" <= ch) & (ch <= "z") THEN
			RETURN (ORD(ch) - ORD("a")) + (ORD("9") - ORD("0") + 1) + (ORD("Z") - ORD("A") + 1)
		END;
	END Val;
	
	
	PROCEDURE Print* (font, variant, size, color, ch: CHAR);
		VAR 
			fname: ARRAY 32 OF CHAR;
			sizeStr: ARRAY 8 OF CHAR;
	BEGIN
		CASE font OF
		| "s": fname := "Oberon";
		| "t": fname := "Times";
		| "c": fname := "Courier";
		| "m": fname := "Math";
		END;
		Strings.IntToStr(Val(size), sizeStr);
		Strings.Append(fname, sizeStr);
		CASE variant OF
		| "n": Strings.Append(fname, ".Scn.Fnt");
		| "i": Strings.Append(fname, "i.Scn.Fnt");
		| "b": Strings.Append(fname, "b.Scn.Fnt");
		END;
		Texts.SetFont(W, Fonts.This(fname));
		Texts.SetColor(W, SHORT(Val(color)));
		Texts.Write(W, ch);
		Texts.Append(Oberon.Log, W.buf)
	END Print;
	
BEGIN
	Texts.OpenWriter(W);
END RichPrinter.