unit pform02;

interface

uses
  SysUtils, WinTypes, WinProcs, Messages, Classes, Graphics, Controls,
  Forms, Dialogs, StdCtrls, pars01b, Buttons, ExtCtrls, TabNotBk, Menus,
  iniFiles;

type
  TIntForm = class(TForm)
    Panel1: TPanel;
    OpenSBtn: TSpeedButton;
    SaveAsBtn: TSpeedButton;
    SaveBtn: TSpeedButton;
    ClearSbtn: TSpeedButton;
    RunBtn: TSpeedButton;
    ViewBtn: TSpeedButton;
    OpenDialog: TOpenDialog;
    SaveDialog: TSaveDialog;
    MainMenu1: TMainMenu;
    mnFile: TMenuItem;
    mnFileNew: TMenuItem;
    mnFileOpen: TMenuItem;
    mnFileSave: TMenuItem;
    mnFileSaveAs: TMenuItem;
    mnFileExit: TMenuItem;
    mnHelp: TMenuItem;
    mnHelpAbout: TMenuItem;
    mnText: TMenuItem;
    mnFont: TMenuItem;
    FontDialog: TFontDialog;
    mnColor: TMenuItem;
    ColorDialog: TColorDialog;
    mnFileClose: TMenuItem;
    mnFile3: TMenuItem;
    mnFilePrint: TMenuItem;
    mnFile2: TMenuItem;
    mnRun: TMenuItem;
    mnRunRun: TMenuItem;
    mnRunCur: TMenuItem;
    Memo1: TMemo;
    mnEdit: TMenuItem;
    mnPaste: TMenuItem;
    mnCut: TMenuItem;
    mnCopy: TMenuItem;
    Header: TPanel;
    Locate: TPanel;
    PnlModify: TPanel;
    PnlFileName: TPanel;
    mnSearch: TMenuItem;
    mnFindAg: TMenuItem;
    mnReopen: TMenuItem;
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure RunBtnClick(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure memo1KeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure OpenSBtnClick(Sender: TObject);
    procedure ClearSbtnClick(Sender: TObject);
    procedure SaveAsBtnClick(Sender: TObject);
    procedure SaveBtnClick(Sender: TObject);
    procedure mnHelpAboutClick(Sender: TObject);
    procedure mnFileExitClick(Sender: TObject);
    procedure mnFileOpenClick(Sender: TObject);
    procedure mnFileSaveClick(Sender: TObject);
    procedure mnFileSaveAsClick(Sender: TObject);
    procedure mnFontClick(Sender: TObject);
    procedure mnColorClick(Sender: TObject);
    procedure memo1Change(Sender: TObject);
    procedure mnFileNewClick(Sender: TObject);
    procedure mnFileCloseClick(Sender: TObject);
    procedure mnRunRunClick(Sender: TObject);
    procedure mnRunCurClick(Sender: TObject);
    procedure mnCutClick(Sender: TObject);
    procedure mnCopyClick(Sender: TObject);
    procedure mnPasteClick(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure mnSearchClick(Sender: TObject);
    procedure mnFindAgClick(Sender: TObject);
    procedure mnReopenClick(Sender: TObject);
  //  procedure FormShow(Sender: TObject);
  private
    SymTab:TSymTab; //таблица символов
    Strings:TStrings;  //строки для вывода
    FStream:TStream;  //поток вывода
    FileName:ShortString; //имя открытого файла
    OpenFlag:boolean;
    IniFile:TFileStream;  //ини-файл
    IniName:string;       //имя ини-файла
    ResFile:TFileStream;  //файл  параметров мемо
    ResName:TFileName;    //имя файла параметров мемо
    FModify:boolean;      //флаг изменений
    FFontName:TFontName;  //имя шрифта
    FFontChange:boolean;  //изменение отображения шрифта
    FHistoryList:TStringList; //открытые файлы
    SaveList:TStringList; //сохраненные файлы
    Rect:TRect;
    Buffer:pchar; {буфер}
    Buflen:longint; {длина буфера-1}
    procedure RunInt;
    procedure LineCor;
    procedure AddFile(FileName:string);
    procedure CloseFile;
    procedure SaveFile;
    procedure RunIntAtCur(pos:longint);
    function TestFile:boolean;
    procedure NotFound;
    function MemoCurPos:TPoint;
  public
    property HistoryList:TStringList read FHistoryList;
  end;

var
  IntForm: TIntForm;

implementation
{$R *.DFM}
Uses UPForm01, MStream,  UFind, ViFile, FindKmp;

const
  iniFileName :string = 'univac.ini';

procedure TIntForm.FormCreate(Sender: TObject);
var
  i, count:integer;
  IniFile:TIniFile;
begin
  FileName:='';
  try
    InitParser;
  except
    ShowMessage('Ошибка инициализации');
  end;
  SymTab:= TSymTab.Create(200);
  Strings:= TStringList.Create;
  FStream:= TMemStream.Create;
  ViewForm2:= TViewForm.Create(Self);
  ViewForm2.Left:=16;
  ViewForm2.Top:=20;
  ViewForm2.Width:= 400;
  ViewForm2.Height:= 300;
  FHistoryList:= TStringList.Create;

  IniFileName:= ExtractFilePath(ParamStr(0))+IniFileName;
  IniFile:= TIniFile.Create(IniFileName);
  try
    FileName:= IniFile.ReadString('LastFile', 'FileName', '');
    count:= IniFile.ReadInteger('FileList', 'Count', 0);
    if Count > 10 then Count:= 10;
    for i:= 0 to count-1 do 
      FHistoryList.Add(IniFile.ReadString('FileList',  'FileName'+IntToStr(i), ''));
    i:= IniFile.ReadInteger('Window', 'Top', 0);
    if i > 0 then Top:= i;
    i:= IniFile.ReadInteger('Window', 'Left', 0);
    if i > 0 then Left:= i;
    i:= IniFile.ReadInteger('Window', 'Height', 0);
    if i > 0 then Height:= i;
    i:= IniFile.ReadInteger('Window', 'Width', 0);
    if i > 0 then Width:= i;  
  finally
    IniFile.Free;
  end;
  if ParamCount > 0 then 
    FileName:= ParamStr(1);
  FModify:=false;
  OpenFlag:=false;
end;


procedure TIntForm.FormClose(Sender: TObject; var Action: TCloseAction);
var
  i:integer;
  IniFile: TIniFile;  
begin
  if not TestFile then
      begin Action:= caNone; exit; end;

  FreeParser;
  Strings.Free;
  FStream.Free;

  IniFile:=TIniFile.Create(IniFileName);
  try
    if FileName <> '' then    
      IniFile.WriteString('LastFile', 'FileName', FileName);
    IniFile.WriteInteger('FileList', 'Count', FHistoryList.Count);
    for i:= 0 to FHistoryList.Count-1 do 
      if i <10 then 
        IniFile.WriteString('FileList', 'FileName'+IntToStr(i), FHistoryList[i])
      else break;
    with IniFile do begin
      WriteInteger('Window', 'Left', Left);
      WriteInteger('Window', 'Top', Top);
      WriteInteger('Window', 'Height', Height);
      WriteInteger('Window', 'Width', Width);
    end;
  finally
    IniFile.Free;
  end;
end;

procedure TIntForm.RunBtnClick(Sender: TObject);
begin
  RunInt;
end;

procedure TIntForm.RunInt;
var
  Buf:PChar;
  Size:longint;
begin
 try
  SymTab.Clear;
  Size:= Memo1.GetTextLen+1;
  GetMem(Buf, size);
  Memo1.GetTextBuf(buf, size);
  SetSymTab(SymTab);
  SetBuffer(buf, size);
  SetStrings(Strings);
  {FStream.Seek(0,soFromBeginning);}
  TMemStream(FStream).Clear;
  TMemStream(FStream).WriteDone:= false;
  SetStream(FStream);
  Parser;
  FreeMem(Buf, Size);
  Strings.Clear;
  FStream.Seek(soFromBeginning,0);
  if TMemStream(FStream).WriteDone then begin
    ViewForm2.Print2(FStream);
    ViewForm2.Show;
    ViewForm2.BringToFront;
  end;
  except
   on E:ESyntaxError do begin
     ShowMessage(E.Message);
     Memo1.SelStart:= E.Pos;
     Memo1.Perform(EM_SCROLLCARET, 0,0);
   end
   else raise;
  end;
end;

procedure TIntForm.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if Key=VK_F9 then RunInt;
  if (Key=VK_F4) and (ssCtrl in Shift) then CloseFile
  else if Key=VK_F2 then SaveBtnClick(Sender)
  else if (Key=$53)and(ssCtrl in Shift)then SaveBtnClick(Sender)
  else if (Key=$58)and(ssAlt in Shift) then Close
  else if ((Key=$4F)or(Key=202)) and (ssCtrl in Shift) then
    OpenSBtnClick(Sender);
end;

procedure TIntForm.memo1KeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
  var
    line:longint;
begin
  if (ssCtrl in Shift) then begin
    Line:= Memo1.Perform(EM_LINEFROMCHAR, Memo1.SelStart,0);
    case Key of
      $59: Memo1.Lines.Delete(line);
      $4E: Memo1.Lines.Insert(line, '');
    end;
   end;
   LineCor;
end;

function TIntForm.MemoCurPos:TPoint;
begin
  Result.X := LongRec(SendMessage(Handle, EM_GETSEL, 0, 0)).Hi;
  Result.Y := SendMessage(Handle, EM_LINEFROMCHAR, Result.X, 0);
  Result.X := Result.X - SendMessage(Handle, EM_LINEINDEX, -1, 0);
end;

procedure TIntForm.LineCor;
var
  Line:integer;
  Chars:integer;
begin

  Chars:= Memo1.SelStart;
  Line:= Memo1.Perform(EM_LINEFROMCHAR, Chars,0);
  Chars:= Chars - SendMessage(Memo1.Handle, EM_LINEINDEX,word(-1),0);

  Locate.Caption:='  '+IntToStr(line)+':  '+ IntToStr(chars)+'  ';
end;

procedure TIntForm.OpenSBtnClick(Sender: TObject);
begin
  if OpenDialog.Execute then begin
    if not TestFile then exit;
    FileName:= OpenDialog.FileName;
    AddFile(FileName);
  end;
end;


function TIntForm.TestFile:boolean;
var
 res:word;
begin
  result:=true;
  if Memo1.Modified then begin
    res:= MessageDlg('Файл изменен. Сохранить?',
      mtConfirmation, [mbYes, mbNo, mbCancel],0);
    if res = mrYes then
     if FileName='' then SaveAsBtnClick(nil)
     else SaveFile
    else if res = mrCancel then result:=false;
  end;
end;

procedure TIntForm.SaveFile;
begin
  Memo1.Lines.SaveToFile(FileName);
  Memo1.Modified:=False;
  PnlFileName.Caption:= ExtractFileName(FileName);
  PnlModify.Caption:='';
end;

procedure TIntForm.AddFile(FileName:string);
begin
  FHistoryList.Add(FileName);
  FModify:=true;
  Memo1.Lines.LoadFromFile(FileName);
  Memo1.Modified:=false;
  PnlFileName.Caption:=ExtractFileName(FileName);
  PnlModify.Caption:='';
end;

procedure TIntForm.SaveAsBtnClick(Sender: TObject);
begin
  SaveDialog.FileName:= ExtractFileName(FileName);
  if SaveDialog.execute then begin
    FModify:=true;
    FileName:=SaveDialog.FileName;
    FHistoryList.Add(FileName);
    ReopenForm.UpdateList(FHistoryList);
    SaveFile;
  end;
end;

procedure TIntForm.SaveBtnClick(Sender: TObject);
begin
  if (FileName='') or OpenFlag then begin
    SaveDialog.FileName:= 'prog1.unv';
    if SaveDialog.Execute then begin
      FileName:= SaveDialog.FileName;
      SaveDialog.HistoryList.Insert(0,FileName);
      SaveFile;
    end;
    OpenFlag:=false;
  end
  else SaveFile;
end;


procedure TIntForm.CloseFile;
begin
  if not TestFile then exit;
  Memo1.Clear;
  PnlModify.Caption:='';
  Locate.Caption:='0:0';
  PnlFileName.Caption:='';
  FileName:='';
  if Memo1.Modified then Memo1.Modified:= false
end;

procedure TIntForm.ClearSbtnClick(Sender: TObject);
begin
  SymTab.DeleteNames;
end;

procedure TIntForm.mnHelpAboutClick(Sender: TObject);
begin
//  ABox.ShowModal;
end;

procedure TIntForm.mnFileExitClick(Sender: TObject);
begin
  Close;
end;

procedure TIntForm.mnFileOpenClick(Sender: TObject);
begin
  OpenSBtnClick(Sender);
end;

procedure TIntForm.mnFileSaveClick(Sender: TObject);
begin
  SaveBtnClick(Sender);
end;

procedure TIntForm.mnFileSaveAsClick(Sender: TObject);
begin
  SaveAsBtnClick(Sender);
end;

procedure TIntForm.mnFileCloseClick(Sender: TObject);
begin
  CloseFile;
end;

procedure TIntForm.mnFontClick(Sender: TObject);
begin
  FontDialog.Font:= Memo1.Font;
  if FontDialog.Execute then begin
    Memo1.Font:=FontDialog.Font;
    FFontChange:=True;
  end;
end;

procedure TIntForm.mnColorClick(Sender: TObject);
begin
  ColorDialog.Color:= Memo1.Color;
  if ColorDialog.Execute then begin
    Memo1.Color:= ColorDialog.Color;
    FFontChange:= true;
  end;
end;


procedure TIntForm.memo1Change(Sender: TObject);
begin
  if Memo1.Modified then PnlModify.Caption:='Изменено';
end;

procedure TIntForm.mnFileNewClick(Sender: TObject);
begin
  if not TestFile then exit;
  Memo1.Clear;
  FileName:= 'prog1.unv';
  PnlFileName.Caption:='prog1.Unv';
  PnlModify.Caption:='';
  OpenFlag:=true;
end;


procedure TIntForm.mnRunRunClick(Sender: TObject);
begin
  RunInt;
end;

procedure TIntForm.RunIntAtCur(pos:longint);
var
  Buf,BufPtr:PChar;
  Size:longint;
begin
 try
  SymTab.Clear;
  pos:=memo1.SelStart;
  Size:= Memo1.GetTextLen+1;
  GetMem(Buf, size);
  Memo1.GetTextBuf(buf, size);
  BufPtr:= Buf+pos;
  SetSymTab(SymTab);
  SetBuffer(bufPtr, size);
  SetStrings(Strings);
  {FStream.Seek(0,soFromBeginning);}
  TMemStream(FStream).Clear;
  TMemStream(FStream).WriteDone:= false;
  SetStream(FStream);
  Parser;
  FreeMem(Buf, Size);
  SymTab.Report(Strings);
  Strings.Clear;
  FStream.Seek(soFromBeginning,0);
  if TMemStream(FStream).WriteDone then begin
    ViewForm2.Print2(FStream);
    ViewForm2.Show;
    ViewForm2.BringToFront;
  end;
  except
   on E:ESyntaxError do ShowMessage(E.Message);
   else raise;
  end;
end;

procedure TIntForm.mnRunCurClick(Sender: TObject);
begin
 RunIntAtCur(Memo1.SelStart);
end;

procedure TIntForm.mnCutClick(Sender: TObject);
begin
  Memo1.CutToClipboard;
end;

procedure TIntForm.mnCopyClick(Sender: TObject);
begin
  Memo1.CopyToClipboard;
end;

procedure TIntForm.mnPasteClick(Sender: TObject);
begin
  Memo1.PasteFromClipboard;
end;

procedure TIntForm.FormResize(Sender: TObject);
begin
  Memo1.Align:=alClient;
end;


procedure TIntForm.NotFound;
begin
  MessageDlg('Строка ' + StrPas(patern)+' не найдена',
          mtInformation, [mbOk], 0);
end;



procedure SetSelStart(pos:integer);
begin
  with IntForm do begin
    memo1.SelStart:= pos;
    Memo1.Perform(EM_SCROLLCARET,0,0);
  end;
end;

procedure TIntForm.mnSearchClick(Sender: TObject);
var
  bufptr:pchar;
  bufdlin,
  Origin,
  pos,
  CurPos:integer;
begin
   if FindForm.Execute then begin
    {получить буфер с текстом}
    try
      buflen:=Memo1.GetTextLen;
      GetMem(buffer, sizeof(char)*(buflen+1));
      Memo1.GetTextBuf(Buffer, buflen+1);

      Origin:= FindForm.Origin;
      CurPos:=Memo1.SelStart;
      {искать с позиции курсора}
      if Origin=FindFromCur then begin
        Bufptr:= Buffer+CurPos;
        bufdlin:=buflen-CurPos+1;
      end
      {весь файл}
      else begin
        bufptr:=buffer;
        bufdlin:=buflen;
      end;
      {установить образец с опициями}
      with FindForm do
        SetPatern(patern, len, Words, Cased);
      {выполнить поиск}
      pos:=Find(Bufptr, bufdlin);
    finally
      FreeMem(Buffer, sizeof(char)*(BufLen+1));
    end;
    if pos > -1 then begin
     {положение курсора в начале поиска + позиция образца в тексте}
      if Origin=FindFromCur then begin
        inc(pos, CurPos);
        SetSelStart(pos);
      end
      else SetSelStart(pos);
    end
    else NotFound;
  end;
end;

procedure TIntForm.mnFindAgClick(Sender: TObject);
var
  pos:integer;
  bufptr:pchar;
  bufdlin:integer;
  CurPos:integer;
begin
  try
    {получить буфер с текстом}
    buflen:=Memo1.GetTextLen;
    bufdlin:=buflen;
    GetMem(Buffer, sizeof(char)*(Buflen+1));
    Memo1.GetTextBuf(Buffer, Buflen+1);

    {текущая позиция в тексте}
    CurPos:=memo1.SelStart;
    dec(bufdlin,CurPos+1);
    bufptr:=buffer+CurPos+1;
    pos:= Find(Bufptr, bufdlin);
  finally
    FreeMem(Buffer, (Buflen+1)*sizeof(char));
  end;
  if pos > -1 then SetSelStart(pos+CurPos+1)
  else  NotFound;
end;

procedure TIntForm.mnReopenClick(Sender: TObject);
begin
  if ReopenForm.Execute then begin
    AddFile(ReopenForm.FileName);
    FileName:= ReopenForm.FileName;
    OpenFlag:=false;
  end;
end;



{procedure TIntForm.FormShow(Sender: TObject);
var
  len:word;
begin
      IniFile.Seek(160, soFromBeginning);
      IniFile.Read(len, sizeof(word));
      Memo1.SelStart:=len;
      Memo1.Perform(EM_SCROLLCARET,0,0);
end;}

end.


