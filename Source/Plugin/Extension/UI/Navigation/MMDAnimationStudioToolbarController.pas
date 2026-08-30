unit MMDAnimationStudioToolbarController;

// MMDAnimationStudioのページツールバーについて、配色、アイコン、ページ連動、DPI高さを管理する。
// 各ページの生成と表示内容は所有せず、呼び出し元から渡されたControlだけを操作する。

interface

uses
  System.Classes,
  Vcl.ComCtrls,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.ImgList,
  ToolBarPanelManager;

type
  TMmdStudioToolbarController = class
  private
    FImages: TCustomImageList;
    FInitialized: Boolean;
    FManager: TToolBarPanelManager;
    FOnChanging: TToolBarPanelChangeEvent;
    FToolbar: TToolBar;
    FToolbarPanel: TPanel;
    FUpdatingHeight: Boolean;
    procedure ButtonClick(Sender: TObject);
  public
    // ツールバーと表示対象パネルを関連付ける。渡されたControlは所有しない。
    constructor Create(AToolbarPanel: TPanel; AToolbar: TToolBar;
      AImages: TCustomImageList; const APanels: array of TPanel;
      AOnChanging, AOnChange: TToolBarPanelChangeEvent);
    // 内部のページ管理オブジェクトだけを破棄し、VCL Controlは破棄しない。
    destructor Destroy; override;
    // 指定ページを表示し、登録済み変更通知を呼び出す。
    procedure Activate(Index: Integer);
    // 初回だけ現在DPIに合わせてボタン、アイコン、ヒントを設定する。
    procedure Initialize(CurrentPpi: Integer);
    // DPIや折返し後のボタン矩形からツールバー領域の必要高さを再計算する。
    procedure UpdateHeight(CurrentPpi: Integer);
  end;

implementation

uses
  Winapi.CommCtrl,
  Winapi.Windows,
  System.Math,
  Vcl.Graphics,
  MMDAnimationStudioToolbarIcons;

const
  ToolbarBackground = TColor($002B2B2B);
  ToolbarForeground = clWhite;
  ToolbarHighlight = TColor($00627DE7);
  ToolbarHot = TColor($00B03C3C);
  ToolbarPressed = TColor($001F1F1F);
  ToolbarChecked = TColor($00FF6666);

constructor TMmdStudioToolbarController.Create(AToolbarPanel: TPanel;
  AToolbar: TToolBar; AImages: TCustomImageList;
  const APanels: array of TPanel; AOnChanging,
  AOnChange: TToolBarPanelChangeEvent);
var
  Panel: TPanel;
begin
  inherited Create;
  FToolbarPanel := AToolbarPanel;
  FToolbar := AToolbar;
  FImages := AImages;
  FOnChanging := AOnChanging;
  FToolbarPanel.Color := ToolbarBackground;
  FToolbarPanel.BevelOuter := bvNone;
  FToolbarPanel.BevelKind := bkSoft;
  FToolbarPanel.BevelWidth := 1;
  FToolbar.Color := ToolbarBackground;
  FToolbar.Font.Color := ToolbarForeground;

  FManager := TToolBarPanelManager.Create;
  FManager.ToolBarBackgroundColor := ToolbarBackground;
  FManager.ToolBarFontColor := ToolbarForeground;
  FManager.ToolBarCheckedColor := ToolbarChecked;
  FManager.ToolBarPressedColor := ToolbarPressed;
  FManager.ToolBarHotColor := ToolbarHot;
  FManager.ShowCaptions := False;
  FManager.OnChange := AOnChange;
  for Panel in APanels do
    FManager.AddPanel(Panel);
end;

procedure TMmdStudioToolbarController.ButtonClick(Sender: TObject);
begin
  if Sender is TToolButton then
    Activate(TToolButton(Sender).Index);
end;

destructor TMmdStudioToolbarController.Destroy;
begin
  FManager.Free;
  inherited;
end;

procedure TMmdStudioToolbarController.Activate(Index: Integer);
begin
  if Assigned(FOnChanging) then
    FOnChanging(Self, Index);
  FManager.Activate(Index);
end;

procedure TMmdStudioToolbarController.Initialize(CurrentPpi: Integer);
var
  ButtonSize: Integer;
  Index: Integer;
begin
  if FInitialized then
    Exit;
  ButtonSize := MulDiv(28, CurrentPpi, 96);
  FToolbar.ButtonWidth := ButtonSize;
  FToolbar.ButtonHeight := ButtonSize;
  FToolbar.Height := ButtonSize;
  FToolbar.ShowCaptions := False;
  FToolbar.ShowHint := True;
  for Index := 0 to FToolbar.ButtonCount - 1 do
  begin
    if FToolbar.Buttons[Index].Hint = '' then
      FToolbar.Buttons[Index].Hint := FToolbar.Buttons[Index].Caption;
    FToolbar.Buttons[Index].ShowHint := True;
  end;
  BuildMMDAnimationStudioToolbarIcons(FImages,
    MulDiv(20, CurrentPpi, 96), ToolbarForeground, ToolbarHighlight);
  FToolbar.Images := FImages;
  // Attachは変更通知を発生させるため、親Frameが表示準備を終えた初期化時まで遅延する。
  FManager.Attach(FToolbar);
  for Index := 0 to FToolbar.ButtonCount - 1 do
    FToolbar.Buttons[Index].OnClick := ButtonClick;
  FInitialized := True;
  UpdateHeight(CurrentPpi);
end;

procedure TMmdStudioToolbarController.UpdateHeight(CurrentPpi: Integer);
var
  ButtonRect: TRect;
  Index: Integer;
  RequiredHeight: Integer;
begin
  if not FInitialized or FUpdatingHeight or not FToolbar.HandleAllocated then
    Exit;
  FUpdatingHeight := True;
  try
    FToolbar.Perform(TB_AUTOSIZE, 0, 0);
    RequiredHeight := MulDiv(28, CurrentPpi, 96);
    for Index := 0 to FToolbar.ButtonCount - 1 do
      if FToolbar.Perform(TB_GETITEMRECT, Index,
        LPARAM(@ButtonRect)) <> 0 then
        RequiredHeight := Max(RequiredHeight, ButtonRect.Bottom);
    if FToolbar.Height <> RequiredHeight then
      FToolbar.Height := RequiredHeight;
    if FToolbarPanel.Height <> RequiredHeight then
      FToolbarPanel.Height := RequiredHeight;
  finally
    FUpdatingHeight := False;
  end;
end;

end.
