Unit Hat_Trie;
{
 * This file is part of hat-trie.
 *
 * Copyright (c) 2011 by Daniel C. Jones <dcjones@cs.washington.edu>
 *
}

Interface

Uses hat_table;

Const
  // maximum number of keys that may be stored in a bucket before it is burst
  MAX_BUCKET_SIZE = 16384;
  NODE_MAXCHAR = 255; // 0x7f for 7-bit ASCII
  NODE_CHILDS = NODE_MAXCHAR+1;

Type
  PTrieNode = ^trie_node;

  // Node's may be trie nodes or buckets. This union allows us to keep non-specific pointer.
  node_ptr = record
    case Byte of
      0:(b:TahTable);
      1:(t:PTrieNode);
      //2:(flag:PHatNodeSet);
  end;
  Pnode_ptr = ^node_ptr;

  trie_node = record
    flag:THatNodeSet;
    // the value for the key that is consumed on a trie node
    val:Integer;
    // Map a character to either a trie_node_t or a ahtable_t. The first byte
    // must be examined to determine which.
    xs:Array[0..NODE_CHILDS-1] of node_ptr;
  end;

  hattrie = record
    root:node_ptr; // root node
    m:Cardinal;    // number of stored keys
  end;
  Phattrie = ^hattrie;

  // plan for iteration:
  // This is tricky, as we have no parent pointers currently, and I would like to
  // avoid adding them. That means maintaining a stack
  Phattrie_node_stack = ^hattrie_node_stack;
  hattrie_node_stack = record
    c:Char;
    level:Cardinal;
    node:node_ptr;
    next:Phattrie_node_stack;
  end;
  {
  hattrie_iter = record
    key:PAnsiChar;
    keysize:Cardinal; // space reserved for the key
    level:Cardinal;

    // keep track of keys stored in trie nodes
    has_nil_key:Boolean;
    nil_val:Integer;
    T:Phattrie;
    i:Pahtable_iter;
    stack:Phattrie_node_stack;
  end;
  Phattrie_iter = ^hattrie_iter;
  }
  THatTrie = class
  Private
    FHat:Phattrie;
    Function ClearVal (n:node_ptr):Integer;
    Function FindNode (Var key:PAnsiChar; Var len:Cardinal):node_ptr;
    Function UseVal (n:node_ptr):PInteger;
  Public
    Constructor Create;
    Destructor Destroy; Override;
    Procedure Clear;
    // Find the given key in the trie, inserting it if it does not exist, and
    // returning a pointer to it's key.
    // This pointer is not guaranteed to be valid after additional calls to
    // GetValPtr, Delete, Clear, or other functions that modifies the trie.
    Function Get (key:PAnsiChar; len:Cardinal):PInteger;
    // Find a given key in the table, returning a NULL pointer if it does not exist
    Function Find (key:PAnsiChar; len:Cardinal):PInteger;
    // Delete a given key from trie. Returns 0 if successful or -1 if not found
    Function Delete (key:PAnsiChar; len:Cardinal):Integer;
  end;

{
Function hattrie_iter_Begin (Const T:Phattrie):Phattrie_iter;
Function hattrie_iter_finished (i:Phattrie_iter):Boolean;
Procedure hattrie_iter_next (i:Phattrie_iter);
Procedure hattrie_iter_free (i:Phattrie_iter);
}

Implementation

// ============= utility functions =============

// Create a new trie node with all pointers pointing to the given child (which can be NULL).
Function AllocTrieNode(child:node_ptr):PTrieNode;
Var
  i:Integer;
Begin
  New(Result);
  Result.flag := [NODE_TYPE_TRIE];
  Result.val  := 0;

  for i := 0 to NODE_CHILDS-1 do Result.xs[i] := child;
End;

Procedure FreeNode(node:node_ptr);
var
  i:Integer;
Begin
  if NODE_TYPE_TRIE in node.t.flag then
  begin
    for i := 0 to NODE_CHILDS-1 do
    begin
      if (i > 0) and (node.t.xs[i].t = node.t.xs[i - 1].t) then continue;

      // XXX: recursion might not be the best choice here. It is possible
      // to build a very deep trie.
      if Assigned(node.t.xs[i].t) then FreeNode(node.t.xs[i]);
    end;
    Dispose(node.t);
  end
  else node.b.Free;
End;

// iterate trie nodes until string is consumed or bucket is found
Function hattrie_consume(var p:node_ptr; var k:PAnsiChar; var l:Cardinal; brk:Cardinal):node_ptr;
Begin
  Result:= p.t.xs[Byte(k^)];
  while (NODE_TYPE_TRIE in Result.t.flag) and (l > brk) do
  Begin
    Inc(k);
    Dec(l);
    p := Result;
    Result := Result.t.xs[Byte(k^)];
  End;

  // copy and writeback variables if it's faster
  assert(NODE_TYPE_TRIE in p.t.flag);
End;

// Perform one split operation on the given node with the given parent.
Procedure Split(parent,node:node_ptr);
Var
  val:PInteger;
  len,num_slots,c:Cardinal;
  key:PAnsiChar;
  iter:TahIterator;
  cs:Array[0..NODE_CHILDS-1] of Cardinal; // occurance count for leading chars
  left_m, right_m, all_m:Cardinal;
  j:Byte;
  d:Integer;
  left, right:node_ptr;
  u,v:PInteger;
Begin
  // only buckets may be split
  assert((NODE_TYPE_PURE_BUCKET in node.b.flag) or (NODE_TYPE_HYBRID_BUCKET in node.b.flag));
  assert(NODE_TYPE_TRIE in parent.t.flag);

  if NODE_TYPE_PURE_BUCKET in node.b.flag then
  begin
    // turn the pure bucket into a hybrid bucket
    parent.t.xs[node.b.c0].t := AllocTrieNode(node);

    // if the bucket had an empty key, move it to the new trie node 
    val := node.b.Find(Nil, 0);
    if Assigned(val) then
    begin
      parent.t.xs[node.b.c0].t.val := val^;
      Include(parent.t.xs[node.b.c0].t.flag, NODE_HAS_VAL);
      val^ := 0;
      node.b.Delete(Nil, 0);
    End;

    with node.b do
    begin
      c0   := 0;
      c1   := NODE_MAXCHAR;
      flag := [NODE_TYPE_HYBRID_BUCKET];
    end;  ;
    Exit;
  End;

  // This is a hybrid bucket. Perform a proper split.

  // count the number of occourances of every leading character
  FillChar(cs[0], Length(cs) * SizeOf(Cardinal),0);
  iter := TahIterator.Create(node.b);
  while not iter.Finished do
  begin
    key := iter.GetKey(len);
    assert(len > 0);
    Inc(cs[Byte(key[0])], 1);
    iter.Next;
  end;
  iter.Free;

  // choose a split point 
  j := node.b.c0;
  all_m   := node.b.ms;
  left_m  := cs[j];
  right_m := all_m - left_m;

  while j + 1 < node.b.c1 do
  begin
    d := abs(Integer(left_m + cs[j + 1]) - Integer(right_m - cs[j + 1]));
    if (d <= abs(left_m - right_m)) and (left_m + cs[j + 1] < all_m) then
    begin
      Inc(j, 1);
      Inc(left_m, cs[j]);
      Dec(right_m, cs[j]);
    end
    else break;
  end;

  // now split into two node cooresponding to ranges [0, j] and [j + 1, NODE_MAXCHAR], respectively.

  // create new left and right nodes

  // TODO: Add a special case if either node is a hybrid bucket containing all
  // the keys. In such a case, do not build a new table, just use the old one.
  num_slots := ahtable_initial_size;
  while left_m > ahtable_max_load_factor * num_slots do num_slots:= num_slots * 2;

  left.b  := TahTable.Create(num_slots);
  left.b.c0   := node.b.c0;
  left.b.c1   := j;
  if left.b.c0 = left.b.c1 then left.b.flag := [NODE_TYPE_PURE_BUCKET]
    else left.b.flag:= [NODE_TYPE_HYBRID_BUCKET];

  num_slots := ahtable_initial_size;
  while right_m > ahtable_max_load_factor * num_slots do num_slots:=num_slots * 2;

  right.b := TahTable.Create(num_slots);
  right.b.c0   := j + 1;
  right.b.c1   := node.b.c1;
  if right.b.c0 = right.b.c1 then right.b.flag := [NODE_TYPE_PURE_BUCKET]
    else right.b.flag:= [NODE_TYPE_HYBRID_BUCKET];

  // update the parent's pointer 
  c := node.b.c0;
  while c<=j do 
  begin
    parent.t.xs[c] := left;
    Inc(c);
  end;
  while c <= node.b.c1 do
  begin
    parent.t.xs[c] := right;
    Inc(c); 
  end;

  // distribute keys to the new left or right node
  iter := TahIterator.Create(node.b);
  while not iter.Finished do
  begin
    key := iter.GetKey(len);
    u   := iter.GetVal;
    assert(len > 0);

    // left
    if Byte(key[0]) <= j then
    begin
      if NODE_TYPE_PURE_BUCKET in left.b.flag then
        v := left.b.Get(key + 1, len - 1)
      else
        v := left.b.Get(key, len);
      v^ := u^;
    end
    // right
    else
    begin
      if NODE_TYPE_PURE_BUCKET in right.b.flag then
        v := right.b.Get(key + 1, len - 1)
      else
        v := right.b.Get(key, len);
      v^ := u^;
    end;
    iter.Next;
  end;
  iter.Free;
  node.b.Free;
End;

// ============= Methos =============

Constructor THatTrie.Create;
Var
  node:node_ptr;
Begin
  New(FHat);
  FHat.m := 0;

  node.b := TahTable.Create;
  with node.b do
  begin
    flag := [NODE_TYPE_HYBRID_BUCKET];
    c0 := 0;
    c1 := NODE_MAXCHAR;
  end;
  FHat.root.t := AllocTrieNode(node);
End;

Destructor THatTrie.Destroy;
Begin
  FreeNode(FHat.root);
  Dispose(FHat);
  Inherited;
End;

Procedure THatTrie.Clear;
var
  node:node_ptr;
Begin
  FreeNode(FHat.root);
  node.b := TahTable.Create;
  with node.b do
  begin
    flag := [NODE_TYPE_HYBRID_BUCKET];
    c0 := 0;
    c1 := 255;
  end;
  FHat.root.t := AllocTrieNode(node);
End;

// use node value and return pointer to it
Function THatTrie.UseVal(n:node_ptr):PInteger;
Begin
  if not (NODE_HAS_VAL in n.t.flag) then
  begin
    Include(n.t.flag, NODE_HAS_VAL);
    Inc(FHat.m);
  end;
  Result:= @n.t.val;
End;

// clear node value if exists
Function THatTrie.ClearVal(n:node_ptr):Integer;
Begin
  if NODE_HAS_VAL in n.t.flag then
  begin
    Exclude(n.t.flag, NODE_HAS_VAL);
    n.t.val := 0;
    Dec(FHat.m);
    Result:= 0;
  end
  else Result:= -1;
End;

// find node in trie
Function THatTrie.FindNode(var key:PAnsiChar; var len:Cardinal):node_ptr;
var
  parent:node_ptr;
Begin
  parent := FHat.root;
  assert(NODE_TYPE_TRIE in parent.t.flag);

  if len = 0 then
  begin
    Result:=parent;
    Exit;
  end;
  Result:= hattrie_consume(parent, key, len, 1);

  // if the trie node consumes value, use it
  if NODE_TYPE_TRIE in Result.t.flag then
  begin
    if not(NODE_HAS_VAL in Result.t.flag) then Result.t.flag := [];
    Exit;
  End;

  // pure bucket holds only key suffixes, skip current char
  if NODE_TYPE_PURE_BUCKET in Result.b.flag then
  begin
    Inc(key, 1);
    Dec(len, 1);
  end;

  // do not scan bucket, it's not needed for this operation
End;

Function THatTrie.Get(key:PAnsiChar; len:Cardinal):PInteger;
var
  node,parent:node_ptr;
  m_old:Cardinal;
  val:PInteger;
Begin
  parent := FHat.root;
  assert(NODE_TYPE_TRIE in parent.t.flag);

  if len = 0 then
  begin
    Result:= @parent.t.val;
    Exit;
  End;

  // consume all trie nodes, now parent must be trie and child anything
  node := hattrie_consume(parent, key, len, 0);
  assert(NODE_TYPE_TRIE in parent.t.flag);

  // if the key has been consumed on a trie node, use its value
  if len = 0 then
  begin
    if NODE_TYPE_TRIE in node.t.flag then
    begin
      Result:= UseVal(node);
      Exit;
    end
    else if NODE_TYPE_HYBRID_BUCKET in node.b.flag then
    begin
      Result:=UseVal(parent);
      Exit;
    end;
  end;

  // preemptively split the bucket if it is full
  while node.b.ms >= MAX_BUCKET_SIZE do
  begin
    Split(parent, node);

    // after the split, the node pointer is invalidated, so we search from
    // the parent again.
    node := hattrie_consume(parent, key, len, 0);

    // if the key has been consumed on a trie node, use its value 
    if len = 0 then
    begin
      if NODE_TYPE_TRIE in node.t.flag then
      begin
        Result:= UseVal(node);
        Exit;
      end
      else if NODE_TYPE_HYBRID_BUCKET in node.b.flag then
      begin
        Result:=UseVal(parent);
        Exit;
      end;
    end;
  end;

  assert((NODE_TYPE_PURE_BUCKET in node.b.flag) or (NODE_TYPE_HYBRID_BUCKET in node.b.flag));
  assert(len > 0);
  m_old := node.b.ms;
  if NODE_TYPE_PURE_BUCKET in node.b.flag then
    val := node.b.Get(key + 1, len - 1)
  else
    val := node.b.Get(key, len);
  Inc(FHat.m, node.b.ms - m_old);
  Result:=val;
End;

Function THatTrie.Find(key:PAnsiChar; len:Cardinal):PInteger;
var
  node:node_ptr;
Begin
  // find node for given key
  node := FindNode(key, len);
  if node.b = Nil then
  begin
    Result:=Nil;
    Exit;
  End;

  // if the trie node consumes value, use it
  if NODE_TYPE_TRIE in node.t.flag then
  begin
    Result:= @node.t.val;
    Exit;
  End;
  Result:= node.b.Find(key, len);
End;

Function THatTrie.Delete(key:PAnsiChar; len:Cardinal):Integer;
var
  node,parent:node_ptr;
  m_old:Cardinal;
  ret:Integer;
Begin
  parent := FHat.root;
  assert(NODE_TYPE_TRIE in parent.t.flag);

  // find node for deletion
  node := FindNode(key, len);
  if node.b = Nil then
  begin
    Result:= -1;
    Exit;
  End;

  // if consumed on a trie node, clear the value
  if NODE_TYPE_TRIE in node.t.flag then
  begin
    Result:= ClearVal(node);
    Exit;
  End;

  // remove from bucket 
  m_old := node.b.ms;
  ret := node.b.Delete(key, len);
  Dec(FHat.m, m_old - node.b.ms);

  // TODO - merge empty buckets
  Result:=ret;
End;

{
Procedure hattrie_iter_pushchar(i:Phattrie_iter; level:Cardinal; c:Char);
Begin
  if i.keysize < level then
  begin
    i.keysize:=i.keysize * 2;
    ReallocMem(i.key, i.keysize * SizeOf(Char));
  end;
  if level > 0 then i.key[level - 1] := c;
  i.level := level;
End;

Procedure hattrie_iter_nextnode(i:Phattrie_iter);
var
  node:node_ptr;
  next:Phattrie_node_stack;
  c:Char;
  level:Cardinal;
  j:Integer;
Begin
  if not Assigned(i.stack) then Exit;

  // pop the stack
  node  := i.stack.node;
  next  := i.stack.next;
  c     := i.stack.c;
  level := i.stack.level;

  Dispose(i.stack);
  i.stack := next;

  if NODE_TYPE_TRIE in node.flag^ then
  begin
    hattrie_iter_pushchar(i, level, c);
    if NODE_HAS_VAL in node.t.flag then
    begin
      i.has_nil_key := true;
      i.nil_val := node.t.val;
    end;

    // push all child nodes from right to left
    for j := NODE_MAXCHAR downto 0 do
    begin
      // skip repeated pointers to hybrid bucket
      if (j < NODE_MAXCHAR) and (node.t.xs[j].t = node.t.xs[j + 1].t) then continue;

      // push stack
      next := i.stack;
      New(i.stack);
      i.stack.node  := node.t.xs[j];
      i.stack.next  := next;
      i.stack.level := level + 1;
      i.stack.c     := Chr(j);
    end;
  end
  else 
  begin
    if NODE_TYPE_PURE_BUCKET in node.flag^ then
      hattrie_iter_pushchar(i, level, c)
    else 
      i.level := level - 1;
    i.i := ahtable_iter_begin(node.b);
  end;
End;

function hattrie_iter_Begin(Const T:Phattrie): Phattrie_iter;
Begin
  New(Result);
  Result.T := T;
  Result.i := Nil;
  Result.keysize := 16;
  GetMem(Result.key,Result.keysize * SizeOf(Char));
  Result.level := 0;
  Result.has_nil_key := false;
  Result.nil_val := 0;

  New(Result.stack);
  Result.stack.next   := Nil;
  Result.stack.node   := T.root;
  Result.stack.c      := #0;
  Result.stack.level  := 0;

  while ((Result.i = Nil) or ahtable_iter_finished(Result.i)) and not Result.has_nil_key and Assigned(Result.stack) do
  begin
    ahtable_iter_free(Result.i);
    Result.i := Nil;
    hattrie_iter_nextnode(Result);
  end;

  if Assigned(Result.i) and ahtable_iter_finished(Result.i) then
  begin
    ahtable_iter_free(Result.i);
    Result.i := Nil;
  end;
End;

Function hattrie_iter_finished(i:Phattrie_iter):Boolean;
Begin
  Result:= (i.stack = Nil) and (i.i = Nil) and not i.has_nil_key;
End;

Procedure hattrie_iter_next(i:Phattrie_iter);
Begin
  if hattrie_iter_finished(i) then Exit;

  if Assigned(i.i) and not ahtable_iter_finished(i.i) then ahtable_iter_next(i.i)
  else if i.has_nil_key then
  begin
    i.has_nil_key := false;
    i.nil_val := 0;
    hattrie_iter_nextnode(i);
  end;

  while ((i.i = Nil) or ahtable_iter_finished(i.i)) and not i.has_nil_key and Assigned(i.stack) do
  begin
    ahtable_iter_free(i.i);
    i.i := Nil;
    hattrie_iter_nextnode(i);
  end;

  if Assigned(i.i) and ahtable_iter_finished(i.i) then
  begin
    ahtable_iter_free(i.i);
    i.i := Nil;
  end;
End;

Procedure hattrie_iter_free(i:Phattrie_iter);
var
  next:Phattrie_node_stack;
Begin
  if not Assigned(i) then exit;
  if Assigned(i.i) then ahtable_iter_free(i.i);
  while Assigned(i.stack) do
  begin
    next := i.stack.next;
    Dispose(i.stack);
    i.stack := next;
  end;
  FreeMem(i.key);
  Dispose(i);
End;

Function hattrie_iter_key(i:Phattrie_iter; len:PCardinal):PAnsiChar;
var
  sublen:Cardinal;
  subkey:PAnsiChar;
Begin
  Result:=Nil;
  if hattrie_iter_finished(i) then Exit;
  if i.has_nil_key then
  begin
    subkey := Nil;
    sublen := 0;
  end
  else subkey := ahtable_iter_key(i.i, @sublen);

  if i.keysize < i.level + sublen + 1 then
  begin
    while i.keysize < i.level + sublen + 1 do i.keysize:=i.keysize * 2;
    ReallocMem(i.key, i.keysize * SizeOf(Char));
  end;

  Move(subkey^,(i.key + i.level)^, sublen);
  i.key[i.level + sublen] := #0;

  if Assigned(len) then len^ := i.level + sublen;
  Result:= i.key;
End;

Function hattrie_iter_val(i:Phattrie_iter):PInteger;
Begin
  if i.has_nil_key then Result:= @i.nil_val
  else if hattrie_iter_finished(i) then Result:=Nil
  else Result:= ahtable_iter_val(i.i);
End;

Function hattrie_iter_equal(a,b:Phattrie_iter):Boolean;
Begin
  Result:= (a.T = b.T) and (a.i = b.i);
End;
}

End.