unit Unit2;

{ Окно «Настройка цветов». Цвет белых шашек задаётся тремя ползунками (множители каналов
  от -10 до 10, по умолчанию 10 — исходный цвет картинки), чёрные получаются отражением
  белых относительно цвета фона клетки. Значения хранятся в HKCU\Software\Checkers (R, G, B). }

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
    Panel1: TPanel;
    Image2: TImage;
    Image3: TImage;
    RLabel: TPanel;
    GLabel: TPanel;
    BLabel: TPanel;
    Image4: TImage;
    RedUpDown: TUpDown;
    GreenUpDown: TUpDown;
    BlueUpDown: TUpDown;
    Image5: TImage;
    Image6: TImage;
    Bevel1: TBevel;
    Bevel2: TBevel;
    Bevel8: TBevel;
    SpeedButton5: TSpeedButton;
    Image1: TImage;
    Image7: TImage;
    Image8: TImage;
    procedure RedBarChange(Sender: TObject);
    procedure RedUpDownClick(Sender: TObject; Button: TUDBtnType);
    procedure SpeedButton5Click(Sender: TObject);
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

implementation

uses
  Unit1;

{$R *.lfm}

var
  Reg: TRegIniFile;

{ TForm2 }

procedure TForm2.RedBarChange(Sender: TObject);
var
  X, Y: Integer;
begin
  for X := 2 to Image2.Width - 3 do
    for Y := 8 to Image2.Height - 9 do
    begin
      PixColor := Image1.Canvas.Pixels[X, Y];
      PixR := GetRValue(PixColor);
      PixG := GetGValue(PixColor);
      PixB := GetBValue(PixColor);
      if PixR <> BaseR then
      begin
        PixR := Byte(Round((PixR - BaseR) * (RedBar.Position / 10) + BaseR));
        PixG := Byte(Round((PixG - BaseG) * (GreenBar.Position / 10) + BaseG));
        PixB := Byte(Round((PixB - BaseB) * (BlueBar.Position / 10) + BaseB));
        Image2.Canvas.Pixels[X, Y] := RGB(PixR, PixG, PixB);
        Image3.Canvas.Pixels[X, Y] := RGB(Byte(2 * BaseR - PixR), Byte(2 * BaseG - PixG),
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

{ Кнопка OK: сохраняет множители и раздаёт перекрашенные шашки (Image1) и дамки (Image7)
  основному окну. }
procedure TForm2.SpeedButton5Click(Sender: TObject);
begin
  Reg := TRegIniFile.Create('');
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if Reg.OpenKey('\Software', True) then
      if Reg.CreateKey('Checkers') then
        if Reg.OpenKey('\Software\Checkers', True) then
        begin
          Reg.WriteString('\Software\Checkers', 'R', IntToStr(RedBar.Position));
          Reg.WriteString('\Software\Checkers', 'G', IntToStr(GreenBar.Position));
          Reg.WriteString('\Software\Checkers', 'B', IntToStr(BlueBar.Position));
        end;
  finally
    Reg.CloseKey;
    Reg.Free;
  end;
  Form1.WhiteFish.Picture := Image2.Picture;
  Form1.BlackFish.Picture := Image3.Picture;
  Image8.Picture := Image1.Picture;
  Image1.Picture := Image7.Picture;
  RedBarChange(Sender);
  Form1.WhiteFish2.Picture := Image2.Picture;
  Form1.BlackFish2.Picture := Image3.Picture;
  Image7.Picture := Image1.Picture;
  Image1.Picture := Image8.Picture;
  OkPressed := True;
  Close;
end;

procedure TForm2.FormShow(Sender: TObject);
var
  X, Y: Integer;
begin
  Panel1.Color := Image1.Canvas.Pixels[1, 1];
  PixColor := Image1.Canvas.Pixels[1, 1];
  BaseR := GetRValue(PixColor);
  BaseG := GetGValue(PixColor);
  BaseB := GetBValue(PixColor);
  Image6.Picture := Image1.Picture;
  Image5.Picture := Image1.Picture;
  for X := 2 to Image2.Width - 3 do
    for Y := 8 to Image2.Height - 9 do
    begin
      PixColor := Image1.Canvas.Pixels[X, Y];
      PixR := GetRValue(PixColor);
      PixG := GetGValue(PixColor);
      PixB := GetBValue(PixColor);
      if PixR <> BaseR then
        Image5.Canvas.Pixels[X, Y] := RGB(Byte(2 * BaseR - PixR), Byte(2 * BaseG - PixG),
          Byte(2 * BaseB - PixB));
    end;
  Image2.Picture := Image6.Picture;
  Image3.Picture := Image5.Picture;
  Reg := TRegIniFile.Create('');
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if Reg.OpenKey('\Software', True) then
      if Reg.OpenKey('\Software\Checkers', True) then
      begin
        RedBar.Position := StrToInt(Reg.ReadString('\Software\Checkers', 'R', '10'));
        GreenBar.Position := StrToInt(Reg.ReadString('\Software\Checkers', 'G', '10'));
        BlueBar.Position := StrToInt(Reg.ReadString('\Software\Checkers', 'B', '10'));
      end;
  finally
    Reg.CloseKey;
    Reg.Free;
  end;
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
    SpeedButton5Click(Sender);
end;

end.
