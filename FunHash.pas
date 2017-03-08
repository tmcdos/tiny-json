unit FunHash;

interface

Function FunHash32(d:PAnsiChar; len:Integer; seed:Cardinal = $9e3779b9):Cardinal;

implementation

Const
  FH_C1 = $b8b34b2d;
  FH_C2 = $52c6a2d9;

{$OVERFLOWCHECKS OFF}

Function FunHash32(d:PAnsiChar; len:Integer; seed:Cardinal = $9e3779b9):Cardinal;
var
  a,b,c,t:Cardinal;
  n:Integer;
Begin
	a := seed xor (2 shl 16);
  b := seed;
	case len of
    0: t:=0;
    1: t:=PByte(d)^;
    2: t:=PWord(d)^;
    3: t:=(PWord(d+1)^ Shl 8) or PByte(d)^;
    else
    begin
      n := len div 4;
      while n<>0 do
      begin
        // reference formula
        c:=a xor PCardinal(d)^;
        a := ((Word(c) shl 16) or (c shr 16)) * FH_C1;
        b := (Word(b) Shl 16) Or (c shr 16);
        b := (b xor PCardinal(d)^) * FH_C2;
        Dec(n);
        Inc(d,4);
      end;
      t := PCardinal(d-(4-(len and 3)))^;
    end;
	end;
  len:=(Word(Len) shl 16) or (Len Shr 16);
	b:=b xor Len;
  c:=a xor t;
	a := ((Word(c) Shl 16) or (c shr 16)) * FH_C1;
  b := (Word(b) Shl 16) or (b shr 16);
	b := (b xor t) * FH_C2;

	a:=a xor (a shr 17);
	b:=b xor (b shr 16);
	a:=a * FH_C1;
	b:=b * FH_C2;
	Result:= a xor b xor (a shr 16) xor (b shr 17);
End;

end.
 
