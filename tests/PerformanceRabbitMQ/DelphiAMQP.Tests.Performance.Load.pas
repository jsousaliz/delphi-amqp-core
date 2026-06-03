unit DelphiAMQP.Tests.Performance.Load;

interface

uses
  System.Classes,
  DelphiAMQP.Interfaces,
  DelphiAMQP.Tests.Performance.Config,
  DelphiAMQP.Tests.Performance.SharedState;

type
  TConsumerRuntime = record
    Connection: IAMQPConnection;
    Channel: IAMQPChannel;
    Consumer: IAMQPConsumer;
  end;

  TPublisherThread = class(TThread)
  private
    FConfig: TPerformanceConfig;
    FEndMessageId: Integer;
    FSharedState: TPerformanceSharedState;
    FStartMessageId: Integer;
  protected
    procedure Execute; override;
  public
    constructor Create(
      const AConfig: TPerformanceConfig;
      const AStartMessageId: Integer;
      const AEndMessageId: Integer;
      const ASharedState: TPerformanceSharedState);
  end;

procedure CleanupQueue(const AConfig: TPerformanceConfig; const ADeleteQueue: Boolean);
function RunPublishers(
  const AConfig: TPerformanceConfig;
  const ASharedState: TPerformanceSharedState): UInt64;
procedure StartConsumers(
  const AConfig: TPerformanceConfig;
  const ASharedState: TPerformanceSharedState;
  var AConsumers: TArray<TConsumerRuntime>);
procedure StopConsumers(var AConsumers: TArray<TConsumerRuntime>);

implementation

uses
  System.SysUtils,
  DelphiAMQP.Factory,
  DelphiAMQP.Logging,
  DelphiAMQP.Message,
  DelphiAMQP.Tests.Performance.Messages;

constructor TPublisherThread.Create(
  const AConfig: TPerformanceConfig;
  const AStartMessageId: Integer;
  const AEndMessageId: Integer;
  const ASharedState: TPerformanceSharedState);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FConfig := AConfig;
  FStartMessageId := AStartMessageId;
  FEndMessageId := AEndMessageId;
  FSharedState := ASharedState;
end;

procedure TPublisherThread.Execute;
var
  LChannel: IAMQPChannel;
  LConnection: IAMQPConnection;
  LFactory: IAMQPConnectionFactory;
  LMessageId: Integer;
begin
  try
    LFactory := TAMQPConnectionFactory.Create(TAMQPLogger.Null);
    LConnection := LFactory.CreateConnection(BuildOptions(FConfig));
    LConnection.Connect;
    try
      LChannel := LConnection.CreateChannel;
      try
        for LMessageId := FStartMessageId to FEndMessageId do
        begin
          LChannel.Publish(
            '',
            FConfig.QueueName,
            TAMQPMessage.FromText(BuildMessagePayload(LMessageId)));
          FSharedState.IncrementPublished;
        end;
      finally
        LChannel.Close;
      end;
    finally
      LConnection.Disconnect;
    end;
  except
    on E: Exception do
      FSharedState.AddError(E.ClassName + ': ' + E.Message);
  end;
end;

function RunPublishers(
  const AConfig: TPerformanceConfig;
  const ASharedState: TPerformanceSharedState): UInt64;
var
  LBaseCount: Integer;
  LEndMessageId: Integer;
  LIndex: Integer;
  LMessageCount: Integer;
  LRemainder: Integer;
  LStartMessageId: Integer;
  LStartTick: UInt64;
  LThreads: array of TPublisherThread;
begin
  LStartTick := TThread.GetTickCount64;
  SetLength(LThreads, AConfig.PublisherCount);

  LBaseCount := AConfig.MessageCount div AConfig.PublisherCount;
  LRemainder := AConfig.MessageCount mod AConfig.PublisherCount;
  LStartMessageId := 1;

  try
    for LIndex := 0 to High(LThreads) do
    begin
      LMessageCount := LBaseCount;
      if LIndex < LRemainder then
        Inc(LMessageCount);

      LEndMessageId := LStartMessageId + LMessageCount - 1;
      LThreads[LIndex] := TPublisherThread.Create(
        AConfig,
        LStartMessageId,
        LEndMessageId,
        ASharedState);
      LStartMessageId := LEndMessageId + 1;
    end;

    for LIndex := 0 to High(LThreads) do
      LThreads[LIndex].Start;

    for LIndex := 0 to High(LThreads) do
      LThreads[LIndex].WaitFor;
  finally
    for LIndex := 0 to High(LThreads) do
      LThreads[LIndex].Free;
  end;

  Result := TThread.GetTickCount64 - LStartTick;
end;

procedure StartConsumers(
  const AConfig: TPerformanceConfig;
  const ASharedState: TPerformanceSharedState;
  var AConsumers: TArray<TConsumerRuntime>);
var
  LFactory: IAMQPConnectionFactory;
  LIndex: Integer;
begin
  SetLength(AConsumers, AConfig.ConsumerCount);
  LFactory := TAMQPConnectionFactory.Create(TAMQPLogger.Null);

  for LIndex := 0 to High(AConsumers) do
  begin
    AConsumers[LIndex].Connection := LFactory.CreateConnection(BuildOptions(AConfig));
    AConsumers[LIndex].Connection.Connect;
    AConsumers[LIndex].Channel := AConsumers[LIndex].Connection.CreateChannel;
    AConsumers[LIndex].Consumer := AConsumers[LIndex].Channel.BasicConsume(
      AConfig.QueueName,
      procedure(const AMessage: IAMQPMessage; const AContext: IAMQPConsumerContext)
      var
        LMessageId: Integer;
      begin
        try
          if TryParseMessageId(AMessage.AsText, LMessageId) then
            ASharedState.MarkConsumed(LMessageId)
          else
            ASharedState.AddError('Invalid message payload: ' + AMessage.AsText);
          AContext.Ack;
        except
          on E: Exception do
            ASharedState.AddError(E.ClassName + ': ' + E.Message);
        end;
      end,
      False);
    AConsumers[LIndex].Consumer.Start;
  end;
end;

procedure StopConsumers(var AConsumers: TArray<TConsumerRuntime>);
var
  LIndex: Integer;
begin
  for LIndex := 0 to High(AConsumers) do
  begin
    try
      if AConsumers[LIndex].Consumer <> nil then
        AConsumers[LIndex].Consumer.Stop;
    except
    end;

    try
      if AConsumers[LIndex].Channel <> nil then
        AConsumers[LIndex].Channel.Close;
    except
    end;

    try
      if AConsumers[LIndex].Connection <> nil then
        AConsumers[LIndex].Connection.Disconnect;
    except
    end;

    AConsumers[LIndex].Consumer := nil;
    AConsumers[LIndex].Channel := nil;
    AConsumers[LIndex].Connection := nil;
  end;
  SetLength(AConsumers, 0);
end;

procedure CleanupQueue(const AConfig: TPerformanceConfig; const ADeleteQueue: Boolean);
var
  LChannel: IAMQPChannel;
  LConnection: IAMQPConnection;
  LFactory: IAMQPConnectionFactory;
begin
  LFactory := TAMQPConnectionFactory.Create(TAMQPLogger.Null);
  LConnection := LFactory.CreateConnection(BuildOptions(AConfig));
  LConnection.Connect;
  try
    LChannel := LConnection.CreateChannel;
    try
      LChannel.QueuePurge(AConfig.QueueName);
      if ADeleteQueue then
        LChannel.QueueDelete(AConfig.QueueName);
    finally
      LChannel.Close;
    end;
  finally
    LConnection.Disconnect;
  end;
end;

end.
