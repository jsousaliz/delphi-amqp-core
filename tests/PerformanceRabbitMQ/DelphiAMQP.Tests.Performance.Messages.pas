unit DelphiAMQP.Tests.Performance.Messages;

interface

function BuildMessagePayload(const AMessageId: Integer): string;
function TryParseMessageId(const APayload: string; out AMessageId: Integer): Boolean;

implementation

uses
  System.JSON,
  System.SysUtils;

const
  MESSAGE_IDENTIFIER = 'delphi-amqp-core-perf';
  MESSAGE_TYPE_OFFSET = 3;
  MESSAGE_TYPE_STEP = 7;

function BuildMessagePayload(const AMessageId: Integer): string;
const
  MESSAGE_TEXTS: array[0..4] of string = (
    'Mensagem curta para teste de performance.',
    'Mensagem media para simular uma carga comum de servico com dados operacionais e texto adicional.',
    'Mensagem longa para validar publicacao e consumo com payload maior, simulando eventos de negocio com varias propriedades, descricoes e dados complementares de rastreabilidade.',
    'Mensagem de auditoria com texto medio, identificador funcional, origem, destino, status e detalhes suficientes para simular um evento de integracao.',
    'Mensagem extensa para exercitar blocos maiores de conteudo no AMQP, com descricao detalhada, informacoes repetidas, contexto operacional, observabilidade, rastreio, diagnostico e dados adicionais usados em cenarios reais de mensageria.'
  );
var
  LMessageText: string;
  LMessageType: Integer;
begin
  LMessageType := (Pred(AMessageId) * MESSAGE_TYPE_STEP + MESSAGE_TYPE_OFFSET) mod Length(MESSAGE_TEXTS);
  LMessageText := MESSAGE_TEXTS[LMessageType];

  Result := Format(
    '{"id":%d,"identificador":"%s","tipo":"tipo-%d","mensagem":"%s"}',
    [AMessageId, MESSAGE_IDENTIFIER, LMessageType + 1, LMessageText]);
end;

function TryParseMessageId(const APayload: string; out AMessageId: Integer): Boolean;
var
  LIdValue: TJSONValue;
  LJSON: TJSONValue;
  LObject: TJSONObject;
begin
  Result := False;
  LJSON := TJSONObject.ParseJSONValue(APayload);
  try
    if not (LJSON is TJSONObject) then
      Exit;

    LObject := TJSONObject(LJSON);
    LIdValue := LObject.GetValue('id');
    if LIdValue = nil then
      Exit;

    Result := TryStrToInt(LIdValue.Value, AMessageId);
  finally
    LJSON.Free;
  end;
end;

end.
