unit f_table;

{$MODE OBJFPC}
{$LONGSTRINGS ON}

interface

uses
  SysUtils, Classes,
  Forms, Controls, Dialogs, StdCtrls,
  SQLdb, db, DBGrids, CheckLst;

type
  
  TFilter = record
    Column: Integer;
    Operation: Integer;
    Constant: String;
    Logic: Integer;
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
    FFilters : array of TFilter;
    FSortIndex : Integer;
    FDescSort : Boolean;
    FDataEdited : Boolean;
    procedure Fetch();
    function DiscardChanges(): Boolean;
    procedure UpdateFilter( Index: Integer );
    function BuildFilter( Index: Integer; ForQuery: Boolean;
                          AddLogic: Boolean = True ): String;
  public
    { public declarations }
  end;

  function ShowTableForm( Index: Integer; DBConnection: TSQLConnection ): Boolean;
  function ExtractIntFromStr( Str: String ): String;

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
  SetLength( FFilters, FiltersCList.Count+1 );
  FiltersCList.Items.Add('');
  FiltersCList.ItemIndex := FiltersCList.Count-1;
  FiltersCList.Checked[ FiltersCList.ItemIndex ] := True;
  UpdateFilter( FiltersCList.ItemIndex );
end;

procedure TTableForm.ClearFiltersBtnClick( Sender: TObject );
begin
  FiltersCList.Clear();
  SetLength( FFilters, 0 );
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
  
  with FFilters[ FiltersCList.ItemIndex ] do begin
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

  with FFilters[ Index ] do begin
    Column := ColumnsCB.ItemIndex;
    Operation := OperationsCB.ItemIndex;
    Constant := ConstEdit.Text;
    Logic := LogicCB.ItemIndex;
  end;

  FiltersCList.Items.Strings[ Index ] := BuildFilter( Index, False );
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
    for i := 0 to FiltersCList.Count-1 do begin
      if ( FiltersCList.Checked[i] ) then begin
        FilterStr := BuildFilter( i, True, QueryCmd <> '' );
        if ( FilterStr <> '' ) then QueryCmd += ' ' + FilterStr;
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
  SQLQuery.Active := True;

  RegTable[Tag].AdjustDBGrid( DBGrid );
  FDataEdited := False;
end;

function TTableForm.BuildFilter( Index: Integer; ForQuery: Boolean;
                                 AddLogic: Boolean = True ): String;
begin
  with FFilters[ Index ] do begin
    if ForQuery then Result := RegTable[Tag].ColumnName( Column )
                else Result := RegTable[Tag].ColumnCaption( Column );

    Result += ' ' + OperationsCB.Items.Strings[Operation] + ' ';

    if ( RegTable[Tag].ColumnDataType( Column ) = DT_STRING ) then
      Result += '''' + Constant + ''''
    else
      Result += ExtractIntFromStr( Constant );

    if AddLogic then begin
      if ForQuery then // A + OP B + OP C ...
        Result := LogicCB.Items.Strings[Logic] + ' ' + Result
      else // A OP + B OP + C OP ...
        Result += ' ' + LogicCB.Items.Strings[Logic];
    end;
  end;
end;

{ COMMON ROUTINES ============================================================ }

function ExtractIntFromStr( Str: String ): String;
var
  i : Char;
begin
  Result := '';
  for i in Str do
    if i in ['0'..'9'] then Result += i;
  try    Result := IntToStr( StrToInt( Result ) );
  except Result := '0';
  end;
end;

end.

