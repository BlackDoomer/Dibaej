unit filters;

{$MODE OBJFPC}
{$LONGSTRINGS ON}

interface

uses
  SysUtils, Classes,
  tables;

const
  FilterOperations: array[0..5] of String = ('=', '<>', '>', '>=', '<', '<=');
  FilterLogic: array[0..1] of String = ('AND', 'OR');

type

  TFilter = record
    Column: Integer;
    Operation: Integer;
    Constant: String;
    Logic: Integer;
  end;

  { TFilterContext }

  TFilterContext = class
  private
    FFilters: array of TFilter;
    FCount: Integer;
    FTable: Integer;
  public
    constructor Create( Table: Integer );
    destructor Destroy(); override;

    function Add(): Integer;
    procedure Update( Index: Integer; AColumn: Integer; AOperation: Integer;
                      AConstant: String; ALogic: Integer );
    procedure Clear();

    function GetSQL( Index: Integer; ForQuery: Boolean; 
                     AddLogic: Boolean = True ): String;
    function GetConst( Index: Integer; Brackets: Boolean = False ): String;
    function GetFilter( Index: Integer ): TFilter;
  end;

implementation

constructor TFilterContext.Create( Table: Integer );
begin
  FCount := 0;
  FTable := Table;
end;

destructor TFilterContext.Destroy();
begin
  Clear();
end;

{ –=────────────────────────────────────────────────────────────────────────=– }

function TFilterContext.Add(): Integer;
begin
  Result := FCount;
  FCount += 1;
  SetLength( FFilters, FCount );
end;

procedure TFilterContext.Update( Index: Integer; AColumn: Integer;
  AOperation: Integer; AConstant: String; ALogic: Integer);
begin
  if (Index < 0) or (Index >= FCount) then
    raise Exception.Create('Invalid filter index.');
  with FFilters[Index] do begin
    Column := AColumn;
    Operation := AOperation;
    Constant := AConstant;
    Logic := ALogic;
  end;
end;

procedure TFilterContext.Clear;
begin
  SetLength( FFilters, 0 );
  FCount := 0;
end;

{ –=────────────────────────────────────────────────────────────────────────=– }

function TFilterContext.GetSQL( Index: Integer; ForQuery: Boolean;
                                AddLogic: Boolean = True ): String;
begin
  with FFilters[Index] do begin
    Result := ' ' + FilterOperations[Operation] + ' ';

    if ForQuery then begin // A + OP B + OP C ...
      // queries are parametrised, so we don't add constants, only ending space
      Result := RegTable[FTable].ColumnName( Column ) + Result;
      if AddLogic then Result := FilterLogic[Logic] + ' ' + Result;
    end else begin // A OP + B OP + C OP ...
      Result := RegTable[FTable].ColumnCaption( Column ) + Result
        + GetConst( Index, True );
      if AddLogic then Result += ' ' + FilterLogic[Logic];
    end;
  end;
end;

function TFilterContext.GetConst( Index: Integer; Brackets: Boolean = False ): String;

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

begin
  with FFilters[Index] do begin
    if ( RegTable[FTable].ColumnDataType( Column ) = DT_STRING ) then begin
      Result := Constant;
      if Brackets then Result := '''' + Result + '''';
    end else
      Result := ExtractIntFromStr( Constant );
  end;
end;

function TFilterContext.GetFilter(Index: Integer): TFilter;
begin
  Result := FFilters[Index];
end;

{ –=────────────────────────────────────────────────────────────────────────=– }

end.


