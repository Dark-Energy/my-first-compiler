unit Mstream;

interface

 Uses SysUtils, Classes;
type
     TMemStream = class(TStream)
  private
    FMemory: Pointer;
    FSize, FCapacity, FPosition: Longint;
    FWriteDone:boolean;
    procedure SetCapacity(Value: Longint);
  public
    constructor Create;
    destructor Destroy; override;
    function Read(var Buffer; Count: Longint): Longint; override;
    function Write(const Buffer; Count: Longint): Longint; override;
    function Seek(Offset: Longint; Origin: Word): Longint; override;
    procedure LoadFromStream(Stream: TStream);
    procedure LoadFromFile(const FileName: string);
    procedure SaveToStream(Stream: TStream);
    procedure SaveToFile(const FileName: string);
    procedure SetSize(Size: Longint);
    procedure Clear;
    property Memory: Pointer read FMemory;
    property WriteDone: boolean read FWriteDone write FWriteDone;
  end;



implementation
Uses WinProcs,WinTypes;

const
  MemoryDelta =$2000;

constructor TMemStream.Create;
begin
  inherited Create;
  FWriteDone:=false;
end;


destructor TMemStream.Destroy;
begin
  Clear;
  inherited Destroy;
end;


function TMemStream.Read(var Buffer; Count: Longint): Longint;
var
  source,dest:pchar;
begin
  if (FPosition >= 0) and (Count >= 0) then begin
    Result := FSize - FPosition;
    if Result > 0 then   begin
      if Result > Count then Result := Count;
      source:=FMemory;
      source:=source+FPosition;
      dest:=@buffer;
      {if dest<>pchar(Buffer) then
        ShowMessage('fuck');}
      CopyMemory(dest, source, Result);
      //move(dest, source, Result);
      Inc(FPosition, Result);
      Exit;
    end;
  end;
  Result := 0;
end;

function TMemStream.Write(const Buffer; Count: Longint): Longint;
var
  Pos: Longint;
  Mem1,Mem2: Pchar;
begin
  if (FPosition >= 0) and (Count >= 0) then begin
    Pos := FPosition + Count;
    if Pos > 0 then   begin
      if Pos > FSize then    begin
        if Pos > FCapacity then
          SetCapacity((Pos + (MemoryDelta - 1)) and not (MemoryDelta - 1));
        FSize := Pos;
      end;
      Mem1:=FMemory;
      Mem1:=Mem1+FPosition;
      mem2:=pchar(Buffer);
      CopyMemory(Mem1, mem2, Count);
      FPosition := Pos;
      Result := Count;
      FWriteDone:=True;
      Exit;
    end;
  end;
  FWriteDone:= False;
  Result := 0;
end;

function TMemStream.Seek(Offset: Longint; Origin: Word): Longint;
begin
  case Origin of
    0: FPosition := Offset;{begin}
    1: Inc(FPosition, Offset);{current}
    2: FPosition := FSize + Offset; {end}
  end;
  Result := FPosition;
end;

procedure TMemStream.LoadFromStream(Stream: TStream);
var
  Count: Longint;
begin
  Stream.Position := 0;
  Count := Stream.Size;
  SetSize(Count);
  if Count <> 0 then Stream.ReadBuffer(FMemory^, Count);
end;

procedure TMemStream.LoadFromFile(const FileName: string);
var
  Stream: TStream;
begin
  Stream := TFileStream.Create(FileName, fmOpenRead);
  try
    LoadFromStream(Stream);
  finally
    Stream.Free;
  end;
end;

procedure TMemStream.SaveToStream(Stream: TStream);
begin
  if FSize <> 0 then Stream.WriteBuffer(FMemory^, FSize);
end;

procedure TMemStream.SaveToFile(const FileName: string);
var
  Stream: TStream;
begin
  Stream := TFileStream.Create(FileName, fmCreate);
  try
    SaveToStream(Stream);
  finally
    Stream.Free;
  end;
end;

procedure TMemStream.Clear;
begin
  SetCapacity(0);
  FSize := 0;
  FPosition := 0;
  FWriteDone:=false;
end;

procedure TMemStream.SetSize(Size: Longint);
begin
  Clear;
  SetCapacity(Size);
  FSize := Size;
end;

procedure TMemStream.SetCapacity(Value: Longint);
var
  P: Pointer;
begin
  if Value <> FCapacity then begin
    if Value = 0 then  begin
      GlobalFreePtr(FMemory);
      FMemory := nil;
    end
    else  begin
      if FCapacity = 0 then
        P := GlobalAllocPtr(HeapAllocFlags, Value)
      else
        P := GlobalReallocPtr(FMemory, Value, HeapAllocFlags);
      if P = nil
        then raise EStreamError.Create('fuck');
      FMemory := P;
    end;
    FCapacity := Value;
  end;
end;


end.
