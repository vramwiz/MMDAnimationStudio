unit MMDAnimationStudioFrame;

// MMDAnimationStudioの各機能ページを遅延生成し、選択PMXと外部通知をページ間で調停する。

interface

uses
  System.Classes,
  System.ImageList,
  Winapi.Messages,
  Vcl.Controls,
  Vcl.ComCtrls,
  Vcl.ExtCtrls,
  Vcl.Forms,
  Vcl.ImgList,
  Vcl.StdCtrls,
  Vcl.ToolWin,
  DarkPanel,
  DarkLabel,
  ExplorerFrame,
  LauncherFrame,
  PmxCatalogFrame,
  MmdAccessoryCatalogFrame,
  MmdPoseCatalogFrame,
  MmdTimelinePosePageController,
  MmdTimelinePoseTabController,
  MmdMotionCatalogFrame,
  MmdFaceCatalogFrame,
  SerifFrame,
  MmdSerifHost,
  MmdStudioPageComposition,
  MMDAnimationStudioToolbarController;

const
  WM_MMD_APPLY_SCENE_CHANGED = WM_APP + 242;

type
  TFrameMMDAnimationStudio = class(TFrame)
    PanelToolbar: TDarkPanel;
    ToolbarPages: TToolBar;
    ButtonPmx: TToolButton;
    ButtonAccessory: TToolButton;
    ButtonPoseMotion: TToolButton;
    ButtonPoseSync: TToolButton;
    ButtonMotion: TToolButton;
    ButtonExpression: TToolButton;
    ButtonSerif: TToolButton;
    ButtonExplorer: TToolButton;
    ButtonMusic: TToolButton;
    ButtonLaunch: TToolButton;
    PanelPmx: TDarkPanel;
    PanelAccessory: TDarkPanel;
    PanelPoseMotion: TDarkPanel;
    PanelPoseSync: TDarkPanel;
    PanelMotion: TDarkPanel;
    PanelExpression: TDarkPanel;
    PanelSerif: TDarkPanel;
    PanelExplorer: TDarkPanel;
    PanelMusic: TDarkPanel;
    PanelLaunch: TDarkPanel;
    ToolbarImages: TImageList;
  private
    FToolbarController: TMmdStudioToolbarController;
    FPages: TMmdStudioPageComposition;
    FPmxCatalogFrame: TFramePmxCatalog;
    FAccessoryCatalogFrame: TFrameMmdAccessoryCatalog;
    FPoseCatalogFrame: TFrameMmdPoseCatalog;
    FTimelinePosePage: TMmdTimelinePosePageController;
    FTimelinePoseTab: TMmdTimelinePoseTabController;
    FMotionCatalogFrame: TFrameMmdMotionCatalog;
    FFaceCatalogFrame: TFrameMmdFaceCatalog;
    FSerifHost: TMmdSerifHost;
    FExplorerFrame: TFrameExplorer;
    FLauncherFrame: TFrameLauncher;
    FSelectedPmxId: string;
    FSyncingPmxSelection: Boolean;
    FPendingSceneID: Longint;
    FSceneChangePosted: Longint;
    procedure EnsurePmxCatalogFrame;
    procedure EnsureAccessoryCatalogFrame;
    procedure EnsurePoseCatalogFrame;
    procedure EnsurePoseSyncPage;
    procedure EnsureMotionCatalogFrame;
    procedure EnsureFaceCatalogFrame;
    procedure EnsureSerifFrame;
    procedure EnsureExplorerFrame;
    procedure EnsureLauncherFrame;
    function GetSerifFrame: TFrameSerif;
    procedure PageChanging(Sender: TObject; Index: Integer);
    procedure PageChanged(Sender: TObject; Index: Integer);
    procedure PmxSelectionChanged(Sender: TObject);
    procedure SerifSelectionChanged(Sender: TObject);
    procedure PublishAiPoseCatalogContext;
    procedure ProjectLoaded;
    procedure ProjectSaving(const OldProjectFilePath,
      NewProjectFilePath: string);
    procedure SceneChanged(SceneID: Integer);
    procedure WmApplySceneChanged(var Message: TMessage);
      message WM_MMD_APPLY_SCENE_CHANGED;
  protected
    procedure Resize; override;
  public
    // ページ管理とAviUtl2通知接続を初期化する。各機能ページは必要になるまで生成しない。
    constructor Create(AOwner: TComponent); override;
    // AviUtl2通知を解除し、ページ管理とセリフホストを破棄する。
    destructor Destroy; override;
    // ドロップ内容を各Importerへ渡すが、現在の表示ページは変更しない。
    procedure DropFiles(Control: TWinControl; const Files: TArray<string>);
    // Codex候補をVPDとPoseUIDへ登録し、表示中の同一PMX一覧を更新する。
    function RegisterAiPose(const PmxId, ModelFile, PoseName,
      PoseData: string; out RegisteredPmxId, PoseFile, PoseId,
      ErrorText: string): Boolean;
    // 初回表示に必要なツールバー、PMX一覧、Launcherのホットキー受付を準備する。
    procedure Show; reintroduce;
    property PmxCatalogFrame: TFramePmxCatalog read FPmxCatalogFrame;
    property AccessoryCatalogFrame: TFrameMmdAccessoryCatalog
      read FAccessoryCatalogFrame;
    property PoseCatalogFrame: TFrameMmdPoseCatalog read FPoseCatalogFrame;
    property MotionCatalogFrame: TFrameMmdMotionCatalog read FMotionCatalogFrame;
    property FaceCatalogFrame: TFrameMmdFaceCatalog read FFaceCatalogFrame;
    property SerifFrame: TFrameSerif read GetSerifFrame;
    property ExplorerFrame: TFrameExplorer read FExplorerFrame;
    property LauncherFrame: TFrameLauncher read FLauncherFrame;
  end;

implementation

uses
  Winapi.Windows,
  Vcl.Graphics,
  AppFolderUtils,
  AviUtl2PluginProject,
  AviUtl2PluginScene,
  MmdAiPoseStudioIntegration,
  MMDAnimationStudioPmxSelection;

{$R *.dfm}

constructor TFrameMMDAnimationStudio.Create(AOwner: TComponent);
begin
  inherited;

  FPendingSceneID := -1;

  Color := clBlack;
  FToolbarController := TMmdStudioToolbarController.Create(PanelToolbar,
    ToolbarPages, ToolbarImages, [PanelPmx, PanelAccessory, PanelPoseMotion,
    PanelPoseSync, PanelMotion, PanelExpression, PanelSerif, PanelExplorer,
    PanelMusic, PanelLaunch], PageChanging, PageChanged);
  FPages := TMmdStudioPageComposition.Create(Self, PanelPmx, PanelAccessory,
    PanelPoseMotion, PanelPoseSync, PanelMotion, PanelExpression,
    PanelExplorer, PanelLaunch, PmxSelectionChanged);
  FTimelinePoseTab := TMmdTimelinePoseTabController.CreateForToolbar(Self,
    Self, ButtonPoseSync, FToolbarController, 2, 3);

  FSerifHost := TMmdSerifHost.Create(Self, PanelSerif);
  FSerifHost.OnSelection := SerifSelectionChanged;
  AviUtl2ProjectSetOnLoad(ProjectLoaded);
  AviUtl2ProjectSetOnSave(ProjectSaving);
  AviUtl2SceneSetOnChange(SceneChanged);
end;

destructor TFrameMMDAnimationStudio.Destroy;
begin
  AviUtl2SceneSetOnChange(nil);
  AviUtl2ProjectSetOnSave(nil);
  AviUtl2ProjectSetOnLoad(nil);
  FTimelinePoseTab.Free;
  FPages.Free;
  FSerifHost.Free;
  FToolbarController.Free;
  inherited;
end;

procedure TFrameMMDAnimationStudio.DropFiles(Control: TWinControl;
  const Files: TArray<string>);
begin
  try
    FPages.DropFiles(Files);
    FPmxCatalogFrame := FPages.Pmx;
    FAccessoryCatalogFrame := FPages.Accessory;
    FPoseCatalogFrame := FPages.Pose;
    FMotionCatalogFrame := FPages.Motion;
    FFaceCatalogFrame := FPages.Face;
    FExplorerFrame := FPages.Explorer;
    FLauncherFrame := FPages.Launcher;
  except
    { WM_DROPFILESのコールバック境界から例外を漏らさない。 }
  end;
end;

procedure TFrameMMDAnimationStudio.EnsureAccessoryCatalogFrame;
begin
  FPages.EnsureAccessory;
  FAccessoryCatalogFrame := FPages.Accessory;
end;

procedure TFrameMMDAnimationStudio.EnsureMotionCatalogFrame;
begin
  FPages.EnsureMotion;
  FPmxCatalogFrame := FPages.Pmx;
  FMotionCatalogFrame := FPages.Motion;
end;

procedure TFrameMMDAnimationStudio.EnsureExplorerFrame;
begin
  FPages.EnsureExplorer;
  FExplorerFrame := FPages.Explorer;
end;

procedure TFrameMMDAnimationStudio.EnsureLauncherFrame;
begin
  FPages.EnsureLauncher;
  FLauncherFrame := FPages.Launcher;
end;

procedure TFrameMMDAnimationStudio.EnsurePmxCatalogFrame;
begin
  FPages.EnsurePmx;
  FPmxCatalogFrame := FPages.Pmx;
end;

procedure TFrameMMDAnimationStudio.EnsurePoseCatalogFrame;
begin
  FPages.EnsurePose;
  FPmxCatalogFrame := FPages.Pmx;
  FPoseCatalogFrame := FPages.Pose;
end;

procedure TFrameMMDAnimationStudio.EnsurePoseSyncPage;
begin
  FPages.EnsurePoseSync;
  FTimelinePosePage := FPages.PoseSync;
end;

procedure TFrameMMDAnimationStudio.EnsureFaceCatalogFrame;
begin
  FPages.EnsureFace;
  FPmxCatalogFrame := FPages.Pmx;
  FFaceCatalogFrame := FPages.Face;
end;
procedure TFrameMMDAnimationStudio.EnsureSerifFrame;
begin
  FSerifHost.EnsureFrame;
end;

function TFrameMMDAnimationStudio.GetSerifFrame: TFrameSerif;
begin
  Result := FSerifHost.Frame;
end;

procedure TFrameMMDAnimationStudio.PageChanged(Sender: TObject;
  Index: Integer);
var
  TargetPmxId: string;
begin
  TargetPmxId := FSelectedPmxId;
  case Index of
    0:
      begin
        EnsurePmxCatalogFrame;
        FPmxCatalogFrame.SelectPmxId(FSelectedPmxId);
        FPmxCatalogFrame.Show;
      end;
    1:
      begin
        EnsureAccessoryCatalogFrame;
        FAccessoryCatalogFrame.Show;
      end;
    2:
      begin
        EnsurePoseCatalogFrame;
        // 初回生成時の既定選択通知で、切替前の選択を上書きさせない。
        FSelectedPmxId := TargetPmxId;
        FPoseCatalogFrame.SelectPmxId(TargetPmxId);
        FPoseCatalogFrame.Visible := True;
        FPoseCatalogFrame.Show;
      end;
    3:
      begin
        EnsurePoseSyncPage;
        FTimelinePosePage.Activate;
      end;
    4:
      begin
        EnsureMotionCatalogFrame;
        FSelectedPmxId := TargetPmxId;
        FMotionCatalogFrame.SelectPmxId(TargetPmxId);
        FMotionCatalogFrame.Visible := True;
        FMotionCatalogFrame.Show;
      end;
    5:
      begin
        EnsureFaceCatalogFrame;
        FSelectedPmxId := TargetPmxId;
        FFaceCatalogFrame.SelectPmxId(TargetPmxId);
        FFaceCatalogFrame.Visible := True;
        FFaceCatalogFrame.Show;
      end;
    6:
      begin
        EnsureSerifFrame;
        FSerifHost.Show;
      end;
    7:
      begin
        EnsureExplorerFrame;
        FExplorerFrame.Show;
      end;
    9:
      begin
        EnsureLauncherFrame;
        FLauncherFrame.Show;
      end;
  end;
end;

procedure TFrameMMDAnimationStudio.PageChanging(Sender: TObject;
  Index: Integer);
begin
  if PanelPoseSync.Visible and Assigned(FTimelinePosePage) then
    FTimelinePosePage.Deactivate;
  // ページを隠すと一覧が先頭へ戻ることがあるため、可視中の選択を切替前に保存する。
  if PanelPmx.Visible and Assigned(FPmxCatalogFrame) and
    (FPmxCatalogFrame.SelectedPmxId <> '') then
    FSelectedPmxId := FPmxCatalogFrame.SelectedPmxId;
end;

procedure TFrameMMDAnimationStudio.ProjectLoaded;
begin
  if Assigned(FTimelinePosePage) then
  begin
    FTimelinePosePage.Deactivate;
    if PanelPoseSync.Visible then FTimelinePosePage.Activate(False);
  end;
  FSerifHost.ProjectLoaded;
end;

procedure TFrameMMDAnimationStudio.ProjectSaving(const OldProjectFilePath,
  NewProjectFilePath: string);
begin
  FSerifHost.ProjectSaving(OldProjectFilePath, NewProjectFilePath);
end;

procedure TFrameMMDAnimationStudio.SceneChanged(SceneID: Integer);
begin
  // AviUtl2の編集セクション内では再度CallEditSectionを呼べない。
  InterlockedExchange(FPendingSceneID, SceneID);
  if not HandleAllocated then Exit;
  if InterlockedCompareExchange(FSceneChangePosted, 1, 0) = 0 then
    if not PostMessage(Handle, WM_MMD_APPLY_SCENE_CHANGED, 0, 0) then
      InterlockedExchange(FSceneChangePosted, 0);
end;

procedure TFrameMMDAnimationStudio.WmApplySceneChanged(
  var Message: TMessage);
var
  SceneID: Integer;
begin
  InterlockedExchange(FSceneChangePosted, 0);
  SceneID := InterlockedExchange(FPendingSceneID, -1);
  Message.Result := 0;
  if SceneID < 0 then Exit;
  try
    if Assigned(FTimelinePosePage) then
    begin
      FTimelinePosePage.Deactivate;
      if PanelPoseSync.Visible then FTimelinePosePage.Activate(False);
    end;
    FSerifHost.SceneChanged(SceneID);
  except
    // シーン変更のUI通知境界へ例外を漏らさない。
  end;
end;

procedure TFrameMMDAnimationStudio.PmxSelectionChanged(Sender: TObject);
begin
  SynchronizeMmdStudioPmxSelection(Sender, FPages.Pmx,
    FPages.Pose, FPages.Motion, FPages.Face,
    FSelectedPmxId, FSyncingPmxSelection);
  PublishAiPoseCatalogContext;
end;

procedure TFrameMMDAnimationStudio.PublishAiPoseCatalogContext;
begin
  PublishMmdAiCatalogContext(FPages.Pmx, FSelectedPmxId);
end;

function TFrameMMDAnimationStudio.RegisterAiPose(const PmxId, ModelFile,
  PoseName, PoseData: string; out RegisteredPmxId, PoseFile, PoseId,
  ErrorText: string): Boolean;
begin
  EnsurePmxCatalogFrame;
  Result := RegisterMmdAiPoseCandidate(FPmxCatalogFrame, FPoseCatalogFrame,
    FSelectedPmxId, PmxId, ModelFile, PoseName, PoseData, RegisteredPmxId,
    PoseFile, PoseId, ErrorText);
end;

procedure TFrameMMDAnimationStudio.Resize;
begin
  inherited;
  FToolbarController.UpdateHeight(CurrentPPI);
end;

procedure TFrameMMDAnimationStudio.Show;
begin
  FToolbarController.Initialize(CurrentPPI);
  EnsurePmxCatalogFrame;
  PublishAiPoseCatalogContext;
  // ランチャーページを開く前でもCtrl+Alt+数字を利用できるようにする。
  EnsureLauncherFrame;
  inherited Show;
  FTimelinePoseTab.Start;
  if FPendingSceneID >= 0 then SceneChanged(FPendingSceneID);
end;

procedure TFrameMMDAnimationStudio.SerifSelectionChanged(Sender: TObject);
begin
  if FToolbarController.ActiveIndex <> 6 then
    FToolbarController.Activate(6);
end;

end.
