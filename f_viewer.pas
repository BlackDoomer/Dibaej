unit f_viewer;

{$MODE OBJFPC}
{$LONGSTRINGS ON}

interface {════════════════════════════════════════════════════════════════════}

uses
  Classes, SysUtils, sqldb, db,
  Forms, Controls, Dialogs, CheckLst, StdCtrls, Grids;

{ –=────────────────────────────────────────────────────────────────────────=– }
type { Editor form class ═════════════════════════════════════════════════════ }

  { TViewForm }

  TViewForm = class( TForm )
  { interface controls }    
    FieldsCList       : TCheckListBox;
    LRowCB            : TLabel;
    RowFieldCB        : TComboBox;
    RowValsCList      : TCheckListBox;
    LColCB            : TLabel;
    ColFieldCB        : TComboBox;
    ColValsCList      : TCheckListBox;
    BuildBtn          : TButton;
  { end of interface controls }

    SQLTransaction    : TSQLTransaction;
    SQLQuery          : TSQLQuery;
    DataSource        : TDataSource;
    ViewSGrid: TStringGrid;

    procedure FormShow( Sender: TObject );
    procedure FormClose( Sender: TObject; var CloseAction: TCloseAction );
    procedure BuildBtnClick( Sender: TObject );
    procedure RowFieldCBChange( Sender: TObject );
    procedure ColFieldCBChange( Sender: TObject );
    procedure ViewSGridDrawCell( Sender: TObject; aCol, aRow: Integer; 
      aRect: TRect; aState: TGridDrawState );
  private
    FDataReady : Boolean;
    FDataStorage : array of array of array of String;
      //i - row, j - column, k - record entry
    procedure Build();
    function CListFilter( CList: TCheckListBox; KeyName: String;
                          Append: String = '' ): String;
  public
    { public declarations }
  end;

{ –=────────────────────────────────────────────────────────────────────────=– }

function ShowViewerForm( DBConnection: TSQLConnection ): Boolean;

const
  DefCellWidth = 256;
  DefFontHeight = 10;

var
  ViewForm: TViewForm;

implementation {═══════════════════════════════════════════════════════════════}

uses Math, Graphics, tables, def_tables, common;

{$R *.lfm}

function ShowViewerForm( DBConnection: TSQLConnection ): Boolean;
begin
  if Assigned( ViewForm ) then begin
    ViewForm.ShowOnTop();
    Result := False;
  end else begin
    ViewForm := TViewForm.Create( DBConnection.Owner );
    with ViewForm do begin
      SQLTransaction.DataBase := DBConnection;
      SQLQuery.DataBase := DBConnection;
      Show();
    end;
    Result := True;
  end;
end;

{ –=────────────────────────────────────────────────────────────────────────=– }

procedure TViewForm.FormShow( Sender: TObject );
begin
  FDataReady := False;
  tblSummary.GetColumns( FieldsCList.Items, True );
  FieldsCList.CheckAll( cbChecked );
  with RowFieldCB do begin
    Items.AddStrings( FieldsCList.Items );
    ItemIndex := 0; OnChange( Self );
  end;
  with ColFieldCB do begin
    Items.AddStrings( FieldsCList.Items );
    ItemIndex := 0; OnChange( Self );
  end;
end;

procedure TViewForm.FormClose( Sender: TObject; var CloseAction: TCloseAction );
begin
  ViewForm := nil;
  CloseAction := caFree;
end;

procedure TViewForm.BuildBtnClick( Sender: TObject );
begin
  Build();
  FDataReady := True;
end;

{ –=────────────────────────────────────────────────────────────────────────=– }

procedure TViewForm.RowFieldCBChange( Sender: TObject );
var
  column : TColumnInfo;
begin
  column := tblSummary.Columns( StrID( RowFieldCB.Items, RowFieldCB.ItemIndex ) );
  GetIDRelation( column.RefTable, column.Name, SQLQuery, RowValsCList.Items );
  RowValsCList.CheckAll( cbChecked );
end;

procedure TViewForm.ColFieldCBChange( Sender: TObject );
var
  column : TColumnInfo;
begin
  column := tblSummary.Columns( StrID( ColFieldCB.Items, ColFieldCB.ItemIndex ) );
  GetIDRelation( column.RefTable, column.Name, SQLQuery, ColValsCList.Items );
  ColValsCList.CheckAll( cbChecked );
end;

procedure TViewForm.ViewSGridDrawCell( Sender: TObject; aCol, aRow: Integer; 
  aRect: TRect; aState: TGridDrawState );
var
  i, chcount: Integer;
begin
  if (aCol = 0) or (aRow = 0) then Exit;
  if not FDataReady then Exit;

  chcount := CListCheckedCount( FieldsCList );
  with ViewSGrid.Canvas do begin
    for i := 0 to High( FDataStorage[aRow-1,aCol-1] ) do begin
      if ( i mod chcount = 0 ) then
        if ( Font.Color = clBlack ) then Font.Color := clBlue
                                    else Font.Color := clBlack;

      TextOut( aRect.Left + 4, aRect.Top + (DefFontHeight+4)*i,
               FDataStorage[aRow-1,aCol-1][i] );
    end;
  end;
end;

{ –=────────────────────────────────────────────────────────────────────────=– }

procedure TViewForm.Build();
var
  rowvals, colvals, i, noref, maxlen, row, col, keyrow, keycol, cellsz : Integer;
  keyname, filter, value : String;
begin
  rowvals := CListCheckedCount( RowValsCList );
  colvals := CListCheckedCount( ColValsCList );

  SetLength( FDataStorage, 0 );
  SetLength( FDataStorage, rowvals, colvals);

  SQLQuery.Active := False;
  SQLQuery.SQL.Text := tblSummary.GetSelectSQL( '', True,
    RowFieldCB.ItemIndex, ColFieldCB.ItemIndex );

  //filtering unchecked values
  keyname := tblSummary.ColumnKeyName( StrID( RowFieldCB.Items, RowFieldCB.ItemIndex ) );
  filter := CListFilter( RowValsCList, keyname );
  keyname := tblSummary.ColumnKeyName( StrID( ColFieldCB.Items, ColFieldCB.ItemIndex ) );
  SQLQuery.SQL.Append( CListFilter( ColValsCList, keyname, filter ) );

  //ordering selection by row and column
  SQLQuery.SQL.Append( 'order by ' + IntToStr( RowFieldCB.ItemIndex+1 ) + ', ' +
    IntToStr( ColFieldCB.ItemIndex+1 ) );

  //setting new counts of rows and columns
  ViewSGrid.Clear();
  ViewSGrid.RowCount := rowvals + 1; //ViewSGrid.FixedRows;
  ViewSGrid.ColCount := colvals + 1; //ViewSGrid.FixedCols;

  //setting captions for rows...
  noref := 0;
  maxlen := 0;
  for i := 1 to RowValsCList.Count do begin
    if RowValsCList.Checked[i-1] then begin
      ViewSGrid.Cells[0,i-noref] := RowValsCList.Items[i-1];
      maxlen := Max( Length( RowValsCList.Items[i-1] )*9, maxlen );
        //10 is an average letter width
    end else
      noref += 1;
  end;
  ViewSGrid.ColWidths[0] := maxlen;
  //...and columns
  noref := 0;
  for i := 1 to ColValsCList.Count do begin
    if ColValsCList.Checked[i-1] then
      ViewSGrid.Cells[i-noref,0] := ColValsCList.Items[i-1]
    else
      noref += 1;
  end;

  SQLQuery.Active := True;
  while not SQLQuery.EOF do begin
    keyrow := SQLQuery.Fields.Fields[ RowFieldCB.ItemIndex ].AsInteger;
    row := CListCheckedIndex( RowValsCList, IndexID( RowValsCList.Items, keyrow ) );
    repeat
      keycol := SQLQuery.Fields.Fields[ ColFieldCB.ItemIndex ].AsInteger;
      col := CListCheckedIndex( ColValsCList, IndexID( ColValsCList.Items, keycol ) );

      //now we know destination row and column, so we writing fields to cell
      cellsz := Length( FDataStorage[row,col] );
      SetLength( FDataStorage[row,col], cellsz + CListCheckedCount( FieldsCList ) );
      noref := 0;
      for i := 0 to FieldsCList.Count-1 do begin
        if not FieldsCList.Checked[i] then begin
          noref += 1;
          Continue;
        end;

        if (i = RowFieldCB.ItemIndex) then
          value := RowValsCList.Items[ IndexID( RowValsCList.Items, keyrow ) ]
        else
        if (i = ColFieldCB.ItemIndex) then
          value := ColValsCList.Items[ IndexID( ColValsCList.Items, keycol ) ]
        else
          value := SQLQuery.Fields.Fields[i].AsString;
        value := FieldsCList.Items[i] + ': ' + value;
        FDataStorage[row,col][cellsz+i-noref] := value;
      end;
      SQLQuery.Next();
      //setting height for this row
      cellsz += FieldsCList.Count + 1 - noref;
      ViewSGrid.RowHeights[row+1] := Max( cellsz * (DefFontHeight+4),
                                          ViewSGrid.RowHeights[row+1] );
    until ( keyrow <> SQLQuery.Fields.Fields[ RowFieldCB.ItemIndex ].AsInteger )
          or SQLQuery.EOF;

    SQLQuery.Next();
  end;
end;

function TViewForm.CListFilter( CList: TCheckListBox; KeyName: String;
                                Append: String = '' ): String;
var
  i : Integer;
begin
  Result := Append;
  for i := 0 to CList.Count-1 do begin
    if not CList.Checked[i] then begin
      if ( Result = '' ) then Result := 'where '
                         else Result += ' and ';
      Result += KeyName + ' <> ' + IntToStr( StrID( CList.Items, i ) );
    end;
  end;
end;

end.

