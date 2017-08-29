unit Upform01;

interface

uses
  SysUtils, WinTypes, WinProcs, Messages, Classes, Graphics, Controls,
  Forms, Dialogs, StdCtrls, Buttons, ExtCtrls;

type
  TViewForm = class(TForm)
    Memo1: TMemo;
    Panel1: TPanel;
    CloseBtn: TBitBtn;
    ClearBtn: TBitBtn;
    procedure CloseBtnClick(Sender: TObject);
    procedure ClearBtnClick(Sender: TObject);
  public
    procedure Print(Strings:TStrings);
    procedure Print2(Stream:TStream);
  end;

var
  ViewForm: TViewForm;
  ViewForm2: TViewForm;

implementation

{$R *.DFM}

procedure TViewForm.CloseBtnClick(Sender: TObject);
begin
  Close;
end;

procedure TViewForm.Print(Strings:TStrings);
begin
  Memo1.Lines.AddStrings(Strings);
  {Show;}
end;


procedure TViewForm.ClearBtnClick(Sender: TObject);
begin
  Memo1.Clear;
end;

procedure TViewForm.Print2(Stream:TStream);
begin
  Memo1.Lines.LoadFromStream(Stream);
  {Show;}
end;

end.
