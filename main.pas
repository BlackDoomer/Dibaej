unit main;

{$MODE OBJFPC}
{$LONGSTRINGS ON}

interface

uses
  SysUtils, Classes,
  Menus, Forms, Controls, Dialogs, StdCtrls,
  SQLdb, IBConnection,
  tables, f_table;

type
  
  { TMainForm }

  TMainForm = class( TForm )
  { interface controls }
    MainMenu                : TMainMenu;
      TablesItem            : TMenuItem;
      AboutItem             : TMenuItem;
      ConnectItem           : TMenuItem;

    LogMemo                 : TMemo;
  { end of interface controls }

    IBConnection: TIBConnection;

    procedure FormCreate( Sender: TObject );

    procedure ConnectItemClick( Sender: TObject );
    procedure AboutItemClick( Sender: TObject );
    procedure TableItemClick( Sender: TObject );

    procedure IBConnectionAfterConnect( Sender: TObject );
    procedure IBConnectionAfterDisconnect( Sender: TObject );
    procedure IBConnectionBeforeConnect( Sender: TObject );

    procedure IBConnectionLog( Sender: TSQLConnection; EventType: TDBEventType; 
                               const Msg: String );
    procedure WriteToLog( Report: String; Separate: Boolean = False );
    procedure ReportError( Sender: TObject; E: Exception );

  private
    { private declarations }
  public
    { public declarations }
  end;

var
  MainForm: TMainForm;

implementation

{$R *.lfm}

{ TMainForm }

procedure TMainForm.FormCreate( Sender: TObject );
var
  i : Integer;
  item : TMenuItem;
begin
  Application.OnException := @ReportError;
  Caption := Application.Title;

  IBConnection.LogEvents := LogAllEvents - [detFetch]; //because Lazarus don's save this. it's bug.

  //registering all tables from corresponding unit in menu
  for i := 0 to High(RegTable) do begin
    item := TMenuItem.Create( TablesItem );
    with item do begin
      Caption := RegTable[i].Caption;
      OnClick := @Self.TableItemClick;
      Tag := i;
    end;
    TablesItem.Add( item );
  end;

  SetLength( TableForm, Length(RegTable) );
  IBConnection.Connected := True;
end;

{ INTERFACE EVENTS =========================================================== }

procedure TMainForm.ConnectItemClick( Sender: TObject );
begin
  if IBConnection.Connected then begin
    if not ( MessageDlg( 'Connection seems established, do you want to reconnect?',
                          mtWarning, mbYesNo, 0 ) = mrYes ) then Exit;
    IBConnection.Close( True );

    { okay, another Lazarus^W SQLdb bug again. if connection was interrupted,
      we're lose any chance to reanimate it because when we try to closedown
      connection (even forced)), we get an error that connection is interrupted
      without any changes on connection context. }
  end;

  IBConnection.Open();
end;

procedure TMainForm.AboutItemClick( Sender: TObject );
begin
  MessageDlg( 'Dibaej - Timetable Editor' + LineEnding +
              'Written by Dmitry D. Chernov, FEFU, 2015',
              mtInformation, [mbOK], 0 );
end;

//callback for dynamically registering table items in their menu
procedure TMainForm.TableItemClick( Sender: TObject );
begin
  ShowTableForm( (Sender as TMenuItem).Tag, IBConnection )
end;

{ DATABASE CONNECTION EVENTS ================================================= }

procedure TMainForm.IBConnectionAfterConnect( Sender: TObject );
begin
  ConnectItem.Checked := True;
  WriteToLog( 'Successfully connected.' + LineEnding );
end;

procedure TMainForm.IBConnectionAfterDisconnect( Sender: TObject );
begin
  ConnectItem.Checked := False;
  WriteToLog( 'Disconnected from database.' + LineEnding );
end;

procedure TMainForm.IBConnectionBeforeConnect( Sender: TObject );
    begin WriteToLog( 'Establishing connection to database...' );
      end;

{ COMMON ROUTINES ============================================================ }

procedure TMainForm.IBConnectionLog( Sender: TSQLConnection; 
                                     EventType: TDBEventType; const Msg: String );
begin
  WriteToLog( Msg, True );
end;

procedure TMainForm.WriteToLog( Report: String; Separate: Boolean = False );
begin
  //if it's initial message, reset welcome text
  if not LogMemo.Enabled then begin
    LogMemo.Lines.Clear();
    LogMemo.Enabled := True;
  end else

  if Separate then begin
    if not ( LogMemo.Lines[ LogMemo.Lines.Count-1 ] = '' ) then
      Report := LineEnding + Report;
    Report += LineEnding;
  end;

  LogMemo.Lines.Add( Report );
end;

//default exception handler
procedure TMainForm.ReportError( Sender: TObject; E: Exception );
begin
  { TODO 1 : Write proper exception handling }
  MessageDlg( E.Message, mtError, [mbOK], 0 );
  WriteToLog( 'An error occurred:' + LineEnding + E.Message, True );
end;

end.

