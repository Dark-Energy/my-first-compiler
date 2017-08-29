unit FindKMP;

interface
Uses SysUtils;

var
  Buffer:pchar;
  Buflen:integer;
  patern:array[0..255]of char;
  PatLen:integer;
  FindTab:array[0..255]of SmallInt;
  WordsOnly:boolean;
  CaseIgnore:boolean;

procedure SetPatern(TextToFind:pchar; len:integer; Words, CaseIg:boolean);
function  Find(ABuffer:pchar; ABuflen:integer):integer;

implementation

var
  i, j, k:integer;
procedure MakeFindTab;
begin
  k:=-1;
  j:=0;
  FindTab[0]:=-1;
  while j<Patlen-1 do begin
    while (k>=0) and (patern[j]<>patern[k]) do
     k:=FindTab[k];
    inc(j); inc(k);
    if patern[j] =patern[k] then
      FindTab[j] :=FindTab[k]
    else FindTab[j]:=k;
  end;
end;

procedure SetPatern(TextToFind:pchar; len:integer; Words, CaseIg:boolean);
begin
  StrCopy(Patern, TextToFind);
  PatLen:=len;
  WordsOnly:=Words;
  CaseIgnore:=CaseIg;
  if CaseIgnore then
    StrUpper(Patern);
  if not Words then MakeFindTab;
end;


function FindText:integer;
begin
 result:=-1;
 i:=0;  j:=0;
 while (j<Patlen) and (i<Buflen) do begin
   while (j>=0) and (buffer[i]<>patern[j]) do
     j:=FindTab[j];
   inc(i);  inc(j);
  end;
  if j = PatLen then result:=i-PatLen;
end;

function FindCaseIgnore:integer;
var
  i,j,k:integer;
  p:pchar;
begin
  result:=-1;
  i:=0;  j:=0;
  while (j<Patlen) and (i<Buflen) do begin
    while (j>=0) and (UpCase(buffer[i])<>patern[j]) do j:=FindTab[j];
      inc(i);  inc(j);
  end;
  if j = PatLen then result:=i-PatLen;
end;

function FindWord:integer;
begin
  result:=-1;
  j:=0; i:=0;
  while (j<Patlen) and (i < buflen) do begin
    while buffer[i]<=' ' do inc(i);
    j:=0;
    while (buffer[i]=patern[j]) do begin
      inc(j); inc(i);
    end;
    if j=Patlen then
      if buffer[i]=' 'then break else j:=0;
    while buffer[i]>' ' do inc(i);
  end;
  if j=Patlen then result:=i-Patlen;
end;


function FindWordCaseIgnore:integer;
begin
  result:=-1;
  j:=0; i:=0;
  while (j<Patlen) and (i < buflen) do begin
    while buffer[i]<=' ' do inc(i);
    j:=0;
    while (UpCase(buffer[i])=patern[j]) do begin
      inc(j); inc(i);
    end;
    if j=PAtlen then
      if buffer[i]=' 'then break else j:=0;
    while buffer[i]>' ' do inc(i);
  end;
  if j=Patlen then result:=i-Patlen;
end;

function Find(abuffer:pchar; abuflen:integer):integer;
begin
  Buffer:=ABuffer;
  Buflen:=ABuflen;
  if CaseIgnore then
    if WordsOnly then
      result:=FindWordCaseIgnore
    else result:=FindCaseIgnore
  else if WordsOnly then
    result:=FindWord
  else result:=FindText;
end;

end.
