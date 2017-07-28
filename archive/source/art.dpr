library art;
uses Windows, SysUtils, Messages, Classes, console;


procedure ShowMessage(msg: pchar); stdcall;
begin
  MessageBox(0, msg, '', mb_ok);
end;

procedure write(i:integer); stdcall;
var
  s:string;
begin
 // ShowMessage(pchar(IntToStr(i)));
  s:= IntToStr(i)+' ';
  OutStream.Write(s[1], length(s));
end;

procedure writeln(i:integer); stdcall;
var
  s:string;
begin
  s:= IntToStr(i)+#13#10;
  OutStream.Write(s[1], Length(s));
  //ShowMessage(pchar(IntToStr(i)));
end;


exports  ShowMessage, write, writeln, ModalConsole;

end.