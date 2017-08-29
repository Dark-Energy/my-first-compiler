unit Ufind;

interface

uses
  SysUtils, WinTypes, WinProcs, Messages, Classes, Graphics, Controls,
  Forms, Dialogs, StdCtrls, Buttons, ExtCtrls;

type
  TFindForm = class(TForm)
    BitBtn1: TBitBtn;
    BitBtn2: TBitBtn;
    edFText: TEdit;
    Label1: TLabel;
    rgOrig: TRadioGroup;
    rgDirect: TRadioGroup;
    GroupBox1: TGroupBox;
    chCase: TCheckBox;
    chWords: TCheckBox;
    procedure FormCreate(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
  public
    len:integer;
    patern:array[0..255]of char;
    Cased:boolean;
    Origin:integer;
    Direct:integer;
    Words:boolean;
    function Execute:boolean;
  end;

var
  FindForm: TFindForm;

const
  FindGlobal = 1;
  FindFromCur = 0;


implementation

{$R *.DFM}


function TFindForm.Execute:boolean;
begin
  result:=false;
  rgOrig.ItemIndex:=Origin;
  rgDirect.ItemIndex:=Direct;
  chCase.Checked:=Cased;
  chWords.Checked:= Words;
  if ShowModal=mrOk then begin
    len:= edFText.GetTextLen;
    edFText.GetTextBuf(patern, len+1);
    result:=true;
    Origin:=rgOrig.ItemIndex;
    Direct:=rgDirect.ItemIndex;
    Cased:=chCase.Checked;
    Words:=chWords.Checked;
  end;
end;



procedure TFindForm.FormCreate(Sender: TObject);
begin
  Cased:=false;
  Words:=false;
  Origin:=0;
  Direct:=0;
end;

procedure TFindForm.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  case Key of
    VK_RETURN : ModalResult:=mrOk;
    VK_ESCAPE : ModalResult:=mrCancel;
  end;
end;

end.
