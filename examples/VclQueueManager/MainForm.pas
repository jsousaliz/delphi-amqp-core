unit MainForm;

interface

uses
  System.Classes,
  System.Generics.Collections,
  System.SysUtils,
  System.TypInfo,
  Vcl.ComCtrls,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.StdCtrls,
  DelphiAMQP.Interfaces,
  DelphiAMQP.Types;

type
  TLogEventProc = reference to procedure(const AEvent: TAMQPLogEvent);

  TVclQueueManagerLogger = class(TInterfacedObject, IAMQPLogger)
  private
    FOnLog: TLogEventProc;
  public
    constructor Create(const AOnLog: TLogEventProc);
    procedure Log(const AEvent: TAMQPLogEvent);
  end;

  TMainForm = class(TForm)
    LabelHost: TLabel;
    LabelPort: TLabel;
    LabelVirtualHost: TLabel;
    LabelUserName: TLabel;
    LabelPassword: TLabel;
    LabelDispatchMode: TLabel;
    LabelQueueName: TLabel;
    LabelMessage: TLabel;
    LabelReceived: TLabel;
    LabelLevelFilter: TLabel;
    LabelKindFilter: TLabel;
    EdtHost: TEdit;
    EdtPort: TEdit;
    EdtVirtualHost: TEdit;
    EdtUserName: TEdit;
    EdtPassword: TEdit;
    CmbDispatchMode: TComboBox;
    EdtQueueName: TEdit;
    MemoMessage: TMemo;
    MemoReceived: TMemo;
    BtnConnect: TButton;
    BtnDisconnect: TButton;
    BtnCreateQueue: TButton;
    BtnPurgeQueue: TButton;
    BtnDeleteQueue: TButton;
    BtnPublish: TButton;
    BtnStartConsumer: TButton;
    BtnStopConsumer: TButton;
    BtnClearLogs: TButton;
    CmbLevelFilter: TComboBox;
    CmbKindFilter: TComboBox;
    ListLogs: TListView;
    procedure BtnClearLogsClick(Sender: TObject);
    procedure BtnConnectClick(Sender: TObject);
    procedure BtnCreateQueueClick(Sender: TObject);
    procedure BtnDeleteQueueClick(Sender: TObject);
    procedure BtnDisconnectClick(Sender: TObject);
    procedure BtnPublishClick(Sender: TObject);
    procedure BtnPurgeQueueClick(Sender: TObject);
    procedure BtnStartConsumerClick(Sender: TObject);
    procedure BtnStopConsumerClick(Sender: TObject);
    procedure CmbFilterChange(Sender: TObject);
  private
    FFactory: IAMQPConnectionFactory;
    FConnection: IAMQPConnection;
    FChannel: IAMQPChannel;
    FConsumer: IAMQPConsumer;
    FLogger: IAMQPLogger;
    FLogEvents: TList<TAMQPLogEvent>;

    procedure AddLogEvent(const AEvent: TAMQPLogEvent);
    procedure FillFilters;
    procedure HandleChannelClosed(const AException: EAMQPChannelClosedError);
    function LogEventMatchesFilter(const AEvent: TAMQPLogEvent): Boolean;
    procedure RebuildLogList;
    procedure UpdateButtons;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  VclQueueManagerForm: TMainForm;

implementation

{$R *.dfm}

uses
  Vcl.Dialogs,
  DelphiAMQP.Factory,
  DelphiAMQP.Logging,
  DelphiAMQP.Message,
  DelphiAMQP.Options;

function ComboTextMatchesEnum(
  const AText: string;
  const ATypeInfo: PTypeInfo;
  const AOrdinal: Integer): Boolean;
begin
  Result := (AText = 'Todos') or SameText(AText, GetEnumName(ATypeInfo, AOrdinal));
end;

constructor TVclQueueManagerLogger.Create(const AOnLog: TLogEventProc);
begin
  inherited Create;
  FOnLog := AOnLog;
end;

procedure TVclQueueManagerLogger.Log(const AEvent: TAMQPLogEvent);
begin
  TThread.Queue(nil,
    procedure
    begin
      if Assigned(FOnLog) then
        FOnLog(AEvent);
    end);
end;

procedure TMainForm.AddLogEvent(const AEvent: TAMQPLogEvent);
begin
  FLogEvents.Add(AEvent);
  if LogEventMatchesFilter(AEvent) then
    RebuildLogList;
end;

procedure TMainForm.BtnClearLogsClick(Sender: TObject);
begin
  FLogEvents.Clear;
  RebuildLogList;
end;

procedure TMainForm.BtnConnectClick(Sender: TObject);
var
  LOptions: IAMQPConnectionOptions;
  LPort: Integer;
  LDispatchMode: TAMQPConsumerDispatchMode;
begin
  LPort := StrToInt(EdtPort.Text);
  if CmbDispatchMode.ItemIndex = 1 then
    LDispatchMode := cdmMainThread
  else
    LDispatchMode := cdmWorkerThread;

  FFactory := TAMQPConnectionFactory.Create(FLogger);
  LOptions := TAMQPConnectionOptions.CreateDefault
    .SetHost(EdtHost.Text)
    .SetPort(UInt16(LPort))
    .SetVirtualHost(EdtVirtualHost.Text)
    .SetUserName(EdtUserName.Text)
    .SetPassword(EdtPassword.Text)
    .SetConsumerDispatchMode(LDispatchMode);

  FConnection := FFactory.CreateConnection(LOptions);
  FConnection.Connect;
  FChannel := FConnection.CreateChannel;
  UpdateButtons;
end;

procedure TMainForm.BtnCreateQueueClick(Sender: TObject);
var
  LResult: TAMQPQueueDeclareResult;
begin
  try
    LResult := FChannel.QueueDeclare(EdtQueueName.Text, True, False, False);
    ShowMessage(Format(
      'Fila declarada: %s'#13#10'Mensagens: %d'#13#10'Consumers: %d',
      [LResult.QueueName, LResult.MessageCount, LResult.ConsumerCount]));
  except
    on E: EAMQPChannelClosedError do
      HandleChannelClosed(E);
  end;
end;

procedure TMainForm.BtnDeleteQueueClick(Sender: TObject);
begin
  try
    FChannel.QueueDelete(EdtQueueName.Text);
  except
    on E: EAMQPChannelClosedError do
      HandleChannelClosed(E);
  end;
end;

procedure TMainForm.BtnDisconnectClick(Sender: TObject);
begin
  if FConsumer <> nil then
  begin
    FConsumer.Stop;
    FConsumer := nil;
  end;

  if FConnection <> nil then
    FConnection.Disconnect;

  FChannel := nil;
  FConnection := nil;
  FFactory := nil;
  UpdateButtons;
end;

procedure TMainForm.BtnPublishClick(Sender: TObject);
begin
  FChannel.Publish('', EdtQueueName.Text, TAMQPMessage.FromText(MemoMessage.Text));
end;

procedure TMainForm.BtnPurgeQueueClick(Sender: TObject);
begin
  try
    FChannel.QueuePurge(EdtQueueName.Text);
  except
    on E: EAMQPChannelClosedError do
      HandleChannelClosed(E);
  end;
end;

procedure TMainForm.BtnStartConsumerClick(Sender: TObject);
begin
  try
    FConsumer := FChannel.BasicConsume(
      EdtQueueName.Text,
      procedure(const AMessage: IAMQPMessage; const AContext: IAMQPConsumerContext)
      begin
        TThread.Queue(nil,
          procedure
          begin
            MemoReceived.Lines.Add(AMessage.AsText);
          end);
        AContext.Ack;
      end,
      False);
    FConsumer.Start;
    UpdateButtons;
  except
    on E: EAMQPChannelClosedError do
    begin
      FConsumer := nil;
      HandleChannelClosed(E);
    end;
  end;
end;

procedure TMainForm.BtnStopConsumerClick(Sender: TObject);
begin
  if FConsumer <> nil then
  begin
    FConsumer.Stop;
    FConsumer := nil;
  end;
  UpdateButtons;
end;

procedure TMainForm.CmbFilterChange(Sender: TObject);
begin
  RebuildLogList;
end;

constructor TMainForm.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FLogEvents := TList<TAMQPLogEvent>.Create;
  FLogger := TVclQueueManagerLogger.Create(
    procedure(const AEvent: TAMQPLogEvent)
    begin
      AddLogEvent(AEvent);
    end);
  FillFilters;
  UpdateButtons;
end;

destructor TMainForm.Destroy;
begin
  if FConsumer <> nil then
    FConsumer.Stop;
  if FConnection <> nil then
    FConnection.Disconnect;
  FLogEvents.Free;
  inherited;
end;

procedure TMainForm.FillFilters;
var
  LLevel: TAMQPLogLevel;
  LKind: TAMQPLogEventKind;
begin
  CmbLevelFilter.Items.Add('Todos');
  for LLevel := Low(TAMQPLogLevel) to High(TAMQPLogLevel) do
    CmbLevelFilter.Items.Add(GetEnumName(TypeInfo(TAMQPLogLevel), Ord(LLevel)));
  CmbLevelFilter.ItemIndex := 0;

  CmbKindFilter.Items.Add('Todos');
  for LKind := Low(TAMQPLogEventKind) to High(TAMQPLogEventKind) do
    CmbKindFilter.Items.Add(GetEnumName(TypeInfo(TAMQPLogEventKind), Ord(LKind)));
  CmbKindFilter.ItemIndex := 0;
end;

procedure TMainForm.HandleChannelClosed(const AException: EAMQPChannelClosedError);
begin
  FConsumer := nil;
  FChannel := nil;
  if FConnection <> nil then
    FChannel := FConnection.CreateChannel;
  UpdateButtons;
  ShowMessage('O RabbitMQ fechou o canal AMQP usado pela operação. Um novo canal foi aberto para as próximas ações.');
end;

function TMainForm.LogEventMatchesFilter(const AEvent: TAMQPLogEvent): Boolean;
begin
  Result :=
    ComboTextMatchesEnum(CmbLevelFilter.Text, TypeInfo(TAMQPLogLevel), Ord(AEvent.Level)) and
    ComboTextMatchesEnum(CmbKindFilter.Text, TypeInfo(TAMQPLogEventKind), Ord(AEvent.Kind));
end;

procedure TMainForm.RebuildLogList;
var
  LEvent: TAMQPLogEvent;
  LItem: TListItem;
begin
  ListLogs.Items.BeginUpdate;
  try
    ListLogs.Items.Clear;
    for LEvent in FLogEvents do
    begin
      if not LogEventMatchesFilter(LEvent) then
        Continue;

      LItem := ListLogs.Items.Add;
      LItem.Caption := FormatDateTime('hh:nn:ss.zzz', LEvent.Timestamp);
      LItem.SubItems.Add(GetEnumName(TypeInfo(TAMQPLogLevel), Ord(LEvent.Level)));
      LItem.SubItems.Add(GetEnumName(TypeInfo(TAMQPLogEventKind), Ord(LEvent.Kind)));
      LItem.SubItems.Add(LEvent.Operation);
      LItem.SubItems.Add(LEvent.ChannelId.ToString);
      if LEvent.DurationMS > 0 then
        LItem.SubItems.Add(LEvent.DurationMS.ToString + ' ms')
      else
        LItem.SubItems.Add('');
      LItem.SubItems.Add(LEvent.Message);
    end;
  finally
    ListLogs.Items.EndUpdate;
  end;
end;

procedure TMainForm.UpdateButtons;
var
  LConnected: Boolean;
  LConsuming: Boolean;
begin
  LConnected := FChannel <> nil;
  LConsuming := FConsumer <> nil;

  BtnConnect.Enabled := not LConnected;
  BtnDisconnect.Enabled := LConnected;
  BtnCreateQueue.Enabled := LConnected;
  BtnPurgeQueue.Enabled := LConnected;
  BtnDeleteQueue.Enabled := LConnected and not LConsuming;
  BtnPublish.Enabled := LConnected;
  BtnStartConsumer.Enabled := LConnected and not LConsuming;
  BtnStopConsumer.Enabled := LConnected and LConsuming;
end;

end.
