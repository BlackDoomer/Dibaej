unit common;

{$MODE OBJFPC}
{$LONGSTRINGS ON}

interface {════════════════════════════════════════════════════════════════════}

uses
  SysUtils, Classes,
  CheckLst, SQLdb, tables;

{ –=────────────────────────────────────────────────────────────────────────=– }

procedure GetIDRelation( Table: TTableInfo; ColName: String;
                         SQLQuery: TSQLQuery; Storage: TStrings );
function StrID( Strings: TStrings; Index: Integer ): Integer;
function IndexID( Strings: TStrings; ID: Integer ): Integer;

function CListCheckedCount( CList: TCheckListBox ): Integer;
function CListCheckedIndex( CList: TCheckListBox; Index: Integer ): Integer;

implementation {═══════════════════════════════════════════════════════════════}

//retrieves <ID;COLUMN> relations from table and stores them in TStrings
procedure GetIDRelation( Table: TTableInfo; ColName: String;
                         SQLQuery: TSQLQuery; Storage: TStrings );
begin
  SQLQuery.Active := False;
  SQLQuery.SQL.Text := Table.GetSelectSQL( ColName );
  SQLQuery.Active := True;

  Storage.Clear();
  while not SQLQuery.EOF do begin
    //IDs are stores in pointers that are associated with strings in TStrings
    Storage.AddObject( SQLQuery.Fields.Fields[1].AsString,
      TObject( SQLQuery.Fields.Fields[0].AsInteger ) );
    SQLQuery.Next();
  end;

  SQLQuery.Active := False;
end;

function StrID( Strings: TStrings; Index: Integer ): Integer;
begin
  Result := Integer( Strings.Objects[Index] );
end;

function IndexID( Strings: TStrings; ID: Integer ): Integer;
begin
  Result := Strings.IndexOfObject( TObject(ID) );
end;

{ –=────────────────────────────────────────────────────────────────────────=– }

function CListCheckedCount( CList: TCheckListBox ): Integer;
var
  i : Integer;
begin
  Result := 0;
  for i := 0 to CList.Count-1 do
    if CList.Checked[i] then Result += 1;
end;

function CListCheckedIndex( CList: TCheckListBox; Index: Integer ): Integer;
var
  i : Integer;
begin
  Result := Index;
  for i := 0 to Index do
    if not CList.Checked[i] then Result -= 1;
end;

end.

