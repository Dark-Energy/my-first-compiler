unit cgl;
interface
uses SysUtils;

type
   ArrayOfByte = array[0..0] of byte;
   PByteArray = ^ArrayOfByte;

var
    FSize: longint;
    FCode: PByteArray;
    FCodePtr: integer;
    procedure Clear;
    procedure Init; 

proceudre WriteByte(value: integer);
procedure WriteWord(value: integer);
procedure WriteInteger(value: integer);
function ReadByteAt(index: integer);
function ReadWordAt(index: integer);
function ReadIntegerAt(index: integer);
procedure WriteByteAt(index, value:integer);
procedure WriteWordAt(index, value: integer);
procedure WriteIntegerAt(index, value: integer);
//procedure PutWord(opcode: integer);
//procedure PutWordAt(index, opcode: integer); 


implementation

procedure Clear;
begin
  if FCode = nil then exit;
  FreeMem(FCode, FSize);
  FCode:= nil;
  FCodePtr:= 0;
  FSize:= 0;
end;

procedure Init;
begin
  Clear;
  FSize:= 4096;
  GetMem(FCode, FSize);
  FCodePtr:= 0;
end;

procedure Grow(delta: integer);
begin
  if FCodePtr + delta >= FSize then begin
    inc(FSize, 4096);
    ReallocMem(FCode, FSize);
  end;
end;

procedure WriteByte(value: integer);
begin
  Grow(1);
  FCode^[FCodePtr] := value;
end;

procedure WriteWord(value: integer);
begin
  Grow(2);
  FCode^[FCodePtr]:= value and $00FF; inc(FCodePtr);
  FCode^[FCodePtr]:= value and $FF00 shr 8); inc(FCodePtr);
end;

procedure WriteInteger(value: integer);
begin
  Grow(4);
  FCode^[FCodePtr]:= value and $000000FF; inc(FCodePtr);
  FCode^[FCodePtr]:= (value and $0000FF00) shr 8; inc(FCodePtr);
  FCode^[FCodePtr]:= (value and  $00FF0000) shr 16; inc(FCodePtr);
  FCode^[FCodePtr]:= (value and $FF000000) shr 24; inc(FCodePtr);
end;

 function ReadByteAt(index:integer):integer;
 begin
   result:= FCode^[index];
 end;

 function ReadWordAt(index:integer):integer;
 begin
   result:= FCode^[index] or FCode^[index+1] shl 8;
 end;

 function ReadIntegerAt(index:integer):integer;
 begin
   result:= FCode^[index] or FCode^[index+1] shl 8
     or FCode^[index+2] shl 16 or FCode^[index+3] shl 24;
 end;

procedure WriteByteAt(index, value: integer);
begin
  FCode^[index]:= value;
end;

procedure WriteWordAt(index, value: integer);
begin
  FCode^[index]:= value and $00FF; inc(index);
  FCode^[index]:= value and $FF00 shr 8;
end;

procedure WriteIntegerAt(index, value:integer);
begin
  FCode^[index]:= value and $000000FF; inc(index);
  FCode^[index]:= (value and $0000FF00) shr 8; inc(index);
  FCode^[index]:= (value and  $00FF0000) shr 16; inc(index);
  FCode^[index]:= (value and $FF000000) shr 24; 
end;

end. 