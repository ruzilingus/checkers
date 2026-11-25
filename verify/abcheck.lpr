program abcheck;

{ Проверка альфа-беты: на случайных позициях сравнивает с полным перебором лучшую оценку
  и набор равных лучших ходов (из него компьютер выбирает ход случайно).
  Запуск: abcheck <число позиций> <макс. уровень> [зерно] }

{$mode delphi}{$H+}

uses
  SysUtils, Engine;

var
  Seed: LongWord = 1;

function Rnd(N: Integer): Integer;
begin
  Seed := Seed * 1103515245 + 12345;
  Result := Integer((Seed shr 8) mod LongWord(N));
end;

procedure RandomBoard;
var
  Dark: array[1..32] of record X, Y: Integer; end;
  n, i, j, k, Side, Cnt, t: Integer;
  tmpX, tmpY: Integer;
begin
  n := 0;
  for j := 1 to 8 do
    for i := 1 to 8 do
    begin
      Board[i, j] := 0;
      if (i + j) mod 2 = 0 then
      begin
        Inc(n);
        Dark[n].X := i;
        Dark[n].Y := j;
      end;
    end;
  for i := 32 downto 2 do
  begin
    k := Rnd(i) + 1;
    tmpX := Dark[i].X;
    tmpY := Dark[i].Y;
    Dark[i] := Dark[k];
    Dark[k].X := tmpX;
    Dark[k].Y := tmpY;
  end;
  t := 1;
  for Side := 1 to 2 do
  begin
    Cnt := Rnd(8) + 1;
    for k := 1 to Cnt do
    begin
      i := Dark[t].X;
      j := Dark[t].Y;
      Inc(t);
      if (Rnd(10) < 3) or ((Side = 1) and (j = 8)) or ((Side = 2) and (j = 1)) then
        Board[i, j] := Side + 10
      else
        Board[i, j] := Side;
    end;
  end;
end;

function RootCount(Side, Depth: Integer): Integer;
begin
  if CapCntD(Side, Depth)^ > 0 then
    Result := CapCntD(Side, Depth)^
  else
    Result := SimCntD(Side, Depth)^;
end;

var
  Total, MaxLv, c, Side, Lv, i, n1, n2, BestF, BestA, Bad: Integer;
  Saved: TBoard;
  CandF: array[1..400] of Boolean;
  Same: Boolean;
begin
  Total := StrToInt(ParamStr(1));
  MaxLv := StrToInt(ParamStr(2));
  if ParamCount > 2 then
    Seed := StrToInt(ParamStr(3));
  Bad := 0;
  for c := 1 to Total do
  begin
    RandomBoard;
    Side := Rnd(2) + 1;
    Lv := Rnd(MaxLv) + 1;
    Poddavki := Ord(Rnd(4) = 0);
    WhiteLevel := Lv;
    BlackLevel := Lv;
    Saved := Board;
    BestF := FullSearch(Side, Lv);
    n1 := RootCount(Side, Lv);
    for i := 1 to n1 do
      CandF[i] := RootValues(Side)^[i] = BestF;
    Board := Saved;
    BestA := Search(Side, Lv);
    n2 := RootCount(Side, Lv);
    Same := (BestA = BestF) and (n1 = n2);
    if Same then
      for i := 1 to n1 do
        if CandF[i] <> (RootValues(Side)^[i] = BestA) then
          Same := False;
    if not Same then
    begin
      Inc(Bad);
      WriteLn('MISMATCH case ', c, ': side ', Side, ' level ', Lv, ' poddavki ', Poddavki,
        ' full ', BestF, ' ab ', BestA, ' moves ', n1, '/', n2);
    end;
  end;
  WriteLn('checked ', Total, ' positions, mismatches: ', Bad);
end.
