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
      FReadOnly      : Boolean;

    public
      constructor Create( AName, ACaption: String );
      procedure AddColumn( AName: String = 'ID'; ACaption: String = '';
                           AWidth: Byte = 0; ARefTable: TTableInfo = nil;
                           AColKey: String = ''; ARefKey: String = 'ID' );
      function GetSelectSQL(): String;
      procedure Fetch( DBGrid: TDBGrid; SQLQuery: TSQLQuery );

      property Caption: String read FCaption;
  end;

var
  RegTable: array of TTableInfo;

implementation

constructor TTableInfo.Create( AName, ACaption: String );
begin
  FName := AName;
  FCaption := ACaption;
  FReadOnly := False;
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
  { TODO 2 : Possibility to edit referenced tables? Now they just locks. }
  if not ( ARefTable = nil ) then FReadOnly := True;
end;

function TTableInfo.GetSelectSQL(): String;
var
  ColInf : TColumnInfo;
  ColNames, TableRefs : String;
begin
  ColNames := '';
  TableRefs := '';

  for ColInf in FColumns do begin
    if not ( ColNames = '' ) then ColNames += ', ';

    if ( ColInf.RefTable = nil ) then
      ColNames += FName
    else begin
      ColNames += ColInf.RefTable.FName;

      //support for table references
      TableRefs += ' inner join ' + ColInf.RefTable.FName +
                   ' on ' + FName + '.' + ColInf.ColKey +
                   ' = ' + ColInf.RefTable.FName + '.' + ColInf.RefKey;
    end;

    ColNames += '.' + ColInf.Name;
  end;

  Result := 'select ' + ColNames + ' from ' + FName + TableRefs;
end;

procedure TTableInfo.Fetch( DBGrid: TDBGrid; SQLQuery: TSQLQuery );
var
  i : Integer;
begin
  DBGrid.ReadOnly := FReadOnly;

  //let's retrieve data from table
  SQLQuery.Active := False;
  SQLQuery.SQL.Text := GetSelectSQL();
  SQLQuery.Active := True;

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

