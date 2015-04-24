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
    DBGrid          : TDBGrid;
    RefreshBtn      : TButton;

    FiltersBox      : TGroupBox;
      FiltersList   : TListBox;
      ColumnsCB     : TComboBox;
      OperationsCB  : TComboBox;
      ConstEdit     : TEdit;
      LogicCB       : TComboBox;
      AddBtn        : TButton;
      ClearBtn      : TButton;
      FiltersCheck  : TCheckBox;


  { database controls }
    SQLTransaction  : TSQLTransaction;
    SQLQuery        : TSQLQuery;
    DataSource      : TDataSource;

    procedure FormClose( Sender: TObject; var CloseAction: TCloseAction );
    procedure RefreshBtnClick( Sender: TObject );
    procedure DBGridTitleClick( Column: TColumn );

    procedure AddBtnClick(Sender: TObject);
    procedure ClearBtnClick( Sender: TObject );
    procedure FilterChange( Sender: TObject );
    procedure FiltersListSelectionChange( Sender: TObject; User: Boolean );

  private
    FFilters: array of TFilter;
    FFilterCount: Integer;
    FSortIndex: Integer;
    FDescSort: Boolean;
    procedure Fetch( UpdateCBs: Boolean = False );
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

      Fetch( True );
      Result := True;
    end;
  end;

end;

{ TTableForm }

procedure TTableForm.FormClose( Sender: TObject; var CloseAction: TCloseAction );
begin
  { TODO 2 : Split commit and rollback onto two separate buttons in table form }
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
        CloseAction := TCloseAction.caNone; //caNone is also a transaction state
        Exit;
      end;
    end;

  //transaction will be performed on form close
  TableForm[Tag] := nil;
  CloseAction := caFree;
end;

procedure TTableForm.RefreshBtnClick( Sender: TObject );
    begin Fetch();
      end;

procedure TTableForm.DBGridTitleClick( Column: TColumn );
begin
  { TODO 2 : Improve sorting, add ability to select multiple columns }
  FSortIndex := Column.Index;
  FDescSort := not FDescSort;
  Fetch();
end;

procedure TTableForm.Fetch( UpdateCBs: Boolean = False );
var
  QueryCmd : String;
  i : Integer;
begin
  QueryCmd := RegTable[Tag].GetSelectSQL();

  if FiltersCheck.Checked then
    for i := 0 to FFilterCount-1 do begin
      if (i = 0) then QueryCmd += ' where';
      QueryCmd += ' ' + BuildFilter( i, True );
    end;

  if not ( FSortIndex = -1 ) then begin
    QueryCmd += ' order by ' + IntToStr( FSortIndex );
    if FDescSort then QueryCmd += ' desc';
  end;

  SQLQuery.Active := False;
  SQLQuery.SQL.Text := QueryCmd;
  SQLQuery.Active := True;

  RegTable[Tag].AdjustDBGrid( DBGrid );  
  if UpdateCBs then RegTable[Tag].FillCombobox( ColumnsCB );
end;

{ FILTERS PROCESSING ========================================================= }

procedure TTableForm.AddBtnClick( Sender: TObject );
begin
  FFilterCount += 1;
  SetLength( FFilters, FFilterCount );
  FiltersList.Items.Add('');
  FiltersList.ItemIndex := FFilterCount-1;
  UpdateFilter( FFilterCount-1 );
end;

procedure TTableForm.ClearBtnClick( Sender: TObject );
begin
  FFilterCount := 0;
  SetLength( FFilters, 0 );
  FiltersList.Clear();
end;

procedure TTableForm.FilterChange( Sender: TObject );
begin
  if ( FFilterCount > 0 ) then
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

    if not ForQuery or ( Index < FFilterCount-1 ) then
      Result += ' ' + Logic;
  end;
end;

end.

