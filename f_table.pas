unit f_table;

{$MODE OBJFPC}
{$LONGSTRINGS ON}

interface

uses
  SysUtils, Classes,
  Forms, Controls, Dialogs, StdCtrls,
  SQLdb, db, DBGrids;

type
  
  { TTableForm }
  TTableForm = class( TForm )
  { interface controls }
    DBGrid          : TDBGrid;
    RefreshBtn      : TButton;

  { database controls }
    SQLTransaction  : TSQLTransaction;
    SQLQuery        : TSQLQuery;
    DataSource      : TDataSource;

    procedure FormClose( Sender: TObject; var CloseAction: TCloseAction );
    procedure RefreshBtnClick( Sender: TObject );

  private
    { private declarations }
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

      SQLTransaction.DataBase := DBConnection;
      SQLQuery.DataBase := DBConnection;
      SQLTransaction.Active := True;

      RegTable[Index].Fetch( DBGrid, SQLQuery );
      Result := True;
    end;
  end;

end;

{ TTableForm }

procedure TTableForm.FormClose( Sender: TObject; var CloseAction: TCloseAction );
begin
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
    begin SQLQuery.Refresh();
      end;

{ TODO 2 : How about some user sorting in DBGrid? (with dgHeaderPushedLook) }

end.

