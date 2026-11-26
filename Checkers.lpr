program Checkers;

{ Шашки, Р.Ш. Мухутдинов, ВМК, 2003. Исходник восстановлен по exe (Delphi 5) под Lazarus. }

{$mode delphi}{$H+}

uses
  Interfaces, Forms, MainWindow, ColorsWindow;

{$R *.res}

begin
  RequireDerivedFormResource := True;
  Application.Scaled := False;
  Application.Initialize;
  Application.Title := 'Шашки';
  Application.CreateForm(TMainForm, MainForm);
  Application.CreateForm(TColorsForm, ColorsForm);
  Application.Run;
end.
