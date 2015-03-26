unit f_table;

{ NOTE: f_table isn't a single independent module,
  it's just additional code for "tables" unit }

{$MODE OBJFPC}
{$LONGSTRINGS ON}

interface

uses
  SysUtils, Classes, Forms, StdCtrls,
  SQLdb, db, DBGrids;

type
  
  { TTableForm }

  TTableForm = class( TForm )
  { interface controls }
    DBGrid          : TDBGrid;
    RefreshBtn      : TButton;
    FilterEdit      : TEdit;
    ApplyBtn        : TButton;

  { database controls }
    SQLTransaction  : TSQLTransaction;
    SQLQuery        : TSQLQuery;
    DataSource      : TDataSource;

    procedure FilterEditClick(Sender: TObject);
    procedure ApplyBtnClick(Sender: TObject);
    procedure RefreshBtnClick(Sender: TObject);

  private
    { private declarations }

  public
    { public declarations }
  end;

implementation

{$R *.lfm}

{ TTableForm }

procedure TTableForm.RefreshBtnClick(Sender: TObject);
    begin SQLQuery.Refresh();
      end;

procedure TTableForm.FilterEditClick(Sender: TObject);
begin
  //executes only once to erase intro
  if FilterEdit.ReadOnly then begin
    FilterEdit.Text := '';
    FilterEdit.ReadOnly := False;
    ApplyBtn.Enabled := True;
  end;
end;

procedure TTableForm.ApplyBtnClick(Sender: TObject);
begin
  SQLQuery.ServerFiltered := False;
  SQLQuery.Filter := FilterEdit.Text;
  SQLQuery.ServerFiltered := True;  
end;

{ TODO 2 : How about some user sorting in DBGrid? (with dgHeaderPushedLook) }

end.

