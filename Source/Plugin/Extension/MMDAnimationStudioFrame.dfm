object FrameMMDAnimationStudio: TFrameMMDAnimationStudio
  Left = 0
  Top = 0
  Width = 640
  Height = 480
  Color = clBlack
  ParentBackground = False
  ParentColor = False
  TabOrder = 0
  object PanelPmx: TPanel
    Left = 0
    Top = 30
    Width = 640
    Height = 450
    Align = alClient
    BevelOuter = bvNone
    Caption = ''
    Color = clBlack
    ParentBackground = False
    TabOrder = 0
  end
  object PanelPoseMotion: TPanel
    Left = 0
    Top = 30
    Width = 640
    Height = 450
    Align = alClient
    BevelOuter = bvNone
    Caption = ''
    Color = clBlack
    ParentBackground = False
    TabOrder = 1
  end
  object PanelExpression: TPanel
    Left = 0
    Top = 30
    Width = 640
    Height = 450
    Align = alClient
    BevelOuter = bvNone
    Caption = ''
    Color = clBlack
    ParentBackground = False
    TabOrder = 2
  end
  object PanelSerif: TPanel
    Left = 0
    Top = 30
    Width = 640
    Height = 450
    Align = alClient
    BevelOuter = bvNone
    Caption = ''
    Color = clBlack
    ParentBackground = False
    TabOrder = 3
  end
  object PanelExplorer: TPanel
    Left = 0
    Top = 30
    Width = 640
    Height = 450
    Align = alClient
    BevelOuter = bvNone
    Caption = ''
    Color = clBlack
    ParentBackground = False
    TabOrder = 4
  end
  object PanelMusic: TPanel
    Left = 0
    Top = 30
    Width = 640
    Height = 450
    Align = alClient
    BevelOuter = bvNone
    Caption = ''
    Color = clBlack
    ParentBackground = False
    TabOrder = 5
  end
  object PanelLaunch: TPanel
    Left = 0
    Top = 30
    Width = 640
    Height = 450
    Align = alClient
    BevelOuter = bvNone
    Caption = ''
    Color = clBlack
    ParentBackground = False
    TabOrder = 6
  end
  object PanelToolbar: TPanel
    Left = 0
    Top = 0
    Width = 640
    Height = 30
    Align = alTop
    AutoSize = True
    BevelOuter = bvNone
    Caption = ''
    Color = 2829099
    ParentBackground = False
    TabOrder = 7
    object ToolbarPages: TToolBar
      Left = 0
      Top = 0
      Width = 640
      Height = 28
      Align = alTop
      ButtonHeight = 28
      ButtonWidth = 28
      Caption = 'ToolbarPages'
      Color = 2829099
      EdgeBorders = []
      Flat = True
      List = False
      ParentColor = False
      ParentShowHint = False
      ShowCaptions = False
      ShowHint = True
      TabOrder = 0
      object ButtonPmx: TToolButton
        Left = 0
        Top = 0
        Hint = 'PMX'#12501#12449#12452#12523#12434#30331#37682#12375#31649#29702#12377#12427
        Caption = 'PMX'#12398#31649#29702
        ImageIndex = 0
      end
      object ButtonPoseMotion: TToolButton
        Left = 28
        Top = 0
        Hint = #12509#12540#12474#12392#12514#12540#12471#12519#12531#12434#30331#37682#12375#31649#29702#12377#12427
        Caption = #12509#12540#12474#12539#12514#12540#12471#12519#12531
        ImageIndex = 2
      end
      object ButtonExpression: TToolButton
        Left = 56
        Top = 0
        Hint = #34920#24773#12398#30331#37682#12392#31649#29702
        Caption = #34920#24773
        ImageIndex = 1
      end
      object ButtonSerif: TToolButton
        Left = 84
        Top = 0
        Hint = #12475#12522#12501#12434#30331#37682#12375#31649#29702#12377#12427
        Caption = #12475#12522#12501
        ImageIndex = 3
      end
      object ButtonExplorer: TToolButton
        Left = 112
        Top = 0
        Hint = #23554#29992#12456#12463#12473#12503#12525#12540#12521#12540#12434#34920#31034
        Caption = #12456#12463#12473#12503#12525#12540#12521#12540
        ImageIndex = 4
      end
      object ButtonMusic: TToolButton
        Left = 140
        Top = 0
        Hint = #38899#27005#12434#34920#31034
        Caption = #38899#27005
        ImageIndex = 5
      end
      object ButtonLaunch: TToolButton
        Left = 168
        Top = 0
        Hint = #30331#37682#12375#12383#12450#12503#12522#12434#36215#21205
        Caption = #36215#21205
        ImageIndex = 10
      end
    end
  end
  object ToolbarImages: TImageList
    ColorDepth = cd32Bit
    Height = 20
    Width = 20
    Left = 24
    Top = 56
  end
end
