unit MMDAnimationStudioFrame;

interface

uses
  System.Classes,
  System.ImageList,
  Vcl.Controls,
  Vcl.ComCtrls,
  Vcl.ExtCtrls,
  Vcl.Forms,
  Vcl.ImgList,
  Vcl.ToolWin,
  ToolBarPanelManager,
  PmxCatalogFrame;

type
  TFrameMMDAnimationStudio = class(TFrame)
    PanelToolbar: TPanel;
    ToolbarPages: TToolBar;
    ButtonPmx: TToolButton;
    ButtonPoseMotion: TToolButton;
    ButtonExpression: TToolButton;
    ButtonSerif: TToolButton;
    ButtonExplorer: TToolButton;
    ButtonMusic: TToolButton;
    ButtonLaunch: TToolButton;
    PanelPmx: TPanel;
    PanelPoseMotion: TPanel;
    PanelExpression: TPanel;
    PanelSerif: TPanel;
    PanelExplorer: TPanel;
    PanelMusic: TPanel;
    PanelLaunch: TPanel;
    ToolbarImages: TImageList;
  private
    FToolbarInitialized: Boolean;
    FToolbarManager: TToolBarPanelManager;
    FUpdatingToolbarHeight: Boolean;
    FPmxCatalogFrame: TFramePmxCatalog;
    procedure DropFilesCore(const Files: TArray<string>);
    procedure EnsurePmxCatalogFrame;
    procedure InitializeToolbar;
    procedure UpdateToolbarHeight;
  protected
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure DropFiles(Control: TWinControl; const Files: TArray<string>);
    procedure Show; reintroduce;
    property PmxCatalogFrame: TFramePmxCatalog read FPmxCatalogFrame;
  end;

implementation

uses
  Winapi.CommCtrl,
  Winapi.Windows,
  System.Math,
  System.SysUtils,
  Vcl.Graphics,
  MMDAnimationStudioToolbarIcons;

{$R *.dfm}

const
  ToolbarBackground = TColor($002B2B2B);
  ToolbarForeground = clWhite;
  ToolbarHighlight = TColor($00627DE7);
  ToolbarHot = TColor($00B03C3C);
  ToolbarPressed = TColor($001F1F1F);
  ToolbarChecked = TColor($00FF6666);

constructor TFrameMMDAnimationStudio.Create(AOwner: TComponent);
begin
  inherited;

  Color := clBlack;
  PanelToolbar.Color := ToolbarBackground;
  ToolbarPages.Color := ToolbarBackground;
  ToolbarPages.Font.Color := ToolbarForeground;

  FToolbarManager := TToolBarPanelManager.Create;
  FToolbarManager.ToolBarBackgroundColor := ToolbarBackground;
  FToolbarManager.ToolBarFontColor := ToolbarForeground;
  FToolbarManager.ToolBarCheckedColor := ToolbarChecked;
  FToolbarManager.ToolBarPressedColor := ToolbarPressed;
  FToolbarManager.ToolBarHotColor := ToolbarHot;
  FToolbarManager.ShowCaptions := False;
end;

destructor TFrameMMDAnimationStudio.Destroy;
begin
  FToolbarManager.Free;
  inherited;
end;

procedure TFrameMMDAnimationStudio.DropFiles(Control: TWinControl;
  const Files: TArray<string>);
begin
  try
    DropFilesCore(Files);
  except
    { WM_DROPFILESのコールバック境界から例外を漏らさない。 }
  end;
end;

procedure TFrameMMDAnimationStudio.DropFilesCore(const Files: TArray<string>);
var
  FileName: string;
begin
  for FileName in Files do
    if SameText(ExtractFileExt(FileName), '.pmx') then
    begin
      EnsurePmxCatalogFrame;
      FToolbarManager.Activate(0);
      FPmxCatalogFrame.DropFiles(Files);
      Exit;
    end;
end;

procedure TFrameMMDAnimationStudio.EnsurePmxCatalogFrame;
begin
  if Assigned(FPmxCatalogFrame) then
    Exit;

  FPmxCatalogFrame := TFramePmxCatalog.Create(Self);
  FPmxCatalogFrame.Parent := PanelPmx;
  FPmxCatalogFrame.Align := alClient;
  FPmxCatalogFrame.Visible := True;
  FPmxCatalogFrame.Show;
end;

procedure TFrameMMDAnimationStudio.InitializeToolbar;
var
  ButtonSize: Integer;
  Index: Integer;
begin
  if FToolbarInitialized then
    Exit;

  ButtonSize := MulDiv(28, CurrentPPI, 96);
  ToolbarPages.ButtonWidth := ButtonSize;
  ToolbarPages.ButtonHeight := ButtonSize;
  ToolbarPages.Height := ButtonSize;
  ToolbarPages.ShowCaptions := False;
  ToolbarPages.ShowHint := True;

  for Index := 0 to ToolbarPages.ButtonCount - 1 do
  begin
    if ToolbarPages.Buttons[Index].Hint = '' then
      ToolbarPages.Buttons[Index].Hint := ToolbarPages.Buttons[Index].Caption;
    ToolbarPages.Buttons[Index].ShowHint := True;
  end;

  BuildMMDAnimationStudioToolbarIcons(ToolbarImages,
    MulDiv(20, CurrentPPI, 96), ToolbarForeground, ToolbarHighlight);
  ToolbarPages.Images := ToolbarImages;

  FToolbarManager.AddPanel(PanelPmx);
  FToolbarManager.AddPanel(PanelPoseMotion);
  FToolbarManager.AddPanel(PanelExpression);
  FToolbarManager.AddPanel(PanelSerif);
  FToolbarManager.AddPanel(PanelExplorer);
  FToolbarManager.AddPanel(PanelMusic);
  FToolbarManager.AddPanel(PanelLaunch);
  FToolbarManager.Attach(ToolbarPages);
  FToolbarInitialized := True;
  UpdateToolbarHeight;
end;

procedure TFrameMMDAnimationStudio.Resize;
begin
  inherited;
  UpdateToolbarHeight;
end;

procedure TFrameMMDAnimationStudio.UpdateToolbarHeight;
var
  ButtonRect: TRect;
  Index: Integer;
  RequiredHeight: Integer;
begin
  if not FToolbarInitialized or FUpdatingToolbarHeight or
     not ToolbarPages.HandleAllocated then
    Exit;

  FUpdatingToolbarHeight := True;
  try
    ToolbarPages.Perform(TB_AUTOSIZE, 0, 0);
    RequiredHeight := MulDiv(28, CurrentPPI, 96);
    for Index := 0 to ToolbarPages.ButtonCount - 1 do
      if ToolbarPages.Perform(TB_GETITEMRECT, Index,
        LPARAM(@ButtonRect)) <> 0 then
        RequiredHeight := Max(RequiredHeight, ButtonRect.Bottom);

    if ToolbarPages.Height <> RequiredHeight then
      ToolbarPages.Height := RequiredHeight;
    if PanelToolbar.Height <> RequiredHeight then
      PanelToolbar.Height := RequiredHeight;
  finally
    FUpdatingToolbarHeight := False;
  end;
end;

procedure TFrameMMDAnimationStudio.Show;
begin
  InitializeToolbar;
  EnsurePmxCatalogFrame;
  inherited Show;
end;

end.
