unit Vifile;

interface

uses
  SysUtils, WinTypes, WinProcs, Messages, Classes, Graphics, Controls,
  Forms, Dialogs, StdCtrls, Pform02, Buttons;

type
  TReopenForm = class(TForm)
    ReopenBox: TListBox;
    Label1: TLabel;
    bntOr: TBitBtn;
    btnCancel: TBitBtn;
    procedure ReopenBoxDblClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure ReopenBoxKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
  private
    { Private declarations }
  public
    FileName:string;
    procedure Init(Strings:TStrings);
    procedure UpdateList(Strings:TStrings);
    function Execute:boolean;
  end;

var
  ReopenForm: TReopenForm;

implementation

{$R *.DFM}

procedure TReopenForm.ReopenBoxDblClick(Sender: TObject);
begin
  ModalResult:= mrOk;
end;

function TReopenForm.Execute:boolean;
begin
  result:= false;
  if ShowModal = mrOk then begin
    result:= true;
    FileName:= ReopenBox.Items[ReopenBox.ItemIndex];
  end;
end;

procedure TReopenForm.Init(Strings:TStrings);
begin
  ReopenBox.Items.AddStrings(Strings);
  ReopenBox.ItemIndex:=0;
end;

procedure TReopenForm.UpdateList(Strings:TStrings);
var
  tem:integer;
begin
  tem:=ReopenBox.ItemIndex;
  ReopenBox.Items.Clear;
  ReopenBox.Items.AddStrings(Strings);
  ReopenBox.ItemIndex:=0;
end;

procedure TReopenForm.FormCreate(Sender: TObject);
begin
  ReopenBox.ItemIndex:=0;
end;

procedure TReopenForm.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  case Key of
    VK_RETURN : ModalResult:= mrOk;
    VK_ESCAPE : ModalResult:= mrCancel;
  end;
end;

procedure TReopenForm.ReopenBoxKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
   if Key= VK_DELETE then begin
      IntForm.HistoryList.Delete(ReopenBox.ItemIndex);
      with Reopenbox do begin
        Items.Delete(ItemIndex);
        ItemIndex:=ItemIndex+1;
        if ItemIndex > Items.Count-1 then
          ItemIndex := Items.Count-1;
      end;
   end;
end;

end.
