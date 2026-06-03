unit DelphiAMQP.Tests.Performance.Result;

interface

type
  TPerformanceResult = record
    PublishedCount: Integer;
    ConsumedCount: Integer;
    MissingCount: Integer;
    DuplicateCount: Integer;
    ErrorCount: Integer;
    TotalElapsedMS: UInt64;
    PublishElapsedMS: UInt64;
    ConsumeElapsedMS: UInt64;
    ErrorMessage: string;
    Success: Boolean;
  end;

function EmptyPerformanceResult: TPerformanceResult;

implementation

function EmptyPerformanceResult: TPerformanceResult;
begin
  Result.PublishedCount := 0;
  Result.ConsumedCount := 0;
  Result.MissingCount := 0;
  Result.DuplicateCount := 0;
  Result.ErrorCount := 0;
  Result.TotalElapsedMS := 0;
  Result.PublishElapsedMS := 0;
  Result.ConsumeElapsedMS := 0;
  Result.ErrorMessage := '';
  Result.Success := False;
end;

end.
