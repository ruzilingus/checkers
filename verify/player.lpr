program player;

{ Игрок для матча движков: читает команды из stdin, отвечает в stdout строкой.
  move <сторона> <уровень> <зерно> <доска> — ход компьютера, как ComputerMove в Unit1
    (перебор, равные лучшие, случайный среди них по зерну): «<доска после> <мс>» или «none <мс>»;
  rand <сторона> <зерно> <доска> — случайный разрешённый ход (взятие обязательно): «<доска>» или «none»;
  list <сторона> <доска> — все разрешённые ходы с полями пути через пробел, поле — две цифры
    (вертикаль, горизонталь), поля хода через «-»: «33-44 33-24» или «33-55-37»; нет ходов — пусто.
  Доска — 32 символа .wbWB, горизонтали 1..8, в каждой тёмные поля слева направо. }

{$mode delphi}{$H+}
{$Q-}{$R-}

uses
  Windows, SysUtils, Engine;

var
  Freq: Int64;

{ Ход компьютера; False — ходить нечем. }
function EngineMove(Side, Lv: Integer): Boolean;
var
  Saved: TBoard;
  Best: Integer;
begin
  WhiteLevel := Lv;
  BlackLevel := Lv;
  Poddavki := 0;
  StopSearch := False;
  Saved := Board;
  Best := Search(Side, Lv);
  Board := Saved;
  CaptureMoves(Side, CapCnt[Side], CapList[Side]);
  if CapCnt[Side] = 0 then
  begin
    SimpleMoves(Side, SimCnt[Side], SimList[Side]);
    if SimCnt[Side] = 0 then
      Exit(False);
    ApplySimple(Side, SimList[Side][PickRootMove(Side, SimCnt[Side], Best)]);
  end
  else
    ApplyCapture(Side, CapList[Side][PickRootMove(Side, CapCnt[Side], Best)]);
  Result := True;
end;

function RandomMove(Side: Integer): Boolean;
begin
  CaptureMoves(Side, CapCnt[Side], CapList[Side]);
  if CapCnt[Side] > 0 then
    ApplyCapture(Side, CapList[Side][DRandom(CapCnt[Side]) + 1])
  else
  begin
    SimpleMoves(Side, SimCnt[Side], SimList[Side]);
    if SimCnt[Side] = 0 then
      Exit(False);
    ApplySimple(Side, SimList[Side][DRandom(SimCnt[Side]) + 1]);
  end;
  Result := True;
end;

{ Разрешённые ходы стороны в порядке генерации, см. команду list. }
function ListMoves(Side: Integer): string;
var
  i, t: Integer;
begin
  Result := '';
  CaptureMoves(Side, CapCnt[Side], CapList[Side]);
  if CapCnt[Side] > 0 then
    for i := 1 to CapCnt[Side] do
      with CapList[Side][i] do
      begin
        if Result <> '' then
          Result := Result + ' ';
        Result := Result + IntToStr(Path[0].X) + IntToStr(Path[0].Y);
        for t := 1 to Len do
          Result := Result + '-' + IntToStr(Path[t].X) + IntToStr(Path[t].Y);
      end
  else
  begin
    SimpleMoves(Side, SimCnt[Side], SimList[Side]);
    for i := 1 to SimCnt[Side] do
      with SimList[Side][i] do
      begin
        if Result <> '' then
          Result := Result + ' ';
        Result := Result + IntToStr(FX) + IntToStr(FY) + '-' + IntToStr(TX) + IntToStr(TY);
      end;
  end;
end;

var
  Line: string;
  P: TStringArray;
  T0, T1: Int64;
  Ok: Boolean;
begin
  QueryPerformanceFrequency(Freq);
  SearchIdle := nil;
  while not EOF(Input) do
  begin
    ReadLn(Line);
    P := Line.Split([' ']);
    if (Length(P) >= 5) and (P[0] = 'move') then
    begin
      DRandSeed := StrToInt64(P[3]);
      TextToBoard(P[4], Board);
      QueryPerformanceCounter(T0);
      Ok := EngineMove(StrToInt(P[1]), StrToInt(P[2]));
      QueryPerformanceCounter(T1);
      if Ok then
        WriteLn(BoardToText(Board), ' ', ((T1 - T0) * 1000 div Freq))
      else
        WriteLn('none ', ((T1 - T0) * 1000 div Freq));
    end
    else if (Length(P) >= 4) and (P[0] = 'rand') then
    begin
      DRandSeed := StrToInt64(P[2]);
      TextToBoard(P[3], Board);
      if RandomMove(StrToInt(P[1])) then
        WriteLn(BoardToText(Board))
      else
        WriteLn('none');
    end
    else if (Length(P) >= 3) and (P[0] = 'list') then
    begin
      TextToBoard(P[2], Board);
      WriteLn(ListMoves(StrToInt(P[1])));
    end
    else
      WriteLn('error');
    Flush(Output);
  end;
end.
