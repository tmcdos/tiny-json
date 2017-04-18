# JSON library for Delphi

This is a small and clean library for associative arrays with Boolean / Integer / Float / WideString values. 
Allows import (export) from (to) JSON text. Extensive error-checking. 

Some open-source projects I would like to give credit:

* [FunHash](https://github.com/funny-falcon/funny_hash) by Sokolov Yura
* [HatTrie](https://github.com/dcjones/hat-trie) by Daniel C. Jones
* FastInt64 - _unknown source_
* [FastMove](http://fastcode.sourceforge.net/challenge_content/FastMove.html) by FastCode project

The library was built for the ease of use and clean understandable code - performance was not a first priority so I have not made any benchmarking.

Features
========
* Numeric and WideString indexes (similar to PHP arrays)
* Boolean / Int64 / Double / WideString item values
* Strict parsing of JSON with descriptive Exception on error
* Simple interface (Add, Delete, Remove, Clear)
* Simple iterators (First, Last, Prev, Next)

Types of node values
=====

|Name|Description|
|---|---|
|jsNull|The `NULL` value|
|jsBool|Node value is `Boolean`|
|jsInt|Node value is `Integer`|
|jsFloat|Node value is `Floating-point`|
|jsString|Node value is `String`|
|jsArray|Node is an array - has children|

Iterators
======

- TJSONEnum = procedure (Nomer: Integer; Elem: TJSONbase; Data: Pointer; Var Stop: Boolean);
- TJSONEnumObj = procedure (Nomer: Integer; Elem: TJSONbase; Data: Pointer; Var Stop: Boolean) Of Object;

Parsing
=====
### function ParseJSON(JSON_str: PAnsiChar): TJSONbase;

Properties
==========

|Name|Type|Description|
|---|---|---|
|Assoc|Boolean|Whether all keys are Numeric or at least *one* key is String|
|Parent|TJSONbase|Where the given node belongs to|
|FirstChild|TJSONbase|Childs are organized as a double-linked list|
|LastChild|TJSONbase|Childs are organized as a double-linked list|
|Next|TJSONbase|Next sibling (by the order of creation)|
|Prev|TJSONbase|Previous sibling (by the order of creation)|
|SelfType|TJSONtype|Type of data in the current node|
|Value|Variant|Value of the current node|
|Count|Integer|Number of children if the node is non-scalar|
|Name|WideString|The String *key* of the current node if this is an associative array|
|ID|Integer|The Numeric *key* of the current node if this is non-associative array|
|Child[Index: Integer]|TJSONbase|Used to access the children of non-associative arrays|
|Field[Key: WideString]|TJSONbase|Used to access the children of associatve arrays|
|JsonText|AnsiString|Stringification of the current node as JSON text|

Methods
=======

|Name|Parameters|Returns|Description|
|---|---|---|---|
|Clear| | |Remove all children|
|Delete|Idx: Integer| |Delete a child from non-associative array and free the object|
|Delete|Key: WideString| |Delete a child from associative array and free the object|
|Remove|Idx: Integer|TJSONbase|Removee a child from non-associative array and return the object|
|Remove|Key: WideString|TJSONbase|Remove a child from associative array and return the object|
|ForEach|Iterator: TJSONEnum<br>UserData: Pointer| |Iterates over the children of non-associative array|
|ForEach|Iterator: TJSONEnumObj<br>UserData: Pointer| |Iterates over the children of associative array|
|Add|B: Boolean|TJSONbase|Appends a new `Boolean` child to the node (making it an array if not already, returns the new child)|
|Add|I: Int64|TJSONbase|Appends a new `Integer` child to the node (making it an array if not already, returns the new child)|
|Add|D: Double|TJSONbase|Appends a new `Floating-point` child to the node (making it an array if not already, returns the new child)|
|Add|S: WideString|TJSONbase|Appends a new `String` child to the node (making it an array if not already, returns the new child)|
|Add|A: TJSONbase| |Appends an existing array as a child to the node (making it an array if not already|
|Add|Key: WideString<br>B: Boolean|TJSONbase|Appends a new `Boolean` child to the node (making it an array if not already, returns the new child)|
|Add|Key: WideString<br>I: Int64|TJSONbase|Appends a new `Integer` child to the node (making it an array if not already, returns the new child)|
|Add|Key: WideString<br>D: Double|TJSONbase|Appends a new `Floating-point` child to the node (making it an array if not already, returns the new child)|
|Add|Key: WideString<br>S: WideString|TJSONbase|Appends a new `String` child to the node (making it an array if not already, returns the new child)|
|Add|Key: WideString<br>A: TJSONbase| |Appends an existing array as a child to the node (making it an array if not already|

Possible errors
===============
- Unsupported assignment of object
- Automatic indexing overflow
- Invalid data type assigned to TJSONbase
- This is an array - it does not have a value by itself
- Index is outside the array
- TJSONbase is not an array and does not support indexes
- Associative arrays do not support empty index
- TJSONbase is not an array and does not have Count property
- Unsupported data type in TJSONbase.JsonText
- Unexpected character at position
- Empty element at position
- Missing closing bracket for array
- Missing closing bracket for object
- Unterminated string at position
- Missing property name/value delimiter (:) at position
- Missing property value at position
- Missing fractional part of a floating-point number at position
- Exponent of the number is not integer at position
- Unquoted property name at position
- Control character encountered at position
- Unrecognized escape sequence at position
- Invalid UNICODE escape sequence at position
- Unescaped symbol at position
- Empty property name at position
- Expected closing bracket or comma at position
