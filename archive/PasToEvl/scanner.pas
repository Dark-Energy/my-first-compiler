unit scanner;
interface
uses SysUtils;

type TTokenVal ( tEof, tBegin, tEnd, tFunc, tProc, tType, tVar, tConst,
  tRecord, tIf,  tElse, tStdcall, tInt, tReal, tDot, tSemi, tColon, 
  tLp, tRp, tComma, tArrow, tArray, tOf, tLbrak, tRbrak
);


var
  TokPtr: pchar;
  tokEnd: pchar;
  bufptr: pchar;
  bufend: pchar;
  buffer: pchar;
  bufsize: longint;    

implementation

procedure Error(m: string);
begin
end;

procedure skip;
begin
  while bufptr < bufend do begin
    while (bufptr < bufend) and (bufptr^ <= ' ') do inc(bufptr);
    if bufptr >= bufend then exit;
    //комментарии  - до конца строки
    if (bufptr[0] = '/') and (bufptr[1] = '/') then begin
      while (bufptr < bufend) and (bufptr <> #13) do inc(bufptr);
      continue;
    end  
    else if (bufptr[0] = '{') then begin
      while (bufptr < bufend) and (bufptr^ <> '}') do inc(bufptr);
      if bufptr >= bufend then Error('неоконченный комментарий');
      inc(bufptr);
    end
    else if (bufptr[0] = '(') and (bufptr[1] = '*') then begin
      inc(bufptr, 2);
      while (bufptr<bufend) do 
        if (bufptr[0] = '*') and (bufptr[1] = ')') then begin
          inc(bufptr, 2); break;
        end
        inc(bufptr);
    end
    else break;  
  end;
end;

function Get: integer;
var
  c: char;
begin
  result:= tEof;
  skip;
  tokptr:= bufptr;
  if bufptr >= bufend then exit;
  c:= bufptr^; inc(bufptr);
  if c in Alpha then begin
     while bufptr^ in Alnum do inc(bufptr);
     tokend:= bufptr;
     SetString(tokstr, tokptr, tokend-tokptr);
     UpperChar(@tokstr[1], @tokstr[1]);
     result:= tIdent;
     case tokstr[1] of
       'C': if tokstr = 'CONST' then result := tConst;
       'E': if tokstr = 'ELSE' then result := tElse
          else if tokstr = 'END' then result:= tEnd;
       'F': if tokstr = 'FUNCTION' then result := tFunction;
       'I': if tokstr = 'IF' then result := tIf
         else if tokstr = 'IMPLEMENTATION' then result:= tImpl
         else if tokstr = 'INTERFACE' then result := tIntf;
       'P': if tokstr = 'PROCEDURE' then result:= tProcedure;
       'R': if tokstr = 'RECORD' then result := tRecord;
       'S': if tokstr = 'STDCALL' then result:= tStdcall;
       'T': if tokstr = 'TYPE' then result := tType;
     end;
  end
  else if c in Digits then begin  
     while bufptr^ in Digits do inc(bufptr);
     
  end
  else if c = '$' then begin
  end
  else begin
    '(': result:= tLp;
    ')': result:= tRp;
    '=': rseult := tEq;
    ':': result:= tColon;
    ';': result:= tSemi;
    '.': result:= tDot;
    ',': result:= tComma;     
    '^': result:= tArrow; 
    '[': result:= tLbrak;
    ']': result:= tRbrak;
  end; 
end;

end.