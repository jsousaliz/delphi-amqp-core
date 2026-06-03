unit DelphiAMQP.Tests.Performance.Runner;

interface

uses
  DelphiAMQP.Tests.Performance.Config,
  DelphiAMQP.Tests.Performance.Result;

function RunPerformanceTest(const AConfig: TPerformanceConfig): TPerformanceResult;

implementation

uses
  System.Classes,
  System.SysUtils,
  DelphiAMQP.Factory,
  DelphiAMQP.Interfaces,
  DelphiAMQP.Logging,
  DelphiAMQP.Tests.Performance.Load,
  DelphiAMQP.Tests.Performance.SharedState;

function RunPerformanceTest(const AConfig: TPerformanceConfig): TPerformanceResult;
var
  LChannel: IAMQPChannel;
  LConnection: IAMQPConnection;
  LConsumers: TArray<TConsumerRuntime>;
  LConsumeStartTick: UInt64;
  LFactory: IAMQPConnectionFactory;
  LSharedState: TPerformanceSharedState;
  LStartTick: UInt64;
begin
  LStartTick := TThread.GetTickCount64;
  Result := EmptyPerformanceResult;

  LSharedState := TPerformanceSharedState.Create(AConfig.MessageCount);
  try
    LFactory := TAMQPConnectionFactory.Create(TAMQPLogger.Null);
    try
      LConnection := LFactory.CreateConnection(BuildOptions(AConfig));
      LConnection.Connect;
      try
        LChannel := LConnection.CreateChannel;
        LChannel.QueueDeclare(AConfig.QueueName, False, False, False);
        LChannel.QueuePurge(AConfig.QueueName);
        LChannel.Close;
      finally
        LConnection.Disconnect;
      end;

      StartConsumers(AConfig, LSharedState, LConsumers);
      LConsumeStartTick := TThread.GetTickCount64;
      Result.PublishElapsedMS := RunPublishers(AConfig, LSharedState);
      if not LSharedState.WaitForCompletion(AConfig.TimeoutMS) then
        LSharedState.AddError('Timeout waiting for all messages.');
      Result.ConsumeElapsedMS := TThread.GetTickCount64 - LConsumeStartTick;
      StopConsumers(LConsumers);

      Result.PublishedCount := LSharedState.PublishedCount;
      Result.ConsumedCount := LSharedState.ConsumedCount;
      Result.DuplicateCount := LSharedState.DuplicateCount;
      Result.ErrorCount := LSharedState.ErrorCount;
      Result.ErrorMessage := LSharedState.ErrorText;
      Result.MissingCount := AConfig.MessageCount - Result.ConsumedCount;
      Result.Success :=
        (Result.PublishedCount = AConfig.MessageCount) and
        (Result.ConsumedCount = AConfig.MessageCount) and
        (Result.DuplicateCount = 0) and
        (Result.ErrorCount = 0);
    except
      on E: Exception do
      begin
        LSharedState.AddError(E.ClassName + ': ' + E.Message);
        StopConsumers(LConsumers);
        Result.PublishedCount := LSharedState.PublishedCount;
        Result.ConsumedCount := LSharedState.ConsumedCount;
        Result.DuplicateCount := LSharedState.DuplicateCount;
        Result.ErrorCount := LSharedState.ErrorCount;
        Result.ErrorMessage := LSharedState.ErrorText;
        Result.MissingCount := AConfig.MessageCount - Result.ConsumedCount;
        Result.Success := False;
      end;
    end;
  finally
    LSharedState.Free;
  end;

  Result.TotalElapsedMS := TThread.GetTickCount64 - LStartTick;
end;

end.
