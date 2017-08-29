program Intr01;

uses
  Forms,
  pform02 in 'pform02.pas' {IntForm},
  Mstream in 'MSTREAM.PAS',
  Upform01 in 'UPFORM01.PAS' {ViewForm},
  //Abox1 in '\EXAMPL\EXP\ABOX1.PAS' {ABox},
  PARS01b in 'PARS01b.pas',
  Ufind in 'UFIND.PAS' {FindForm},
  Vifile in 'VIFILE.PAS' {ReopenForm},
  FindKMP in 'FindKMP.pas';

{$R *.RES}

begin
  Application.CreateForm(TIntForm, IntForm);
  //Application.CreateForm(TABox, ABox);
  Application.CreateForm(TFindForm, FindForm);
  Application.Run;
end.
