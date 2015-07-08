unit f_edit;

{$MODE OBJFPC}
{$LONGSTRINGS ON}

interface {════════════════════════════════════════════════════════════════════}

uses
  SysUtils, Classes,
  Forms, Controls, Dialogs, StdCtrls, ValEdit,
  SQLdb, db, Grids,
  tables;

{ –=────────────────────────────────────────────────────────────────────────=– }
type { Editor form class ═════════════════════════════════════════════════════ }

  TEditForm = class( TForm )
  { interface controls }
    GridEdit       : TValueListEditor;
    OkBtn          : TButton;
    CancelBtn      : TButton;
  { end of interface controls }

    SQLQuery       : TSQLQuery;

    procedure FormShow( Sender: TObject );
    procedure FormClose( Sender: TObject; var CloseAction: TCloseAction );
    procedure OkBtnClick( Sender: TObject );
    procedure CancelBtnClick( Sender: TObject );
    procedure GridEditKeyPress( Sender: TObject; var Key: Char );

  private
    FEditing : Boolean;
    FRowID : Integer; //row surrogate key
    FTable : TTableInfo;
  public
    property Editing: Boolean read FEditing write FEditing;
    property RowID: Integer read FRowID write FRowID;
    property Table: TTableInfo read FTable write FTable;
  end;

{ –=────────────────────────────────────────────────────────────────────────=– }

function ShowEditForm( TableID: Integer; Fields: TFields;
                       DBTransaction: TSQLTransaction ): Boolean;

implementation {═══════════════════════════════════════════════════════════════}

uses f_table, common;

var
  RowEdit: array[0..255] of TEditForm; //256 is good enough, haters gonna hate

{$R *.lfm}

{ –=────────────────────────────────────────────────────────────────────────=– }

function ShowEditForm( TableID: Integer; Fields: TFields;
                       DBTransaction: TSQLTransaction ): Boolean;
var
  i, empty, keyid : Integer;
  edit : Boolean;
  value : String;
begin
  edit := Fields <> nil;
  if edit then keyid := Fields.Fields[ RegTable[TableID].KeyColumn ].AsInteger
          else keyid := -1;

  //check if editor for this field is already opened
  empty := -1;
  for i := High(RowEdit) downto Low(RowEdit) do begin
    if not Assigned( RowEdit[i] ) then
      empty := i
    else
      { TODO: NOT A KEY ID }
      if ( RowEdit[i].RowID = keyid ) then begin
        RowEdit[i].ShowOnTop();
        Exit( False );
      end;    
  end;

  if ( empty = -1 ) then
    raise Exception.Create('Too many editors.');

  //everything seems OK, let's create form...
  RowEdit[empty] := TEditForm.Create( TableForm[TableID] );
  with RowEdit[empty] do begin
    Tag := empty;
    RowID := keyid;
    Table := RegTable[TableID];
    SQLQuery.Transaction := DBTransaction;
    SQLQuery.DataBase := DBTransaction.DataBase;

    //...and fill editor grid with keys (and values)
    value := '';
    for i := 0 to Table.ColumnsNum-1 do begin
      if edit then value := Fields.Fields[i].AsString;
      GridEdit.InsertRow( Table.ColumnCaption(i), value, True );
    end;
    Editing := edit;
    Show();
  end;

  Result := True;
end;

{ –=────────────────────────────────────────────────────────────────────────=– }
{ ═ TEditForm ──────────────────────────────────────────────────────────────── }

//FormShow used as FormCreate to prepare form somehow before (see ShowEditForm)
procedure TEditForm.FormShow( Sender: TObject );
var
  i : Integer;
  column : TColumnInfo;
begin
  if FEditing then Caption := 'ID ' + IntToStr( FRowID ) 
              else Caption := 'Insert';
  Caption := Caption + ' - ' + FTable.Caption;

  //setting editor grid more complexly
  GridEdit.ItemProps[ FTable.KeyColumn ].ReadOnly := True;

  for i := 0 to FTable.ColumnsNum-1 do begin
    column := FTable.Columns(i);
    if ( column.RefTable <> nil ) then
      with GridEdit.ItemProps[i] do begin
        ReadOnly := True;
        EditStyle := esPickList;
        GetIDRelation( column.RefTable, column.Name, SQLQuery, PickList );
      end;
  end;

  GridEdit.Row := -1;
end;

procedure TEditForm.FormClose( Sender: TObject; var CloseAction: TCloseAction );
begin
  RowEdit[Tag] := nil;
  CloseAction := caFree;
end;

{ –=────────────────────────────────────────────────────────────────────────=– }

procedure TEditForm.OkBtnClick( Sender: TObject );
var
  i, ind : Integer;
  param : String;
  column : TColumnInfo;
begin
  if FEditing then begin
    SQLQuery.SQL.Text := FTable.GetUpdateSQL();
    SQLQuery.ParamByName('0').AsInteger := FRowID;
  end else
    SQLQuery.SQL.Text := FTable.GetInsertSQL();

  for i := 0 to GridEdit.RowCount-2 do begin
    column := FTable.Columns(i);
    with GridEdit do begin
      param := Cells[1, i+1];
      if ( column.RefTable <> nil ) then begin
        Row := i+1; //this sets necessary combobox to Editor property
        ind := TComboBox(Editor).ItemIndex;
        if (ind < 0) then //if something weren't selected, go out
          raise Exception.Create('Some values were not selected.');
        param := IntToStr( StrID( ItemProps[i].PickList, ind ) );
      end;
    end;

    //simple datatypes support
    with SQLQuery.ParamByName( IntToStr(i+1) ) do begin
      AsString := param;
      if ( column.DataType = DT_NUMERIC ) then
        DataType := ftInteger;
    end;

  end;

  SQLQuery.ExecSQL();
  (Owner as TTableForm).RemoteUpdate();
  Close();
end;

procedure TEditForm.CancelBtnClick( Sender: TObject );
begin
  Close();
end;

{ –=────────────────────────────────────────────────────────────────────────=– }

procedure TEditForm.GridEditKeyPress( Sender: TObject; var Key: Char );
begin
  if ( RowEdit[Tag].Table.Columns( GridEdit.Row-1 ).DataType = DT_NUMERIC ) then begin
    if not ( Key in ['0'..'9', #8, #127] ) then Key := #0;
  end;
end;

end.

