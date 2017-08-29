unit pform01;

interface

uses
  SysUtils, WinTypes, WinProcs, Messages, Classes, Graphics, Controls,
  Forms, Dialogs, StdCtrls, pars01c, Buttons, ExtCtrls, TabNotBk, Menus;

type

  TFindText = class(TObject)
  private
    FPatLen:integer;{длина образца}
    FPatern:array[0..255]of char;{образец для поиска}
    FDef:array[0..255]of integer;{вектор значений для поиска}
    FBuffer:pchar; {буфер}
    FBuflen:longint; {длина буфера-1}
    FLastPos:integer;{где был последний найденный текст}
    FCaseIgnore:boolean;{прописные/строчные}
    FWordsOnly:boolean;{только слова}
    procedure SetBuffer(ABuffer:pchar);
    procedure SetBuflen(ABuflen:integer);
    procedure SetPatern(APatern: pchar);
  public
    constructor Create;
    function Find(ABuffer:pchar; ABufLen:integer):integer;
    function FindCaseIgnore(ABuffer:pchar; ABufLen:integer):integer;
    function FindWord(ABuffer:pchar; ABufLen:integer):integer;
    function FindText:integer;
    property WordsOnly: boolean read FWordsOnly write FWordsOnly;
    property CaseIgnore: boolean read FCaseIgnore write FCaseIgnore;
    property Patern:pchar write SetPatern;
    property Buffer:pchar write FBuffer;
    property Buflen:longint write FBuflen;
  end;





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
    procedure RunInt;
    procedure LineCor;
    procedure AddFile(FileName:string);
    procedure CloseFile;
    procedure SaveFile;
    procedure RunIntAtCur(pos:longint);
    function TestFile:boolean;
    function FindCaseIgnore(buffer:pchar; buflen:integer):integer;
    function Find(buffer:pchar;buflen:integer):integer;
    function FindWord(buffer:pchar; buflen:integer):integer;
    procedure NotFound;
    function MemoCurPos:TPoint;
  public
    property HistoryList:TStringList read FHistoryList;
  end;



var
  IntForm: TIntForm;

implementation
{$R *.DFM}
Uses UPForm01, MStream, ABox1, UFind, ViFile;


procedure TIntForm.FormCreate(Sender: TObject);
var
  len:integer;
  tem:string[100];
  f:boolean;
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
  IniName:='c:\exampl\parse\pr\univ.ini';
  f:=true;
  FHistoryList:= TStringList.Create;
  if ParamCount > 0 then begin
    FileName:= ParamStr(1);
    if fileExists(FileName) then
      begin AddFile(FileName); f:=false; end
    else  ShowMessage('неверное имя файла');
  end;
    if not FileExists(IniName) then begin
      IniFile:=TFileStream.Create(IniName,fmCreate);
      FillChar(tem,100,'c');
      IniFile.Write(tem, 100);
      IniFile.Write(tem, 100);
      FFontChange:=True;
      FModify:=True;
    end
    else begin
      IniFile:=TFileStream.Create(IniName,fmOpenReadWrite);
      try
        if f then begin
          len:=0;
          IniFile.Read(len, sizeof(word));
          if len<>0  then begin
            len:=IniFile.Read(FileName[1],len);
            FileName[0]:=chr(len);
            AddFile(FileName);
          end;
        end;
        IniFile.Seek(180, soFromBeginning);
        FHistoryList.Sorted:=true;
        FHistoryList.Duplicates:=dupIgnore;
        FHistoryList.LoadFromStream(IniFile);
        FFontChange:=true;

        if ReopenForm = nil then begin
          ReopenForm:= TReopenForm.Create(Self);
        end;
       ReopenForm.Init(FHistoryList);


      IniFile.Seek(150, soFromBeginning);
      IniFile.Read(Rect.Left, sizeof(word));
      IniFile.Read(Rect.Top, sizeof(word));
      IniFile.Read(Rect.Bottom, sizeof(word));
      IniFile.Read(Rect.Right, sizeof(word));
      IntForm.Left:=Rect.Left;
      IntForm.Top:=Rect.Top;
      IntForm.Height:=Rect.Bottom;
      IntForm.Width:=Rect.Right;

        ResName:= 'c:\exampl\univ\univ.fm';
        if not FileExists(ResName) then
          ResFile:= TFileStream.Create(ResName, fmCreate)
        else begin
          ResFile:= TFileStream.Create(ResName, fmOpenReadWrite);
          ResFile.ReadComponent(Memo1);
          FFontChange:=false;
        end;
      except
        ShowMessage('ошибка чтения ини файла');
      end;
    end;
    FModify:=false;
    OpenFlag:=false;
 end;


procedure TIntForm.FormClose(Sender: TObject; var Action: TCloseAction);
var
  len:integer;
begin
    if not TestFile then
      begin Action:= caNone; exit; end;

    FreeParser;
    Strings.Free;
    FStream.Free;

    if FModify then begin
      len:= length(FileName);
      IniFile.Seek(0,soFromBeginning);
      if FileName<>''then begin
        IniFile.Write(len,sizeof(word));
        IniFile.Write(FileName[1], len);
      end
      else begin
        len:=0;
        IniFile.Write(len,2);
      end;
      IniFile.Seek(180, soFromBeginning);
      FHistoryList.Sort;
      FHistoryList.SaveToStream(IniFile);
      FHistoryList.Free;
    end;

    if (Rect.Top<>top)or(Rect.Left<>Left) then begin
      IniFile.Seek(150, soFromBeginning);
      len:=Left;
      IniFile.Write(len, sizeof(word));
      len:=Top;
      IniFile.Write(len, sizeof(word));
      len:=Height;
      IniFile.Write(len, sizeof(word));
      len:=Width;
      IniFile.Write(len, sizeof(word));
    end;

    Memo1.Clear;
    if FFontChange then  begin
      ResFile.Seek(0, soFromBeginning);
      ResFile.WriteComponent(Memo1);
      ResFile.WriteComponent(OpenDialog);
    end;
    IniFile.Destroy;
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
  if (FileName='')or OpenFlag then begin
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
  ABox.ShowModal;
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
  pos:integer;
  buffer:pchar;
  dlin:integer;
  Origin:integer;
  start:integer;
begin
  dlin:=Memo1.GetTextLen;
  GetMem(buffer, sizeof(char)*(dlin+1));
  Memo1.GetTextBuf(Buffer, dlin+1);
  if FindForm.Execute then begin
    FT.PatLen:=FindForm.Len;
    FT.Patern:=FindForm.Patern;
    Origin:= FindForm.Origin;
    start:=Memo1.SelStart;
    FT.CaseIgnore:=FindForm.Cased;
    if Origin = 0 then begin
      FT.Buffer:= Buffer+Memo1.SelStart;
      FT.Buflen:=dlin-Memo1.SelStart+1;
    end
    else begin
      FT.buffer:=buffer;
      FT.buflen:=dlin;
    end;
    FT.Words:=FindForm.Words;

    if Words then  pos:=FindWord(bufptr, dlin)
    else begin
      if Cased then pos:=Find(bufptr, dlin)
      else pos:=FindCaseIgnore(bufptr,dlin);
    end;
    LastPos:=pos;
    if pos > -1 then begin
      if Origin=0 then begin
        inc(pos, Start);
        SetSelStart(pos);
      end
      else SetSelStart(pos);
    end
    else NotFound;
  end;
  FreeMem(Buffer, sizeof(char)*(BufLen+1));
end;

procedure TIntForm.mnFindAgClick(Sender: TObject);
var
  pos:integer;
  bufptr:pchar;
  bufdlin:integer;
begin
  buflen:=Memo1.GetTextLen;
  bufdlin:=buflen;
  GetMem(Buffer, sizeof(char)*(Buflen+1));
  Memo1.GetTextBuf(Buffer, Buflen+1);
  dec(bufdlin,LastPos);
  bufptr:=buffer+LastPos+1;
  FT.FindText(FindForm.Words, FindForm.Cased,
  if Words then pos:=FindWord(bufptr, bufdlin)
  else begin
    if Cased then pos:=Find(bufptr,bufdlin)
    else pos:=FindCaseIgnore(bufptr,bufdlin);
  end;
  FreeMem(Buffer, (Buflen+1)*sizeof(char));
  if pos > -1 then SetSelStart(pos+LastPos+1)
  else
    NotFound;
  LastPos:=LastPos+pos+1;
end;

procedure TIntForm.mnReopenClick(Sender: TObject);
begin
  if ReopenForm.Execute then begin
    AddFile(ReopenForm.FileName);
    FileName:= ReopenForm.FileName;
  end;
end;


function TFintText.FindText:integer;
begin
  if CaseIgnore then
    if WordsOnly then
    result:=FindCaseIgnore

end;

function TFindText.Find(abuffer:pchar; abuflen:integer):integer;
var
  i,j,k :integer;
begin
  k:=-1;
  j:=0;
  d[0]:=-1;
  result:=-1;
while j<len-1 do begin
  while (k>=0)and (patern[j]<>patern[k])do k:=d[k];
  inc(j); inc(k);
  if patern[j] =patern[k] then d[j] :=d[k] else d[j]:=k;
end;

i:=0;  j:=0;
while (j<len) and (i<Buflen) do begin
  while (j>=0) and (buffer[i]<>patern[j]) do j:=d[j];
  inc(i);  inc(j);
end;
if j = len then result:=i-len;
end;

function TFindText.FindCaseIgnore(aBuffer:pchar; aBuflen:integer):integer;
var
  i,j,k:integer;
  p:pchar;
begin
  GetMem(p, sizeof(char)*(len+1));
  StrCopy(p, patern);
  k:=-1; j:=0; d[0]:=-1;
  result:=-1;
  StrUpper(p);
while j<len-1 do begin
  while (k>=0)and (p[j]<>p[k])do k:=d[k];
  inc(j); inc(k);
  if p[j] =p[k] then d[j] :=d[k] else d[j]:=k;
end;

i:=0;  j:=0;
while (j<len) and (i<Buflen) do begin
  while (j>=0) and (UpCase(buffer[i])<>p[j]) do j:=d[j];
  inc(i);  inc(j);
end;
if j = len then result:=i-len;
FreeMem(p, sizeof(char)*(len+1));
end;

function TFindText.FindWord(abuffer:pchar; abuflen:integer):integer;
var
  i,j:integer;
begin
  result:=-1;
  j:=0; i:=0;
  while (j<len) and (i < buflen) do begin
    while buffer[i]<=' ' do inc(i);
    j:=0;
    while (buffer[i]=patern[j]) do begin
      inc(j); inc(i);
    end;
    if j=len then
      if buffer[i]=' 'then break else j:=0;
    while buffer[i]>' ' do inc(i);
  end;
  if j=len then result:=i-len;
end;


procedure TFindText.SetBuffer(ABuffer:pchar);
begin
  FBuffer:=ABuffer;
end;

procedure TFindText.SetBuflen(ABuflen:integer);
begin
  FBuflen:=ABuflen;
end;

procedure TFindText.SetPatern(APatern:pchar);
begin
  StrCopy(FPatern, APatern);
end;

end.


