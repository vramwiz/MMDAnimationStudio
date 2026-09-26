unit MmdSerifHost;

// MMDAnimationStudioと共有Serifフレームのライフサイクル境界を所有する。
// AviUtl2コールバック中の再入を避け、プロジェクト同期はVCLタイマーへ遅延する。

interface

uses
  System.Classes,
  Vcl.Controls,
  Vcl.ExtCtrls,
  SerifFrame,
  SerifSpeechSynthesisProject,
  MmdSerifAviUtlSelectionSync;

type
  TMmdSerifSelectionEvent = procedure(Sender: TObject) of object;

  TMmdSerifProjectSaveAction = (
    mssNone,
    mssPromoteTemporary,
    mssCreateEmpty,
    mssRegisterExisting
  );

  TMmdSerifHost = class
  private
    FOwner: TComponent;
    FParent: TWinControl;
    FFrame: TFrameSerif;
    FProjectLoadTimer: TTimer;
    FProjectSaveTimer: TTimer;
    FProjectSaveAction: TMmdSerifProjectSaveAction;
    FProjectSaveFolder: string;
    FProjectSaveFilePath: string;
    FSpeechSaveAction: TSerifSpeechSynthesisSaveAction;
    FSpeechSourceFolder: string;
    FSpeechTargetFolder: string;
    FSelectionTimer: TTimer;
    FWasHovered: Boolean;
    FLastSelection: TMmdSerifSelection;
    FHasSelection: Boolean;
    FOnSelection: TMmdSerifSelectionEvent;
    procedure ProjectLoadTimer(Sender: TObject);
    procedure ProjectSaveTimer(Sender: TObject);
    procedure SelectionTimer(Sender: TObject);
    function Hovered: Boolean;
    procedure SerifMoveCursorFocus(Sender: TObject; Layer, Frame: Integer);
  public
    // 共有Serifを配置する親Controlを保持し、遅延同期用タイマーを生成する。引数は所有しない。
    constructor Create(AOwner: TComponent; AParent: TWinControl);
    // 保留中の同期を停止し、生成済みSerifフレームを破棄する。
    destructor Destroy; override;
    // 共有Serifフレームを必要時に1度だけ生成して返す。
    function EnsureFrame: TFrameSerif;
    // Serifフレームを生成して表示し、現在の台本状態を画面へ反映する。
    procedure Show;
    // AviUtl2のプロジェクト読込通知を遅延処理へ渡し、コールバック中の再入を防ぐ。
    procedure ProjectLoaded;
    // 保存前後のパスからプロジェクト昇格方法を決め、実処理をVCLタイマーへ遅延する。
    procedure ProjectSaving(const OldProjectFilePath,
      NewProjectFilePath: string);
    // 生成済みSerifフレームだけへシーン変更を通知する。未生成時は何もしない。
    procedure SceneChanged(SceneID: Integer);
    // タイムラインのフォーカス対象をSerif画面へ反映する。初回表示でも呼べる。
    procedure SyncSelection;
    property OnSelection: TMmdSerifSelectionEvent read FOnSelection write FOnSelection;
    property Frame: TFrameSerif read FFrame;
  end;

implementation

uses
  System.SysUtils,
  Winapi.Windows,
  AviUtl2PluginProject,
  SerifAviUtlProfile,
  SerifHostBootstrap,
  SerifProject,
  SerifProjectAviUtlSync;

constructor TMmdSerifHost.Create(AOwner: TComponent; AParent: TWinControl);
begin
  inherited Create;
  if AOwner = nil then
    raise EArgumentNilException.Create('MMD Serif host owner is nil.');
  if AParent = nil then
    raise EArgumentNilException.Create('MMD Serif host parent is nil.');
  FOwner := AOwner;
  FParent := AParent;

  FProjectLoadTimer := TTimer.Create(AOwner);
  FProjectLoadTimer.Enabled := False;
  FProjectLoadTimer.Interval := 1;
  FProjectLoadTimer.OnTimer := ProjectLoadTimer;

  FProjectSaveTimer := TTimer.Create(AOwner);
  FProjectSaveTimer.Enabled := False;
  FProjectSaveTimer.Interval := 1;
  FProjectSaveTimer.OnTimer := ProjectSaveTimer;

  FSelectionTimer := TTimer.Create(AOwner);
  FSelectionTimer.Interval := 250;
  FSelectionTimer.OnTimer := SelectionTimer;
end;

destructor TMmdSerifHost.Destroy;
begin
  FSelectionTimer.Free;
  FProjectSaveTimer.Free;
  FProjectLoadTimer.Free;
  FFrame.Free;
  inherited;
end;

function TMmdSerifHost.EnsureFrame: TFrameSerif;
var
  Config: TSerifHostConfig;
  Profile: TSerifAviUtlProfile;
begin
  if not Assigned(FFrame) then
  begin
    Profile := CurrentSerifAviUtlProfile;
    Config := Default(TSerifHostConfig);
    Config.ProductID := Profile.ProductID;
    Config.AppFolderName := Profile.ProductID;
    Config.Parent := FParent;
    Config.OnMoveCursorFocus := SerifMoveCursorFocus;
    FFrame := CreateHostedSerifFrame(FOwner, Config);
    SerifSpeechSynthesisLoadProject(AviUtl2GetProjectFilePath,
      ReadSerifAviUtlProjectFolder);
    FFrame.OpenSpeechSynthesisProject(SerifSpeechSynthesisCurrentFolder);
  end;
  Result := FFrame;
end;

procedure TMmdSerifHost.Show;
begin
  if not EnsureFrame.IsInputPageActive then
    FFrame.Show;
end;

function TMmdSerifHost.Hovered: Boolean;
var
  Cursor: TPoint;
  WindowAtCursor: HWND;
  Surface: TWinControl;
begin
  Result := False;
  if not (FOwner is TWinControl) then Exit;
  Surface := TWinControl(FOwner);
  if not Surface.Visible or not Surface.HandleAllocated or
    not GetCursorPos(Cursor) then Exit;
  WindowAtCursor := WindowFromPoint(Cursor);
  Result := (WindowAtCursor = Surface.Handle) or
    IsChild(Surface.Handle, WindowAtCursor);
end;

procedure TMmdSerifHost.SelectionTimer(Sender: TObject);
begin
  if not Hovered then
  begin
    FWasHovered := False;
    FHasSelection := False;
    Exit;
  end;
  if FWasHovered then Exit;
  FWasHovered := True;
  SyncSelection;
end;

procedure TMmdSerifHost.SyncSelection;
var
  Selection: TMmdSerifSelection;
begin
  try
    if not TryReadSelectedMmdSerif(Selection) then
    begin
      FHasSelection := False;
      Exit;
    end;
    if FHasSelection and
      (FLastSelection.ObjectId = Selection.ObjectId) and
      (FLastSelection.Layer = Selection.Layer) and
      (FLastSelection.StartFrame = Selection.StartFrame) and
      (FLastSelection.EndFrame = Selection.EndFrame) and
      (FLastSelection.WaveLayer = Selection.WaveLayer) and
      (FLastSelection.UID = Selection.UID) then Exit;
    FHasSelection := True;
    FLastSelection := Selection;
    if Assigned(FOnSelection) then FOnSelection(Self);
    Show;
    FFrame.ActiveSerif(Selection.StartFrame, Selection.Layer,
      Selection.WaveLayer, Selection.UID);
  except
    // AviUtl2との選択読取失敗をVCLタイマー境界から漏らさない。
  end;
end;

procedure TMmdSerifHost.ProjectLoaded;
begin
  FHasSelection := False;
  FWasHovered := False;
  SerifSpeechSynthesisBeginProjectLoad;
  FProjectLoadTimer.Enabled := False;
  FProjectLoadTimer.Enabled := True;
end;

procedure TMmdSerifHost.ProjectLoadTimer(Sender: TObject);
begin
  FProjectLoadTimer.Enabled := False;
  SerifSpeechSynthesisLoadProject(AviUtl2GetProjectFilePath,
    ReadSerifAviUtlProjectFolder);
  if not Assigned(FFrame) then Exit;
  FFrame.OpenSpeechSynthesisProject(SerifSpeechSynthesisCurrentFolder);
  FFrame.SyncProjectAndScene;
end;

procedure TMmdSerifHost.ProjectSaving(const OldProjectFilePath,
  NewProjectFilePath: string);
var
  CurrentFolder: string;
  NewFolder: string;
  OldParentFolder: string;
  NewParentFolder: string;
begin
  FSpeechSaveAction := SerifSpeechSynthesisPrepareSave(
    OldProjectFilePath, NewProjectFilePath, FSpeechSourceFolder,
    FSpeechTargetFolder);

  FProjectSaveAction := mssNone;
  FProjectSaveFolder := '';
  FProjectSaveFilePath := NewProjectFilePath;
  if Trim(NewProjectFilePath) = '' then Exit;
  CurrentFolder := ReadSerifAviUtlProjectFolder;
  if Trim(CurrentFolder) <> '' then
  begin
    if IsTemporarySerifProjectFolder(CurrentFolder) then
      FProjectSaveAction := mssPromoteTemporary
    else if Trim(OldProjectFilePath) = '' then
      FProjectSaveAction := mssRegisterExisting
    else
    begin
      OldParentFolder := ExcludeTrailingPathDelimiter(
        ExtractFilePath(OldProjectFilePath));
      NewParentFolder := ExcludeTrailingPathDelimiter(
        ExtractFilePath(NewProjectFilePath));
      if not SameText(OldParentFolder, NewParentFolder) then
        FProjectSaveAction := mssCreateEmpty;
    end;
  end;

  if FProjectSaveAction = mssRegisterExisting then
    FProjectSaveFolder := CurrentFolder
  else if FProjectSaveAction <> mssNone then
  begin
    NewFolder := CreateAutomaticSerifProjectFolder;
    if NewFolder = '' then
      FProjectSaveAction := mssNone
    else
    begin
      WriteSerifAviUtlProjectFolder(NewFolder);
      FProjectSaveFolder := NewFolder;
    end;
  end;

  if (FProjectSaveAction = mssNone) and
    (FSpeechSaveAction = sssaNone) then Exit;
  FProjectSaveTimer.Enabled := False;
  FProjectSaveTimer.Enabled := True;
end;

procedure TMmdSerifHost.ProjectSaveTimer(Sender: TObject);
var
  Action: TMmdSerifProjectSaveAction;
  Folder: string;
  ProjectFilePath: string;
  SpeechAction: TSerifSpeechSynthesisSaveAction;
  SpeechSourceFolder: string;
  SpeechTargetFolder: string;
begin
  FProjectSaveTimer.Enabled := False;
  Action := FProjectSaveAction;
  Folder := FProjectSaveFolder;
  ProjectFilePath := FProjectSaveFilePath;
  SpeechAction := FSpeechSaveAction;
  SpeechSourceFolder := FSpeechSourceFolder;
  SpeechTargetFolder := FSpeechTargetFolder;
  FProjectSaveAction := mssNone;
  FProjectSaveFolder := '';
  FProjectSaveFilePath := '';
  FSpeechSaveAction := sssaNone;
  FSpeechSourceFolder := '';
  FSpeechTargetFolder := '';

  if Assigned(FFrame) then
    FFrame.SaveSpeechSynthesisProject;
  SerifSpeechSynthesisCompleteSave(SpeechAction, SpeechSourceFolder,
    SpeechTargetFolder, ProjectFilePath);
  if Assigned(FFrame) and (SpeechAction = sssaSaveAs) then
    FFrame.OpenSpeechSynthesisProject(SpeechTargetFolder);

  if not Assigned(FFrame) then
  begin
    if Action = mssCreateEmpty then
      InitializeEmptySerifProjectFolder(Folder);
    Exit;
  end;
  case Action of
    mssPromoteTemporary:
      FFrame.PromoteTemporaryProject(Folder, ProjectFilePath);
    mssCreateEmpty:
      FFrame.SwitchToEmptyProject(Folder, ProjectFilePath);
    mssRegisterExisting:
      FFrame.RegisterAutomaticProject(Folder, ProjectFilePath);
  end;
end;

procedure TMmdSerifHost.SceneChanged(SceneID: Integer);
begin
  FHasSelection := False;
  FWasHovered := False;
  if Assigned(FFrame) then
    FFrame.SceneChange(SceneID);
end;

procedure TMmdSerifHost.SerifMoveCursorFocus(Sender: TObject; Layer,
  Frame: Integer);
begin
  // 共通SerifSceneMsgPanelが通知直後にカーソル移動とフォーカス設定を行う。
  // MMD側にはSyncroh2の選択同期ガードが無いため、追加処理は不要。
end;

end.
