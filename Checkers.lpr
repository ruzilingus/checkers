program Checkers;

{ Шашки, Р.Ш. Мухутдинов, ВМК, 2003. Исходник восстановлен по exe (Delphi 5) под Lazarus. }

{$mode delphi}{$H+}

uses
  Interfaces, Forms, Unit1, Unit2;

{$R *.res}

begin
  RequireDerivedFormResource := True;
  Application.Scaled := False;
  Application.Initialize;
  Application.Title := 'Шашки';
  Application.CreateForm(TForm1, Form1);
  Application.CreateForm(TForm2, Form2);
  Application.Run;
end.
