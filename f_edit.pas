unit f_edit;

{$MODE OBJFPC}
{$LONGSTRINGS ON}

interface {════════════════════════════════════════════════════════════════════}

uses
  SysUtils, Classes,
  Forms, Controls, Dialogs, StdCtrls, ValEdit,
  SQLdb, db, Grids;

{ –=────────────────────────────────────────────────────────────────────────=– }
type { Editor form class ═════════════════════════════════════════════════════ }

  { TEditForm }

  TEditForm = class( TForm )
  { interface controls }
    GridEdit            : TValueListEditor;
    OkBtn               : TButton;
    CancelBtn           : TButton;
  { end of interface controls }

    SQLQuery            : TSQLQuery;

    procedure FormShow( Sender: TObject );
    procedure FormClose( Sender: TObject; var CloseAction: TCloseAction );
    procedure OkBtnClick( Sender: TObject );
    procedure CancelBtnClick( Sender: TObject );
    procedure GridEditKeyPress( Sender: TObject; var Key: Char );

  private
    { private declarations }
  public
    { public declarations }
  end;

{ –=────────────────────────────────────────────────────────────────────────=– }

function ShowEditForm( TableID: Integer; Fields: TFields;
                       DBTransaction: TSQLTransaction ): Boolean;

implementation {═══════════════════════════════════════════════════════════════}

uses tables, f_table;

var
  RowEdit: array[0..255] of record //256 is good enough, haters gonna hate
    ID: Integer;        //row surrogate key
    Form: TEditForm;    //editor form
    Table: TTableInfo;  //table metadata object
  end;

{$R *.lfm}

{ –=────────────────────────────────────────────────────────────────────────=– }

function ShowEditForm( TableID: Integer; Fields: TFields;
                       DBTransaction: TSQLTransaction ): Boolean;
var
  i, empty, keyid : Integer;
begin
  //check if editor for this field is already opened
  keyid := Fields.Fields[ RegTable[TableID].KeyColumn ].AsInteger;
  empty := -1;
  for i := High(RowEdit) downto Low(RowEdit) do begin
    if not Assigned( RowEdit[i].Form ) then
      empty := i
    else
      if ( RowEdit[i].ID = keyid ) then begin
        RowEdit[i].Form.ShowOnTop();
        Exit( False );
      end;    
  end;

  if ( empty = -1 ) then
    raise Exception.Create('Too many editors.');

  //evrything seems OK, let's create form...
  RowEdit[empty].Form := TEditForm.Create( TableForm[TableID] );
  RowEdit[empty].ID := keyid;
  RowEdit[empty].Table := RegTable[TableID];
  with RowEdit[empty].Form do begin
    Tag := empty;
    SQLQuery.Transaction := DBTransaction;
    SQLQuery.DataBase := DBTransaction.DataBase;

    //...and fill editor grid with keys and values
    for i := 0 to RegTable[TableID].ColumnsNum-1 do
      GridEdit.InsertRow( RegTable[TableID].ColumnCaption(i),
                          Fields.Fields[i].AsString, True );
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
  Caption := 'ID ' + IntToStr( RowEdit[Tag].ID ) + ' - ' + RowEdit[Tag].Table.Caption;

  //setting editor grid more complexly
  GridEdit.ItemProps[ RowEdit[Tag].Table.KeyColumn ].ReadOnly := True;

  for i := 0 to RowEdit[Tag].Table.ColumnsNum-1 do begin
    column := RowEdit[Tag].Table.Columns(i);
    if ( column.RefTable <> nil ) then begin
      SQLQuery.Active := False;
      SQLQuery.SQL.Text := column.RefTable.GetSelectSQL( column.Name );
      SQLQuery.Active := True;

      GridEdit.ItemProps[i].ReadOnly := True;
      GridEdit.ItemProps[i].EditStyle := esPickList;
      while not SQLQuery.EOF do begin
        GridEdit.ItemProps[i].PickList.AddObject( SQLQuery.Fields.Fields[1].AsString,
                                                  TObject( SQLQuery.Fields.Fields[0].AsInteger ) );
        SQLQuery.Next();
      end;
    end;
  end;

  GridEdit.Row := -1;
end;

procedure TEditForm.FormClose( Sender: TObject; var CloseAction: TCloseAction );
begin
  RowEdit[Tag].Form := nil;
  CloseAction := caFree;
end;

{ –=────────────────────────────────────────────────────────────────────────=– }

procedure TEditForm.OkBtnClick( Sender: TObject );
var
  i : Integer;
  param : String;
begin
  SQLQuery.SQL.Text := RowEdit[Tag].Table.GetUpdateSQL();
  SQLQuery.ParamByName('0').AsInteger := RowEdit[Tag].ID;

  for i := 0 to GridEdit.RowCount-2 do begin
    with GridEdit do begin
      param := Cells[1, i+1];
      //if this column is referenced, we use ID instead of visible value
      if ( ItemProps[i].EditStyle = esPickList ) then begin
        Row := i+1; //this sets necessary combobox to Editor property
        param := IntToStr( Integer(
          ItemProps[i].PickList.Objects[ TComboBox(Editor).ItemIndex ] ) );
      end;
    end;

    //simple datatypes support
    with SQLQuery.ParamByName( IntToStr(i+1) ) do begin
      AsString := param;
      if ( RowEdit[Tag].Table.Columns(i).DataType = DT_NUMERIC ) then
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

