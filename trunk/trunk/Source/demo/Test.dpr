program Test;

uses
  Forms,
  UnitTest in 'UnitTest.pas' {Form4},
  BeaEngineDelphi in '..\BeaEngineDelphi.pas',
  HookUtils in '..\HookUtils.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TForm4, Form4);
  Application.Run;
end.
