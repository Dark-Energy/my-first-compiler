program rnd;
uses Windows, Dialogs, SysUtils;


procedure ShowMessage(msg: pchar); stdcall;
begin
  Dialogs.showMessage('ttt'); 
  {if msg = nil then 
    Dialogs.ShowMessage('nil')
  else Dialogs.ShowMessage(strPas(msg));}
  MessageBox(0, '', msg, mb_ok);
end;

exports  ShowMessage;

end.