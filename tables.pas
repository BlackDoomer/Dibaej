unit tables;

{$MODE OBJFPC}
{$LONGSTRINGS ON}

interface

uses
  SysUtils, Classes,
  SQLdb, DBGrids, f_table;

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
      FColumns       : array of TColumnInfo;

    public
      constructor Create( AName, ACaption: String );
      procedure AddColumn( AName: String = 'ID'; ACaption: String = '';
                           AWidth: Byte = 0; ARefTable: TTableInfo = nil;
                           AColKey: String = ''; ARefKey: String = 'ID' );
      procedure Fetch( DBGrid: TDBGrid );

      property Caption: String read FCaption;
  end;

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
procedure TTableInfo.Fetch( DBGrid: TDBGrid );
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
      DBGrid.ReadOnly := True;
      cmd += ' inner join ' + ColInf.RefTable.FName +
             ' on ' + FName + '.' + ColInf.ColKey +
             ' = ' + ColInf.RefTable.FName + '.' + ColInf.RefKey;
    end;

  //command is prepared, let's execute
  with (DBGrid.DataSource.DataSet as TSQLQuery) do begin
    Active := False;
    SQL.Text := cmd;
    Active := True;
  end;

  //next we set predefined columns captions and widths
  for i := 0 to High( FColumns ) do
    with DBGrid.Columns.Items[i] do begin
      if not ( FColumns[i].Caption = '' ) then
        Title.Caption := FColumns[i].Caption;
      if ( FColumns[i].Width > 0 ) then
        Width := FColumns[i].Width;
    end;
end;

end.

