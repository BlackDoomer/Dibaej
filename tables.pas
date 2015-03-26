unit tables;

{ Note from developer:
  Both of "tables" and "f_table" units are just a interdependent prototypes.
  Some things should be rewritten partially or even completely, I think. }

{$MODE OBJFPC}
{$LONGSTRINGS ON}

{$MACRO ON}
{$DEFINE ALIAS_TABLE_DEFINITION_CLASS :=
  class( TTableEdit ) constructor Create(); override; end} //here u smilin' ;3

interface

uses
  SysUtils, Classes,
  SQLdb,
  Forms, Controls, Dialogs, f_table;

type

  TTableEdit = class;

  //general column class
  TColumnInfo = record
    Name               : String;      //if referenced, points to another table
    Caption            : String;      //if empty, Name will be used
    Width              : Byte;        //if 0, will be automatic
    RefTable           : TTableEdit;  //is that column is from another table?
    ColKey             : String;      //joining key in our table
    RefKey             : String;      //joining key in referenced table
  end;

  //general table class
  TTableEdit = class
    private
      FName          : String;
      FCaption       : String;
      FForm          : TTableForm;
      FColumns       : array of TColumnInfo;

      procedure Fetch();
    public
      constructor Create(); virtual; abstract;

      procedure Show( DBConnection: TSQLConnection );
      procedure FormClose( Sender: TObject; var CloseAction: TCloseAction );

      procedure AddColumn( AName: String = 'ID'; ACaption: String = '';
                           AWidth: Byte = 0; ARefTable: TTableEdit = nil;
                           AColKey: String = ''; ARefKey: String = 'ID' );

      property Caption: String read FCaption;
      property Form: TTableForm read FForm;
  end;

  TRegTables = ( tblClassrooms, tblGroups, tblGroupsSubjects, tblLessons,
                 tblSubjects, tblTeachers, tblTeachersSubjects, tblWeekday,
                 tblSummary );

  TClassroomsTbl       = ALIAS_TABLE_DEFINITION_CLASS;
  TGroupsTbl           = ALIAS_TABLE_DEFINITION_CLASS;
  TGroupsSubjectsTbl   = ALIAS_TABLE_DEFINITION_CLASS;
  TLessonsTbl          = ALIAS_TABLE_DEFINITION_CLASS;
  TSubjectsTbl         = ALIAS_TABLE_DEFINITION_CLASS;
  TTeachersTbl         = ALIAS_TABLE_DEFINITION_CLASS;
  TTeachersSubjectsTbl = ALIAS_TABLE_DEFINITION_CLASS;
  TWeekdayTbl          = ALIAS_TABLE_DEFINITION_CLASS;

  TSummaryTbl          = ALIAS_TABLE_DEFINITION_CLASS;

var
  RegTable: array[TRegTables] of TTableEdit;

implementation

{ FORM PROCESSING ROUTINES =================================================== }

procedure TTableEdit.Show( DBConnection: TSQLConnection );
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
procedure TTableEdit.FormClose( Sender: TObject; var CloseAction: TCloseAction );
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

procedure TTableEdit.AddColumn( AName: String = 'ID'; ACaption: String = '';
                                AWidth: Byte = 0; ARefTable: TTableEdit = nil;
                                AColKey: String = ''; ARefKey: String = 'ID' );
begin
  SetLength( FColumns, Length( FColumns )+1 );
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
procedure TTableEdit.Fetch();
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

{ TABLE DEFINITION CLASSES CONSTRUCTORS ====================================== }

constructor TClassroomsTbl.Create;
begin
  FName := 'CLASSROOMS';
  FCaption := 'Audiences';
  AddColumn();
  AddColumn( 'NAME', 'No.' );
end;

constructor TGroupsTbl.Create;
begin
  FName := 'GROUPS';
  FCaption := 'Groups';
  AddColumn();
  AddColumn( 'NAME', 'Code' );
end;

constructor TGroupsSubjectsTbl.Create;
begin
  FName := 'GROUPS_SUBJECTS';
  FCaption := 'Groups subjects';
  AddColumn(   'GROUP_ID', 'Group ID' );
  AddColumn( 'SUBJECT_ID', 'Subject ID' );
end;

constructor TLessonsTbl.Create;
begin
  FName := 'LESSONS';
  FCaption := 'Pairs timetable';
  AddColumn(    'PAIR_ID', 'Pair ID' );
  AddColumn( 'WEEKDAY_ID', 'Weekday ID' );
  AddColumn(   'GROUP_ID', 'Group ID' );
  AddColumn( 'SUBJECT_ID', 'Subject ID' );
  AddColumn(   'CLASS_ID', 'Audience ID' );
  AddColumn( 'TEACHER_ID', 'Teacher ID' );
end;

constructor TSubjectsTbl.Create;
begin
  FName := 'SUBJECTS';
  FCaption := 'Subjects';
  AddColumn();
  AddColumn( 'NAME', 'Subject' );
end;

constructor TTeachersTbl.Create;
begin
  FName := 'TEACHERS';
  FCaption := 'Teachers';
  AddColumn();
  AddColumn( 'NAME', 'Name' );
end;

constructor TTeachersSubjectsTbl.Create;
begin
  FName := 'TEACHERS_SUBJECTS';
  FCaption := 'Teachers subjects';
  AddColumn( 'TEACHER_ID', 'Teacher ID' );
  AddColumn( 'SUBJECT_ID', 'Subject ID' );
end;

constructor TWeekdayTbl.Create;
begin
  FName := 'WEEKDAY';
  FCaption := 'Weekdays';
  AddColumn();
  AddColumn( 'WEEKDAY', 'Weekday' );
end;

constructor TSummaryTbl.Create;
begin
  FName := 'LESSONS';
  FCaption := '-= Timetable Summary =-';
  AddColumn( 'PAIR_ID', 'Pair No.' );
  AddColumn( 'WEEKDAY', 'Weekday', 0, RegTable[tblWeekday], 'WEEKDAY_ID' );
  AddColumn( 'NAME', 'Group No.', 0, RegTable[tblGroups], 'GROUP_ID' );
  AddColumn( 'NAME', 'Subject', 0, RegTable[tblSubjects], 'SUBJECT_ID' );
  AddColumn( 'NAME', 'Audience', 0, RegTable[tblClassrooms], 'CLASS_ID' );
  AddColumn( 'NAME', 'Teacher', 0, RegTable[tblTeachers], 'TEACHER_ID' );
end;

{ ============================================================================ }

initialization

  RegTable[tblClassrooms]         := TClassroomsTbl.Create;
  RegTable[tblGroups]             := TGroupsTbl.Create;
  RegTable[tblGroupsSubjects]     := TGroupsSubjectsTbl.Create;
  RegTable[tblLessons]            := TLessonsTbl.Create;
  RegTable[tblSubjects]           := TSubjectsTbl.Create;
  RegTable[tblTeachers]           := TTeachersTbl.Create;
  RegTable[tblTeachersSubjects]   := TTeachersSubjectsTbl.Create;
  RegTable[tblWeekday]            := TWeekdayTbl.Create;

  RegTable[tblSummary]            := TSummaryTbl.Create;

end.

