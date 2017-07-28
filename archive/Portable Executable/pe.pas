unit pe;
interface
uses SysUtils, Windows, classes;
procedure GenFile(name: string);

var
  Buffer: array[0..4096] of char;


const
  Artl = 'artl.dll';

type
  TImportNode = class;

   PFuncItem = ^TFuncItem;
   TFuncItem = record
     name: string;
     funcRVA: longint;  
     CallFunc: longint;
     Dll: TImportNode; 
   end; 

  TImportNode = class
  private   
    function Get(index:integer):PFuncItem;
  public
    DLLname: string;
    FuncList: TList;
    FuncCount: integer;
    constructor Create;
    destructor Destroy; override;
    function AddFunc(name: string): PFuncItem;
    function Find(name: string): PFuncItem;
    procedure UseFunc(name: string; var Addr: integer);
    property List[index:integer]: PFuncItem read Get ; default;
  end;

  TImportList = class
  private
    function Get(index:integer):TImportNode; 
  public  
    DllList: TList;
    DllCount: integer;
    constructor Create; 
    destructor Destroy; override;
    function AddModule(name:string): TImportNode;
    property List[index:integer] : TImportNode read Get; default;
  end;

var
  ImportList:TImportList;

implementation

{$i mz.inc}

type
  //����� ��������� PE 
  SectAddr = record
    //0-������� (proba:$10000,$CA)
    //1-������  (proba:$F000,$4C4)
     virtualAddress: integer;
     vsize: integer;
   end;

  TPEHeader = record
    Signature: array[0..3] of char;
    CPUType: word;
    SectionCount: word;
    TimeDateStamp: integer;
    CoffTablePtr: integer;
    CoffTableSize: integer;
    SizeOptionalHeader: word;
    flags: word; //����� 
    magic: word; //010B
    linkerVersion: word; //������ ������� : 1902
    CodeSize: integer;  //������ ����: ��������� ����� �� 1000
    InitDataSize: integer; // ������ �������������� ������ (�����)
    UnInitDataSize: integer; // ������ ���������������� ������: 0
    EntryPoint: integer; //1000 + �������� ����� �����
    BaseOfCode: integer; //1000 (RVA ������ .text)
    BaseOfData: integer; //1000H (RVA ������ .data)
    imageBase: integer; //$400000  ����������� ��������� ����� ��������
     sectionAlign : integer; //$1000
    fileAlign: integer; //$200
    osVersion: integer; //1 ������ ���
    imageVersion: integer; //0
    subsystVersion: integer; //$000A0003 ������ ����������
    reserved1: integer; //0 �� ���.
    sizeofImage: integer; //RVA ��������� ������+�� ������-RVA ������ ������
    sizeofHeaders: integer; //������ ��������� � ������� ������ (� proba - $400)
    checkSum: integer; //0 ����������� ����� (�� ���)
    subSystem: word;    //3 - ��������, 2- ���; ����������
    dllFlags: word;    //0
    stackReserve: integer; //$100000 ���� ������ �����
    stackCommit: integer; //$2000 ��� ������ �����
    heapReserve: integer; //$100000 ���� ������ ����
    heapCommit: integer; //$1000 ��� ������ ����
    loaderFlags: integer; //0 
    numRvaAndSizes:integer; //16
    dirs : array [0..15] of SectAddr
  end;

var
  PEHeader : TPEHeader;

(* ������� ������ *)
type
  TSectionType = (exeNULL, exeDos, exeHeader, exeSect, exeData,
    exeIData, exeEData, exeText, exeRsrc, exeDebug);

  TSection = record
    name:array[0..7]of char; //��� ������
    //������ ������ � ������ (������ ��������)
    virtualSize:integer;
    //RVA ������ ($1000 ��� .text � �.�.)
    SectionRVA: integer;
   //���������� ������ ������ � ������ (��������� �� $200)
    PhysicalSize:integer; 
   //���������� �������� �� ������ ����� 
    PhysicalOffset: integer; 
    pointerReloc:integer; //0
    pointerLineNum:integer; //0
    numReloc:word; //0
    numLineNum:word; //0
    flags:integer; //������
        //.text :$60000020
        //.data :$C0000040
        //.idata:$40000040
        //.edata:$40000040
        //.rsrc :$40000040
        //.debug :$40000040
  end;

var
  Sections: array [1..4] of TSection;
  MakeDLL: boolean = false;
  CodeSize:integer =  11;
  BASECODE: integer = $400000;
  STACKMAX : integer = $100000;
  STACKMIN : integer = $2000;
  HEAPMAX : integer =  $100000;
  HEAPMIN : integer = $1000;
  SizeOfImportData: integer=0; 
  Code : array[0..256] of byte;
  Data: string = '��� ����';
  DataSize: integer = 9; 

type
  ImportDescriptor = record
    origFirstThunk:integer; //0
    timeDateStump:integer; //0
    forwardChain:integer; //0
    name:integer; //RVA �����-����� ����� DLL
    FirstThunk:integer; //RVA ������� ���������� �� ���.�������
  end;
  //������ Thunk ������� �� RVA ���������� (zeroend)
  //������ ��������� �� 0,0,��� ������� zeroend
  //�������� �� ������� Thunk (�� RVA-������
  //������ ������������ � ������� CALL PTR[]
  

function genAlign(siz, align:integer):integer;
begin
  if align=0 then result:= siz
  else if siz mod align = 0 then result:= siz
  else result:= siz - siz mod align + align
end;

procedure WriteAlign(Handle, align:integer);
const
  b:byte = 0;
var
  hw: word;
begin
  while (align <> 0) and
  (Windows.GetFileSize(Handle, @hw) mod align <> 0) do
    FileWrite(Handle, b, 1);
end;


function SizeOfDllNames(dll: integer):integer;
var
  i: integer;
begin
  result:= 0;
  for i:= 0 to dll-1 do 
    with TImportNode(ImportList.DllList[i]) do 
      inc(result, Length(DllName)+1);
end;


function SizeOfFuncNames(dll, func: integer):integer;
var
  i:integer;
begin
  result:=0;
  with TImportNode(ImportList.DllList[dll]) do
    for i:= 0 to func-1 do 
      inc(result, length(PFuncItem(FuncList[i])^.name)+3);
end;

function GetSizeThunk(dll: integer):integer;
var
  i:integer;
begin
  result:=0;
  //������ ���� ������������ �������
  inc(result, sizeof(ImportDescriptor)*(ImportList.DllCount+1));
  //�����, ���������� ������� DLL
  inc(result, SizeOfDllNames(ImportList.DllCount));
  for i:= 0 to dll-1 do 
    with TImportNode(ImportList.DllList[i]) do begin
      //������ ������� ����������
      inc(result, FuncCount*4 + 4); 
      //����� ���� ���� �������, ������������� �� ���� DLL
      inc(result, SizeOfFuncNames(i, FuncCount));
    end;
end;




procedure InitPEHeader;
var
  i:integer;
begin
  i:= CodeSize;
  with PEHeader do begin
    //���������
    Signature[0]:= 'P'; Signature[1]:= 'E'; Signature[2]:= #0; Signature[3]:= #0;
    CPUType:= $14C;     //��� ���
    SectionCount:= 3; // ����� ������
    TimeDateStamp:= $073924CA; //���� � �����
    CoffTablePtr:= 0; CoffTableSize:= 0;
    SizeOptionalHeader:= $E0;
    flags:= $10E or $02;

    magic:= $010B;
    linkerVersion:= 3;
    UnInitDataSize:= 0; // ������ �������������������� ������
    InitDataSize:= GenAlign(DataSize, $1000);// ������ ������������������ ������
    CodeSize:= genAlign(i, $1000);// ������ ����

    BaseOfCode := $1000 + GenAlign(SizeOfImportData, $1000) + InitDataSize;  

    entryPoint := BaseOfCode; //����� �����
    baseOfData:=  $1000; // ������ ������
    BASECODE:= $400000;
    imageBase:= BASECODE; //������� ����������� ����� 

    SectionAlign:= $1000; //������������ � ������
    FileAlign:= $200; //������������ � �����
    OsVersion:= 4; ImageVersion:= 0; reserved1:= 0;

    sizeOfImage := $1000 + GenAlign(SizeOfImportData, $100) + 
      CodeSize + InitDataSize; //������ ������
    sizeofHeaders:= genAlign(sizeof(DOSHeader) + sizeof(TPEHeader) +
      sizeof(TSection)*3, $200); //������ ���� ����������

    checkSum:= 0; //����������� �����
    subSystem:= 2; //GUI ����� ���������� : �������, ��� � ��.
    dllFlags:= 0; //�� ���.
    //������ �����
    stackReserve:= STACKMAX;
    stackCommit:= STACKMIN;
     //������ ����
    heapReserve:= HEAPMAX;  heapCommit:= HEAPMIN;
    loaderFlags:=0;
    //������ ����-��
    numRvaAndSizes:=16;
    for i:=0 to 15 do
      with dirs[i] do
        if i = 1 then begin  //������
          virtualAddress:= InitDataSize+BaseOfData;
          vsize:= GenAlign(SizeOfImportData, $1000);
        end
        else begin virtualAddress:=0;  vsize:=0; end;
  end;
end;

function SizeDllName(dll: integer):integer;
begin
   result:= length(ImportList[dll].DllName)+1;
end;

function SizeOfThunk(dll: integer):integer;
begin
  result:= 0;
  if dll < 0 then exit;
  with ImportList[dll] do begin
    result:= FuncCount*4+4;
    inc(result, SizeOfFuncNames(dll, FuncCount));
  end; 
end;

function SizeOfImportTable:integer;
begin
  result:= GetSizeThunk(ImportList.DllCount);
end;

procedure WriteImportTable(Handle: THandle);
var
  i, j, k, t, rva:integer;
  imp: ImportDescriptor;
  sizeOfAllDllNames: integer;
begin
  ZeroMemory(@imp, sizeof(imp));
  k:= Sections[2].SectionRVA + sizeof(ImportDescriptor)*(ImportList.DllCount+1);
  SizeOfAllDllNames:= SizeOfDllNames(ImportList.DllCount);
  //����������� ������� 
  for i:= 0 to ImportList.DllCount-1 do begin
    with ImportList[i], imp do begin
      if i = 0 then begin 
        name:= k; 
        FirstThunk:= k + SizeOfAllDllNames; 
      end
      else begin  
        inc(name, SizeDllName(i-1));
        inc(FirstThunk, SizeOfThunk(i-1));
       end; 
    end;   
    FileWrite(Handle, imp, sizeof(imp)); 
  end;
  ZeroMemory(@imp, sizeof(imp));     FileWrite(Handle, imp, sizeof(imp)); 
  //����� ������������ DLL
  for i:= 0 to ImportList.DllCount-1 do 
    with ImportList[i] do FileWrite(Handle, DllName[1], length(DllName)+1);
   
  inc(k, SizeOfAllDllNames); rva:=k;
  for i:= 0 to ImportList.DllCount-1 do begin
     inc(k, ImportList[i].FuncCount*4+4);
      //������ ���������� �� ����� �������
      for j:= 0 to ImportList[i].FuncCount-1 do begin
        with ImportList[i][j]^ do begin
          FuncRVA:= rva; inc(rva, 4);
          t:= k + SizeOfFuncNames(i,j);
          FileWrite(handle, t, 4); 
        end;
      end;
      t:=0; FileWrite(handle, t, 4);
      for j:= 0 to ImportList[i].FuncCount-1 do begin
        FileWrite (handle, t, 2);
        with ImportList[i][j]^ do  
          FileWrite(handle, name[1], length(name)+1);
      end;
     inc(k, sizeOfFuncNames(i,importList[i].FuncCount)); rva:=k;
  end;
end;

const
  DLLName :string = 'kernel32.dll';
  FuncName :string = 'ExitProcess';
  Kernel = 'kernel32.dll'; 
  user :string = 'ttt.dll';
  MBoxName :string=  'ShowMessage';

procedure GenExeFile(Handle: THandle);
var
  b: byte;
  imp1, imp2: ImportDescriptor;
  i:integer;
  funcRVA: longint;
  k:integer; 
  CurAddr: longint;
  mboxRVA: integer;
begin

   CodeSize := 10+12;

  SizeOfImportData := 
    Length(kernel)+Length(user)+2+
    length(MBoxName)+length(FuncName)+6+16 + sizeof(ImportDescriptor)*3;
 
  //������ � ����� ���������
  InitPEHeader; //��������� PE
  FileWrite(Handle, DOSHeader, sizeof(DOSHeader));
  FileWrite(Handle, PEHeader, sizeof(PEHeader));



//������� ������
  with Sections[1] do begin
    ZeroMemory(@name[0], 8); lstrcpy(@name[0], '.data'); 
    SectionRVA:= $1000;
    VirtualSize:= GenAlign(DataSize, $1000);
    PhysicalOffset := genAlign(sizeof(DOSHeader)+
      Sizeof(PEHeader)+sizeof(Sections), $200);
    PhysicalSize := GenAlign(DataSize, $200);
    flags:= $C0000040;
  end;
  inc(CurAddr, sizeof(TSection));
  with Sections[2] do begin//������
    lstrcpy(@name[0],'.idata'); name[7]:=char(0);
    SectionRVA:= Sections[1].SectionRVA + Sections[1].VirtualSize;//�������� � ������
    VirtualSize:= GenAlign(SizeOfImportData, $1000); //������ � ������
    PhysicalOffset:= Sections[1].PhysicalOffset + Sections[1].PhysicalSize;
    PhysicalSize:= GenAlign(SizeOfImportData, $200);
    flags:= $40000040;
  end;
  inc(CurAddr, sizeof(TSection));
  with Sections[3] do begin //���
    lstrcpy(@name[0],'.text'); name[6]:=char(0); name[7]:=char(0);
    SectionRVA := Sections[2].SectionRVA + Sections[2].VirtualSize;
    VirtualSize:= GenAlign(CodeSize, $1000);
    PhysicalOffset:= Sections[2].PhysicalOffset+Sections[2].PhysicalSize;
    PhysicalSize:= GenAlign(CodeSize, $200);
    flags:= $60000020;
   end;
   ZeroMemory(@Sections[4], sizeof(TSection));
   FileWrite(Handle, Sections[1], sizeof(Sections));
   WriteAlign(Handle, $200);
   inc(CurAddr, sizeof(SEctions));

   CurAddr:= GenAlign(CurAddr, $200);  
   writeln('Data Section : ', CurAddr, ' Physical Offset : ', Sections[1].PhysicalOffset); 
 
   FileWrite(Handle, Data[1], length(Data)+1);
   WriteAlign(Handle, $200);

    //������ ������� (������ ImportDesctriptor)  
    writeImportTable(handle);
    WriteAlign(Handle, $200);

    Mboxrva := ImportList[1][0]^.funcRVA; 
    funcRVA := ImportList[0][0]^.funcRVA; 

//������ ����

          k:= 0;

          i:= PEHeader.ImageBase + Sections[1].SectionRVA; //
          code[k]:= $68; inc(k);
          code[k]:=lobyte(loword(i)); inc(k);
          code[k]:=hibyte(loword(i)); inc(k);
          code[k]:=lobyte(hiword(i));  inc(k);
          code[k]:=hibyte(hiword(i)); inc(k);

          //����� �������
          code[k]:= $FF; inc(k);
          code[k]:= $15; inc(k);       
          writeln('r ',mboxrva);   
          MboxRVA:= BASECODe + MBoxRVA;
          code[k]:=lobyte(loword(mboxrva)); inc(k);
          code[k]:=hibyte(loword(mboxrva)); inc(k);
          code[k]:=lobyte(hiword(mboxrva)); inc(k);
          code[k]:=hibyte(hiword(mboxrva)); inc(k);


          code[k]:= $FF; inc(k);
          code[k]:= $15; inc(k);

        FuncRva:= BASECODE + funcRVA;   
          code[k]:=lobyte(loword(funcrva)); inc(k);
          code[k]:=hibyte(loword(funcrva)); inc(k);
          code[k]:=lobyte(hiword(funcrva));  inc(k);
          code[k]:=hibyte(hiword(funcrva)); inc(k);
          FileWrite(Handle, Code[0], k);
  WriteAlign(Handle, $200);

//����������
    with Sections[2] do 
      writeln('Section Import Virtual Size : ', SizeOfImportData);
    writeln(GetSizeThunk(ImportList.DllCount));
end;

procedure GenFile(name: string);
var
  handle: THandle;
begin
  ZeroMemory(@Buffer[0], sizeof(Buffer));
  handle:= FileCreate(name);
  if handle = 0 then exit;
  try  
   GenExeFile(handle);
  finally
    CloseHandle(handle);
  end;
end;

function TImportNode.AddFunc(name: string):PFuncItem;
begin
  New(result);
  result^.name:= name;
  FuncList.Add(result);
  inc(FuncCount);
end;

function TImportNode.Find(name:string):PFuncItem;
var
  i:integer;
begin 
  result:= nil;
  for i:= 0 to FuncList.Count-1 do 
    if PFuncItem(FuncList[i])^.name = name then begin
      result:= FuncList[i];
      break;
    end; 
end;

function TImportNode.Get(index:Integer):PFuncItem;
begin
  result:= PFuncItem(FuncList[index]);
end;

procedure TImportNode.UseFunc(name: string; var Addr: integer);
var
  tmp: PFuncItem;
  i: integer;
begin
  tmp:= Find(name);
  if tmp = nil then exit;
  i:= tmp^.CallFunc;
  tmp^.CallFunc := Addr;
  Addr:= i;
end;

constructor TImportNode.Create;
begin
  FuncList:= TList.Create;
end;

destructor TImportNode.Destroy;
var
  i:integer;
begin
  for i:= 0 to FuncList.Count-1 do 
    Dispose(PFuncItem(FuncList[i]));
  FuncList.Free;
  inherited Destroy;
end;

function TImportList.Get(index:integer):TImportNode;
begin
  result:= TImportNode(DllList[index]);
end;

constructor TImportList.Create;
begin
  DllList:= TList.Create
end;

destructor TImportList.Destroy;
var 
  i: integer;
begin
  for i:= 0 to DllCount-1 do 
    TObject(DllList[i]).Free;
  DllList.Free;
  inherited Destroy; 
end;

function TImportList.AddModule(name: string): TImportNode;
begin
  result:= TImportNode.Create;
  result.Dllname:= name;
  DllList.Add(result);
  inc(DllCount);
end;

procedure InsertApi;
begin
  ImportList:= TImportList.Create;
  with ImportList.AddModule('kernel32.dll') do begin
     Addfunc('ExitProcess');
  end;
  with ImportList.AddModule('ttt.dll') do begin
    AddFunc('ShowMessage');
  end;
end;

initialization
  InsertApi;
finalization
  ImportList.Free;
end.