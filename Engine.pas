unit Engine;

{ Движок шашек: доска, генерация ходов, оценка и перебор. Без зависимостей от форм, чтобы
  его можно было проверять отдельно от окна.

  Доска — TBoard[вертикаль, горизонталь], обе от 1 до 8, поле a1 = [1, 1].
  Значения клеток: 0 — пусто, 1 — белая шашка, 11 — белая дамка, 2 — чёрная шашка,
  12 — чёрная дамка. Стороны: 1 — белые, 2 — чёрные.

  Уровень N — это перебор на N полных ходов (ход стороны и ответ соперника), то есть 2N
  полуходов: альфа-бета с таблицей транспозиций и доигрыванием взятий в листьях. Оценка —
  материал с бонусом за продвижение, подвижность, охрану тыла и центр.

  Версия, которая играет ход в ход как программа 2003 года (полный перебор вместе с двумя
  её ошибками), — в git под меткой original-2003. }

{$mode delphi}{$H+}
{$Q-}{$R-}

interface

uses
  Windows, Math;

const
  MaxDepth = 10;   // уровней перебора
  MaxJumps = 12;   // прыжков в одном взятии
  Inf = 666666666;
  { Ходов в одном списке, с большим запасом: взятия сначала записываются все, включая
    неполные серии дамки, и только потом лишние выбрасываются. }
  ListCap = 400;

type
  TBoard = array[1..8, 1..8] of Integer;

  TSq = record
    X, Y: Integer;
  end;

  { Простой ход: откуда и куда. }
  TSimpleMove = record
    FX, FY, TX, TY: Integer;
  end;

  { Взятие целиком: Path[0] — исходное поле, Path[k] и Caps[k] — приземление и побитая
    фигура k-го прыжка. }
  TMove = record
    Len: Integer;
    Path: array[0..MaxJumps] of TSq;
    Caps: array[0..MaxJumps] of TSq;
  end;
  TMoveList = array[1..ListCap] of TMove;
  TSimpleList = array[1..ListCap] of TSimpleMove;
  TIntList = array[1..ListCap] of Integer;
  PMoveList = ^TMoveList;
  PSimpleList = ^TSimpleList;
  PIntList = ^TIntList;

var
  Board: TBoard;

  Closing: Boolean;     // окно закрывается: перебор прерывается
  StopSearch: Boolean;  // запрошена остановка перебора
  Poddavki: Integer;    // 1 — игра в поддавки
  { Уровни по умолчанию. }
  WhiteLevel: Integer = 6;
  BlackLevel: Integer = 6;

  { Списки ходов по номеру стороны. Ходы стороны, которая ходит сейчас (игрока или после
    перебора — компьютера): число взятий и простых ходов, сами ходы; оценки ходов корня
    последнего перебора — в RootValues, на тех же местах, что ходы в списке. }
  CapCnt, SimCnt: array[1..2] of Integer;
  CapList: array[1..2] of TMoveList;
  SimList: array[1..2] of TSimpleList;
  RootValues: array[1..2] of TIntList;
  { Ходы узлов перебора: [сторона, глубина]. }
  CapCntD, SimCntD: array[1..2, 1..MaxDepth] of Integer;
  CapListD: array[1..2, 1..MaxDepth] of TMoveList;
  SimListD: array[1..2, 1..MaxDepth] of TSimpleList;

  { Датчик случайных чисел Delphi 5: тот же ряд, что в программе 2003 года. }
  DRandSeed: LongWord;
  FixedSeed: Boolean;  // без Randomize: ряд случайных чисел с нуля, партии повторяются

  { Вызывается раз в IdleEvery узлов перебора: окно обрабатывает сообщения. }
  SearchIdle: procedure;

procedure DRandomize;
function DRandom(Range: Integer): Integer;
function PromoRow(Side: Integer): Integer; inline;
function Level(Side: Integer): Integer;
procedure CopyBoard(var Dst: TBoard; const Src: TBoard);
function BoardsEqual(const A, B: TBoard): Boolean;
procedure InitBoard(var B: TBoard);
procedure NewBoard;
function BoardToText(const B: TBoard): string;
procedure TextToBoard(const S: string; var B: TBoard);
procedure SideScores(out W, B: Integer);
function Eval(Side: Integer): Integer;
procedure CaptureMoves(Side: Integer; var Count: Integer; var List: TMoveList);
procedure SimpleMoves(Side: Integer; var Count: Integer; var List: TSimpleList);
procedure ApplyCapture(Side: Integer; const M: TMove);
procedure ApplySimple(Side: Integer; const M: TSimpleMove); inline;
procedure UndoSimple(const M: TSimpleMove; Piece: Integer); inline;
function Search(Side, Depth: Integer): Integer;
function FullSearch(Side, Depth: Integer): Integer;
function PickRootMove(Side, Count, Best: Integer): Integer;

implementation

procedure DRandomize;
var
  T: TSystemTime;
begin
  GetLocalTime(T);
  DRandSeed := ((T.wHour * 60 + T.wMinute) * 60 + T.wSecond) * 1000 + T.wMilliseconds;
end;

function DRandom(Range: Integer): Integer;
begin
  DRandSeed := DRandSeed * $08088405 + 1;
  Result := Integer((UInt64(DRandSeed) * LongWord(Range)) shr 32);
end;

{ ---------- Доска ---------- }

function PromoRow(Side: Integer): Integer;
begin
  if Side = 1 then
    Result := 8
  else
    Result := 1;
end;

function Level(Side: Integer): Integer;
begin
  if Side = 1 then
    Result := WhiteLevel
  else
    Result := BlackLevel;
end;

{ Копирует доску целиком: одно присваивание быстрее обхода тёмных полей, а светлые поля
  всегда пусты. }
procedure CopyBoard(var Dst: TBoard; const Src: TBoard);
begin
  Dst := Src;
end;

function BoardsEqual(const A, B: TBoard): Boolean;
var
  i, j: Integer;
begin
  Result := True;
  i := 1;
  while (i < 9) and Result do
  begin
    j := 1;
    while (j < 9) and Result do
    begin
      if A[i, j] <> B[i, j] then
        Result := False;
      Inc(j);
    end;
    Inc(i);
  end;
end;

procedure InitBoard(var B: TBoard);
var
  i, j: Integer;
begin
  for i := 1 to 8 do
    for j := 1 to 8 do
      B[i, j] := 0;
  for i := 1 to 8 do
    for j := 1 to 3 do
      if (i + j) mod 2 = 0 then
        B[i, j] := 1;
  for i := 1 to 8 do
    for j := 6 to 8 do
      if (i + j) mod 2 = 0 then
        B[i, j] := 2;
end;

procedure NewBoard;
var
  B: TBoard;
begin
  InitBoard(B);
  Board := B;
end;

const
  { Буквы клеток в позиции строкой: 0 — '.', 1 — 'w', 2 — 'b', 11 — 'W', 12 — 'B'. }
  CellChar: array[0..12] of Char = ('.', 'w', 'b', '?', '?', '?', '?', '?', '?', '?', '?',
    'W', 'B');

{ Позиция строкой: 32 символа .wbWB — горизонтали 1..8, в каждой тёмные поля слева направо.
  Так позицию пишет журнал окна (/log) и читает игрок матча (verify/player). }
function BoardToText(const B: TBoard): string;
var
  i, j: Integer;
begin
  Result := '';
  for j := 1 to 8 do
    for i := 1 to 8 do
      if (i + j) mod 2 = 0 then
        Result := Result + CellChar[B[i, j]];
end;

{ Позиция из строки BoardToText; другие буквы — пустые поля. }
procedure TextToBoard(const S: string; var B: TBoard);
var
  i, j, k: Integer;
begin
  k := 1;
  for j := 1 to 8 do
    for i := 1 to 8 do
    begin
      B[i, j] := 0;
      if (i + j) mod 2 = 0 then
      begin
        case S[k] of
          'w': B[i, j] := 1;
          'b': B[i, j] := 2;
          'W': B[i, j] := 11;
          'B': B[i, j] := 12;
        end;
        Inc(k);
      end;
    end;
end;

const
  { Слагаемые оценки обычной игры, не поддавков; веса подобраны
    матчами (verify/match.py). EvBack — шашка на c1 или e1 (у чёрных d8 или f8): охраняет
    тыл, не пускает соперника в дамки. EvCenter — шашка в центре: c5, d4, e5, f4. }
  EvBack = 300;
  EvCenter = 100;

{ Слагаемые оценки за один проход по доске. W и B — фигуры белых и чёрных: шашка 10000 +
  100 за каждую горизонталь от своего края (первая — 100), +1 за каждое свободное поле
  впереди, дамка 30000. PW и PB — охрана тыла и центр. }
procedure EvalParts(out W, B, PW, PB: Integer); inline;
var
  i, j: Integer;
begin
  W := 0;
  B := 0;
  PW := 0;
  PB := 0;
  for i := 1 to 8 do
  begin
    if i mod 2 = 0 then
      j := 2
    else
      j := 1;
    while j < 9 do
    begin
      case Board[i, j] of
        1:
          begin
            W := W + 10000 + j * 100;
            if (i > 1) and (Board[i - 1, j + 1] = 0) then
              Inc(W);
            if (i < 8) and (Board[i + 1, j + 1] = 0) then
              Inc(W);
            if (j = 1) and ((i = 3) or (i = 5)) then
              Inc(PW, EvBack);
            if ((j = 4) and ((i = 4) or (i = 6))) or ((j = 5) and ((i = 3) or (i = 5))) then
              Inc(PW, EvCenter);
          end;
        11:
          W := W + 30000;
        2:
          begin
            B := B + 10900 - j * 100;
            if (i > 1) and (Board[i - 1, j - 1] = 0) then
              Inc(B);
            if (i < 8) and (Board[i + 1, j - 1] = 0) then
              Inc(B);
            if (j = 8) and ((i = 4) or (i = 6)) then
              Inc(PB, EvBack);
            if ((j = 4) and ((i = 4) or (i = 6))) or ((j = 5) and ((i = 3) or (i = 5))) then
              Inc(PB, EvCenter);
          end;
        12:
          B := B + 30000;
      end;
      Inc(j, 2);
    end;
  end;
end;

{ Оценки белых (W) и чёрных (B) по отдельности — для полосок перевеса в окне: только фигуры,
  в поддавках со знаком минус. }
procedure SideScores(out W, B: Integer);
var
  PW, PB: Integer;
begin
  EvalParts(W, B, PW, PB);
  if Poddavki = 1 then
  begin
    W := -W;
    B := -B;
  end;
end;

{ Оценка позиции для Side: разность её оценки и соперника, в обычной игре — с охраной тыла и
  центром, в поддавках фигуры идут со знаком минус. }
function Eval(Side: Integer): Integer;
var
  W, B, PW, PB: Integer;
begin
  EvalParts(W, B, PW, PB);
  if Poddavki = 1 then
  begin
    W := -W;
    B := -B;
  end
  else
  begin
    W := W + PW;
    B := B + PB;
  end;
  if Side = 1 then
    Result := W - B
  else
    Result := B - W;
end;

{ ---------- Генерация ходов ---------- }

const
  { Направления по диагоналям в порядке, в котором серии взятий попадают в список:
    влево-вниз, вправо-вверх, влево-вверх, вправо-вниз. Влево поля приземления дамки
    перебираются от дальнего к ближнему, вправо — от ближнего к дальнему. От порядка зависят
    номера ходов, а значит, и случайный выбор среди равных. }
  DirX: array[1..4] of Integer = (-1, 1, -1, 1);
  DirY: array[1..4] of Integer = (-1, 1, 1, -1);

var
  { Генератор взятий на время одного вызова CaptureMoves: свои и чужие фигуры, горизонталь
    превращения, список для серий и текущая серия (поля и побитые фигуры). }
  GenMan, GenKing, GenEMan, GenEKing, GenPromo: Integer;
  GenCount: PInteger;
  GenList: PMoveList;
  GenPath, GenCaps: array[0..MaxJumps] of TSq;

{ Дописывает в список текущую серию из N прыжков. }
procedure AddSeries(N: Integer);
var
  t: Integer;
  M: ^TMove;
begin
  Inc(GenCount^);
  M := @GenList^[GenCount^];
  M^.Len := N;
  M^.Path[0] := GenPath[0];
  for t := 1 to N do
  begin
    M^.Path[t] := GenPath[t];
    M^.Caps[t] := GenCaps[t];
  end;
end;

function JumpsFrom(X, Y, Len: Integer): Boolean; forward;

{ Прыжок (Len + 1)-й в серии: фигура с (X, Y) бьёт (CX, CY) и встаёт на (i, j); затем
  продолжения серии. Побитая фигура на это время помечается своей шашкой: её нельзя бить
  второй раз и через неё нельзя перепрыгнуть. }
procedure Jump(X, Y, i, j, CX, CY, Len: Integer);
var
  Piece, Captured: Integer;
begin
  Piece := Board[X, Y];
  Captured := Board[CX, CY];
  if j = GenPromo then
    Board[i, j] := GenKing
  else
    Board[i, j] := Piece;
  Board[X, Y] := 0;
  Board[CX, CY] := GenMan;
  GenPath[Len + 1].X := i;
  GenPath[Len + 1].Y := j;
  GenCaps[Len + 1].X := CX;
  GenCaps[Len + 1].Y := CY;
  if not JumpsFrom(i, j, Len + 1) then
    AddSeries(Len + 1);
  Board[X, Y] := Piece;
  Board[CX, CY] := Captured;
  Board[i, j] := 0;
end;

{ Все продолжения серии с поля (X, Y) после Len прыжков; серия, которую продолжить нельзя,
  дописывается в список. Шашка бьёт соседнюю фигуру соперника через одно поле; дамка — первую
  фигуру на диагонали, если это не своя, на любое свободное поле за ней. False — бить с поля
  нечего. }
function JumpsFrom(X, Y, Len: Integer): Boolean;
var
  d, dx, dy, i, j, CX, CY, n, k, v: Integer;
  LX, LY: array[1..7] of Integer;
begin
  Result := False;
  if Board[X, Y] = GenMan then
    for d := 1 to 4 do
    begin
      i := X + 2 * DirX[d];
      j := Y + 2 * DirY[d];
      if (i < 1) or (i > 8) or (j < 1) or (j > 8) or (Board[i, j] <> 0) then
        Continue;
      v := Board[X + DirX[d], Y + DirY[d]];
      if (v = GenEMan) or (v = GenEKing) then
      begin
        Result := True;
        Jump(X, Y, i, j, X + DirX[d], Y + DirY[d], Len);
      end;
    end
  else
    for d := 1 to 4 do
    begin
      dx := DirX[d];
      dy := DirY[d];
      i := X + dx;
      j := Y + dy;
      while (i >= 1) and (i <= 8) and (j >= 1) and (j <= 8) and (Board[i, j] = 0) do
      begin
        Inc(i, dx);
        Inc(j, dy);
      end;
      if (i < 1) or (i > 8) or (j < 1) or (j > 8) then
        Continue;
      v := Board[i, j];
      if (v = GenMan) or (v = GenKing) then
        Continue;
      CX := i;
      CY := j;
      n := 0;
      Inc(i, dx);
      Inc(j, dy);
      while (i >= 1) and (i <= 8) and (j >= 1) and (j <= 8) and (Board[i, j] = 0) do
      begin
        Inc(n);
        LX[n] := i;
        LY[n] := j;
        Inc(i, dx);
        Inc(j, dy);
      end;
      if n > 0 then
        Result := True;
      if dx < 0 then
        for k := n downto 1 do
          Jump(X, Y, LX[k], LY[k], CX, CY, Len)
      else
        for k := 1 to n do
          Jump(X, Y, LX[k], LY[k], CX, CY, Len);
    end;
end;

{ Все взятия стороны. Бить обязательно до конца: серия, которая совпадает с началом более
  длинной (те же поля и те же побитые), выбрасывается. }
procedure CaptureMoves(Side: Integer; var Count: Integer; var List: TMoveList);
var
  i, j, k, s, a, b: Integer;
  Same: Boolean;
begin
  Count := 0;
  GenMan := Side;
  GenKing := Side + 10;
  GenEMan := 3 - Side;
  GenEKing := 13 - Side;
  GenPromo := PromoRow(Side);
  GenCount := @Count;
  GenList := @List;
  for i := 1 to 8 do
  begin
    if i mod 2 = 0 then
      j := 2
    else
      j := 1;
    while j < 9 do
    begin
      if (Board[i, j] = Side) or (Board[i, j] = Side + 10) then
      begin
        GenPath[0].X := i;
        GenPath[0].Y := j;
        JumpsFrom(i, j, 0);
      end;
      Inc(j, 2);
    end;
  end;
  for a := 1 to Count do
    for b := 1 to Count do
      if List[a].Len < List[b].Len then
      begin
        s := 1;
        Same := True;
        while (s <= List[a].Len) and Same do
        begin
          if (List[a].Path[s - 1].X <> List[b].Path[s - 1].X)
            or (List[a].Path[s - 1].Y <> List[b].Path[s - 1].Y)
            or (List[a].Caps[s].X <> List[b].Caps[s].X)
            or (List[a].Caps[s].Y <> List[b].Caps[s].Y) then
            Same := False;
          Inc(s);
        end;
        if Same then
          List[a].Path[0].X := -1;
      end;
  a := 1;
  while a <= Count do
    if List[a].Path[0].X = -1 then
    begin
      for k := a to Count - 1 do
        List[k] := List[k + 1];
      Dec(Count);
    end
    else
      Inc(a);
end;

{ Поля строго между (X1, Y1) и (X2, Y2) свободны. }
function PathClear(X1, Y1, X2, Y2: Integer): Boolean;
var
  dx, dy, X, Y: Integer;
begin
  Result := True;
  if X1 > X2 then
    dx := -1
  else
    dx := 1;
  if Y1 > Y2 then
    dy := -1
  else
    dy := 1;
  X := X1 + dx;
  Y := Y1 + dy;
  while Result and (X <> X2) do
  begin
    if Board[X, Y] <> 0 then
      Result := False;
    Inc(X, dx);
    Inc(Y, dy);
  end;
end;

procedure SimpleMoves(Side: Integer; var Count: Integer; var List: TSimpleList);
var
  i, j, k, l, dy, JLimit: Integer;

  procedure Add(FX, FY, TX, TY: Integer);
  begin
    Inc(Count);
    List[Count].FX := FX;
    List[Count].FY := FY;
    List[Count].TX := TX;
    List[Count].TY := TY;
  end;

begin
  Count := 0;
  if Side = 1 then
  begin
    dy := 1;
    JLimit := 8;
  end
  else
  begin
    dy := -1;
    JLimit := 9;
  end;
  for i := 1 to 8 do
  begin
    if i mod 2 = 0 then
      j := 2
    else if Side = 1 then
      j := 1
    else
      j := 3;
    while j < JLimit do
    begin
      if Board[i, j] = Side then
      begin
        if (i > 1) and (Board[i - 1, j + dy] = 0) then
          Add(i, j, i - 1, j + dy);
        if (i < 8) and (Board[i + 1, j + dy] = 0) then
          Add(i, j, i + 1, j + dy);
      end;
      Inc(j, 2);
    end;
  end;
  for i := 1 to 8 do
  begin
    if i mod 2 = 0 then
      j := 2
    else
      j := 1;
    while j < 9 do
    begin
      if Board[i, j] = Side + 10 then
      begin
        for k := Max(i - j + 1, 1) to Min(8 - j + i, 8) do
        begin
          l := j - i + k;
          if (Board[k, l] = 0) and PathClear(i, j, k, l) then
            Add(i, j, k, l);
        end;
        for k := Max(j + i - 8, 1) to Min(j + i - 1, 8) do
        begin
          l := i + j - k;
          if (Board[k, l] = 0) and PathClear(i, j, k, l) then
            Add(i, j, k, l);
        end;
      end;
      Inc(j, 2);
    end;
  end;
end;

procedure ApplyCapture(Side: Integer; const M: TMove);
var
  k: Integer;
begin
  Board[M.Path[M.Len].X, M.Path[M.Len].Y] := Board[M.Path[0].X, M.Path[0].Y];
  if (M.Path[M.Len].X <> M.Path[0].X) or (M.Path[M.Len].Y <> M.Path[0].Y) then
    Board[M.Path[0].X, M.Path[0].Y] := 0;
  for k := 1 to M.Len do
  begin
    Board[M.Caps[k].X, M.Caps[k].Y] := 0;
    if M.Path[k].Y = PromoRow(Side) then
      Board[M.Path[M.Len].X, M.Path[M.Len].Y] := Side + 10;
  end;
end;

procedure ApplySimple(Side: Integer; const M: TSimpleMove);
begin
  if M.TY = PromoRow(Side) then
    Board[M.TX, M.TY] := Side + 10
  else
    Board[M.TX, M.TY] := Board[M.FX, M.FY];
  Board[M.FX, M.FY] := 0;
end;

{ Отменяет простой ход M; Piece — фигура, которая ходила (до превращения). Поле, куда шёл
  простой ход, было пустым, поэтому копия всей доски не нужна. }
procedure UndoSimple(const M: TSimpleMove; Piece: Integer);
begin
  Board[M.FX, M.FY] := Piece;
  Board[M.TX, M.TY] := 0;
end;

{ ---------- Перебор ---------- }

const
  { Сообщения окна обрабатываются раз в IdleEvery узлов: обработка в каждом узле заметно
    замедляет перебор, а за IdleEvery узлов проходят миллисекунды. }
  IdleEvery = 256;

var
  IdleLeft: Integer;  // узлов до следующей обработки сообщений

{ Узел перебора: раз в IdleEvery узлов окно обрабатывает сообщения. }
procedure SearchPoll;
begin
  if Assigned(SearchIdle) then
  begin
    Dec(IdleLeft);
    if IdleLeft <= 0 then
    begin
      IdleLeft := IdleEvery;
      SearchIdle;
    end;
  end;
end;

{ Доигрывание взятий в листьях (quiescence search), только в обычном режиме. Бить
  обязательно, поэтому позиция, где ходящая сторона может бить, ещё не решена: без
  доигрывания размен, начатый на последнем ходу перебора, оценивается так, будто ответить на
  него нельзя. Взятия разыгрываются до позиции, где ходящей стороне бить нечего, и
  оценивается уже она. Окно (Alpha, Beta) — как в альфа-бете, с бесконечным окном это полный
  перебор взятий. }

const
  MaxQPly = 32;  // взятий подряд не больше, чем фигур на доске

var
  QCnt: array[1..MaxQPly] of Integer;
  QList: array[1..MaxQPly] of TMoveList;

function QReply(Side, Alpha, Beta, Ply: Integer): Integer; forward;

{ Оценка листа для Side, когда ходит Side. }
function QMax(Side, Alpha, Beta, Ply: Integer): Integer;
var
  m, V: Integer;
  Save: TBoard;
begin
  if Ply > MaxQPly then
    Exit(Eval(Side));
  CaptureMoves(Side, QCnt[Ply], QList[Ply]);
  if QCnt[Ply] = 0 then
    Exit(Eval(Side));
  Result := -Inf;
  for m := 1 to QCnt[Ply] do
  begin
    CopyBoard(Save, Board);
    ApplyCapture(Side, QList[Ply][m]);
    V := QReply(Side, Alpha, Beta, Ply + 1);
    CopyBoard(Board, Save);
    Result := Max(Result, V);
    Alpha := Max(Alpha, Result);
    if Alpha >= Beta then
      Break;
  end;
end;

{ Оценка листа для Side, когда ходит соперник. }
function QReply(Side, Alpha, Beta, Ply: Integer): Integer;
var
  Opp, r, V: Integer;
  Save: TBoard;
begin
  if Ply > MaxQPly then
    Exit(Eval(Side));
  Opp := 3 - Side;
  CaptureMoves(Opp, QCnt[Ply], QList[Ply]);
  if QCnt[Ply] = 0 then
    Exit(Eval(Side));
  Result := Inf;
  for r := 1 to QCnt[Ply] do
  begin
    CopyBoard(Save, Board);
    ApplyCapture(Opp, QList[Ply][r]);
    V := QMax(Side, Alpha, Beta, Ply + 1);
    CopyBoard(Board, Save);
    Result := Min(Result, V);
    Beta := Min(Beta, Result);
    if Alpha >= Beta then
      Break;
  end;
end;

{ Худший для Side результат по всем ответам соперника на уже сделанный ход; листья — после
  доигрывания взятий. }
function ReplyValue(Side, Depth: Integer): Integer;
var
  Opp, r, Piece: Integer;
  Save2: TBoard;
  Mv: TSimpleMove;
begin
  Opp := 3 - Side;
  CaptureMoves(Opp, CapCntD[Opp, Depth], CapListD[Opp, Depth]);
  Result := Inf;
  for r := 1 to CapCntD[Opp, Depth] do
  begin
    CopyBoard(Save2, Board);
    ApplyCapture(Opp, CapListD[Opp, Depth][r]);
    if Depth = 1 then
      Result := Min(Result, QMax(Side, -Inf - 1, Inf + 1, 1))
    else
      Result := Min(Result, FullSearch(Side, Depth - 1));
    CopyBoard(Board, Save2);
  end;
  if CapCntD[Opp, Depth] = 0 then
  begin
    SimpleMoves(Opp, SimCntD[Opp, Depth], SimListD[Opp, Depth]);
    if (SimCntD[Opp, Depth] = 0) and (Poddavki = 1) then
      Result := -Inf;
    for r := 1 to SimCntD[Opp, Depth] do
    begin
      Mv := SimListD[Opp, Depth][r];
      Piece := Board[Mv.FX, Mv.FY];
      ApplySimple(Opp, Mv);
      if Depth = 1 then
        Result := Min(Result, QMax(Side, -Inf - 1, Inf + 1, 1))
      else
        Result := Min(Result, FullSearch(Side, Depth - 1));
      UndoSimple(Mv, Piece);
    end;
  end;
end;

{ Полный перебор без отсечений: лучшая для Side оценка на Depth полных ходов вперёд. Эталон
  для проверки альфа-беты (verify/abcheck). На корне (Depth = уровень стороны) оценки ходов
  пишутся в RootValues[Side]; у вложенных узлов Depth меньше, и туда они не пишут. }
function FullSearch(Side, Depth: Integer): Integer;
var
  m, V, Piece: Integer;
  Save1: TBoard;
  Mv: TSimpleMove;
begin
  Result := -Inf;
  SearchPoll;
  if Closing or StopSearch then
    Exit;
  CaptureMoves(Side, CapCntD[Side, Depth], CapListD[Side, Depth]);
  if CapCntD[Side, Depth] > 0 then
    for m := 1 to CapCntD[Side, Depth] do
    begin
      CopyBoard(Save1, Board);
      ApplyCapture(Side, CapListD[Side, Depth][m]);
      V := ReplyValue(Side, Depth);
      if Depth = Level(Side) then
        RootValues[Side][m] := V;
      Result := Max(Result, V);
      CopyBoard(Board, Save1);
    end
  else
  begin
    SimpleMoves(Side, SimCntD[Side, Depth], SimListD[Side, Depth]);
    if (SimCntD[Side, Depth] = 0) and (Poddavki = 1) then
      Result := Inf;
    for m := 1 to SimCntD[Side, Depth] do
    begin
      Mv := SimListD[Side, Depth][m];
      Piece := Board[Mv.FX, Mv.FY];
      ApplySimple(Side, Mv);
      V := ReplyValue(Side, Depth);
      if Depth = Level(Side) then
        RootValues[Side][m] := V;
      Result := Max(Result, V);
      UndoSimple(Mv, Piece);
    end;
  end;
end;

{ ---------- Альфа-бета ---------- }

{ Альфа-бета даёт ту же оценку лучшего хода, что и полный перебор, но пропускает ветки,
  которые на неё повлиять не могут: если соперник уже нашёл ответ хуже для Side, чем
  известный Side вариант (Alpha), остальные его ответы не смотрятся, и наоборот (Beta).
  Узел возвращает точную оценку, если она внутри окна (Alpha, Beta); если нет — границу:
  не больше Alpha — оценка не выше возвращённой, не меньше Beta — не ниже.

  Отсекается тем больше, чем раньше смотрится сильный ход. Простой ход, давший отсечение,
  скорее всего даст его и в соседних позициях той же глубины (ход-убийца, killer move), а
  частые отсечения копятся в истории по полям «откуда — куда» (history heuristic): такие ходы
  смотрятся первыми. Сортировка по оценке позиции стоит дороже, чем экономит. На оценку
  внутри окна порядок не влияет, поэтому лучшая оценка и набор равных лучших ходов те же,
  что при порядке генерации; ходы корня не переставляются.

  Одна и та же позиция получается разными перестановками ходов, особенно у дамок. Итог узла
  запоминается в таблице транспозиций (transposition table) по ключу позиции (Zobrist
  hashing) и виду узла. Оценка узла зависит только от позиции, вида узла и оставшейся
  глубины, поэтому запись той же глубины заменяет перебор: точная оценка — точная, граница
  отвечает узлу, если решает его при новом окне. Запись другой глубины даёт только ход,
  который смотрится первым. }

const
  TTBits = 20;
  TTMask = 1 shl TTBits - 1;
  TTExact = 1;  // оценка точная
  TTLower = 2;  // оценка не ниже Value
  TTUpper = 3;  // оценка не выше Value

type
  { Запись таблицы транспозиций. }
  TTransEntry = record
    Key: QWord;
    Value: Integer;
    Gen: Word;
    Depth, Flag: Byte;
    MFX, MFY, MTX, MTY: Byte;  // лучший простой ход узла; MFX = 0 — нет
  end;
  PTransEntry = ^TTransEntry;

var
  { Ходы-убийцы: два последних простых хода, давших отсечение на этой глубине;
    [False] — ходы Side, [True] — ответы соперника. }
  Killers: array[Boolean, 1..MaxDepth, 1..2] of TSimpleMove;
  { История отсечений простых ходов: [сторона, FX, FY, TX, TY]. }
  History: array[1..2, 1..8, 1..8, 1..8, 1..8] of Integer;
  { Оценки порядка ходов узла, по тем же индексам, что Killers. }
  Scores: array[Boolean, 1..MaxDepth] of TIntList;
  TT: array[0..TTMask] of TTransEntry;
  TTGen: Word;  // номер перебора: записи прежних переборов считаются пустыми
  { Ключи Zobrist: [вертикаль, горизонталь, значение клетки]; у пустой клетки — 0. }
  Zobrist: array[1..8, 1..8, -1..12] of QWord;
  ZReply: QWord;  // добавка к ключу узла ответа соперника

{ Заполняет ключи Zobrist постоянным рядом (splitmix64): перебор не зависит от запуска. }
procedure InitZobrist;
var
  S, Z: QWord;
  i, j, v: Integer;
begin
  S := QWord($9E3779B97F4A7C15);
  for i := 1 to 8 do
    for j := 1 to 8 do
      for v := -1 to 12 do
      begin
        S := S + QWord($9E3779B97F4A7C15);
        Z := S;
        Z := (Z xor (Z shr 30)) * QWord($BF58476D1CE4E5B9);
        Z := (Z xor (Z shr 27)) * QWord($94D049BB133111EB);
        Z := Z xor (Z shr 31);
        if v = 0 then
          Zobrist[i, j, v] := 0
        else
          Zobrist[i, j, v] := Z;
      end;
  ZReply := Zobrist[1, 2, 1];  // светлое поле: на доске не встречается
end;

{ Ключ позиции на доске. }
function BoardKey: QWord;
var
  i, j: Integer;
begin
  Result := 0;
  for i := 1 to 8 do
  begin
    if i mod 2 = 0 then
      j := 2
    else
      j := 1;
    while j < 9 do
    begin
      Result := Result xor Zobrist[i, j, Board[i, j]];
      Inc(j, 2);
    end;
  end;
end;

{ Ищет узел Key в таблице. Move — лучший простой ход из записи (MFX = 0 — нет). True, если
  запись той же глубины решает узел при окне (Alpha, Beta); тогда её оценка — в V. }
function TTProbe(Key: QWord; Depth, Alpha, Beta: Integer; var V: Integer;
  var Move: TSimpleMove): Boolean;
var
  E: PTransEntry;
begin
  Result := False;
  E := @TT[Key and TTMask];
  if (E^.Gen <> TTGen) or (E^.Key <> Key) then
  begin
    Move.FX := 0;
    Exit;
  end;
  Move.FX := E^.MFX;
  Move.FY := E^.MFY;
  Move.TX := E^.MTX;
  Move.TY := E^.MTY;
  if E^.Depth = Depth then
    case E^.Flag of
      TTExact: Result := True;
      TTLower: Result := E^.Value >= Beta;
      TTUpper: Result := E^.Value <= Alpha;
    end;
  if Result then
    V := E^.Value;
end;

{ Запоминает итог V узла Key, посчитанного с окном (Alpha, Beta). Прерванный перебор итога
  не даёт и не запоминается. Запись другой позиции этого перебора с большей глубиной не
  вытесняется: её перебор стоил дороже. }
procedure TTStore(Key: QWord; Depth, V, Alpha, Beta: Integer; const Move: TSimpleMove);
var
  E: PTransEntry;
begin
  if Closing or StopSearch then
    Exit;
  E := @TT[Key and TTMask];
  if (E^.Gen = TTGen) and (E^.Key <> Key) and (E^.Depth > Depth) then
    Exit;
  E^.Key := Key;
  E^.Gen := TTGen;
  E^.Depth := Depth;
  E^.Value := V;
  if V <= Alpha then
    E^.Flag := TTUpper
  else if V >= Beta then
    E^.Flag := TTLower
  else
    E^.Flag := TTExact;
  E^.MFX := Move.FX;
  E^.MFY := Move.FY;
  E^.MTX := Move.TX;
  E^.MTY := Move.TY;
end;

{ Новый перебор: записи таблицы от прежних больше не действуют. }
procedure TTNewSearch;
begin
  if TTGen = High(TTGen) then
  begin
    FillChar(TT, SizeOf(TT), 0);
    TTGen := 0;
  end;
  Inc(TTGen);
end;

function SameMove(const A, B: TSimpleMove): Boolean;
begin
  Result := (A.FX = B.FX) and (A.FY = B.FY) and (A.TX = B.TX) and (A.TY = B.TY);
end;

{ Оценки порядка простых ходов узла: первым ход из таблицы транспозиций (First), затем
  ходы-убийцы глубины, остальные по истории. }
procedure ScoreMoves(const L: TSimpleList; Count, Mover: Integer; Reply: Boolean;
  Depth: Integer; const First: TSimpleMove);
var
  k: Integer;
  S: PIntList;
begin
  S := @Scores[Reply, Depth];
  for k := 1 to Count do
    if SameMove(L[k], First) then
      S^[k] := MaxInt
    else if SameMove(L[k], Killers[Reply, Depth, 1]) then
      S^[k] := MaxInt - 1
    else if SameMove(L[k], Killers[Reply, Depth, 2]) then
      S^[k] := MaxInt - 2
    else
      with L[k] do
        S^[k] := History[Mover, FX, FY, TX, TY];
end;

{ Ставит на место m ход с наибольшей оценкой порядка среди m..Count; при равных оценках
  остаётся порядок генерации. }
procedure PickMove(var L: TSimpleList; Reply: Boolean; Depth, m, Count: Integer);
var
  k, Best, V: Integer;
  S: PIntList;
  T: TSimpleMove;
begin
  S := @Scores[Reply, Depth];
  Best := m;
  for k := m + 1 to Count do
    if S^[k] > S^[Best] then
      Best := k;
  if Best <> m then
  begin
    T := L[m];
    L[m] := L[Best];
    L[Best] := T;
    V := S^[m];
    S^[m] := S^[Best];
    S^[Best] := V;
  end;
end;

{ Простой ход M стороны Mover дал отсечение на глубине Depth. }
procedure StoreCutoff(const M: TSimpleMove; Mover: Integer; Reply: Boolean; Depth: Integer);
var
  H: PInteger;
  a, b, c, d, s: Integer;
begin
  if not SameMove(M, Killers[Reply, Depth, 1]) then
  begin
    Killers[Reply, Depth, 2] := Killers[Reply, Depth, 1];
    Killers[Reply, Depth, 1] := M;
  end;
  H := @History[Mover, M.FX, M.FY, M.TX, M.TY];
  Inc(H^, Depth * Depth);
  if H^ > 1 shl 28 then  // далеко от оценок ходов-убийц (MaxInt)
    for s := 1 to 2 do
      for a := 1 to 8 do
        for b := 1 to 8 do
          for c := 1 to 8 do
            for d := 1 to 8 do
              History[s, a, b, c, d] := History[s, a, b, c, d] shr 1;
end;

function ABMax(Side, Depth, Alpha, Beta: Integer): Integer; forward;

{ Худший для Side ответ соперника с отсечением по окну (Alpha, Beta). }
function ABReply(Side, Depth, Alpha, Beta: Integer): Integer;
var
  Opp, r, Piece, V, Alpha0, Beta0: Integer;
  Save2: TBoard;
  Key: QWord;
  First, Best, Mv: TSimpleMove;
begin
  Key := BoardKey xor ZReply;
  if TTProbe(Key, Depth, Alpha, Beta, V, First) then
    Exit(V);
  Alpha0 := Alpha;
  Beta0 := Beta;
  Best.FX := 0;
  Opp := 3 - Side;
  CaptureMoves(Opp, CapCntD[Opp, Depth], CapListD[Opp, Depth]);
  Result := Inf;
  if CapCntD[Opp, Depth] > 0 then
  begin
    for r := 1 to CapCntD[Opp, Depth] do
    begin
      CopyBoard(Save2, Board);
      ApplyCapture(Opp, CapListD[Opp, Depth][r]);
      if Depth = 1 then
        V := QMax(Side, Alpha, Beta, 1)
      else
        V := ABMax(Side, Depth - 1, Alpha, Beta);
      CopyBoard(Board, Save2);
      Result := Min(Result, V);
      Beta := Min(Beta, Result);
      if Alpha >= Beta then
        Break;
    end;
  end
  else
  begin
    SimpleMoves(Opp, SimCntD[Opp, Depth], SimListD[Opp, Depth]);
    if (SimCntD[Opp, Depth] = 0) and (Poddavki = 1) then
      Result := -Inf;
    ScoreMoves(SimListD[Opp, Depth], SimCntD[Opp, Depth], Opp, True, Depth, First);
    for r := 1 to SimCntD[Opp, Depth] do
    begin
      PickMove(SimListD[Opp, Depth], True, Depth, r, SimCntD[Opp, Depth]);
      Mv := SimListD[Opp, Depth][r];
      Piece := Board[Mv.FX, Mv.FY];
      ApplySimple(Opp, Mv);
      if Depth = 1 then
        V := QMax(Side, Alpha, Beta, 1)
      else
        V := ABMax(Side, Depth - 1, Alpha, Beta);
      UndoSimple(Mv, Piece);
      if (r = 1) or (V < Result) then
        Best := Mv;
      Result := Min(Result, V);
      Beta := Min(Beta, Result);
      if Alpha >= Beta then
      begin
        StoreCutoff(Mv, Opp, True, Depth);
        Break;
      end;
    end;
  end;
  TTStore(Key, Depth, Result, Alpha0, Beta0, Best);
end;

{ Лучший для Side ход с отсечением по окну (Alpha, Beta). }
function ABMax(Side, Depth, Alpha, Beta: Integer): Integer;
var
  m, V, Piece, Alpha0, Beta0: Integer;
  Save1: TBoard;
  Key: QWord;
  First, Best, Mv: TSimpleMove;
begin
  Result := -Inf;
  SearchPoll;
  if Closing or StopSearch then
    Exit;
  Key := BoardKey;
  if TTProbe(Key, Depth, Alpha, Beta, V, First) then
    Exit(V);
  Alpha0 := Alpha;
  Beta0 := Beta;
  Best.FX := 0;
  CaptureMoves(Side, CapCntD[Side, Depth], CapListD[Side, Depth]);
  if CapCntD[Side, Depth] > 0 then
  begin
    for m := 1 to CapCntD[Side, Depth] do
    begin
      CopyBoard(Save1, Board);
      ApplyCapture(Side, CapListD[Side, Depth][m]);
      V := ABReply(Side, Depth, Alpha, Beta);
      CopyBoard(Board, Save1);
      Result := Max(Result, V);
      Alpha := Max(Alpha, Result);
      if Alpha >= Beta then
        Break;
    end;
  end
  else
  begin
    SimpleMoves(Side, SimCntD[Side, Depth], SimListD[Side, Depth]);
    if (SimCntD[Side, Depth] = 0) and (Poddavki = 1) then
      Result := Inf;
    ScoreMoves(SimListD[Side, Depth], SimCntD[Side, Depth], Side, False, Depth, First);
    for m := 1 to SimCntD[Side, Depth] do
    begin
      PickMove(SimListD[Side, Depth], False, Depth, m, SimCntD[Side, Depth]);
      Mv := SimListD[Side, Depth][m];
      Piece := Board[Mv.FX, Mv.FY];
      ApplySimple(Side, Mv);
      V := ABReply(Side, Depth, Alpha, Beta);
      UndoSimple(Mv, Piece);
      if (m = 1) or (V > Result) then
        Best := Mv;
      Result := Max(Result, V);
      Alpha := Max(Alpha, Result);
      if Alpha >= Beta then
      begin
        StoreCutoff(Mv, Side, False, Depth);
        Break;
      end;
    end;
  end;
  TTStore(Key, Depth, Result, Alpha0, Beta0, Best);
end;

{ Корень альфа-беты. Каждый ход считается с окном (лучшее - 1, бесконечность): оценка
  точна у всякого хода, который не хуже уже найденного лучшего, поэтому набор равных
  лучших ходов — тот же, что у полного перебора, и случайный выбор среди них не меняется.
  Ходы хуже получают лишь верхнюю границу и в выбор не попадают.
  Перебор идёт с углублением (iterative deepening): уровни 1, 2, … Depth, и на каждом ходы
  корня смотрятся в порядке оценок предыдущего уровня — лучший первым, тогда остальные
  отсекаются быстрее. Оценки пишутся на места ходов в списке, номера ходов не меняются. }
function ABRoot(Side, Depth: Integer): Integer;
var
  m, k, d, n, t, V: Integer;
  Caps: Boolean;
  Save1: TBoard;
  Order: TIntList;
  Vals: PIntList;
begin
  Result := -Inf;
  FillChar(Killers, SizeOf(Killers), 0);
  FillChar(History, SizeOf(History), 0);
  TTNewSearch;
  SearchPoll;
  if Closing or StopSearch then
    Exit;
  CaptureMoves(Side, CapCntD[Side, Depth], CapListD[Side, Depth]);
  Caps := CapCntD[Side, Depth] > 0;
  if Caps then
    n := CapCntD[Side, Depth]
  else
  begin
    SimpleMoves(Side, SimCntD[Side, Depth], SimListD[Side, Depth]);
    n := SimCntD[Side, Depth];
    if (n = 0) and (Poddavki = 1) then
      Result := Inf;
  end;
  if n = 0 then
    Exit;
  Vals := @RootValues[Side];
  for k := 1 to n do
    Order[k] := k;
  for d := 1 to Depth do
  begin
    if Closing or StopSearch then
      Exit;
    // по убыванию оценок предыдущего уровня, при равных — в порядке генерации
    if d > 1 then
      for k := 2 to n do
      begin
        t := Order[k];
        m := k - 1;
        while (m >= 1) and (Vals^[Order[m]] < Vals^[t]) do
        begin
          Order[m + 1] := Order[m];
          Dec(m);
        end;
        Order[m + 1] := t;
      end;
    Result := -Inf;
    for k := 1 to n do
    begin
      m := Order[k];
      CopyBoard(Save1, Board);
      if Caps then
        ApplyCapture(Side, CapListD[Side, Depth][m])
      else
        ApplySimple(Side, SimListD[Side, Depth][m]);
      V := ABReply(Side, d, Result - 1, Inf + 1);
      Vals^[m] := V;
      Result := Max(Result, V);
      CopyBoard(Board, Save1);
    end;
  end;
end;

{ Перебор для хода компьютера: Depth — уровень стороны. }
function Search(Side, Depth: Integer): Integer;
begin
  IdleLeft := 1;  // сообщения обрабатываются уже в корне
  Result := ABRoot(Side, Depth);
end;

{ Ход компьютера после Search с итогом Best: номер случайного хода среди Count ходов корня с
  оценкой Best (в CapList или SimList стороны). Не нашлось ни одного — первый ход. }
function PickRootMove(Side, Count, Best: Integer): Integer;
var
  i, n: Integer;
  Cand: TIntList;
begin
  n := 0;
  for i := 1 to Count do
    if RootValues[Side][i] = Best then
    begin
      Inc(n);
      Cand[n] := i;
    end;
  if n = 0 then
    Result := 1
  else
    Result := Cand[DRandom(n) + 1];
end;

initialization
  InitZobrist;

end.
