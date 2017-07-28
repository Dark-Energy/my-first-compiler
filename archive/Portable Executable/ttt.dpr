library ttt;
uses Windows, SysUtils;


procedure ShowMessage(msg: pchar); stdcall;
begin
  MessageBox(0, '', msg, mb_ok);
end;

exports  ShowMessage;

end.