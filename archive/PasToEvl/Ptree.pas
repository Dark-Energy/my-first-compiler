unit ptree;
interface
uses Scanner, Symtab, sysutils;

type
  PNode = ^TNode;
  TNode = record
    ntype: TTokenValue; //значение узла
    left, right, next, link: PNode;
    ConVal: PConst; //константное значение
    sym: PSymbol; //символ
    tip: PTypeDesc; //результирующий тип
  end;

  TParseTree = class
  private
    FHead: PNode;
    FRoot: PNode;
    FCount: integer;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    function NewNode(ntype: TTokenValue):PNode;
    procedure Arith(var left, right, result: PNode; Op: TTokenValue);
    procedure Logic(var left, right, result: PNode; Op: TTokenValue);
    procedure Compare(left, right: PNode; var result:PNode; Op: TTokenValue);
    function NewOp(left, right: PNode; ntype: TTokenValue):PNode;
    function NewIntConst(value: integer):PNode; 
    function NewBoolConst(value: integer):PNode; 
    function NewIdentNode(ident: PSymbol):PNode;
    function NewBinNode(left, right: PNode; ntype: TTokenValue):PNode;
    function NewStdFunc(left, right: PNode; func: PSymbol; kolvo: integer):PNode; 
    function NewStrNode(str: string):PNode; 
    property Root : PNode read FRoot write FRoot;
    property Count : integer read FCount;
  end;


  EParserError = class(Exception)
  public
    FLine, FCol: integer;
  end;  

function isConst(node: PNode):boolean;

implementation

function isConst(node: PNode):boolean;
begin
  result:= false;
  if node = nil then exit;
  result:= node^.ntype in [tvIntNum, tvTrue, tvFalse];
end;

const
  EIncompTypes = 'Ќесовместимые типы';

procedure Error(msg: string);
begin
  raise EParserError.Create(msg);
end;

constructor TParseTree.Create;
begin
  FHead:= nil;
  FRoot:= nil;
  FCount:= 0;
end;

destructor TParseTree.Destroy;
begin
  Clear;
  inherited Destroy;
end;

procedure TParseTree.Clear;
begin
  while FHead <> nil do begin
    FRoot:= FHead^.next;
    if FHead^.ConVal <> nil then 
      Dispose(FHead^.ConVal);
    Dispose(FHead);
    FHead:= FRoot;
  end;
  FCount:= 0;
end;

(* =================== создание узлов ================================= *)
function TParseTree.NewNode(ntype: TTokenValue):PNode;
begin  
  New(result);
  result^.next:= FHead;
  FHead:= result;
  result^.left:= nil;
  result^.right:= nil;
  result^.ntype:= ntype;
  result^.ConVal:= nil;
  result^.link:= nil;
  inc(FCount);
end;

function TParseTree.NewIdentNode(ident: PSymbol):PNode;
begin
  result:= NewNode(tvName);
  result^.sym:= ident;
end;

function TParseTree.NewIntConst(value: integer):PNode;
begin
  result:= newNode(tvIntNum);
  New(result^.ConVal);
  result^.ConVal^.ival:= value;
  result^.tip := Symtab.IntType;
end;

function TParseTree.NewBoolConst(value: integer):PNode;
begin
  if value <> 0 then result:= NewNode(tvTrue)
  else result:= NewNode(tvFalse);
  result^.tip := Symtab.BoolType;
end;

function TParseTree.NewBinNode(left, right: PNode; ntype: TTokenValue):PNode;
begin
  result:= NewNode(ntype);
  result^.left:= left;
  result^.right:= right;
end;

(* =============== —вертвывание констант ================================== *)
(* арифметика *)
procedure TParseTree.Arith(var left, right, result: PNode; Op: TTokenValue);
var
  l, r, res: integer;
begin
  l:= left^.ConVal^.ival;
  r:= right^.ConVal^.ival;
  res:=0;
  case op of
    tvAdd: res:= l + r;
    tvSub: res:= l - r;
    tvMul: res:= l * r;
    tvDiv: res:= l div r;
    tvMod: res:= l  mod r;
  end;
  result:= NewIntConst(res);
end;

(* сравнени€ *)
procedure TParseTree.Compare(left, right: PNode; var result:PNode; Op: TTokenValue);
var
  l, r, res: integer;
begin
  l:= left^.ConVal^.ival;
  r:= right^.ConVal^.ival;
  res:=0;
  case Op of
    tvGt: res:= ord(l > r);
    tvGe: res:= ord(l >= r);
    tvEq: res:= ord(l = r);
    tvNE: res:= ord(l <> r);
    tvLe: res:= ord(l <= r);
    tvLt: res:= ord(l < r);
  end;
  result:= NewBoolConst(res);
end;

(* логические операции *)
procedure TParseTree.Logic(var left, right, result: PNode; Op: TTokenValue);
var
  res: integer;
begin
  res:=0;
  case Op of
    tvAnd:  res:= ord((left^.ntype = tvTrue) and (right^.ntype = tvTrue));
    tvOr:   res:= ord((left^.ntype = tvTrue) or (right^.ntype = tvTrue));
    tvNot : res:= ord(not (left^.ntype = tvTrue));
  end;
  result:= NewBoolConst(res);
end;

(* это выражение - константное? *)

(* --------- помечает узлы соотв. типом ---------- *)
procedure CheckTypes(node: PNode);
begin
  with node^ do begin
    case ntype of
      tvName: node^.tip:= sym.tip;
      tvIntNum: node^.tip := IntType;
      tvFalse, tvTrue: tip:= BoolType;
      tvAdd, tvSub, tvMul, tvDiv, tvMod, tvNeg:
        if left^.tip^.form in RealTypes then tip:= left^.tip
        else if right^.tip^.form in RealTypes then tip := right^.tip
        else if (left^.tip^.form in IntTypes) and
             (right^.tip^.form in IntTypes) then tip:= left^.tip
        else Error(EIncompTypes);
      tvOr, tvAnd :
        if (left^.tip^.form <> ntBoolean) or
           (right^.tip^.form <> ntBoolean) then
          Error(EIncompTypes);
      tvNot: if left^.tip^.form <> ntBoolean then
          Error(EIncompTypes);
      tvCallFunc: tip := sym^.tip;
    end;
  end;
end;

(* создать узел-операцию *)
function TParseTree.NewOp(left, right: PNode; ntype: TTokenValue):PNode;
var
  a, b: boolean;
begin
  if ntype = tvNot then begin
    if isConst(left) then Logic(left, right, result, tvNot);
    left:= nil;
    exit;
  end;
  a:= isConst(left);
  b:= isConst(right);
  if  ntype in [tvOr, tvAnd] then begin
    //если оба операнда - логические константы
    if a and b then begin
      Logic(left, right, result, ntype);
      exit;
    end
    else if a then begin //если константа только первый операнд
      case ntype of
        tvOr: if (left^.ntype = tvTrue) then  //результат уже известен
            result:= NewBoolConst(1)
          else result:= right; // результат - правое подвыражение
        tvAnd : if (left^.ntype = tvFalse) then
            result:= NewBoolConst(0)
          else result:= right;
      end;
      exit;
    end
    else result:= NewBinNode(left, right, ntype);
  end
  else if a and b then begin
    if ntype in [tvAdd, tvSub, tvMul, tvDiv, tvMod] then
      Arith(left, right, result, ntype)
    else if ntype in [tvGT..tvLt] then
      Compare(left, right, result, ntype);
    exit;
  end
  else result:= NewBinNode(left, right, ntype);
end;


function TParseTree.NewStdFunc(left, right: PNode; func: PSymbol; kolvo: integer):PNode;
begin
  if left <> nil then left^.link:= right;
  result:= NewBinNode(left, nil, tvCallFunc);
  result^.sym:= func;
end;

function NewStr(str:string):PChar;
begin
  GetMem(result, length(str)+1);
  System.Move(str[1], result^, length(str)+1);
end;

function TParseTree.NewStrNode(str: string):PNode;
begin
  result:= NewNode(tvStrConst);
  New(result^.ConVal); 
  result^.ConVal^.ival:= length(str);
  result^.ConVal^.str:= NewStr(pchar(str));
end;

end.