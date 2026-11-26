unit TestKit;

{ Общее для проверок regress и abcheck: случайные позиции. }

{$mode delphi}{$H+}
{$Q-}{$R-}

interface

uses
  Engine;

var
  Seed: LongWord;  // зерно Rnd: каждая проверка ставит своё

function Rnd(N: Integer): Integer;
procedure RandomBoard(MaxPieces: Integer; Weird: Boolean);

implementation

{ Случайное число от 0 до N - 1: свой ряд, не зависит от DRandom движка. }
function Rnd(N: Integer): Integer;
begin
  Seed := Seed * 1103515245 + 12345;
  Result := Integer((Seed shr 8) mod LongWord(N));
end;

{ Случайная позиция на Board: от одной до MaxPieces фигур у каждой стороны, треть — дамки,
  шашек на горизонтали превращения нет; Weird — ещё одна-три клетки со значениями -1 и 10. }
procedure RandomBoard(MaxPieces: Integer; Weird: Boolean);
var
  DX, DY: array[1..32] of Integer;
  n, i, j, k, Side, Cnt, t, tx, ty: Integer;
begin
  n := 0;
  for j := 1 to 8 do
    for i := 1 to 8 do
    begin
      Board[i, j] := 0;
      if (i + j) mod 2 = 0 then
      begin
        Inc(n);
        DX[n] := i;
        DY[n] := j;
      end;
    end;
  for i := 32 downto 2 do
  begin
    k := Rnd(i) + 1;
    tx := DX[i];
    ty := DY[i];
    DX[i] := DX[k];
    DY[i] := DY[k];
    DX[k] := tx;
    DY[k] := ty;
  end;
  t := 1;
  for Side := 1 to 2 do
  begin
    Cnt := Rnd(MaxPieces) + 1;
    for k := 1 to Cnt do
    begin
      i := DX[t];
      j := DY[t];
      Inc(t);
      if (Rnd(10) < 3) or ((Side = 1) and (j = 8)) or ((Side = 2) and (j = 1)) then
        Board[i, j] := Side + 10
      else
        Board[i, j] := Side;
    end;
  end;
  if Weird then
    for k := 1 to Rnd(3) + 1 do
    begin
      if Rnd(2) = 0 then
        Board[DX[t], DY[t]] := -1
      else
        Board[DX[t], DY[t]] := 10;
      Inc(t);
    end;
end;

end.
