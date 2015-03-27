unit tables;

{ Note from developer:
  Both of "tables" and "f_table" units are just a interdependent prototypes.
  Some things should be rewritten partially or even completely, I think. }

{$MODE OBJFPC}
{$LONGSTRINGS ON}

interface

uses
  SysUtils, Classes,
  SQLdb,
  Forms, Controls, Dialogs, f_table;

type

  TTableInfo = class;

  //general column class
  TColumnInfo = record
    Name               : String;      //if referenced, points to another table
    Caption            : String;      //if empty, Name will be used
    Width              : Byte;        //if 0, will be automatic
    RefTable           : TTableInfo;  //is that column is from another table?
    ColKey             : String;      //joining key in our table
    RefKey             : String;      //joining key in referenced table
  end;

  //general table class
  TTableInfo = class
    private
      FName          : String;
      FCaption       : String;
      FForm          : TTableForm;
      FColumns       : array of TColumnInfo;

      procedure Fetch();
    public
      constructor Create( AName, ACaption: String );

      procedure Show( DBConnection: TSQLConnection );
      procedure FormClose( Sender: TObject; var CloseAction: TCloseAction );

      procedure AddColumn( AName: String = 'ID'; ACaption: String = '';
                           AWidth: Byte = 0; ARefTable: TTableInfo = nil;
                           AColKey: String = ''; ARefKey: String = 'ID' );

      property Caption: String read FCaption;
      property Form: TTableForm read FForm;
  end;

  TRegTables = ( tblClassrooms, tblGroups, tblGroupsSubjects, tblLessons,
                 tblSubjects, tblTeachers, tblTeachersSubjects, tblWeekday,
                 tblSummary );

var
  RegTable: array of TTableInfo;

implementation

constructor TTableInfo.Create( AName, ACaption: String );
begin
  FName := AName;
  FCaption := ACaption;
  SetLength( RegTable, Length(RegTable)+1 );
  RegTable[ High(RegTable) ] := Self;
end;

{ FORM PROCESSING ROUTINES =================================================== }

procedure TTableInfo.Show( DBConnection: TSQLConnection );
begin
  if Assigned( FForm ) then
    FForm.ShowOnTop()
  else begin
    Application.CreateForm( TTableForm, FForm );
    with FForm do begin
      Caption := Self.FCaption;
      OnClose := @Self.FormClose;

      SQLTransaction.DataBase := DBConnection;
      SQLQuery.DataBase := DBConnection;

      SQLTransaction.Active := True;
      Fetch();
    end;
  end;
end;

{ TODO 3 : Move this somehow to f_table unit? }
procedure TTableInfo.FormClose( Sender: TObject; var CloseAction: TCloseAction );
begin
  with FForm do
    if not DBGrid.ReadOnly then
      case MessageDlg( 'Would you like to apply your changes?' + LineEnding +
                       '(if no changes were made, sorry me and press "No")',
                       mtConfirmation, mbYesNoCancel, 0 ) of
        mrYes: begin
          SQLQuery.ApplyUpdates();
          SQLTransaction.Action := caCommit;
        end;

        mrNo:
          SQLTransaction.Action := caRollback;

        else begin
          CloseAction := caNone;
          Exit;
        end;
      end;

  //transaction will be performed on form close
  FForm := nil;
  CloseAction := caFree;
end;

{ COMMON ROUTINES ============================================================ }

procedure TTableInfo.AddColumn( AName: String = 'ID'; ACaption: String = '';
                                AWidth: Byte = 0; ARefTable: TTableInfo = nil;
                                AColKey: String = ''; ARefKey: String = 'ID' );
begin
  SetLength( FColumns, Length(FColumns)+1 );
  with FColumns[ High( FColumns ) ] do begin
    Name := AName;
    Caption := ACaption;
    Width := AWidth;
    RefTable := ARefTable;
    ColKey := AColKey;
    RefKey := ARefKey;
  end;
end;

//this builds SQL SELECT command from table data and executes it
procedure TTableInfo.Fetch();
var
  cmd : String;
  init : Boolean;
  ColInf : TColumnInfo;
  i : Integer;
begin
  cmd := 'select ';

  init := True;
  for ColInf in FColumns do begin
    if init then init := False else cmd += ', ';
    if ( ColInf.RefTable = nil ) then cmd += FName
                                 else cmd += ColInf.RefTable.FName;
    cmd += '.' + ColInf.Name;
  end;

  cmd += ' from ' + FName;

  //support for table references
  for ColInf in FColumns do
    if not ( ColInf.RefTable = nil ) then begin
      { TODO 2 : Possibility to edit referenced tables? Now they just locks. }
      FForm.DBGrid.ReadOnly := True;
      cmd += ' inner join ' + ColInf.RefTable.FName +
             ' on ' + FName + '.' + ColInf.ColKey +
             ' = ' + ColInf.RefTable.FName + '.' + ColInf.RefKey;
    end;

  //command is prepared, let's execute
  FForm.SQLQuery.Active := False;
  FForm.SQLQuery.SQL.Text := cmd;
  FForm.SQLQuery.Active := True;

  //next we set predefined columns captions and widths
  for i := 0 to High( FColumns ) do
    with FForm.DBGrid.Columns.Items[i] do begin
      if not ( FColumns[i].Caption = '' ) then
        Title.Caption := FColumns[i].Caption;
      if ( FColumns[i].Width > 0 ) then
        Width := FColumns[i].Width;
    end;
end;

end.

