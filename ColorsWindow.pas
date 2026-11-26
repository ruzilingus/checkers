unit ColorsWindow;

{ Окно «Настройка цветов». Цвет белых шашек задаётся тремя ползунками (множители каналов
  от -10 до 10, по умолчанию 10 — исходный цвет картинки), чёрные получаются отражением
  белых относительно цвета фона клетки. Значения хранятся в реестре (R, G, B), см. SettingsKey. }

{$mode delphi}{$H+}
{$Q-}{$R-}

interface

uses
  Windows, SysUtils, Classes, Graphics, Controls, Forms, ExtCtrls, Buttons, ComCtrls,
  Registry;

type

  { TColorsForm }

  TColorsForm = class(TForm)
    RedBar: TTrackBar;
    GreenBar: TTrackBar;
    BlueBar: TTrackBar;
    SamplePanel: TPanel;
    WhitePreview: TImage;
    BlackPreview: TImage;
    RLabel: TPanel;
    GLabel: TPanel;
    BLabel: TPanel;
    BackImage: TImage;
    RedUpDown: TUpDown;
    GreenUpDown: TUpDown;
    BlueUpDown: TUpDown;
    BlackOriginal: TImage;
    WhiteOriginal: TImage;
    OriginalBevel: TBevel;
    PreviewBevel: TBevel;
    OkBevel: TBevel;
    OkButton: TSpeedButton;
    ManTemplate: TImage;
    KingTemplate: TImage;
    procedure RedBarChange(Sender: TObject);
    procedure RedUpDownClick(Sender: TObject; Button: TUDBtnType);
    procedure OkButtonClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure RedBarKeyPress(Sender: TObject; var Key: Char);
  private
    procedure Recolor(Template: TImage);
    procedure ShowSliderValues;
  public
    OkPressed: Boolean;
  end;

var
  ColorsForm: TColorsForm;

const
  { Ключ настроек в HKCU: цвета (R, G, B) и звук (Sound). AppDataLow, а не Software\Checkers:
    туда может писать и процесс с низким уровнем целостности, а с ним запускается exe из папки
    с такой меткой (на машине разработки так помечена C:\Projects). }
  SettingsKey = '\Software\AppDataLow\Checkers';
  { Прежний ключ цветов: читается, пока в SettingsKey значения нет. }
  OldSettingsKey = '\Software\Checkers';

function ReadSetting(const Name, Default: string): string;
procedure WriteSetting(const Name, Value: string);
function MirrorColor(C, Base: TColor): TColor;

implementation

uses
  MainWindow;

{$R *.lfm}

var
  { Цвет фона картинок шашки и дамки по каналам — пиксель (1, 1) шаблона. Точка, у которой
    красная составляющая как у фона, считается фоном и не перекрашивается. }
  BaseR, BaseG, BaseB: Byte;
  { Ползунки на момент открытия окна: закрытие без OK возвращает их. }
  SavedR, SavedG, SavedB: Integer;

{ Цвет чёрных для цвета белых C: отражение относительно цвета фона Base по каждому каналу. }
function MirrorColor(C, Base: TColor): TColor;
begin
  Result := RGB(Byte(2 * GetRValue(Base) - GetRValue(C)), Byte(2 * GetGValue(Base) - GetGValue(C)),
    Byte(2 * GetBValue(Base) - GetBValue(C)));
end;

{ Настройка Name из SettingsKey, а если там её нет — из OldSettingsKey; нет нигде или это не
  строка — Default. }
function ReadSetting(const Name, Default: string): string;
const
  Keys: array[1..2] of string = (SettingsKey, OldSettingsKey);
var
  R: TRegistry;
  i: Integer;
begin
  Result := Default;
  R := TRegistry.Create(KEY_READ);
  try
    R.RootKey := HKEY_CURRENT_USER;
    for i := 1 to 2 do
    begin
      if R.OpenKeyReadOnly(Keys[i]) and R.ValueExists(Name)
        and (R.GetDataType(Name) = rdString) then
        Exit(R.ReadString(Name));
      R.CloseKey;
    end;
  finally
    R.Free;
  end;
end;

{ Записывает настройку Name в SettingsKey. Не вышло — сообщение в отладочный вывод
  (DebugView): окно об этом не беспокоит, настройка действует до выхода из игры. }
procedure WriteSetting(const Name, Value: string);
var
  R: TRegistry;
begin
  R := TRegistry.Create;
  try
    R.RootKey := HKEY_CURRENT_USER;
    if R.OpenKey(SettingsKey, True) then
      R.WriteString(Name, Value)
    else
      {$push}{$warn 5044 off}  // LastError есть только у TRegistry под Windows
      OutputDebugString(PChar(Format('Checkers: setting %s not saved, HKCU%s open error %d',
        [Name, SettingsKey, R.LastError])));
      {$pop}
  finally
    R.Free;
  end;
end;

{ TColorsForm }

{ Перекрашивает образцы WhitePreview и BlackPreview по шаблону Template: точки фигуры
  сдвигаются от цвета фона множителями ползунков, у чёрных — отражение. Точки, где у шаблона
  фон, в образцах не трогаются. }
procedure TColorsForm.Recolor(Template: TImage);
var
  X, Y: Integer;
  C, Base: TColor;
  PixR, PixG, PixB: Byte;
begin
  Base := RGB(BaseR, BaseG, BaseB);
  for X := 2 to WhitePreview.Width - 3 do
    for Y := 8 to WhitePreview.Height - 9 do
    begin
      C := Template.Canvas.Pixels[X, Y];
      PixR := GetRValue(C);
      PixG := GetGValue(C);
      PixB := GetBValue(C);
      if PixR <> BaseR then
      begin
        PixR := Byte(Round((PixR - BaseR) * (RedBar.Position / 10) + BaseR));
        PixG := Byte(Round((PixG - BaseG) * (GreenBar.Position / 10) + BaseG));
        PixB := Byte(Round((PixB - BaseB) * (BlueBar.Position / 10) + BaseB));
        C := RGB(PixR, PixG, PixB);
        WhitePreview.Canvas.Pixels[X, Y] := C;
        BlackPreview.Canvas.Pixels[X, Y] := MirrorColor(C, Base);
      end;
    end;
end;

{ Подписи значений и стрелки ползунков — по их положению. }
procedure TColorsForm.ShowSliderValues;
begin
  RLabel.Caption := IntToStr(RedBar.Position);
  GLabel.Caption := IntToStr(GreenBar.Position);
  BLabel.Caption := IntToStr(BlueBar.Position);
  RedUpDown.Position := RedBar.Position;
  GreenUpDown.Position := GreenBar.Position;
  BlueUpDown.Position := BlueBar.Position;
end;

procedure TColorsForm.RedBarChange(Sender: TObject);
begin
  Recolor(ManTemplate);
  ShowSliderValues;
end;

procedure TColorsForm.RedUpDownClick(Sender: TObject; Button: TUDBtnType);
begin
  RedBar.Position := RedUpDown.Position;
  GreenBar.Position := GreenUpDown.Position;
  BlueBar.Position := BlueUpDown.Position;
  RedBarChange(Sender);
end;

{ Кнопка OK: сохраняет множители и раздаёт основному окну перекрашенные шашки и дамки.
  Дамка перекрашивается поверх образцов шашки: где у шаблона дамки фон, остаются точки
  шашки. }
procedure TColorsForm.OkButtonClick(Sender: TObject);
begin
  WriteSetting('R', IntToStr(RedBar.Position));
  WriteSetting('G', IntToStr(GreenBar.Position));
  WriteSetting('B', IntToStr(BlueBar.Position));
  MainForm.WhiteFish.Picture := WhitePreview.Picture;
  MainForm.BlackFish.Picture := BlackPreview.Picture;
  Recolor(KingTemplate);
  MainForm.WhiteKingFish.Picture := WhitePreview.Picture;
  MainForm.BlackKingFish.Picture := BlackPreview.Picture;
  OkPressed := True;
  Close;
end;

{ Открытие окна (и подготовка цветов при запуске игры): фон, образцы исходных цветов —
  белые как в шаблоне, чёрные отражением, — затем ползунки из настроек и образцы по ним. }
procedure TColorsForm.FormShow(Sender: TObject);
var
  X, Y: Integer;
  C, Base: TColor;
begin
  Base := ManTemplate.Canvas.Pixels[1, 1];
  SamplePanel.Color := Base;
  BaseR := GetRValue(Base);
  BaseG := GetGValue(Base);
  BaseB := GetBValue(Base);
  WhiteOriginal.Picture := ManTemplate.Picture;
  BlackOriginal.Picture := ManTemplate.Picture;
  for X := 2 to WhitePreview.Width - 3 do
    for Y := 8 to WhitePreview.Height - 9 do
    begin
      C := ManTemplate.Canvas.Pixels[X, Y];
      if GetRValue(C) <> BaseR then
        BlackOriginal.Canvas.Pixels[X, Y] := MirrorColor(C, Base);
    end;
  WhitePreview.Picture := WhiteOriginal.Picture;
  BlackPreview.Picture := BlackOriginal.Picture;
  RedBar.Position := StrToIntDef(ReadSetting('R', '10'), 10);
  GreenBar.Position := StrToIntDef(ReadSetting('G', '10'), 10);
  BlueBar.Position := StrToIntDef(ReadSetting('B', '10'), 10);
  RedBarChange(Sender);  // образцы, подписи и стрелки — по ползункам
  SavedR := RedBar.Position;
  SavedG := GreenBar.Position;
  SavedB := BlueBar.Position;
  OkPressed := False;
end;

{ Закрытие без OK возвращает ползунки к значениям на момент открытия окна. }
procedure TColorsForm.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  if not OkPressed then
  begin
    RedBar.Position := SavedR;
    GreenBar.Position := SavedG;
    BlueBar.Position := SavedB;
    ShowSliderValues;
  end;
end;

procedure TColorsForm.RedBarKeyPress(Sender: TObject; var Key: Char);
begin
  if Key = #27 then
    Close;
  if Key = #13 then
    OkButtonClick(Sender);
end;

end.
