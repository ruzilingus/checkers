program engtest;

{ Сверка движка с оригиналом: читает позиции из stdin, печатает результат перебора и оценки
  ходов корня. Строка ввода: сторона глубина поддавки доска(32 символа: .wbWB, горизонтали
  1..8, в каждой тёмные поля слева направо). }

{$mode delphi}{$H+}

uses
  SysUtils, Engine;

var
  Line, S: string;
  Side, Depth, Pod, i, j, k, n, R: Integer;
  Parts: TStringArray;
begin
  while not EOF(Input) do
  begin
    ReadLn(Line);
    Parts := Line.Split([' ']);
    if Length(Parts) < 4 then
      Continue;
    Side := StrToInt(Parts[0]);
    Depth := StrToInt(Parts[1]);
    Pod := StrToInt(Parts[2]);
    S := Parts[3];
    k := 1;
    for j := 1 to 8 do
      for i := 1 to 8 do
      begin
        Board[i, j] := 0;
        if (i + j) mod 2 = 0 then
        begin
          case S[k] of
            'w': Board[i, j] := 1;
            'b': Board[i, j] := 2;
            'W': Board[i, j] := 11;
            'B': Board[i, j] := 12;
          end;
          Inc(k);
        end;
      end;
    Poddavki := Pod;
    if (Length(Parts) > 4) and (Parts[4] = 'caps') then
    begin
      CaptureMoves(Side, n, CapList(Side)^);
      WriteLn('captures: ', n);
      for i := 1 to n do
        with CapList(Side)^[i] do
        begin
          Write('  ', i, ': ');
          for k := 0 to Len do
            Write(Chr(Ord('a') + Path[k].X - 1), Path[k].Y, ' ');
          WriteLn;
        end;
      Continue;
    end;
    WhiteLevel := Depth;
    BlackLevel := Depth;
    StopSearch := False;
    R := Search(Side, Depth);
    if CapCntD(Side, Depth)^ > 0 then
      n := CapCntD(Side, Depth)^
    else
      n := SimCntD(Side, Depth)^;
    Write(R, ' ', n);
    for i := 1 to n do
      Write(' ', RootValues(Side)^[i]);
    WriteLn;
    if (Length(Parts) > 4) and (Parts[4] = 'moves') then
    begin
      for i := 1 to n do
        if CapCntD(Side, Depth)^ > 0 then
          with CapListD(Side, Depth)^[i] do
          begin
            Write('  ', i, ': ');
            for k := 0 to Len do
              Write(Chr(Ord('a') + Path[k].X - 1), Path[k].Y, ' ');
            WriteLn('= ', RootValues(Side)^[i]);
          end
        else
          with SimListD(Side, Depth)^[i] do
            WriteLn('  ', i, ': ', Chr(Ord('a') + FX - 1), FY, '-', Chr(Ord('a') + TX - 1), TY,
              ' = ', RootValues(Side)^[i]);
    end;
    Flush(Output);
  end;
end.
