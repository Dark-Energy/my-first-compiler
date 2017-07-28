unit scanner;
interface
uses sysutils, windows;
type
  TTokenValue = (tvEof, tvAdd, tvSub, tvMul, tvDiv, tvMod, tvPow,
   tvNumber,  tvGt, tvGe,  tvNe, tvEq,  tvLe, tvLt,tvLp, tvRp, 
   tvIntNum, tvAssign, tvAnd, tvOr, tvNot, tvInteger, tvReal, tvBoolean, 
   tvString, tvStrConst, tvLbrak, tvRBrak, tvIndex,
   tvArray, tvColon,  tvBoolVal, tvRealNum,  tvTrue, tvFalse, 
   tvThen, tvTo, tvDo, tvBy, tvName, 
   tvSemicolon, tvElse, tvElsif, tvUntil, tvEnd,
   tvIf, tvCase, tvWhile, tvRepeat, tvFor, tvWith, tvExit,  tvReturn,
   tvConst,  tvBegin, tvDefun,  tvIfElse,  tvNeg,  tvVarDef, tvRecord,
   tvVar, tvFormals,  tvFuncBody, tvCallFunc, tvComma, tvDot, tvInc, tvDec);

type
  TScanner = class
    FTokenValue: TTokenValue;
    FBuffer: pchar;
    FBufptr: pchar;
    FTokPtr: pchar;
    FTokEnd: pchar;
    FBufsize: pchar;
    FLineNumber: integer;
    FTokLen: integer;
    FColNumber: integer;
    function Name:string;
    function NextToken: TTokenValue;
    procedure Skip;
  public
    procedure Init(s: string);
  end;

  ELexError = class(Exception);


function LexToStr(t:TTokenValue):string;


implementation

function LexToStr(t:TTokenValue):string;
begin
  case t of 
    tvAssign: result:= 'Assign';
    tvIfElse: result:= 'IfElse';
    tvWhile: result:= 'While';
    tvRepeat: result:= 'Repeat';
    tvUntil: result:= 'Until';
    tvThen: result:= 'Then';
    tvDo: result:= 'Do'; 
    tvSemicolon: result:= ';';
    tvIntNum: result:= 'Integer';
    tvName: result:= 'Name';
    tvEof: result:= 'Eof';
    tvEnd: result:= 'End';
    tvAdd: result:= '+';
    tvSub: result:= '-';
    tvGt..tvLt: result:= 'relat';
    tvDefun: result:= 'DEFun';
    tvBegin: result:= 'BEgin';
    tvDot: result:= 'точка';
    tvInteger: result:= 'Integer';
    tvRp: result:= ')';
    tvLp: result:= '('; 
    tvComma: result:= ',';
    tvOr: result:= 'OR';
    tvAnd: result:= 'AND';
    else result:='shit';
  end;
end;

procedure TScanner.Init(s: string);
begin
  FBuffer:= pchar(S);
  FBufptr:= FBuffer;
  FTokPtr:= FBufptr;
  FTokEnd:= FBufptr;
  FTokenValue:= tvEnd;
  FTokLen:= 0;
  FLineNumber := 0; FColNumber:= 0;
end;

const
  Letters = ['A'..'Z', '_', 'a'..'z'];
  Digits = ['0'..'9'];
  AlNum = Letters + Digits;

procedure TScanner.Skip;
begin
  while True do begin
    while (FBufptr^ > #0) and (FBufptr^ <= ' ')  do begin 
      if FBufptr^ = #13 then inc(FLineNumber);
      inc(FBufptr);
    end; 
    if (FBufptr^ <> #0) and (FBufptr[0] = '/') and (FBufptr[1] = '/') then begin
      while (FBufptr^ > #0) and (FBufptr^ <> #13) do inc(FBufptr);
      if FBufptr^ = #13 then begin 
        inc(FBufptr, 2);
        inc(FLineNumber);
      end; 
    end 
    else exit;
  end;
end;

function TScanner.NextToken:TTokenValue;
var
 s : string;
begin
  Skip;
  result:= tvEof;
  FTokPtr:= FBufptr;
  if FBufptr^ = #0 then begin FTokenValue:= tvEof; exit; end
  else if FBufptr^ in Letters then begin
    while FBufptr^ in AlNum do inc(FBufptr);
    SetString(s, FTokPtr, FBufPtr - FTokPtr);
    s:= UpperCase(s);
    result:= tvName;
    CASE s[1] OF
      'A': 
        if s = 'ARRAY' then result:= tvArray;
      'B': 
        if s='BEGIN' then result:= tvBegin
        else if s = 'BY' then result:= tvBy;
      'D': 
        if s = 'DO' then result:= tvDo
        else if s = 'DEFUN' then result:= tvDefun;
      'E': 
        if s = 'ELSE' then result:= tvElse
        else if s = 'END' then result:= tvEnd
        else if s = 'ELSIF' then result:=  tvElsIf;
      'F': if s = 'FOR' then result:= tvFor 
        else if s = 'FALSE' then result:= tvFalse;
      'I': if s = 'IF' then result:= tvIf;
        //else if s = 'INTEGER' then result:= tvInteger;
      'R':  if s = 'REPEAT' then result:= tvRepeat
        else if s = 'RETURN' then result:= tvReturn
        else if s = 'RECORD' then result:= tvRecord;
      'S': if s = 'STRING' then result:= tvString; 
      'T':
        if s = 'THEN' then result:= tvThen
        else if s = 'TO' then result:= tvTo
        else if s = 'TRUE' then result:= tvTrue;
      'U': if s = 'UNTIL' then result:= tvUntil;
      'W': if s = 'WHILE' then result:= tvWhile;
    end;
  end
  else if FBufptr^ = '"' then begin
    inc(FBufptr);
    FTokPtr:= FBufptr;
    while (FBufptr^ > #0)  and (FBufptr^ <> #13) and (FBufptr^ <> '"') do begin
      inc(FBufptr);
    end;
    if FBufptr^ <> '"' then 
      raise ELexError.Create('неконченная строка');

    FTokEnd:= FBufptr;
    inc(FBufptr);
    result:= tvStrConst;
    FTokenValue:= result;
    FTokLen:= FTokEnd-FTokPtr; 
    exit;
  end
  else if FBufptr^ in Digits then begin
    while FBufptr^ in Digits do inc(FBufptr);
    if FBufptr^ = '.' then inc(FBufptr);
    while FBufptr^ in Digits do inc(FBufptr);
    result:= tvNumber;
  end
  else begin
    case FBufptr[0] of
    '-': result:= tvSub;
    '+': result:= tvAdd;
    '*': result:= tvMul;
    '.': result:= tvDot;
    '/': result:= tvDiv;
    '%': result:= tvMod; 
    '<':  case FBufptr[1] of
        '=': result:= tvLe;
        '>': result:= tvNe;
        else result:= tvLt; 
       end;
    '=': case FBufptr[1] of 
         '>' : result:= tvGe;
         '=' : result:= tvEq; 
         else result:= tvAssign;
         end;
    '|': result := tvOr;
    '&': result := tvAnd;
    ';': result := tvSemicolon;
    ':': result := tvColon; 
    ',': result:= tvComma; 
    '>': result:= tvGt;
    '(': result:= tvLp; 
    ')': result:= tvRp;
    '[': result:= tvLBrak;
    ']': result:= tvRBrak;     
    '!': if FBufptr[1] = '=' then result:= tvNe
         else result:= tvNot; 
    end; //case
    if result in [tvNot, tvGe, tvEq, tvLe, tvNe] then inc(FBufptr, 2)
    else inc(FBufptr);
  end;
  FTokenValue:= result;
  FTokEnd:= FBufPtr;
  FTokLen:= FTokEnd - FTokPtr;
end;

function TScanner.Name: string;
begin
  SetString(result, FTokPtr, FTokEnd - fTokPtr);
end;

end.
