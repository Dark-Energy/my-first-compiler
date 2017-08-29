program tst;
{$apptype console}
uses windows, compiler, sysutils, gencode, Classes;
type
 tproc = procedure;

function FormatError:string;
var
  ErrorCode: Integer;
  Buf: array [Byte] of Char;
begin
  ErrorCode := GetLastError;
    FormatMessage(
      FORMAT_MESSAGE_FROM_SYSTEM, 
      nil,
      ErrorCode, 
      LOCALE_USER_DEFAULT, 
      Buf, 
      sizeof(Buf), 
      nil); 
  MessageBox(0, @buf[0], '', mb_ok);
  SetString(result, buf, strlen(buf)); 
end;


type
  TGeneratedCode = function : integer;

var
  comp: TCompiler;
  source: string;
  p: tproc;
  generated_code: TGeneratedCode;
  m: TMemoryStream;
  n: boolean;
begin
  m:= TMemoryStream.Create;
    m.LoadFromFile('tst.unv');
    m.Seek(0, soFromBeginning);
    SetString(source, pchar(m.Memory), m.Size);
    comp:= TCompiler.Create;
  n:= true;
try
  generated_code:= TGeneratedCode(comp.Compile(source));
except
  on E:Exception do begin
    MessageBox(0, pchar(E.Message), '', mb_ok); n:= false;
  end;
end;
 try  
     if n then generated_code;
  except 
    on E:Exception do writeln(E.Message+'; Run-Time Error');  end;
  //writeln(StVar1,',', StVar2, ',', StVar3, ',', StVar4);
  //c.SaveAsText('tst.dmp');
  c.Free;
  m.Free;
end.