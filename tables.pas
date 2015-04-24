unit tables;

{$MODE OBJFPC}
{$LONGSTRINGS ON}

interface

uses
  SysUtils, Classes,
  StdCtrls, DBGrids;

type

  TTableInfo = class;

  //general column class
  TColumnInfo = record
    UserEdit           : Boolean;     //is column could be edited by user
    Name               : String;      //if referenced, points to another table
    Caption            : String;      //if empty, Name will be used
    Width              : Byte;        //if 0, will be automatic
    RefTable           : TTableInfo;  //is that column is from another table?
    ColKey             : String;      //joining key in our table
    RefKey             : String;      //joining key in referenced table
  end;

  //general table class
  
  { TTableInfo }

  TTableInfo = class
    private
      FName          : String;
      FCaption       : String;
      FColumns       : array of TColumnInfo;
      FReferenced    : Boolean;

      function GetColumnName( ColInf: TColumnInfo ): String;
      function GetColumnCaption( ColInf: TColumnInfo ): String;
    public
      constructor Create( AName, ACaption: String );
      procedure AddColumn( AUserEdit: Boolean = False;
                           AName: String = 'ID'; ACaption: String = '';
                           AWidth: Byte = 0; ARefTable: TTableInfo = nil;
                           AColKey: String = ''; ARefKey: String = 'ID' );
      function GetSelectSQL(): String;
      function ColumnName( Index: Integer ): String;
      function ColumnCaption( Index: Integer ): String;
      procedure AdjustDBGrid( DBGrid: TDBGrid );
      procedure FillCombobox( ComboBox: TComboBox );

      property Caption: String read FCaption;
  end;

var
  RegTable: array of TTableInfo;

implementation

constructor TTableInfo.Create( AName, ACaption: String );
begin
  FName := AName;
  FCaption := ACaption;
  FReferenced := False;
  SetLength( RegTable, Length(RegTable)+1 );
  RegTable[ High(RegTable) ] := Self;
end;

{ COMMON ROUTINES ============================================================ }

procedure TTableInfo.AddColumn( AUserEdit: Boolean = False;
                                AName: String = 'ID'; ACaption: String = '';
                                AWidth: Byte = 0; ARefTable: TTableInfo = nil;
                                AColKey: String = ''; ARefKey: String = 'ID' );
begin
  SetLength( FColumns, Length(FColumns)+1 );
  with FColumns[ High( FColumns ) ] do begin
    UserEdit := AUserEdit;
    Name := AName;
    Caption := ACaption;
    Width := AWidth;
    RefTable := ARefTable;
    ColKey := AColKey;
    RefKey := ARefKey;
  end;
  if not ( ARefTable = nil ) then FReferenced := True;
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
    ColNames += GetColumnName( ColInf );

    //support for table references
    if not ( ColInf.RefTable = nil ) then
      TableRefs += ' inner join ' + ColInf.RefTable.FName +
                   ' on ' + FName + '.' + ColInf.ColKey +
                   ' = ' + ColInf.RefTable.FName + '.' + ColInf.RefKey;
  end;

  Result := 'select ' + ColNames + ' from ' + FName + TableRefs;
end;

function TTableInfo.GetColumnName( ColInf: TColumnInfo ): String;
begin
  if ( ColInf.RefTable = nil ) then Result := FName
                               else Result := ColInf.RefTable.FName;
  Result += '.' + ColInf.Name;
end;

function TTableInfo.ColumnName(Index: Integer): String;
   begin Result := GetColumnName( FColumns[Index] );
     end;

function TTableInfo.GetColumnCaption( ColInf: TColumnInfo ): String;
begin
  if ( ColInf.Caption = '' ) then begin
    if FReferenced then
      Result := GetColumnName( ColInf )
    else
      Result := ColInf.Name;
  end else begin
    Result := ColInf.Caption;
  end;
end;

function TTableInfo.ColumnCaption( Index: Integer ): String;
   begin Result := GetColumnCaption( FColumns[Index] );
     end;

//sets predefined columns captions and widths
procedure TTableInfo.AdjustDBGrid( DBGrid: TDBGrid );
var
  i : Integer;
begin
  { TODO 2 : Possibility to edit referenced tables? Now they just locks. }
  DBGrid.ReadOnly := FReferenced;

  for i := 0 to High( FColumns ) do
    with DBGrid.Columns.Items[i] do begin
      Field.Required := FColumns[i].UserEdit;
      ReadOnly := not Field.Required;
      Title.Caption := GetColumnCaption( FColumns[i] );
      if ( FColumns[i].Width > 0 ) then
        Width := FColumns[i].Width;
    end;
end;

//fills specified combobox with columns captions
procedure TTableInfo.FillCombobox( ComboBox: TComboBox );
var
  ColInf : TColumnInfo;
begin
  ComboBox.Clear();
  for ColInf in FColumns do
    ComboBox.Items.Add( GetColumnCaption( ColInf ) );
  ComboBox.ItemIndex := 0;
end;

end.

