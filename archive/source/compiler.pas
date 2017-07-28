unit Compiler;
interface
uses parser, symtab, gencode, sysutils, PE, ptree, Windows;
type
  TCompiler = class
  private
    FSymtab: TSymtab;
  public
    constructor Create; 
    destructor Destroy; override;
    procedure Compile(s: string);
    property  SymTab: TSymTab read FSymtab; 
  end;

implementation

procedure TCompiler.Compile(s: string);
var
  p: TParser;
  g: TGenerator;
  t: TParseTree;
  value: longint;
  f: pchar;
  Code, Data:pointer;
  Dsize, csize, epoint: integer;
begin
  p:= TParser.Create;
  try
    p.Symtab:= FSymtab;
    t:= p.Parse(s);
  finally
    p.Free;
  end;
  g:= TGenerator.Create;
  try
    g.Symtab:= FSymtab; 
    g.Compile(t.Root);
    code:= g.GetCode(csize, dsize, data, epoint);
  finally
   t.Free;
   g.Free;
  end;  
  try
    GenFile('prog.exe', code, data, csize, dsize, epoint, FSymtab.ImportList);
  finally
    if code <> nil then  FreeMem(code, csize);
    if (data <> nil) and (dsize>0) then FreeMem(data, dsize); 
  end;
end;

constructor TCompiler.Create;
begin
  FSymtab:= TSymtab.Create;
end;

destructor TCompiler.Destroy;
begin
  inherited Destroy;
  FSymtab.Free;
end;


end.