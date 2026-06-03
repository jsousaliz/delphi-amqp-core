unit DelphiAMQP.Tests.Performance.SharedState;

interface

uses
  System.Classes,
  System.Generics.Collections,
  System.SyncObjs;

type
  TPerformanceSharedState = class
  private
    FCompleteEvent: TEvent;
    FConsumedCount: Integer;
    FConsumedIds: TDictionary<Integer, Byte>;
    FDuplicateCount: Integer;
    FErrors: TStringList;
    FExpectedCount: Integer;
    FLock: TCriticalSection;
    FPublishedCount: Integer;
  public
    constructor Create(const AExpectedCount: Integer);
    destructor Destroy; override;
    procedure AddError(const AMessage: string);
    procedure IncrementPublished;
    procedure MarkConsumed(const AMessageId: Integer);
    function ConsumedCount: Integer;
    function DuplicateCount: Integer;
    function ErrorCount: Integer;
    function ErrorText: string;
    function PublishedCount: Integer;
    function WaitForCompletion(const ATimeoutMS: Cardinal): Boolean;
  end;

implementation

uses
  System.SysUtils;

constructor TPerformanceSharedState.Create(const AExpectedCount: Integer);
begin
  inherited Create;
  FCompleteEvent := TEvent.Create(nil, True, False, '');
  FConsumedCount := 0;
  FConsumedIds := TDictionary<Integer, Byte>.Create;
  FDuplicateCount := 0;
  FErrors := TStringList.Create;
  FExpectedCount := AExpectedCount;
  FLock := TCriticalSection.Create;
  FPublishedCount := 0;
end;

destructor TPerformanceSharedState.Destroy;
begin
  FLock.Free;
  FErrors.Free;
  FConsumedIds.Free;
  FCompleteEvent.Free;
  inherited;
end;

procedure TPerformanceSharedState.AddError(const AMessage: string);
begin
  FLock.Acquire;
  try
    FErrors.Add(AMessage);
  finally
    FLock.Release;
  end;
end;

procedure TPerformanceSharedState.IncrementPublished;
begin
  TInterlocked.Increment(FPublishedCount);
end;

procedure TPerformanceSharedState.MarkConsumed(const AMessageId: Integer);
begin
  FLock.Acquire;
  try
    if FConsumedIds.ContainsKey(AMessageId) then
    begin
      Inc(FDuplicateCount);
      Exit;
    end;

    FConsumedIds.Add(AMessageId, 1);
    TInterlocked.Increment(FConsumedCount);
    if FConsumedCount >= FExpectedCount then
      FCompleteEvent.SetEvent;
  finally
    FLock.Release;
  end;
end;

function TPerformanceSharedState.ConsumedCount: Integer;
begin
  Result := FConsumedCount;
end;

function TPerformanceSharedState.DuplicateCount: Integer;
begin
  FLock.Acquire;
  try
    Result := FDuplicateCount;
  finally
    FLock.Release;
  end;
end;

function TPerformanceSharedState.ErrorCount: Integer;
begin
  FLock.Acquire;
  try
    Result := FErrors.Count;
  finally
    FLock.Release;
  end;
end;

function TPerformanceSharedState.ErrorText: string;
var
  LIndex: Integer;
begin
  FLock.Acquire;
  try
    Result := '';
    for LIndex := 0 to FErrors.Count - 1 do
    begin
      if not Result.IsEmpty then
        Result := Result + sLineBreak;
      Result := Result + Format('%d. %s', [LIndex + 1, FErrors[LIndex]]);
    end;
  finally
    FLock.Release;
  end;
end;

function TPerformanceSharedState.PublishedCount: Integer;
begin
  Result := FPublishedCount;
end;

function TPerformanceSharedState.WaitForCompletion(const ATimeoutMS: Cardinal): Boolean;
begin
  Result := FCompleteEvent.WaitFor(ATimeoutMS) = wrSignaled;
end;

end.
