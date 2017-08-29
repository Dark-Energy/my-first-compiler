unit Symtab;
interface
uses SysUtils, classes;

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
    function Find(name:string):TImportNode;
  end;

type
  PConst = ^TConst;
  TConst = record
    str: pchar;  //строка или список измерений массива
    ival: integer; //целое или длина строки, колво размерностей массива
    fval: double; //вещественное
    dop: integer; //что-то еще
  end;

  PTypeDesc = ^TypeDesc;
  TypeDesc = record
    next: PTypeDesc; //используется при распределении памяти
    form: integer; //форма - см.ниже
    size: integer; //размер
    link: PTypeDesc; //связь 
    BaseType: PTypeDesc;//базовый тип 
  end;

  PSymbol = ^TSymbol;
  TSymbol = record
    left, right, scope, link: PSymbol; //нужно для таблицы имен
    fpar: PSymbol; //список формальных параметров
    mode: integer;
    next, prev: PSymbol; //нужно для освобождения памяти
    name: string; //имя 
    ConVal: PConst;   //значение константы
    tip: PTypeDesc; //тип
    adr: longint; //адрес
    func: PFuncItem;
  end;

  TSymTab = class
  private   
    FHead: PSymbol;
    FTopScope: PSymbol;
    HeadType: PTypeDesc;
    procedure InsertStdProcs;
    procedure InsertTypes;
    procedure InsertApi;
  public
    ImportList: TImportList;
    constructor Create;
    destructor Destroy; override;
    function NewSym:PSymbol;
    function Insert(name:string):PSymbol;
    function Find(name:string):PSymbol;
    procedure Clear;
    procedure OpenScope(sym: PSymbol);
    procedure CloseScope;
    property TopScope : PSymbol read FTopScope;
    procedure InsertProc(name: string; num: integer; tip: integer);
    function InsertType(name: string; form, size: integer):PTypeDesc;
    function NewType(form: integer):PTypeDesc;
    procedure PrintAll;
  end;

  ESymtabError = class(Exception);

const
  modeGlobalVar = 0;
  modeLocalVar = 1;
  modeFormalParametr = 2;
  ModeFunction = 3;
  ModeStaicArray = 4;   
  ModeLocalArray = 5;
  ModeExternalFunc = 128;  ModeSystemVar = 257;
  ModeStandProc = 6;
  ModeType = 7;
  ModeApiFunc = 8;

  FuncSet = [ModeStandProc, ModeExternalFunc, ModeFunction];

type
  PPointerArray = ^TPointerArray;
  TPointerArray = array[0..0]of pointer;
var
  FuncTable: PPointerArray;


  //типы
const
  ntInteger = 1;
  ntWord = 2;
  ntByte = 3;
  ntReal = 5;
  ntLongReal = 6;
  ntBoolean = 7;
  ntString = 8;
  ntArray = 16;
  ntRecord = 17;
  RealTypes = [ntReal, ntLongReal];
  IntTypes = [ntInteger, ntWord, ntByte];

var
  BoolType, IntType, WordType, ByteType, CharType : PTypeDesc;

const
  incfn = 1;  decfn = 2;

procedure NewConVal(var S:PSymbol);
procedure NewConSize(var S:PSymbol; size:integer);
procedure NewConStr(var S:PSymbol; size:integer; p:pchar);

implementation
uses windows;

procedure NewConVal(var S:PSymbol);
begin
  New(S.ConVal);
  with S.ConVal^ do begin
   str:=nil; ival:=0; fval:=0;
  end;
end;

procedure NewConSize(var S:PSymbol; size:integer);
begin
  NewConVal(S);
  with S.ConVal^ do begin
     GetMem(Str, size); ival:= size; 
  end;
end;

procedure NewConStr(var S:PSymbol; size:integer; p:pchar);
begin
  NewConVal(S); 
  with S.ConVal^ do begin
    GetMem(Str, size);
    ival:= size;
    System.Move(p^, Str^, size);
  end;
end;

procedure Error(msg: string);
begin
  raise ESymtabError.Create(msg);
end;

function TSymtab.NewType(form: integer):PTypeDesc;
begin
  New(result);
  result^.link:= nil;
  result^.next:= headType;
  headType:= result;
  result^.form:=form;
end;

constructor TSymtab.Create;
begin
  FHead:= nil;
  FTopScope:= NewSym;
  InsertTypes;
  InsertStdProcs;
  InsertApi;
end;

destructor TSymtab.Destroy;
begin  
  Clear;
  ImportList.Free;
end;

procedure TSymtab.Clear;
var
  nxt:  PSymbol;
begin
  while FHead <> nil do begin
    nxt:= FHead^.next; 
    if FHead^.ConVal <> nil then begin
      if FHead.ConVal.str <> nil then 
        FreeMem(FHead^.ConVal^.Str, FHead^.ConVal^.ival);
      Dispose(FHead^.ConVal);
    end;
    Dispose(FHead);
    FHead:= nxt;
  end; 
end;

procedure TSymtab.PrintAll;
var
  next: PSymbol;
  head: PSymbol;
begin
  head := FHead;
  while head <> nil do
  begin
    next := head^.next;
    if next <> nil then
    begin
      MessageBox(0, pchar('found symbol is name ' + next^.name), '', mb_ok);
    end;
    head := next;
  end;
end;

function TSymtab.NewSym:PSymbol;
begin
  New(result);
  result^.left:= nil;
  result^.right:= nil;
  result^.name:= '';
  result^.next:= FHead;
  result^.scope:=nil;
  result^.link:= nil;
  result^.ConVal:= nil;
  FHead:= result;
end;

function TSymtab.Insert(name: string):PSymbol;
var
  root, sym: PSymbol; 
  left: boolean;
begin
  root:= FTopScope;
  sym:= root^.right;
  left:= false;
  while true do begin
    if sym <> nil then begin
      //меньше
      if name < sym^.name then begin
        root:= sym;
        sym:= root^.left;
        left:= true;
      end   //больше
      else if name > sym^.name then begin
        root:= sym;
        sym:= root^.right;
        left:= false;
      end  //найдено
      else begin
         Error('Переопределение имени '+ name);
      end; 
    end //пусто
    else begin
      sym:= NewSym;
      sym^.name:= name;
      if left then root^.left:= sym
      else root^.right:= sym;
      break;
    end;       
  end;
  result:= sym;
end;

function TSymtab.Find(name:string):PSymbol;
var
  head, sym: PSymbol;
begin
  sym:= nil;
  head:= FTopScope;
  //обойти все контексты, начиная с самого вложенного 
  while True do begin
    sym:= head^.right;
    while True do begin              //поиск в контексте
      if sym = nil then break;
      if name < Sym^.name then  
        sym:= sym^.left
      else if name > Sym^.name then
        sym:= sym^.right
      else break;
    end;
    if sym <> nil then break;
    head:= head^.left; //контекст верхнего уровня
    if head = nil then break;
  end;
  result:= sym;
end;

procedure TSymtab.OpenScope(sym: PSymbol);
var
  head: PSymbol;
begin
  head:= NewSym;
  head^.link:= sym;
  if sym <> nil then sym^.scope:= head;
  head^.left:= FTopScope;
  FTopScope:= head;
end;

procedure TSymtab.CloseScope;
begin
  FTopScope:= FTopScope^.left;
end;

procedure TSymtab.InsertProc(name: string; num: integer; tip: integer);
var
  s: PSymbol;
begin
  s:=Insert(name);
  s^.mode:= ModeStandProc;
  s^.adr:= num;
end;

procedure TSymtab.InsertStdProcs;
begin
  InsertProc('inc', incfn, 0);
  InsertProc('dec', decfn, 0);
  //InsertProc('writeln', console_log, 0);
  //PrintAll;
end;

procedure console_log(m: string);
begin
  writeln(m);
end;


function TSymtab.InsertType(name: string; form, size: integer):PTypeDesc;
var
  sym: pSymbol;
begin
  result:= NewType(form);
  result^.size:= size;
  sym:= Insert(name);
  sym^.mode:= modeType;
  sym^.tip:= result;
end;

procedure TSymtab.InsertTypes;
begin
  booltype := InsertType('boolean', ntBoolean, 1);
  inttype := InsertType('integer', ntInteger, 4);
  wordtype := InsertType('word', ntWord, 2);
  bytetype:= InsertType('byte', ntByte, 1);
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
  item: PFuncItem;
begin
  result:= nil;
  for i:= 0 to FuncList.Count-1 do
  begin
    item := PFuncItem(FuncList[i]);
    if item^.name = name then
    begin
      result := FuncList[i];
      break;
    end;
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
 //MessageBox(0, pchar('get index of dll ' + result.DLLname), '', mb_ok);
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

//find dll
function TImportList.Find(name:string):TImportNode;
var
  i:integer;
begin
  result:=nil;
  for i:= 0 to DllCount-1 do 
    if List[i].Dllname = name then begin
      result:= list[i]; exit;
     end;
end;

//add dll
function TImportList.AddModule(name: string): TImportNode;
begin
  result:= TImportNode.Create;
  result.Dllname:= name;
  DllList.Add(result);
  inc(DllCount);
end;



procedure TSymtab.InsertApi;
var
  s:PSymbol;
begin
  ImportList:= TImportList.Create;
  with ImportList.AddModule('kernel32.dll') do begin
     Addfunc('ExitProcess');
  end;
  with ImportList.AddModule('art.dll') do begin
    s:= Insert('writeln'); s^.mode:= ModeApiFunc; s^.adr:=0;
    s^.func:= AddFunc('writeln');
    s:= Insert('write'); s^.mode:= modeApiFunc; s^.adr:=0;
    s^.func:= AddFunc('write');
    s:= Insert('box'); s^.mode:= modeApiFunc; s^.adr:=0;
    s^.func:= AddFunc('ShowMessage');
    s:= Insert('ShowConsole'); s^.mode:= ModeApiFunc; s^.adr:=0;
    s^.func:= Addfunc('ModalConsole');
  end;
end;

end.

