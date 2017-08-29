unit gencode;
interface
uses SysUtils, Symtab, Parser, scanner, ptree, PE;

type
  PLabel = ^TLabel;
  TLabel = record
    instr: integer;
    target: integer;
    ltype: integer;
  end;
  PLabelArray = ^TLabelArray;
  TLabelArray = array[0..0] of TLabel;

  TGeneratedCode = record 
    CodeSize: integer;
    DataSize: integer;
    Data: pointer;
    EnterPoint: integer;
    CodePtr: pointer;
  end;

  TGenerator = class
  private
    FCode: PChar;
    FCodePtr: integer;
    FCodeSize: integer;
    FSymtab: TSymtab;
    FSizeOfData: longint;
    FEnterPoint: longint;
    FLabelStack: PLabelArray;
    FLastLabel: integer;
    Strings : PNode;
    {чтение/запись кода}
    procedure WriteByte(value: integer);
    procedure WriteWord(w: word);
    procedure WriteInteger(value: integer);
    function ReadByteAt(index:integer):integer;
    function ReadWordAt(index:integer):integer;
    function ReadIntegerAt(index:integer):integer;
    procedure WriteByteAt(index, value: integer);
    procedure WriteWordAt(index: integer; w: word);
    procedure WriteIntegerAt(index: integer; value: integer);
    procedure WriteWordInstr(w: Word);
    procedure AllocStrConst(node: PNode);

    procedure CompileExpr(root: PNode);
    procedure CompileIf(node:PNode);
    procedure CompileStatList(root: PNode);
    procedure MoveToReg(reg, value: integer);
    procedure VarToReg(sym: PSymbol; reg:integer); 
    procedure VarAddr(sym: PSymbol; reg: integer);
    procedure Prolog(size: integer);
    procedure Epilog(size: integer);
    procedure FuncDef(func: PNode);  
    procedure CompileBlock(block: PNode);
    procedure VarDef(vars: PNode);
    procedure CallFunc(call: PNode);
    procedure RegToVar(sym: PSymbol; reg: integer);
    procedure StdFunc(call: PNode);
    procedure CompileRelat(node: PNode; var x :TLabel);
    procedure CompileLogic(node: PNode; var x: TLabel);
    procedure ArrayDef(arr: PSymbol);
   procedure Index(node: PNode; sym:PSymbol);

    { переходы }
    function PushLabel(ltype: integer):PLabel;
    procedure DropTop;
    procedure ReserveForwardJump(ltype: integer);
    procedure GenForwardJump(ltype: integer);
    procedure TraseLabel(ltype: integer);
    procedure GenBackJump(ltype: integer);   
    procedure BackJumpTarget(ltype: integer);
    function FindLabel(ltype: integer):PLabel;
    procedure PutJumpF(cod: integer; var loc: integer);
    procedure FixLink(target: integer);
    PROCEDURE CFJ(VAR x: TLabel; VAR loc: integer);
    PROCEDURE CBJ(VAR x: TLabel; loc: integer);
    PROCEDURE PutJumpB(target: integer);
    PROCEDURE PutBackJump(cod: INTEGER; loc: integer);

   procedure MoveRegReg(fromReg, toReg:integer);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Compile(root: Pnode);
  function GetCode(var code: TGeneratedCode):pointer;
    property Symtab: TSymtab read FSymtab write FSymtab;
  end;  
var
  STaticVArs : pointer;
  stVar1: integer = 0;
  stVar2: integer = 0;
  stVar3: integer = 0;
  stVar4: longint = 0;

const
  LabelStackSize = 512;

(* оператор 
  IF условие THEN операторы
  [ELSIF условие THEN операторы ]
  [ELSE операторы ]
  END
root := left, right 
        left:= tvIf
        right:= tvElse (операторы)
;
tvIf:= список вида :
        left:= условие
        right:= операторы 
        link := след. узел tvIf

WHILE условие DO операторы END
        left = условие
        right = операторы
REPEAT операторы UNTIL услоивие
        лево = условие
        право = операторы 
*)


implementation


const//коды регистров
  EAX = 0;  ECX = 1;  EDX = 2;  EBX = 3;
  EBP = 5;  ESP = 4;  ESI = 6;  EDI = 7;
  PushReg = $50;
  PopReg = $58;

  SetCC: array [tvGt..tvLt] of word  = (
    $0F94,  $0F9F, $0F9D,  $0F9C, $0F9E, $0F95
  );

  JmpShort : array[tvGt..tvLT] of byte =
   ( $7F, $7D, $75, $74, $7E, $7C );

  JmpNear : array [tvGt..tvLt] of word = (
   $0F8F,  $0F8D, $0F85, $0F84, $0F8E, $0F8C
  );

  jumpShort = $EB;
  JumpNear = $E9;

(*      $0800 + cc * $100
        eql = 9; neq = 10; lss = 11; leq = 12; gtr = 13; geq = 14; 
*)

  offs8EBP : array [EAX..EDI] of byte = 
    ( $45, $4D, $55, $5D, $65, $6D, $75, $7D);   

  RET = $C3;
  CallNearOffset = $E8; 

  InverseJumpNear :array [tvGT..tvLt] of word = (
    $0F8E, $0F8C, $0F84, $0F85, $0F8F, $0F8D     
  );
  
 InverseJumpShort: array[tvGt..tvLt] of byte = (
   $7E, $7C, $74, $75, $7F, $7D
 );

  modeAbs = 0;
  modeOffs8 = 64;
  modeOffs32 = 128;
  modeRegReg = 128 + 64;

function ModRM(mode, reg1, reg2:integer):integer;
begin
  result:=  reg2 or (reg1 shl 3) or mode; 
end;

constructor TGenerator.Create;
begin
  FCode:= nil;
  FCodeSize:= 0;
  GetMem(FLabelStack, LabelStackSize * sizeof(TLabel));
  FLastLabel:=0;
end;

destructor TGenerator.Destroy;
begin
  if FCode <> nil then
    FreeMem(FCode, 2048);
  FreeMem(FLabelStack, LabelStackSize* sizeof(TLabel));
  inherited Destroy;
end;


{ =================== ПЕРЕХОДЫ ===========================================}
const
  ltBreak =1;
  ltContinue = 2;
  ltReturn = 3;
  ltEndIf = 4;  //конец оператора IF
  ltElse = 5; //переход на ELSE
  ltThen = 6;//конец блока Then (обход ELSE) 

//поместить метку на стек
function TGenerator.PushLabel(ltype: integer):PLabel;
begin
  if FLastLabel = LabelStackSize then 
     raise Exception.Create('stack jump overflow');
  result:= @FLabelStack^[FLastLabel];
  result^.ltype:= ltype;
  inc(FLastLabel);
end; 

//резервироть переход вперед
procedure TGenerator.ReserveForwardJump(ltype: integer);
var
  jmp: PLabel;
begin
  jmp:= PushLabel(ltype);       //положить метку на стек
  jmp^.instr:= FCodePtr;        //адрес инструкции перехода
  WriteInteger(-1);             //записать в поле смещения -1
end;

//очередной переход вперед по тому же адресу, что и первый
procedure TGenerator.GenForwardJump(ltype: integer);
var
  lab: PLabel;
  adr: longint;
begin
  lab:= FindLabel(ltype); //найти метку нужного типа
  if lab = nil then exit;
  adr:= lab^.instr;  //адрес предыдущей инструкции перехода
  lab^.instr:= FCodePtr; //текущий адрес
  WriteInteger(adr); // указатель на предыдущую инструкцию перехода
end;

//поместить в стек цель перехода назад
procedure TGenerator.BackJumpTarget(ltype:integer);
var
  lab: PLabel;
begin
  lab:= PushLabel(ltype);
  lab^.target:= FCodePtr;
  lab^.instr:= -1;
end;

//переход назад по адресу в стеке
procedure TGenerator.GenBackJump(ltype: integer);
var
 lab:PLabel;
begin
  lab:= FindLabel(ltype);
  if lab = nil then exit;
  WriteInteger(-(FCodePtr - lab^.target +4) ) ;
end;

//сбросить верхнюю метку
procedure TGenerator.DropTop;
begin
  dec(FLastLabel);
end;

//найти метку заданного типа начиная с верхней
function TGenerator.FindLabel(ltype: integer):PLabel;
var
  i:integer;
begin
  result:= nil;
  for i:= FLastLabel-1 downto 0 do begin
    if FLabelStack^[i].ltype = ltype then begin
      result:= @FLabelStack^[i];
      break;
    end;
  end;
end;

//пройтись по списку меток 
//генерить смещения для переходов вперед
procedure TGenerator.TraseLabel(ltype: integer);
var
  lab:PLabel;
  target, i:longint;
begin
  lab:= FindLabel(ltype); 
  if lab = nil then exit;
  target:= lab^.instr;   //начальный адрес
  while target >= 0 do begin   //пройти по списку
    i:= target; 
    target:= ReadIntegerAt(i); //следующая метка
    WriteIntegerAt(i, (FCodePtr - i - 4));  //писать смещение
  end;
end;

procedure TGenerator.WriteByte(value: integer);
begin                     
  FCode[FCodePtr]:= chr(value); inc(FCodePtr);
end;

procedure TGenerator.WriteWord(w: word);
begin
  FCode[FCodePtr]:= chr(w and $00FF); inc(FCodePtr);
  FCode[FCodePtr]:= chr((w and $FF00) shr 8); inc(FCodePtr);
end;

procedure TGenerator.WriteInteger(value: integer);
begin
  FCode[FCodePtr]:= chr(value and $000000FF); inc(FCodePtr);
  FCode[FCodePtr]:= chr((value and $0000FF00) shr 8); inc(FCodePtr);
  FCode[FCodePtr]:= chr((value and  $00FF0000) shr 16); inc(FCodePtr);
  FCode[FCodePtr]:= chr((value and $FF000000) shr 24); inc(FCodePtr);
end;

 function TGenerator.ReadByteAt(index:integer):integer;
 begin
   result:= ord(FCode[index]);
 end;

 function TGenerator.ReadWordAt(index:integer):integer;
 begin
   result:= byte(FCode[index]) or byte(FCode[index+1]) shl 8;
 end;

 function TGenerator.ReadIntegerAt(index:integer):integer;
 begin
   result:= byte(FCode[index]) or byte(FCode[index+1]) shl 8
     or byte(FCode[index+2]) shl 16 or byte(FCode[index+3]) shl 24;
 end;

procedure TGenerator.WriteByteAt(index, value: integer);
begin
  FCode[index]:= chr(value);
end;

procedure TGenerator.WriteWordAt(index: integer; w: word);
begin
  FCode[index]:= chr(w and $00FF); inc(index);
  FCode[index]:= chr((w and $FF00) shr 8);
end;

procedure TGenerator.WriteIntegerAt(index:integer; value: integer);
begin
  FCode[index]:= chr(value and $000000FF); inc(index);
  FCode[index]:= chr((value and $0000FF00) shr 8); inc(index);
  FCode[index]:= chr((value and  $00FF0000) shr 16); inc(index);
  FCode[index]:= chr((value and $FF000000) shr 24); 
end;

procedure TGenerator.MoveToReg(reg, value: integer);
begin
  WriteByte($B8+reg);   //Move
  WriteInteger(value);
end;

const
  EBXOffs : array[EAX..EDI]of byte = ( $83, $8B, $93, $9B, $A3, $AB, $B3, $BB);

(* пересылка переменной в регистр *)
procedure TGenerator.VarToReg(sym : PSymbol; reg:integer);
begin
  if sym^.tip^.size = 4 then WriteByte($8B)
  else if sym.tip.size = 2 then
    begin WriteByte($66); WriteByte($8B); end
  else if sym^.tip^.size = 1 then begin
    WriteByte($33); WriteByte(ModRM(modeRegReg, EAX, EAX)); //xor EAX, EAX
    Writebyte($8A);
  end;
  VarAddr(sym, reg);
end;

(* пересылка регистра в переменную памяти *)
procedure TGenerator.RegToVar(sym: PSymbol; reg: integer);
begin
  if sym^.tip.size = 4 then WriteByte($89)
  else if sym^.tip.size = 2 then begin
    WriteByte($66);
    WriteByte($89);
  end
  else if sym.tip.size = 1 then begin
     WriteByte($88); //byte reg->r/m
  end;
  VarAddr(sym, reg);
end;

function RegToReg(fromReg, toReg:integer):byte;
begin
  result:= fromReg or (toReg shl 3) or $C0;
end;

procedure TGenerator.MoveRegReg(fromReg, toReg:integer);
begin
  WriteByte($8B); // MOV
  WriteByte(fromReg or (toReg shl 3) or $C0);
end;


const
  Offs32 :array [EAX..EDI] of byte = (
    $05, $0D, $15, $1D, $25, $2D, $35, $3D); 

(* получить адрес переменной *)
procedure TGenerator.VarAddr(sym: PSymbol; reg: integer);
begin
  if sym^.mode = ModeLocalVar then begin
    WriteByte(offs8EBP[reg]);
    WriteByte(-sym^.adr);
  end
  else if sym^.mode = ModeFormalParametr then begin
    WriteByte(offs8EBP[reg]);
    WriteByte(sym^.adr);
  end
  else if sym^.mode = ModeGlobalVar then begin
    //write(reg,' : '); writeln(IntToHex(sym^.adr,2));
    WriteByte(Offs32[reg]);
    WriteInteger(sym^.adr);
  end;
end;


(* стандартные процедуры (inc, dec) *)
procedure TGenerator.StdFunc(call: PNode);
var
  func: PSymbol;
  num: integer;
begin
  if call = nil then exit;
  with call^ do begin
    num:= sym^.adr;
    case num of
      incfn : begin
        if right <> nil then CompileExpr(right);
        WriteByte($FF); VarAddr(left^.sym, 0);     
      end;
      decfn: begin
        if right <> nil then CompileExpr(right);
        WriteByte($FF); VarAddr(left^.sym, 1);
      end;
    end;
  end;
end;

 //переворачивает список 
procedure InverseList(var head: PNode);
var
   next, prev, tmp: PNode;
begin
  if head = nil then exit;
  next:= head^.link; head^.link:= nil; prev:= head;
  while next <> nil do begin
    tmp:= next^.link;  
    next^.link:= prev;  prev:= next;  next:= tmp;
  end;
  head:= prev;
end;

function GetLast(head: PSymbol):PSymbol;
begin
  result:= nil;
  if head = nil then exit;
  while head^.link <> nil do begin
     head:= head^.link;
  end;
  result:= head;
end;

(* вызов функции *)
procedure TGenerator.CallFunc(call:PNode);
var
  arg: PNode;
  addr: longint;
  sym, fun:PSymbol;
begin
  if call = nil then exit;
  fun:= call^.sym; 
  if fun^.mode = ModeStandProc then begin
    StdFunc(call);
    exit;
  end;
  arg:= call^.left;
  InverseList(arg);
  sym:=GetLast(fun^.fpar);  
  while arg <> nil do begin
    CompileExpr(arg);
    if (fun.mode <> ModeApiFunc) then begin
      if (sym^.tip^.size = 1) then begin
        WriteByte($66); WriteByte($50 + EAX); //PUSH AX
        WriteByte($40+ESP); //DEC ESP
      end
      else if (sym.tip.size = 2) then begin
        WriteByte($66); WriteByte($50 + EAX); //PUSH AX
      end
      else WriteByte($50 + EAX); //PUSH EAX
      sym := sym^.prev;
    end
    else WriteByte($50 + EAX);
    arg:= arg^.link;
  end;
   //вызов фукнции АПИ 
  if fun^.mode = ModeApiFunc then begin
    WriteByte($FF); WriteByte($15);
    WriteInteger(fun^.adr);
    fun^.adr:= FCodePtr - 4;
    fun^.func^.CallFunc:= fun^.adr;
    exit;
  end;

  WriteByte($E8); //CallNearOffset;
  addr:= call^.sym^.adr;
  if FCodePtr > addr then addr:= addr - (FCodePtr + 4)
  else addr:= addr - FCodePtr - 4;
  WriteInteger(addr); //адрес
end;
                          
{* обработка индексов в массиве }
{procedure TGenerator.Index(node: PNode; sym:PSymbol);
var
  tmp: PNode;
begin
  if node = nil then exit; tmp:= node;
   //вычислить индексное выражение
  //while tmp <> nil do begin
    CompileExpr(tmp);
    tmp:= tmp^.link;
  //end;
    WriteByte($C1); WriteByte($E0);  WriteByte(2); //shl eax, 2
    MoveToReg(EDX, sym^.adr); //mov edx, sym^.addr
    WriteByte($03); WriteByte(ModRM(ModeRegReg, EAX, EDX));//add eax, edx
end;}

procedure TGenerator.Index(node: PNode; sym:PSymbol);
var
  tmp: PNode;
  t: PTypeDesc;
begin
  if node = nil then exit; tmp:= node; t:= sym^.tip;
   //вычислить индексное выражение
  MoveToReg(EDX, 0); //EDX = 0;
  while tmp <> nil do begin
    CompileExpr(tmp);
    if t.link <> nil then begin
      // IMUL EAX, t.link.size
      WriteByte($69); WriteByte($C0); WriteInteger(t.link.Size);
      {MoveToReg(ECX, t.link.Size);
      WriteByte($0F); WriteByte($AF); Writebyte(ModRM(ModeRegReg, ECX, EAX));}
      //ADD EDX, EAX
      WriteByte($03); WriteByte(ModRM(ModeRegReg, EDX, EAX));
    end;
    tmp:= tmp^.link; t:= t.link;
  end;
  case sym.tip.BaseType.Size of
    2: begin
       WriteByte($C1); WriteByte($E0);  WriteByte(1); //shl eax, 1
    end;
    4: begin
      WriteByte($C1); WriteByte($E0);  WriteByte(2); //shl eax, 2
    end;
  end;
  //ADD EDX, EAX
  WriteByte($03); WriteByte(ModRM(ModeRegReg, EDX, EAX));
  //WriteByte($81); WriteByte($C2); WriteInteger(sym^.adr);
  MoveToReg(EAX, sym^.adr); //mov edx, sym^.addr
  WriteByte($03); WriteByte(ModRM(ModeRegReg, EAX, EDX));//add eax, edx
end;

const
    eql = 9; neq = 10; lss = 11; leq = 12; gtr = 13; geq = 14;
InverseCompare : array[eql..geq] of integer =
    (neq, eql, geq, gtr, leq, lss);
  CmpOp : array[eql..geq] of word = (
     $0F84, $0F85,  $0F8C, $0F8E, $0F8F, $0F8D
  );


procedure TGenerator.WriteWordInstr(w: Word);
begin
  FCode[FCodePtr]:= chr((w and $FF00) shr 8); inc(FCodePtr);
  FCode[FCodePtr]:= chr(w and $00FF); inc(FCodePtr);
end;

PROCEDURE TGenerator.PutJumpF(cod: integer; var loc: integer);
{const
 CmpOp : array[eql..geq] of word = (
   $0F84, $0F85,  $0F8C, $0F8E, $0F8F, $0F8D
 );}
begin
  WriteWordInstr(CmpOp[cod]);
  WriteInteger(loc);
  loc:= FCodePtr - 4;
end;

function Inverted(cod: integer):integer;
begin
  result:= InverseCompare[cod];
end;

PROCEDURE TGenerator.CFJ(VAR x: TLabel; VAR loc: integer);
BEGIN
  PutJumpF(Inverted(x.ltype), x.instr);
  loc:=x.instr; // Fjmp         
  FixLink(x.target); // Tjmp here
END;

function isSimple(n: PNode):boolean;
begin
  result:= (n^.ntype = tvIntNum) or (n^.ntype = tvName);
end;

procedure TGenerator.CompileRelat(node: PNode; var x :TLabel);
begin
  if node^.ntype = tvName then begin
     WriteByte($8A); 
     VarAddr(node^.sym, EAX);
     WriteByte($3C); WriteByte(0);
     x.ltype := eql;
     exit;
  end;
  case node^.ntype of
    tvGt: x.ltype := gtr;
    tvGe: x.ltype := geq;
    tvNe: x.ltype := neq;
    tvEq: x.ltype := eql;
    tvLe: x.ltype := leq;
    tvLt: x.ltype := lss;
  end;
  with node^ do begin
    CompileExpr(right);
    writeByte($50); //push EAX
    CompileExpr(left);
    WriteByte($58 + EDX); // pop EDX
    WriteByte($39); WriteByte($D0); //cmp EAX, EDX
  end;
  node^.ntype:= tvSub;
  CompileExpr(node);
  x.instr:= 0;
  x.target:= 0;
end;

procedure TGenerator.FixLink(target: integer);
var
    h, d: longint;
begin
  while target <> 0 do begin
    h:=target;
    target:= ReadIntegerAt(target);
    d:= FCodePtr - h - 4;
    WriteIntegerAt(h, d)
  end;
end;

  PROCEDURE TGenerator.CBJ(VAR x: TLabel; loc: integer);
    // условный перехода назад, если Ложь
  VAR 
    L1: integer;
  BEGIN
    IF x.instr = 0 THEN
      PutBackJump(Inverted(x.ltype), loc) // Fjmp 
    ELSE begin
      L1:= 0;
      PutJumpF(x.ltype, L1);
      FixLink(x.instr);  // Fjmp here 
      PutJumpB(loc);
      FixLink(L1);
    END;
    FixLink(x.target)    // Tjmp here 
  END;

    // писать безуслоный переход назад  target = цель перехода
  PROCEDURE TGenerator.PutJumpB(target: integer);
  VAR 
    d: LONGINT;
  BEGIN 
    d := target - FCodePtr - 1;
    IF d < -128 THEN begin
      WriteByte(JumpNear); // JMP rel32  
      WriteInteger(d-4);
    end
    ELSE begin // JMP rel8  
      WriteByte(JumpShort); WriteByte(d-1);
    END
  END;

  PROCEDURE TGenerator.PutBackJump(cod: INTEGER; loc: integer);
    // писать условный переход назад
    // cc =  код условия  loc = цель перехода
  VAR 
    d: LONGINT;
  BEGIN
    d:=loc - FCodePtr - 4;
    WriteWord(CmpOp[cod]);  WriteInteger(d-4);
  END;


(* ------ компиляиця логических выражений по короткой схеме --- *)
procedure TGenerator.CompileLogic(node: PNode; var x: TLabel);

  PROCEDURE GenNot(VAR x: TLabel);
  VAR 
    h: longInt;
  BEGIN
    x.ltype := Inverted(x.ltype);
    h:= x.instr; x.instr:= x.target;  x.target := h; // exchange Tjmp and Fjmp 
  END;

  // логическое И 
  PROCEDURE condAnd(var x: TLabel);
  BEGIN
    //резервировать переход вперед по False
    PutJumpF(Inverted(x.ltype), x.instr);
    FixLink(x.target);
  END;

  PROCEDURE GenAnd(var x, y:TLabel);
  BEGIN
    //if y.instr <> 0 then  MergedLink(x.instr, y.instr);
    x.ltype:= y.ltype;
  END;

  // логическое ИЛИ 
  PROCEDURE CondOr(var x: TLabel);
  BEGIN
    PutJumpF(x.ltype, x.target); //переход по True
    FixLink(x.instr); //фиксировать переходы для операций AND
  END;

  PROCEDURE GenOr(var x, y: TLabel);
  BEGIN
    //if y.target <> 0 then MergedLink(x.target, y.target);
    x.ltype:= y.ltype;
  END;

VAR
  y: TLabel;
BEGIN
  IF node = nil THEN exit;
  with node^ do begin
    IF node^.ntype IN [tvGt..tvLt] THEN begin
      CompileRelat(node, x);
      exit;
    END
    ELSE IF ntype = tvNot THEN begin
      CompileLogic(node^.left, x);   GenNot(x);  
    end
    ELSE IF (ntype <> tvOr) AND (ntype <> tvAnd) THEN exit;
    CompileLogic(node^.left, x); //левое подвыражение
    IF ntype = tvAnd THEN CondAnd(x)  ELSE IF ntype = tvOr THEN CondOr(x);
    CompileLogic(node^.right, y);     //правое подвыражение 
    IF ntype = tvAnd THEN GenAnd(x, y) ELSE IF ntype = tvOr THEN GenOr(x, y);
  END;
END;

//компиляция выражения
PROCEDURE TGenerator.CompileExpr(root: PNode);
VAR
  src: integer;
BEGIN
  IF root = nil THEN exit;
  WITH root^ DO begin
     CASE ntype OF 
       tvName: begin  //поместить переменную в регистр
         VarToReg(sym, EAX);
       end;
       tvIntNum: begin
          MoveToReg(EAX, ConVal^.ival);  //поместить в регистр константу
       end;
       tvCallFunc: begin  
         CallFunc(root);  //вызов функции
       end; 
       tvIndex: begin
         Index(root^.right, root^.sym);         
         WriteByte($8B); WriteByte(ModRM(modeAbs, EAX, EAX));
       end;
       tvAdd, tvSub: //сложение, вычитание
         if isSimple(right) then begin
           CompileExpr(left);
           if right^.ntype = tvIntNum then begin //сложить с константой
             if ntype = tvAdd then
               WriteByte($05) //регистр += константа
             else WriteByte($2D); //EAX -= const
             WriteInteger(right^.ConVal^.ival);
           end //или сложить с переменной
           else begin
             if ntype = tvAdd then
               WriteByte($03) // ADD reg32, r/m
             else WriteByte($2B); //SUB reg32, r/m
             VarAddr(right^.sym, EAX); //адрес переменной
           end;
         end
         else if isSimple(left) then begin
           CompileExpr(right);   
           if ntype = tvAdd then begin
             if left^.ntype = tvIntNum then 
               begin WriteByte($05); WriteInteger(left^.ConVal^.ival); end 
             else begin WriteByte($03); VarAddr(left^.sym, EAX);  end; 
           end
           else begin
             if left^.ntype = tvName then 
               VarToReg(left^.sym, EDX) 
             else if left^.ntype = tvIntNum then 
               MoveToReg(EDX, left^.ConVal^.ival); 
             WriteByte($2B); WriteByte($D0); 
           end; 
         end
         else begin
           CompileExpr(right);
           writeByte($50); //push EAX
           CompileExpr(left);
           WriteByte($58 + EDX); // pop EDX
           if ntype = tvAdd then
             begin WriteByte($03); WriteByte($C2); end
           else begin WriteByte($2B); WriteByte($C2); end;
         end;
       tvDiv, tvMul, tvMod: begin
         CompileExpr(right); //множитель/делитель 
         WriteByte($50); //сохранить в стеке 

         CompileExpr(left); //умножаемое/делимое в EAX
         WriteByte($58 + ECX); //множитель в ECX
         if ntype = tvMul then begin
           WriteByte($0F); WriteByte($AF);// imul r32, r/m32
           WriteByte($C1); //EAX  ECX
         end
         else begin
           WriteByte($99); //cwq
           WriteByte($F7); WriteByte($F9); 
           if ntype = tvMod then  begin
             WriteByte($8B); WriteByte($C2); 
           end; //mov EAX, EDX
         end;
       end; 
       tvNeg: begin
        CompileExpr(left);
        WriteByte($F7); WriteByte($D8);
       end;
       tvTrue: begin
          MoveToReg(EAX, -1);
       end;
       tvFalse: begin
          MoveToReg(EAX, 0);
       end;
       tvStrConst: begin
         AllocStrConst(root);
         MoveToReg(EAX, ConVal^.dop+BASECODE + $1000); 
       end;
     end;
  end;
end;


PROCEDURE TGenerator.CompileIf(node: PNode);

  PROCEDURE GenJump(var x: integer);
  BEGIN
    WriteByte(JumpNear); 
    WriteInteger(x);
    x:= FCodePtr - 4;
  END;

VAR
  target1, target2: INTEGER;
  x: TLabel;
  tmp: PNode;
BEGIN
  target2:= 0;
  tmp:= node^.left;
  WHILE tmp <> nil DO begin
    WITH tmp^ DO begin
      CompileLogic(left, x);
      CFJ(x, target1);
      CompileStatList(right);
      IF (node^.right <> nil) OR (link <> nil) THEN 
        GenJump(target2);  //резервировать обход else
      FixLink(target1);
    END;
    tmp:= tmp^.link;
  END;
  IF node^.right <> nil THEN 
    CompileStatList(node^.right);  
  FixLink(target2);
END;

procedure TGenerator.CompileStatList(root: PNode);
var
  target, beg: integer;
  x: TLabel;
begin
  while root <> nil do begin
  with root^ do begin
    case ntype of
      tvCallFunc: begin
        CallFunc(root);
      end;
      tvAssign: begin
        CompileExpr(right);
        if left <> nil then begin //присваивание элементу массива
          WriteByte(PushReg+EAX);
          Index(left, sym);
          WriteByte(PopReg+EDX);          
          WriteByte($89); WriteByte(ModRM(ModeAbs, EDX, EAX));
        end 
        else RegToVar(sym, EAX);//Mov name, EAX
      end;
      tvIfElse : CompileIf(root);
      tvRepeat: begin
        target:= FCodePtr;
        CompileStatList(right);
        CompileLogic(left, x);
        CBJ(x, target);
      end;
      tvWhile: begin
        beg:= FCodePtr;
        CompileLogic(left, x);
        CFJ(x, target);
        CompileStatList(right);
        //безусловный переход на начало цикла
        WriteByte(jumpNear); WriteInteger(-(FCodePtr - beg + 4));
        //метка обхода тела цикла
        FixLink(target);
      end;
      tvReturn : begin
        CompileExpr(left);
        WriteByte(JumpNear);
        GenForwardJump(ltReturn);
      end;
    end; //case
  end;//with
  root:= root^.link;
  end;
end;

//вход в фукнцию
procedure TGenerator.Prolog(Size:  integer);
begin
  {WriteByte(PushReg+EBX);
  WriteByte(PushReg+ESI);
  WriteByte(PushReg+EDI);}
  //
  WriteByte($50 + EBP); //push EBP
  MoveRegReg(ESP, EBP); //EBP <- ESP
  //WriteByte($8B); WriteByte(RegToReg(ESP, EBP));   //mov EBP, ESP

  if Size > 0 then begin //выделить память для локальных
    WriteByte($81); WriteByte($EC); WriteInteger(Size); //Sub ESP, Size
  end;                                  
end;

//выход из фукнции
procedure TGenerator.Epilog(Size: integer);
begin
  WriteByte($8B); WriteByte(RegToReg(EBP, ESP));  //move ESP, EBP
  WriteByte($58 + EBP); //pop EBP
   {WriteByte(PopReg+EDI);
   WriteByte(PopReg+ESI);
   WriteByte(PopReg+EBX);}

  if Size > 0 then begin
    WriteByte($C2); WriteWord(size);   //RET;                   
  end 
  else writeByte($C3); 
  if size > 0 then begin 
    //WriteByte($81); WriteByte($C4); WriteInteger(Size); //ADD ESP, Size
  end;
end;

//компилить фукнцию
PROCEDURE TGenerator.FuncDef(func: PNode);
VAR             
  vars, formals, tmp, prev: PSymbol;
  list: PNode;
  varCount, ParamCount, offs: integer;
BEGIN
  if func = nil then exit;
  list:= func^.left; vars:= nil; formals:= nil;
  if list <> nil then begin
    formals:= list^.sym;
    if list^.ntype = tvVarDef then
      vars:= list^.sym
    else if list^.link <> nil then
      vars:= list^.link^.sym;
  end;

  tmp:= formals; {offs:= 20;} offs:= 8; //адрес возврата + сохраненный EBP
  ParamCount:= 0;
  while tmp <> nil do begin               //для формальных параметров
    tmp^.adr:= offs; // [EBP + offs]
    inc(offs, tmp.tip.size);
    tmp:=tmp^.link;
    inc(ParamCount);
    //inc(offs, sizeof(integer)); //смещение следующего параметра в стеке
  end;
    //для локальных переменных
  tmp:= vars;  offs:= 4;  VarCount:=0;
  while tmp <> nil do begin
    tmp^.adr:= offs; //[EBP - offs]
    //inc(offs, tmp.tip.size);
    inc(offs, 4);
    tmp:= tmp^.link;
    inc(VarCount);
  end;
  func^.sym^.adr:= FCodePtr;

 {компиляция тела функции}
  with PushLabel(ltReturn)^ do begin
   instr:= -1;
   target:= -1;
  end;
  Prolog(VarCount*4);     //пролог
  CompileStatList(func^.right);
  TraseLabel(ltReturn);
  DropTop;
  Epilog(ParamCount*4);   //эпилог
END;

(* объявление переменной: определяет адрес глобальной переменной *)

procedure TGenerator.AllocStrConst(node: PNode);
begin
  node^.link:= strings; strings:= node;
  node^.ConVal^.dop:= FSizeOfData;
  inc(FSizeOfData, node^.ConVal^.ival+1);
end;
                
procedure TGenerator.VarDef(vars: PNode);
var
  v:PSymbol;
begin
  v:= vars^.sym;
  while v <> nil do begin
    V.Adr := FSizeOfData + BASECODE + $1000;
    if v = nil then raise Exception.Create('fuck!');
    inc(FSizeOfData, v^.tip^.size);
    v:= v^.link;
  end;
end;

(* определение массива *)
PROCEDURE TGenerator.ArrayDef(arr: PSymbol);
VAR
  size: integer;
  t:PTypeDesc;
BEGIN
  //текущий адрес - размер данных + Основание образа + 1000h
  arr^.adr:= FSizeOfData+BASECODE+$1000;
{  //размер массива size:= arr^.tip^.size * arr^.tip^.BaseType^.size;}
  t:= arr.tip; size:=t.size;
  while t <> nil do begin  
    if t.link <> nil then size:= size*t.link.size
    else size:= size * t.baseType.size;
    t:=t.link;  
  end;
  inc(FSizeOfData, size);
END;

PROCEDURE TGenerator.CompileBlock(block: PNode);
var 
  s: PSymbol; i:integer;
BEGIN
  WHILE block <> nil DO begin
    if block^.ntype = tvVarDef then VarDef(block)
    else if block^.ntype = tvDefun then begin  
      FuncDef(block); 
    end
    else if block^.ntype = tvArray then begin
      ArrayDef(block^.sym); 
    end
    else if block^.ntype = tvRecord then begin
      i:=0; s:= block^.sym^.fpar; 
      while s <> nil do begin
        inc(i, s^.tip^.size); s:= s^.link; 
      end;
      block^.sym^.tip^.size:= i;
    end
    else if block^.ntype = tvBegin then begin
      FEnterPoint:= FCodePtr; 
      CompileStatList(block^.left);
    end;
    block:= block^.link;
  end;
end;

procedure TGenerator.Compile(root:PNode);
begin
  FSizeOfData:= 0;
  GetMem(FCode, 4096);
  strings:= nil;
  CompileBlock(root);
end;

//record
//CodeSize: integer;
//DataSize: integer;
//Data: pointer;
//Enter: integer;
//CodePtr: pointer
function TGenerator.GetCode(
  var code: TGeneratedCode):pointer;
begin
  code.DataSize:= FSizeOfData;
  if FSizeOfData > 0 then
    GetMem(code.Data, FSizeOfData);
  while Strings<> nil do begin
    with Strings^.ConVal^ do
      System.Move(str^, (pchar(code.Data)+dop)^, ival+1);
    Strings:= Strings^.link;
  end;
  StaticVars:= code.Data;
  //code
  GetMem(result, FCodePtr);
  System.Move(FCode^, result^, FCodePtr);
  code.CodeSize:= FCodePtr;
  code.EnterPoint:= FEnterPoint;
  code.CodePtr := result;
end;

end.

