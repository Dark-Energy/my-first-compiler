unit PARS01b;
interface
Uses SysUtils, Classes, WinProcs,WinTypes, Dialogs, MStream, Math;
type
  TExprType = (etInt, etFloat, etBool, etChar, etVector, etString, etMatrix, etArray);

  TTokenType = (
  ttEof,  ttInt, ttReal,  ttBool, ttChar, ttVoid,ttString,
   ttNull,
   ttName,  ttWhile,  ttWend,  ttFor,  ttTo, ttStep, ttNext,
   ttRepeat, ttUntil, ttIf, ttThen, ttElse, ttEndIf,
   ttBreak, ttContinue, ttDefun,  ttReturn, ttEndFn,
   ttSelect, ttCase, ttOf, ttDefault, ttEndsel, ttNeg,
  {лексемы арифметических операций}
  ttAdd, ttSub, ttOr, ttXor,
  ttMul, ttFDiv, ttDiv, ttMod, ttAnd, ttShl,ttShr,
  ttPow,  ttNot,
  {операции сравнения}
  ttLT, ttLE, ttEq, ttNe, ttGe, ttGt,
  {логические операции}
  ttLNOT, ttLAND, ttLOR, ttLXor,
  {операция присваивания}
  ttAssign,
  {сокращенне операции присваивания}
  ttAddAss, ttSubAss, ttOrAss,  ttXorAss,
  ttMulAss, ttFDivAss, ttDivAss, ttModAss, ttAndAss, ttShlAss, ttShrAss,
  ttNotAss, ttPowAss, ttAddAsg,
  ttLiteral,
  ttComma, ttSemi, ttLp, ttRp, ttLBracket, ttRBracket, ttColon,
  ttQwest, ttDot, ttQuote, ttBQuote,
  ttTrue, ttFalse, ttDo, ttVector,   ttGoto,
  ttInc, ttDec, ttLoop, ttLend,
  ttProg, ttMatrix, ttVar, ttBegin,
  ttArray, ttIntConst, ttFloatConst, ttEnd);

  PStrRec = ^TStrRec;
  TStrRec = record
    AllocSize:longint;
    RefCount:longint;
    Dlin:longint;
    Str:PChar
  end;

  PArray = ^TArray;
  TArray = record
    DimCount: byte;
    size:integer;
    ElemType: TTokenType;
    ElemSize:integer;
    Data: PChar;
    Bounds: array[0..255] of integer;
  end;

  PNode = ^TNode;
  TNode = record
    case ntype:TExprType of
      etInt:(ival:longint);
      etFloat:(fval:double);
      etBool:(bval:integer);
      etChar:(cval:char);
      etVector:(vtype: TTokenType;
      vsize:integer; vdata:PChar);
      etString:(StrRec: PStrRec);
      etMatrix:(mtype:TTokenType;
      size1,size2:integer;
      mdata:pchar);
      etArray:(Arr:PArray);
  end;

  TProc = procedure;

  PFunc = ^TFunc;
  TFunc = record
    addr:pointer;
    Ftype:integer;
    Count:integer;
    List:string;
  end;

  PSymboll = ^TSymboll;

  PUsDef = ^TUsDef;
  TUsDef = record
    ArgCount:integer;
    VarCount:integer;
    Locals:PSymboll;
    addr:PChar;
    ftype:TTokenType;
    fend:PChar;
  end;

  TSymType = (stName,  stFunc, stKey, stUsDef, stLocal);

  TSymboll = record
    name:PChar;
    next:PSymboll;
    ptype:integer;
    kind:byte;
    case stype: TSymType of
      stKey:(val:TTokenType);
      stName:(value:PNode);
      stFunc:(func:PFunc);
      stUsDef:(UsDef:PUsDef);
      stLocal:(offs:integer;
      ltype:TTokenType);
    end;



  TSymbollArray = array[0..16000] of PSymboll;
  PSymbollArray = ^TSymbollArray;

  TNodeArray = array[0..2000] of TNode;
  PNodeArray = ^TNodeArray;

  TPNodeArray = array[0..16000] of PNode;
  PPNodeArray = ^TPNodeArray;

const
  ltInt = 1;
  ltFloat = 2;
  MaxTab = 200;
  EvalStackSize = 200;
  ftProc = 0;
  ftFunc = 1;

type
  TSymTab = class
  private
    FSymTab: PSymbollArray;
    FTabSize: integer;
    procedure RemoveAllNames;
  public
    constructor Create(ATabSize:integer);
    destructor Free;
    function hash(name:PChar):integer;
    function MakeSym(name:PChar; SymType: TSymType):PSymboll;
    function FindSym(name:PChar):PSymboll;
    procedure FreeSym(sym: PSymboll);
    procedure FreeName(name:PChar);
    procedure DeleteNames;
    procedure RemoveName(name:PChar);
    procedure Clear;
    procedure Report(Strings:TStrings);
    function MakeName(name:PChar; AType:TExprType):PSymboll;
    function HashCompName(name1, name2:pchar):integer;
    property TabSize: integer read fTabSize;
    property SymTab: PSymbollArray read FSymTab;
  end;

  procedure Parser;
  procedure SetBuffer(Buf:PChar; Size:longint);
  procedure SetSymTab(SymTab:TSymTab);
  function GetSymTab:TSymTab;
  procedure InitParser;
  procedure FreeParser;
  function GetExpr(Buf:PChar; size:integer):PNode;
  function GetStream:TStream;
  procedure SetStream(Stream:TStream);
  procedure SetStrings(Strings:TStrings);
  function GetStrings:TStrings;

  var
   CountLines:integer;
   CountChars:integer;

type

  ESyntaxError = class(Exception)
  private
    FPos:integer;
    constructor Create(Msg:string);
    constructor FCreate(Msg:integer);
    constructor CreateFmt(Msg:string; Fmt:array of const);
  public
    property Pos:integer read FPos;
  end;


implementation


function NewString(str:pchar;len:integer):PStrRec;
var
  p:pchar;
begin
  GetMem(result, sizeof(TStrRec)+len+1);
  p:= pchar(result);
  p:= p+sizeof(TStrRec);
  if str <> nil then
    StrCopy(p, str);
  result^.AllocSize:= len+1;
  result^.Dlin:= len;
  result^.Str:=p;
  result^.RefCount:=1;
end;


function NewTempString(str:pchar;len:integer):PStrRec;
begin
  result:=NewString(str, len);
  dec(result^.RefCount);
end;

  {создать новую строкову, инициализованную строковой константой}
  function InitStrFromPchar(source:pchar; len:integer):PStrRec;
  var
    p:PAnsiChar;
  begin
     GetMem(result, sizeof(TStrRec)+len+1);
     p:=pchar(result);
     p:=p+sizeof(TStrRec);
     result^.Str:=p;
     if source <> nil then
       StrCopy(p,source);
     result^.RefCount:=1;
     result^.AllocSize:=len+1;
     result^.Dlin:=len;
  end;

  function CreateStr(size:integer):PStrRec;
  begin
    result:=InitStrFromPchar(nil, size);
  end;

  procedure InitStrFromStr(dest:PNode; source:PStrRec);
  begin
    dest^.StrRec:= source;
    if source <> nil then
      inc(source^.RefCount);
  end;


  procedure AssignStrToStr(Dest:PNode; Source:PNode);
  var
    size:integer;
  begin
    with Dest^ do
      if StrRec <> nil then
        if StrRec^.RefCount > 1 then
          dec(StrRec^.RefCount)
        else begin
          size:= StrRec^.AllocSize+sizeof(TStrRec);
          FreeMem(StrRec, size);
        end;

    Dest^.StrRec:= Source^.StrRec;
    if Source^.StrRec<>nil then
      inc(Source^.StrRec^.RefCount);
  end;

  procedure AssignStrToPchar(dest:PNode; source:pchar);
  var
    size:integer;
  begin
    with dest^ do
      if StrRec<>nil then
        if StrRec^.RefCount > 1 then
          dec(StrRec^.RefCount)
        else begin
          Size:= StrRec^.AllocSize+Sizeof(TStrRec);
          FreeMem(StrRec, Size);
        end;
    if source <> nil then
      dest^.StrRec:= InitStrFromPchar(source, StrLen(source))
    else dest^.StrRec:=nil;
  end;

  procedure ClrString(Str:PNode);
  var
    size:integer;
  begin
    with Str^ do begin
      if StrRec=nil then exit;
      dec(StrRec^.RefCount);
      if StrRec^.RefCount < 1 then begin
        size:=StrRec^.AllocSize+sizeof(TStrRec);
        FreeMem(StrRec, size);
      end;
      StrRec:=nil;
    end;
  end;

function CatStr(left, right:PStrRec):PStrRec;
var
  size:integer;
begin
  size:= left^.Dlin + right^.Dlin+1; //общая длина
  result:= NewString(nil, size);   //новая строка
  StrCopy(result^.Str, left^.Str); //копировать
  StrCat(result^.Str, right^.Str); //сцепить
end;

procedure AddStrToStr(dest:PNode; Source:PStrRec);
var
  tem:PStrRec;
begin
  with dest^ do begin
    tem:=CatStr(dest^.StrRec, source);
    ClrString(dest);
    dest^.StrRec:=tem;
  end;
end;

type
  plongint = ^longint;
  pdouble = ^double;
  pinteger = ^integer;

const
  Sizes:array[ttInt..ttChar]of integer = (
  sizeof(longint), sizeof(double), sizeof(integer), sizeof(char)
  );


  constructor TSymTab.Create(ATabSize:integer);
  var
    i:integer;
  begin
    FTabSize:= ATabSize;
    try
      GetMem(FSymTab, SizeOf(TSymboll) * FTabSize);
      for i:= 0 to FTabSize-1 do FSymTab^[i]:= nil;
    except
      raise;
    end;
  end;

 procedure TSymTab.FreeSym(Sym:PSymboll);
 var
   node:PNode;
   i:integer;
   Cur, Next: PSymboll;
   size:integer;
 begin
   if Sym = nil then exit;
   try
     case Sym^.stype of
       stName:
         begin
           node:= Sym^.value;
           if Node<>nil then begin
             if (Node^.ntype = etVector) and (Node^.vdata<>nil) then begin
               i:=Node^.vsize;
               case Node^.vtype of
                 ttInt: i:= i*SizeOf(longint);
                 ttReal: i:= i*SizeOf(double);
                 ttBool: i:= i*SizeOf(integer);
                 ttChar: i:= i*sizeof(char);
               end;
               FreeMem(Node^.vdata, i);
             end
             else if node^.ntype = etString then begin
               if node^.StrRec<>nil then begin
                 if node^.StrRec^.RefCount>1 then
                   dec(node^.StrRec^.RefCount)
               end
               else
                 ClrString(node);
             end
             else if node^.ntype = etArray then begin
                if node^.Arr<>nil then begin
                  if Node^.Arr^.Data<>nil then
                    FreeMem(Node^.Arr^.Data, Node^.Arr^.Size);
                  FreeMem(node^.Arr, sizeof(TArray));
                end;
             end
             else if node^.ntype = etMatrix then begin
               if node^.mdata<>nil then begin
                 size:=node^.size1;
                 size:=size*node^.size2;
                 size:=size*Sizes[node^.mtype];
                 FreeMem(node^.mdata, size);
               end;
             end;
             FreeMem(Node, SizeOf(TNode));
           end;
         end;
     stFunc:
       begin
         if Sym^.func<>nil then FreeMem(Sym^.func, SizeOf(TFunc));
       end;
     stUsDef:
       begin
         Cur:= Sym^.UsDef^.Locals;
         while cur<>nil do begin
           Next:= cur^.next;
           FreeSym(cur);
           cur:= next;
         end;
         FreeMem(Sym^.UsDef, SizeOf(TUsDef));
       end;
   end;
   if sym^.name<>nil then StrDispose(Sym^.name);
   FreeMem(Sym, SizeOf(TSymboll));
except
   raise;
end;
end;

 destructor TSymTab.Free;
 var
   i:integer;
   next, cur: PSymboll;
 begin
   for i:= 0 to FTabSize-1 do begin
     cur:= FSymTab^[i];
     while Cur<>nil do begin
       Next:= Cur^.next;
       FreeSym(Cur);
       Cur:=Next;
     end;
  end;
end;

procedure TSymTab.FreeName(name:PChar);
var
  sym,prev:PSymboll;
  i:integer;
begin
  i:= hash(name);
  Sym:=FSymTab^[i];
  prev:=nil;
  while Sym<>nil do begin
    if StrIComp(name, Sym^.name)= 0 then break;
    prev:= sym;
    Sym:= Sym^.next;
  end;
  if Sym = nil then exit;
  if prev<>nil then prev^.next:= Sym^.next;
  FreeSym(sym);
end;

procedure TSymTab.RemoveName(name:PChar);
var
  sym,prev:PSymboll;
  i:integer;
begin
  i:= hash(name);
  Sym:=FSymTab^[i];
  prev:=nil;
  while Sym<>nil do begin
    if StrIComp(name, Sym^.name)= 0 then break;
    prev:= sym;
    Sym:= Sym^.next;
  end;
  if Sym = nil then exit;
  if prev<>nil then prev^.next:= Sym^.next;
end;


function TSymTab.FindSym(name:PChar):PSymboll;
var
  i:integer;
begin
  i:= hash(name);
  result:= FSymTab^[i];
  while result<>nil do begin
    if StrIComp(result^.name, name)=0 then break;
    result:= result^.next;
  end;
end;

function TSymTab.MakeSym(name:PChar; SymType:TSymType):PSymboll;
var
  i:integer;
begin
  try
    result:= FindSym(name);
    if result<>nil then result:= nil
    else begin
      i:=hash(name);
      GetMem(result, SizeOf(TSymboll));
      result^.next:=FSymTab^[i];
      FSymTab^[i]:= result;
      result^.name:= StrNew(name);
      result^.stype:= SymType;
    end;
  except
    raise;
  end;
end;

 function TSymTab.MakeName(name:PChar; AType: TExprType):PSymboll;
 begin
   result:=MakeSym(name, stName);
   GetMem(result^.value, SizeOf(TNode));
   result^.value^.ntype := AType;
 end;

function TSymTab.HashCompName(name1,name2:pchar):integer;
begin
  result:=0;
  while name1^<>#0 do begin
    result:= (result shl 2) xor ord(name1^);
    inc(name1);
  end;
  while name2^<>#0 do begin
    result:= (result shl 2) xor ord(name2^);
    inc(name2);
  end;
  result:=result mod FTabSize;
end;


function TSymTab.hash(name:PChar):integer;
begin
  result:= 0;
  while name^ <> #0 do begin
    result:= (result shl 2) xor (ord(name^));
    inc(name);
  end;
  if result <0 then result:= -result;
  result:= result mod FTabSize;
end;

 procedure TSymTab.Clear;
 begin
  DeleteNames;
 end;

procedure TSymTab.RemoveAllNames;
var
  i:integer;
  next,cur,prev:PSymboll;
begin
  for i:= 0 to FTabSize-1 do begin
    cur:=FSymTab^[i];
    prev:=nil;
    while cur <> nil do begin
      next:= cur^.next;
      if cur^.stype = stName then begin
        if prev <> nil then prev^.next:= next
        else FSymTab^[i]:= next;
        FreeSym(cur);
      end
      else prev:= cur;
      cur:= next;
    end;
  end;
end;

procedure TSymTab.DeleteNames;
var
  i:integer;
  next,cur,prev:PSymboll;
begin
  for i:= 0 to FTabSize-1 do begin
    cur:=FSymTab^[i];
    prev:=nil;
    while cur <> nil do begin
      next:= cur^.next;
      if (cur^.stype = stName)or(cur^.stype=stUsDef) then begin
        if prev <> nil then prev^.next:= next
        else FSymTab^[i]:= next;
        FreeSym(cur);
      end
      else prev:= cur;
      cur:= next;
    end;
  end;
end;



procedure TSymTab.Report(Strings:TStrings);
var
  i:integer;
  sym:PSymboll;
  str:string;
  j,k,n, t:integer;
  p:pointer;
begin
  for i:= 0 to FTabSize-1 do begin
    sym:= SymTab^[i];
    while sym <> nil do begin
      if sym^.stype = stName then begin
        if sym^.name <> nil then
          Str:= StrPas(sym^.name);
        if sym^.value <> nil then begin
          str:= str+ ': ';
          with sym^ do begin
            case value^.ntype of
              etInt: str:= str+  IntToStr(value^.ival);
              etFloat: str:= str+ FloatToStr(value^.fval);
              etBool: if value^.bval <> 0 then str:= str + ' True'
                      else str:= str+ 'False';
              etVector:
                begin
                  n:= value^.vsize;
                  p:= value^.vdata;
                  case value^.vtype of
                    ttInt: begin k:= SizeOf(longint); t:= 1; end;
                    ttReal: begin k:= SizeOf(double); t:= 2; end;
                    ttBool: begin k:= SizeOf(integer); t:= 3; end;
                  end;
                  for j:=1 to n do begin
                    case t of
                      1:str:= str+ IntToStr(plongint(p)^);
                      2:str:= str+ FloatToStr(pdouble(p)^);
                      3:if pinteger(p)^ <> 0 then str:= 'True'
                       else str:= 'False';
                    end;
                    str:= str + ',';
                    if j = 0 then p:= value^.vdata + k
                    else p:= value^.vdata + k * j;
                  end;
                end;
              etString:
                str:=str+StrPas(value^.StrRec^.str);
              etChar:
                if value^.cval=#0 then  str:= str+ '#0'
                else str:= str+ value^.cval;
            end;
          end;
        end;
        Strings.Add(str);
      end;
      sym:= sym^.next;
    end;
  end;
end;

var
  MainTab:TSymTab;
  CurTab:TSymTab;


 procedure SetSymTab(SymTab:TSymTab);
 begin
   CurTab:= SymTab;
 end;

 function GetSymTab:TSymTab;
 begin
   result:= CurTab;
 end;

{lexical scanner}
 var
   Buffer:PChar;
   BufPtr:PChar;
   BufSize:longint;
   TokenPtr:PChar;
   TokenEnd:PChar;
   TokenValue:TTokenType;
   TokenString:array[0..255]of char;
   Ident:PSymboll;
   LitType:integer;
   {CurToken: TSemRec;}
   LenString:integer;
   isFunc:boolean;
   CurFunc:PUsDef;


   Tokens:array[1..256] of TTokenType;


procedure SetBuffer(Buf:Pchar; Size:longint);
begin
  Buffer:= Buf;
  BufPtr:= Buffer;
  TokenPtr:= BufPtr;
  TokenEnd:= TokenPtr;
  BufSize:= Size;
  CountLines:=0;
  CountChars:=0;
end;

 procedure Skip;
 begin
    while (BufPtr^ <>#00) do begin
      if BufPtr^ = '/' then begin
        BufPtr:= BufPtr+1;
        if BufPtr^ = '*' then begin
          BufPtr:= BufPtr+1;
          while (BufPtr^ <> #00) do begin
            if BufPtr^ = '*' then begin
              inc(BufPtr, SizeOf(Char));
              if BufPtr^ = '/' then break;
            end;
            inc(BufPtr, SizeOf(char));
            continue;
          end;
          if BufPtr^ = #0 then
            raise Exception.Create('undefined end of file');
          inc(BufPtr, SizeOf(char));
        end
        else if BufPtr^ = '/' then begin
          while (BufPtr^ <> #00) do begin
            if BufPtr^ = #10 then  break;
            inc(BufPtr, SizeOf(char));
          end;
          if BufPtr^ = #10 then inc(BufPtr, SizeOf(Char));
          continue;
        end
        else dec(BufPtr);
      end;
      if (BufPtr^ = #00) or (BufPtr^ >= #33) then break;
      inc(BufPtr);
    end;
 end;


  function FindName(name:PChar):PSymboll;
  begin
   {искать символ в главной таблице}
    result:= MainTab.FindSym(name);
    {если не найден и если внутри функции}
    if (result = nil) and isFunc then begin
     {искать в списке параметров функции}
      result:= CurFunc^.Locals;
      while result<>nil do begin
        if StrIComp(result^.name, name)=0 then break;
        result:= result^.next;
      end;
    end;
    {иначе искать в текущей таблице}
    if result = nil then result:= CurTab.FindSym(name);
  end;

procedure NextToken;
var
  i:word;
  f:boolean;
  s:PSymboll;
begin
    TokenValue:=ttEnd;
    f:= false;
    Skip;
    if BufPtr^ = #00 then
      begin  TokenValue:= ttEof;  exit; end;
    TokenPtr:= BufPtr;
    case BufPtr^ of
      'a'..'z','A'..'Z','_':
        begin
           while BufPtr^ in ['0'..'9', 'a'..'z','A'..'Z','_'] do
             inc(BufPtr);
           f:=true;
        end;
      '0'..'9': begin
        while BufPtr^ in ['0'..'9'] do inc(BufPtr);
        LitType:= ltInt;
        if BufPtr^ in ['.', 'e', 'E'] then begin
          LitType:= ltFloat;
          if BufPtr^ = '.' then begin
            inc(BufPtr);
            while BufPtr^ in ['0'..'9'] do  inc(BufPtr);
          end;
          if UpCase(BufPtr^) = 'E' then begin
            inc(BufPtr);
            if BufPtr^ in ['+','-'] then  inc(BufPtr);
            while BufPtr^ in ['0'..'9'] do inc(BufPtr);
          end;
        end;
        TokenValue:= ttLiteral;
      end;
      else begin
        TokenValue:= Tokens[ord(bufPtr^)];

                 case BufPtr^ of
            '*':
              begin
               inc(BufPtr);
               if BufPtr^ = '*' then
                 begin TokenValue:= ttPow; inc(BufPtr); end;
              end;
            '|':
               begin
               inc(BufPtr);
               if BufPtr^ = '|' then
                 begin TokenValue:= ttLor; inc(bufPtr); end;
              end;
            '&':
                begin
               inc(BufPtr);
               if BufPtr^ = '&' then
                 begin TokenValue:= ttLAnd; inc(BufPtr); end;
              end;
            '^':
              begin
               inc(BufPtr);
               if BufPtr^ = '^' then
                 begin TokenValue:= ttLxor; inc(bufPtr); end;
              end;
            '<':
               begin
               inc(BufPtr);
               if BufPtr^ in ['<', '=', '>'] then begin
                 case BufPtr^ of
                   '<': TokenValue:= ttShr;
                   '=': TokenValue:= ttLe;
                   '>': TokenValue:= ttNe;
                 end;
                inc(BufPtr);
              end;
              end;
            '>':
              begin
               inc(BufPtr);
               if BufPtr^ in ['>', '=', '<'] then begin
                 case BufPtr^ of
                   '>': TokenValue:= ttShl;
                   '=': TokenValue:= ttGe;
                   '<': TokenValue:= ttNe;
                 end;
                 inc(BufPtr);
              end;
              end;
            '!':
              begin
                inc(BufPtr);
                if BufPtr^ = '=' then
                  begin TokenValue:= ttNe; inc(BufPtr);end;
              end;
            '=':
              begin
                inc(BufPtr);
                if BufPtr^ = '>'then
                  begin TokenValue:= ttGe; inc(bufPtr); end;
              end;
            ':':
              begin
                inc(BufPtr);
                if BufPtr^ = '=' then
                  begin TokenValue:= ttAssign;inc(bufPtr);end;
              end;
            '+':
              begin
                inc(BufPtr);
                if BufPtr^='+' then
                  begin TokenValue:= ttInc;inc(bufPtr);end;
              end;
            '-':
              begin
                inc(BufPtr);
                if BufPtr^='-' then
                  begin TokenValue:= ttDec; inc(BufPtr); end;
              end;
            '"':
              begin
                inc(BufPtr);
                while (BufPtr^<>#0)and(BufPtr^<>#13)do begin
                  if BufPtr^='"'then break;
                  inc(BufPtr);
                end;
                if BufPtr^<>'"' then
                  raise ESyntaxError.Create('неоконченная строка');
                inc(BufPtr);
              end;
            '''':
              begin
                TokenValue:= ttQuote;
                inc(BufPtr);
                TokenPtr:= BufPtr;
                if BufPtr^ <> '''' then inc(BufPtr);
                if BufPtr^<>'''' then
                  raise ESyntaxError.Create('требуется '' ');
                inc(BufPtr);
              end;
            else inc(BufPtr);
          end;
          if TokenValue = ttEof then
            raise ESyntaxError.Create('недопустимый символ');
           if TokenValue in [ttAdd..ttNot] then begin
             if BufPtr^ = '=' then begin
               inc(BufPtr);
               TokenValue:= TTokenType(ord(TokenValue)+ord(ttAddAss)-ord(ttAdd));
             end;
           end;
      end;
    end;
    TokenEnd:= BufPtr;
    i:= TokenEnd - TokenPtr;
    if TokenValue=ttBQuote then begin
       TokenPtr:=TokenPtr+1;
       dec(i,2);
       LenString:=i;
    end;
    if TokenValue=ttQuote then dec(i);
    StrLCopy(TokenString, TokenPtr, i);
    TokenString[i]:= #0;
    if f then begin
      StrUpper(TokenString);
      s:=FindName(TokenString);
      if (s<>nil) and (s^.stype = stKey) then begin
        TokenValue:= s^.val;
      end
      else begin
        TokenValue:= ttName;
        Ident:= s;
      end;
    end;
  end;

  const
    SECount = 14;
    SyntaxErrors : array[1..SECount] of string = (
     'неверный тип',
     'ошибка в выражении',
     'недопустимое присваивание',
     'переопределение имени',
     'неопределенное имя',
     'требуется идентификатор',
     'требуется оператор присваивания',
     'требуется левая скобка (',
     'требуется правая скобка )',
     'требуется %s',
     'требуется ]',
     'требуется ;',
     'требуется запятая',
     'мало аргументов'
     );

     SETypeError =  1;
     SEExprError =  2;
     SEInvAssig  =  3;
     SERedefName =  4;
     SEUndefName =  5;
     SEExpIdent  =  6;
     SEExpAssig  =  7;
     SEExpRp     =  8;
     SEExpLp     =  9;
     SEExpLB     = 10;
     SEExpRB     = 11;
     SEExpSemi   = 12;
     SEExpComma  = 13;
     SEArgFew    = 14;


    constructor ESyntaxError.CreateFmt(Msg:string; Fmt:array of const);
    begin
      FPos:= Bufptr-Buffer;
      inherited CreateFmt(Msg, Fmt);
    end;

    constructor ESyntaxError.FCreate(Msg:integer);
    var
      str:string;
    begin
      FPos:= BufPtr-Buffer;
      str:= SyntaxErrors[Msg];
      if Msg = SEUndefName then
        str:=Str+StrPas(TokenString);
      inherited Create(str);
      {inherited Create(msg);}
    end;

    constructor ESyntaxError.Create(Msg:string);
    begin
      FPos:= BufPtr-Buffer;
      inherited Create(Msg);
    end;

{вычислить выражение}
var
  ctFalse, ctTrue:PNode;
  FResult:TNode; {результат функции}
  EvalStack:PNodeArray; {стек вычислений}
  EvalStackPtr:integer; {указател верхушки стека}
  EvalStackBase: integer;
  {указатель базы стека - используется для адресации параметров в функциях}


procedure push(Node:PNode);
begin
  if EvalStackPtr = EvalStackSize then
    raise Exception.Create('Stack Overflow');
  inc(EvalStackPtr);
  EvalStack^[EvalStackPtr]:= Node^;
end;

procedure arith(Left, Right: PNode; op:TTokenType);

function IPow(base, exp:longint):longint;
var
  i:integer;
begin
  result:=1;
  if exp = 0 then result:=1
  else if exp=1 then result:=base
  else for i:= 1 to exp do
      result:= result*base
end;

function FPower(x, y: double):double;
begin
  result:= Exp(Ln(x)*y);
end;

var
  float:boolean;
  dummy1, dummy2: double;
  int1, int2:longint;
begin
  Float:= false;
  if (Right^.ntype = etBool) or (Left^.ntype =etBool) then
    raise Exception.Create('type error');
  if (Right^.ntype=etFloat)or(Left^.ntype=etFloat)or(op=ttFDiv)then
  begin
    float:= true;
    case Left^.ntype of
      etFloat: dummy1:= Left^.fval;
      etInt:   dummy1:= Left^.ival
    end;
    case Right^.ntype of
      etFloat: dummy2:= Right^.fval;
      etInt:   dummy2:= Right^.ival;
    end;
  end
  else begin
    case  left^.ntype of
      etChar: int1:=ord(left^.cval);
      etInt:  int1:= left^.ival;
    end;
    case right^.ntype of
      etChar: int2:= ord(right^.cval);
      etInt:  int2:= right^.ival;
    end;
  end;

  if float then begin
    Left^.ntype:= etFloat;
    with Left^ do begin
      case op of
        ttPow: fval:=FPower(dummy1, dummy2);
        ttMul: fval:= dummy1 * dummy2;
        ttDiv,ttFDiv: if dummy2 = 0 then raise EZeroDivide.Create('')
               else fval:= dummy1 / dummy2;
        ttAdd: fval:= dummy1 + dummy2;
        ttSub: fval:= dummy1 - dummy2;
      end;
    end;
  end
  else begin
    with Left^ do begin
      case op of
        ttPow: int1:= IPow(int1, int2);
        ttMul: int1:= int1  *  int2;
        ttDiv: int1:= int1 div int2;
        ttMod: int1:= int1 mod int2;
        ttAnd: int1:= int1 and int2;
        ttShl: int1:= int1 shl int2;
        ttShr: int1:= int1 shr int2;
        ttAdd: int1:= int1  +  int2;
        ttSub: int1:= int1  -  int2;
        ttOr : int1:= int1 or  int2;
        ttXor: int1:= int1 xor int2;
      end;
      if Left^.ntype = etChar then
        Left^.cval:= chr(int1)
      else Left^.ival:= int1;
    end;
  end;
end;

procedure StArith(op:TTokenType);
var
  Left, Right:PNode;
begin
  Right:= @EvalStack^[EvalStackPtr];
  dec(EvalStackPtr);
  Left:= @EvalStack^[EvalStackPtr];
  arith(Left, Right, op);
end;

procedure Compare(left, right, result:PNode; op:TTokenType);
var
  dummy1, dummy2:double;
  int1, int2: longint;
  i:integer;
  f:boolean;
begin
  f:= false;
  if (Left^.ntype = etFloat) or (Right^.ntype = etFloat) then begin
    f:= true;
    case Left^.ntype of
     etFloat: dummy1:= Left^.fval;
     etInt:   dummy1:= Left^.ival;
    end;
    case Right^.ntype of
      etFloat: dummy2:= Right^.fval;
      etInt:   dummy2:= Right^.ival;
    end;
    dummy1:= dummy1 - dummy2;
  end
  else begin
    case Left^.ntype of
      etInt:  int1:= left^.ival;
      etChar: begin i:= ord(left^.cval); int1:=i; end;
      etBool: int1:= left^.bval;
    end;
    case Right^.ntype of
      etInt: int2:= right^.ival;
      etChar: int2:= ord(right^.cval);
      etBool: int2:= right^.bval;
    end;
    {int1:= int1 - int2;}
  end;
  result^.ntype:= etBool;
  with result^ do begin
    if not f then begin
      case op of
        ttLt: bval:= ord(int1 <  int2);
        ttLe: bval:= ord(int1 <= int2);
        ttEq: bval:= ord(int1 =  int2);
        ttNe: bval:= ord(int1 <> int2);
        ttGe: bval:= ord(int1 >= int2);
        ttGt: bval:= ord(int1 >  int2);
      end
    end
    else begin
      case op of
        ttLt: bval:= ord(dummy1 < 0);
        ttLe: bval:= ord(dummy1 <=0);
        ttEq: bval:= ord(dummy1 = 0);
        ttNe: bval:= ord(dummy1 <>0);
        ttGe: bval:= ord(dummy1 >=0);
        ttGt: bval:= ord(dummy1 > 0);
      end;
    end;
  end;
end;

procedure unary(op:TTokenType);
begin
  if op = ttAdd then op:= ttSub;
  with EvalStack^[EvalStackPtr] do begin
    case op of
      ttNot:
        begin
          case ntype of
            etBool: bval:= not bval;
            etInt: ival:= not ival;
            else
              raise ESyntaxError.FCreate(SETypeError);
          end;
        end;
      ttSub:
        begin
          case ntype of
            etInt: ival:= -ival;
            etFloat: fval:= -fval;
            else
              raise ESyntaxError.FCreate(SETypeError);
          end;
        end;
      ttLNot:
        begin
          if ntype <> etBool then
            raise ESyntaxError.FCreate(SETypeError);
          if bval <> 0 then bval:= 0 else bval:=1;
        end;
     end;
  end;
end;


procedure logic(op:TTokenType);
var
  l, r: integer;
begin
{  with EvalStack^[EvalStackPtr] do begin
    if ntype <> etBool then begin
      case ntype of
        etInt : if ival <> 0 then r := 1 else r:= 0;
        etFloat: if fval <> 0 then r:= 1 else r:= 0;
      end;
    end
    else r:= bval;
  end;
  dec(EvalStackPtr);
  with EvalStack^[EvalStackPtr] do begin
    if ntype <> etBool then begin
      case ntype of
        etInt : if ival <> 0 then l:= 1 else l:=0;
        etFloat: if fval <> 0 then l:=1 else l:=0;
      end;
    end
    else l:= bval;
  end;}
  r:= EvalStack^[EvalStackPtr].bval;
  dec(EvalStackPtr);
  l:= EvalStack^[EvalStackPtr].bval;
  with EvalStack^[EvalStackPtr] do begin
    case op of
      ttLAnd:
        if (l <> 0) and (r <> 0) then bval:= 1 else bval:= 0;
      ttLOr:
        if (l <> 0 ) or (r <> 0) then bval:= 1 else bval:=0;
      ttLXor:
        if (l <> 0) xor (r <> 0) then bval:= 1 else bval:= 0;
    end;
  end;
  end;



type
  TFuncRec = record
    Addr:PChar;
    StackPtr:integer;
    OldBase:integer;
    OldFunc:PUsDef;
  end;

const
  FuncStackSize = 100;
  var
    FuncStackPtr:integer;
    FuncStack:array[0..FuncStackSize-1] of TFuncRec;



{разбор выражения}
procedure level1;forward;

{вызывать встроенную фукнцию}
procedure CallFunc;
var
  func:PFunc;
  i:integer;
  proc: TProc;
begin
  func:= Ident^.func;
  i:= func^.Count;
  NextToken;
  if func^.Ftype = ftProc then
    raise ESyntaxError.FCreate(SEExprError);
  if i > 0 then begin
    if TokenValue <> ttLp then
      raise ESyntaxError.FCreate(SEExpLp);
    NextToken;
    while i > 0 do begin
      Level1;
      if (TokenValue <> ttComma) and (TokenValue <> ttRp) then
        raise ESyntaxError.FCreate(SEExpComma);
      NextToken;
      dec(i);
    end;
  end;
  proc:= TProc(func^.addr);
  proc;
end;

var count:integer;
procedure StmtList;forward;

{вызвать функцию, определенную через defun}
procedure CallUser;
var
  func:PUsDef;
  i,l:integer;
  sym:PSymboll;
  v:boolean;
begin
  inc(count);
  func:= Ident^.usdef;
  sym:=func^.Locals;
  i:= func^.ArgCount;
  l:=1;
  NextToken;
  if TokenValue <> ttLp then
    raise ESyntaxError.FCreate(SEExpLp);
  NextToken;
  v:=false;
  if i > 0 then begin
    while i > 0 do begin
      if sym^.stype= stName then begin
        if (TokenValue<>ttName)or(ident=nil)or(ident^.stype<>stName) then
          raise ESyntaxError.Create('переменная требуется');
        sym^.value:=ident^.value;
        v:=true;
        NextToken;
      end
      else
      Level1;
      sym:= sym^.next;
      dec(i);
      inc(l);
      {после разбора выражения всегда указывает на
      следующую лексему - это должна быть запятая или
      правая скобка, если это не запятая -
      то это может быть скобка}
      if TokenValue <> ttComma then break;
      NextToken;
    end;
    if i > 0 then raise ESyntaxError.FCreate(SEArgFew);
  end;
  if TokenValue<>ttRP then
    raise ESyntaxError.FCreate(SEExpRp);

  i:=Func^.VarCount;
  while i>0 do begin
    inc(EvalStackPtr);
    with EvalStack^[EvalStackPtr]do
    case  sym^.ltype of
      ttInt: ntype:=etInt;
      ttReal: ntype:= etFloat;
      ttBool: ntype:= etBool;
      ttChar: ntype:= etChar;
    end;
    dec(i);
    Sym:=Sym^.next;
  end;

  inc(FuncStackPtr);
  if FuncStackPtr = FuncStackSize then
    raise Exception.Create('переполнение стека');
  if EvalStackBase = 0 then EvalStackBase:= EvalStackPtr;
  FuncStack[FuncStackPtr].addr:= BufPtr;
  FuncStack[FuncStackPtr].StackPtr:= EvalStackPtr;
  FuncStack[FuncStackptr].OldBase:= EvalStackBase;
  EvalStackBase:= EvalStackPtr;
  BufPtr:= func^.Addr;
  isFunc:= True;
  FuncStack[FuncStackPtr].OldFunc:=CurFunc;
  CurFunc:= func;

  StmtList;


  {выход из фунции}
  BufPtr:= FuncStack[FuncStackPtr].addr;
  EvalStackPtr:= FuncStack[FuncStackPtr].StackPtr;
  EvalStackBase:= FuncStack[FuncStackPtr].OldBase;
  CurFunc:=FuncStack[FuncStackPtr].OldFunc;
  dec(FuncStackPtr);
  if FuncStackPtr=0 then isFunc:=false;
  dec(EvalStackPtr,Func^.VarCount);
  dec(EvalStackPtr,l-1);
  if Func^.ftype<>ttVoid then begin
    inc(EvalStackPtr);
    EvalStack^[EvalStackPtr]:=FResult;
  end;
  NextToken;

  if v then begin
    sym:=func^.locals;
    for i:=1 to func^.ArgCount do begin
      if sym^.stype = stName then
        sym^.value:= nil;
      sym:=sym^.next;
    end;
  end;
end;


{получить число - поместить на вершину стека}
procedure GetNumber;
var
  f:boolean;
  i:integer;
begin
  if LitType = ltFloat then f:= true else f:= false;
  if EvalStackPtr = EvalStackSize then
    Exception.Create('Stack overflow');
  inc(EvalStackPtr);
  with EvalStack^[EvalStackPtr] do begin
    if f then begin ntype:= etFloat; val(TokenString, fval, i); end
    else begin ntype:= etInt;   val(TokenString, ival, i);  end;
  end;
end;


const
  ExprType :array[ttInt..ttChar] of TExprType =(
   etInt, etFloat, etBool, etChar);


{получить индекс в многомерном массиве}
function GetIndex(node:PNode):integer;
var
  kolvo,i:integer;
  size, index:integer;
  Arr:PArray;
begin
  kolvo:= node^.Arr^.DimCount;
  size:=node^.arr^.ElemSize;
  Arr:=node^.Arr;
  if tokenValue<>ttLBracket then
    raise ESyntaxError.Create('[');
  result:=0;
  while kolvo>0 do begin
    NextToken;
    Level1;
    with EvalStack^[EvalStackPtr] do begin
      if ntype= etInt then index:=ival
      else if ntype = etChar then index:=ord(cval)
      else raise ESyntaxError.Create('ошибка типа');
    end;
    dec(EvalStackPtr);
    dec(kolvo);
    if kolvo > 0 then
      for i:= kolvo downto 1 do
        index:=index*Arr^.Bounds[i];
    result:=result+index;
    if TokenValue<>ttComma then break;
  end;
  result:=result*size;
end;


{присвоить значение узла по указателю на тип atype с проверкой}
 procedure AssigToPointer(p:pointer; atype:TExprType; node:PNode);
 var
   ftemp:double;
   itemp:integer;
   ctemp:char;
 begin
   with node^ do begin
     case atype of
      etInt:
        if ntype = etInt then plongint(p)^:=ival
        else if ntype = etBool then plongint(p)^:=bval
        else if ntype = etChar then plongint(p)^:= ord(cval)
        else raise ESyntaxError.Create('');
      etFloat:
        if ntype = etInt then
          begin ftemp:= ival; pdouble(p)^:=ftemp; end
        else if ntype = etFloat then pdouble(p)^:= fval
        else raise ESyntaxError.Create('');
      etChar:
        if ntype = etInt then
          begin ctemp:=chr(ival); pchar(p)^:=ctemp; end
        else if ntype = etChar then pchar(p)^:=cval
        else raise ESyntaxError.Create('');
      etBool:
        if ntype = etBool then pinteger(p)^:=bval
        else if ntype = etInt then
          begin  itemp:=ival; pinteger(p)^:=itemp; end;
        else raise ESyntaxError.Create('');
    end;
   end;
 end;

{присвоить один узел другому с проверкой типа}
procedure AssigNode(Dst, Src:PNode);
begin
  with Src^ do begin
    case Dst^.ntype of
      etFloat:
        if ntype = etFloat then Dst^.fval:= fval
        else if ntype = etInt then Dst^.fval:= ival
        else raise ESyntaxError.Create('type error');
      etInt:
        if ntype = etInt then Dst^.ival:= ival
        else if ntype = etChar then Dst^.ival:= ord(cval)
        else if ntype = etBool then Dst^.ival:= bval
        else raise ESyntaxError.Create('type error');
      etBool:
        if ntype = etBool then Dst^.bval:= bval
        else if ntype = etInt then Dst^.bval:=ival
        else raise ESyntaxError.Create('type error');
      etChar:
        if ntype=etChar then Dst^.cval:=cval
        else if ntype = etInt then Dst^.cval:= chr(ival)
        else raise ESyntaxError.Create('type error');
    end;
  end;
end;

procedure DeletesStrRec(StrRec:PStrRec);
begin
    dec(StrRec^.refCount);
    if StrRec^.RefCount > 0 then exit;
    StrDispose(StrRec^.Str);
    FreeMem(StrRec, sizeof(TStrRec));
end;


{рекурсивный спуск}
{первичные выражения}
procedure Level9;
type
  IntArray = array[0..32000]of integer;
  PIntArray = ^IntArray;
var
  node:PNode;
  index:integer;
  p:pointer;
  tem:pchar;
begin
  case TokenValue of
    ttName:
      begin
        if Ident=nil then
          raise ESyntaxError.FCreate(SEUndefName);
        if ident^.stype = stUsdef then begin
          if ident^.usdef^.ftype = ttVoid then
            raise ESyntaxError.Create('ошибка в выражении')
          else  CallUser
        end
        else if ident^.stype = stFunc then CallFunc
        else if ident^.stype = stLocal then begin
          push(@EvalStack^[EvalStackBase-ident^.offs]);
          NextToken;
        end
        else begin
          node:= ident^.value;
          NextToken;
          if node^.ntype = etVector then begin
            if TokenValue = ttLBracket then begin
              NextToken;
              Level1;
              if TokenValue <> ttRBracket then
                raise ESyntaxError.Create(']');
              NextToken;
              with EvalStack^[EvalStackPtr] do
                if ntype = etInt then index:=ival
                else if ntype = etChar then index:=ord(cval)
                else raise ESyntaxError.Create('неверный тип индекса');
              if (index <0)  or (index > node^.vsize-1) then
                raise Exception.Create('range error');
              if node^.vdata = nil then
                raise  Exception.Create('internal Error');
           {умножить на размер типа элемента}
              index:=index*Sizes[node^.vtype];
            {адрес элемента}
              p:=node^.vdata+index;
              with EvalStack^[EvalStackPtr] do begin
                ntype:= ExprType[node^.vtype];
                case node^.vtype of
                  ttInt : ival:= plongint(p)^;
                  ttReal: fval:= pdouble(p)^;
                  ttBool: bval:= pinteger(p)^;
                  ttChar: cval:=pchar(p)^;
                end;
              end;
            end; {ttLBracket}
          end
           else if node^.ntype = etArray then begin
             index:=GetIndex(ident^.value);
             inc(EvalStackPtr);
             with EvalStack^[EvalStackPtr] do begin
               ntype:= ExprType[node^.Arr^.ElemType];
               tem:= Node^.Arr^.Data;
               tem:=tem+index;
               case ntype of
                 etInt: ival:=plongint(tem)^;
                 etFloat: fval:= pdouble(tem)^;
                 etBool: bval:= pinteger(tem)^;
                 etChar: cval:= tem^;
               end;
             end;
             NextToken;
           end
           else if node^.ntype = etMatrix then begin
             if TokenValue = ttLBracket then begin
               NextToken;
               Level1;
               index:=EvalStack^[EvalStackPtr].ival;
               dec(EvalStackPtr);
               if TokenValue<>ttRBracket then
                 raise ESyntaxError.Create('требуется ]');
               NextToken;
               if TokenValue<>ttLBracket then
                 raise ESyntaxError.Create('требуется [');
               NextToken;
               Level1;
               if TokenValue<>ttRBracket then
                 raise ESyntaxError.Create('требуется ]');
               NextToken;
               index:=index*node^.size2;
               index:=index+EvalStack^[EvalStackPtr].ival;
               index:=index*Sizes[node^.mtype];
               with EvalStack^[EvalStackPtr] do begin
                 ntype:=ExprType[node^.mtype];
                 p:=node^.mdata+index;
                 case ntype of
                   etInt : ival:= plongint(p)^;
                   etFloat: fval:= pdouble(p)^;
                   etBool: bval:= pinteger(p)^;
                   etChar: cval:= pchar(p)^;
                 end;
               end;
             end;

           end
           else if node^.ntype = etString then begin
             if TokenValue = ttLBracket then begin
               if node^.StrRec^.Str = nil then
                 raise EInvalidPointer.Create('internal error');
               NextToken;
               Level1;
               if TokenValue <> ttRBracket then
                 raise ESyntaxError.Create(']');
               NextToken;

               if EvalStack^[EvalStackPtr].ntype <> etInt then
                 raise ESyntaxError.Create('неверный тип индекса');
               index:= EvalStack^[EvalStackPtr].ival;
               if (index <0)  or (index > node^.StrRec^.AllocSize-1) then
                 raise ESyntaxError.Create('range error');
               index:= index*sizeof(char);

               with EvalStack^[EvalStackPtr] do begin
                 ntype:=etChar;
                 tem:= node^.StrRec^.Str;
                 inc(tem, index);
                 cval:= tem^;
               end;
             end
             else begin
               Push(ident^.value);
             end;
           end
           else Push(node);
        end;
      end;
    ttLiteral: begin GetNumber; NextToken; end;
    ttTrue: begin Push(ctTrue); NextToken; end;
    ttFalse: begin Push(ctFalse); NextToken; end;
    ttQuote:
      begin
        inc(EvalStackPtr);
        EvalStack^[EvalStackPtr].ntype:= etChar;
        EvalStack^[EvalStackPtr].cval:= TokenString[0];
        NextToken;
      end;
    ttBQuote:
      begin
        inc(EvalStackPtr);
        with EvalStack^[EvalStackPtr] do begin
          ntype:= etString;
          StrRec:=NewTempString(TokenString,LenString);
        end;
        NextToken;
      end;
    ttLp:
      begin
        NextToken;
        Level1;
        if TokenValue <> ttRp then
          raise ESyntaxError.Create(' требуется правая скобка ) ');
        NextToken;
      end;
    else
      raise ESyntaxError.Create('ошибка в выражении');
  end;
end;

{унарные}
procedure Level8;
var
  op:TTokenType;
  node:PNode;
  sym:PSymboll;

  {эти действия приходится выполнять в двух местах}
  {чтобы не дублировать код - отдельная процедура}
procedure transcrement;
begin
{проверки}
 if sym=nil then
    raise ESyntaxError.Create('неизвестное имя'+StrPas(TokenString));
  if (sym^.stype <> stName)and(sym^.stype<>stLocal) then
     raise ESyntaxError.Create('требуется переменная ');
  if sym^.stype=stLocal then
     node:= @EvalStack^[EvalStackBase-sym^.offs]
  else node:= sym^.value;
  if (node^.ntype = etVector)or(node^.ntype=etString) then
    raise ESyntaxError.FCreate(SEExprError);

{уменьешение/увеличиение на 1 }
  with node^ do begin
    case op of
      ttInc:
        begin
          case ntype of
            etInt: inc(ival);
            etFloat: fval:= fval+ 1.0;
            etBool: inc(bval);
            etChar: inc(cval);
          end;{case}
        end;{begin}
      ttDec:
         begin
           case Node^.ntype of
             etInt: dec(node^.ival);
             etFloat: fval:= fval-1.0;
             etBool: dec(bval);
             etChar: dec(cval);
           end;{case}
         end;{begin}
    end;{case op}
  end;{with node}
end;

begin
  op:= ttEof;
  {сохранить текущий символ - понадобится потом для постфиксной формы}
  if TokenValue = ttName then Sym:=ident else sym:=nil;
  {если лексема - префиксная унараня операция}
  if TokenValue in [ttSub, ttAdd, ttNot, ttInc, ttDec] then begin
   {сохранить значение операции, получить операнд, назначить символ}
    op:=TokenValue;
    NextToken;
    sym:=ident;
    {если операция - префиксный инк-дек}
    {инк-декнуть, втолкнуть новое значение на стек, след лексема}
    if op in [ttInc, ttDec] then
      begin transcrement; Push(node); NextToken; end
     {иначе получить операнд и выполнить унарную операцию}
    else begin  Level9;  unary(op); end;
  end
  else Level9;
  {если встречен посфиксный инкдек}
  if TokenValue in [ttInc, ttDec] then begin
    op:=TokenValue;
    sym:=ident;
    transcrement;
    NextToken;
  end;
end;

{степень}
procedure Level7;
var
  op:TTokenType;
begin
  Level8;
  if TokenValue = ttPow then begin
    op:= TokenValue;
    NextToken;
    Level8;
    StArith(op);
  end;
end;

{мультипликативные выражения - включая сдвиги и побитовое И}
procedure Level6;
var
  op:TTokenType;
begin
  level7;
  while TokenValue in [ttMul..ttShr] do begin
    op:= TokenValue;
    NextToken;
    Level7;
    StArith(op);
  end;
end;

procedure ConcatStr;
var
  tem:PStrRec;
  i:integer;
begin
  tem:=EvalStack^[EvalStackPtr].StrRec;
  dec(EvalStackPtr);
  with EvalStack^[EvalStackPtr] do
    tem:= CatStr(StrRec, tem);
  for i:= 0 to 1 do
    with EvalStack^[EvalStackPtr+i] do
     if (StrRec<>nil) and (StrRec^.RefCount = 0) then
       ClrString(@EvalStack^[EvalStackPtr+i]);
  EvalStack^[EvalStackPtr].StrRec:=tem;
end;

{аддитивные операции - включая логические ИЛИ и исключающее ИЛИ}
procedure level5;
var
  op:TTokenType;
begin
  level6;
  while TokenValue in [ttAdd..ttXor] do begin
    op:=TokenValue;
    NextToken;
    Level6;
    with EvalStack^[EvalStackPtr] do
    if (ntype= etString) then
      if (op = ttAdd) then ConcatStr
      else raise ESyntaxError.Create('type error')
    else  StArith(op);
  end;
end;

{операции сравнения}
procedure Level4;
var
  op:TTokenType;
  left, right:PNode;
begin
  Level5;
  while TokenValue in [ttLt..ttGt] do begin
    op:= TokenValue;
    NextToken;
    Level5;
    right:=@EvalStack^[EvalStackPtr];
    dec(EvalStackPtr);
    left:= @EvalStack^[EvalStackPtr];
    Compare(left, right, left, op);
  end;
end;


{логическое НЕ}
procedure level3;
var
  t:boolean;
begin
  t:= false;
  if TokenValue = ttLNot then
    begin t:= true; NextToken; end;
    Level4;
    if t then unary(ttLNot);
end;

{логическое И}
procedure level2;
var
  op:TTokenType;
begin
  level3;
  while TokenValue = ttLAnd do begin
    op:= TokenValue;
    NextToken;
    Level3;
    logic(op);
  end;
end;

{логические ИЛИ и исключающее ИЛИ}
procedure level1;
var
  op:TTokenType;
begin
  level2;
  while TokenValue in [ttLOr, ttLXor] do begin
    op:= TokenValue;
    NextToken;
    Level2;
    logic(op);
  end;
end;




{интерпретатор}

procedure InitArray(p:pointer; atype:TTokenType; count:integer);
var
  len:integer;
  index:pchar;
begin
  len:=Sizes[atype];
  index:=p;
  if TokenValue<>ttLp then
    raise ESyntaxError.Create('требуется (');
  NextToken;
  while count > 0 do begin
      dec(count);
      if (TokenValue<>ttLiteral) then
        if (TokenValue<>ttTrue)and(TokenValue<>ttFalse) then
          raise ESyntaxError.Create('константа требуется');
      if (TokenValue in [ttFalse, ttTrue]) then begin
        if (atype = ttBool) then
          if TokenValue=ttFalse then pinteger(index)^:= 0
          else pinteger(index)^:=1
        else raise ESyntaxError.Create('error in type');
      end;
      if (TokenValue = ttLiteral)and(atype in [ttInt, ttReal]) then begin
        if atype = ttReal then
          pdouble(index)^:=StrToFloat(StrPas(TokenString))
        else if atype = ttInt then
          if LitType= ltInt then
            plongint(index)^:= StrToInt(StrPas(TokenString))
          else raise ESyntaxError.Create('error in type');
      end;

      index:=index+len;
      NextToken;
      if TokenValue<>ttComma then break;
      NextToken;
    end;
    if TokenValue<>ttrp then
      raise ESyntaxError.Create('Требуется )');
    NextToken;
    if count>0 then raise ESyntaxError.Create('Syntax Error');
end;

{определить вектор}
procedure DefVector(t:TTokenType);
var
  sym:PSymboll;
  size: integer;
  n:PNode;
  p:pchar;
begin
  NextToken;
  {должно быть имя вектора}
   if TokenValue <> ttName then
      raise ESyntaxError.Create('требуется имя');
   {создать запись в таблице символов}
   Sym:=CurTab.MakeSym(TokenString, stName);
   if ident<>nil then
      raise ESyntaxError.Create('переопределение имени'+StrPas(TokenString));
   GetMem(Sym^.value, SizeOf(TNode));
   Sym^.value^.ntype := etVector;
   Sym^.value^.vtype := t;
   Sym^.value^.vdata := nil;
   //размер вектора в [666]
   NextToken;
   if TokenValue <> ttLBracket  then
      raise ESyntaxError.Create(' требуется [ ');
   NextToken;
   //получить размер вектора
   Level1;
   if EvalStack^[EvalStackPtr].ntype <> etInt then
     raise ESyntaxError.Create('invalid type');
   Sym^.value^.vsize:= EvalStack^[EvalStackPtr].ival;
   dec(EvalStackPtr);
   if TokenValue <> ttRBracket then
       raise ESyntaxError.Create(']');
   NextToken;

   size:= sym^.value^.vsize;
   size:=size*Sizes[T];
   if size > 64000 then
     raise Exception.Create('overflow');
  GetMem(Sym^.value^.vdata, size);
  n:=Sym^.value;
  if TokenValue = ttAssign then begin
    NextToken;
    if TokenValue<>ttLp then
      raise ESyntaxError.Create('Требуется )');
    size:=n^.vsize;
    p:=n^.vdata;
    InitArray(p, T, size);
  end;
end;

procedure DefMatrix(mtype:TTokenType);
var
  sym:PSymboll;
  size1, size2:integer;
  i:integer;
  p:pchar;
begin
  NextToken;
  if TokenValue <>ttName then
    raise ESyntaxError.Create('требуется имя');
  if Ident<>nil then
    raise ESyntaxError.Create('переопределение имени'+StrPas(TokenString));
  sym:= CurTab.MakeSym(TokenString, stName);
  sym^.value:=nil;
  NextToken;
  if TokenValue<>ttLBracket then
    raise ESyntaxError.Create('требуется [');
  NextToken;
  if TokenValue<>ttLiteral then
    raise ESyntaxError.Create('требуется константа');
  if LitType<>ltInt then
    raise ESyntaxError.Create('ошибка типа');
  val(TokenString, size1,i);
  NextToken;
  if TokenValue<>ttRBracket then
    raise ESyntaxError.Create('требуется ]');
  NextToken;
  if TokenValue<>ttLBracket then
    raise ESyntaxError.Create('требуется [');
  NextToken;
  if TokenValue<>ttLiteral then
    raise ESyntaxError.Create('требуется константа');
  if LitType<>ltInt then
    raise ESyntaxError.Create('ошибка типа');
  val(TokenString, size2, i);
  NextToken;
  if TokenValue<>ttRBracket then
    raise ESyntaxError.Create('требуется ]');
  NextToken;
  GetMem(Sym^.value, sizeof(TNode));
  sym^.value^.ntype:=etMatrix;
  sym^.value^.size1:=size1;
  sym^.value^.size2:=size2;
  sym^.value^.mtype:=mtype;
  i:= size1*size2*Sizes[mtype];
  if i > 64000 then
    raise ESyntaxError.Create('ошибка диапазона');
  GetMem(sym^.value^.mdata, i);
  if TokenValue = ttAssign then begin
    NextToken;
    if TokenValue<>ttLp then
      raise ESyntaxError.Create('требуется (');
    NextToken;
    p:=sym^.value^.mdata;
    while size1>0 do begin
      InitArray(p, mtype, size2);
      dec(size1);
      p:=p+size2*Sizes[mtype];
      if TokenValue<>ttComma then break;
      NextToken;
    end;
    if size1>0 then raise ESyntaxError.Create('ошибка инициализации');
    if TokenValue<>ttRp then
      raise ESyntaxError.Create('требуется )');
    NextToken;
  end;
end;

procedure DefArray(t:TTokenType);
var
  sym:PSymboll;
  node:PNode;
  kolvo:integer;
  i, index:integer;
  size, MemCount:integer;
begin
  NextToken;
  if TokenValue<>ttName then
    raise ESyntaxError.Create('требуется имя');
  if ident<>nil then
    raise ESyntaxError.Create('переопределение имени'+StrPas(TokenString));
  try
    sym:= CurTab.MakeSym(TokenString, stName);
    NextToken;
    if TokenValue<>ttLBracket then
      raise ESyntaxError.Create('требуется [');
    NextToken;
    try
      GetMem(sym^.value, sizeof(TNode));
      node:=sym^.value;
      node^.ntype:= etArray;
      try
        GetMem(node^.Arr, sizeof(TArray));
        node^.Arr^.ElemType:=t;
        case t of
          ttInt: size:= sizeof(longint);
          ttReal: size:= sizeof(double);
          ttBool: size := sizeof(integer);
          ttChar: size:= sizeof(char);
        end;
        kolvo:=0;
        MemCount:=size;
        repeat
          if (TokenValue<>ttLiteral)and(LitType<>ltInt)then
            raise ESyntaxError.Create('ошибка в выражении');
          val(TokenString, index, i);
          node^.Arr^.Bounds[kolvo]:=index;
          MemCount:=MemCount*index;
          if MemCount > 64000 then
            raise ESyntaxError.Create('ошибка размерности');
          inc(kolvo);
          NextToken;
          if TokenValue<>ttComma then break;
          NextToken;
          if kolvo>25 then
            raise ESyntaxError.Create('ошибка размерности');
        until false;
        if TokenValue<>ttRBracket then
          raise ESyntaxError.Create('требуется ]');
        NextToken;
        node^.Arr^.Data:=nil;
        node^.arr^.ElemSize:=Size;
        node^.Arr^.Size:=MemCount;
        GetMem(Node^.Arr^.Data, MemCount);
        node^.Arr^.DimCount:=kolvo;
      except
        FreeMem(Node^.Arr, sizeof(TArray));
        raise;
      end;
    except
      FreeMem(Sym^.value, sizeof(TNode));
      raise;
    end;
  except
    CurTab.FreeSym(Sym);
    raise;
  end;
end;


{определить перменную}
procedure Defined;
var
  sym:PSymboll;
  t:TTokenType;
begin
  t:= TokenValue;
  repeat
    NextToken;
    if TokenValue = ttArray then begin DefArray(t); exit; end;
    if (TokenValue <> ttName) then //*********
      raise ESyntaxError.Create('имя требуется');
     sym:= CurTab.MakeSym(TokenString, stName);
    if sym = nil then
      raise ESyntaxError.Create('Redefined name  ' + strPas(TokenString));
    Getmem(sym^.value, sizeof(TNode));
    sym^.value^.ntype:= ExprType[t];
    NextToken;
    if TokenValue <> ttAssign then continue;

    NextToken;
    Level1;
    AssigNode(sym^.value, @EvalStack^[EvalStackPtr]);
    dec(EvalStackPtr);
  until TokenValue <> ttComma;
end;


//определить строку
procedure DefStr;
var
  sym:PSymboll;

  i, ival:integer;
begin
  NextToken;
  if TokenValue=ttVector then begin DefVector(ttString); exit; end;
  //должен быть идентификатор
  if TokenValue<>ttName then
    raise ESyntaxError.Create('требуется идентификатор');
  // неиспользованный
  if Ident<>nil then
    raise ESyntaxError.Create('переопределение имени '+StrPas(TokenString));
  //создать символ
  sym:=CurTab.MakeSym(TokenString, stName);
  GetMem(sym^.value, sizeof(TNode));
  sym^.value^.ntype:=etString;
  //следующая лексема
  NextToken;

  // string str[23];
  //если [], то определить размер выделяемой памяти
  if TokenValue = ttLbracket then begin
    // константа
    NextToken;
    val(TokenString, ival, i);
    NextToken;
    if TokenValue<>ttRbracket then
      raise EsyntaxError.Create('требуется ]');
    NextToken;
    //создать запись со строкой и распределенным блоком памяти
    //sym^.value := AllocStrNode(ival);
    sym^.value^.StrRec:= CreateStr(ival);
    exit;
  end;

  //string str :=
  if tokenValue=ttAssign then begin
    NextToken;
      //sring str:="new string";
    if TokenValue=ttBQuote then
      sym^.value^.StrRec:=InitStrFromPchar(TokenString, lenString)
       //string str:= source;
    else if TokenValue = ttName then begin
      if (ident=nil)or (ident^.stype<>stName)or
      (ident^.value^.ntype<>etString) then
        raise ESyntaxError.Create('требуется строка');
        InitStrFromStr(sym^.value, ident^.value^.StrRec);
    end
    else if TokenValue = ttNull then
      sym^.value^.StrRec:=nil
    else
      raise ESyntaxError.Create('требуется строка');
    NextToken;
  end
  else
    sym^.value^.StrRec:=nil;
end;

{преобразования}
procedure AIntToStr;
var
  result:string;
  p:pchar;
  len:integer;
begin
  with EvalStack^[EvalStackPtr] do begin
    if ntype<>etInt then exit;
    result:= IntToStr(ival);
    ntype:= etString;
    len:= length(result)+1;
    GetMem(p, len);
    try
      StrPCopy(p, result);
      StrRec:= NewTempString(p,len-1);
    finally
      FreeMem(p, len)
    end;
  end;
end;

procedure CopyVector(Dest, Source:pointer; DestSize:integer; vtype:TTokenType);
begin
  CopyMemory(Dest, Source, DestSize*Sizes[vtype]);
end;

procedure VectorToVector(Src, Dst:pointer; op:TTokenType);
begin

end;

{присвоить значение элементу вектора}
procedure AssignVector;
var
  index:integer;
  p:pointer;
  node:PNode;

  op:TTokenType;
begin
  node:= Ident^.value;
  NextToken;

 {если индексация}
  if TokenValue = ttLBracket then begin
  {пропустить [}
    NextToken;
    {получить значение выражения}
    Level1;
    {проверить тип выражения}
    with EvalStack^[EvalStackPtr] do
      if ntype = etInt then index:=ival
      else if ntype = etChar then index:=ord(cval)
      else raise ESyntaxError.Create('index type error');
    dec(EvalStackPtr);
    {должна быть ]}
    if TokenValue <> ttRBracket then
      raise ESyntaxError.Create(']');
    {пропустить ]}
    NextToken
  end{if TokenValue=ttLBracket}
  else if TokenValue in [ttAssign..ttPowAss] then begin
    op:=TokenValue;
    NextToken;
    if (TokenValue = ttName)then
      if ident = nil then
        raise ESyntaxError.Create('')
      else if ident^.stype<>stName then
        raise ESyntaxError.Create('')
      else if ident^.value^.ntype<>etVector then
        raise ESyntaxError.Create('');
    if node^.vtype<>ident^.value^.vtype then
      raise ESyntaxError.Create('');
    if op = ttAssign then
      CopyVector(node^.vdata,ident^.value^.vdata, node^.vsize, node^.vtype)
    else ;
    NextToken;
    exit;
  end;


    {проверить ранг индекса}
  if (index < 0) or (index > node^.vsize-1) then
     raise Exception.Create('range error');
  {должне быть оператор присваивания}
  if TokenValue <> ttAssign then
    raise ESyntaxError.Create(':=');
    {пропустить его}
  NextToken;
   {получить значение присваиваемого выражения}
  Level1;

  {вычислить адрес n-го элемента : }
  {база + index*sizeof(type_элемента массива ) }
  { p - результирующий указатель на элемент вектора}
  if index = 0 then p:= node^.vdata
  else begin
    index:=index*Sizes[node^.vtype];
    p:= node^.vdata + index;
  end;
   AssigToPointer(p, ExprType[node^.vtype], @EvalStack^[EvalStackPtr]);
  {присвоить значение выражения на вершине стека элементу массива}
  {испоьзуется приведение к типу нужного указателя и разыменование}
  {}
  dec(EvalStackPtr);
end;


procedure AFloatToStr;
var
  result:string;
  len:integer;
begin
  with EvalStack^[EvalStackPtr] do begin
    if ntype <> etFloat then exit;
    result:= FloatToStr(fval);
    len:= length(result);
    ntype:=etString;
    StrRec:=NewTempString(pchar(result),len);
  end;
end;

procedure ABoolToStr;
var
  result:pchar;
  len:integer;
begin
  with EvalStack^[EvalStackPtr] do begin
    if ntype<>etBool then exit;
    if bval<>0 then begin
      result:= 'Истина'{'True'};
      len:={4}6;
    end
    else begin
      result:= 'Ложь'{'False'};
      len:=4{5};
    end;
    ntype:= etString;
    StrRec:= NewTempString(result,len);
  end;
end;



procedure AssignStr;
var
  node:PNode;
  index:integer;
  P:pchar;
  StRec:PStrRec;
begin
  node:=ident^.value;
  StRec:= node^.StrRec;
  NextToken;

  {индекс - приваивание элементу строки}
  //s[20]:=
  if TokenValue = ttLBracket then begin
    NextToken;
    Level1;
    if EvalStack^[EvalStackPtr].ntype <> etInt then
      raise ESyntaxError.Create('index type error');
    index:= EvalStack^[EvalStackPtr].ival;
    dec(EvalStackPtr);
    if TokenValue <> ttRBracket then
      raise ESyntaxError.Create(']');
    NextToken;
    if (index < 0) or (index > StRec^.AllocSize-1) then
      raise Exception.Create('range error');
    if TokenValue <> ttAssign then
      raise ESyntaxError.Create(':=');
    NextToken;
    Level1;
    p:=StRec^.Str;
    p:=p+index;
    with EvalStack^[EvalStackPtr] do begin
      if ntype=etChar then  p^:=cval
      else if ntype = etInt then p^:= chr(ival)
      else raise ESyntaxError.Create('type error');
    end;
    dec(EvalStackptr);
    exit;
  end;{присваивание элементу строки}
  {присваивание строки}

  if TokenValue<>ttAssign then
    raise ESyntaxError.Create('оператор присваивания требуется');
  NextToken;
  if TokenValue = ttNull then begin
    ClrString(node);
    node^.StrRec:= nil;
    NextToken;
    exit;
  end;
  {получить строковое выражение}
  //inc(EvalStackPtr);
  //EvalStack^[EvalStackPtr].ntype:=etString;
 // EvalStack^[EvalStackPtr].StrRec:=GetStringExpr;

  Level1;

  if EvalStack^[EvalStackPtr].ntype<>etString then
    case EvalStack^[EvalStackPtr].ntype of
      etInt: AIntToStr;
      etBool: ABoolToStr;
      etFloat: AFloatToStr;
    end;

  ClrString(node);
  AssignStrToStr(node, @EvalStack^[EvalStackPtr]);
  dec(EvalStackptr);
end;

{присвоить значение элементу многомерного массива}
procedure AssignArray;
var
  sym:PSymboll;
  arr:PArray;
  index:integer;
  p:pointer;
  atype:TExprType;
begin
  sym:=ident;
  arr:=sym^.value^.Arr;
  NextToken;
  if TokenValue<>ttLBracket then
      raise ESyntaxError.Create('требуется [');
  index:=GetIndex(Sym^.value);
  p:=Arr^.Data+index;
  if TokenValue<>ttAssign then
    raise ESyntaxError.Create('требуется :=');
  NextToken;
  Level1;
  atype:=ExprType[Arr^.ElemType];
  AssigToPointer(p, atype, @EvalStack^[EvalStackPtr]);
  dec(EvalStackPtr);
end;


procedure AssignMatrix;
var
  node:PNode;
  index:integer;
begin
  node:= ident^.value;
  NextToken;
  if TokenValue<>ttLBracket then exit;
  NextToken;
  Level1;
  with EvalStack^[EvalStackPtr] do begin
    if (ntype=etInt) then index:= ival
    else if ntype = etChar then index:= ord(cval)
    else
      raise ESyntaxError.Create('type error');
    index:=index*node^.size2;
    if TokenValue<>ttRBracket then
      raise ESyntaxError.Create('требуется ]');
    NextToken;
    if TokenValue<> ttLBracket then
      raise ESyntaxError.Create('требуется [');
    NextToken;
  end;
  Level1;
  if TokenValue<>ttRBracket then
    raise ESyntaxError.Create('требуется ]');
  with EvalStack^[EvalStackPtr]do begin
    if (ntype=etInt) then index:= index+ival
    else if ntype = etChar then index:= index + ord(cval)
    else
      raise ESyntaxError.Create('type error');
    NextToken;
    index:=index*sizes[node^.mtype];
  end;
  if TokenValue<>ttAssign then
    raise ESyntaxError.Create('требуется оператор присваивания');
  NextToken;
  Level1;
  AssigToPointer(node^.mdata+index, ExprType[node^.mtype],@(EvalStack^[EvalStackPtr]));
end;


{присвоить значение переменной}
procedure AssignName;
var
  sym:PSymboll;
  node:PNode;
  op:TTokenType;
  offs:integer;
begin
  sym:= Ident;
  if sym = nil then
    raise ESyntaxError.Create('неопределенное имя '+ StrPas(TokenString)) ;
  if (sym^.stype <>stName)and(sym^.stype<>stLocal) then
     raise ESyntaxError.Create('недопустимое присваивание');
  if (sym^.stype<>stLocal)and(sym^.value = nil) then
    raise Exception.Create('internal error');

  if sym^.stype=stName then begin
    if sym^.value^.ntype = etVector then
      begin AssignVector; exit; end
    else if sym^.value^.ntype = etString then
      begin AssignStr; exit; end
    else if sym^.value^.ntype = etArray then
      begin AssignArray; exit;end
    else if sym^.value^.ntype = etMatrix then
      begin AssignMatrix; exit; end
  end;

  NextToken;
  if  not (TokenValue in [ttAssign..ttNotAss]) then
    raise ESyntaxError.Create('требуется оператор присваивания');
  op:= TokenValue;
  NextToken;
  Level1;
  if sym^.stype<>stLocal then  node:= sym^.value
  else begin
      {offs:=FuncStack[FuncStackPtr].StackPtr;}
      {offs:=offs-sym^.offs;}
      offs:=EvalStackBase - sym^.offs;
      node:= @EvalStack^[offs];
  end;
  if op <> ttAssign then begin
      Arith(node, @EvalStack^[EvalStackPtr], TTokenType(ord(op)-24));
      dec(EvalStackPtr);
      exit;
  end;

  AssigNode(node, @EvalStack^[EvalStackPtr]);
  Dec(EvalStackPtr);
end;


type
  PLoop = ^TLoop;
  TLoop = record
    beg:Pchar;
    ltype: byte;
    count:PNode;
    lim:longint;
    step: integer;
  end;
{структура для сохранения параметров цикла -
указатель на начало тела цикла,
тип цикла, для цикла for - количество счетчик,
конечное значение, величина шага каждой итерации}

  TLoopArray = array [0..2000] of TLoop;
  PLoopArray =^TLoopArray;
{стек для вложенных циклов}

{типы искпользуемых циклов и размер стека }
const
  ltRepeat = 1;
  ltWhile = 2;
  ltFor = 3;
  ltLoop = 4;
  LoopStackSize = 30;

var
  LoopStackPtr: integer;
  LoopStack: PLoopArray;

  {получить значение булевского выражения}
function GetBool:boolean;
begin
  Level1;
  result:= false;
  with EvalStack^[EvalStackPtr] do begin
    case ntype of
      etInt :   if ival <>0 then result:= true;
      etFloat:  if fval <>0 then result:=true;
      etChar:   if cval<>#0 then result:= true;
      etString: if StrRec^.Str<>nil then result:= true;
      etBool:   if bval <> 0 then result:= true;
    end;
  end;
  dec(EvalStackPtr);
end;

procedure ExDo;
begin
  if LoopStackPtr+1 > LoopStackSize then
    raise Exception.Create('Stack overflow');
  inc(LoopStackPtr);
  LoopStack^[LoopStackPtr].ltype:= ltLoop;
  LoopStack^[LoopStackPtr].beg:= BufPtr;
  tokenValue:= ttSemi;
end;

procedure Loop;
begin
  if (LoopStackPtr < 0)or (LoopStackPtr>LoopStackSize)
    then raise Exception.Create('internal error');
  if LoopStack^[LoopStackPtr].ltype<> ltLoop then
    raise ESyntaxError.Create('требуетя DO');
  bufptr:=LoopStack^[LoopStackPtr].beg;
end;

{цикл пока не...}
procedure StRepeat;
begin
  if LoopStackPtr = 25 then
    raise exception.Create('stack overflow');
  inc(LoopStackPtr);
  with LoopStack^[LoopStackPtr] do  begin
    beg:= BufPTr;
    ltype:= ltRepeat;
  end;
  TokenValue:= ttSemi;
end;


procedure StUntil;
begin
  if LoopStackPtr < 0 then
    raise exception.Create('stack underflow');
  NextToken;
  if not GetBool then
    BufPtr:= LoopStack^[LoopStackPtr].beg
  else  dec(LoopStackPtr);
end;

procedure SkipTo(token, etoken: TTokenType);
var
  level:integer;
begin
  level:=1;
  while TokenValue<>ttEof do begin
    if TokenValue=token then inc(level)
    else if TokenValue=etoken then dec(level);
    if level=0 then break;
    NextToken;
  end;
end;


{цикл пока...}
procedure ExWhile;
var
  temp:PChar;
begin
  temp:= BufPtr;
  NextToken;
  if GetBool then begin
    if LoopStackPtr = LoopStackSize then
      raise Exception.Create('stack nest overflow');
    inc(LoopStackPtr);
    LoopStack^[LoopStackPtr].beg:= temp;
    LoopStack^[LoopStackPtr].ltype:= ltWhile;
    TokenValue:=ttSemi;
  end
  else begin
    SkipTo(ttWhile, ttWend);
     if TokenValue<>ttWend then
       raise ESyntaxError.Create('Wend');
     NextToken;
  end;
end;

procedure ExWend;
var
  tem:pchar;
begin
  NextToken;
  tem:= BufPtr;
  BufPtr:= LoopStack^[LoopStackPtr].beg;
  NextToken;
  if not GetBool then
    begin BufPtr:= tem; dec(LoopStackPtr); end;
  TokenValue:= ttSemi;
end;

{it then}
procedure ExIf;
var
  t:boolean;
  lev:integer;
begin
  NextToken;
  t:= GetBool;
  if TokenValue <> ttThen then
   raise ESyntaxError.Create('Требуется then');
  if not t then begin
    lev:=1;
    while  TokenValue <> ttEof do begin
      case TokenValue of
        ttIf: inc(lev);
        ttEndif: dec(lev);
      end;
      if lev = 0 then break;
      if (TokenValue = ttElse) and (lev = 1) then break;
      NextToken;
    end;
    if (lev > 0) and (TokenValue<>ttElse )
      then raise ESyntaxError.Create('требуется endif');
  end;
  TokenValue:= ttSemi;
end;

{else}
procedure exElse;
begin
  SkipTo(ttIf,ttEndif);
  if TokenValue <> ttEndIf then
    raise ESyntaxError.Create('Требуется  '';''');
  NextToken;
end;


{for i:= 0 to lim step x }
{цикл for с шагом }
procedure ExecFor;
var
  counter: PNode;
  step:integer;
  lim:longint;
begin
  NextToken;
  if (TokenValue <> ttName) or (ident = nil)
     or (ident^.stype <> stName)and(ident^.stype<>stLocal) then
       raise ESyntaxError.Create('требуется идентефикатор');
  if ident^.stype=stLocal then
    counter:=@EvalStack^[EvalStackBase-ident^.offs]
  else  counter:= Ident^.value;
  if counter^.ntype <> etInt then
    raise ESyntaxError.Create('counter type error');
  NextToken;
  if TokenValue <> ttAssign then
      raise ESyntaxError.Create(':=');
  NextToken;
  Level1;
  if (EvalStack^[EvalStackPtr]. ntype <> etInt) then
      raise ESyntaxError.Create('');
  if TokenValue <> ttTo then
    raise ESyntaxError.Create('to');
  NextToken;
  Level1;
  if (EvalStack^[EvalStackPtr]. ntype <> etInt) then
      raise ESyntaxError.Create('');

    lim:= EvalStack^[EvalStackPtr].ival;
    dec(EvalStackPtr);

    if TokenValue = ttStep then begin
      NextToken;
      Level1;
      if EvalStack^[EvalStackPtr].ntype <> etInt then
        raise ESyntaxError.Create('invalid   type');
      step:= EvalStack^[EvalStackPtr].ival;
      dec(EvalStackPtr);
    end
    else step := 1;

    if step =0 then raise ESyntaxError.Create('invalid step value');
    if ((step < 0) and (lim > EvalStack^[EvalStackPtr].ival)) or
    ((step > 0) and (lim < EvalStack^[EvalStackPtr].ival)) then  begin
      EvalStackPtr:= EvalStackPtr - 1;
      SkipTo(ttFor, ttNext);
      if TokenValue<>ttNext then
        raise ESyntaxError.Create('Next');
      NextToken;
      exit;
    end;

    inc(LoopStackPtr);
    LoopStack^[LoopStackPtr].beg:= BufPtr;
    LoopStack^[LoopStackPtr].ltype:= ltFor;
    LoopStack^[LoopStackPtr].count:= counter;
    LoopStack^[LoopStackPtr].lim:= lim;
    LoopStack^[LoopStackPtr].step:= step;
    counter^.ival:= EvalStack^[EvalStackPtr].ival;
    dec(EvalStackPtr);
    TokenValue:= ttSemi;
end;



{следующая итерация цикла for - команда next}
procedure Next;
var
  n:PNode;
  step:integer;
  val:integer;
begin
  if LoopStack^[LoopStackPtr].ltype <> ltFor then
    raise ESyntaxError.Create('требуется for ');
  n:= LoopStack^[LoopStackPtr].count;
  step:= LoopStack^[LoopStackPtr].step;
  NextToken;
  val:= n^.ival;
  inc(val, step);
  if step > 0 then begin
    if val > LoopStack^[LoopStackPtr].lim then begin
      dec(LoopStackPtr);
      exit;
    end;
  end
  else begin
    inc(val, step);
    if val < LoopStack^[LoopStackPtr].lim then begin
      dec(LoopStackPtr);
      exit;
    end;
  end;
  n^.ival:=val;
  BufPtr:= LoopStack^[LoopStackPtr].beg;
end;

{выполнить выход из цикла}
procedure ExBreak;
var
  ltype : integer;
begin
  if LoopStackPtr < 0 then raise ESyntaxError.Create('not loop');
  ltype:= LoopStack^[LoopStackPtr].ltype;
  case ltype of
    ltRepeat:
      begin
        SkipTo(ttRepeat, ttUntil);
        if TokenValue<>ttUntil then
          raise ESyntaxError.Create('until not found');
        while (TokenValue <> ttEof) or(TokenValue<>ttSemi) do
          NextToken;
        if TokenValue<>ttSemi then
          raise ESyntaxError.Create('; expected');
      end;
    ltWhile:
      begin
        SkipTo(ttWhile, ttWend);
        if TokenValue<>ttWend then
          raise ESyntaxError.Create('wend not found');
        NextToken;
      end;
    ltFor:
      begin
        SkipTo(ttFor, ttNext);
        if TokenValue<>ttNext then
          raise ESyntaxError.Create('next not found');
        NextToken;
      end;
    ltLoop:
      begin
        SkipTo(ttDo, ttLoop);
      end;
  end;
  dec(LoopStackPtr);
end;

procedure ExCont;
var
  beg:PChar;
begin
  if LoopStackPtr < 0 then raise ESyntaxError.Create('not loop');
  beg:= LoopStack^[LoopStackPtr].beg;
  case LoopStackPtr of
    ltRepeat: BufPtr:=beg;
    ltFor:BufPtr:= beg;
    ltWhile: BufPtr:= beg;
  end;
  TokenValue:= ttSemi;
end;

{формальные параметры помещаются в список в обратном порядке,}
{так как величины их смещения не определены -  первый параметр}
{должен иметь самое большее смещение от вершины стека, а последний -}
{нулевое смещение}

{определение функции }
function MakeSymList(aType: TTokenType; name: PChar; head: PSymboll):PSymboll;
var
  prev, tem: PSymboll;
begin
  result:= nil;
  tem:= head;
  prev:=nil;
  while tem<>nil do begin
    if StrIComp(tem^.name, name) = 0 then break;
    prev:=tem;
    tem:= tem^.next;
  end;
  if tem <> nil then exit;
  GetMem(result, SizeOf(TSymboll));
  result^.name:= StrNew(name);
  result^.stype:= stLocal;
  result^.next:=nil;
  result^.offs:= 0;
  result^.ltype:= aType;
  if prev<>nil then prev^.next:= result;
end;


{определить функцию}
procedure Defun;
var
  ftype:TTokenType;
  Sym, head, tem:Psymboll;
  kolvo,i, count:integer;
  v:boolean;
begin
{получить тип функции}
  NextToken;
  if not(TokenValue in [ttInt..ttVoid]) then
    raise ESyntaxError.Create('type func');
  ftype:= TokenValue;
  {получить имя функции}
  NextToken;
  if (TokenValue<>ttName) then
    raise ESyntaxError.Create('name func');
  if Ident<>nil then
    raise ESyntaxError.Create('redefined name '+StrPas(TokenString));
  Sym:= CurTab.MakeSym(TokenString, stUsDef);
  GetMem(Sym^.UsDef, SizeOf(TUsDef));
  Sym^.UsDef^.ftype:=ftype;

  {получить опциональный список формальных параметров}
  NextToken;
  if TokenValue <> ttLP then
    raise ESyntaxError.Create('Левая скобка требуется');
  NextToken;
  kolvo:=0;
  head:=nil;
  v:=false;
  if TokenValue<>ttRP then begin
    repeat
       {объявление  параметра должно начинаться с его типа}
      if TokenValue = ttVar then begin
        v:=true;
        NextToken;
      end;
      if not (TokenValue in [ttInt..ttBool]) then
        raise ESyntaxError.Create('требуется тип параметра');
      ftype:= TokenValue;
      NextToken;
      if TokenValue<>ttName then
        raise ESyntaxError.Create('требуется имя');
      {создать запись о первом параметре}
      tem:= MakeSymList(ftype, TokenString,head);
      if head=nil then head:= tem;
      if v then begin
        tem^.stype:=stName;
        tem^.value:=nil;
        v:=false;
      end;
      NextToken;
      inc(kolvo);
      if TokenValue = ttComma then NextToken
      else break;
    until false;
    if TokenValue<> ttRP then
      raise ESyntaxError.Create('правая скобка требуется');
  end;{if}
  Sym^.UsDef^.ArgCount:= kolvo;
  Sym^.UsDef^.Locals:= head;

  NextToken;
  if TokenValue<>ttSemi then
    raise ESyntaxError.Create('требуется ;');
  NextToken;

  {локальные переменные}
  count:=kolvo;
  kolvo:=0;

  if TokenValue=ttVar then begin
    NextToken;
    if not (TokenValue in [ttInt..ttChar]) then
      raise ESyntaxError.Create('требуется переменная');
    repeat
      ftype:= TokenValue;
      repeat
        NextToken;
        if (TokenValue <> ttName) then
          raise ESyntaxError.Create('имя требуется');
        tem:=MakeSymList(ftype,TokenString,head);
        if head=nil then head:= tem;
        NextToken;
        inc(kolvo);
      until TokenValue <> ttComma;
      if TokenValue<>ttSemi then
        raise ESyntaxError.Create('требуется ;');
      NextToken;
    until not ( TokenValue in [ttInt..ttChar]);
   end;
  Sym^.UsDef^.VarCount:=kolvo;
  Sym^.UsDef^.Locals:= head;

  {vars^.next:=head;}
 {записать смещения значений параметров в стеке}
  i:=count+kolvo-1;
  while head<>nil do begin
    head^.offs:=i;
    dec(i);
    head:=head^.next;
  end;
  if TokenValue <> ttBegin then
   raise ESyntaxError.Create('требуется Begin');
   {NextToken;}
  Sym^.UsDef^.addr:= BufPtr;
  NextToken;
    {пропустить тело функции}
  while TokenValue<>ttEof do begin
    if TokenValue = ttEndFn then break;
    NextToken;
  end;
  if TokenValue <> ttEndfn then
    raise ESyntaxError.Create('function end');
  Sym^.UsDef^.fend:= BufPtr;
  NextToken;
end;

procedure Return;
begin
  if FuncStackPtr = 0 then
    raise ESyntaxError.Create('return ');
  NextToken;
  if CurFunc^.ftype<>ttVoid then begin
    Level1;
    FResult:= EvalStack^[EvalStackPtr];
  end;
  TokenValue:=ttEndFn;
end;




procedure ExecProc;
var
  count:integer;
  proc:TProc;
  func:PFunc;
begin
  func:= Ident^.func;
  count:= func^.count;
  NextToken;
  if Count > 0 then begin
    if TokenValue<>ttLp then
      raise ESyntaxError.Create('требуется скобка (');
    while count>0 do begin
      NextToken;
      Level1;
      dec(count);
      if tokenValue<>ttComma then
        if Count>0 then
          raise ESyntaxError.Create('мало аргументов')
        else break;
    end;
    if TokenValue<>ttRp then
      raise ESyntaxError.Create('требуется )');
     NextToken;
  end;
  proc:=TProc(func^.addr);
  proc;
  dec(EvalStackPtr,func^.count);
end;

function Test(node1, node2:PNode):boolean;
begin
  result:=false;
  case node1^.ntype of
    etInt: if node1^.ival = node2^.ival then result:=true;
    etFloat: if node1^.fval = node2^.fval then result:= true;
    etBool: if node1^.bval = node2^.bval then result:= true;
    etChar: if node1^.cval = node2^.cval then result:= true;
    etString:
      if StrComp(node1^.StrRec^.Str, node2^.StrRec^.Str) = 0 then
        result:= true;
  end;
end;

procedure GetConst;
begin
  if TokenValue <> ttLiteral then
    if TokenValue = ttQuote then begin
      inc(EvalStackPtr);
      with EvalStack^[EvalStackPtr] do begin
        ntype:= etChar;
        cval:= TokenString[0];
      end;
      exit;
    end
    else
      raise ESyntaxError.Create('константа требуется');
  GetNumber;
end;

procedure Select;
var
  node:PNode;
  level:integer;
begin
  NextToken;
  level1;
  node:= @EvalStack^[EvalStackPtr];
  if not (node^.ntype in [etInt..etChar]) then
    raise ESyntaxError.Create('ощибка типа');
  if TokenValue<>ttOf then
    raise ESyntaxError.Create('требуется OF');
  NextToken;
  while True do begin
    if TokenValue<>ttCase then
      raise ESyntaxError.Create('требуется CASE');
    NextToken;
    GetConst;
    NextToken;
    if TokenValue <> ttColon then
      raise ESyntaxError.Create('требуется :');
    if node^.ntype <>EvalStack^[EvalStackPtr].ntype then
      raise ESyntaxError.Create('ошибка типа');
    if Test(node, @EvalStack^[EvalStackPtr]) then break
    else begin
      level:=1;
      while (TokenValue<>ttEof)and(level>0) do begin
        nextToken;
        case TokenValue of
          ttSelect:  inc(level);
          ttEndSel:  dec(level);
        end;
        if ((TokenValue = ttCase)or(TokenValue=ttDefault))
        and (level=1) then break;
      end;
      if TokenValue <>ttCase then
        if (TokenValue <> ttEndsel)and(TokenValue<>ttDefault) then
          raise ESyntaxError.Create('ENDSEL требуется')
        else break;
    end;
  end;
  TokenValue:= ttSemi;
end;

procedure SkipCase;
begin
  SkipTo(ttSelect, ttEndsel);
  if TokenValue<>ttEndsel then
    raise EsyntaxError.Create('требуется ENDSEL');
  NextToken;
end;

procedure Default;
begin
  SkipTo(ttSelect, ttEndsel);
  if TokenValue<>ttEndsel
   then raise ESyntaxError.Create('требуется ENDSEL');
  NextToken;
end;

procedure ForStack;
var
  i:integer;
begin
  for i:= EvalStackSize downto EvalStackPtr do
    with EvalStack^[i] do
      if ntype = etString then
        with StrRec^ do
          if RefCount = 0 then ShowMessage(Str);
end;

procedure StmtList;
var
  f:TTokenType;
begin
  try
    NextToken;
    while tokenValue <> ttEof do begin
      case TokenValue of
        ttInt..ttChar:
          if isFunc then
            raise ESyntaxError.Create('не доступно внутри функции')
          else  defined;
        ttString:
         if isFunc then
           raise ESyntaxError.Create('не доступно внутри функции')
         else defStr;
        ttName:
          begin
            if (ident<>nil) then begin
              if ident^.stype=stUsDef then CallUser
              else if (ident^.stype=stName)or(ident^.stype=stLocal) then AssignName
              else if (ident^.stype = stFunc) then ExecProc;
            end
            else raise ESyntaxError.Create('неизвестное имя');
          end;
        ttWhile:ExWhile;
        ttWend: ExWend;
        ttFor: execFor;
        ttNext: Next;
        ttRepeat:stRepeat;
        ttUntil:stUntil;
        ttIf: begin ExIf; f:= ttIf;  end;
        ttElse: ExElse;
        ttEndif:NextToken;
        ttBreak: ExBreak;
        ttContinue: ExCont;
        ttDefun: Defun;
        ttReturn:Return;
        ttEndFn: begin  NextToken; Exit;  end;
        ttSelect: Select;
        ttDefault: Default;
        ttCase:SkipCase;
        ttEndsel: NextToken;
        ttEnd: begin NextToken; Exit; end;
      end;
      if TokenValue <> ttSemi then
         if TokenValue=ttEndFn then
           begin NextToken;  exit; end
         else  if f =  ttIf then
           begin f:= ttEof; Continue; end
         else raise ESyntaxError.Create('требуется ;');
      NextToken;
    end;
  finally
  end;
end;

type
  TKeyRec = record
    Key:PChar;
    Val:TTokenType;
  end;

TKeyArray = array [0..100] of TKeyRec;

const
  KeyCount = 47;

  KeyArray: array [1..KeyCount] of TKeyRec = (
  (Key: 'WHILE';    Val: ttWhile   ), (Key: 'WEND';   Val: ttWend  ),
  (Key: 'REPEAT';   Val: ttRepeat  ), (Key: 'UNTIL';  Val:ttUntil  ),
  (Key: 'IF';       Val: ttIf      ), (Key: 'THEN';   Val: ttThen  ),
  (Key: 'ELSE';     Val: ttElse    ), (Key: 'ENDIF';  Val: ttEndIf ),
  (Key: 'AND';      Val: ttLAnd    ), (Key: 'NOT';    Val: ttLNot  ),
  (Key: 'OR';       Val: ttLOr     ), (Key: 'XOR';    Val: ttLXor  ),
  (Key: 'TRUE';     Val: ttTrue    ), (Key: 'FALSE';  Val: ttFalse ),
  (Key: 'FOR';      Val: ttFor     ), (Key: 'TO';     Val: ttTo    ),
  (Key: 'STEP';     Val: ttStep    ), (Key: 'NEXT';   Val: ttNext  ),
  (Key: 'INT';      Val: ttInt     ), (Key: 'DO';     Val: ttDo    ),
  (Key: 'REAL';     Val: ttReal    ), (Key: 'BOOL';   Val: ttBool  ),
  (Key: 'SHL';      Val: ttShl     ), (Key: 'SHR';    Val: ttShr   ),
  (Key: 'DIV';      Val :ttDiv     ), (Key: 'MOD';    Val: ttMod   ),
  (Key: 'VECTOR';   Val: ttVector  ), (Key: 'LOOP';   Val: ttLoop  ),
  (Key: 'BREAK';    Val: ttBreak   ), (Key: 'CASE';   Val: ttCase  ),
  (Key: 'DEFUN';    Val: ttDefun   ), (Key: 'OF';     Val: ttOf    ),
  (Key: 'ENDFN';    Val: ttEndFn   ), (Key: 'RETURN'; Val: ttReturn),
  (Key: 'STRING';   Val: ttString  ), (Key: 'CHAR';   Val: ttChar  ),
  (Key: 'NULL';     Val: ttNull    ), (Key: 'MATRIX'; Val: ttMatrix),
  (Key: 'VAR';      Val: ttVar     ), (Key: 'BEGIN';  Val: ttBegin ),
  (Key: 'END';      Val: ttEnd     ), (Key: 'VOID';   Val: ttVoid  ),
  (Key: 'ARRAY';    Val: ttArray   ), (Key: 'SELECT'; Val: ttSelect),
  (Key: 'CONTINUE'; Val: ttContinue), (Key: 'ENDSEL'; Val: ttEndsel),
  (Key: 'DEFAULT';  Val: ttDefault )

  );

var
  FStream: TStream;
  FStrings: TStrings;

  function GetStream:TStream;
  begin
    result:= FStream;
  end;

  procedure SetStream(Stream:TStream);
  begin
    if Stream=nil then
      ShowMessage('неверный поток');
    FStream:= Stream;
  end;

  procedure SetStrings(Strings:TStrings);
  begin
    FStrings:= Strings;
  end;

function GetStrings:TStrings;
begin
   result:= FStrings;
end;

procedure WriteStr;
var
  tem:pchar;
  len:integer;
begin
  with EvalStack^[EvalStackPtr] do begin
    if ntype <> etString then begin
      case ntype of
        etInt: AIntToStr;
        etFloat: AFloatToStr;
        etBool: ABoolToStr;
      end;
    end;
    if ntype=etChar then begin tem:= @cval; len:=1;end
    else begin
      if strRec^.Str=nil then exit;
      tem:= StrRec^.Str;
      len:= StrRec^.Dlin;
    end;
    if FStream<>nil then
      FStream.Write(tem, len)
    else if FStrings<>nil then begin
      FStrings.SetText(tem);
    end;
    if ntype = etString then
      if StrRec^.RefCount =0 then
        ClrString(@EvalStack^[EvalStackPtr]);
  end;
end;

procedure AWriteln;
var
  tem:pchar;
begin
  WriteStr;
  if FStream<>nil then begin
    tem:= #13#10;
    FStream.Write(tem,2);
  end;
end;

procedure AStrLen;far;
var
  node: PNode;
  len:integer;
begin
  node:= @EvalStack^[EvalStackPtr];
  if node^.ntype<>etString then begin
    ShowMessage('должна быть строка');
    exit;
  end;
  if node^.StrRec^.Str = nil then len:=0
  else  len:= StrLen(node^.StrRec^.Str);
  ClrString(node);
  node^.ntype:= etInt;
  node^.ival:= Len;
end;

procedure ALength;far;
var
  len:longint;
  node:PNode;
begin
  node:=@EvalStack^[EvalStackPtr];
  len:= node^.StrRec^.Dlin;
  node^.ntype:=etInt;
  node^.ival:= len;
end;

procedure ASetLen;
begin
end;

procedure ARound;far;
var
  res:longint;
begin
  with EvalStack^[EvalStackPtr] do begin
    if ntype<>etFloat then exit;
    res:= System.Round(fval);
    ntype:= etInt;
    ival:= res;
  end;
end;

procedure ATrunc;far;
var
  result:longint;
begin
  with EvalStack^[EvalStackPtr] do begin
    if ntype <> etFloat then exit;
    result:= System.Trunc(fval);
    ntype:= etInt;
    ival:= result;
  end;
end;

procedure AChr;
var
  result:char;
begin
  with EvalStack^[EvalStackPtr] do begin
    if ntype<>etInt then exit;
    result:= chr(ival);
    ntype:= etChar;
    cval:=result;
  end;
end;

procedure AOrd;
var
  result:integer;
begin
  with EvalStack^[EvalStackPtr] do begin
    if ntype<>etChar then exit;
    result:= ord(cval);
    ntype:=etInt;
    ival:= result;
  end;
end;

procedure AMesBox;
var
  tem:string[10];
begin
  with EvalStack^[EvalStackPtr] do begin
    if ntype<>etString then begin
       case ntype of
         etInt: AIntToStr;
         etFloat: AFloatToStr;
         etBool: ABoolToStr;
       end;
    end;
    if ntype = etChar then
       begin tem[1]:= cval;  tem[0]:=chr(1); ShowMessage(tem); end
    else if ntype <>etString then exit
    else ShowMessage(string(StrRec^.Str));
//    else tem:= StrPas(StrRec^.Str);
  end;
end;

procedure ARandom;
begin
  {randomize;}
  with EvalStack^[EvalStackPtr] do begin
    ival:= System.random(ival);
  end;
end;

procedure AAbs;
begin
  with EvalStack^[EvalStackPtr] do begin
    if ntype = etInt then
      ival:= System.abs(ival)
    else if ntype = etFloat then
      fval:= System.abs(fval)
    else exit;
  end;
end;

procedure ARandomize;
begin
  Randomize;
end;

procedure AStrToFloat;
var
  result:double;
  i:integer;
begin
  with EvalStack^[EvalStackPtr] do begin
    if  ntype <> etString then exit;
    val(StrRec^.Str, result,i);
    ntype:= etFloat;
    fval:= result;
  end;
end;

procedure ALog2;
var
  tem:extended;
begin
  with EvalStack^[EvalStackPtr] do begin
    if ntype = etInt then tem:=ival
    else if ntype = etFloat then tem:=fval
    else begin ShowMessage('error type'); exit; end;
    ntype:=etFloat;
    fval:=Log2(tem);
  end;
end;

procedure ALog10;
var
  tem:extended;
begin
  with EvalStack^[EvalStackPtr] do begin
    if ntype = etInt then tem:=ival
    else if ntype = etFloat then tem:=fval
    else begin ShowMessage('error type'); exit; end;
    ntype:=etFloat;
    fval:=Log10(tem);
  end;
end;

procedure ASin;
var
  result: double;
begin
  with EvalStack^[EvalStackPtr] do begin
    if ntype = etInt then result:= ival
    else if ntype = etFloat then result:= fval
    else exit;
    ntype := etFloat;
    fval:= sin(result); 
  end;
end;

procedure ACos;
var
  result: double;
begin
  with EvalStack^[EvalStackPtr] do begin
     if ntype = etInt then result:= ival
     else if ntype = etFloat then result:= fval
     else exit;
     ntype:= etFloat;
     fval:= cos(result);
  end;
end;



type
  TProcRec = record
    Name: pchar;
    Func: TFunc;
  end;

  TFuncTable = array[1..100] of TProcRec;

const
  FuncCount = 18;

  FuncTable : array [ 1..FuncCount] of TProcRec = (
  (Name: 'STRLEN'; Func:(addr: @AStrLen; Ftype : 1; Count: 1; List: '')),
  (Name: 'LENGTH'; Func:(addr: @ALength; Ftype : 1; Count: 1; List: '')),
  (Name: 'TRUNC';  Func:(addr: @ATrunc;  Ftype : 1; Count: 1; List: '')),
  (Name: 'ROUND';  Func:(addr: @ARound;  Ftype : 1; Count: 1; List: '')),
  (Name: 'WRITE'; Func:(addr: @WriteStr; Ftype : ftProc; Count:1; List:'')),
  (Name: 'INTTOSTR'; Func:(addr: @AIntToStr; Ftype: ftFunc; Count:1; List:'')),
  (Name: 'CHR';   Func:(addr: @AChr; Ftype: ftFunc; Count:1; List:'')),
  (Name: 'ORD'; Func:(addr: @AOrd; Ftype: ftFunc; Count:1; List: '')),
  (Name: 'MESBOX'; Func:(addr: @AMesBox; Ftype: ftProc; Count:1; List:'')),
  (Name: 'WRITELN'; Func:(addr: @AWriteln; Ftype: ftProc; Count:1; List:'')),
  (Name: 'RANDOM'; Func:(addr: @ARandom; Ftype: ftFunc; count:1; List:'')),
  (Name: 'ABS';   Func:(addr: @AAbs; Ftype: ftFunc; count:1; List:'')),
  (Name: 'RANDOMIZE'; Func:(addr: @ARandomize; Ftype: ftProc; count:0; List:'')),
  (Name: 'STRTOFLOAT'; Func:(addr:@AStrToFloat; Ftype: ftFunc; count:1; list:'')),
  (Name: 'LOG10'; Func:(addr:@Alog10; ftype: ftFunc;  count:1; list:'')),
  (Name: 'LOG2'; Func:(addr:@ALog2; ftype : ftFunc; count: 1; list:'')),
  (name: 'SIN'; Func:(addr:@ASin; ftype: ftFunc; count: 1; list: '')),
  (name: 'COS'; Func:(addr:@ACos; ftype: ftFunc; count: 1; list: ''))
  );


procedure InitParser;
var
  i:integer;
  s:PSymboll;
  p:Pchar;
begin
  GetMem(EvalStack, EvalStackSize * sizeof(TNode));
  EvalStackPtr:= 0;
  MainTab:= TSymTab.Create(MaxTab);
  for i:= 1 to KeyCount do begin
    p:= KeyArray[i].Key;
    s:= MainTab.MakeSym(p, stKey);
    s^.val:= KeyArray[i].Val;
  end;
  for i:= 1 to FuncCount do begin
    s:= MainTab.MakeSym(FuncTable[i].name, stFunc);
    s^.func:= @FuncTable[i].func;
  end;

  GetMem(ctTrue, SizeOf(TNode));
  with ctTrue^ do begin
    ntype := etBool;
    bval:= 1;
  end;
  GetMem(ctFalse, SizeOf(TNode));
  with ctFalse^ do begin  ntype := etBool; bval:= 0; end;
  GetMem(LoopStack, LoopStackSize * sizeof(TLoop));
  LoopStackPtr:=0;
end;

procedure FreeParser;
var
  i:integer;
  Sym: PSymboll;
begin
  for i:= 1 to FuncCount do begin
    Sym:= MainTab.FindSym(FuncTable[i].name);
    if Sym <> nil then  Sym^.func:=nil;
  end;
  FreeMem(EvalStack, EvalStackSize * sizeof(TNode));
  MainTab.Free;
  FreeMem(ctTrue, sizeOf(TNode));
  FreeMem(ctFalse, sizeof(TNode));
  FreeMem(LoopStack, LoopStackSize * sizeOf(TLoop));
end;

procedure Parser;
begin
  try
    if (Buffer = nil) or (CurTab=nil) then
      raise Exception.Create('parser not initializen');
    FuncStackPtr:=0;
    EvalStackPtr:=0;
    LoopStackPtr:=0;
    CurFunc:=nil;
    StmtList;
  finally
    isFunc:=false;
    EvalStackPtr:=0;
  end;
end;

function GetExpr(buf:PChar; size:integer):PNode;
begin
  SetBuffer(buf,size);
  NextToken;
  Level1;
  result:= @EvalStack^[EvalStackPtr];
  dec(EvalStackPtr);
end;


const
  TokenX: array [1..25]of TTokenType= (
    ttAdd, ttSub, ttOr, ttXor, ttMul, ttFDiv, ttDiv, ttMod,ttAnd,
    ttSemi, ttComma, ttDot, ttColon, ttQwest, ttBquote, ttQuote,
    ttEq, ttLt, ttGt, ttLNot, ttNot, ttLBracket, ttRBracket,
    ttLp, ttRp);
var
  i,j:integer;
  s:string;

begin
  s:= '+-|^*/\%&;,.:?"''=<>!~[]()';
  for i:= 1 to 256 do  Tokens[i]:=ttEof;
  for i:= 1 to 25 do  Tokens[ord(s[i])]:= TokenX[i];
  count:=0;
end.


