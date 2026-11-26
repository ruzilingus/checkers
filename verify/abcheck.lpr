program abcheck;

{ Проверка альфа-беты: на случайных позициях сравнивает с полным перебором лучшую оценку
  и набор равных лучших ходов (из него компьютер выбирает ход случайно).
  Запуск: abcheck <число позиций> <макс. уровень> [зерно] }

{$mode delphi}{$H+}

uses
  SysUtils, Engine, TestKit;

var
  Total, MaxLv, c, Side, Lv, i, n1, n2, BestF, BestA, Bad: Integer;
  Saved: TBoard;
  CandF: array[1..ListCap] of Boolean;
  Same: Boolean;
begin
  Total := StrToInt(ParamStr(1));
  MaxLv := StrToInt(ParamStr(2));
  Seed := 1;
  if ParamCount > 2 then
    Seed := StrToInt(ParamStr(3));
  Bad := 0;
  for c := 1 to Total do
  begin
    RandomBoard(8, False);
    Side := Rnd(2) + 1;
    Lv := Rnd(MaxLv) + 1;
    Poddavki := Rnd(4) = 0;
    WhiteLevel := Lv;
    BlackLevel := Lv;
    Saved := Board;
    BestF := FullSearch(Side, Lv);
    n1 := RootCount(Side, Lv);
    for i := 1 to n1 do
      CandF[i] := RootValues[Side][i] = BestF;
    Board := Saved;
    BestA := Search(Side, Lv);
    n2 := RootCount(Side, Lv);
    Same := (BestA = BestF) and (n1 = n2);
    if Same then
      for i := 1 to n1 do
        if CandF[i] <> (RootValues[Side][i] = BestA) then
          Same := False;
    if not Same then
    begin
      Inc(Bad);
      WriteLn('MISMATCH case ', c, ': side ', Side, ' level ', Lv, ' poddavki ', Ord(Poddavki),
        ' full ', BestF, ' ab ', BestA, ' moves ', n1, '/', n2);
    end;
  end;
  WriteLn('checked ', Total, ' positions, mismatches: ', Bad);
end.
