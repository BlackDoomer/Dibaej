unit f_table;

{$MODE OBJFPC}
{$LONGSTRINGS ON}

interface

uses
  SysUtils, Classes,
  Forms, Controls, Dialogs, StdCtrls,
  SQLdb, db, DBGrids;

type
  
  TFilter = record
    Column: Integer;
    Operation: String;
    Constant: String;
    Logic: String;
  end;
  
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
      FiltersList       : TListBox;
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
    procedure FilterChange( Sender: TObject );
    procedure FiltersListSelectionChange( Sender: TObject; User: Boolean );

    procedure AddEntryBtnClick( Sender: TObject );
    procedure EraseEntryBtnClick( Sender: TObject );
    procedure DataSourceUpdateData( Sender: TObject );

  private
    FFilters : array of TFilter;
    FSortIndex : Integer;
    FDescSort : Boolean;
    FDataEdited : Boolean;
    procedure Fetch();
    function DiscardChanges(): Boolean;
    procedure UpdateFilter( Index: Integer );
    function BuildFilter( Index: Integer; ForQuery: Boolean ): String;
  public
    { public declarations }
  end;

  function ShowTableForm( Index: Integer; DBConnection: TSQLConnection ): Boolean;

var
  TableForm : array of TTableForm;

implementation

uses tables;

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

      SQLTransaction.DataBase := DBConnection;
      SQLQuery.DataBase := DBConnection;
      SQLTransaction.Active := True;

      Fetch();
      RegTable[Index].FillCombobox( ColumnsCB );
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
  FiltersList.Items.Add('');
  SetLength( FFilters, FiltersList.Count );
  FiltersList.ItemIndex := FiltersList.Count-1;
  UpdateFilter( FiltersList.Count-1 );
end;

procedure TTableForm.ClearFiltersBtnClick( Sender: TObject );
begin
  SetLength( FFilters, 0 );
  FiltersList.Clear();
end;

procedure TTableForm.FilterChange( Sender: TObject );
begin
  if ( FiltersList.Count > 0 ) then
    UpdateFilter( FiltersList.ItemIndex );
end;

procedure TTableForm.FiltersListSelectionChange( Sender: TObject; User: Boolean );
begin
  if User then
    with FFilters[ FiltersList.ItemIndex ] do begin
      ColumnsCB.ItemIndex := Column;
      OperationsCB.Text := Operation;
      ConstEdit.Text := Constant;
      LogicCB.Text := Logic;
    end;
end;

procedure TTableForm.UpdateFilter( Index: Integer );
begin
  with FFilters[ Index ] do begin
    Column := ColumnsCB.ItemIndex;
    Operation := OperationsCB.Text;
    Constant := ConstEdit.Text;
    Logic := LogicCB.Text;
  end;
  FiltersList.Items.Strings[ Index ] := BuildFilter( Index, False );
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
  QueryCmd, FilterStr : String;
  i : Integer;
begin
  QueryCmd := '';
  if FiltersCheck.Checked then begin
    for i := 0 to FiltersList.Count-1 do begin
      FilterStr := BuildFilter( i, True );
      if not ( FilterStr = '' ) then QueryCmd += ' ' + FilterStr;
    end;
    if not ( QueryCmd = '' ) then
      QueryCmd := ' where' + QueryCmd;
  end;

  QueryCmd := RegTable[Tag].GetSelectSQL() + QueryCmd;

  if not ( FSortIndex = -1 ) then begin
    QueryCmd += ' order by ' + IntToStr( FSortIndex );
    if FDescSort then QueryCmd += ' desc';
  end;

  SQLQuery.Active := False;
  SQLQuery.SQL.Text := QueryCmd;
  SQLQuery.Active := True;

  RegTable[Tag].AdjustDBGrid( DBGrid );
  FDataEdited := False;
end;

function TTableForm.BuildFilter( Index: Integer; ForQuery: Boolean ): String;
begin
  with FFilters[ Index ] do begin
    if ForQuery then Result := RegTable[Tag].ColumnName( Column )
                else Result := RegTable[Tag].ColumnCaption( Column );

    Result += ' ' + Operation + ' ';

    if ( Constant = '' ) then begin
      if ForQuery then Exit('') else Result += '?';
    end else begin
      Result += Constant;
    end;

    if not ForQuery or ( Index < FiltersList.Count-1 ) then
      Result += ' ' + Logic;
  end;
end;

end.

