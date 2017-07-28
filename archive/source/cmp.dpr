program cmp;
{$apptype console}
uses windows, compiler, sysutils, Classes;

var
  c: TCompiler;
  s: string;
  m: TMemoryStream;
begin
  m:= TMemoryStream.Create;
  try
    m.LoadFromFile('tst.unv');
    m.Seek(0, soFromBeginning);
    SetString(s, pchar(m.Memory), m.Size);
  finally  
    m.Free;
  end;
  try
    c:= TCompiler.Create;  
    try
      c.Compile(s);
    except on E:Exception do MessageBox(0, pchar(E.Message), '', mb_ok); 
    end;
  finally
    c.Free;
  end;
end.