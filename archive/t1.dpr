program t1;
uses Windows;

var
  hOut: THandle;
  s:string;
  f:integer;
begin
  AllocConsole;
  hOut:= GetStdHandle(Std_Output_Handle);
  s:= 'ffffff';
   WriteFile(hout, s[1], length(s), 
     longWord(f),  nil); 
  FreeConsole;
end.