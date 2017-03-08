unit JSON;

// Written by TMCDOS

// 16-Jul-2011  v1.1 - first public version
// 18-Jul-2011  v1.2 - modified to use output memory buffer instead of TStringStream for JSON-to-text
// 18-Jul-2011  v1.2.1
//                   - fixed bug in Mem_Write - 1st argument of Move() should be dereferenced pointer
//                   - empty arrays in PHP are always encoded as List, so TJSONlist.GetField() for empty
//                     lists does not throw exception
// 19-Jul-2011  v1.2.2 - fixed bug in Int2Hex (PUSH/POP EAX should be PUSH/POP AX)
// 12-Aug-2011  v1.2.3
//                   - added TJSONlist.Remove and TJSONobject.Remove
//                   - added TJSONlist.Clear and TJSONobject.Clear
// 18-Aug-2011  v1.3
//                   - fixed error in Int2Hex (wrong usage of outer variable CODE)
//                   - replaced TObjectList with TList, because otherwise REMOVE methods did not function properly
// 20-Apr-2012  v1.4 - added Result.Free at several places to avoid memory leaks when raising exceptions

// 11-Jul-2016  v2.0 - first private version (architectural changes - using hat tries)
// 14-Jul-2016  v2.1 - first public version (added DUnit tests)

interface

uses SysUtils,Classes,hat_trie;

Type
  TJSONtype = (jsNull, jsBool, jsInt, jsFloat, jsString, jsArray);

  TMemBuf = record
    p0,p1,p2:PAnsiChar;
    pLen:Cardinal;
  end;

  TJSONError = class(Exception)
  end;

  TJSONbase = Class;

  TJSONEnum = procedure (Nomer:Integer; Elem:TJSONbase; Data:Pointer; Var Stop:Boolean);
  TJSONEnumObj = procedure (Nomer:Integer; Elem:TJSONbase; Data:Pointer; Var Stop:Boolean) Of Object;

  TJSONbase = Class (TObject)
  Protected
    FType:TJSONtype;
    FValue:Variant;
    FParent,FChildFirst,FChildLast:TJSONbase;
    FChildCnt:Integer;
    FPrev,FNext:TJSONbase;
    FList:THatTrie;
    FKey:WideString; // if "", then use FIndex
    FIndex:Integer;
    FNextID:Integer; // when adding elements without key
    FAssoc:Boolean; // if there was at least 1 non-empty string key in children, or non-contiguous numeric IDs
    Function GetValue:Variant;
    procedure SetValue(AValue:Variant);
    function GetJSON:AnsiString;
    procedure GetJSONBuf(var mem:TMemBuf);
    Function GetItem(Index:Integer):TJSONbase;
    Procedure SetItem(Index:Integer;AValue:TJSONbase);
    function GetField(const Key:WideString): TJSONbase;
    procedure SetField(const Key:WideString;AValue:TJSONbase);
    Function GetCount:Integer;
    Function AddIndex:TJSONbase;
    Function AddKey(Key:WideString):TJSONbase;
    Procedure Append (j:TJSONbase);
    Procedure SetIndex (j:TJSONbase;Idx:Integer);
    Procedure SetKey (j:TJSONbase;Key:WideString);
    procedure Delete(js:TJSONbase;canFree:Boolean = True); overload;
  Public
    constructor Create;
    Destructor Destroy; Override;
    procedure Clear;
    Procedure Delete(Idx:Integer); Overload; // delete element and free the object
    procedure Delete(const Key:WideString); overload;
    function Remove(Idx:Integer):TJSONbase; Overload; // remove element from list and return reference to object
    function Remove(const Key:WideString): TJSONbase; overload;
    Procedure ForEach(Iterator:TJSONEnum;UserData:Pointer); Overload;
    Procedure ForEach(Iterator:TJSONEnumObj;UserData:Pointer); Overload;

    Function Add(B:Boolean):TJSONbase; Overload;
    Function Add(I:Int64):TJSONbase; Overload;
    Function Add(D:Double):TJSONbase; Overload;
    Function Add(S:WideString):TJSONbase; Overload;
    procedure Add(A:TJSONbase); overload;

    Function Add(Key:WideString;B:Boolean):TJSONbase; Overload;
    Function Add(Key:WideString;I:Int64):TJSONbase; Overload;
    Function Add(Key:WideString;D:Double):TJSONbase; Overload;
    Function Add(Key:WideString;S:WideString):TJSONbase; Overload;
    procedure Add(Key:WideString;A:TJSONbase); overload;

    Property Assoc:Boolean Read FAssoc;
    Property Parent:TJSONbase read FParent;
    Property FirstChild:TJSONbase Read FChildFirst;
    Property LastChild:TJSONbase Read FChildLast;
    Property Next:TJSONbase Read FNext;
    Property Prev:TJSONbase Read FPrev;
    Property SelfType:TJSONtype read FType;
    Property Value:Variant Read GetValue write SetValue;
    Property JsonText:AnsiString Read GetJSON;
    Property Count:Integer read GetCount;
    Property Child[Idx:Integer]:TJSONbase Read GetItem Write SetItem;
    property Field[const Key:WideString]:TJSONbase Read GetField Write SetField;
    Property Name:WideString Read FKey;
    Property ID:Integer Read FIndex;
  End;

function ParseJSON(old_pos:PAnsiChar): TJSONbase;

Resourcestring
  JR_OBJ = 'Unsupported assignment of object';
  JR_MAX_INDEX = 'Automatic indexing overflow';
  JR_TYPE = 'Invalid data type assigned to TJSONbase';
  JR_LIST_VALUE = 'This is an array - it does not have a value by itself';
  JR_INDEX = 'Index (%d) is outside the array';
  JR_NO_INDEX = 'TJSONbase is not an array and does not support indexes';
  JR_NO_NAME = 'Associative arrays do not support empty index';
  JR_NO_COUNT = 'TJSONbase is not an array and does not have Count property';

  JR_BAD_TXT = 'Unsupported data type in TJSONbase.Text';
  JR_PARSE_CHAR = 'Unexpected character at position %d - %.20s';
  JR_PARSE_EMPTY = 'Empty element at position %d';
  JR_OPEN_LIST = 'Missing closing bracket for array';
  JR_OPEN_OBJECT = 'Missing closing bracket for object';
  JR_OPEN_STRING = 'Unterminated string at position %d';
  JR_NO_COLON = 'Missing property name/value delimiter (:) at position %d';
  JR_NO_VALUE = 'Missing property value at position %d';
  JR_BAD_FLOAT = 'Missing fractional part of a floating-point number at position %d';
  JR_BAD_EXPONENT = 'Exponent of the number is not integer at position %d';
  JR_UNQUOTED = 'Unquoted property name at position %d';
  JR_CONTROL = 'Control character (%d) encountered at position %d in %s';
  JR_ESCAPE = 'Unrecognized escape sequence at position %d in "%s"';
  JR_CODEPOINT = 'Invalid UNICODE escape sequence at position %d in "%s"';
  JR_UNESCAPED = 'Unescaped symbol at position %d in "%s"';
  JR_EMPTY_NAME = 'Empty property name at position %d';
  JR_NO_COMMA = 'Expected closing bracket or comma at position %d';

implementation

uses Windows,Variants,FastMove,FastInt64;

Const
  MemDelta = 50000;
  INVALID_IDX = -1;

Var
  fmt:TFormatSettings; // always use "." for decimal separator

// functions for output buffering in JSON generation

procedure GetMemStart(var mem:TMemBuf);
Begin
  with mem do
  Begin
    pLen := MemDelta;
    p0 := AllocMem(pLen);
    p1 := p0;
    p2 := p1 + pLen;
  end;
end;

procedure GetMoreMemory(var mem:TMemBuf);
Begin
  with mem do
  begin
    Inc(pLen, MemDelta);
    ReallocMem(p0, pLen);
    p2 := p0 + pLen;
    p1 := p2 - MemDelta;
  end;
end;

procedure mem_char(ch: AnsiChar; var mem:TMemBuf);
begin
  with mem Do
  begin
    if p1 >= p2 then GetMoreMemory(mem);
    p1^ := ch;
    Inc(p1);
  end;
end;

procedure mem_write(const s: AnsiString; var mem:TMemBuf);
var
  Len,Room: Integer;
  p:PAnsiChar;
begin
  Len:=Length(s);
  p:=@s[1];
  while Len>0 Do
  begin
    with mem Do
    begin
      If p1 >= p2 then GetMoreMemory(mem);
      Room:=p2 - p1;
    end;
    if Room > Len then Room:=Len;
    Move(p^,mem.p1^,Room);
    Dec(Len,Room);
    Inc(p,Room);
    Inc(mem.p1,Room);
  End;
end;

// string escaping and un-escaping

procedure EscapeString(const s:WideString;var Buf:TMemBuf);
type
  hex_code = Array[1..4] of AnsiChar;
var
  i:Integer;
  code:hex_code;
  code_char:Cardinal absolute code;

  function Int2Hex(c:Word):Cardinal; Assembler;
  Asm
    PUSH EAX
    SHL EAX,16
    MOV AX,[ESP]
    MOV AH,AL

    AND AL,15
    CMP AL,10
    CMC
    ADC AL,'0'
    DAA
    MOV [ESP+3],AL

    MOV AL,AH
    SHR AL,4
    CMP AL,10
    CMC
    ADC AL,'0'
    DAA
    MOV [ESP+2],AL

    SHR EAX,16
    MOV AL,AH
    AND AL,15
    CMP AL,10
    CMC
    ADC AL,'0'
    DAA
    MOV [ESP+1],AL

    MOV AL,AH
    SHR AL,4
    CMP AL,10
    CMC
    ADC AL,'0'
    DAA
    MOV [ESP],AL
    POP EAX
  end;

Begin
  mem_char('"',Buf);
  For i:=1 to Length(s) do
    Case s[i] Of
      '/', '\', '"':
        Begin
          mem_char('\',Buf);
          mem_char(AnsiChar(s[i]),Buf);
        end;
      #8:
        Begin
          mem_char('\',Buf);
          mem_char('b',Buf);
        end;
      #9:
        Begin
          mem_char('\',Buf);
          mem_char('t',Buf);
        end;
      #10:
        Begin
          mem_char('\',Buf);
          mem_char('n',Buf);
        end;
      #12:
        Begin
          mem_char('\',Buf);
          mem_char('f',Buf);
        end;
      #13:
        Begin
          mem_char('\',Buf);
          mem_char('r',Buf);
        end;
    Else
      if s[i] in [WideChar(' ') .. WideChar('~')] Then mem_char(AnsiChar(s[i]),Buf)
      else
      Begin
        mem_char('\',Buf);
        mem_char('u',Buf);
        code_char:=Int2Hex(Ord(s[i]));
        mem_write(code,Buf);
      end;
    end;
  mem_char('"',Buf);
end;

Function UnescapeString(const s:AnsiString):WideString;
type
  hex_code = Array[1..4] of AnsiChar;
var
  idx,out_len,k,in_len:Integer;
  code:hex_code;
  code_char:Cardinal absolute code;
  
  function Hex2Wide(c:Cardinal):WideChar; Assembler;
  Asm
    SUB AL,'0'
    CMP AL,9
    JNA @@1
    SUB AL,7
  @@1:
    SHRD DX,AX,4
    MOV AL,AH
    SUB AL,'0'
    CMP AL,9
    JNA @@2
    SUB AL,7
  @@2:
    SHRD DX,AX,4
    SHR EAX,16
    SUB AL,'0'
    CMP AL,9
    JNA @@3
    SUB AL,7
  @@3:
    SHRD DX,AX,4
    MOV AL,AH
    SUB AL,'0'
    CMP AL,9
    JNA @@4
    SUB AL,7
  @@4:
    SHRD DX,AX,4
    MOV AX,DX
  end;

Begin
  in_len:=Length(s);
  SetLength(Result,in_len);
  idx:=1;
  out_len:=0;
  While idx<=in_len do
  begin
    if s[idx] < ' ' then Raise TJSONError.CreateFmt(JR_CONTROL,[Ord(s[idx]),idx,s]);
    If s[idx] = '\' Then
    Begin
      Inc(idx);
      case s[idx] Of
        '"','\','/':
          Begin
            Inc(out_len);
            Result[out_len]:=WideChar(s[idx]);
            Inc(idx);
          end;
        'b':
          Begin
            Inc(out_len);
            Result[out_len]:=#8;
            Inc(idx);
          end;
        't':
          Begin
            Inc(out_len);
            Result[out_len]:=#9;
            Inc(idx);
          end;
        'n':
          Begin
            Inc(out_len);
            Result[out_len]:=#10;
            Inc(idx);
          end;
        'f':
          Begin
            Inc(out_len);
            Result[out_len]:=#12;
            Inc(idx);
          end;
        'r':
          Begin
            Inc(out_len);
            Result[out_len]:=#13;
            Inc(idx);
          end;
        'u':
          Begin
            if idx+4 > in_len Then
              raise TJSONError.CreateFmt(JR_CODEPOINT,[idx,s]);
            For k:=1 to 4 do
            begin
              code[5-k]:=s[idx+k];
              If Not(code[5-k] in ['0'..'9','a'..'f','A'..'F']) then
                Raise TJSONError.CreateFmt(JR_CODEPOINT,[idx,s]);
            End;
            Inc(out_len);
            Inc(idx,5);
            Result[out_len]:=Hex2Wide(code_char);
          end;
      Else
        Raise TJSONError.CreateFmt(JR_ESCAPE,[idx,s]);
      end;
    end
    else
    Begin
      if not (s[idx] in [#32..#126]) then Raise TJSONError.CreateFmt(JR_UNESCAPED,[idx,s]);
      Inc(out_len);
      Result[out_len]:=WideChar(s[idx]);
      Inc(idx);
    end;
  End;
  // now out_len contains the real length of result in characters
  SetLength(Result,out_len);
end;

// ===== TJSONbase =====

Constructor TJSONbase.Create;
Begin
  FType:=jsNull;
  FValue:=Null;
  FParent:=Nil;
  FChildFirst:=Nil;
  FChildLast:=Nil;
  FChildCnt:=0;
  FNextID:=0;
  FIndex:=0;
  FKey:='';
  FAssoc:=False;
  FList:=THatTrie.Create;
end;

Destructor TJSONbase.Destroy;
Begin
  If (FType=jsArray)and(FChildCnt<>0) then Clear;
  FList.Free;
  Inherited;
end;

Function TJSONbase.GetCount:Integer;
Begin
  if FType=jsArray then Result:=FChildCnt
    else raise TJSONError.Create(JR_NO_COUNT);
end;

Function TJSONbase.GetValue:Variant;
Begin
  If Self=Nil then Result:=Null
  else If FType=jsArray Then Raise TJSONError.Create(JR_LIST_VALUE)
  Else Result:=FValue;
end;

Procedure TJSONbase.SetValue (AValue:Variant);
var
  r:Int64;
Begin
  // clear previous value
  Case VarType(AValue) Of
    varEmpty,
    varNull:
      Begin
        if FType=jsArray then clear;
        FType:=jsNull;
        FValue:=Null;
      end;
    varBoolean:
      Begin
        if FType=jsArray then Clear;
        FType:=jsBool;
        FValue:=Boolean(AValue);
      end;
    varShortInt,
    varByte,
    varSmallint,
    varWord,
    varInteger,
    varLongWord,
    varInt64:
      Begin
        if FType=jsArray then Clear;
        FType:=jsInt;
        r:=AValue;
        FValue:=r; // compiler does not allow direct assignment
      end;
    varCurrency,
    varSingle,
    varDouble:
      Begin
        if FType=jsArray then Clear;
        FType:=jsFloat;
        FValue:=Double(AValue);
      end;
    varOleStr,
    varStrArg,
    varString:
      Begin
        if FType=jsArray then Clear;
        FType:=jsString;
        FValue:=WideString(AValue);
      end;
    varByRef: Raise TJSONError.Create(JR_OBJ);
  else Raise TJSONError.Create(JR_TYPE);
  end;
end;

Procedure TJSONbase.GetJSONBuf(var mem:TMemBuf);
var
  comma:Boolean;
  c:TJSONbase;
Begin
  Case FType Of
    jsNull:   mem_write('null',mem);
    jsBool:   if FValue then mem_write('true',mem) else mem_write('false',mem);
    jsInt:    mem_write(IntToStr64(TVarData(FValue).VInt64),mem);
    jsFloat:  mem_write(FloatToStr(TVarData(FValue).VDouble,fmt),mem);
    jsString: EscapeString(TVarData(FValue).VOleStr,mem);
    jsArray:
      if FAssoc Then
      Begin
        mem_char('{',mem);
        comma:=False;
        c:=FChildFirst;
        While Assigned(c) do
        Begin
          If comma then mem_char(',',mem)
            else comma:=True;
          if c.FKey<>'' then EscapeString(c.FKey,mem)
            Else EscapeString(IntToStr(c.FIndex),mem);
          mem_char(':',mem);
          c.GetJSONBuf(mem);
          c:=c.FNext;
        end;
        mem_char('}',mem);
      end
      Else
      Begin
        mem_char('[',mem);
        comma:=False;
        c:=FChildFirst;
        While Assigned(c) do
        Begin
          If comma then mem_char(',',mem)
            else comma:=True;
          c.GetJSONBuf(mem);
          c:=c.FNext;
        end;
        mem_char(']',mem);
      end;
  Else raise TJSONError.Create(JR_BAD_TXT);
  end;
end;

Function TJSONbase.GetJSON:AnsiString;
var
  Buf:TMemBuf;
Begin
  Result:='';
  Buf.p0:=Nil;
  GetMemStart(Buf);
  Try
    GetJSONBuf(Buf);
    mem_char(#0,Buf);
    Result:=AnsiString(Buf.p0);
  Finally
    FreeMem(Buf.p0);
  end;
end;

Procedure TJSONbase.Append(j:TJSONbase);
Begin
  If FChildCnt=MaxInt then Raise TJSONError.Create(JR_MAX_INDEX);
  j.FParent:=Self;
  j.FPrev:=FChildLast;
  If Assigned(FChildLast) then FChildLast.FNext:=j;
  FChildLast:=j;
  if FChildCnt=0 then FChildFirst:=FChildLast;
  Inc(FChildCnt);
  FType:=jsArray;
end;

Procedure TJSONbase.SetIndex(j:TJSONbase;Idx:Integer);
var
  s:WideString;
  p:PInteger;
Begin
  j.FIndex:=Idx;
  s:=IntToStr(Idx);
  p:=FList.Get(@s[1],Length(s)*2);
  p^:=Integer(j);
end;

Function TJSONbase.AddIndex:TJSONbase;
Begin
  if FNextID=MaxInt then Raise TJSONError.Create(JR_MAX_INDEX);
  Result:=TJSONbase.Create;
  Append(Result);
  SetIndex(Result,FNextID);
  Inc(FNextID);
end;

function TJSONbase.Add(B:Boolean): TJSONbase;
Begin
  Result:=AddIndex;
  Result.Value:=B;
end;

function TJSONbase.Add(I:Int64): TJSONbase;
Begin
  Result:=AddIndex;
  Result.Value:=I;
end;

function TJSONbase.Add(D:Double): TJSONbase;
Begin
  Result:=AddIndex;
  Result.Value:=D;
end;

function TJSONbase.Add(S:WideString): TJSONbase;
Begin
  Result:=AddIndex;
  Result.Value:=S;
end;

Procedure TJSONbase.Add(A:TJSONbase);
Begin
  If Assigned(A) then
  Begin
    if FNextID=MaxInt then Raise TJSONError.Create(JR_MAX_INDEX);
    Append(A);
    A.FKey:='';
    SetIndex(A,FNextID);
    Inc(FNextID);
  end
  else Raise TJSONError.Create(JR_OBJ);
end;

Procedure TJSONbase.SetKey(j:TJSONbase;Key:WideString);
var
  p:PInteger;
  x:Integer;
Begin
  j.FKey:=Key;
  j.FIndex:=INVALID_IDX;
  p:=FList.Get(@Key[1],Length(Key)*2);
  p^:=Integer(j);
  x:=StrToIntDef(Key,-1);
  If (x > FNextID)and(FNextID < MaxInt) then FNextID:=x+1;
end;

Function TJSONbase.AddKey(Key:WideString):TJSONbase;
Begin
  Result:=TJSONbase.Create;
  Append(Result);
  SetKey(Result,Key);
  FAssoc:=True;
end;

function TJSONbase.Add(Key:WideString;B:Boolean): TJSONbase;
Begin
  if Key='' then Raise TJSONError.Create(JR_NO_NAME);
  Result:=AddKey(Key);
  Result.Value:=B;
end;

function TJSONbase.Add(Key:WideString;I:Int64): TJSONbase;
Begin
  if Key='' then Raise TJSONError.Create(JR_NO_NAME);
  Result:=AddKey(Key);
  Result.Value:=I;
end;

function TJSONbase.Add(Key:WideString;D:Double): TJSONbase;
Begin
  if Key='' then Raise TJSONError.Create(JR_NO_NAME);
  Result:=AddKey(Key);
  Result.Value:=D;
end;

function TJSONbase.Add(Key:WideString;S:WideString): TJSONbase;
Begin
  if Key='' then Raise TJSONError.Create(JR_NO_NAME);
  Result:=AddKey(Key);
  Result.Value:=S;
end;

Procedure TJSONbase.Add(Key:WideString;A:TJSONbase);
Begin
  if Key='' then Raise TJSONError.Create(JR_NO_NAME);
  If Assigned(A) then
  Begin
    Append(A);
    SetKey(A,Key);
    FAssoc:=True;
  end
  else Raise TJSONError.Create(JR_OBJ);
end;

Function TJSONbase.GetItem(Index:Integer):TJSONbase;
var
  p:PInteger;
  s:WideString;
Begin
  If FType<>jsArray Then Raise TJSONError.Create(JR_NO_INDEX);
  s:=IntToStr(Index);
  p:=FList.Find(@s[1],Length(s)*2);
  if Assigned(p) then Result:=TJSONbase(p^) else Result:=Nil;
end;

Procedure TJSONbase.SetItem(Index:Integer;AValue:TJSONbase);
var
  p:PInteger;
  s:WideString;
  js:TJSONbase;
Begin
  s:=IntToStr(Index);
  p:=FList.Get(@s[1],Length(s)*2);
  if p^ <> 0 then
  Begin
    js:=TJSONbase(p^);
    AValue.FPrev:=js.Prev;
    AValue.FNext:=js.Next;
    AValue.FParent:=Self;
    If js.Parent.FirstChild=js Then js.Parent.FChildFirst:=AValue;
    If js.Parent.LastChild=js then js.Parent.FChildLast:=AValue;
    js.Free;
  end;
  AValue.FKey:='';
  AValue.FIndex:=Index;
  if Index > FNextID then
  Begin
    FNextID:=Index+1;
    FAssoc:=True;
  end;
  p^:=Integer(AValue);
end;

Function TJSONbase.GetField(const Key:WideString):TJSONbase;
var
  p:PInteger;
Begin
  if FType<>jsArray Then Raise TJSONError.Create(JR_NO_INDEX);
  if Key='' then Raise TJSONError.Create(JR_NO_NAME);
  p:=FList.Find(@Key[1],Length(Key)*2);
  if Assigned(p) then Result:=TJSONbase(p^) else Result:=Nil;
end;

procedure TJSONbase.SetField(const Key:WideString;AValue:TJSONbase);
var
  p:PInteger;
  js:TJSONbase;
Begin
  if Key='' then Raise TJSONError.Create(JR_NO_NAME);
  p:=FList.Get(@Key[1],Length(Key)*2);
  if p^ <> 0 then
  Begin
    js:=TJSONbase(p^);
    AValue.FPrev:=js.Prev;
    AValue.FNext:=js.Next;
    AValue.FParent:=Self;
    If js.Parent.FirstChild=js Then js.Parent.FChildFirst:=AValue;
    If js.Parent.LastChild=js then js.Parent.FChildLast:=AValue;
    js.Free;
  end;
  AValue.FKey:=Key;
  AValue.FIndex:=INVALID_IDX;
  FAssoc:=True;
  p^:=Integer(AValue);
end;

procedure TJSONbase.Delete(js:TJSONbase;canFree:Boolean = True);
Begin
  if Assigned(js.FParent) Then
  With js.FParent do
  Begin
    Dec(FChildCnt);
    If FChildCnt=0 Then
    Begin
      FAssoc:=False;
      FNextID:=0;
    end;
    if FChildFirst=js then FChildFirst:=js.FNext;
    If FChildLast=js then FChildLast:=js.FPrev;
  end;
  if Assigned(js.FNext) then js.FNext.FPrev:=js.FPrev;
  if Assigned(js.FPrev) then js.FPrev.FNext:=js.FNext;
  if canFree Then js.Free;
end;

procedure TJSONbase.Delete(Idx:Integer);
var
  s:WideString;
  p:PInteger;
  Len:Integer;
Begin
  s:=IntToStr(Idx);
  Len:=Length(s);
  p:=FList.Find(@s[1],Len*2);
  if Assigned(p) then
  begin
    Delete(TJSONbase(p^));
    FList.Delete(@s[1],Len*2);
  end;
end;

procedure TJSONbase.Delete(const Key:WideString);
var
  p:PInteger;
  Len:Integer;
Begin
  if Key='' then Raise TJSONError.Create(JR_NO_NAME);
  Len:=Length(Key);
  p:=FList.Find(@Key[1],Len*2);
  if Assigned(p) then
  begin
    Delete(TJSONbase(p^));
    FList.Delete(@Key[1],Len*2);
  end;
end;

function TJSONbase.Remove(Idx:Integer):TJSONbase;
var
  s:WideString;
  p:PInteger;
  Len:Integer;
Begin
  s:=IntToStr(Idx);
  Len:=Length(s);
  p:=FList.Find(@s[1],Len*2);
  if Assigned(p) then
  Begin
    Result:=TJSONbase(p^);
    Delete(Result,False);
    FList.Delete(@s[1],Len*2);
  end
  else Raise TJSONError.CreateFmt(JR_INDEX,[Idx]);
end;

function TJSONbase.Remove(const Key:WideString):TJSONbase;
var
  p:PInteger;
  Len:Integer;
Begin
  if Key='' then Raise TJSONError.Create(JR_NO_NAME);
  Len:=Length(Key);
  p:=FList.Find(@Key[1],Len*2);
  if Assigned(p) then
  Begin
    Result:=TJSONbase(p^);
    Delete(Result,False);
    FList.Delete(@Key[1],Len*2);
  end
  else Result:=Nil;
end;

procedure TJSONbase.Clear;
Var
  js,tmp:TJSONbase;
Begin
  js:=FChildFirst;
  while Assigned(js) do
  Begin
    tmp:=js.FNext;
    Delete(js);
    js:=tmp;
  End;
  FList.Clear;
end;

Procedure TJSONbase.ForEach(Iterator:TJSONEnum;UserData:Pointer);
var
  i:Integer;
  stop:Boolean;
  js:TJSONbase;
Begin
  stop:=False;
  js:=FChildFirst;
  i:=0;
  while Assigned(js) and not stop do
  begin
    Iterator(i,js,UserData,stop);
    js:=js.FNext;
    Inc(i);
  end;
end;

Procedure TJSONbase.ForEach(Iterator:TJSONEnumObj;UserData:Pointer);
var
  i:Integer;
  stop:Boolean;
  js:TJSONbase;
Begin
  i:=0;
  stop:=False;
  js:=FChildFirst;
  while Assigned(js) and not stop do
  begin
    Iterator(i,js,UserData,stop);
    js:=js.FNext;
    Inc(i);
  end;
end;

// ===== Parse JSON =====

Function ParseJSON(old_pos:PAnsiChar):TJSONbase;
var
  txt:PAnsiChar;

  procedure SkipSpace;
  Begin
    while txt^ in [#9, #10, #13, ' '] do Inc(txt);
  end;

  Function ParseRoot:TJSONbase; Forward;

  function ParseBase:TJSONbase;
  var
    ptr:PAnsiChar;
    s:AnsiString;
    L:Integer;
    escaped:Boolean;
    is_float:Boolean;
  Begin
    Result:=Nil;
    if txt^ = #0 then Exit;
    SkipSpace;
    case txt^ of
      '"':
        Begin
          Inc(txt);
          ptr:=txt;
          escaped:=False;
          While ptr^ <> #0 Do
          Begin
            If escaped Then escaped:=False
            Else if ptr^ = '"' then Break
            else if ptr^ = '\' then escaped:=True;
            Inc(ptr);
          end;
          If ptr^ = #0 then
          Begin
            Result.Free;
            Raise TJSONError.CreateFmt(JR_OPEN_STRING,[txt-old_pos]);
          end;
          L:=ptr-txt;
          Result:=TJSONbase.Create;
          if L>0 then
          begin
            SetLength(s,L);
            StrLCopy(@s[1],txt,L);
            try
              Result.Value:=UnescapeString(s);
            Except
              Result.Free;
              Raise;
            End;
          end
          else Result.Value:='';
          txt:=ptr+1;
        end;
      'n','N':
        Begin
          If txt[1] in ['u','U'] Then
            if txt[2] in ['l','L'] Then
              if txt[3] In ['l','L'] then
              Begin
                Inc(txt,4);
                Result:=TJSONbase.Create;
                Result.Value:=Null;
              end;
        end;
      't','T':
        Begin
          if txt[1] in ['r','R'] Then
            if txt[2] in ['u','U'] Then
              if txt[3] in ['e','E'] Then
              Begin
                Inc(txt,4);
                Result:=TJSONbase.Create;
                Result.Value:=True;
              end;
        end;
      'f','F':
        Begin
          if txt[1] in ['a','A'] Then
            if txt[2] in ['l','L'] Then
              if txt[3] in ['s','S'] Then
                if txt[4] in ['e','E'] Then
                Begin
                  Inc(txt,5);
                  Result:=TJSONbase.Create;
                  Result.Value:=False;
                end;
        end;
      '-','0'..'9':
        Begin
          is_float:=False;
          ptr:=txt+1;
          while ptr^ in ['0'..'9'] do Inc(ptr); // integer part
          If ptr^ = '.' then
          Begin
            is_float:=True;
            Inc(ptr);
            if Not (ptr^ in ['0'..'9']) then
            Begin
              Result.Free;
              Raise TJSONError.CreateFmt(JR_BAD_FLOAT,[txt-old_pos]);
            end;
            While ptr^ in ['0'..'9'] do Inc(ptr); // rational part
          end;
          if ptr^ in ['e','E'] Then
          Begin
            is_float:=True;
            Inc(ptr);
            if not (ptr^ in ['-','+','0'..'9']) then
            Begin
              Result.Free;
              Raise TJSONError.CreateFmt(JR_BAD_EXPONENT,[txt-old_pos]);
            end;
            If ptr^ in ['+','-'] Then Inc(ptr); // exponent sign
            if not (ptr^ in ['0'..'9']) then
            Begin
              Result.Free;
              Raise TJSONError.CreateFmt(JR_BAD_EXPONENT,[txt-old_pos]);
            end;
            While ptr^ in ['0'..'9'] do Inc(ptr); // exponent
          end;
          L:=ptr-txt;
          Result:=TJSONbase.Create;
          if L>0 Then
          begin
            SetLength(s,L);
            StrLCopy(@s[1],txt,L);
            if is_float then Result.Value:=StrToFloat(s,fmt)
              else Result.Value:=StrToInt64(s);
          End
          Else Result.Value:=0.0;
          txt:=ptr;
        end;
    Else
      Result:=ParseRoot;
    end;
  end;

  function ParseList:TJSONbase; // does not consume closing ]
  var
    Elem:TJSONbase;
    need_value,need_comma:Boolean;
  Begin
    Result:=TJSONbase.Create;
    Result.FType:=jsArray;
    need_value:=False;
    need_comma:=False;
    While txt^ <> #0 Do
    Begin
      SkipSpace;
      if txt^ = #0 then
      Begin
        Result.Free;
        Raise TJSONError.CreateFmt(JR_OPEN_LIST,[txt-old_pos]);
      end;
      Case txt^ Of
        ']':
          Begin
            If need_value then
            Begin
              Result.Free;
              Raise TJSONError.CreateFmt(JR_PARSE_EMPTY,[txt-old_pos]);
            End;
            //Inc(txt);
            need_comma:=False;
            Break;
          end;
        ',':
          begin
            if need_value or (Result.Count=0) then
            Begin
              Result.Free;
              Raise TJSONError.CreateFmt(JR_PARSE_EMPTY,[txt-old_pos]);
            end;
            Inc(txt);
            need_value:=True;
            need_comma:=False;
          end;
      else
        if need_comma then
        Begin
          Result.Free;
          Raise TJSONError.CreateFmt(JR_NO_COMMA,[txt-old_pos]);
        end
        else
        Begin
          Elem:=ParseBase;
          If not Assigned(Elem) then
          Begin
            Result.Free;
            Raise TJSONError.CreateFmt(JR_PARSE_EMPTY,[txt-old_pos]);
          end;
          Result.Add(Elem);
          need_value:=False;
          need_comma:=True;
        end;
      end;
    end;
  end;

  Function ParseName:WideString;
  var
    ptr:PAnsiChar;
    s:AnsiString;
    L:Integer;
    escaped:Boolean;
  Begin
    SkipSpace;
    if txt^ = '"' Then
    begin
      Inc(txt);
      ptr:=txt;
      escaped:=False;
      While ptr^ <> #0 Do
      Begin
        If escaped Then escaped:=False
        Else if ptr^ = '"' then Break
        else if ptr^ = '\' then escaped:=True;
        Inc(ptr);
      end;
      If ptr^ = #0 then Raise TJSONError.CreateFmt(JR_OPEN_STRING,[txt-old_pos]);
      L:=ptr-txt;
      if L>0 Then
      begin
        SetLength(s,L);
        StrLCopy(@s[1],txt,L);
        Result:=UnescapeString(s);
      End
      else raise TJSONError.CreateFmt(JR_EMPTY_NAME,[txt-old_pos]);
      txt:=ptr+1;
    End
    Else raise TJSONError.CreateFmt(JR_UNQUOTED,[txt-old_pos]);
  end;

  function ParseObject:TJSONbase; // does not consume closing }
  var
    Title:WideString;
    Elem:TJSONbase;
    need_value,need_comma:Boolean;
  Begin
    Result:=TJSONbase.Create;
    Result.FType:=jsArray;
    need_value:=False;
    need_comma:=False;
    While txt^ <> #0 Do
    Begin
      SkipSpace;
      if txt^ = #0 then
      Begin
        Result.Free;
        Raise TJSONError.CreateFmt(JR_OPEN_LIST,[txt-old_pos]);
      end;
      Case txt^ Of
        '}':
          Begin
            If need_value then
            Begin
              Result.Free;
              Raise TJSONError.CreateFmt(JR_PARSE_EMPTY,[txt-old_pos]);
            end;
            //Inc(txt);
            need_comma:=False;
            Break;
          end;
        ',':
          begin
            if need_value or (Result.Count=0) then
            Begin
              Result.Free;
              Raise TJSONError.CreateFmt(JR_PARSE_EMPTY,[txt-old_pos]);
            end;
            Inc(txt);
            need_value:=True;
            need_comma:=False;
          end;
      else
        if need_comma then
        Begin
          Result.Free;
          Raise TJSONError.CreateFmt(JR_NO_COMMA,[txt-old_pos]);
        end
        else
        Begin
          Title:=ParseName;
          SkipSpace;
          If txt^ <> ':' then
          Begin
            Result.Free;
            Raise TJSONError.CreateFmt(JR_NO_COLON,[txt-old_pos]);
          end;
          Inc(txt);
          SkipSpace;
          if txt^ in [',','}'] then
          Begin
            Result.Free;
            Raise TJSONError.CreateFmt(JR_NO_VALUE,[txt-old_pos]);
          end;
          Elem:=ParseBase;
          If not Assigned(Elem) then
          Begin
            Result.Free;
            Raise TJSONError.CreateFmt(JR_PARSE_EMPTY,[txt-old_pos]);
          end;
          Result.Add(Title,Elem);
          need_value:=False;
          need_comma:=True;
        end;
      end;
    end;
  end;

  Function ParseRoot:TJSONbase;
  begin
    Result:=Nil;
    While txt^ <> #0 do
    Begin
      SkipSpace;
      if txt^ = #0 Then Break;
      case txt^ Of
        '{':
          begin
            Inc(txt);
            Result:=ParseObject;
            SkipSpace;
            if txt^ <> '}' then
            Begin
              Result.Free;
              Raise TJSONError.CreateFmt(JR_OPEN_OBJECT,[txt-old_pos]);
            end;
            Inc(txt);
            Break;
          End;
        '[':
          Begin
            Inc(txt);
            Result:=ParseList;
            SkipSpace;
            if txt^ <> ']' then
            Begin
              Result.Free;
              Raise TJSONError.CreateFmt(JR_OPEN_LIST,[txt-old_pos]);
            end;
            Inc(txt);
            Break;
          end;
      Else
        Result.Free;
        Raise TJSONError.CreateFmt(JR_PARSE_CHAR,[txt-old_pos,txt]);
      end;
    end;
  end;

Begin
  txt:=old_pos;
  Result:=Nil;
  if txt<>NIL then
  try
    Result:=ParseRoot;
    SkipSpace;
    If txt^ <> #0 Then
    begin
      Result.Free;
      Raise TJSONError.CreateFmt(JR_PARSE_CHAR,[txt-old_pos,txt]);
    End;
  Except
    Result.Free;
    Raise;
  End;
end;

Initialization
  GetLocaleFormatSettings(GetUserDefaultLCID,fmt);
  fmt.DecimalSeparator:='.';
  fmt.ThousandSeparator:=#0;

end.
