program regress;

{ Сверка поведения движка с эталоном: правка, которая не должна менять игру (рефакторинг,
  ускорение), обязана дать те же хэши.
    regress              — печатает хэши набора проверок;
    regress <эталон>     — сравнивает с эталоном: OK или строки, где расходится (код выхода 1).
  Набор: сырые списки взятий на 200 000 случайных позиций — байт в байт, вместе с хвостом за
  Count (в четверти позиций ещё и посторонние значения клеток -1 и 10: генератор не должен
  на них ломаться), и оценки всех ходов корня Search на 1000 случайных позиций блоками по 100
  (с поддавками). Эталон — regress_normal.txt. Строки с # (время) не сравниваются. }

{$mode delphi}{$H+}
{$Q-}{$R-}

uses
  Windows, SysUtils, Classes, Engine, TestKit;

const
  CapPositions = 200000;
  SearchPositions = 1000;
  SearchBlock = 100;
  ModeName = 'normal';
  MaxLevel = 5;
  FnvBasis = QWord(14695981039346656037);
  FnvPrime = QWord(1099511628211);

var
  Buf: array[1..600] of TMove;
  Lines: TStringList;
  Freq: Int64;

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
    Poddavki := Rnd(4) = 0;
    WhiteLevel := Lv;
    BlackLevel := Lv;
    Best := Search(Side, Lv);
    Cnt := RootCount(Side, Lv);
    H := HashBytes(H, @Best, SizeOf(Best));
    H := HashBytes(H, @Cnt, SizeOf(Cnt));
    H := HashBytes(H, @RootValues[Side][1], SizeOf(Integer) * Cnt);
    if c mod SearchBlock = 0 then
    begin
      Lines.Add(Format('search %d..%d, levels 1-%d: hash %s',
        [c - SearchBlock + 1, c, MaxLevel, IntToHex(H, 16)]));
      H := FnvBasis;
    end;
  end;
  Poddavki := False;
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
  Seed := 7;
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
