unit JSONTests;

interface

uses
  JSON,
  TestFrameWork;

type
  TJSONhack = class(TJSONbase)
  end;

  TJSONbaseTests = class(TTestCase)
  Private
    Procedure Enum2(Nomer:Integer; Elem:TJSONbase; Data:Pointer; Var Stop:Boolean);
  protected

//    procedure SetUp; override;
//    procedure TearDown; override;

  published

    // Test methods
    procedure TestCreate;
    Procedure TestCreateParent;
    procedure TestValue;
    procedure TestClear;
    procedure TestDelete1;
    procedure TestDelete2;
    procedure TestRemove1;
    procedure TestRemove2;
    procedure TestForEach1;
    procedure TestForEach2;
    procedure TestAdd;
    procedure TestAdd2;
    Procedure TestParse;
  end;

implementation

uses Variants,SysUtils;

procedure Enum1(Nomer:Integer; Elem:TJSONbase; Data:Pointer; Var Stop:Boolean);
Begin
  case Nomer Of
    0: TJSONbaseTests(Data).CheckTrue((Elem.ID=-1)and(Elem.Name='2'),'Invalid ID/Key for 0;');
    1: TJSONbaseTests(Data).CheckTrue((Elem.ID=3)and(Elem.Name=''),'Invalid ID/Key for 1;');
    2: TJSONbaseTests(Data).CheckTrue((Elem.ID=-1)and(Elem.Name='d'),'Invalid ID/Key for 2;');
  end;
end;

procedure TJSONbaseTests.Enum2(Nomer: Integer; Elem: TJSONbase; Data: Pointer; var Stop: Boolean);
begin
  case Nomer Of
    0: CheckTrue((Data=Pointer(8))And(Elem.ID=-1)and(Elem.Name='2'),'Invalid ID/Key for 0;');
    1: CheckTrue((Data=Pointer(8))And(Elem.ID=3)and(Elem.Name=''),'Invalid ID/Key for 1;');
    2: CheckTrue((Data=Pointer(8))And(Elem.ID=-1)and(Elem.Name='d'),'Invalid ID/Key for 2;');
  end;
end;

procedure TJSONbaseTests.TestForEach1;
var
  js:TJSONbase;
begin
  js:=Nil;
  try
    js:=TJSONbase.Create;
    js.Add('2',True);
    js.Add(5);
    js.Add('d',2.5);
    js.ForEach(ENum1,Self);
  Finally
    js.free;
  End;
end;

procedure TJSONbaseTests.TestForEach2;
var
  js:TJSONbase;
begin
  js:=Nil;
  try
    js:=TJSONbase.Create;
    js.Add('2',True);
    js.Add(5);
    js.Add('d',2.5);
    js.ForEach(ENum2,Pointer(8));
  Finally
    js.free;
  End;
end;

procedure TJSONbaseTests.TestClear;
var
  js,js2,js3,t:TJSONbase;
begin
  js:=Nil;
  Try
    js:=TJSONbase.Create;
    js2:=TJSONbase.Create;
    js3:=TJSONbase.Create;
    TJSONhack(js).Append(js2);
    TJSONhack(js).Append(js3);
    t:=js.FirstChild;
    CheckTrue(t = js2,'FirstChild <> js2;');
    t:=t.Next;
    CheckTrue(t = js3,'Next <> js3;');
    CheckTrue(t = js.LastChild,'Next <> LastChild;');
    t:=t.Next;
    CheckTrue(t = NIL,'T_end <> NIL;');
    t:=js.LastChild;
    CheckTrue(t = js3,'LastChild <> js3;');
    t:=t.Prev;
    CheckTrue(t = js2,'Prev <> js2;');
    t:=t.Prev;
    CheckTrue(t = NIL,'T_beg <> NIL;');
    js.Clear;
    CheckEquals(0,js.Count,'Count <> 0;');
  Finally
    js.Free;
  end;
end;

procedure TJSONbaseTests.TestCreate;
var
  js,t:TJSONbase;
  i:Integer;
begin
  js:=Nil;
  Try
    js:=TJSONbase.Create;
    // testing private members
    CheckTrue(TJSONhack(js).FType = jsNull,'FType <> jsNULL;');
    CheckTrue(TJSONhack(js).FChildCnt = 0,'FChildCnt <> 0;');
    CheckTrue(TJSONhack(js).FValue = Null,'FValue <> NULL;');
    CheckTrue(TJSONhack(js).FParent = NIL,'FParent <> NIL;');
    CheckTrue(TJSONhack(js).FChildFirst = NIL,'FChildFirst <> NIL;');
    CheckTrue(TJSONhack(js).FChildLast = NIL,'FChildLast <> NIL;');
    CheckTrue(TJSONhack(js).FPrev = NIL,'FPrev <> NIL;');
    CheckTrue(TJSONhack(js).FNext = NIL,'FNext <> NIL;');
    CheckTrue(TJSONhack(js).FList <> NIL,'FList = NIL;');
    CheckTrue(TJSONhack(js).FKey = '','FKey is not empty;');
    CheckTrue(TJSONhack(js).FIndex = 0,'FIndex <> 0;');
    CheckTrue(TJSONhack(js).FNextID = 0,'FNextID <> 0;');
    CheckFalse(TJSONhack(js).FAssoc,'FAssoc is TRUE;');
    // testing public properties
    CheckTrue(js.SelfType = jsNull,'FType is not jsNULL;');
    try
      i:=js.Count;
      CheckFalse(True,'Count() must throw an exception when <> jsArray;');
    Except
      on E:TJSONError do CheckTrue(True,'Count() has thrown an exception when <> jsArray;');
    End;
    CheckTrue(js.Value = Null,'Value <> NULL;');
    CheckTrue(js.Parent = NIL,'Parent <> NIL;');
    CheckTrue(js.FirstChild = NIL,'FirstChild <> NIL;');
    CheckTrue(js.LastChild = NIL,'LastChild <> NIL;');
    CheckTrue(js.Prev = NIL,'Prev <> NIL;');
    CheckTrue(js.Next = NIL,'Next <> NIL;');
    CheckTrue(js.Name = '','Key is not empty;');
    CheckTrue(js.ID = 0,'ID <> 0;');
    CheckFalse(js.Assoc,'Assoc is TRUE;');
    try
      t:=js.Child[1];
      CheckFalse(True,'Child[] must throw an exception when <> jsArray;');
    Except
      on E:TJSONError do CheckTrue(True,'Child[] has thrown an exception when <> jsArray;');
    End;
    try
      t:=js.Field['1'];
      CheckFalse(True,'Field[] must throw an exception when <> jsArray;');
    Except
      on E:TJSONError do CheckTrue(True,'Field[] has thrown an exception when <> jsArray;');
    End;
    CheckEqualsString('null',js.Text,'JsonEncode <> "null";');
  Finally
    js.Free;
  End;
end;

procedure TJSONbaseTests.TestCreateParent;
var
  js,js2,js3:TJSONbase;
  v:Variant;
begin
  js:=Nil;
  Try
    js:=TJSONbase.Create;
    js2:=TJSONbase.Create;
    TJSONhack(js).Append(js2);
    // testing private members
    CheckTrue(TJSONhack(js).FType = jsArray,'FType <> jsArray;');
    CheckTrue(TJSONhack(js).FChildCnt = 1,'FChildCnt <> 1;');
    CheckTrue(TJSONhack(js2).FParent = js,'FParent_1 is wrong;');
    CheckTrue(TJSONhack(js).FChildFirst = js2,'FChildFirst <> js2;');
    CheckTrue(TJSONhack(js).FChildLast = js2,'FChildLast <> js2;');
    CheckTrue(TJSONhack(js).FPrev = NIL,'FPrev <> NIL;');
    CheckTrue(TJSONhack(js).FNext = NIL,'FNext <> NIL;');
    CheckTrue(TJSONhack(js).FList <> NIL,'FList = NIL;');
    CheckTrue(TJSONhack(js).FKey = '','FKey is not empty;');
    CheckTrue(TJSONhack(js).FIndex = 0,'FIndex <> 0;');
    CheckFalse(TJSONhack(js).FAssoc,'FAssoc is TRUE;');
    // testing public properties
    CheckTrue(js.SelfType = jsArray,'FType is not jsArray;');
    CheckEquals(1,js.Count,'Count <> 1;');
    try
      v:=js.Value;
      CheckFalse(True,'GetValue() must throw an exception when jsArray;');
    Except
      on E:TJSONError do CheckTrue(True,'GetValue() has thrown an exception when jsArray;');
    End;
    CheckTrue(js2.Parent = js,'Parent is wrong;');
    CheckTrue(js.FirstChild = js2,'FirstChild <> js2;');
    CheckTrue(js.LastChild = js2,'LastChild <> js2;');
    CheckTrue(js.Prev = NIL,'Prev <> NIL;');
    CheckTrue(js.Next = NIL,'Next <> NIL;');
    CheckTrue(js.Name = '','Key is not empty;');
    CheckTrue(js.ID = 0,'ID <> 0;');
    CheckFalse(js.Assoc,'Assoc is TRUE;');
    // test another child
    js3:=TJSONbase.Create;
    TJSONhack(js).Append(js3);
    CheckTrue(TJSONhack(js).FChildCnt = 2,'FChildCnt <> 2;');
    CheckTrue(TJSONhack(js3).FParent = js,'FParent_2 is wrong;');
    CheckTrue(TJSONhack(js).FChildFirst = js2,'FChildFirst <> js2;');
    CheckTrue(TJSONhack(js).FChildLast = js3,'FChildLast <> js3;');
    CheckTrue(TJSONhack(js3).FPrev = js2,'FPrev_3 <> js2;');
    CheckTrue(TJSONhack(js2).FNext = js3,'FNext_2 <> js3;');
    CheckEquals(2,js.Count,'Count <> 2;');
  Finally
    js.Free;
  end;
end;

procedure TJSONbaseTests.TestValue;
Const
  s:AnsiString = 'abc';
  w:WideString = 'рст';
var
  js:TJSONbase;
begin
  js:=Nil;
  Try
    js:=TJSONbase.Create;
    // testing Boolean
    js.Value:=True;
    CheckTrue(js.Value,'Value <> TRUE;');
    CheckTrue(js.SelfType = jsBool,'Type <> Boolean;');
    CheckEqualsString('true',js.Text,'Text <> "true";');
    js.Value:=False;
    CheckFalse(js.Value,'Value <> FALSE;');
    CheckTrue(js.SelfType = jsBool,'Type <> Boolean;');
    CheckEqualsString('false',js.Text,'Text <> "false";');
    js.Value:=Null;
    CheckTrue(js.Value = Null,'Value <> NULL;');
    CheckTrue(js.SelfType = jsNull,'Type <> NULL;');
    // testing Integer
    js.Value:=1;
    CheckTrue(js.Value = 1,'Value <> 1;');
    CheckTrue(js.SelfType = jsInt,'Type <> Integer;');
    CheckEqualsString('1',js.Text,'Text <> "1";');
    js.Value:=-1;
    CheckTrue(js.Value = -1,'Value <> -1;');
    CheckTrue(js.SelfType = jsInt,'Type <> Integer;');
    CheckEqualsString('-1',js.Text,'Text <> "-1";');
    js.Value:=500;
    CheckTrue(js.Value = 500,'Value <> 500;');
    CheckTrue(js.SelfType = jsInt,'Type <> Integer;');
    CheckEqualsString('500',js.Text,'Text <> "500";');
    js.Value:=-500;
    CheckTrue(js.Value = -500,'Value <> -500;');
    CheckTrue(js.SelfType = jsInt,'Type <> Integer;');
    CheckEqualsString('-500',js.Text,'Text <> "500";');
    js.Value:=200000;
    CheckTrue(js.Value = 200000,'Value <> 200 000;');
    CheckTrue(js.SelfType = jsInt,'Type <> Integer;');
    CheckEqualsString('200000',js.Text,'Text <> "200000";');
    js.Value:=-200000;
    CheckTrue(js.Value = -200000,'Value <> -200 000;');
    CheckTrue(js.SelfType = jsInt,'Type <> Integer;');
    CheckEqualsString('-200000',js.Text,'Text <> "-200000";');
    js.Value:=2000000000000;
    CheckTrue(js.Value = 2000000000000,'Value <> 2 000 000 000 000;');
    CheckEqualsString('2000000000000',js.Text,'Text <> "2000000000000";');
    CheckTrue(js.SelfType = jsInt,'Type <> Integer;');
    js.Value:=-2000000000000;
    CheckTrue(js.Value = -2000000000000,'Value <> -2 000 000 000 000;');
    CheckTrue(js.SelfType = jsInt,'Type <> Integer;');
    CheckEqualsString('-2000000000000',js.Text,'Text <> "-2000000000000";');
    // testing double
    js.Value:=3.1415;
    CheckTrue(js.Value = 3.1415,'Value <> 3.1415;');
    CheckTrue(js.SelfType = jsFloat,'Type <> Float;');
    CheckEqualsString('3.1415',js.Text,'Text <> "3.1415";');
    // testing AnsiString
    js.Value:=s;
    CheckEqualsString(s,js.Value,'Value <> abc;');
    CheckTrue(js.SelfType = jsString,'Type <> String;');
    CheckEqualsString('"abc"',js.Text,'Text <> "abc";');
    // testing WideString
    js.Value:=w;
    CheckEqualsWideString(w,js.Value,'Value <> рст;');
    CheckTrue(js.SelfType = jsString,'Type <> String;');
    CheckEqualsString('"\u0430\u0431\u0432"',js.Text,'Text <> "рст";');
  Finally
    js.Free;
  end;
end;

procedure TJSONbaseTests.TestAdd;
var
  js,t,q:TJSONbase;
  i:Integer;
begin
  js:=Nil;
  Try
    js:=TJSONbase.Create;
    js.Add(True);
    js.Add(20);
    js.Add(3.1415);
    js.Add('abc');
    CheckEquals(4,js.Count,'Count <> 4;');
    i:=0;
    q:=js.FirstChild;
    While Assigned(q) Do
    begin
      t:=js.Child[i];
      CheckTrue(Assigned(t),'Child['+IntToStr(i)+'] is not assigned;');
      case i Of
        0: CheckTrue(t.Value,'Child[0] <> TRUE;');
        1: CheckEquals(20,t.Value,'Child[1] <> 20;');
        2: CheckEquals(3.1415,t.Value,0.00005,'Child[2] <> 3.1415;');
        3: CheckEqualsWideString('abc',t.Value,'Child[3] <> "abc";');
      end;
      CheckTrue(t = q,'t <> q;');
      t:=js.Field[IntToStr(i)];
      CheckTrue(Assigned(t),'Field['+IntToStr(i)+'] is not assigned;');
      q:=q.Next;
      Inc(i);
    end;
    t:=js.Child[i];
    CheckFalse(Assigned(t),'Child[4] is assigned;');
    t:=js.Field['5'];
    CheckFalse(Assigned(t),'Field[5] is assigned;');
  Finally
    js.Free;
  end;
end;

procedure TJSONbaseTests.TestAdd2;
var
  js,t,q:TJSONbase;
  i:Integer;
begin
  js:=Nil;
  Try
    js:=TJSONbase.Create;
    js.Add('a',True);
    js.Add('2',20);
    js.Add(3.1415);
    js.Add('d','abc');
    CheckEquals(4,js.Count,'Count <> 4;');
    i:=0;
    q:=js.FirstChild;
    While Assigned(q) Do
    begin
      case i Of
        0:
          Begin
            t:=js.Field['a'];
            CheckTrue(Assigned(t),'Field[a] is not assigned;');
            CheckTrue(t.Value,'Field[a] <> TRUE;');
          end;
        1:
          Begin
            t:=js.Field['2'];
            CheckTrue(Assigned(t),'Field[2] is not assigned;');
            CheckEquals(20,t.Value,'Field[2] <> 20;');
          End;
        2:
          Begin
            t:=js.Child[3];
            CheckTrue(Assigned(t),'Child[3] is not assigned;');
            CheckEquals(3.1415,t.Value,0.00005,'Child[3] <> 3.1415;');
          End;
        3:
          Begin
            t:=js.Field['d'];
            CheckTrue(Assigned(t),'Field[d] is not assigned;');
            CheckEqualsWideString('abc',t.Value,'Field[d] <> "abc";');
          end;
      end;
      CheckTrue(t = q,'t <> q;');
      q:=q.Next;
      Inc(i);
    end;
    t:=js.Child[i];
    CheckFalse(Assigned(t),'Child[4] is assigned;');
  Finally
    js.Free;
  end;
end;

procedure TJSONbaseTests.TestDelete1;
var
  js,t,q:TJSONbase;
  c:Currency;
begin
  js:=Nil;
  try
    js:=TJSONbase.Create;
    js.Add('2',True);
    js.Add(5);
    c:=2.5;
    js.Add('d',c);
    CheckEquals(3,js.Count,'Count <> 3;');
    t:=js.Child[2];
    CheckTrue(Assigned(t),'Child[2] is not assigned;');
    t:=js.Field['d'];
    CheckTrue(Assigned(t),'Field[d] is not assigned;');
    CheckEquals(2.5,t.Value,'Value <> 2.5;');
    t:=js.Child[3];
    CheckTrue(Assigned(t),'Child[3] is not assigned;');
    CheckEquals(5,t.Value,'Value <> 5;');
    CheckEqualsString('{"2":true,"3":5,"d":2.5}',js.Text,'Wrong js.Text;');
    // delete middle item
    js.Delete(3);
    CheckEquals(2,js.Count,'Count <> 2;');
    t:=js.Field['2'];
    q:=js.Field['d'];
    CheckTrue(Assigned(t),'Field[2] is not assigned;');
    CheckTrue(Assigned(q),'Q is not assigned;');
    CheckTrue(t = js.FirstChild,'T <> FirstChild;');
    CheckTrue(q = js.LastChild,'Q <> LastChild;');
    CheckTrue(t.Next = q,'T.Next <> Q;');
    CheckTrue(q.Prev = t,'Q.Prev <> T;');
    CheckTrue(js.Assoc,'Assoc <> TRUE;');
    // delete all items
    js.Delete(2);
    js.Delete('d');
    CheckEquals(0,js.Count,'Count <> 0;');
    CheckFalse(js.Assoc,'Assoc <> FALSE;');
    CheckTrue(js.Text = '[]','Text <> [];');
  Finally
    js.Free;
  End;
end;

procedure TJSONbaseTests.TestDelete2;
var
  js,t,q:TJSONbase;
  c:Currency;
begin
  js:=Nil;
  try
    js:=TJSONbase.Create;
    js.Add('2',True);
    c:=2.5;
    js.Add('d',c);
    js.Add(5);
    CheckEquals(3,js.Count,'Count <> 3;');
    CheckEqualsString('{"2":true,"d":2.5,"3":5}',js.Text,'Wrong js.Text;');
    // delete middle item
    js.Delete('d');
    CheckEquals(2,js.Count,'Count <> 2');
    t:=js.Field['2'];
    q:=js.Child[3];
    CheckTrue(Assigned(t),'Field[2] is not assigned;');
    CheckTrue(Assigned(q),'Q is not assigned;');
    CheckTrue(t = js.FirstChild,'T <> FirstChild');
    CheckTrue(q = js.LastChild,'Q <> LastChild');
    CheckTrue(t.Next = q,'T.Next <> Q;');
    CheckTrue(q.Prev = t,'Q.Prev <> T;');
    // delete all items
    js.Delete(2);
    js.Delete(3);
    CheckEquals(0,js.Count,'Count <> 0;');
    CheckFalse(js.Assoc,'Assoc <> FALSE;');
    CheckTrue(js.Text = '[]','Text <> [];');
  Finally
    js.Free;
  End;
end;

procedure TJSONbaseTests.TestRemove1;
var
  js,js2,t,q:TJSONbase;
  c:Currency;
begin
  js:=Nil;
  try
    js:=TJSONbase.Create;
    js.Add('2',True);
    js.Add(5);
    c:=2.5;
    js.Add('d',c);
    CheckEquals(3,js.Count,'Count <> 3;');
    t:=js.Child[2];
    CheckTrue(Assigned(t),'Child[2] is not assigned;');
    t:=js.Field['d'];
    CheckTrue(Assigned(t),'Field[d] is not assigned;');
    CheckEquals(2.5,t.Value,'Value <> 2.5;');
    t:=js.Child[3];
    CheckTrue(Assigned(t),'Child[3] is not assigned;');
    CheckEquals(5,t.Value,'Value <> 5;');
    // delete middle item
    js2:=js.Remove(3);
    CheckEquals(2,js.Count,'Count <> 2');
    t:=js.Field['2'];
    q:=js.Field['d'];
    CheckTrue(Assigned(t),'Field[2] is not assigned;');
    CheckTrue(Assigned(q),'Q is not assigned;');
    CheckTrue(t = js.FirstChild,'T <> FirstChild');
    CheckTrue(q = js.LastChild,'Q <> LastChild');
    CheckTrue(t.Next = q,'T.Next <> Q;');
    CheckTrue(q.Prev = t,'Q.Prev <> T;');
    CheckEquals(5,js2.Value,'Deleted value <> 5;');
  Finally
    js2.Free;
    js.Free;
  End;
end;

procedure TJSONbaseTests.TestRemove2;
var
  js,js2,t,q:TJSONbase;
  c:Currency;
begin
  js:=Nil;
  try
    js:=TJSONbase.Create;
    js.Add('2',True);
    c:=2.5;
    js.Add('d',c);
    js.Add(5);
    CheckEquals(3,js.Count,'Count <> 3;');
    // delete middle item
    js2:=js.Remove('d');
    CheckEquals(2,js.Count,'Count <> 2');
    t:=js.Field['2'];
    q:=js.Child[3];
    CheckTrue(Assigned(t),'Field[2] is not assigned;');
    CheckTrue(Assigned(q),'Q is not assigned;');
    CheckTrue(t = js.FirstChild,'T <> FirstChild');
    CheckTrue(q = js.LastChild,'Q <> LastChild');
    CheckTrue(t.Next = q,'T.Next <> Q;');
    CheckTrue(q.Prev = t,'Q.Prev <> T;');
    CheckEquals(2.5,js2.Value,'Deleted value <> 2.5;');
  Finally
    js.Free;
  End;
end;

procedure TJSONbaseTests.TestParse;
Const
  s1:AnsiString = '{"a":true,"2":2,"d":3.1415,"x":"y"}';
  s2:AnsiString = '[true,2,3.1415,"abc"]';
  s3:AnsiString = '[1,{"a":2,"b":3},4]';
  s4:AnsiString = '{"z":[1,{"z":4},3],"x":2}';
  s5:AnsiString = '{"cmd":"stop"';
var
  js:TJSONbase;
begin
  js:=Nil;
  try
    js:=ParseJSON(@s1[1]);
    CheckEquals(4,js.Count,'Count_1 <> 4;');
    CheckEqualsString(s1,js.Text,'Decode_1 <> Encode_1;');
  Finally
    js.Free;
  end;
  js:=Nil;
  try
    js:=ParseJSON(@s2[1]);
    CheckEquals(4,js.Count,'Count_2 <> 4;');
    CheckEqualsString(s2,js.Text,'Decode_2 <> Encode_2;');
    CheckTrue(js.Child[3].Value = 'abc','Child[3] <> "abc";');
  Finally
    js.Free;
  end;
  js:=Nil;
  try
    js:=ParseJSON(@s3[1]);
    CheckEquals(3,js.Count,'Count_3 <> 3;');
    CheckEqualsString(s3,js.Text,'Decode_3 <> Encode_3;');
    CheckTrue(js.Child[1].Field['b'].Value = 3,'Child[1].Field[b] <> 3;');
  finally
    js.Free;
  end;
  js:=Nil;
  try
    js:=ParseJSON(@s4[1]);
    CheckEquals(2,js.Count,'Count_4 <> 4;');
    CheckEqualsString(s4,js.Text,'Decode_4 <> Encode_4;');
    CheckTrue(js.Field['z'].Child[1].Field['z'].Value = 4,'<> 4;');
  finally
    js.Free;
  end;
  js:=Nil;
  try
    try
      js:=ParseJSON(@s5[1]);
      CheckFalse(True,'Parse must throw an exception when } is missing;');
    Except
      on E:TJSONError do CheckTrue(True,'Parse has thrown an exception when } is missing;');
    End;
  finally
    js.Free;
  end;
end;

initialization

  TestFramework.RegisterTest('JSONTests Suite',
    TJSONbaseTests.Suite);

end.
