unit MMDAnimationStudioFrame;

// MMDAnimationStudioの各機能ページを遅延生成し、選択PMXと外部通知をページ間で調停する。

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
  DarkPanel,
  ExplorerFrame,
  LauncherFrame,
  PmxCatalogFrame,
  MmdPoseCatalogFrame,
  MmdMotionCatalogFrame,
  MmdFaceCatalogFrame,
  SerifFrame,
  MmdSerifHost,
  MMDAnimationStudioToolbarController;

type
  TFrameMMDAnimationStudio = class(TFrame)
    PanelToolbar: TDarkPanel;
    ToolbarPages: TToolBar;
    ButtonPmx: TToolButton;
    ButtonPoseMotion: TToolButton;
    ButtonMotion: TToolButton;
    ButtonExpression: TToolButton;
    ButtonSerif: TToolButton;
    ButtonExplorer: TToolButton;
    ButtonMusic: TToolButton;
    ButtonLaunch: TToolButton;
    PanelPmx: TDarkPanel;
    PanelPoseMotion: TDarkPanel;
    PanelMotion: TDarkPanel;
    PanelExpression: TDarkPanel;
    PanelSerif: TDarkPanel;
    PanelExplorer: TDarkPanel;
    PanelMusic: TDarkPanel;
    PanelLaunch: TDarkPanel;
    ToolbarImages: TImageList;
  private
    FToolbarController: TMmdStudioToolbarController;
    FPmxCatalogFrame: TFramePmxCatalog;
    FPoseCatalogFrame: TFrameMmdPoseCatalog;
    FMotionCatalogFrame: TFrameMmdMotionCatalog;
    FFaceCatalogFrame: TFrameMmdFaceCatalog;
    FSerifHost: TMmdSerifHost;
    FExplorerFrame: TFrameExplorer;
    FLauncherFrame: TFrameLauncher;
    FSelectedPmxId: string;
    FSyncingPmxSelection: Boolean;
    procedure DropFilesCore(const Files: TArray<string>);
    procedure EnsurePmxCatalogFrame;
    procedure EnsurePoseCatalogFrame;
    procedure EnsureMotionCatalogFrame;
    procedure EnsureFaceCatalogFrame;
    procedure EnsureSerifFrame;
    procedure EnsureExplorerFrame;
    procedure EnsureLauncherFrame;
    function GetSerifFrame: TFrameSerif;
    procedure PageChanging(Sender: TObject; Index: Integer);
    procedure PageChanged(Sender: TObject; Index: Integer);
    procedure PmxSelectionChanged(Sender: TObject);
    procedure ProjectLoaded;
    procedure ProjectSaving(const OldProjectFilePath,
      NewProjectFilePath: string);
    procedure SceneChanged(SceneID: Integer);
  protected
    procedure Resize; override;
  public
    // ページ管理とAviUtl2通知接続を初期化する。各機能ページは必要になるまで生成しない。
    constructor Create(AOwner: TComponent); override;
    // AviUtl2通知を解除し、ページ管理とセリフホストを破棄する。
    destructor Destroy; override;
    // ドロップ内容と表示ページに応じてPMX、VPD、VMD、Explorer、Launcherへ入力を振り分ける。
    procedure DropFiles(Control: TWinControl; const Files: TArray<string>);
    // 初回表示に必要なツールバー、PMX一覧、Launcherのホットキー受付を準備する。
    procedure Show; reintroduce;
    property PmxCatalogFrame: TFramePmxCatalog read FPmxCatalogFrame;
    property PoseCatalogFrame: TFrameMmdPoseCatalog read FPoseCatalogFrame;
    property MotionCatalogFrame: TFrameMmdMotionCatalog read FMotionCatalogFrame;
    property FaceCatalogFrame: TFrameMmdFaceCatalog read FFaceCatalogFrame;
    property SerifFrame: TFrameSerif read GetSerifFrame;
    property ExplorerFrame: TFrameExplorer read FExplorerFrame;
    property LauncherFrame: TFrameLauncher read FLauncherFrame;
  end;

implementation

uses
  System.IOUtils,
  System.SysUtils,
  Vcl.Graphics,
  AviUtl2PluginProject,
  AviUtl2PluginScene;

{$R *.dfm}

constructor TFrameMMDAnimationStudio.Create(AOwner: TComponent);
begin
  inherited;

  Color := clBlack;
  FToolbarController := TMmdStudioToolbarController.Create(PanelToolbar,
    ToolbarPages, ToolbarImages, [PanelPmx, PanelPoseMotion, PanelMotion,
    PanelExpression, PanelSerif, PanelExplorer, PanelMusic, PanelLaunch],
    PageChanging, PageChanged);

  FSerifHost := TMmdSerifHost.Create(Self, PanelSerif);
  AviUtl2ProjectSetOnLoad(ProjectLoaded);
  AviUtl2ProjectSetOnSave(ProjectSaving);
  AviUtl2SceneSetOnChange(SceneChanged);
end;

destructor TFrameMMDAnimationStudio.Destroy;
begin
  AviUtl2SceneSetOnChange(nil);
  AviUtl2ProjectSetOnSave(nil);
  AviUtl2ProjectSetOnLoad(nil);
  FSerifHost.Free;
  FToolbarController.Free;
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
  HasPmx, HasVmd, HasVpd, PoseWasActive: Boolean;
begin
  { ホストがマウス進入時などに空のドロップ通知を送る場合がある。
    空通知では表示ページを変更せず、そのまま無視する。 }
  if Length(Files) = 0 then
    Exit;

  if PanelLaunch.Visible then
  begin
    EnsureLauncherFrame;
    FLauncherFrame.DropFiles(Files);
    Exit;
  end;
  if PanelExplorer.Visible then
  begin
    EnsureExplorerFrame;
    FExplorerFrame.DropFile(Files);
    Exit;
  end;
  HasPmx := False;
  HasVmd := False;
  HasVpd := False;
  PoseWasActive := PanelPoseMotion.Visible;
  for FileName in Files do
    if SameText(ExtractFileExt(FileName), '.pmx') then
      HasPmx := True
    else if SameText(ExtractFileExt(FileName), '.vmd') then
      HasVmd := True
    else if SameText(ExtractFileExt(FileName), '.vpd') then
      HasVpd := True
    else if TDirectory.Exists(FileName) then
      try
        if Length(TDirectory.GetFiles(FileName, '*.vpd',
          TSearchOption.soAllDirectories)) > 0 then HasVpd := True;
        if Length(TDirectory.GetFiles(FileName, '*.vmd',
          TSearchOption.soAllDirectories)) > 0 then HasVmd := True;
      except
        { 読み取れないフォルダは登録処理側で失敗件数として扱う。 }
      end;
  if HasPmx then
  begin
    EnsurePmxCatalogFrame;
    FToolbarController.Activate(0);
    FPmxCatalogFrame.DropFiles(Files);
  end;
  if HasVpd then
  begin
    EnsurePmxCatalogFrame;
    if PoseWasActive then
    begin
      EnsurePoseCatalogFrame;
      FPoseCatalogFrame.ImportVpdFiles(Files);
    end
    else
      FPmxCatalogFrame.ImportVpdFiles(Files);
  end;
  if HasVmd then
  begin
    EnsureMotionCatalogFrame;
    FToolbarController.Activate(2);
    FMotionCatalogFrame.ImportVmdFiles(Files);
  end;
  if not HasPmx and not HasVpd and not HasVmd then
  begin
    EnsureExplorerFrame;
    FToolbarController.Activate(5);
    FExplorerFrame.DropFile(Files);
  end;
end;

procedure TFrameMMDAnimationStudio.EnsureMotionCatalogFrame;
begin
  EnsurePmxCatalogFrame;
  if Assigned(FMotionCatalogFrame) then
  begin
    FMotionCatalogFrame.SetCatalog(FPmxCatalogFrame.Catalog);
    Exit;
  end;
  FMotionCatalogFrame := TFrameMmdMotionCatalog.Create(Self);
  FMotionCatalogFrame.Parent := PanelMotion;
  FMotionCatalogFrame.Align := alClient;
  FMotionCatalogFrame.OnPmxSelectionChanged := PmxSelectionChanged;
  FMotionCatalogFrame.SetCatalog(FPmxCatalogFrame.Catalog);
end;

procedure TFrameMMDAnimationStudio.EnsureExplorerFrame;
begin
  if Assigned(FExplorerFrame) then
    Exit;

  FExplorerFrame := TFrameExplorer.Create(Self);
  FExplorerFrame.Parent := PanelExplorer;
  FExplorerFrame.Align := alClient;
end;

procedure TFrameMMDAnimationStudio.EnsureLauncherFrame;
begin
  if Assigned(FLauncherFrame) then
    Exit;

  FLauncherFrame := TFrameLauncher.Create(Self);
  FLauncherFrame.Parent := PanelLaunch;
  FLauncherFrame.Align := alClient;
end;

procedure TFrameMMDAnimationStudio.EnsurePmxCatalogFrame;
begin
  if Assigned(FPmxCatalogFrame) then
    Exit;

  FPmxCatalogFrame := TFramePmxCatalog.Create(Self);
  FPmxCatalogFrame.Parent := PanelPmx;
  FPmxCatalogFrame.Align := alClient;
  FPmxCatalogFrame.Visible := True;
  FPmxCatalogFrame.OnPmxSelectionChanged := PmxSelectionChanged;
  FPmxCatalogFrame.Show;
end;

procedure TFrameMMDAnimationStudio.EnsurePoseCatalogFrame;
begin
  EnsurePmxCatalogFrame;
  if Assigned(FPoseCatalogFrame) then
  begin
    FPoseCatalogFrame.SetCatalog(FPmxCatalogFrame.Catalog);
    Exit;
  end;

  FPoseCatalogFrame := TFrameMmdPoseCatalog.Create(Self);
  FPoseCatalogFrame.Parent := PanelPoseMotion;
  FPoseCatalogFrame.Align := alClient;
  FPoseCatalogFrame.OnPmxSelectionChanged := PmxSelectionChanged;
  FPoseCatalogFrame.SetCatalog(FPmxCatalogFrame.Catalog);
end;

procedure TFrameMMDAnimationStudio.EnsureFaceCatalogFrame;
begin
  EnsurePmxCatalogFrame;
  if Assigned(FFaceCatalogFrame) then
  begin
    FFaceCatalogFrame.SetCatalog(FPmxCatalogFrame.Catalog);
    Exit;
  end;

  FFaceCatalogFrame := TFrameMmdFaceCatalog.Create(Self);
  FFaceCatalogFrame.Parent := PanelExpression;
  FFaceCatalogFrame.Align := alClient;
  FFaceCatalogFrame.OnPmxSelectionChanged := PmxSelectionChanged;
  FFaceCatalogFrame.SetCatalog(FPmxCatalogFrame.Catalog);
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
        EnsurePoseCatalogFrame;
        // 初回生成時の既定選択通知で、切替前の選択を上書きさせない。
        FSelectedPmxId := TargetPmxId;
        FPoseCatalogFrame.SelectPmxId(TargetPmxId);
        FPoseCatalogFrame.Visible := True;
        FPoseCatalogFrame.Show;
      end;
    2:
      begin
        EnsureMotionCatalogFrame;
        FSelectedPmxId := TargetPmxId;
        FMotionCatalogFrame.SelectPmxId(TargetPmxId);
        FMotionCatalogFrame.Visible := True;
        FMotionCatalogFrame.Show;
      end;
    3:
      begin
        EnsureFaceCatalogFrame;
        FSelectedPmxId := TargetPmxId;
        FFaceCatalogFrame.SelectPmxId(TargetPmxId);
        FFaceCatalogFrame.Visible := True;
        FFaceCatalogFrame.Show;
      end;
    4:
      begin
        EnsureSerifFrame;
        FSerifHost.Show;
      end;
    5:
      begin
        EnsureExplorerFrame;
        FExplorerFrame.Show;
      end;
    7:
      begin
        EnsureLauncherFrame;
        FLauncherFrame.Show;
      end;
  end;
end;

procedure TFrameMMDAnimationStudio.PageChanging(Sender: TObject;
  Index: Integer);
begin
  // ページを隠すと一覧が先頭へ戻ることがあるため、可視中の選択を切替前に保存する。
  if PanelPmx.Visible and Assigned(FPmxCatalogFrame) and
    (FPmxCatalogFrame.SelectedPmxId <> '') then
    FSelectedPmxId := FPmxCatalogFrame.SelectedPmxId;
end;

procedure TFrameMMDAnimationStudio.ProjectLoaded;
begin
  FSerifHost.ProjectLoaded;
end;

procedure TFrameMMDAnimationStudio.ProjectSaving(const OldProjectFilePath,
  NewProjectFilePath: string);
begin
  FSerifHost.ProjectSaving(OldProjectFilePath, NewProjectFilePath);
end;

procedure TFrameMMDAnimationStudio.SceneChanged(SceneID: Integer);
begin
  FSerifHost.SceneChanged(SceneID);
end;

procedure TFrameMMDAnimationStudio.PmxSelectionChanged(Sender: TObject);
begin
  if FSyncingPmxSelection then Exit;
  FSyncingPmxSelection := True;
  try
    if Sender = FPmxCatalogFrame then
    begin
      FSelectedPmxId := FPmxCatalogFrame.SelectedPmxId;
      if Assigned(FPoseCatalogFrame) then
        FPoseCatalogFrame.SetCatalog(FPmxCatalogFrame.Catalog);
      if Assigned(FFaceCatalogFrame) then
        FFaceCatalogFrame.SetCatalog(FPmxCatalogFrame.Catalog);
      if Assigned(FMotionCatalogFrame) then
        FMotionCatalogFrame.SetCatalog(FPmxCatalogFrame.Catalog);
    end
    else if Sender = FPoseCatalogFrame then
      FSelectedPmxId := FPoseCatalogFrame.PmxSelector.SelectedPmxId
    else if Sender = FMotionCatalogFrame then
      FSelectedPmxId := FMotionCatalogFrame.PmxSelector.SelectedPmxId
    else if Sender = FFaceCatalogFrame then
      FSelectedPmxId := FFaceCatalogFrame.PmxSelector.SelectedPmxId;
    if Assigned(FPmxCatalogFrame) and (Sender <> FPmxCatalogFrame) then
      FPmxCatalogFrame.SelectPmxId(FSelectedPmxId);
    if Assigned(FPoseCatalogFrame) and (Sender <> FPoseCatalogFrame) then
      FPoseCatalogFrame.SelectPmxId(FSelectedPmxId);
    if Assigned(FMotionCatalogFrame) and (Sender <> FMotionCatalogFrame) then
      FMotionCatalogFrame.SelectPmxId(FSelectedPmxId);
    if Assigned(FFaceCatalogFrame) and (Sender <> FFaceCatalogFrame) then
      FFaceCatalogFrame.SelectPmxId(FSelectedPmxId);
  finally
    FSyncingPmxSelection := False;
  end;
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
  // ランチャーページを開く前でもCtrl+Alt+数字を利用できるようにする。
  EnsureLauncherFrame;
  inherited Show;
end;

end.
