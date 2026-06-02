unit DelphiAMQP.Internal.Session;

interface

uses
  DelphiAMQP.Types,
  DelphiAMQP.Protocol.Frame;

type
  IAMQPFrameSession = interface
    ['{6E3A10BF-39FD-45F7-A6A4-6FC58395285F}']
    procedure SendFrame(const AFrame: TAMQPFrame);
    function ReceiveFrame: TAMQPFrame;
    function ReceiveExpectedMethod(const AClassId, AMethodId: UInt16): TAMQPFrame;
    function GetFrameMax: UInt32;
    function GetConnectionId: string;
    function GetConsumerDispatchMode: TAMQPConsumerDispatchMode;
  end;

implementation

end.
