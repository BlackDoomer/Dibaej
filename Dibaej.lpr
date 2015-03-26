program Dibaej;

{$MODE OBJFPC}
{$LONGSTRINGS ON}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms, main, f_table, tables
  { you can add units after this };

{$R *.res}

begin
  RequireDerivedFormResource := True;
  Application.Title := 'Dibaej';
  Application.Initialize();
  Application.CreateForm(TMainForm, MainForm);
  Application.Run();
end.

