unit Unit2;

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

  { TForm2 }

  TForm2 = class(TForm)
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
    TemplateBuffer: TImage;
    procedure RedBarChange(Sender: TObject);
    procedure RedUpDownClick(Sender: TObject; Button: TUDBtnType);
    procedure OkButtonClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure RedBarKeyPress(Sender: TObject; var Key: Char);
  public
    OkPressed: Boolean;
  end;

var
  Form2: TForm2;
  { Общие с Unit1 переменные пересчёта цвета: пиксель картинки, его каналы и цвет фона
    картинки шашки (пиксель (1,1)), по которому отличаются точки фигуры от фона. }
  PixColor: TColor;
  PixR, PixG, PixB: Byte;
  BaseR, BaseG, BaseB: Byte;
  SavedR, SavedG, SavedB: Integer;

const
  { Ключ настроек в HKCU: цвета (R, G, B) и звук (Sound). AppDataLow, а не Software\Checkers:
    туда может писать и процесс с низким уровнем целостности, а с ним запускается exe из папки
    с такой меткой (на машине разработки так помечена C:\Projects). }
  SettingsKey = '\Software\AppDataLow\Checkers';
  { Прежний ключ цветов: читается, пока в SettingsKey значения нет. }
  OldSettingsKey = '\Software\Checkers';

function ReadSetting(const Name, Default: string): string;
procedure WriteSetting(const Name, Value: string);

implementation

uses
  Unit1;

{$R *.lfm}

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

{ TForm2 }

procedure TForm2.RedBarChange(Sender: TObject);
var
  X, Y: Integer;
begin
  for X := 2 to WhitePreview.Width - 3 do
    for Y := 8 to WhitePreview.Height - 9 do
    begin
      PixColor := ManTemplate.Canvas.Pixels[X, Y];
      PixR := GetRValue(PixColor);
      PixG := GetGValue(PixColor);
      PixB := GetBValue(PixColor);
      if PixR <> BaseR then
      begin
        PixR := Byte(Round((PixR - BaseR) * (RedBar.Position / 10) + BaseR));
        PixG := Byte(Round((PixG - BaseG) * (GreenBar.Position / 10) + BaseG));
        PixB := Byte(Round((PixB - BaseB) * (BlueBar.Position / 10) + BaseB));
        WhitePreview.Canvas.Pixels[X, Y] := RGB(PixR, PixG, PixB);
        BlackPreview.Canvas.Pixels[X, Y] := RGB(Byte(2 * BaseR - PixR), Byte(2 * BaseG - PixG),
          Byte(2 * BaseB - PixB));
      end;
    end;
  RLabel.Caption := IntToStr(RedBar.Position);
  GLabel.Caption := IntToStr(GreenBar.Position);
  BLabel.Caption := IntToStr(BlueBar.Position);
  RedUpDown.Position := RedBar.Position;
  GreenUpDown.Position := GreenBar.Position;
  BlueUpDown.Position := BlueBar.Position;
end;

procedure TForm2.RedUpDownClick(Sender: TObject; Button: TUDBtnType);
begin
  RedBar.Position := RedUpDown.Position;
  GreenBar.Position := GreenUpDown.Position;
  BlueBar.Position := BlueUpDown.Position;
  RedBarChange(Sender);
end;

{ Кнопка OK: сохраняет множители и раздаёт основному окну перекрашенные шашки и дамки.
  RedBarChange перекрашивает образцы по ManTemplate, поэтому на время перекраски дамки
  шаблон шашки подменяется шаблоном дамки, а сам ждёт в TemplateBuffer. }
procedure TForm2.OkButtonClick(Sender: TObject);
begin
  WriteSetting('R', IntToStr(RedBar.Position));
  WriteSetting('G', IntToStr(GreenBar.Position));
  WriteSetting('B', IntToStr(BlueBar.Position));
  Form1.WhiteFish.Picture := WhitePreview.Picture;
  Form1.BlackFish.Picture := BlackPreview.Picture;
  TemplateBuffer.Picture := ManTemplate.Picture;
  ManTemplate.Picture := KingTemplate.Picture;
  RedBarChange(Sender);
  Form1.WhiteFish2.Picture := WhitePreview.Picture;
  Form1.BlackFish2.Picture := BlackPreview.Picture;
  KingTemplate.Picture := ManTemplate.Picture;
  ManTemplate.Picture := TemplateBuffer.Picture;
  OkPressed := True;
  Close;
end;

procedure TForm2.FormShow(Sender: TObject);
var
  X, Y: Integer;
begin
  SamplePanel.Color := ManTemplate.Canvas.Pixels[1, 1];
  PixColor := ManTemplate.Canvas.Pixels[1, 1];
  BaseR := GetRValue(PixColor);
  BaseG := GetGValue(PixColor);
  BaseB := GetBValue(PixColor);
  WhiteOriginal.Picture := ManTemplate.Picture;
  BlackOriginal.Picture := ManTemplate.Picture;
  for X := 2 to WhitePreview.Width - 3 do
    for Y := 8 to WhitePreview.Height - 9 do
    begin
      PixColor := ManTemplate.Canvas.Pixels[X, Y];
      PixR := GetRValue(PixColor);
      PixG := GetGValue(PixColor);
      PixB := GetBValue(PixColor);
      if PixR <> BaseR then
        BlackOriginal.Canvas.Pixels[X, Y] := RGB(Byte(2 * BaseR - PixR), Byte(2 * BaseG - PixG),
          Byte(2 * BaseB - PixB));
    end;
  WhitePreview.Picture := WhiteOriginal.Picture;
  BlackPreview.Picture := BlackOriginal.Picture;
  RedBar.Position := StrToIntDef(ReadSetting('R', '10'), 10);
  GreenBar.Position := StrToIntDef(ReadSetting('G', '10'), 10);
  BlueBar.Position := StrToIntDef(ReadSetting('B', '10'), 10);
  RedBarChange(Sender);
  SavedR := RedBar.Position;
  SavedG := GreenBar.Position;
  SavedB := BlueBar.Position;
  RedUpDown.Position := SavedR;
  GreenUpDown.Position := SavedG;
  BlueUpDown.Position := SavedB;
  RLabel.Caption := IntToStr(SavedR);
  GLabel.Caption := IntToStr(SavedG);
  BLabel.Caption := IntToStr(SavedB);
  OkPressed := False;
end;

{ Закрытие без OK возвращает ползунки к значениям на момент открытия окна. }
procedure TForm2.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  if not OkPressed then
  begin
    RedBar.Position := SavedR;
    GreenBar.Position := SavedG;
    BlueBar.Position := SavedB;
    RedUpDown.Position := SavedR;
    GreenUpDown.Position := SavedG;
    BlueUpDown.Position := SavedB;
    RLabel.Caption := IntToStr(SavedR);
    GLabel.Caption := IntToStr(SavedG);
    BLabel.Caption := IntToStr(SavedB);
  end;
end;

procedure TForm2.RedBarKeyPress(Sender: TObject; var Key: Char);
begin
  if Key = #27 then
    Close;
  if Key = #13 then
    OkButtonClick(Sender);
end;

end.
