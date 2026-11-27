unit MainWindow;

{ Главное окно: отрисовка, ход игрока щелчками и клавишами, режимы игры. Правила, оценка и
  перебор — в модуле Engine. Компьютер среди ходов с лучшей оценкой выбирает случайный.

  Ходы игрока и компьютера идут через таймеры: WhiteTimer — ход компьютера за белых,
  BlackTimer — за чёрных (оба — ComputerTurn), PauseTimer — пауза после хода компьютера с
  подсвеченным путём, затем ход человека или компьютера. LastMover хранит, кто ходил
  последним: 1 — белые (ходят чёрные), 2 — чёрные (ходят белые). Сейчас ли ход человека —
  HumanToMove; конец партии (проигрыш или ничья) — EndGame. }

{$mode delphi}{$H+}
{$Q-}{$R-}

interface

uses
  Windows, SysUtils, Classes, Graphics, Controls, Forms, ExtCtrls, Buttons, Menus,
  StdCtrls, LMessages, Math, Engine;

type
  { Картинка доски: при уходе мыши гасит подсветку координат. }
  TRuzilImage = class(TImage)
  private
    procedure CMMouseLeave(var Message: TLMessage); message CM_MOUSELEAVE;
  end;

  { TMainForm }

  TMainForm = class(TForm)
    TitleLabel: TLabel;
    MainPanel: TPanel;
    BoardPanel: TPanel;
    ScorePanel: TPanel;
    BlackScoreBar: TPanel;
    WhiteScoreBar: TPanel;
    BackImage: TImage;
    TitleImage: TImage;
    IconImage: TImage;
    ScoreBackImage: TImage;
    PoddavkiOnGlyph: TImage;
    PoddavkiOffGlyph: TImage;
    LightSquare: TImage;
    DarkSquare: TImage;
    SelectSquare: TImage;
    WhiteFish: TImage;
    BlackFish: TImage;
    WhiteKingFish: TImage;
    BlackKingFish: TImage;
    AutoModeBevel: TBevel;
    WhiteModeBevel: TBevel;
    BlackModeBevel: TBevel;
    StopBevel: TBevel;
    AboutBevel: TBevel;
    NewGameBevel: TBevel;
    ColorsBevel: TBevel;
    FlipBevel: TBevel;
    PoddavkiBevel: TBevel;
    NoModeButton: TSpeedButton;
    BlackModeButton: TSpeedButton;
    WhiteModeButton: TSpeedButton;
    AutoModeButton: TSpeedButton;
    NewGameButton: TSpeedButton;
    ColorsButton: TSpeedButton;
    FlipButton: TSpeedButton;
    CloseButton: TSpeedButton;
    PoddavkiButton: TSpeedButton;
    StopButton: TSpeedButton;
    AboutButton: TSpeedButton;
    WhiteTimer: TTimer;
    BlackTimer: TTimer;
    PauseTimer: TTimer;
    BlinkTimer: TTimer;
    WhitePopup: TPopupMenu;
    BlackPopup: TPopupMenu;
    WhiteLevel1: TMenuItem;
    WhiteLevel2: TMenuItem;
    WhiteLevel3: TMenuItem;
    WhiteLevel4: TMenuItem;
    WhiteLevel5: TMenuItem;
    WhiteLevel6: TMenuItem;
    WhiteLevel7: TMenuItem;
    WhiteLevel8: TMenuItem;
    BlackLevel1: TMenuItem;
    BlackLevel2: TMenuItem;
    BlackLevel3: TMenuItem;
    BlackLevel4: TMenuItem;
    BlackLevel5: TMenuItem;
    BlackLevel6: TMenuItem;
    BlackLevel7: TMenuItem;
    BlackLevel8: TMenuItem;
    SoundBevel: TBevel;
    SoundButton: TSpeedButton;
    procedure FormActivate(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormCreate(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FormShow(Sender: TObject);
    procedure StopButtonClick(Sender: TObject);
    procedure AutoModeButtonMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure NewGameButtonClick(Sender: TObject);
    procedure ColorsButtonClick(Sender: TObject);
    procedure FlipButtonClick(Sender: TObject);
    procedure TitleImageMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure CloseButtonClick(Sender: TObject);
    procedure WhiteModeButtonMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure BlackModeButtonMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure PoddavkiButtonClick(Sender: TObject);
    procedure AboutButtonClick(Sender: TObject);
    procedure SoundButtonClick(Sender: TObject);
    procedure BlackScoreBarMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure WhiteScoreBarMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure WhiteTimerTimer(Sender: TObject);
    procedure BlackTimerTimer(Sender: TObject);
    procedure PauseTimerTimer(Sender: TObject);
    procedure BlinkTimerTimer(Sender: TObject);
    procedure WhiteLevelClick(Sender: TObject);
    procedure BlackLevelClick(Sender: TObject);
  private
    { Картинка доски создаётся в FormCreate, её обработчики назначаются там же. }
    BoardImage: TRuzilImage;
    LastActiveForm: TCustomForm;
    procedure BoardImageMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure BoardImageMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure CreateBlinkFrames;
    procedure ActiveFormChanged(Sender: TObject);
    procedure ComputerTurn(Side: Integer; Mode, Other: TSpeedButton);
    procedure UndoMove(Sender: TObject);
    function HumanStepTo(Side, CX, CY: Integer): Boolean;
    procedure SetSetupButtons(Enabled: Boolean);
    procedure EnterHumanMode(Human: Integer);
  end;

var
  MainForm: TMainForm;

implementation

uses
  ColorsWindow;

{$R *.lfm}
{$R cursors.res}

const
  crTransparent = 114;  // обычный курсор над окном
  crEnabled = 115;      // курсор над полем, куда можно сходить
  LabelColor = $000050;
  LabelHotColor = $F42400;
  EvalScale = 122407;   // оценка стороны в начальной позиции

var
  SaveBoard: TBoard;  // позиция на время перебора: на экране показывается она
  { История партии: History[1..MoveNo] — позиции по порядку, место 0 не используется. }
  History: array of TBoard;
  MoveNo: Integer;

  Flipped: Boolean;     // доска перевёрнута (снизу чёрные)
  Thinking: Boolean;    // идёт перебор

  { Ход игрока, набираемый щелчками: Step — число отмеченных полей, Paths — сами поля. }
  Step: Integer;
  Paths: array[1..2, 1..MaxJumps + 1] of TSq;
  BlinkX, BlinkY: Integer;  // мигающее поле
  BlinkPhase: Integer;      // такт мигания: 0..15
  PendingColumn: Integer;   // вертикаль, набранная буквой с клавиатуры (1..8); 0 — нет

  { Кто ходил последним: 1 — белые (ходят чёрные), 2 — чёрные (ходят белые). }
  LastMover: Integer = 2;

  { Кадры мигания выбранной фигуры: [фигура, кадр], кадр — от клетки (0) до фигуры (8).
    Заняты строки фигур 1, 2, 11, 12, остальные пусты. }
  Frames: array[1..12, 0..8] of TImage;
  LetTop, LetBottom, DigLeft, DigRight: array[1..8] of TPanel;

  LogFileName: string; // /log=<файл> — запись позиций партии

  { Звуковые сигналы: «ваш ход» и неверная клавиша. Включает и выключает SoundButton,
    выбор хранится в реестре: настройка Sound (см. SettingsKey в ColorsWindow). }
  SoundOn: Boolean = True;

procedure IdleProcessMessages;
begin
  Application.ProcessMessages;
end;

{ Дописывает строку S в журнал (/log); без ключа журнала ничего не делает. }
procedure AppendLog(const S: string);
var
  F: TextFile;
begin
  if LogFileName = '' then
    Exit;
  AssignFile(F, LogFileName);
  if FileExists(LogFileName) then
    Append(F)
  else
    Rewrite(F);
  WriteLn(F, S);
  CloseFile(F);
end;

{ Для журнала (/log): номер позиции и сама позиция. }
procedure LogPosition(const B: TBoard);
begin
  AppendLog(IntToStr(MoveNo) + ' ' + BoardToText(B));
end;

{ Для журнала (/log): ходы корня перебора и их оценки. }
procedure LogRoot(Side: Integer; IsCapture: Boolean; Count: Integer);
var
  S: string;
  i: Integer;
begin
  if LogFileName = '' then
    Exit;
  S := Format('ROOT %d %d', [Side, Count]);
  for i := 1 to Count do
    if IsCapture then
      with CapList[Side][i] do
        S := S + Format(' %d%d-%d%d=%d', [Path[0].X, Path[0].Y, Path[Len].X, Path[Len].Y,
          RootValues[Side][i]])
    else
      with SimList[Side][i] do
        S := S + Format(' %d%d-%d%d=%d', [FX, FY, TX, TY, RootValues[Side][i]]);
  AppendLog(S);
end;

{ ---------- Отрисовка ---------- }

function SquareRect(X, Y: Integer): TRect;
begin
  if Flipped then
    Result := Rect((8 - X) * 50, (Y - 1) * 50, (9 - X) * 50, Y * 50)
  else
    Result := Rect((X - 1) * 50, (8 - Y) * 50, X * 50, (9 - Y) * 50);
end;

procedure ShowMsg(S: string);
begin
  Application.MessageBox(PChar(S + #13 + #13), PChar(Application.Title), MB_OK);
end;

{ ---------- Звук ---------- }

{ Звуковой сигнал, если звук включён. }
procedure Signal;
begin
  if SoundOn then
    Beep;
end;

{ Рисует на SoundButton динамик: с волнами — звук включён, перечёркнутый — выключен; в
  подсказке — что сделает нажатие. }
procedure ShowSound;
var
  G: TBitmap;
begin
  G := TBitmap.Create;
  try
    G.SetSize(18, 18);
    with G.Canvas do
    begin
      Brush.Color := clAqua;  // цвет прозрачности, как у остальных значков кнопок
      FillRect(0, 0, 18, 18);
      Pen.Color := clMaroon;
      Brush.Color := clMaroon;
      Polygon([Point(2, 6), Point(5, 6), Point(9, 2), Point(9, 15), Point(5, 11),
        Point(2, 11)]);
      Brush.Style := bsClear;
      if SoundOn then
      begin
        Arc(6, 5, 13, 12, 13, 12, 13, 5);
        Arc(5, 2, 17, 15, 17, 15, 17, 2);
      end
      else
      begin
        Pen.Width := 2;
        MoveTo(11, 6);
        LineTo(16, 11);
        MoveTo(16, 6);
        LineTo(11, 11);
      end;
    end;
    G.TransparentColor := clAqua;
    G.Transparent := True;
    MainForm.SoundButton.Glyph := G;
  finally
    G.Free;
  end;
  if SoundOn then
    MainForm.SoundButton.Hint := 'Выключить звук Ctrl+M'
  else
    MainForm.SoundButton.Hint := 'Включить звук Ctrl+M';
end;

{ Рисует пустые клетки доски (тёмные и светлые 50×50) и подписывает координаты по краям: на
  перевёрнутой доске — в обратном порядке. Фигуры поверх рисует DrawPieces. }
procedure DrawBoard;
var
  i, j: Integer;
begin
  for i := 1 to 8 do
    for j := 1 to 8 do
      if (i + j) mod 2 <> 0 then
        MainForm.BoardImage.Canvas.StretchDraw(Rect((i - 1) * 50, (j - 1) * 50, i * 50, j * 50),
          MainForm.DarkSquare.Picture.Graphic)
      else
        MainForm.BoardImage.Canvas.StretchDraw(Rect((i - 1) * 50, (j - 1) * 50, i * 50, j * 50),
          MainForm.LightSquare.Picture.Graphic);
  if Flipped then
    for i := 1 to 8 do
    begin
      DigLeft[i].Caption := IntToStr(9 - i);
      DigRight[i].Caption := IntToStr(9 - i);
      LetTop[i].Caption := Chr(Ord('a') + 8 - i);
      LetBottom[i].Caption := Chr(Ord('a') + 8 - i);
    end
  else
    for i := 1 to 8 do
    begin
      DigLeft[i].Caption := IntToStr(i);
      DigRight[i].Caption := IntToStr(i);
      LetTop[i].Caption := Chr(Ord('a') + i - 1);
      LetBottom[i].Caption := Chr(Ord('a') + i - 1);
    end;
end;

{ Картинка фигуры по значению клетки; пустая клетка — nil. }
function PieceImage(V: Integer): TImage;
begin
  case V of
    1: Result := MainForm.WhiteFish;
    2: Result := MainForm.BlackFish;
    11: Result := MainForm.WhiteKingFish;
    12: Result := MainForm.BlackKingFish;
  else
    Result := nil;
  end;
end;

procedure DrawPiece(X, Y: Integer; const B: TBoard);
var
  Img: TImage;
begin
  Img := PieceImage(B[X, Y]);
  if Img <> nil then
    MainForm.BoardImage.Canvas.StretchDraw(SquareRect(X, Y), Img.Picture.Graphic);
end;

{ Рисует фигуры позиции B поверх клеток. }
procedure DrawPieces(const B: TBoard);
var
  i, j: Integer;
begin
  MainForm.BoardImage.Canvas.Brush.Style := bsSolid;
  for i := 1 to 8 do
    for j := 1 to 8 do
      DrawPiece(i, j, B);
end;

{ Добавляет позицию B в историю партии и в журнал (/log), если она новая: начальная
  позиция начинает историю заново, повтор последней не добавляется. }
procedure RecordPosition(const B: TBoard);
var
  Start: TBoard;
begin
  InitBoard(Start);
  if BoardsEqual(B, Start) then
    MoveNo := 0;
  if (MoveNo = 0) or not BoardsEqual(History[MoveNo], B) then
  begin
    Inc(MoveNo);
    if MoveNo >= Length(History) then
      SetLength(History, 2 * Length(History) + 256);
    CopyBoard(History[MoveNo], B);
    LogPosition(B);
  end;
end;

{ Перекрашивает полоски перевеса и значки кнопок режимов под цвет шашек: белые — цвет фона
  картинки шашки, сдвинутый множителями ползунков окна цветов, чёрные — его отражение
  относительно фона. }
procedure ShowModeColors;

  procedure Fill(Button: TSpeedButton; X, Y: Integer; Color: TColor);
  begin
    with Button.Glyph.Canvas do
    begin
      Brush.Color := Color;
      FloodFill(X, Y, clBlack, fsBorder);
    end;
  end;

var
  C, CW, CB: TColor;
  R, G, Bl: Byte;
  Auto: TSpeedButton;
begin
  C := MainForm.WhiteFish.Canvas.Pixels[1, 1];
  R := Min(255 - GetRValue(C), GetRValue(C));
  G := Min(255 - GetGValue(C), GetGValue(C));
  Bl := Min(255 - GetBValue(C), GetBValue(C));
  R := Byte(Round(GetRValue(C) + R * (ColorsForm.RedBar.Position / 10)));
  G := Byte(Round(GetGValue(C) + G * (ColorsForm.GreenBar.Position / 10)));
  Bl := Byte(Round(GetBValue(C) + Bl * (ColorsForm.BlueBar.Position / 10)));
  CW := RGB(R, G, Bl);
  if CW = MainForm.WhiteScoreBar.Color then
    Exit;
  CB := MirrorColor(CW, C);
  MainForm.WhiteScoreBar.Color := CW;
  MainForm.BlackScoreBar.Color := CB;
  Fill(MainForm.WhiteModeButton, 3, 3, CW);
  Fill(MainForm.BlackModeButton, 3, 3, CB);
  Auto := MainForm.AutoModeButton;
  Fill(Auto, 3, 3, CW);
  Fill(Auto, Auto.Glyph.Width - 3, Auto.Glyph.Height - 3, CB);
end;

{ Высота и подсказки полосок перевеса по оценкам сторон в позиции B. }
procedure ShowScores(const B: TBoard);
var
  SW, SB: Integer;
begin
  SideScores(B, SW, SB);
  MainForm.WhiteScoreBar.Height := Round(Abs(SW) * 70.58823529411765 / EvalScale);
  MainForm.WhiteScoreBar.Top := MainForm.ScorePanel.Height - MainForm.WhiteScoreBar.Height - 6;
  MainForm.BlackScoreBar.Height := Round(Abs(SB) * 70.58823529411765 / EvalScale);
  MainForm.BlackScoreBar.Top := MainForm.ScorePanel.Height - MainForm.BlackScoreBar.Height - 6;
  MainForm.WhiteScoreBar.Hint := FloatToStrF(SW / EvalScale, ffFixed, 10, 4);
  MainForm.BlackScoreBar.Hint := FloatToStrF(SB / EvalScale, ffFixed, 10, 4);
  MainForm.ScorePanel.Repaint;
end;

{ Показывает позицию B: фигуры, история партии, цвета кнопок режимов, полоски перевеса. }
procedure ShowBoard(const B: TBoard);
begin
  DrawPieces(B);
  RecordPosition(B);
  ShowModeColors;
  ShowScores(B);
end;

{ Подсвечивает путь хода от (X1, Y1) до (X2, Y2) включительно и рисует фигуры поверх. }
procedure MarkPath(X1, Y1, X2, Y2: Integer);
var
  k, X, Y: Integer;
begin
  MainForm.BoardImage.Canvas.StretchDraw(SquareRect(X1, Y1), MainForm.SelectSquare.Picture.Graphic);
  DrawPiece(X1, Y1, Board);
  for k := 1 to Abs(X2 - X1) do
  begin
    X := Abs(X2 - X1) * k div (X2 - X1) + X1;
    Y := Abs(Y2 - Y1) * k div (Y2 - Y1) + Y1;
    MainForm.BoardImage.Canvas.StretchDraw(SquareRect(X, Y), MainForm.SelectSquare.Picture.Graphic);
    DrawPiece(X, Y, Board);
  end;
end;

{ Закрашивает поля пути пустой клеткой. }
procedure ErasePath(X1, Y1, X2, Y2: Integer);
var
  k, X, Y: Integer;
begin
  MainForm.BoardImage.Canvas.StretchDraw(SquareRect(X1, Y1), MainForm.DarkSquare.Picture.Graphic);
  for k := 1 to Abs(X2 - X1) do
  begin
    X := Abs(X2 - X1) * k div (X2 - X1) + X1;
    Y := Abs(Y2 - Y1) * k div (Y2 - Y1) + Y1;
    MainForm.BoardImage.Canvas.StretchDraw(SquareRect(X, Y), MainForm.DarkSquare.Picture.Graphic);
  end;
end;

{ Ход из позиции A в позицию B сделан дамкой без взятия: фигур столько же, шашки на месте. }
function QuietKingMove(const A, B: TBoard): Boolean;
var
  i, j, NA, NB: Integer;
begin
  Result := True;
  NA := 0;
  NB := 0;
  for i := 1 to 8 do
    for j := 1 to 8 do
    begin
      if A[i, j] <> 0 then
        Inc(NA);
      if B[i, j] <> 0 then
        Inc(NB);
      if ((A[i, j] = 1) or (A[i, j] = 2) or (B[i, j] = 1) or (B[i, j] = 2))
        and (A[i, j] <> B[i, j]) then
        Result := False;
    end;
  if NA <> NB then
    Result := False;
end;

{ Ничья по правилам: позиция повторилась в третий раз при той же очереди хода или 15 ходов
  подряд каждая сторона ходила только дамками, без взятий. Возвращает текст сообщения,
  '' — не ничья. }
function DrawReason: string;
var
  k, n: Integer;
begin
  Result := '';
  if MoveNo < 2 then
    Exit;
  n := 0;
  k := MoveNo;
  while k >= 1 do
  begin
    if BoardsEqual(History[k], History[MoveNo]) then
      Inc(n);
    Dec(k, 2);
  end;
  if n >= 3 then
    Exit('Ничья: позиция повторилась трижды.');
  n := 0;
  k := MoveNo;
  while (k > 1) and QuietKingMove(History[k - 1], History[k]) do
  begin
    Inc(n);
    Dec(k);
  end;
  if n >= 30 then
    Result := 'Ничья: 15 ходов только дамками, без взятий.';
end;

{ Начальная позиция на доске; первыми ходят белые. }
procedure ResetBoard;
begin
  DrawBoard;
  NewBoard;
  ShowBoard(Board);
  LastMover := 2;
end;

{ Перерисовывает доску с показанной позицией: во время перебора — позицией до хода
  компьютера (SaveBoard), иначе текущей. }
procedure RedrawBoard;
begin
  DrawBoard;
  if Thinking then
    ShowBoard(SaveBoard)
  else
    ShowBoard(Board);
end;

{ Конец партии: в игре с человеком — сообщение Msg, затем новая партия. Белыми начинает
  компьютер, если играет ими, иначе ход за человеком. }
procedure EndGame(const Msg: string);
begin
  with MainForm do
  begin
    if BlackModeButton.Down or WhiteModeButton.Down then
    begin
      ShowMsg(Msg);
      BlackModeButton.Enabled := True;
      WhiteModeButton.Enabled := True;
    end;
    ResetBoard;
    Step := 0;
    if WhiteModeButton.Down then
    begin
      CaptureMoves(1, CapCnt[1], CapList[1]);
      SimpleMoves(1, SimCnt[1], SimList[1]);
    end
    else
      WhiteTimer.Enabled := True;
  end;
end;

{ Ничья по правилам в идущей партии — конец партии. True — партия закончилась. }
function CheckDraw: Boolean;
var
  Why: string;
begin
  Result := False;
  with MainForm do
    if not (BlackModeButton.Down or WhiteModeButton.Down or AutoModeButton.Down) then
      Exit;
  Why := DrawReason;
  if Why = '' then
    Exit;
  EndGame(Why);
  Result := True;
end;

{ Сторона, за которую человек может ходить сейчас: компьютер не думает и не показывает свой
  ход; 0 — не ход человека. }
function HumanToMove: Integer;
begin
  Result := 0;
  with MainForm do
    if not WhiteTimer.Enabled and not BlackTimer.Enabled and not PauseTimer.Enabled then
      if BlackModeButton.Down and (LastMover = 1) then
        Result := 2
      else if WhiteModeButton.Down and (LastMover <> 1) then
        Result := 1;
end;

{ Ход компьютера за сторону Side. False — ходить нечем. }
function ComputerMove(Side: Integer): Boolean;
var
  BestV, k, t: Integer;
begin
  Result := True;
  if not FixedSeed then
    DRandomize;
  CopyBoard(SaveBoard, Board);
  StopSearch := False;
  Thinking := True;
  BestV := Search(Side, Level(Side));
  Thinking := False;
  if StopSearch then
    Exit;
  CopyBoard(Board, SaveBoard);
  CaptureMoves(Side, CapCnt[Side], CapList[Side]);
  if CapCnt[Side] = 0 then
  begin
    SimpleMoves(Side, SimCnt[Side], SimList[Side]);
    if SimCnt[Side] = 0 then
      Exit(False);
    LogRoot(Side, False, SimCnt[Side]);
    k := PickRootMove(Side, SimCnt[Side], BestV);
    with SimList[Side][k] do
      MarkPath(FX, FY, TX, TY);
    ApplySimple(Side, SimList[Side][k]);
  end
  else
  begin
    LogRoot(Side, True, CapCnt[Side]);
    k := PickRootMove(Side, CapCnt[Side], BestV);
    with CapList[Side][k] do
      for t := 1 to Len do
        MarkPath(Path[t - 1].X, Path[t - 1].Y, Path[t].X, Path[t].Y);
    ApplyCapture(Side, CapList[Side][k]);
  end;
end;

{ ---------- Ход игрока ---------- }

{ Можно ли отметить поле (X, Y) очередным (AStep-м) полем хода стороны Side. Index — номер
  хода в списке, Final — ход этим полем завершён. }
function CheckStep(Side, X, Y, AStep: Integer; out Index: Integer; out Final: Boolean): Boolean;
var
  i, k: Integer;
begin
  Result := False;
  if CapCnt[Side] = 0 then
  begin
    if SimCnt[Side] > 0 then
    begin
      i := 1;
      while (i <= SimCnt[Side]) and not Result do
      begin
        if (AStep = 0) and (SimList[Side][i].FX = X) and (SimList[Side][i].FY = Y) then
        begin
          Result := True;
          Final := False;
          Index := i;
        end;
        if (AStep = 1) and (SimList[Side][i].TX = X) and (SimList[Side][i].TY = Y)
          and (SimList[Side][i].FX = Paths[Side, AStep].X)
          and (SimList[Side][i].FY = Paths[Side, AStep].Y) then
        begin
          Result := True;
          Final := True;
          Index := i;
        end;
        Inc(i);
      end;
    end;
  end
  else
  begin
    i := 1;
    while (i <= CapCnt[Side]) and not Result do
    begin
      Result := True;
      for k := 1 to AStep do
        if (CapList[Side][i].Path[k - 1].X <> Paths[Side, k].X)
          or (CapList[Side][i].Path[k - 1].Y <> Paths[Side, k].Y) then
          Result := False;
      if (CapList[Side][i].Path[AStep].X <> X) or (CapList[Side][i].Path[AStep].Y <> Y) then
        Result := False;
      Index := i;
      Final := AStep = CapList[Side][i].Len;
      Inc(i);
    end;
  end;
end;

{ Можно ли сейчас отметить поле (X, Y) стороной Side: очередным полем набираемого хода или
  началом нового. Index и Final — как у CheckStep. }
function CanStep(Side, X, Y: Integer; out Index: Integer; out Final: Boolean): Boolean;
begin
  Result := CheckStep(Side, X, Y, Step, Index, Final) or CheckStep(Side, X, Y, 0, Index, Final);
end;

{ Поле под точкой (X, Y) картинки доски с учётом переворота; вне доски — номера за 1..8. }
procedure PointToSquare(X, Y: Integer; out CX, CY: Integer);
begin
  if Flipped then
  begin
    CX := (399 - X) div 50 + 1;
    CY := 8 - (399 - Y) div 50;
  end
  else
  begin
    CX := X div 50 + 1;
    CY := 8 - Y div 50;
  end;
end;

procedure ApplyHumanMove(Side, Index: Integer);
begin
  if CapCnt[Side] = 0 then
    ApplySimple(Side, SimList[Side][Index])
  else
    ApplyCapture(Side, CapList[Side][Index]);
end;

procedure StartBlink(X, Y: Integer);
begin
  BlinkX := X;
  BlinkY := Y;
  BlinkPhase := 0;
  MainForm.BlinkTimer.Enabled := True;
end;

procedure StopBlink;
begin
  MainForm.BlinkTimer.Enabled := False;
end;

{ Сброс набираемого хода: мигание и отмеченные поля. }
procedure CancelMove;
begin
  StopBlink;
  Step := 0;
  DrawBoard;
  ShowBoard(Board);
end;

{ Подсвечивает подписи вертикали Col и горизонтали Row (номера по экрану, слева и снизу),
  остальные гасит; номер за 1..8 — ничего не подсвечивать. }
procedure HighlightCoords(Col, Row: Integer);
var
  k: Integer;
begin
  for k := 1 to 8 do
  begin
    if (LetTop[k].Font.Color <> LabelColor) and (k <> Col) then
    begin
      LetTop[k].Font.Color := LabelColor;
      LetBottom[k].Font.Color := LabelColor;
    end;
    if (DigLeft[k].Font.Color <> LabelColor) and (k <> Row) then
    begin
      DigLeft[k].Font.Color := LabelColor;
      DigRight[k].Font.Color := LabelColor;
    end;
  end;
  if (Col in [1..8]) and (Row in [1..8]) then
  begin
    if LetTop[Col].Font.Color <> LabelHotColor then
    begin
      LetTop[Col].Font.Color := LabelHotColor;
      LetBottom[Col].Font.Color := LabelHotColor;
    end;
    if DigLeft[Row].Font.Color <> LabelHotColor then
    begin
      DigLeft[Row].Font.Color := LabelHotColor;
      DigRight[Row].Font.Color := LabelHotColor;
    end;
  end;
end;

{ TRuzilImage }

procedure TRuzilImage.CMMouseLeave(var Message: TLMessage);
begin
  inherited;
  MainForm.BoardImage.Cursor := crTransparent;
  HighlightCoords(0, 0);
end;

{ Недоступная кнопка в Delphi рисуется рельефной серой картинкой, LCL же почти не меняет
  тёмный значок. Добавляет второй кадр глифа в стиле Delphi: светлый контур со сдвигом
  на пиксель и серый поверх, фон — прозрачный цвет глифа (левый нижний пиксель). }
procedure AddDisabledGlyph(B: TSpeedButton);
var
  Src, Dst: TBitmap;
  W, H, X, Y: Integer;
  Back, C: TColor;
  Mask: array of array of Boolean;
begin
  Src := B.Glyph;
  W := Src.Width;
  H := Src.Height;
  if (W = 0) or (B.NumGlyphs <> 1) then
    Exit;
  Back := Src.Canvas.Pixels[0, H - 1];
  SetLength(Mask, W + 1, H + 1);
  for X := 0 to W - 1 do
    for Y := 0 to H - 1 do
    begin
      C := ColorToRGB(Src.Canvas.Pixels[X, Y]);
      Mask[X, Y] := (C <> ColorToRGB(Back)) and (C <> clWhite);
    end;
  Dst := TBitmap.Create;
  try
    Dst.PixelFormat := pf24bit;
    Dst.SetSize(W * 2, H);
    for X := 0 to W - 1 do
      for Y := 0 to H - 1 do
      begin
        Dst.Canvas.Pixels[X, Y] := Src.Canvas.Pixels[X, Y];
        Dst.Canvas.Pixels[W + X, Y] := Back;
      end;
    for X := 0 to W - 2 do
      for Y := 0 to H - 2 do
        if Mask[X, Y] then
          Dst.Canvas.Pixels[W + X + 1, Y + 1] := clBtnHighlight;
    for X := 0 to W - 1 do
      for Y := 0 to H - 1 do
        if Mask[X, Y] then
          Dst.Canvas.Pixels[W + X, Y] := clBtnShadow;
    Dst.TransparentColor := Back;
    Dst.Transparent := True;
    B.Glyph := Dst;
    B.NumGlyphs := 2;
  finally
    Dst.Free;
  end;
end;

{ TMainForm }

procedure TMainForm.ActiveFormChanged(Sender: TObject);
begin
  { Как в Delphi: OnActivate — только при переходе фокуса из другого окна этой программы
    (и при первом показе), но не при возврате из чужого приложения или окна сообщения. }
  if Screen.ActiveForm = nil then
    Exit;
  if (Screen.ActiveForm = Self) and (LastActiveForm <> Self) then
    FormActivate(Self);
  LastActiveForm := Screen.ActiveForm;
end;

{ Кадры мигания каждой фигуры: k-й кадр — тёмная клетка, на которой точки фигуры смешаны с
  клеткой в доле k/8. Фон картинки — точки с красной составляющей как у её пикселя (1, 1):
  туда перекраска в окне цветов не пишет, там всегда фон шаблона. Кадры пересоздаются после
  каждой смены цветов: прежние освобождаются. }
procedure TMainForm.CreateBlinkFrames;
const
  Pieces: array[1..4] of Integer = (2, 1, 12, 11);
var
  p, V, k, X, Y: Integer;
  Src, Dst: TImage;
  C: TColor;
  BgR, PixR, PixG, PixB, R0, G0, B0: Byte;
begin
  for p := 1 to 4 do
  begin
    V := Pieces[p];
    Src := PieceImage(V);
    BgR := GetRValue(Src.Canvas.Pixels[1, 1]);
    for k := 0 to 8 do
    begin
      Frames[V, k].Free;
      Dst := TImage.Create(Self);
      Frames[V, k] := Dst;
      Dst.Picture := DarkSquare.Picture;
      for X := 2 to ColorsForm.WhitePreview.Width - 3 do
        for Y := 8 to ColorsForm.WhitePreview.Height - 9 do
        begin
          C := Src.Canvas.Pixels[X, Y];
          PixR := GetRValue(C);
          PixG := GetGValue(C);
          PixB := GetBValue(C);
          if PixR <> BgR then
          begin
            C := DarkSquare.Canvas.Pixels[X, Y];
            R0 := GetRValue(C);
            G0 := GetGValue(C);
            B0 := GetBValue(C);
            Dst.Canvas.Pixels[X, Y] := RGB(Byte(Round(R0 + (PixR - R0) * k / 8)),
              Byte(Round(G0 + (PixG - G0) * k / 8)), Byte(Round(B0 + (PixB - B0) * k / 8)));
          end;
        end;
    end;
  end;
end;

{ Готовит текстуры клеток и подсветки, берёт цвета из окна настроек и начинает новую
  партию. Вызывается из ActiveFormChanged: при первом показе и при переходе из другого окна
  программы, в том числе после закрытия окна настройки цветов. }
procedure TMainForm.FormActivate(Sender: TObject);
var
  X, Y, i, j: Integer;
  C: TColor;
  R, G, B: Byte;
  T: Double;
begin
  for X := 0 to 49 do
    for Y := 0 to 49 do
    begin
      C := DarkSquare.Canvas.Pixels[X, Y];
      R := GetRValue(C);
      G := GetGValue(C);
      B := GetBValue(C);
      LightSquare.Canvas.Pixels[X, Y] := RGB(Byte(Round(R + (255 - R) * 0.65)),
        Byte(Round(G + (255 - G) * 0.65)), Byte(Round(B + (255 - B) * 0.65)));
      T := 1 - Power(Sqrt(Min(1.0, Sqr(Abs(X - 24.5) / 24.5) + Sqr(Abs(Y - 24.5) / 24.5))),
        1.01) / 2;
      SelectSquare.Canvas.Pixels[X, Y] := RGB(Byte(Round(R + (255 - R) * T)),
        Byte(Round((1 - T) * G)), Byte(Round((1 - T) * B)));
    end;
  for i := 1 to 12 do
    for j := 1 to 11 do
      BackImage.Canvas.StretchDraw(Rect((i - 1) * 50, (j - 1) * 50, i * 50, j * 50),
        LightSquare.Picture.Graphic);
  for i := 1 to 2 do
    for j := 1 to 3 do
      ScoreBackImage.Canvas.StretchDraw(Rect((i - 1) * 50, (j - 1) * 50, i * 50, j * 50),
        LightSquare.Picture.Graphic);
  IconImage.Picture.Bitmap := AboutButton.Glyph;
  WhiteModeButton.Glyph := BlackModeButton.Glyph;
  PoddavkiButton.Glyph := PoddavkiOffGlyph.Picture.Bitmap;
  ColorsForm.FormShow(Sender);
  ColorsForm.OkButtonClick(Sender);
  CreateBlinkFrames;
  DrawBoard;
  NewBoard;
  ShowBoard(Board);
  Step := 0;
  CaptureMoves(1, CapCnt[1], CapList[1]);
  SimpleMoves(1, SimCnt[1], SimList[1]);
end;

procedure TMainForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  Closing := True;
end;

{ Ключи запуска (/fixedseed — ряд случайных чисел с нуля, /log=<файл> — журнал партии), звук
  из настроек, картинка доски и подписи координат, курсоры, серые глифы недоступных кнопок,
  галочки уровней по умолчанию. Текстуры, цвета и новая партия — в FormActivate. }
procedure TMainForm.FormCreate(Sender: TObject);
var
  k: Integer;

  function MakeLabel(ALeft, ATop, AHeight: Integer; const ACaption: string): TPanel;
  begin
    Result := TPanel.Create(Self);
    Result.Font.Color := LabelColor;
    Result.Left := 1;
    Result.Width := 9;
    Result.Height := AHeight;
    Result.BevelOuter := bvNone;
    Result.Color := PoddavkiOnGlyph.Canvas.Pixels[1, 1];  // угловая точка значка — цвет фона окна
    Result.Font.Name := 'MS Sans Serif';  // шрифт по умолчанию в Delphi 5
    Result.Font.Size := 12;
    Result.Font.Style := [fsBold];
    Result.Caption := ACaption;
    Result.Top := ATop;
    Result.Left := ALeft;
    Result.Parent := Self;
    Result.Cursor := crTransparent;
  end;

  { Курсор игры над рамкой окна, кнопками и полосками; над доской курсор ставит
    BoardImageMouseMove. }
  procedure SetTransparentCursor(const Controls: array of TControl);
  var
    i: Integer;
  begin
    for i := 0 to High(Controls) do
      Controls[i].Cursor := crTransparent;
  end;

begin
  for k := 1 to ParamCount do
    if SameText(ParamStr(k), '/fixedseed') then
    begin
      FixedSeed := True;
      DRandSeed := 0;
    end
    else if SameText(Copy(ParamStr(k), 1, 5), '/log=') then
      LogFileName := Copy(ParamStr(k), 6, MaxInt);
  SoundOn := ReadSetting('Sound', '1') <> '0';
  ShowSound;

  BoardImage := TRuzilImage.Create(Self);
  BoardImage.Left := 1;
  BoardImage.Top := 1;
  BoardImage.Width := 400;
  BoardImage.Height := 400;
  BoardImage.Parent := BoardPanel;
  BoardImage.OnMouseMove := BoardImageMouseMove;
  BoardImage.OnMouseDown := BoardImageMouseDown;
  for k := 1 to 8 do
  begin
    DigLeft[k] := MakeLabel(18, (9 - k) * 50 + 20, 13, IntToStr(k));
    DigRight[k] := MakeLabel(444, (9 - k) * 50 + 20, 13, IntToStr(k));
    LetTop[k] := MakeLabel(k * 50 + 5, 28, 20, Chr(Ord('a') + k - 1));
    LetBottom[k] := MakeLabel(k * 50 + 5, 453, 20, Chr(Ord('a') + k - 1));
  end;
  Screen.Cursors[crTransparent] := LoadCursor(HInstance, 'TRANSPARENTCURSOR');
  Screen.Cursors[crEnabled] := LoadCursor(HInstance, 'ENABLEDCURSOR');
  SetTransparentCursor([TitleLabel, WhiteScoreBar, BlackScoreBar,
    BlackModeButton, WhiteModeButton, AutoModeButton, NewGameButton, ColorsButton, FlipButton,
    AboutButton, CloseButton, PoddavkiButton, StopButton, SoundButton,
    AutoModeBevel, WhiteModeBevel, BlackModeBevel, StopBevel, AboutBevel, NewGameBevel,
    ColorsBevel, FlipBevel, PoddavkiBevel, SoundBevel,
    BackImage, TitleImage, IconImage, ScoreBackImage, MainPanel, BoardPanel, ScorePanel]);
  // глифы кнопок режимов перекрашиваются под цвет шашек — их не трогаем
  AddDisabledGlyph(NewGameButton);
  AddDisabledGlyph(ColorsButton);
  AddDisabledGlyph(FlipButton);
  AddDisabledGlyph(AboutButton);
  AddDisabledGlyph(StopButton);
  // галочка — на уровне по умолчанию из Engine
  for k := 1 to WhitePopup.Items.Count do
    WhitePopup.Items[k - 1].Checked := k = WhiteLevel;
  for k := 1 to BlackPopup.Items.Count do
    BlackPopup.Items[k - 1].Checked := k = BlackLevel;
  Screen.OnActiveFormChange := ActiveFormChanged;
  SearchIdle := IdleProcessMessages;
end;

{ Отмена хода (Ctrl+Z, Alt+Backspace): ход человека вместе с ответом компьютера — на две
  позиции назад, промежуточная видна 100 мс. Со второй позиции — к началу партии; если
  белыми играет компьютер, он ходит заново. Возвращённая позиция заново пишется в журнал
  (/log): ShowBoard добавляет её в историю под прежним номером. }
procedure TMainForm.UndoMove(Sender: TObject);
var
  Target: Integer;
  ToStart: Boolean;
begin
  ToStart := MoveNo = 2;
  if ToStart then
    Target := 1
  else
  begin
    Dec(MoveNo);
    CopyBoard(Board, History[MoveNo]);
    DrawBoard;
    ShowBoard(Board);
    BoardImage.Repaint;
    Sleep(100);
    Target := MoveNo - 1;
  end;
  CopyBoard(Board, History[Target]);
  MoveNo := Target - 1;
  DrawBoard;
  ShowBoard(Board);
  CaptureMoves(1, CapCnt[1], CapList[1]);
  CaptureMoves(2, CapCnt[2], CapList[2]);
  SimpleMoves(1, SimCnt[1], SimList[1]);
  SimpleMoves(2, SimCnt[2], SimList[2]);
  BoardImage.Repaint;
  if ToStart then
  begin
    LastMover := 2;
    if BlackModeButton.Down then
    begin
      NoModeButton.Down := True;
      BlackModeButtonMouseDown(Sender, mbLeft, [], 1, 1);
    end;
  end;
end;

procedure TMainForm.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  S: TShiftState;
  Side: Integer;
begin
  // в LCL Shift бывает дополнен состоянием Caps/NumLock — сравниваем как в Delphi
  S := Shift * [ssShift, ssAlt, ssCtrl, ssLeft, ssRight, ssMiddle, ssDouble];

  // отмена хода: Ctrl+Z или Alt+Backspace
  if BlackModeButton.Enabled and WhiteModeButton.Enabled and (MoveNo >= 2)
    and (((Key = VK_BACK) and (S = [ssAlt])) or ((Key = Ord('Z')) and (S = [ssCtrl]))) then
  begin
    UndoMove(Sender);
    Key := VK_ESCAPE;
  end;
  // Escape (и после отмены хода): сброс набираемого хода и набранной буквы
  if Key = VK_ESCAPE then
  begin
    PendingColumn := 0;
    if HumanToMove <> 0 then
    begin
      CancelMove;
      HighlightCoords(0, 0);
      BoardImage.Cursor := crTransparent;
    end;
  end;

  if ssCtrl in S then
  begin
    case Key of
      Ord('A'): if AutoModeButton.Enabled then AutoModeButtonMouseDown(Sender, mbLeft, [], 1, 1);
      Ord('W'): if WhiteModeButton.Enabled then WhiteModeButtonMouseDown(Sender, mbLeft, [], 1, 1);
      Ord('B'): if BlackModeButton.Enabled then BlackModeButtonMouseDown(Sender, mbLeft, [], 1, 1);
      Ord('N'): if NewGameButton.Enabled then NewGameButtonClick(Sender);
      Ord('C'): if ColorsButton.Enabled then ColorsButtonClick(Sender);
      Ord('O'): if FlipButton.Enabled then FlipButtonClick(Sender);
      Ord('G'): if PoddavkiButton.Enabled then PoddavkiButtonClick(Sender);
      Ord('S'): if StopButton.Enabled then StopButtonClick(Sender);
      Ord('M'): SoundButtonClick(Sender);
    end;
    Exit;
  end;

  // ход с клавиатуры: буква вертикали, затем цифра горизонтали (в том числе на цифровом блоке)
  if not WhiteModeButton.Down and not BlackModeButton.Down
    and (InRange(Key, Ord('A'), Ord('H')) or InRange(Key, VK_NUMPAD1, VK_NUMPAD9)
    or InRange(Key, Ord('1'), Ord('8'))) then
  begin
    Signal;
    Exit;
  end;
  if InRange(Key, Ord('A'), Ord('H')) then
    PendingColumn := Key - Ord('A') + 1;
  if InRange(Key, VK_NUMPAD1, VK_NUMPAD9) then
    Key := Key - VK_NUMPAD1 + Ord('1');
  if InRange(Key, Ord('1'), Ord('8')) and (PendingColumn <> 0) then
  begin
    Side := HumanToMove;
    if Side <> 0 then
      HumanStepTo(Side, PendingColumn, Key - Ord('0'));
    PendingColumn := 0;
  end;
end;

procedure TMainForm.FormShow(Sender: TObject);
begin
  MainForm.Left := (Screen.Width - MainForm.Width) div 2;
  MainForm.Top := (Screen.Height - MainForm.Height - 28) div 2;
end;

{ Остановка: снимает режим игры; во время перебора просит его прерваться. }
procedure TMainForm.StopButtonClick(Sender: TObject);
begin
  BoardImage.Cursor := crTransparent;
  BlackModeButton.Enabled := True;
  WhiteModeButton.Enabled := True;
  AutoModeButton.Enabled := True;
  SetSetupButtons(True);
  BlinkTimer.Enabled := False;
  NoModeButton.Down := True;
  RedrawBoard;
  if Thinking then
    StopSearch := True
  else if BlackModeButton.Down or WhiteModeButton.Down then
  begin
    if PauseTimer.Enabled then
      PauseTimerTimer(Sender);
  end
  else
    StopSearch := True;
end;

procedure TMainForm.AutoModeButtonMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if not AutoModeButton.Down then
  begin
    AutoModeButton.Down := True;
    BlackModeButton.Enabled := False;
    WhiteModeButton.Enabled := False;
    SetSetupButtons(False);
    StopSearch := False;
    BlinkTimer.Enabled := False;
    if not Thinking then
      PauseTimer.Enabled := True;
  end;
end;

procedure TMainForm.NewGameButtonClick(Sender: TObject);
begin
  WhiteTimer.Enabled := False;
  BlackTimer.Enabled := False;
  PauseTimer.Enabled := False;
  BlinkTimer.Enabled := False;
  ResetBoard;
  StopSearch := False;
  if BlackModeButton.Down or AutoModeButton.Down then
    WhiteTimer.Enabled := True;
end;

procedure TMainForm.ColorsButtonClick(Sender: TObject);
begin
  NoModeButton.Down := True;
  ColorsForm.BackImage.Picture := BackImage.Picture;
  ColorsForm.ShowModal;
  DrawBoard;
  ShowBoard(Board);
  MainForm.Repaint;
  if ColorsForm.OkPressed then
    CreateBlinkFrames;
end;

procedure TMainForm.FlipButtonClick(Sender: TObject);
begin
  Flipped := not Flipped;
  RedrawBoard;
  BoardImage.Repaint;
end;

{ Перетаскивание окна без рамки за полосу заголовка. }
procedure TMainForm.TitleImageMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  ReleaseCapture;
  SendMessage(Handle, WM_SYSCOMMAND, $F012, 0);
end;

procedure TMainForm.CloseButtonClick(Sender: TObject);
begin
  Close;
end;

{ Кнопки, доступные только без режима игры: «Заново», цвета, поддавки. }
procedure TMainForm.SetSetupButtons(Enabled: Boolean);
begin
  NewGameButton.Enabled := Enabled;
  ColorsButton.Enabled := Enabled;
  PoddavkiButton.Enabled := Enabled;
end;

{ Начало игры человека за сторону Human (1 — белые, 2 — чёрные, доска переворачивается):
  если сейчас ход компьютера, он ходит, иначе готовятся ходы человека. }
procedure TMainForm.EnterHumanMode(Human: Integer);
begin
  SetSetupButtons(False);
  BlinkTimer.Enabled := False;
  Flipped := Human = 2;
  DrawBoard;
  ShowBoard(Board);
  StopSearch := False;
  if LastMover = Human then  // человек ходил последним — ход компьютера
    if Human = 1 then
      BlackTimer.Enabled := True
    else
      WhiteTimer.Enabled := True
  else
  begin
    Step := 0;
    CaptureMoves(Human, CapCnt[Human], CapList[Human]);
    SimpleMoves(Human, SimCnt[Human], SimList[Human]);
  end;
end;

{ Игра за белых: компьютер играет чёрными. }
procedure TMainForm.WhiteModeButtonMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if not WhiteModeButton.Down then
  begin
    WhiteModeButton.Down := True;
    EnterHumanMode(1);
  end;
end;

{ Игра за чёрных: компьютер играет белыми, доска переворачивается. }
procedure TMainForm.BlackModeButtonMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if not BlackModeButton.Down then
  begin
    BlackModeButton.Down := True;
    EnterHumanMode(2);
  end;
end;

procedure TMainForm.PoddavkiButtonClick(Sender: TObject);
begin
  LastMover := 2;
  if Poddavki then
  begin
    Poddavki := False;
    PoddavkiButton.Hint := 'Поддавки Ctrl+G';
    Application.Title := 'Шашки';
    TitleLabel.Caption := 'Шашки';
    PoddavkiButton.Glyph := PoddavkiOffGlyph.Picture.Bitmap;
  end
  else
  begin
    Poddavki := True;
    PoddavkiButton.Hint := 'Шашки Ctrl+G';
    Application.Title := 'Поддавки';
    TitleLabel.Caption := 'Поддавки';
    PoddavkiButton.Glyph := PoddavkiOnGlyph.Picture.Bitmap;
  end;
  NewBoard;
  DrawBoard;
  ShowBoard(Board);
end;

procedure TMainForm.AboutButtonClick(Sender: TObject);
begin
  ShowMsg('         Р.Ш.Мухутдинов, ВМК, 2003 г.      ');
end;

procedure TMainForm.SoundButtonClick(Sender: TObject);
begin
  SoundOn := not SoundOn;
  ShowSound;
  WriteSetting('Sound', IntToStr(Ord(SoundOn)));
end;

{ Ctrl + двойной щелчок правой кнопкой по полоске — меню уровня этой стороны. }
procedure TMainForm.BlackScoreBarMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if [ssCtrl, ssRight, ssDouble] <= Shift then
    BlackPopup.Popup(MainForm.Left + ScorePanel.Left + BlackScoreBar.Left + X,
      MainForm.Top + ScorePanel.Top + BlackScoreBar.Top + Y);
end;

procedure TMainForm.WhiteScoreBarMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if [ssCtrl, ssRight, ssDouble] <= Shift then
    WhitePopup.Popup(MainForm.Left + ScorePanel.Left + WhiteScoreBar.Left + X,
      MainForm.Top + ScorePanel.Top + WhiteScoreBar.Top + Y);
end;

{ Ход компьютера за сторону Side в режиме Mode (человек играет другой стороной) или в игре
  с самим собой. Кнопка режима другой стороны (Other) на время раздумья недоступна. Ходить
  нечем — конец партии; иначе пауза с подсвеченным путём (PauseTimer). }
procedure TMainForm.ComputerTurn(Side: Integer; Mode, Other: TSpeedButton);
begin
  if not (Mode.Down or AutoModeButton.Down) then
    Exit;
  if CheckDraw then
    Exit;
  Other.Enabled := False;
  if not ComputerMove(Side) then
  begin
    if Poddavki then
      EndGame('Вы проиграли!')
    else
      EndGame('Вы выиграли!');
    Exit;
  end;
  if StopSearch then
  begin
    Other.Enabled := True;
    StopSearch := False;
    Exit;
  end;
  LastMover := Side;
  PauseTimer.Enabled := True;
end;

{ Ход компьютера за белых. }
procedure TMainForm.WhiteTimerTimer(Sender: TObject);
begin
  WhiteTimer.Enabled := False;
  ComputerTurn(1, BlackModeButton, WhiteModeButton);
end;

{ Ход компьютера за чёрных. }
procedure TMainForm.BlackTimerTimer(Sender: TObject);
begin
  BlackTimer.Enabled := False;
  ComputerTurn(2, WhiteModeButton, BlackModeButton);
end;

{ Конец паузы после хода компьютера: снимает подсветку и передаёт ход. }
procedure TMainForm.PauseTimerTimer(Sender: TObject);
var
  Human: Integer;
begin
  PauseTimer.Enabled := False;
  DrawBoard;
  ShowBoard(Board);
  if not AutoModeButton.Down then
  begin
    BlackModeButton.Enabled := True;
    WhiteModeButton.Enabled := True;
  end;
  if CheckDraw then
    Exit;
  if BlackModeButton.Down then
    Human := 2
  else if WhiteModeButton.Down then
    Human := 1
  else
    Human := 0;
  if Human <> 0 then
  begin
    Signal;
    Step := 0;
    CaptureMoves(Human, CapCnt[Human], CapList[Human]);
    SimpleMoves(Human, SimCnt[Human], SimList[Human]);
    if (SimCnt[Human] = 0) and (CapCnt[Human] = 0) then
      if Poddavki then
        EndGame('Вы выиграли!')
      else
        EndGame('Вы проиграли!');
    Exit;
  end;
  if StopSearch then
  begin
    StopSearch := False;
    Exit;
  end;
  if LastMover = 1 then
    BlackTimer.Enabled := True
  else
    WhiteTimer.Enabled := True;
end;

{ Мигание выбранной фигуры: 16 тактов от фигуры к клетке и обратно. }
procedure TMainForm.BlinkTimerTimer(Sender: TObject);
var
  Side, V, k: Integer;
  Frame: TImage;
begin
  if Step > 1 then
  begin
    // взятие набирается по полям, а на доске фигура до конца хода стоит на первом поле
    // пути; шашка, побывавшая на горизонтали превращения раньше текущего поля, мигает дамкой
    if LastMover = 1 then
      Side := 2
    else
      Side := 1;
    V := Board[Paths[Side, 1].X, Paths[Side, 1].Y];
    for k := 1 to Step - 1 do
      if Paths[Side, k].Y = PromoRow(Side) then
      begin
        V := Side + 10;
        Break;
      end;
  end
  else
    V := Board[BlinkX, BlinkY];
  Frame := nil;
  if (V >= 1) and (V <= 12) then
    Frame := Frames[V, Abs(8 - BlinkPhase)];
  if Frame <> nil then
    BoardImage.Canvas.StretchDraw(SquareRect(BlinkX, BlinkY), Frame.Picture.Graphic);
  if BlinkPhase = 15 then
    BlinkPhase := 0
  else
    BlinkPhase := BlinkPhase + 1;
end;

{ Выбор уровня в меню стороны: уровень — номер пункта по порядку, галочка — только на нём. }
procedure SelectLevel(Popup: TPopupMenu; Item: TMenuItem; var Level: Integer);
var
  i: Integer;
begin
  Level := Item.MenuIndex + 1;
  for i := 0 to Popup.Items.Count - 1 do
    Popup.Items[i].Checked := i = Item.MenuIndex;
end;

procedure TMainForm.WhiteLevelClick(Sender: TObject);
begin
  SelectLevel(WhitePopup, Sender as TMenuItem, WhiteLevel);
end;

procedure TMainForm.BlackLevelClick(Sender: TObject);
begin
  SelectLevel(BlackPopup, Sender as TMenuItem, BlackLevel);
end;

{ Подсветка координат под курсором и вид курсора: можно ли сходить на это поле. }
procedure TMainForm.BoardImageMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  CX, CY, Idx, Side: Integer;
  Fin: Boolean;
begin
  // вне доски (мышь захвачена кнопкой) номера выходят за 1..8 и подсвечивать нечего
  HighlightCoords(X div 50 + 1, 8 - Y div 50);
  PointToSquare(X, Y, CX, CY);
  Side := HumanToMove;
  if Side <> 0 then
    if CanStep(Side, CX, CY, Idx, Fin) then
      BoardImage.Cursor := crEnabled
    else
      BoardImage.Cursor := crTransparent;
end;

{ Отмечает поле (CX, CY) в ходе человека за Side: фигуру — начало нового хода, свободное
  поле — очередное поле пути; последнее поле делает ход и передаёт ход компьютеру. False —
  на это поле ходить нельзя, ничего не сделано. }
function TMainForm.HumanStepTo(Side, CX, CY: Integer): Boolean;
var
  Idx: Integer;
  Fin: Boolean;
begin
  Result := CanStep(Side, CX, CY, Idx, Fin);
  if not Result then
    Exit;
  if Board[CX, CY] <> 0 then
  begin
    Step := 0;
    if (CX <> BlinkX) or (CY <> BlinkY) then
    begin
      DrawBoard;
      ShowBoard(Board);
    end;
  end
  else
    BoardImage.Cursor := crTransparent;
  Paths[Side, Step + 1].X := CX;
  Paths[Side, Step + 1].Y := CY;
  if (CX <> BlinkX) or (CY <> BlinkY) or not BlinkTimer.Enabled then
    StartBlink(CX, CY);
  if Step > 0 then
    ErasePath(Paths[Side, Step].X, Paths[Side, Step].Y, Paths[Side, Step].X,
      Paths[Side, Step].Y);
  Inc(Step);
  if Fin then
  begin
    StopBlink;
    ApplyHumanMove(Side, Idx);
    DrawBoard;
    ShowBoard(Board);
    LastMover := Side;
    if Side = 2 then
      WhiteTimer.Enabled := True
    else
      BlackTimer.Enabled := True;
  end;
end;

{ Ход игрока щелчками: фигура, затем поля пути по одному. Щелчок мимо сбрасывает выбор. }
procedure TMainForm.BoardImageMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  CX, CY, Side: Integer;
begin
  PointToSquare(X, Y, CX, CY);
  Side := HumanToMove;
  if (Side <> 0) and not HumanStepTo(Side, CX, CY) then
  begin
    CancelMove;
    BoardImageMouseMove(Sender, [], X, Y);
  end;
end;

end.
