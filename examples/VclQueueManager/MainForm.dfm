object MainForm: TMainForm
  Left = 0
  Top = 0
  Caption = 'Delphi AMQP Core - VCL Queue Manager'
  ClientHeight = 720
  ClientWidth = 1100
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  TextHeight = 13
  object LabelHost: TLabel
    Left = 16
    Top = 16
    Width = 24
    Height = 13
    Caption = 'Host'
  end
  object LabelPort: TLabel
    Left = 192
    Top = 16
    Width = 27
    Height = 13
    Caption = 'Porta'
  end
  object LabelVirtualHost: TLabel
    Left = 288
    Top = 16
    Width = 60
    Height = 13
    Caption = 'Virtual host'
  end
  object LabelUserName: TLabel
    Left = 394
    Top = 16
    Width = 40
    Height = 13
    Caption = 'Usu'#225'rio'
  end
  object LabelPassword: TLabel
    Left = 530
    Top = 16
    Width = 32
    Height = 13
    Caption = 'Senha'
  end
  object LabelDispatchMode: TLabel
    Left = 666
    Top = 16
    Width = 77
    Height = 13
    Caption = 'Dispatch mode'
  end
  object LabelQueueName: TLabel
    Left = 16
    Top = 84
    Width = 18
    Height = 13
    Caption = 'Fila'
  end
  object LabelMessage: TLabel
    Left = 16
    Top = 152
    Width = 127
    Height = 13
    Caption = 'Mensagem para publicar'
  end
  object LabelReceived: TLabel
    Left = 612
    Top = 152
    Width = 123
    Height = 13
    Caption = 'Mensagens consumidas'
  end
  object LabelLevelFilter: TLabel
    Left = 16
    Top = 292
    Width = 53
    Height = 13
    Caption = 'Filtro level'
  end
  object LabelKindFilter: TLabel
    Left = 184
    Top = 292
    Width = 53
    Height = 13
    Caption = 'Filtro kind'
  end
  object EdtHost: TEdit
    Left = 16
    Top = 36
    Width = 160
    Height = 21
    TabOrder = 0
    Text = 'localhost'
  end
  object EdtPort: TEdit
    Left = 192
    Top = 36
    Width = 80
    Height = 21
    TabOrder = 1
    Text = '5672'
  end
  object EdtVirtualHost: TEdit
    Left = 288
    Top = 36
    Width = 90
    Height = 21
    TabOrder = 2
    Text = '/'
  end
  object EdtUserName: TEdit
    Left = 394
    Top = 36
    Width = 120
    Height = 21
    TabOrder = 3
    Text = 'guest'
  end
  object EdtPassword: TEdit
    Left = 530
    Top = 36
    Width = 120
    Height = 21
    PasswordChar = '*'
    TabOrder = 4
    Text = 'guest'
  end
  object CmbDispatchMode: TComboBox
    Left = 666
    Top = 36
    Width = 130
    Height = 21
    Style = csDropDownList
    ItemIndex = 0
    TabOrder = 5
    Text = 'Worker thread'
    Items.Strings = (
      'Worker thread'
      'Main thread')
  end
  object BtnConnect: TButton
    Left = 816
    Top = 34
    Width = 90
    Height = 30
    Caption = 'Conectar'
    TabOrder = 6
    OnClick = BtnConnectClick
  end
  object BtnDisconnect: TButton
    Left = 912
    Top = 34
    Width = 100
    Height = 30
    Caption = 'Desconectar'
    TabOrder = 7
    OnClick = BtnDisconnectClick
  end
  object EdtQueueName: TEdit
    Left = 16
    Top = 104
    Width = 260
    Height = 21
    TabOrder = 8
    Text = 'delphiamqp.demo'
  end
  object BtnCreateQueue: TButton
    Left = 292
    Top = 102
    Width = 95
    Height = 30
    Caption = 'Criar fila'
    TabOrder = 9
    OnClick = BtnCreateQueueClick
  end
  object BtnPurgeQueue: TButton
    Left = 394
    Top = 102
    Width = 95
    Height = 30
    Caption = 'Purge fila'
    TabOrder = 10
    OnClick = BtnPurgeQueueClick
  end
  object BtnDeleteQueue: TButton
    Left = 496
    Top = 102
    Width = 95
    Height = 30
    Caption = 'Excluir fila'
    TabOrder = 11
    OnClick = BtnDeleteQueueClick
  end
  object BtnStartConsumer: TButton
    Left = 612
    Top = 102
    Width = 115
    Height = 30
    Caption = 'Iniciar consumo'
    TabOrder = 12
    OnClick = BtnStartConsumerClick
  end
  object BtnStopConsumer: TButton
    Left = 734
    Top = 102
    Width = 110
    Height = 30
    Caption = 'Parar consumo'
    TabOrder = 13
    OnClick = BtnStopConsumerClick
  end
  object MemoMessage: TMemo
    Left = 16
    Top = 174
    Width = 420
    Height = 92
    Lines.Strings = (
      'Ol'#225' do exemplo visual Delphi AMQP Core')
    ScrollBars = ssVertical
    TabOrder = 14
  end
  object BtnPublish: TButton
    Left = 452
    Top = 174
    Width = 140
    Height = 30
    Caption = 'Publicar mensagem'
    TabOrder = 15
    OnClick = BtnPublishClick
  end
  object MemoReceived: TMemo
    Left = 612
    Top = 174
    Width = 472
    Height = 92
    ReadOnly = True
    ScrollBars = ssVertical
    TabOrder = 16
  end
  object CmbLevelFilter: TComboBox
    Left = 16
    Top = 312
    Width = 150
    Height = 21
    Style = csDropDownList
    TabOrder = 17
    OnChange = CmbFilterChange
  end
  object CmbKindFilter: TComboBox
    Left = 184
    Top = 312
    Width = 170
    Height = 21
    Style = csDropDownList
    TabOrder = 18
    OnChange = CmbFilterChange
  end
  object BtnClearLogs: TButton
    Left = 372
    Top = 310
    Width = 100
    Height = 30
    Caption = 'Limpar logs'
    TabOrder = 19
    OnClick = BtnClearLogsClick
  end
  object ListLogs: TListView
    Left = 16
    Top = 348
    Width = 1068
    Height = 360
    Columns = <
      item
        Caption = 'Hora'
        Width = 130
      end
      item
        Caption = 'Level'
        Width = 80
      end
      item
        Caption = 'Kind'
        Width = 100
      end
      item
        Caption = 'Opera'#231#227'o'
        Width = 150
      end
      item
        Caption = 'Canal'
      end
      item
        Caption = 'Dura'#231#227'o'
        Width = 90
      end
      item
        Caption = 'Mensagem'
        Width = 445
      end>
    ReadOnly = True
    RowSelect = True
    TabOrder = 20
    ViewStyle = vsReport
  end
end
