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
    function ParseTree(sourceCode:string):TParseTree;
    procedure Use(code: TGeneratedCode);
    property  SymTab: TSymTab read FSymtab;
  end;

implementation

function TCompiler.ParseTree(sourceCode:string):TParseTree;
var
  parser: TParser;
  tree: TParseTree;
begin
    //create parser
  parser:= TParser.Create;
  try
    //create symbol table
    parser.Symtab:= FSymtab;
    try
        //parse text and get Abstract Syntax Tree
      tree:= parser.Parse(sourceCode);
    except
     on E:Exception do
      begin
          MessageBox(0, pchar('Error in parsing programm text!'+E.Message),'',mb_ok);
          raise;
      end
    end
  finally
    parser.Free;
    writeln('syntactic analysis done. Syntaxtic Tree created');
  end;
  result := tree;
end;

procedure TCompiler.Compile(s: string);
var
  g: TGenerator;
  tree: TParseTree;
  value: longint;
  f: pchar;
  generatedCode : TGeneratedCode;
begin
   //create parser
   tree := ParseTree(s);

  //then generation code
  writeln('try generated code');
  g:= TGenerator.Create;
  try
    //we simple copy what? object symtab? class symtabl?
    //oh, what stupid solution
    g.Symtab:= FSymtab;
    //compile syntax tree
    writeln('try compile syntactic tree');
    g.Compile(tree.Root);
    //get code
    writeln('get done code');
    g.GetCode(generatedCode);
  finally
   tree.Free;
   g.Free;
  end;
  Use(generatedCode);
end;



procedure TCompiler.Use(code: TGeneratedCode);
type
  shit =  function: integer;
var
 f : integer;
 tmp: PByte;
begin
{  try
    tmp := code.CodePtr;
    INC(tmp, code.EnterPoint);
    f :=  shit(tmp)();
  except
    on E:Exception do
    begin
      MessageBox(0, pchar(' ' +E.Message), '', mb_ok);
      raise
    end
  end;

  writeln(inttostr(f));
  }

  try
    GenFile('prog.exe', code.CodePtr, code.data, code.CodeSize, code.DataSize, code.EnterPoint, FSymtab.ImportList);
  finally
    if code.CodePtr <> nil then  FreeMem(code.CodePtr, code.CodeSize);
    if (code.data <> nil) and (code.DataSize>0) then FreeMem(code.data, code.DataSize);
    if (code.CodePtr = nil) then writeln('code is nil');
    if (code.data = nil) then writeln('data is nil');
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