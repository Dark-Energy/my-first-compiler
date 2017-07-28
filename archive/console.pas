unit console;
interface
uses Windows, Messages, SysUtils, Classes;


var
   main, Edit1: HWnd;
  OutStream:TMemoryStream;

procedure ModalConsole;export;


implementation

function WindowProc(wnd : HWND; Msg : Integer;   Wparam : Wparam;
    Lparam : Lparam) : Lresult;stdcall;
Begin
  case msg of
   wm_Create:
     begin
     end;
   wm_enable:
     begin
     end;
  wm_destroy :
    Begin
     PostQuitMessage(0); 
     exit;
    End;
  else Result:=DefWindowProc(wnd,msg,wparam,lparam);
  end;
End;


var 
  xPos,
  yPos,
  nWidth,
  nHeight : Integer;
  wc: TWndClassEx;
  Mesg: TMSg;
 tId: DWord;

const
  Null: byte = 0;
function MainConsole(p:longint):longint;
begin
      wc.cbSize:=sizeof(wc); 
      wc.style:=cs_hredraw or cs_vredraw; 
      wc.lpfnWndProc:=@WindowProc;
      wc.cbClsExtra:=0; 
      wc.cbWndExtra:=0; 
      wc.hInstance:=HInstance; 
        wc.hIcon:=LoadIcon(0,idi_application);
      wc.hCursor:=LoadCursor(0,idc_arrow);
      wc.hbrBackground:=COLOR_BTNFACE+1;
      wc.lpszMenuName:=nil;
      wc.lpszClassName:='MainWindow';   

      RegisterClassEx(wc);
      xPos:=100;
      yPos:=150;
      nWidth:=400;
      nHeight:=250;
Main := CreateWindowEx(
          0, 'MainWindow',   'Консоль',  
          ws_overlappedwindow, 
          xPos, yPos, nWidth,  nHeight,
          0,  0, HINSTANCE,  nil ); 

 Edit1 := CreateWindow( 'EDIT', '',   
   WS_VISIBLE Or WS_CHILD Or WS_BORDER or
    ES_AUTOHSCROLL or ES_MULTILINE, 
    0, 0, nWidth,  nHeight,  Main, 
    0, GetWindowLong(Main, GWL_HINSTANCE),  nil);

  
  SetWindowText(Edit1, OutStream.Memory);  
  UpdateWindow(Main);
  ShowWindow(Main, cmdShow);
  While GetMessage(Mesg,0,0,0) do begin
    if (Mesg.Message = WM_QUIT) or (Mesg.Message = WM_DESTROY) then  begin
       OutStream.Free;
    end;
    TranslateMessage(Mesg);
    DispatchMessage(Mesg);
  end;
end;


procedure ModalConsole;
begin
  OutStream.Write(null,  1);
  MainConsole(0);
  //DestroyWindow(main);
end;

initialization
  OutStream:= TMemoryStream.Create;
end.