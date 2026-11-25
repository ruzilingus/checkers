program regress;

{ Сверка поведения движка с эталоном: правка, которая не должна менять игру (рефакторинг,
  ускорение), обязана дать те же хэши.
    regress              — печатает хэши набора проверок;
    regress <эталон>     — сравнивает с эталоном: OK или строки, где расходится (код выхода 1).
  Набор: сырые списки взятий на 200 000 случайных позиций — байт в байт, вместе с хвостом за
  Count (в четверти позиций посторонние значения клеток -1 и 10, как бывает в режиме Original),
  и оценки всех ходов корня Search на 1000 случайных позиций блоками по 100 (с поддавками).
  Обычный режим и Original (-dORIGINAL) собираются отдельно, у каждого свой эталон:
  regress_normal.txt и regress_original.txt. Строки с # (время) не сравниваются. }

{$mode delphi}{$H+}
{$Q-}{$R-}

uses
  Windows, SysUtils, Classes, Engine;

const
  CapPositions = 200000;
  SearchPositions = 1000;
  SearchBlock = 100;
{$IFDEF ORIGINAL}
  ModeName = 'original';
  MaxLevel = 3;  // полный перебор: уровень 4 в эндшпиле идёт секундами
{$ELSE}
  ModeName = 'normal';
  MaxLevel = 5;
{$ENDIF}
  FnvBasis = QWord(14695981039346656037);
  FnvPrime = QWord(1099511628211);

var
  Seed: LongWord = 7;
  Buf: array[1..600] of TMove;  // запас на переполнение списков в режиме Original
  Lines: TStringList;
  Freq: Int64;

function Rnd(N: Integer): Integer;
begin
  Seed := Seed * 1103515245 + 12345;
  Result := Integer((Seed shr 8) mod LongWord(N));
end;

function HashBytes(H: QWord; P: PByte; N: Integer): QWord;
var
  k: Integer;
begin
  for k := 0 to N - 1 do
    H := (H xor P[k]) * FnvPrime;
  Result := H;
end;

function Now_: Double;
var
  C: Int64;
begin
  QueryPerformanceCounter(C);
  Result := C / Freq;
end;

{ Случайная позиция: до MaxPieces фигур у каждой стороны, треть — дамки; Weird — ещё одна-три
  клетки со значениями -1 и 10. }
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

function RootCount(Side, Depth: Integer): Integer;
begin
  if CapCntD(Side, Depth)^ > 0 then
    Result := CapCntD(Side, Depth)^
  else
    Result := SimCntD(Side, Depth)^;
end;

procedure CheckCaptures;
var
  c, Side, Cnt, k, Total, MaxRaw: Integer;
  H: QWord;
  Saved: TBoard;
  t: Double;
begin
  t := Now_;
  H := FnvBasis;
  Total := 0;
  MaxRaw := 0;
  for c := 1 to CapPositions do
  begin
    RandomBoard(12, Rnd(4) = 0);
    Saved := Board;
    for Side := 1 to 2 do
    begin
      FillChar(Buf, SizeOf(TMove) * 100, 0);
      CaptureMoves(Side, Cnt, PMoveList(@Buf)^);
      k := 1;
      while (k <= 100) and (Buf[k].Len <> 0) do
        Inc(k);
      if k - 1 > MaxRaw then
        MaxRaw := k - 1;
      H := HashBytes(H, @Cnt, SizeOf(Cnt));
      H := HashBytes(H, @Buf[1], SizeOf(TMove) * (k - 1));
      Inc(Total, Cnt);
      if not BoardsEqual(Board, Saved) then
        H := HashBytes(H, @c, SizeOf(c));  // генератор испортил доску — хэш разойдётся
    end;
  end;
  Lines.Add(Format('caps %d positions: moves %d, max raw %d, hash %s',
    [CapPositions, Total, MaxRaw, IntToHex(H, 16)]));
  Lines.Add(Format('# caps %.1f s', [Now_ - t]));
end;

procedure CheckSearch;
var
  c, Side, Lv, Best, Cnt: Integer;
  H: QWord;
  t: Double;
begin
  t := Now_;
  H := FnvBasis;
  for c := 1 to SearchPositions do
  begin
    RandomBoard(8, False);
    Side := Rnd(2) + 1;
    Lv := Rnd(MaxLevel) + 1;
    Poddavki := Ord(Rnd(4) = 0);
    WhiteLevel := Lv;
    BlackLevel := Lv;
    Best := Search(Side, Lv);
    Cnt := RootCount(Side, Lv);
    H := HashBytes(H, @Best, SizeOf(Best));
    H := HashBytes(H, @Cnt, SizeOf(Cnt));
    H := HashBytes(H, @RootValues(Side)^[1], SizeOf(Integer) * Cnt);
    if c mod SearchBlock = 0 then
    begin
      Lines.Add(Format('search %d..%d, levels 1-%d: hash %s',
        [c - SearchBlock + 1, c, MaxLevel, IntToHex(H, 16)]));
      H := FnvBasis;
    end;
  end;
  Poddavki := 0;
  Lines.Add(Format('# search %.1f s', [Now_ - t]));
end;

function Compare(const FileName: string): Integer;
var
  Expected: TStringList;
  i, j: Integer;
begin
  Result := 0;
  Expected := TStringList.Create;
  try
    Expected.LoadFromFile(FileName);
    j := 0;
    for i := 0 to Lines.Count - 1 do
    begin
      if Lines[i].StartsWith('#') then
        Continue;
      while (j < Expected.Count) and Expected[j].StartsWith('#') do
        Inc(j);
      if (j >= Expected.Count) or (Expected[j] <> Lines[i]) then
      begin
        Inc(Result);
        WriteLn('MISMATCH: ', Lines[i]);
        if j < Expected.Count then
          WriteLn('   expect: ', Expected[j]);
      end;
      Inc(j);
    end;
  finally
    Expected.Free;
  end;
  if Result = 0 then
    WriteLn('OK: ', ModeName, ', all checks match ', FileName)
  else
    WriteLn(Result, ' mismatches against ', FileName);
end;

var
  i: Integer;
begin
  QueryPerformanceFrequency(Freq);
  SearchIdle := nil;
  Lines := TStringList.Create;
  try
    Lines.Add('mode ' + ModeName);
    CheckCaptures;
    CheckSearch;
    if ParamCount >= 1 then
    begin
      for i := 0 to Lines.Count - 1 do
        if Lines[i].StartsWith('#') then
          WriteLn(Lines[i]);
      if Compare(ParamStr(1)) > 0 then
        ExitCode := 1;
    end
    else
      for i := 0 to Lines.Count - 1 do
        WriteLn(Lines[i]);
  finally
    Lines.Free;
  end;
end.
