program Dibaej;

{$MODE OBJFPC}
{$LONGSTRINGS ON}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms,
  { you can add units after this }
  main, f_table, f_edit, f_viewer,
  tables, def_tables, common;

{$R *.res}

begin
  RequireDerivedFormResource := True;
  Application.Title := 'Dibaej';
  Application.Initialize();
  Application.CreateForm( TMainForm, MainForm );
  Application.Run();
end.

