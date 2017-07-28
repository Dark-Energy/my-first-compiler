unit spl;
interface
uses sysutils;
type
  TTokenValue = (tvEof, tvAdd, tvSub, tvMul, tvDiv, tvMod, 
   tvLp, tvRp, tvAnd, tvOr, tvNot, tvInteger, tvReal,  
   tvString, tvLbrak, tvRBrak, tvArray, tvColon, tvTrue, tvFalse, 
   tvName, tvSemi, tvEnd,  tvCase, tvOf, tvConst,  tvBegin, 
   tvType, tvRecord, tvFunc, tvProc,  tvVar, tvOut, tvArrow,
   tvComma, tvDot, tvSet, tvChar, tvFDiv, tvEql);

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

implementation

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
      'A': if s = 'ARRAY' then result:= tvArray
        else if s = 'AND' then result:= tvAnd;
      'B': if s='BEGIN' then result:= tvBegin;
      'E': if s = 'END' then result:= tvEnd
      'F': if s = 'FALSE' then result:= tvFalse;
      'R': if s = 'RECORD' then result:= tvRecord;
      'S': if s = 'STRING' then result:= tvString; 
      'T': if s = 'TRUE' then result:= tvTrue;
      'O': if s = 'OF' then result:= tvOf
        else if s = 'OR' then result:= tvOr;  
      'V': if s = 'VAR' then result:= tvVar;
      'C': if s = 'CONST' then result:= tvConst;
      'T': if s = 'TYPE' then result:= tvType;
      'X': if s = 'XOR' then result:= tvXor;
      'N': if s = 'NOT' then result:= tvNot;
      'M': if s = 'MOD' then result:= tvMod;
      'D': if s = 'DIV' then result:= tvDiv; 
    end;
  end
  else if FBufptr^ = '''' then begin
    inc(FBufptr);
    FTokPtr:= FBufptr;
    while (FBufptr^ > #0)  and (FBufptr^ <> #13) and (FBufptr^ <> '''') do begin
      inc(FBufptr);
    end;
    if FBufptr^ <> '''' then 
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
    result:= tvInteger;
  end
  else if Fbufptr^ = '$' then begin
    inc(FBufptr);
    while (FBufptr^ in ['0'..'9','A'..'F', 'a'..'f']) do inc(bufptr);
    result:= tvInteger;
  end
  else begin
    case FBufptr^ of
    '-': result:= tvSub;
    '+': result:= tvAdd;
    '*': result:= tvMul;
    '.': result:= tvDot;
    '/': result:= tvFDiv;
    '=': result:= tvEql;
    ';': result := tvSemicolon;
    ':': result := tvColon; 
    ',': result:= tvComma; 
    '(': result:= tvLp; 
    ')': result:= tvRp;
    '[': result:= tvLBrak;
    ']': result:= tvRBrak;     
    end; 
    inc(FBufptr);
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
