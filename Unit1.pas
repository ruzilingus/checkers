unit Unit1;

{ Главное окно: отрисовка, ход игрока щелчками и клавишами, режимы игры. Правила, оценка и
  перебор — в модуле Engine. Компьютер среди ходов с лучшей оценкой выбирает случайный.

  Ходы игрока и компьютера идут через таймеры: WhiteTimer — ход компьютера за белых,
  BlackTimer — за чёрных (оба — ComputerTurn), PauseTimer — пауза после хода компьютера с
  подсвеченным путём, затем ход человека или компьютера. PauseTimer.Tag хранит, кто ходил
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

  { TForm1 }

  TForm1 = class(TForm)
    Title: TLabel;
    MainPanel: TPanel;
    BoardPanel: TPanel;
    ScorePanel: TPanel;
    StatusBlack: TPanel;
    StatusWhite: TPanel;
    BackImage: TImage;
    TitleImage: TImage;
    IconImage: TImage;
    ScoreBackImage: TImage;
    Smile1: TImage;
    Smile2: TImage;
    LightSquare: TImage;
    DarkSquare: TImage;
    Select: TImage;
    WhiteFish: TImage;
    BlackFish: TImage;
    WhiteFish2: TImage;
    BlackFish2: TImage;
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
    BlackLevel1: TMenuItem;
    BlackLevel2: TMenuItem;
    BlackLevel3: TMenuItem;
    BlackLevel4: TMenuItem;
    BlackLevel5: TMenuItem;
    BlackLevel6: TMenuItem;
    BlackLevel7: TMenuItem;
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
    procedure StatusBlackMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure StatusWhiteMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure WhiteTimerTimer(Sender: TObject);
    procedure BlackTimerTimer(Sender: TObject);
    procedure PauseTimerTimer(Sender: TObject);
    procedure BlinkTimerTimer(Sender: TObject);
    procedure OnWhiteItemClick(Sender: TObject);
    procedure OnBlackItemClick(Sender: TObject);
    procedure CreateBlinkFish;
    procedure BoardImageMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure BoardImageMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
  private
    BoardImage: TRuzilImage;
    FLastActiveForm: TCustomForm;
    procedure ActiveFormChanged(Sender: TObject);
    procedure ComputerTurn(Side: Integer; Mode, Other: TSpeedButton);
  end;

var
  Form1: TForm1;

implementation

uses
  Unit2;

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
  History: array[1..100000] of TBoard;
  MoveNo: Integer;

  Flipped: Boolean;     // доска перевёрнута (снизу чёрные)
  Thinking: Boolean;    // идёт перебор

  { Ход игрока, набираемый щелчками: Step — число отмеченных полей, Paths — сами поля. }
  Step: Integer;
  Paths: array[1..2, 1..MaxJumps + 1] of TSq;
  BlinkX, BlinkY: Integer;

  { Кадры мигания выбранной фигуры: от клетки (0) до фигуры (8). }
  FrameB, FrameW, FrameB2, FrameW2: array[0..8] of TImage;
  LetTop, LetBottom, DigLeft, DigRight: array[1..8] of TPanel;

  LogFileName: string; // /log=<файл> — запись позиций партии

  { Звуковые сигналы: «ваш ход» и неверная клавиша. Включает и выключает SoundButton,
    выбор хранится в реестре: настройка Sound (см. SettingsKey в Unit2). }
  SoundOn: Boolean = True;

procedure IdleProcessMessages;
begin
  Application.ProcessMessages;
end;

procedure LogPosition(const B: TBoard);
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
  WriteLn(F, MoveNo, ' ', BoardToText(B));
  CloseFile(F);
end;

{ Для журнала (/log): ходы корня перебора и их оценки. }
procedure LogRoot(Side: Integer; IsCapture: Boolean; Count: Integer);
var
  F: TextFile;
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
  AssignFile(F, LogFileName);
  if FileExists(LogFileName) then
    Append(F)
  else
    Rewrite(F);
  WriteLn(F, S);
  CloseFile(F);
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
    Form1.SoundButton.Glyph := G;
  finally
    G.Free;
  end;
  if SoundOn then
    Form1.SoundButton.Hint := 'Выключить звук Ctrl+M'
  else
    Form1.SoundButton.Hint := 'Включить звук Ctrl+M';
end;

procedure DrawBoard;
var
  i, j: Integer;
begin
  for i := 1 to 8 do
    for j := 1 to 8 do
      if (i + j) mod 2 <> 0 then
        Form1.BoardImage.Canvas.StretchDraw(Rect((i - 1) * 50, (j - 1) * 50, i * 50, j * 50),
          Form1.DarkSquare.Picture.Graphic)
      else
        Form1.BoardImage.Canvas.StretchDraw(Rect((i - 1) * 50, (j - 1) * 50, i * 50, j * 50),
          Form1.LightSquare.Picture.Graphic);
  if Flipped then
    for i := 1 to 8 do
    begin
      DigLeft[i].Caption := IntToStr(9 - i);
      DigRight[i].Caption := IntToStr(9 - i);
      LetTop[i].Caption := Chr($69 - i);
      LetBottom[i].Caption := Chr($69 - i);
    end
  else
    for i := 1 to 8 do
    begin
      DigLeft[i].Caption := IntToStr(i);
      DigRight[i].Caption := IntToStr(i);
      LetTop[i].Caption := Chr($61 + i - 1);
      LetBottom[i].Caption := Chr($61 + i - 1);
    end;
end;

procedure DrawPiece(X, Y: Integer; const B: TBoard);
var
  G: TGraphic;
begin
  case B[X, Y] of
    1: G := Form1.WhiteFish.Picture.Graphic;
    11: G := Form1.WhiteFish2.Picture.Graphic;
    2: G := Form1.BlackFish.Picture.Graphic;
    12: G := Form1.BlackFish2.Picture.Graphic;
  else
    Exit;
  end;
  Form1.BoardImage.Canvas.StretchDraw(SquareRect(X, Y), G);
end;

{ Рисует фигуры позиции, ведёт историю ходов, перекрашивает индикаторы и кнопки режимов
  под текущий цвет шашек и выставляет высоту полосок перевеса. }
procedure ShowBoard(const B: TBoard);
var
  i, j, SW, SB: Integer;
  Tmp: TBoard;
  C: TColor;
  R, G, Bl: Byte;
begin
  Form1.BoardImage.Canvas.Brush.Style := bsSolid;
  for i := 1 to 8 do
    for j := 1 to 8 do
      DrawPiece(i, j, B);
  InitBoard(Tmp);
  if BoardsEqual(B, Tmp) then
    MoveNo := 0;
  if (MoveNo = 0) or not BoardsEqual(History[MoveNo], B) then
  begin
    Inc(MoveNo);
    CopyBoard(History[MoveNo], B);
    LogPosition(B);
  end;

  C := Form1.WhiteFish.Canvas.Pixels[1, 1];
  R := Min(255 - GetRValue(C), GetRValue(C));
  G := Min(255 - GetGValue(C), GetGValue(C));
  Bl := Min(255 - GetBValue(C), GetBValue(C));
  R := Byte(Round(GetRValue(C) + R * (Form2.RedBar.Position / 10)));
  G := Byte(Round(GetGValue(C) + G * (Form2.GreenBar.Position / 10)));
  Bl := Byte(Round(GetBValue(C) + Bl * (Form2.BlueBar.Position / 10)));
  if TColor(RGB(R, G, Bl)) <> Form1.StatusWhite.Color then
  begin
    Form1.StatusWhite.Color := RGB(R, G, Bl);
    Form1.StatusBlack.Color := RGB(Byte(2 * GetRValue(C) - R), Byte(2 * GetGValue(C) - G),
      Byte(2 * GetBValue(C) - Bl));
    with Form1.WhiteModeButton.Glyph.Canvas do
    begin
      Brush.Color := RGB(R, G, Bl);
      FloodFill(3, 3, clBlack, fsBorder);
    end;
    with Form1.BlackModeButton.Glyph.Canvas do
    begin
      Brush.Color := RGB(Byte(2 * GetRValue(C) - R), Byte(2 * GetGValue(C) - G),
        Byte(2 * GetBValue(C) - Bl));
      FloodFill(3, 3, clBlack, fsBorder);
    end;
    with Form1.AutoModeButton.Glyph.Canvas do
    begin
      Brush.Color := RGB(R, G, Bl);
      FloodFill(3, 3, clBlack, fsBorder);
    end;
    with Form1.AutoModeButton.Glyph.Canvas do
    begin
      Brush.Color := RGB(Byte(2 * GetRValue(C) - R), Byte(2 * GetGValue(C) - G),
        Byte(2 * GetBValue(C) - Bl));
      FloodFill(Form1.AutoModeButton.Glyph.Width - 3, Form1.AutoModeButton.Glyph.Height - 3,
        clBlack, fsBorder);
    end;
  end;

  SideScores(SW, SB);
  Form1.StatusWhite.Height := Round(Abs(SW) * 70.58823529411765 / EvalScale);
  Form1.StatusWhite.Top := Form1.ScorePanel.Height - Form1.StatusWhite.Height - 6;
  Form1.StatusBlack.Height := Round(Abs(SB) * 70.58823529411765 / EvalScale);
  Form1.StatusBlack.Top := Form1.ScorePanel.Height - Form1.StatusBlack.Height - 6;
  Form1.StatusWhite.Hint := FloatToStrF(SW / EvalScale, ffFixed, 10, 4);
  Form1.StatusBlack.Hint := FloatToStrF(SB / EvalScale, ffFixed, 10, 4);
  Form1.ScorePanel.Repaint;
end;

{ Подсвечивает путь хода от (X1, Y1) до (X2, Y2) включительно и рисует фигуры поверх. }
procedure MarkPath(X1, Y1, X2, Y2: Integer);
var
  k, X, Y: Integer;
begin
  Form1.BoardImage.Canvas.StretchDraw(SquareRect(X1, Y1), Form1.Select.Picture.Graphic);
  DrawPiece(X1, Y1, Board);
  for k := 1 to Abs(X2 - X1) do
  begin
    X := Abs(X2 - X1) * k div (X2 - X1) + X1;
    Y := Abs(Y2 - Y1) * k div (Y2 - Y1) + Y1;
    Form1.BoardImage.Canvas.StretchDraw(SquareRect(X, Y), Form1.Select.Picture.Graphic);
    DrawPiece(X, Y, Board);
  end;
end;

{ Закрашивает поля пути пустой клеткой. }
procedure ErasePath(X1, Y1, X2, Y2: Integer);
var
  k, X, Y: Integer;
begin
  Form1.BoardImage.Canvas.StretchDraw(SquareRect(X1, Y1), Form1.DarkSquare.Picture.Graphic);
  for k := 1 to Abs(X2 - X1) do
  begin
    X := Abs(X2 - X1) * k div (X2 - X1) + X1;
    Y := Abs(Y2 - Y1) * k div (Y2 - Y1) + Y1;
    Form1.BoardImage.Canvas.StretchDraw(SquareRect(X, Y), Form1.DarkSquare.Picture.Graphic);
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

{ Конец партии: в игре с человеком — сообщение Msg, затем новая партия. Белыми начинает
  компьютер, если играет ими, иначе ход за человеком. }
procedure EndGame(const Msg: string);
begin
  with Form1 do
  begin
    if BlackModeButton.Down or WhiteModeButton.Down then
    begin
      ShowMsg(Msg);
      BlackModeButton.Enabled := True;
      WhiteModeButton.Enabled := True;
    end;
    DrawBoard;
    NewBoard;
    ShowBoard(Board);
    PauseTimer.Tag := 2;
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
  with Form1 do
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
  with Form1 do
    if not WhiteTimer.Enabled and not BlackTimer.Enabled and not PauseTimer.Enabled then
      if BlackModeButton.Down and (PauseTimer.Tag = 1) then
        Result := 2
      else if WhiteModeButton.Down and (PauseTimer.Tag <> 1) then
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
function CheckStep(Side, X, Y, AStep: Integer; var Index: Integer; var Final: Boolean): Boolean;
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
  Form1.BlinkTimer.Tag := 0;
  Form1.BlinkTimer.Enabled := True;
end;

procedure StopBlink;
begin
  Form1.BlinkTimer.Enabled := False;
end;

{ TRuzilImage }

procedure TRuzilImage.CMMouseLeave(var Message: TLMessage);
var
  k: Integer;
begin
  inherited;
  Form1.BoardImage.Cursor := crTransparent;
  for k := 1 to 8 do
  begin
    if LetTop[k].Font.Color <> LabelColor then
    begin
      LetTop[k].Font.Color := LabelColor;
      LetBottom[k].Font.Color := LabelColor;
    end;
    if DigLeft[k].Font.Color <> LabelColor then
    begin
      DigLeft[k].Font.Color := LabelColor;
      DigRight[k].Font.Color := LabelColor;
    end;
  end;
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

{ TForm1 }

procedure TForm1.ActiveFormChanged(Sender: TObject);
begin
  { Как в Delphi: OnActivate — только при переходе фокуса из другого окна этой программы
    (и при первом показе), но не при возврате из чужого приложения или окна сообщения. }
  if Screen.ActiveForm = nil then
    Exit;
  if (Screen.ActiveForm = Self) and (FLastActiveForm <> Self) then
    FormActivate(Self);
  FLastActiveForm := Screen.ActiveForm;
end;

procedure TForm1.CreateBlinkFish;
var
  k, X, Y: Integer;
  R0, G0, B0: Byte;

  procedure Blend(Src, Dst: TImage);
  begin
    PixColor := Src.Canvas.Pixels[X, Y];
    PixR := GetRValue(PixColor);
    PixG := GetGValue(PixColor);
    PixB := GetBValue(PixColor);
    if PixR <> BaseR then
    begin
      PixColor := DarkSquare.Canvas.Pixels[X, Y];
      R0 := GetRValue(PixColor);
      G0 := GetGValue(PixColor);
      B0 := GetBValue(PixColor);
      Dst.Canvas.Pixels[X, Y] := RGB(Byte(Round(R0 + (PixR - R0) * k / 8)),
        Byte(Round(G0 + (PixG - G0) * k / 8)), Byte(Round(B0 + (PixB - B0) * k / 8)));
    end;
  end;

begin
  for k := 0 to 8 do
  begin
    // кадры пересоздаются после каждой смены цветов: прежние освобождаются
    FrameB[k].Free;
    FrameW[k].Free;
    FrameB2[k].Free;
    FrameW2[k].Free;
    FrameB[k] := TImage.Create(Self);
    FrameW[k] := TImage.Create(Self);
    FrameB2[k] := TImage.Create(Self);
    FrameW2[k] := TImage.Create(Self);
    FrameB[k].Picture := DarkSquare.Picture;
    FrameW[k].Picture := DarkSquare.Picture;
    FrameB2[k].Picture := DarkSquare.Picture;
    FrameW2[k].Picture := DarkSquare.Picture;
    for X := 2 to Form2.Image2.Width - 3 do
      for Y := 8 to Form2.Image2.Height - 9 do
      begin
        Blend(BlackFish, FrameB[k]);
        Blend(WhiteFish, FrameW[k]);
        Blend(BlackFish2, FrameB2[k]);
        Blend(WhiteFish2, FrameW2[k]);
      end;
  end;
end;

{ Готовит текстуры клеток и подсветки, берёт цвета из окна настроек и начинает новую
  партию. В оригинале вызывается при каждой активации окна, в том числе после закрытия
  окна настройки цветов. }
procedure TForm1.FormActivate(Sender: TObject);
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
      Select.Canvas.Pixels[X, Y] := RGB(Byte(Round(R + (255 - R) * T)), Byte(Round((1 - T) * G)),
        Byte(Round((1 - T) * B)));
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
  PoddavkiButton.Glyph := Smile2.Picture.Bitmap;
  Form2.FormShow(Sender);
  Form2.SpeedButton5Click(Sender);
  CreateBlinkFish;
  DrawBoard;
  NewBoard;
  ShowBoard(Board);
  Step := 0;
  CaptureMoves(1, CapCnt[1], CapList[1]);
  SimpleMoves(1, SimCnt[1], SimList[1]);
end;

procedure TForm1.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  Closing := True;
end;

procedure TForm1.FormCreate(Sender: TObject);
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
    Result.Color := Smile1.Canvas.Pixels[1, 1];
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
    LetTop[k] := MakeLabel(k * 50 + 5, 28, 20, Chr($61 + k - 1));
    LetBottom[k] := MakeLabel(k * 50 + 5, 453, 20, Chr($61 + k - 1));
  end;
  Screen.Cursors[crTransparent] := LoadCursor(HInstance, 'TRANSPARENTCURSOR');
  Screen.Cursors[crEnabled] := LoadCursor(HInstance, 'ENABLEDCURSOR');
  SetTransparentCursor([Title, StatusWhite, StatusBlack,
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

procedure TForm1.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  S: TShiftState;
  Idx, Digit, Side: Integer;
  Fin: Boolean;
begin
  // в LCL Shift бывает дополнен состоянием Caps/NumLock — сравниваем как в Delphi
  S := Shift * [ssShift, ssAlt, ssCtrl, ssLeft, ssRight, ssMiddle, ssDouble];

  // отмена хода: Ctrl+Z или Alt+Backspace
  if BlackModeButton.Enabled and WhiteModeButton.Enabled and (MoveNo > 2)
    and (((Key = VK_BACK) and (S = [ssAlt])) or ((Key = Ord('Z')) and (S = [ssCtrl]))) then
  begin
    CopyBoard(Board, History[MoveNo - 1]);
    Dec(MoveNo);
    DrawBoard;
    ShowBoard(Board);
    BoardImage.Repaint;
    Sleep(100);
    CopyBoard(Board, History[MoveNo - 1]);
    MoveNo := MoveNo - 2;
    DrawBoard;
    ShowBoard(Board);
    CaptureMoves(1, CapCnt[1], CapList[1]);
    CaptureMoves(2, CapCnt[2], CapList[2]);
    SimpleMoves(1, SimCnt[1], SimList[1]);
    SimpleMoves(2, SimCnt[2], SimList[2]);
    BoardImage.Repaint;
    Key := VK_ESCAPE;
  end;
  if BlackModeButton.Enabled and WhiteModeButton.Enabled and (MoveNo = 2)
    and (((Key = VK_BACK) and (S = [ssAlt])) or ((Key = Ord('Z')) and (S = [ssCtrl]))) then
  begin
    CopyBoard(Board, History[MoveNo - 1]);
    MoveNo := MoveNo - 2;
    DrawBoard;
    ShowBoard(Board);
    CaptureMoves(1, CapCnt[1], CapList[1]);
    CaptureMoves(2, CapCnt[2], CapList[2]);
    SimpleMoves(1, SimCnt[1], SimList[1]);
    SimpleMoves(2, SimCnt[2], SimList[2]);
    BoardImage.Repaint;
    PauseTimer.Tag := 2;
    if BlackModeButton.Down then
    begin
      NoModeButton.Down := True;
      BlackModeButtonMouseDown(Sender, mbLeft, [], 1, 1);
    end;
    Key := VK_ESCAPE;
  end;
  if Key = VK_ESCAPE then
  begin
    Form1.Tag := 0;
    BoardImageMouseDown(Sender, mbLeft, [], 444, 444);
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
    and (InRange(Key, $41, $48) or InRange(Key, $61, $69) or InRange(Key, $31, $38)) then
  begin
    Signal;
    Exit;
  end;
  if InRange(Key, $41, $48) then
    Form1.Tag := Key;
  if InRange(Key, $61, $69) then
    Key := Key - $61 + $31;
  if InRange(Key, $31, $38) and (Form1.Tag <> 0) then
  begin
    Digit := Key - $30;
    Side := HumanToMove;
    if (Side <> 0) and (CheckStep(Side, Form1.Tag - $41 + 1, Digit, Step, Idx, Fin)
      or CheckStep(Side, Form1.Tag - $41 + 1, Digit, 0, Idx, Fin)) then
    begin
      if Flipped then
        BoardImageMouseDown(Sender, mbLeft, [], (7 - (Form1.Tag - $41)) * 50 + 25,
          (Digit - 1) * 50 + 25)
      else
        BoardImageMouseDown(Sender, mbLeft, [], (Form1.Tag - $41) * 50 + 25,
          (8 - Digit) * 50 + 25);
    end;
    Form1.Tag := 0;
  end;
end;

procedure TForm1.FormShow(Sender: TObject);
begin
  Form1.Left := (Screen.Width - Form1.Width) div 2;
  Form1.Top := (Screen.Height - Form1.Height - 28) div 2;
end;

{ Остановка: снимает режим игры; во время перебора просит его прерваться. }
procedure TForm1.StopButtonClick(Sender: TObject);
begin
  BoardImage.Cursor := crTransparent;
  BlackModeButton.Enabled := True;
  WhiteModeButton.Enabled := True;
  AutoModeButton.Enabled := True;
  NewGameButton.Enabled := True;
  ColorsButton.Enabled := True;
  PoddavkiButton.Enabled := True;
  BlinkTimer.Enabled := False;
  NoModeButton.Down := True;
  DrawBoard;
  if Thinking then
    ShowBoard(SaveBoard)
  else
    ShowBoard(Board);
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

procedure TForm1.AutoModeButtonMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if not AutoModeButton.Down then
  begin
    AutoModeButton.Down := True;
    BlackModeButton.Enabled := False;
    WhiteModeButton.Enabled := False;
    NewGameButton.Enabled := False;
    ColorsButton.Enabled := False;
    PoddavkiButton.Enabled := False;
    StopSearch := False;
    BlinkTimer.Enabled := False;
    if not Thinking then
      PauseTimer.Enabled := True;
  end;
end;

procedure TForm1.NewGameButtonClick(Sender: TObject);
begin
  WhiteTimer.Enabled := False;
  BlackTimer.Enabled := False;
  PauseTimer.Enabled := False;
  BlinkTimer.Enabled := False;
  DrawBoard;
  NewBoard;
  ShowBoard(Board);
  PauseTimer.Tag := 2;
  StopSearch := False;
  if BlackModeButton.Down or AutoModeButton.Down then
    WhiteTimer.Enabled := True;
end;

procedure TForm1.ColorsButtonClick(Sender: TObject);
begin
  NoModeButton.Down := True;
  Form2.Image4.Picture := BackImage.Picture;
  Form2.ShowModal;
  DrawBoard;
  ShowBoard(Board);
  Form1.Repaint;
  if Form2.OkPressed then
    CreateBlinkFish;
end;

procedure TForm1.FlipButtonClick(Sender: TObject);
begin
  Flipped := not Flipped;
  DrawBoard;
  if Thinking then
    ShowBoard(SaveBoard)
  else
    ShowBoard(Board);
  BoardImage.Repaint;
end;

{ Перетаскивание окна без рамки за полосу заголовка. }
procedure TForm1.TitleImageMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  ReleaseCapture;
  SendMessage(Handle, WM_SYSCOMMAND, $F012, 0);
end;

procedure TForm1.CloseButtonClick(Sender: TObject);
begin
  Close;
end;

{ Игра за белых: компьютер играет чёрными. }
procedure TForm1.WhiteModeButtonMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if not WhiteModeButton.Down then
  begin
    WhiteModeButton.Down := True;
    NewGameButton.Enabled := False;
    ColorsButton.Enabled := False;
    PoddavkiButton.Enabled := False;
    BlinkTimer.Enabled := False;
    Flipped := False;
    DrawBoard;
    ShowBoard(Board);
    StopSearch := False;
    if PauseTimer.Tag = 1 then
      BlackTimer.Enabled := True
    else
    begin
      Step := 0;
      CaptureMoves(1, CapCnt[1], CapList[1]);
      SimpleMoves(1, SimCnt[1], SimList[1]);
    end;
  end;
end;

{ Игра за чёрных: компьютер играет белыми, доска переворачивается. }
procedure TForm1.BlackModeButtonMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if not BlackModeButton.Down then
  begin
    BlackModeButton.Down := True;
    NewGameButton.Enabled := False;
    ColorsButton.Enabled := False;
    PoddavkiButton.Enabled := False;
    BlinkTimer.Enabled := False;
    Flipped := True;
    DrawBoard;
    ShowBoard(Board);
    StopSearch := False;
    if PauseTimer.Tag <> 1 then
      WhiteTimer.Enabled := True
    else
    begin
      Step := 0;
      CaptureMoves(2, CapCnt[2], CapList[2]);
      SimpleMoves(2, SimCnt[2], SimList[2]);
    end;
  end;
end;

procedure TForm1.PoddavkiButtonClick(Sender: TObject);
begin
  PauseTimer.Tag := 2;
  if Poddavki = 1 then
  begin
    Poddavki := 0;
    PoddavkiButton.Hint := 'Поддавки Ctrl+G';
    Application.Title := 'Шашки';
    Title.Caption := 'Шашки';
    PoddavkiButton.Glyph := Smile2.Picture.Bitmap;
  end
  else if Poddavki = 0 then
  begin
    Poddavki := 1;
    PoddavkiButton.Hint := 'Шашки Ctrl+G';
    Application.Title := 'Поддавки';
    Title.Caption := 'Поддавки';
    PoddavkiButton.Glyph := Smile1.Picture.Bitmap;
  end;
  NewBoard;
  DrawBoard;
  ShowBoard(Board);
end;

procedure TForm1.AboutButtonClick(Sender: TObject);
begin
  ShowMsg('         Р.Ш.Мухутдинов, ВМК, 2003 г.      ');
end;

procedure TForm1.SoundButtonClick(Sender: TObject);
begin
  SoundOn := not SoundOn;
  ShowSound;
  WriteSetting('Sound', IntToStr(Ord(SoundOn)));
end;

{ Ctrl + двойной щелчок правой кнопкой по полоске — меню уровня этой стороны. }
procedure TForm1.StatusBlackMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if [ssCtrl, ssRight, ssDouble] <= Shift then
    BlackPopup.Popup(Form1.Left + ScorePanel.Left + StatusBlack.Left + X,
      Form1.Top + ScorePanel.Top + StatusBlack.Top + Y);
end;

procedure TForm1.StatusWhiteMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if [ssCtrl, ssRight, ssDouble] <= Shift then
    WhitePopup.Popup(Form1.Left + ScorePanel.Left + StatusWhite.Left + X,
      Form1.Top + ScorePanel.Top + StatusWhite.Top + Y);
end;

{ Ход компьютера за сторону Side в режиме Mode (человек играет другой стороной) или в игре
  с самим собой. Кнопка режима другой стороны (Other) на время раздумья недоступна. Ходить
  нечем — конец партии; иначе пауза с подсвеченным путём (PauseTimer). }
procedure TForm1.ComputerTurn(Side: Integer; Mode, Other: TSpeedButton);
begin
  if not (Mode.Down or AutoModeButton.Down) then
    Exit;
  if CheckDraw then
    Exit;
  Other.Enabled := False;
  if not ComputerMove(Side) then
  begin
    if Poddavki = 1 then
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
  PauseTimer.Tag := Side;
  PauseTimer.Enabled := True;
end;

{ Ход компьютера за белых. }
procedure TForm1.WhiteTimerTimer(Sender: TObject);
begin
  WhiteTimer.Enabled := False;
  ComputerTurn(1, BlackModeButton, WhiteModeButton);
end;

{ Ход компьютера за чёрных. }
procedure TForm1.BlackTimerTimer(Sender: TObject);
begin
  BlackTimer.Enabled := False;
  ComputerTurn(2, WhiteModeButton, BlackModeButton);
end;

{ Конец паузы после хода компьютера: снимает подсветку и передаёт ход. }
procedure TForm1.PauseTimerTimer(Sender: TObject);
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
      if Poddavki = 1 then
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
  if PauseTimer.Tag = 1 then
    BlackTimer.Enabled := True
  else
    WhiteTimer.Enabled := True;
end;

{ Мигание выбранной фигуры: 16 тактов от фигуры к клетке и обратно. }
procedure TForm1.BlinkTimerTimer(Sender: TObject);
var
  L, T, V, k: Integer;
begin
  if Flipped then
  begin
    L := (8 - BlinkX) * 50;
    T := (BlinkY - 1) * 50;
  end
  else
  begin
    L := (BlinkX - 1) * 50;
    T := (8 - BlinkY) * 50;
  end;
  if Step > 1 then
  begin
    // при взятии шашка, прошедшая последнюю горизонталь, мигает дамкой
    if PauseTimer.Tag <> 1 then
    begin
      k := 1;
      V := Board[Paths[1, 1].X, Paths[1, 1].Y];
      while k < Step do
        if Paths[1, k].Y = 8 then
        begin
          V := 11;
          k := k + Step;
        end
        else
          Inc(k);
    end
    else
    begin
      k := 1;
      V := Board[Paths[2, 1].X, Paths[2, 1].Y];
      while k < Step do
        if Paths[2, k].Y = 1 then
        begin
          V := 12;
          k := k + Step;
        end
        else
          Inc(k);
    end;
  end
  else
    V := Board[BlinkX, BlinkY];
  case V of
    1: BoardImage.Canvas.StretchDraw(Rect(L, T, L + 50, T + 50),
        FrameW[Abs(8 - BlinkTimer.Tag)].Picture.Graphic);
    2: BoardImage.Canvas.StretchDraw(Rect(L, T, L + 50, T + 50),
        FrameB[Abs(8 - BlinkTimer.Tag)].Picture.Graphic);
    11: BoardImage.Canvas.StretchDraw(Rect(L, T, L + 50, T + 50),
        FrameW2[Abs(8 - BlinkTimer.Tag)].Picture.Graphic);
    12: BoardImage.Canvas.StretchDraw(Rect(L, T, L + 50, T + 50),
        FrameB2[Abs(8 - BlinkTimer.Tag)].Picture.Graphic);
  end;
  if BlinkTimer.Tag = 15 then
    BlinkTimer.Tag := 0
  else
    BlinkTimer.Tag := BlinkTimer.Tag + 1;
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

procedure TForm1.OnWhiteItemClick(Sender: TObject);
begin
  SelectLevel(WhitePopup, Sender as TMenuItem, WhiteLevel);
end;

procedure TForm1.OnBlackItemClick(Sender: TObject);
begin
  SelectLevel(BlackPopup, Sender as TMenuItem, BlackLevel);
end;

{ Подсветка координат под курсором и вид курсора: можно ли сходить на это поле. }
procedure TForm1.BoardImageMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  CX, CY, k, Col, Row, Idx, Side: Integer;
  Fin: Boolean;
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
  Col := X div 50 + 1;
  Row := 8 - Y div 50;
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
  // вне доски (мышь захвачена кнопкой) подсвечивать нечего
  if (X <> 444) and (Col in [1..8]) and (Row in [1..8]) then
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
  Side := HumanToMove;
  if Side <> 0 then
    if CheckStep(Side, CX, CY, Step, Idx, Fin) or CheckStep(Side, CX, CY, 0, Idx, Fin) then
      BoardImage.Cursor := crEnabled
    else
      BoardImage.Cursor := crTransparent;
end;

{ Ход игрока щелчками: фигура, затем поля пути по одному. Щелчок мимо сбрасывает выбор. }
procedure TForm1.BoardImageMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);

  procedure HumanClick(Side, CX, CY: Integer);
  var
    Idx: Integer;
    Fin: Boolean;
  begin
    if CheckStep(Side, CX, CY, Step, Idx, Fin) or CheckStep(Side, CX, CY, 0, Idx, Fin) then
    begin
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
        if Side = 2 then
        begin
          PauseTimer.Tag := 2;
          WhiteTimer.Enabled := True;
        end
        else
        begin
          PauseTimer.Tag := 1;
          BlackTimer.Enabled := True;
        end;
      end;
    end
    else
    begin
      StopBlink;
      Step := 0;
      DrawBoard;
      ShowBoard(Board);
      BoardImageMouseMove(Sender, [], X, Y);
    end;
  end;

var
  CX, CY, Side: Integer;
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
  Side := HumanToMove;
  if Side <> 0 then
    HumanClick(Side, CX, CY);
end;

end.
