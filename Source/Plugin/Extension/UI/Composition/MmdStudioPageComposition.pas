unit MmdStudioPageComposition;

// 拡張画面の機能ページを必要時に生成し、親パネルとPMXカタログへ接続する。

interface

uses
  System.Classes,
  DarkPanel,
  ExplorerFrame,
  LauncherFrame,
  MmdAccessoryCatalogFrame,
  MmdFaceCatalogFrame,
  MmdMotionCatalogFrame,
  MmdPoseCatalogFrame,
  MmdTimelinePosePageController,
  PmxCatalogFrame;

type
  TMmdStudioPageComposition = class
  private
    FOwner: TComponent;
    FOnPmxSelectionChanged: TNotifyEvent;
    FPmxPanel, FAccessoryPanel, FPosePanel, FPoseSyncPanel: TDarkPanel;
    FMotionPanel, FFacePanel, FExplorerPanel, FLauncherPanel: TDarkPanel;
    FPmxCatalogFrame: TFramePmxCatalog;
    FAccessoryCatalogFrame: TFrameMmdAccessoryCatalog;
    FPoseCatalogFrame: TFrameMmdPoseCatalog;
    FTimelinePosePage: TMmdTimelinePosePageController;
    FMotionCatalogFrame: TFrameMmdMotionCatalog;
    FFaceCatalogFrame: TFrameMmdFaceCatalog;
    FExplorerFrame: TFrameExplorer;
    FLauncherFrame: TFrameLauncher;
  public
    // 親画面とページ配置先を保持する。生成したフレームは親画面が所有する。
    constructor Create(AOwner: TComponent; APmxPanel, AAccessoryPanel,
      APosePanel, APoseSyncPanel, AMotionPanel, AFacePanel, AExplorerPanel,
      ALauncherPanel: TDarkPanel; AOnPmxSelectionChanged: TNotifyEvent);
    // 非VCLのポーズ同期ページ管理を破棄する。
    destructor Destroy; override;
    // PMX一覧を初回だけ生成し、選択通知を親画面へ接続する。
    procedure EnsurePmx;
    // アクセサリ一覧を初回だけ生成する。
    procedure EnsureAccessory;
    // PMX一覧とカタログを共有するポーズ一覧を生成または更新する。
    procedure EnsurePose;
    // 選択中Scriptオブジェクトの編集ページを初回だけ生成する。
    procedure EnsurePoseSync;
    // PMX一覧とカタログを共有するモーション一覧を生成または更新する。
    procedure EnsureMotion;
    // PMX一覧とカタログを共有する表情一覧を生成または更新する。
    procedure EnsureFace;
    // ファイルブラウザを初回だけ生成する。
    procedure EnsureExplorer;
    // 起動ツール一覧を初回だけ生成する。
    procedure EnsureLauncher;
    // 現在の表示ページと拡張子に応じて、ファイルを対応するImporterへ渡す。
    procedure DropFiles(const Files: TArray<string>);
    property Pmx: TFramePmxCatalog read FPmxCatalogFrame;
    property Accessory: TFrameMmdAccessoryCatalog read FAccessoryCatalogFrame;
    property Pose: TFrameMmdPoseCatalog read FPoseCatalogFrame;
    property PoseSync: TMmdTimelinePosePageController read FTimelinePosePage;
    property Motion: TFrameMmdMotionCatalog read FMotionCatalogFrame;
    property Face: TFrameMmdFaceCatalog read FFaceCatalogFrame;
    property Explorer: TFrameExplorer read FExplorerFrame;
    property Launcher: TFrameLauncher read FLauncherFrame;
  end;

implementation

uses
  Vcl.Controls,
  Vcl.StdCtrls,
  DarkLabel,
  MmdStudioDropClassifier;

constructor TMmdStudioPageComposition.Create(AOwner: TComponent;
  APmxPanel, AAccessoryPanel, APosePanel, APoseSyncPanel, AMotionPanel,
  AFacePanel, AExplorerPanel, ALauncherPanel: TDarkPanel;
  AOnPmxSelectionChanged: TNotifyEvent);
begin
  inherited Create;
  FOwner := AOwner;
  FPmxPanel := APmxPanel;
  FAccessoryPanel := AAccessoryPanel;
  FPosePanel := APosePanel;
  FPoseSyncPanel := APoseSyncPanel;
  FMotionPanel := AMotionPanel;
  FFacePanel := AFacePanel;
  FExplorerPanel := AExplorerPanel;
  FLauncherPanel := ALauncherPanel;
  FOnPmxSelectionChanged := AOnPmxSelectionChanged;
end;

destructor TMmdStudioPageComposition.Destroy;
begin
  FTimelinePosePage.Free;
  inherited;
end;

procedure TMmdStudioPageComposition.EnsurePmx;
begin
  if Assigned(FPmxCatalogFrame) then Exit;
  FPmxCatalogFrame := TFramePmxCatalog.Create(FOwner);
  FPmxCatalogFrame.Parent := FPmxPanel;
  FPmxCatalogFrame.Align := alClient;
  FPmxCatalogFrame.Visible := True;
  FPmxCatalogFrame.OnPmxSelectionChanged := FOnPmxSelectionChanged;
  FPmxCatalogFrame.Show;
end;

procedure TMmdStudioPageComposition.EnsureAccessory;
begin
  if Assigned(FAccessoryCatalogFrame) then Exit;
  FAccessoryCatalogFrame := TFrameMmdAccessoryCatalog.Create(FOwner);
  FAccessoryCatalogFrame.Parent := FAccessoryPanel;
  FAccessoryCatalogFrame.Align := alClient;
end;

procedure TMmdStudioPageComposition.EnsurePose;
begin
  EnsurePmx;
  if Assigned(FPoseCatalogFrame) then
  begin
    FPoseCatalogFrame.SetCatalog(FPmxCatalogFrame.Catalog);
    Exit;
  end;
  FPoseCatalogFrame := TFrameMmdPoseCatalog.Create(FOwner);
  FPoseCatalogFrame.Parent := FPosePanel;
  FPoseCatalogFrame.Align := alClient;
  FPoseCatalogFrame.OnPmxSelectionChanged := FOnPmxSelectionChanged;
  FPoseCatalogFrame.SetCatalog(FPmxCatalogFrame.Catalog);
end;

procedure TMmdStudioPageComposition.EnsurePoseSync;
var
  Prompt: TDarkLabel;
begin
  if Assigned(FTimelinePosePage) then Exit;
  Prompt := TDarkLabel.Create(FOwner);
  Prompt.Parent := FPoseSyncPanel;
  Prompt.Align := alClient;
  Prompt.AutoSize := False;
  Prompt.Alignment := taCenter;
  Prompt.Layout := tlCenter;
  Prompt.Caption := 'タイムラインのMMDポーズオブジェクトを選択してください';
  Prompt.ApplyDpi;
  FTimelinePosePage := TMmdTimelinePosePageController.CreateForPage(FOwner,
    FPoseSyncPanel, Prompt);
end;

procedure TMmdStudioPageComposition.EnsureMotion;
begin
  EnsurePmx;
  if Assigned(FMotionCatalogFrame) then
  begin
    FMotionCatalogFrame.SetCatalog(FPmxCatalogFrame.Catalog);
    Exit;
  end;
  FMotionCatalogFrame := TFrameMmdMotionCatalog.Create(FOwner);
  FMotionCatalogFrame.Parent := FMotionPanel;
  FMotionCatalogFrame.Align := alClient;
  FMotionCatalogFrame.OnPmxSelectionChanged := FOnPmxSelectionChanged;
  FMotionCatalogFrame.SetCatalog(FPmxCatalogFrame.Catalog);
end;

procedure TMmdStudioPageComposition.EnsureFace;
begin
  EnsurePmx;
  if Assigned(FFaceCatalogFrame) then
  begin
    FFaceCatalogFrame.SetCatalog(FPmxCatalogFrame.Catalog);
    Exit;
  end;
  FFaceCatalogFrame := TFrameMmdFaceCatalog.Create(FOwner);
  FFaceCatalogFrame.Parent := FFacePanel;
  FFaceCatalogFrame.Align := alClient;
  FFaceCatalogFrame.OnPmxSelectionChanged := FOnPmxSelectionChanged;
  FFaceCatalogFrame.SetCatalog(FPmxCatalogFrame.Catalog);
end;

procedure TMmdStudioPageComposition.EnsureExplorer;
begin
  if Assigned(FExplorerFrame) then Exit;
  FExplorerFrame := TFrameExplorer.Create(FOwner);
  FExplorerFrame.Parent := FExplorerPanel;
  FExplorerFrame.Align := alClient;
end;

procedure TMmdStudioPageComposition.EnsureLauncher;
begin
  if Assigned(FLauncherFrame) then Exit;
  FLauncherFrame := TFrameLauncher.Create(FOwner);
  FLauncherFrame.Parent := FLauncherPanel;
  FLauncherFrame.Align := alClient;
end;

procedure TMmdStudioPageComposition.DropFiles(const Files: TArray<string>);
var
  DropKinds: TMmdStudioDropKinds;
  PoseWasActive: Boolean;
begin
  // 空通知では表示ページや選択を変更しない。
  if Length(Files) = 0 then Exit;
  if FLauncherPanel.Visible then
  begin
    EnsureLauncher;
    FLauncherFrame.DropFiles(Files);
    Exit;
  end;
  if FExplorerPanel.Visible then
  begin
    EnsureExplorer;
    FExplorerFrame.DropFile(Files);
    Exit;
  end;
  if FAccessoryPanel.Visible then
  begin
    EnsureAccessory;
    FAccessoryCatalogFrame.DropFiles(Files);
    Exit;
  end;
  PoseWasActive := FPosePanel.Visible or FPoseSyncPanel.Visible;
  DropKinds := ClassifyMmdStudioDropFiles(Files);
  if mdkPmx in DropKinds then
  begin
    EnsurePmx;
    FPmxCatalogFrame.DropFiles(Files);
  end;
  if mdkVpd in DropKinds then
  begin
    EnsurePmx;
    if PoseWasActive then
    begin
      EnsurePose;
      FPoseCatalogFrame.ImportVpdFiles(Files);
    end
    else
      FPmxCatalogFrame.ImportVpdFiles(Files);
  end;
  if mdkVmd in DropKinds then
  begin
    EnsureMotion;
    FMotionCatalogFrame.ImportVmdFiles(Files);
  end;
  // 未知のドロップは無視し、表示ページを維持する。
end;

end.
