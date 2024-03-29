�TextDocs.NewDoc     ���#   Syntax10.Scn.Fnt  v
   v
  MODULE DisplayBench;

IMPORT Display,Kernel,Out,Strings;

VAR
	copyBlockTime, copyBlockPixels : LONGINT;
	copyPatternTime : ARRAY 3 OF LONGINT;
	copyPatternPixels : LONGINT;
	replPatternTime : ARRAY 3 OF LONGINT;
	replPatternPixels : LONGINT;
	replConstTime : ARRAY 3 OF LONGINT;
	replConstPixels : LONGINT;
	t, t2 : LONGINT;
	loopTime : LONGINT;

PROCEDURE OutSecs(ticks : LONGINT);
VAR s : ARRAY 20 OF CHAR;
BEGIN
	Strings.RealToStr(ticks/Kernel.TimeUnit,s);
	Out.String(s); Out.String(" sec");
END OutSecs;

PROCEDURE OutPPS(pix,ticks : LONGINT);
VAR s : ARRAY 20 OF CHAR; sec : REAL;
BEGIN
	sec:=ticks/Kernel.TimeUnit;
	Strings.RealToStr(pix/sec,s);
	Out.String(s); Out.String(" pps");
END OutPPS;


PROCEDURE Do*;
VAR mode, i,j: INTEGER; 
BEGIN	
	t:=Kernel.GetTimer();
	FOR i:=0 TO 10 DO FOR j:=0 TO 650 DO END END;
	t2:=Kernel.GetTimer();
	loopTime:=t2-t;


	t:=Kernel.GetTimer();
	FOR i:=0 TO 10 DO
		FOR j:=0 TO 650 DO
			Display.CopyBlock(0,Display.Height-100,100,100,j,j,mode);
		END
	END;
	t2:=Kernel.GetTimer();
	copyBlockTime:=t2-t-loopTime;
	copyBlockPixels:=6510000;	
	
	FOR mode:=0 TO 2 DO
		t:=Kernel.GetTimer();
		FOR i:=0 TO 10 DO
			FOR j:=0 TO 650 DO
				Display.CopyPattern(12, Display.arrow,j,j,mode);
			END
		END;
		t2:=Kernel.GetTimer();
		copyPatternTime[mode]:=t2-t-loopTime;
	END;
	copyPatternPixels:=LONG(15)*LONG(15)*651;
	
	FOR mode:=0 TO 2 DO
		t:=Kernel.GetTimer();
		FOR i:=0 TO 10 DO
			FOR j:=0 TO 650 DO
				Display.ReplPattern(12, Display.arrow,j,j,100,100,mode);
			END
		END;
		t2:=Kernel.GetTimer();
		replPatternTime[mode]:=t2-t-loopTime;
	END;
	replPatternPixels:=6510000;

	FOR mode:=0 TO 2 DO
		t:=Kernel.GetTimer();
		FOR i:=0 TO 10 DO
			FOR j:=0 TO 650 DO
				Display.ReplConst(3, j,j,100,100,mode);
			END
		END;
		t2:=Kernel.GetTimer();
		replConstTime[mode]:=t2-t-loopTime;
		replConstPixels:=6510000;
	END;


	Out.String("CopyBlock: "); OutSecs(copyBlockTime); Out.String("  "); OutPPS(copyBlockPixels,copyBlockTime); Out.Ln;
	Out.String("CopyPattern: "); Out.Ln;
	FOR i:=0 TO 2 DO 
		Out.String("mode="); Out.Int(i,1);  Out.String("  ");
		OutSecs(copyPatternTime[i]); Out.String("  "); 
		OutPPS(copyPatternPixels,copyPatternTime[i]); Out.Ln 
	END; 
	Out.String("ReplPattern: "); Out.Ln;
	FOR i:=0 TO 2 DO 
		Out.String("mode="); Out.Int(i,1);  Out.String("  ");
		OutSecs(replPatternTime[i]); Out.String("  "); 
		OutPPS(replPatternPixels,replPatternTime[i]); Out.Ln 
	END; 
	Out.String("ReplConst: "); Out.Ln;
	FOR i:=0 TO 2 DO  
		Out.String("mode="); Out.Int(i,1);  Out.String("  ");
		OutSecs(replConstTime[i]); Out.String("  "); 
		OutPPS(replConstPixels,replConstTime[i]); Out.Ln 
	END; 
END Do;

END DisplayBench.Do