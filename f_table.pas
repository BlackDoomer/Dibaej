unit f_table;

{$MODE OBJFPC}
{$LONGSTRINGS ON}

interface

uses
  SysUtils, Classes,
  Forms, Controls, Dialogs, StdCtrls, CheckLst,
  SQLdb, db, DBGrids, tables;

type

  { TTableForm }

  TTableForm = class( TForm )
  { interface controls }
    DBGrid              : TDBGrid;
    AddEntryBtn         : TButton;
    EraseEntryBtn       : TButton;
    CommitBtn           : TButton;
    ResetBtn            : TButton;
    RefreshBtn          : TButton;

    FiltersBox          : TGroupBox;
      FiltersCList      : TCheckListBox;
      ColumnsCB         : TComboBox;
      OperationsCB      : TComboBox;
      ConstEdit         : TEdit;
      LogicCB           : TComboBox;
      AddFilterBtn      : TButton;
      ClearFiltersBtn   : TButton;
      FiltersCheck      : TCheckBox;

  { database controls }
    SQLTransaction  : TSQLTransaction;
    SQLQuery        : TSQLQuery;
    DataSource      : TDataSource;

    procedure FormClose( Sender: TObject; var CloseAction: TCloseAction );
    procedure CommitBtnClick( Sender: TObject );
    procedure ResetBtnClick( Sender: TObject );
    procedure RefreshBtnClick( Sender: TObject );
    procedure DBGridTitleClick( Column: TColumn );

    procedure AddFilterBtnClick( Sender: TObject );
    procedure ClearFiltersBtnClick( Sender: TObject );
    procedure FiltersCListClick( Sender: TObject );
    procedure FilterChange( Sender: TObject );

    procedure AddEntryBtnClick( Sender: TObject );
    procedure EraseEntryBtnClick( Sender: TObject );
    procedure DataSourceUpdateData( Sender: TObject );

  private
    FFilters : TFilterContext;
    FSortIndex : Integer;
    FDescSort : Boolean;
    FDataEdited : Boolean;
    procedure Fetch();
    procedure AdjustControls();
    function DiscardChanges(): Boolean;
    procedure UpdateFilter( Index: Integer );

  public
    { public declarations }
  end;

  function ShowTableForm( Index: Integer; DBConnection: TSQLConnection ): Boolean;

var
  TableForm : array of TTableForm;

implementation

{$R *.lfm}

//returns FALSE if form was already created, TRUE otherwise
function ShowTableForm( Index: Integer; DBConnection: TSQLConnection ): Boolean;
begin

  if Assigned( TableForm[Index] ) then begin
    TableForm[Index].ShowOnTop();
    Result := False;
  end else begin
    Application.CreateForm( TTableForm, TableForm[Index] );
    with TableForm[Index] do begin
      Tag := Index;
      Caption := RegTable[Index].Caption;
      FSortIndex := -1;
      FDescSort := True; //will be set to FALSE on first sorting

      FFilters := TFilterContext.Create( Index );
      SQLTransaction.DataBase := DBConnection;
      SQLQuery.DataBase := DBConnection;
      SQLTransaction.Active := True;
      Fetch();

      RegTable[Index].GetColumns( ColumnsCB.Items );
      ColumnsCB.ItemIndex := 0;
      OperationsCB.Items.AddStrings( FilterOperations );
      OperationsCB.ItemIndex := 0;
      LogicCB.Items.AddStrings( FilterLogic );
      LogicCB.ItemIndex := 0;

      Result := True;
    end;
  end;

end;

{ TTableForm }

procedure TTableForm.FormClose( Sender: TObject; var CloseAction: TCloseAction );
begin
  if DiscardChanges() then begin
    SQLTransaction.Rollback();
    TableForm[Tag] := nil;
    CloseAction := caFree;
  end else begin
    CloseAction := TCloseAction.caNone; //caNone is also a transaction state
  end;
end;

procedure TTableForm.CommitBtnClick( Sender: TObject );
begin
  SQLQuery.ApplyUpdates();
  SQLTransaction.Commit();
  Fetch();
end;

procedure TTableForm.ResetBtnClick( Sender: TObject );
begin
  SQLQuery.CancelUpdates();
  FDataEdited := False;
end;

procedure TTableForm.RefreshBtnClick( Sender: TObject );
begin
  if DiscardChanges() then Fetch();
end;

procedure TTableForm.DBGridTitleClick( Column: TColumn );
begin
  { TODO 2 : Improve sorting, add ability to select multiple columns }
  if DiscardChanges() then begin
    FSortIndex := Column.Index+1;
    FDescSort := not FDescSort;
    Fetch();
  end;
end;

{ FILTERS PROCESSING ========================================================= }

procedure TTableForm.AddFilterBtnClick( Sender: TObject );
begin
  FFilters.Add();
  FiltersCList.Items.Add('');
  FiltersCList.ItemIndex := FiltersCList.Count-1;
  FiltersCList.Checked[ FiltersCList.ItemIndex ] := True;
  UpdateFilter( FiltersCList.ItemIndex );
end;

procedure TTableForm.ClearFiltersBtnClick( Sender: TObject );
begin
  FiltersCList.Clear();
  FFilters.Clear();
end;

procedure TTableForm.FilterChange( Sender: TObject );
begin
  UpdateFilter( FiltersCList.ItemIndex );
end;

procedure TTableForm.FiltersCListClick( Sender: TObject );
begin
  if ( FiltersCList.ItemIndex < 0 ) then Exit;

  //to prevent updating on fields changing
  FiltersCList.Enabled := False;

  with FFilters.GetFilter( FiltersCList.ItemIndex ) do begin
    ColumnsCB.ItemIndex := Column;
    OperationsCB.ItemIndex := Operation;
    ConstEdit.Text := Constant;
    LogicCB.ItemIndex := Logic;
  end;

  FiltersCList.Enabled := True;
end;

procedure TTableForm.UpdateFilter( Index: Integer );
begin
  if not FiltersCList.Enabled or ( Index < 0 ) then Exit;
  FFilters.Update( Index, ColumnsCB.ItemIndex, OperationsCB.ItemIndex,
    ConstEdit.Text, LogicCB.ItemIndex );
  FiltersCList.Items.Strings[Index] := FFilters.GetSQL( Index, False );
end;

{ DATABASE EDITING ROUTINES ================================================== }

procedure TTableForm.AddEntryBtnClick( Sender: TObject );
begin
  SQLQuery.Insert();
end;

procedure TTableForm.EraseEntryBtnClick( Sender: TObject );
begin
  SQLQuery.Delete();
end;

procedure TTableForm.DataSourceUpdateData( Sender: TObject );
begin
  FDataEdited := True;
end;

function TTableForm.DiscardChanges(): Boolean;
begin
  if FDataEdited then
    Result := MessageDlg( 'There are some uncommited changes, discard?',
                          mtConfirmation, mbYesNo, 0 ) = mrYes
  else
    Result := True;
end;

{ DATABASE GRID FETCHING ROUTINES ============================================ }

procedure TTableForm.Fetch();
var
  QueryCmd : String;
  i, param : Integer;
begin
  QueryCmd := '';
  if FiltersCheck.Checked then begin
    param := 0;
    for i := 0 to FiltersCList.Count-1 do begin
      if ( FiltersCList.Checked[i] ) then begin
        QueryCmd += ' ' + FFilters.GetSQL( i, True, QueryCmd <> '' ) + ':'
          + IntToStr(param);
        param += 1;
      end;
    end;
    if ( QueryCmd <> '' ) then
      QueryCmd := ' where' + QueryCmd;
  end;

  QueryCmd := RegTable[Tag].GetSelectSQL() + QueryCmd;

  if ( FSortIndex <> -1 ) then begin
    QueryCmd += ' order by ' + IntToStr( FSortIndex );
    if FDescSort then QueryCmd += ' desc';
  end;

  SQLQuery.Active := False;
  SQLQuery.SQL.Text := QueryCmd;
  if ( param > 0 ) then begin
    param := 0;
    for i := 0 to FiltersCList.Count-1 do begin
      if ( FiltersCList.Checked[i] ) then begin
        with SQLQuery.ParamByName( IntToStr(param) ) do begin
          AsString := FFilters.GetConst(i);
          if ( RegTable[Tag].Columns( FFilters.GetFilter(i).Column ).DataType = DT_NUMERIC ) then
            DataType := ftInteger;
        end;
        param += 1;
      end;
    end;
  end;

  SQLQuery.Active := True;
  AdjustControls();
  FDataEdited := False;
end;

procedure TTableForm.AdjustControls();
var
  i : Integer;
begin
  { TODO 2 : Possibility to edit referenced tables? Now they just locks. }
  if not SQLQuery.CanModify then begin
    DBGrid.ReadOnly := True;
    DBGrid.Options := DBGrid.Options + [dgRowSelect] - [dgEditing];
  end;

  for i := 0 to RegTable[Tag].ColumnsNum-1 do
    with DBGrid.Columns.Items[i] do begin
      Field.Required := RegTable[Self.Tag].Columns(i).UserEdit;
      ReadOnly := not Field.Required;
      Title.Caption := RegTable[Self.Tag].ColumnCaption(i);
      if ( RegTable[Self.Tag].Columns(i).Width > 0 ) then
        Width := RegTable[Self.Tag].Columns(i).Width;
    end;
end;

end.

