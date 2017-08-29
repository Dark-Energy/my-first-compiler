unit parser;
interface
uses SysUtils, Symtab, windows, Scanner,  Ptree;
type
  TParser = class
  private
    FTree: TParseTree;
    FTokenValue: TTokenValue;
    FSymtab: TSymtab;
    FScanner: TScanner;
    FLevel: integer;
    function Level1: PNode;
    function Level2: PNode;
    function Level3: PNode;
    function Level4: PNode;
    function Level5: PNode;
    function Level6: PNode;
    function Level7: PNode;
    function Level8: PNode;
    function FuncDef:PNode; 
    function StatList:PNode;
    procedure Error(msg:string);
    procedure CheckToken(Token: TTokenValue);
    procedure CheckToken_message(Token: TTokenValue; msg:string);
    procedure NextToken;
    function VarDef: PNode;
    function FormalList(var Count: integer):PNode;
    function DefList:Pnode;
    function ActualParams(func: PSymbol):PNode;
    function GetNumber: integer;
    function ArrayDef: PNode;
    function CallStdFunc(func: PSymbol):PNode;
    function ConstExpr:PNode;
    function GetType:PTypeDesc;
    function Index(arr: PSymbol):PNode;
    procedure GetInitArray(s:PSymbol);
  public
    function Parse(s: string):TParseTree; 
    property Symtab: TSymtab read FSymtab write FSymtab;
    constructor Create;
    destructor Destroy; override;
  end;


implementation

function TParser.GetType:PTypeDesc;
var
  sym : PSymbol;
begin
  sym := FSymtab.Find(FScanner.Name);
  if sym = nil then Error('неизвестный идентификатор');
  if sym^.mode <> ModeType then Error('имя типа требуется');
  result:= sym^.tip;
end;


procedure TParser.NextToken;
begin
  FTokenValue:= FScanner.NextToken;
end;

//получить число
function TParser.GetNumber: integer;
begin
  result:= StrToInt(FScanner.Name);
end;

procedure TParser.CheckToken(token: TTokenValue);
begin
  if FTokenValue = token then NextToken
  else begin
    MessageBox(0, pchar(LexToStr(FTokenValue)), '', mb_ok);
     Error(Format('Требуется %s, но найдено %s',
     [LexToStr(token), LexToStr(FTokenValue)]));
  end;
end;

procedure TParser.CheckToken_message(token: TTokenValue; msg:string);
begin
  if FTokenValue = token then NextToken
  else begin
    MessageBox(0, pchar(msg), '', mb_ok);
    Error(Format('Требуется %s, но найдено %s', [LexToStr(token), LexToStr(FTokenValue)]));
  end;

end;



(* ============================ ВЫРАЖЕНИЯ =================================== *)

{function TParser.Index(arr: PSymbol):PNode;
begin
  result:= nil;
  if arr^.tip^.form <> ntArray then Error('тип массива требуется');
  if FTokenValue <> tvLBrak then exit; NextToken;
  result:= Level1;
  CheckToken(tvRBrak);
end;}

function TParser.Index(arr: PSymbol):PNode;
var
  t:PTypeDesc;
  h, l, e: PNode;
begin
  result:= nil; t:= arr^.tip; h:= nil; l:=nil;
  if t.form <> ntArray then Error('тип массива требуется');
  if FTokenValue <> tvLBrak then exit;
  NextToken;
  while t<>nil do begin
    e:= Level1;
    //if isConst(e) and ((e.ConVal.ival <0) or (e.conVal.ival >= t.Size)) then
      //Error('range Error');
    if h = nil then h:= e else l.link:= e; l:=e;
    t:= t.link;
    if FTokenValue <> tvComma then break;
    NextToken;
  end;
  if t <> nil then Error('Выражение требуется');
  CheckToken(tvRBrak);
  result:= h;
end;


(* ----------- вызов встроенной функции ---------- *)
function TParser.CallStdFunc(func: PSymbol):PNode;
var
  num, kolvo: integer;
  x, y: PNode;
begin
  num:= func^.adr; kolvo:= 0;
  x:= nil; y:= nil;
  if FTokenValue = tvLp then begin
    NextToken;
    while True do begin 
      if kolvo = 0 then 
        x:= Level1
      else if kolvo = 1 then 
        y:= Level1;
      inc(kolvo);
      if FTokenValue = tvComma then NextToken
      else break;
    end;
    CheckToken(tvRp);
  end;
  result:= FTree.NewStdFunc(x, y, func, kolvo);
end;

(* ----------- актуальные параметры --------------- *)
function TParser.ActualParams(func: PSymbol):PNode;
var 
  head, last, tmp: PNode;
  fpar: PSymbol;
  cn: boolean;
begin
  last:= nil; head:= nil; fpar:= func^.fpar; 
  cn:= func^.mode = ModeFunction;
  while True do begin
  if (fpar = nil) and cn then Error('Лишние аргументы');
    tmp:= Level1;
    if head = nil then head:= tmp else last^.link:= tmp; last:= tmp;
    if FTokenValue <> tvComma then break else NextToken;
  end;
  CheckToken(tvRp);
  result:= head;
end;

//первичные выражения
function TParser.Level8: PNode;
var
  sym: PSymbol;
  x: PNode;
begin
  result:= nil;
  case FTokenValue of
    tvNumber: begin     //число
      result:= FTree.NewIntConst(GetNumber);  NextToken;
    end;
    tvName: begin     //имя
      sym:=  FSymtab.Find(FScanner.Name);
      //---- вызов фукнции
      if (sym^.mode = ModeFunction) or (sym^.mode=ModeExternalFunc) then begin
        if sym^.tip = nil then Error('требуется функция');
        result:= FTree.NewNode(tvCallFunc);
        result^.sym:= sym;
        NextToken;  if FTokenValue = tvLp then begin 
          NextToken;
          result^.left:= ActualParams(sym);
        end;
      end 
      else if (sym^.tip <> nil) and (sym^.tip^.form = ntArray) then begin
        NextToken; if FTokenValue = tvLBrak then x:= Index(sym);
        result:= FTree.NewNode(tvIndex); result^.right:= x; result^.sym:= sym;
      end  
      else begin
        result:= FTree.NewIdentNode(sym);
        NextToken;
      end;
    end;
    tvStrConst: begin
      result:= FTree.NewStrNode(FScanner.Name);
      NextToken;
    end;
    tvLp: begin
       NextToken;
       result:= Level1;
       if FTokenValue <> tvRp then raise EParserError.Create(')');
       NextToken;  
       exit; 
    end;
    else Error('Ошибка в выражении');
  end;
end;

function TParser.Level7: PNode;
begin
  if FTokenValue = tvSub then begin
    NextToken;
    result:= FTRee.NewOp(level8, nil, tvNeg);
  end
  else result:= level8;
end;

//умножение и деление
function TParser.Level6: PNode;
var
  token:TTokenValue;
begin
  result:= Level7;
  while FTokenValue in [tvMul, tvDiv, tvMod] do begin
    token:= FTokenValue;
    NextToken;
    result:= FTree.NewOp(result, level7, token);
  end;
end;

//сложение, вычитание
function TParser.Level5: PNode;
var
  token: TTokenValue;
begin
  result:= Level6;
  while FTokenValue in [tvAdd, tvSub] do begin
    token:= FTokenValue;
    NextToken;
    result:= FTree.NewOp(result, Level6, token);
  end;
end;

//отношения
function TParser.Level4: PNode;
const
  RelatOp = [tvGt..tvLt];
var
  token: TTokenValue;
begin
  result:=Level5;
  if FTokenValue in RelatOp then begin
    token:= FTokenValue;
    NextToken;
    result:= FTree.NewOp(result, Level5, token);
  end;
end;

//Логическое НЕ
function TParser.level3: PNode;
begin
  if FTokenValue = tvNot then begin
    NextToken;
    result:= FTree.NewOp(Level4, nil, tvNot);
  end
  else result:= Level4;
end;

//Логическое И
function TParser.Level2: PNode;
begin
  result:= Level3;
  while FTokenValue = tvAnd do begin
    NextToken;
    result:= FTree.NewOp(result, Level3, tvAnd);
  end;
end;

//Логическое ИЛИ
function TParser.Level1: PNode;
begin
  result:= level2;
  while FTokenValue = tvOr do begin
    NextToken;
    result:= FTree.NewOp(result, level2, tvOr);
  end;
end;

(* ************************* ОПЕРАТОРЫ ************************************* *)
(* ------------ список операторов --------------- *)
function TParser.StatList:PNode;
var
  x, y, z, lastIf, last: PNode;
  sym: PSymbol;
begin
  result:= nil;
  last:= nil;
  while True do begin
    x:= nil;
    if FTokenValue = tvName then begin (* присваиввание или вызов фукнции *)
      sym:= FSymtab.Find(FScanner.Name);
      if sym=nil then Error('Неизвестный идентификатор '+FScanner.Name);
      NextToken;
      if (sym^.mode = ModeFunction) or (sym^.mode=modeApiFunc) then begin 
        x:= FTree.NewNode(tvCallFunc);         
        x^.sym:= sym;
        if FTokenVAlue = tvLp then begin
          NextToken;
          x^.left:= ActualParams(sym);
        end;
      end (* стандартная процедура *)
      else if sym^.mode = ModeStandProc then begin 
        x:= CallStdFunc(sym);
      end //присваивание массиву или скаляру
      else begin  
        x:= FTree.NewNode(tvAssign);
        x^.sym:= sym; 
        if FTokenValue = tvLBrak then begin
          x^.left:=Index(sym);
        end;
        if FTokenValue <> tvAssign then 
          Error('Требуется = ');
        NextToken;
        x^.right:=  Level1;
      end
    end
     (* верхний узел - tvIfElse *)
     (* лево - узел tvIf, право - список операторов tvElse *) 
     (* link -  список узлов tvElseIf *)
     (* узел tvElseif: *)
     (* лево - выражение, право - список операторов *)
     (* узел tvIf  *) 
     (* лево - выражение, право - список операторов *)
    else if FTokenValue = tvIf then begin   (*оператор IF *)
      NextToken; //след символ
      x:= Level1;  //выражение
      //CheckBool(x);  //проверка, что булево
      CheckToken(tvThen); //слово then 
      y:= StatList; //последовательность операторов
      x:= FTree.NewBinNode(x, y, tvIf);
      lastif:=x;
      WHILE FTokenValue = tvElsif DO begin
        NextToken; 
        y:= Level1; 
        //CheckBool(x);
        CheckToken(tvThen); 
        z:= StatList;
        z:= FTree.NewBinNode(y, z, tvElsif);
        lastif^.link:= z; lastif:= z;
      END;
      IF FTokenValue = tvElse THEN begin
        NextToken;    
        y:= StatList;
      end
      ELSE  y:= nil;
      x:= FTree.NewBinNode(x, y, tvIfElse);
      //first
      //CheckToken(tvEnd);
      CheckToken_message(tvEnd, 'return from function');
    end //возврат из функции
    else if FTokenValue = tvReturn then begin   
      NextToken;  
      if (FSymtab.TopScope^.link^.tip <> nil) then begin  //если это фукнция 
         x:= Level1;
         if x = nil then Error('требуется вернуть значение'); 
         x:= FTree.NewBinNode(x, nil, tvReturn);
      end;
    end 
    else if FTokenValue = tvWhile then begin
      NextToken;
      x:= LEvel1;
     //CheckBool(x); 
      CheckToken(tvDo);
      y:= StatList;
      x:= FTree.NewBinNode(x, y, tvWhile);
      //second
      CheckToken_message(tvEnd, 'end of while');
    end
    else if FTokenValue = tvRepeat then begin   
      NextToken;
      x:= StatList;
      if FTokenValue = tvUntil then begin
        NextToken;
        y:= Level1;
        //CheckBool(y)
      end
      else raise EParserError.Create('треубется until');
      x:= FTree.NewBinNode(y, x, tvRepeat);
    end
    else if FTokenValue = tvFor then begin
      NextToken;
    END; (* конец разбора *)
    IF x <> nil THEN begin
      if result = nil then result:= x
      else last^.link:= x;
      last:= x;
    end;
    IF FTokenValue = tvSemicolon THEN
      NextToken
    else if (FTokenValue <= tvName) OR
      (tvIf <= FTokenVAlue) and (FTokenVAlue <= tvReturn) THEN
      Error('недопустимый оператор!')
    else exit; (* выйти из цикла *)
  END
end;

(* ***************** РАЗБОР ОПИСАНИЙ ************************************* *)

function TParser.ConstExpr:PNode;
begin
  result:= Level1;
  if not IsConst(result) then Error('константа требуется');
end;

procedure TParser.GetInitArray(s: PSymbol);
type
  PIntArray = ^TIntArray;
  TIntArray = array[0..0] of integer;
var
  e, h, l:PNode;
  i:integer;
  t:PTypeDesc;
  ptr: PIntArray;
begin
  if FTokenValue <> tvLp then Error('требуется )');
  h:=nil; l:=nil; i:=0;
  repeat 
    NextToken;
    e:= Level1; //получить значение элемента массива
    if h <> nil then l.link:= e else h:= l; l:= e;
    inc(i);
  until FTokenValue <> tvComma;
  CheckToken(tvRp);
  t:= s.tip.BaseType; NewConSize(S, t.Size * i);
  ptr:= pointer(S.ConVal.Str);
  i:=0; while h <> nil do begin
    ptr^[i] := e.ConVal.ival;
    h:= h.link; inc(i);
  end;
end;

(* ----------- описание типа массива -------- *)
function TParser.ArrayDef: PNode;
var
  e:PNode;
  first, tmp: PSymbol;
  head, last, x: PTypeDesc;
begin
  head:=nil; last:=nil; 
  //размерности массива
  while true do begin
    e:= ConstExpr; 
    if e^.ntype <> tvIntNum then Error('Целый тип требуется');
    x:= FSymtab.NewType(ntArray); x.Size:= e.ConVal.ival;
    //связать в список
    if head = nil then  head:= x else last^.link:= x; last:= x;
    if FTokenValue <> tvComma then break;
    NextToken;
  end;
  head^.BaseType:= GetType;  NextToken;
  //for (x=head; x!=NULL; x=x->link) x->BaseType=head->BaseType;
  x:= head; while x <>nil do begin x^.BaseType:= head^.BaseType; x:= x.link; end;

  first:= nil;
  //список имен переменных
  while True do begin
    if FTokenValue <> tvName then Error('имя требуется');
    tmp:= FSymtab.Insert(FScanner.Name);
    tmp^.next:= first; first:= tmp; tmp^.tip:= head;
    NextToken; 
    if FTokenValue = tvAssign then begin 
      NextToken;
      GetInitArray(tmp);
    end;
    if FTokenValue = tvComma then NextToken else break;
  end;
  //cоздать узел
  e:= FTree.NewNode(tvArray);
  e^.Sym:= first;
  e^.Sym^.tip:= head;
  result:= e;
end;


(* ---------- описание переменной ------------ *)
function TParser.VarDef:PNode;
var
  last, head, tmp: PSymbol;
  tip: PTypeDesc;
begin
  tip:= GetType;
  NextToken;  head:= nil; last:=nil;
  while True do begin
    if FTokenValue <> tvName then Error('требуется имя');
    tmp:= FSymtab.Insert(FScanner.Name);
    if head = nil then head:= tmp else last^.link:= tmp;
    last:= tmp; 
    if FLevel > 0 then tmp^.mode:= ModeLocalVar
    else tmp^.mode:= ModeGlobalVar;
    tmp^.tip:= tip; 
    NextToken;
    if FtokenValue <> tvComma then break;
    NextToken;
  end;
  result:= FTree.NewBinNode(nil, nil, tvVarDef);
  result^.sym:= head;
end;

(* получить список формальных параметров :
  (Имя типа парам1, парам2; Имя типа парам3, парам4) *)
function TParser.FormalList(var Count: integer):PNode;
var
  tail, head, tmp: PSymbol;
  next, last: PNode;
  tip: PTypeDesc;
begin
  result:= nil; last:= nil; Count:= 0;
  while True do begin (* Описание1; Описание2*)
    tip:= GetType; NextToken; 
    tail:= nil; head:= nil;
    while True do begin
      inc(Count);
      if FtokenValue <> tvName then Error('Требуется имя');
      tmp:= FSymtab.Insert(FScanner.Name); NextToken;
      tmp^.mode:= ModeFormalParametr;
      tmp^.tip:= Tip; 
      if head = nil then  head:= tmp  else tail^.link:= tmp; tail:= tmp;
      tmp^.prev:= head; 
      if FTokenValue <> tvComma then break;
      NextToken;
    end;
    next:= FTree.NewBinNode(nil, nil, tvVar); next^.sym:= head;
    if last <> nil then last^.link:= next;
    if result = nil then result:= next;
    last:= next;
    if FTokenValue = tvRp then break;
    CheckToken(tvSemicolon);
   end;
  result:= last;
end;

(* --------- описание функции -------------- *)
function TParser.FuncDef:PNode;
var
  func: PSymbol;
  formals, vars, body:PNode;
  Count: integer;
begin
  if FTokenValue <> tvName then Error('Требуется имя');

  func:= FSymtab.Insert(FScanner.Name);   NextToken;
  New(func^.ConVal); func^.ConVal^.ival:= -1; //для типа
  func^.mode:= ModeFunction;
  FSymtab.OpenScope(func);  inc(FLevel);  //контекст фукнции

  //список формальных параметров
  if FTokenValue = tvLp then begin
    NextToken;
    formals:= FormalList(Count);
    New(func^.ConVal); func^.ConVal^.dop:= Count;
    CheckToken(tvRp);
    func^.fpar:= formals^.sym;
  end
  else begin func^.fpar:= nil; formals:= nil; end;

  func^.tip:= nil;
  if FTokenValue = tvColon then begin           //тип функции
    NextToken;
    func^.tip:= GetType;
    NextToken; CheckToken(tvSemicolon);
  end
  else NextToken;

  vars:= nil;
  while FTokenValue = tvName do begin
    vars:= VarDef;
    CheckToken(tvSemicolon);
  end;
  CheckToken(tvBegin);
  body:= StatList;
  //third
  CheckToken_message(tvEnd, 'end of block, started with begin');

  FSymtab.CloseScope;  dec(FLevel);
  if formals <>nil then formals^.link:= vars
  else formals:= vars;
  result:= FTree.NewBinNode(formals, body, tvDefun);
  result^.sym:= func;
end;

function TParser.DefList:PNode;
var
  first, last, tmp, next: PNode;   
  sym, tail: PSymbol;
begin  
  first:= nil; last:= nil; tmp:= nil;
  while True do begin
     //переменная
    if FTokenValue = tvName then begin
      tmp:= VarDef;
    end
     //описание типа запись
    else if FTokenValue = tvRecord then begin
      NextToken; 
      if FTokenValue <> tvName then Error('требуется имя');
      sym:= FSymtab.Insert(FScanner.Name); sym^.mode:= ModeType;
      NextToken;  tail:=nil;
      while True do begin
        tmp:= VarDef; 
        if tail <> nil then tail^.link:= tmp^.sym else sym^.fpar:= tmp^.sym;
        tail:= tmp^.sym; 
        if FTokenValue <> tvSemicolon then break else NextToken;
        if FTokenValue = tvEnd then break;
      end;
      //fourth
      CheckToken_message(tvEnd, 'end of record');
      tmp:= FTree.NewNode(tvRecord); tmp^.sym:= sym; 
      sym^.tip:= FSymtab.NewType(ntRecord); sym^.tip^.size:=0;
    end
    //описание массив 
    else if FTokenValue = tvArray then begin
      NextToken;
      tmp:= ArrayDef;
    end
    else if FtokenValue = tvDefun then begin
      NextToken;
      tmp:= FuncDef;
    end
    else if FTokenValue = tvBegin then begin
      NextToken;  tmp:= StatList;
      tmp:= FTree.NewBinNode(tmp, nil, tvBegin);
    end
    else break;
    if last <> nil then last^.link:= tmp;
    last:= tmp;
    if first = nil then first:= tmp; 
    if FTokenValue = tvEnd then break
    else if FTokenValue = tvSemicolon then NextToken    
    else Error('Требуется ;');
  end;
  //file
  CheckToken_message(tvEnd, 'end of file? end with dot');
  CheckToken(tvDot);
  result:= first;
end;

(* ------------- основная часть ---------------------- *)
procedure TParser.Error(msg:string);
begin
  raise EParserError.Create(msg+#13#10+'LineNo : '+
     IntToStr(FScanner.FLineNumber));
end;


function TParser.Parse(s:string):TParseTree;
begin
  //подготовка к разбору
  FTree:= TParseTree.Create;
  FScanner.Init(s);
  NextToken;
  FLevel:= 0;
  FSymtab.OpenScope(nil);
  FTree.Root:= DefList;
  FSymtab.CloseScope;
  result:= FTree;
end;

constructor TParser.Create;
begin
  FScanner:= TScanner.Create;
end;

destructor TParser.Destroy;
begin
  FScanner.Free;
  inherited Destroy;
end;

end.