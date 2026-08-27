object FramePmxCatalog: TFramePmxCatalog
  Left = 0
  Top = 0
  Width = 640
  Height = 450
  Color = clBlack
  ParentBackground = False
  ParentColor = False
  TabOrder = 0
  object PanelHeader: TPanel
    Left = 0
    Top = 0
    Width = 640
    Height = 88
    Align = alTop
    BevelOuter = bvNone
    Caption = ''
    Color = 2368548
    ParentBackground = False
    TabOrder = 0
    object LabelTitle: TLabel
      Left = 12
      Top = 10
      Width = 55
      Height = 15
      Caption = 'PMX'#31649#29702
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWhite
      Font.Height = -13
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object LabelDropHint: TLabel
      Left = 12
      Top = 33
      Width = 275
      Height = 15
      Caption = 'PMX'#12501#12449#12452#12523#12434#12371#12398#12506#12540#12472#12408#12489#12525#12483#12503#12375#12390#12367#12384#12373#12356
      Font.Charset = DEFAULT_CHARSET
      Font.Color = 12632256
      Font.Height = -13
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
    end
    object LabelDropStatus: TLabel
      Left = 12
      Top = 57
      Width = 616
      Height = 27
      AutoSize = False
      Caption = #12489#12525#12483#12503#24453#27231#20013
      Font.Charset = DEFAULT_CHARSET
      Font.Color = 8454143
      Font.Height = -13
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      WordWrap = True
    end
  end
end
