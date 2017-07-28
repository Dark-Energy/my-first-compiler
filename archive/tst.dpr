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


var
  c: TCompiler;
  s: string;
  p: tproc;
  f: function: integer;
  m: TMemoryStream;
  n: boolean;
begin
  m:= TMemoryStream.Create;
    m.LoadFromFile('tst.unv');
    m.Seek(0, soFromBeginning);
    SetString(s, pchar(m.Memory), m.Size);
    c:= TCompiler.Create;
  n:= true;
try
  f:= c.Compile(s);
except
  on E:Exception do begin
    MessageBox(0, pchar(E.Message), '', mb_ok); n:= false;
  end;  
end;
 try  
     if n then f;
  except 
    on E:Exception do writeln(E.Message+'; Run-Time Error');  end;
  //writeln(StVar1,',', StVar2, ',', StVar3, ',', StVar4);
  //c.SaveAsText('tst.dmp');
  c.Free;
  m.Free;
end.