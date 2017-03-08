Unit hat_table;
{
 * This file is part of hat-trie.
 *
 * Copyright (c) 2011 by Daniel C. Jones <dcjones@cs.washington.edu>
 *
 * This is an implementation of the 'cache-conscious' hash tables described in,
 *
 *    Askitis, N., & Zobel, J. (2005). Cache-conscious collision resolution in
 *    string hash tables. String Processing and Information Retrieval (pp.
 *    91–102). Springer.
 *
 *    http://naskitis.com/naskitis-spire05.pdf
 *
 * Briefly, the idea behind an Array Hash Table is, as opposed to separate
 * chaining with linked lists, to store keys contiguously in one big array,
 * thereby improving the caching behavior, and reducing space requirements.
 *
 * ahtable keeps a fixed number (array) of slots, each of which contains a
 * variable number of key/value pairs. Each key is preceded by its length--
 * one byte for lengths < 128 bytes, and TWO bytes for longer keys. The least
 * significant bit of the first byte indicates, if set, that the size is two
 * bytes. The slot number where a key/value pair goes is determined by finding
 * the murmurhashed integer value of its key, modulus the number of slots.
 * The number of slots expands in a stepwise fashion when the number of
 * key/value pairs reaches an arbitrarily large number.
 *
 * +-------+-------+-------+-------+-------+-------+
 * |   0   |   1   |   2   |   3   |  ...  |   N   |
 * +-------+-------+-------+-------+-------+-------+
 *     |       |       |       |               |
 *     v       |       |       v               v
 *    NULL     |       |     4html[VALUE]     etc.
 *             |       v
 *             |     5space[VALUE]4jury[VALUE]
 *             v
 *           6justice[VALUE]3car[VALUE]4star[VALUE]
 *
}

Interface

const
  ahtable_max_load_factor = 100000; // arbitrary large number => don't resize
  ahtable_initial_size = 4096;

type
  THatNodeFlag = (NODE_TYPE_TRIE, NODE_TYPE_PURE_BUCKET, NODE_TYPE_HYBRID_BUCKET, NODE_HAS_VAL);
  THatNodeSet = set of THatNodeFlag;
  PHatNodeSet = ^THatNodeSet;

  slot = PAnsiChar;
  arrSlot = Array of slot;
  arrInt = Array of Integer;

  TahTable = class
  Private
    Function get_key (Const key:PAnsiChar; len:Cardinal; insert_missing:Boolean):PInteger;
    Procedure expand;
  Public
    // these fields are reserved for hattrie to fiddle with
    flag:THatNodeSet;
    c0,c1:Byte;

    ns:Cardinal;        // number of slots
    ms:Cardinal;        // number of key/value pairs stored
    max_m:Cardinal;    // number of stored keys before we resize

    fslot_sizes:arrInt;
    fslots:arrSlot;
    // Create an empty hash table, with N slots reserved.
    Constructor Create(NumSlots:Cardinal = ahtable_initial_size);
    Destructor Destroy; Override;
    Procedure Clear; // Remove all entries
    // Find the given key in the table, inserting it if it does not exist, and
    // returning a pointer to it's value.
    // This pointer is not guaranteed to be valid after additional calls to
    // Get, Delete, Clear, or other functions that modify the table.
    Function Get (Const key:PAnsiChar; len:Cardinal):PInteger;
    // Find a given key in the table, return a NULL pointer if it does not exist.
    Function Find (Const key:PAnsiChar; len:Cardinal):PInteger;
    Function Delete (Const key:PAnsiChar; len:Cardinal):Integer;
  end;

  TahIterator = class
  Private
    tbl:Tahtable; // parent
    idx:Cardinal;     // slot index
    sPos:slot;         // slot position
  Public
    constructor Create(table:Tahtable);
    Function Finished:Boolean;
    Function GetKey (Out len:Cardinal):PAnsiChar;
    Function GetVal:PInteger;
    Procedure Next;
  end;
{
Procedure ahtable_iter_next      (i:Pahtable_iter);
Function  ahtable_iter_finished  (i:Pahtable_iter):Boolean;
Procedure ahtable_iter_free      (i:Pahtable_iter);
Function  ahtable_iter_key       (i:Pahtable_iter; len:PCardinal):PAnsiChar;
Function  ahtable_iter_val       (i:Pahtable_iter):PInteger;
}
Implementation

uses SysUtils,FunHash,FastMove;

// ============= utility functions =============

Function keylen(s:slot):Integer;
begin
  if (1 and Byte(s^))<>0 then Result:= PWord(s)^ shr 1
    else Result:=Byte(s^) shr 1;
end;

// Inserts a key with value into slot s, and returns a pointer to the
// space immediately after.
Function ins_key(s:slot;const key:PAnsiChar; len:Cardinal; var val:PInteger):slot;
Begin
  // key length
  if len < 128 then
  begin
    Byte(s[0]) := len shl 1;
    Inc(s, 1);
  end
  else
  begin
    // The least significant bit is set to indicate that two bytes are
    // being used to store the key length.
    PWord(s)^ := (len shl 1) +1;
    Inc(s, 2);
  end;

  // key
  Move(key^, s^,len);
  Inc(s, len);

  // value
  val := PInteger(s);
  val^ := 0;
  Inc(s, sizeof(Cardinal));
  Result:=s;
End;

// ============= ahTable Methos =============

Constructor TahTable.Create(NumSlots:Cardinal);
Begin
  flag := [];
  c0 := 0;
  c1 := 0;

  ns := NumSlots;
  ms := 0;
  max_m := ahtable_max_load_factor * NumSlots;
  SetLength(Fslots,NumSlots);
  FillChar(Fslots[0],NumSlots * SizeOf(slot),0);
  SetLength(Fslot_sizes,NumSlots);
  FillChar(Fslot_sizes[0],NumSlots * SizeOf(Integer),0);
End;

Destructor TahTable.Destroy;
var
  i:Integer;
Begin
  for i := 0 to ns-1 do FreeMem(Fslots[i]);
  Fslots:=Nil;
  Fslot_sizes:=Nil;
End;

Procedure TahTable.Clear;
var
  i:Integer;
Begin
  for i := 0 to ns-1 do FreeMem(Fslots[i]);
  ns := ahtable_initial_size;
  SetLength(Fslots, ns);
  FillChar(Fslots[0], ns * Sizeof(slot),0);
  SetLength(Fslot_sizes, ns);
  FillChar(Fslot_sizes[0], ns * sizeof(Integer),0);
End;

Procedure TahTable.expand;
var
  new_n,len,m,j,h:Cardinal;
  slot_sizes:arrInt;
  key:PAnsiChar;
  iter:TahIterator;
  slots,slots_next:arrSlot;
  u,v:PInteger;
Begin
  {* Resizing a table is essentially building a brand new one.
   * One little shortcut we can take on the memory allocation front is to
   * figure out how much memory each slot needs in advance.
  }
  assert(ns > 0);
  new_n := 2 * ns;
  SetLength(slot_sizes,new_n);
  FillChar(slot_sizes[0],new_n*SizeOf(Integer),0);
  len := 0;
  m := 0;
  iter := TahIterator.Create(Self);
  while not iter.Finished do
  begin
    key := iter.GetKey(len);
    if len<128 then h:=1
      else h:=2;
    Inc(slot_sizes[FunHash32(key, len) mod new_n], len + sizeof(Integer) + h);
    Inc(m);
    iter.next;
  end;
  assert(m = ms);
  iter.Free;

  // allocate slots
  SetLength(slots,new_n);
  for j := 0 to new_n-1 do
    if slot_sizes[j] > 0 then
      GetMem(slots[j],slot_sizes[j])
    else slots[j] := Nil;

  {* rehash values. A few shortcuts can be taken here as well, as we know
   * there will be no collisions. Instead of the regular insertion routine,
   * we keep track of the ends of every slot and simply insert keys.
  }
  slots_next:=Copy(slots);
  m := 0;
  iter := TahIterator.Create(Self);
  while not iter.Finished do
  begin
    key := iter.GetKey(len);
    h := FunHash32(key, len) mod new_n;

    slots_next[h] := ins_key(slots_next[h], key, len, u);
    v := iter.GetVal;
    u^ := v^;

    Inc(m);
    iter.Next;
  end;
  assert(m = ms);
  iter.Free;

  slots_next:=Nil;
  for j := 0 to ns-1 do FreeMem(slots[j]);

  Fslots:=Nil;
  Fslots := slots;

  Fslot_sizes:=Nil;
  Fslot_sizes := slot_sizes;

  ns := new_n;
  max_m := ahtable_max_load_factor * ns;
End;

Function TahTable.get_key(const key:PAnsiChar; len:Cardinal; insert_missing:Boolean):PInteger;
var
  i,k,new_size:Cardinal;
  s:slot;
  val:PInteger;
Begin
  // if we are at capacity, preemptively resize
  if insert_missing and (ms >= max_m) then expand;
  i := FunHash32(key, len) mod ns;

  // search the array for our key
  s := Fslots[i];
  while s - Fslots[i] < Fslot_sizes[i] do
  begin
    // get the key length
    k := keylen(s);
    if k<128 then Inc(s,1)
      else Inc(s,2);

    // skip keys that are longer than ours
    if k <> len then
    begin
      Inc(s, k + sizeof(Integer));
      continue;
    end;

    // key found
    if AnsiStrLComp(s, key, len) = 0 then
    begin
      Result:= Pointer(s + len);
      Exit;
    end
    // key not found
    else
    begin
      Inc(s, k + sizeof(Integer));
      continue;
    end;
  end;
  if insert_missing then
  begin
    // the key was not found, so we must insert it
    new_size := Fslot_sizes[i];
    if len<128 then Inc(new_size,1)
      else Inc(new_size,2); // key length
    Inc(new_size,len * sizeof(Char)); // key
    Inc(new_size, sizeof(Integer)); // value

    ReallocMem(Fslots[i], new_size);
    Inc(ms);
    ins_key(Fslots[i] + Fslot_sizes[i], key, len, val);
    Fslot_sizes[i] := new_size;
    Result:=val;
  end
  else Result:=Nil;
End;

Function TahTable.Get(const key:PAnsiChar; len:Cardinal):PInteger;
Begin
  Result:= get_key(key, len, true);
End;

Function TahTable.Find(const key:PAnsiChar; len:Cardinal):PInteger;
Begin
  Result:=get_key(key, len, false);
End;

Function TahTable.Delete(const key:PAnsiChar; len:Cardinal):Integer;
var
  i:Cardinal;
  k:Cardinal;
  s:slot;
  t:PAnsiChar;
Begin
  i := FunHash32(key, len) mod ns;

  // search the array for our key
  s := Fslots[i];
  while s - Fslots[i] < Fslot_sizes[i] do
  begin
    // get the key length
    k := keylen(s);
    if k<128 then Inc(s,1)
      else Inc(s,2);

    // skip keys that are longer than ours
    if k <> len then
    begin
      Inc(s, k + sizeof(Integer));
      continue;
    end;

    // key found.
    if AnsiStrLComp(s, key, len) = 0 then
    begin
      // move everything over, resize the array
      t := s + len + sizeof(Integer);
      if k<128 then Dec(s,1)
        else Dec(s,2);
      Move(t^,s^, Fslot_sizes[i] - (t - Fslots[i]));
      Dec(Fslot_sizes[i], t - s);
      Dec(ms);
      Result:= 0;
      Exit;
    end
    // key not found.
    else
    begin
      Inc(s, k + sizeof(Integer));
      continue;
    end;
  end;

  // Key was not found. Do nothing.
  Result:= -1;
End;

// ============= ahIterator Methos =============

Constructor TahIterator.Create(table:Tahtable);
Begin
  tbl := table;
  Idx:=0;
  while Idx < tbl.ns do
  begin
    sPos := tbl.Fslots[Idx];
    if tbl.Fslot_sizes[Idx]<>0 then break;
    Inc(Idx);
  end;
End;

Function TahIterator.Finished:Boolean;
Begin
  Result:= Idx >= tbl.ns;
End;

Procedure TahIterator.Next;
var
  k:Cardinal;
Begin
  if Finished then Exit;

  // get the key length
  k := keylen(sPos);
  if k<128 then Inc(sPos,1)
    else Inc(sPos,2);

  // skip to the next key
  Inc(sPos, k + sizeof(Integer));
  if sPos - tbl.Fslots[Idx] >= tbl.Fslot_sizes[Idx] then
  begin
    repeat
      Inc(Idx);
    until (Idx >= tbl.ns) or (tbl.Fslot_sizes[Idx] <> 0);

    if Idx < tbl.ns then sPos := tbl.Fslots[Idx]
      else sPos := Nil;
  end;
End;

Function TahIterator.GetKey(out len:Cardinal):PAnsiChar;
var
  s:slot;
  k:Cardinal;
Begin
  Result:=Nil;
  if Finished then Exit;
  s := sPos;
  if (1 and Byte(s^))<>0 then
  begin
    k := PWord(s)^ shr 1;
    Inc(s, 2);
  end
  else
  begin
    k := Byte(s^) shr 1;
    Inc(s, 1);
  end;
  len := k;
  Result:=s;
End;

Function TahIterator.GetVal:PInteger;
var
  s:slot;
  k:Cardinal;
Begin
  Result:=Nil;
  if Finished then Exit;
  s := sPos;
  if (1 and Byte(s^))<>0 then
  begin
    k := PWord(s)^ shr 1;
    Inc(s, 2);
  end
  else
  begin
    k := Byte(s^) shr 1;
    Inc(s, 1);
  end;
  Inc(s, k);
  Result:=Pointer(s);
End;

End.
