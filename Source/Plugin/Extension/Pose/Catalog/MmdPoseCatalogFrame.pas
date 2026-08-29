unit MmdPoseCatalogFrame;

// ポーズページの共通PMX選択と、選択モデル別ポーズ一覧を構成する。

interface

uses
  System.Classes,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.Forms,
  PmxCatalogStorage,
  PmxCatalogSelector,
  PmxPoseCatalogStorage,
  PmxPoseCatalogGroups,
  PmxPoseCatalogGroupBar,
  PmxPoseCatalogListView,
  PmxPoseCatalogContextMenu,
  PmxPoseCatalogToolbar,
  PmxCatalogThumbnailCache,
  PmxCatalogThumbnailRenderer,
  MmdPoseObjectDragController;

type
  TMmdPoseCatalogEditEvent = function(Sender: TObject;
    Model: TPmxCatalogItem; Item: TPmxPoseCatalogItem): Boolean of object;

  TFrameMmdPoseCatalog = class(TFrame)
  private
    FCatalog: TPmxCatalogStorage;
    FDivider: TSplitter;
    FModelThumbnailCache: TPmxCatalogThumbnailCache;
    FOnEditPose: TMmdPoseCatalogEditEvent;
    FOnPmxSelectionChanged: TNotifyEvent;
    FPmxSelector: TPmxCatalogSelector;
    FPoseCatalog: TPmxPoseCatalogStorage;
    FPoseGroups: TPmxPoseCatalogGroups;
    FPoseGroupBar: TPmxPoseCatalogGroupBar;
    FPoseCatalogContextMenu: TPmxPoseCatalogContextMenu;
    FPoseDrag: TMmdPoseObjectDragController;
    FPoseListView: TPmxPoseCatalogListView;
    FPoseToolbar: TPmxPoseCatalogToolbar;
    FPoseThumbnailCache: TPmxCatalogThumbnailCache;
    FRightPanel: TPanel;
    FThumbnailRenderer: TPmxCatalogThumbnailRenderer;
    FLayoutPPI: Integer;
    procedure ApplyDpiLayout;
    procedure PoseListDblClick(Sender: TObject);
    procedure ReuseVpd(Sender: TObject);
    procedure PmxSelectionChanged(Sender: TObject);
  public
    // 共通PMX選択ペインとモデル別ポーズ一覧を生成する。
    constructor Create(AOwner: TComponent); override;
    // ポーズカタログ、サムネイル、PMX選択部品を解放する。
    destructor Destroy; override;
    // PMX管理と同じカタログをデータ元として設定する。
    procedure SetCatalog(ACatalog: TPmxCatalogStorage);
    // PmxUIDを選択し、対応するポーズ一覧を読み込む。
    procedure SelectPmxId(const PmxId: string);
    // VPDまたはフォルダを共通保管し、選択中PMXのポーズへ登録する。
    function ImportVpdFiles(const Files: TArray<string>;
      const VpdRoot: string = ''): Boolean;
    // AviUtl2のドッキング幅に合わせて一覧寸法を更新する。
    procedure Resize; override;
    // 表示時に選択中PMXのポーズを最新状態へ読み直す。
    procedure Show; reintroduce;
    property PmxSelector: TPmxCatalogSelector read FPmxSelector;
    property PoseCatalog: TPmxPoseCatalogStorage read FPoseCatalog;
    property PoseGroups: TPmxPoseCatalogGroups read FPoseGroups;
    property PoseGroupBar: TPmxPoseCatalogGroupBar read FPoseGroupBar;
    property PoseListView: TPmxPoseCatalogListView read FPoseListView;
    property PoseToolbar: TPmxPoseCatalogToolbar read FPoseToolbar;
    property OnPmxSelectionChanged: TNotifyEvent read FOnPmxSelectionChanged
      write FOnPmxSelectionChanged;
    property OnEditPose: TMmdPoseCatalogEditEvent read FOnEditPose
      write FOnEditPose;
  end;

implementation

uses
  Winapi.Windows,
  System.SysUtils,
  Vcl.Graphics,
  AppFolderUtils,
  PmxPoseCatalogEditor,
  MmdVpdPoseImporter,
  MmdVpdReuseForm;

{$R *.dfm}

const
  PmxListPaneWidth = 105;
  PmxDividerWidth = 3;
  PmxThumbnailSize = 64;
  PmxCaptionAreaHeight = 28;

constructor TFrameMmdPoseCatalog.Create(AOwner: TComponent);
var
  PmxFolder: string;
begin
  inherited;
  Color := clBlack;
  ParentBackground := False;
  PmxFolder := GetAppFolder('PMX');
  FModelThumbnailCache := TPmxCatalogThumbnailCache.Create(
    PmxFolder + 'Cache\Model');
  FPoseThumbnailCache := TPmxCatalogThumbnailCache.Create(
    PmxFolder + 'Cache\Pose');
  FThumbnailRenderer := TPmxCatalogThumbnailRenderer.Create(Self);
  FThumbnailRenderer.Parent := Self;

  FPmxSelector := TPmxCatalogSelector.Create(Self);
  FPmxSelector.Parent := Self;
  FPmxSelector.Color := Color;
  FPmxSelector.SetThumbnailServices(FModelThumbnailCache, FThumbnailRenderer);
  FPmxSelector.OnSelectionChanged := PmxSelectionChanged;

  FDivider := TSplitter.Create(Self);
  FDivider.Parent := Self;
  FDivider.Align := alLeft;
  FDivider.Width := PmxDividerWidth;
  FDivider.Beveled := True;
  FDivider.Left := FPmxSelector.Width;

  FRightPanel := TPanel.Create(Self);
  FRightPanel.Parent := Self;
  FRightPanel.Align := alClient;
  FRightPanel.BevelOuter := bvNone;
  FRightPanel.ParentBackground := False;
  FRightPanel.Color := Color;

  FPoseListView := TPmxPoseCatalogListView.Create(Self);
  FPoseListView.Parent := FRightPanel;
  FPoseListView.Align := alClient;
  FPoseListView.SetThumbnailServices(FPoseThumbnailCache, FThumbnailRenderer);
  FPoseListView.OnDblClick := PoseListDblClick;
  FPoseToolbar := TPmxPoseCatalogToolbar.Create(Self, FPoseListView);
  FPoseToolbar.Parent := FRightPanel;
  FPoseToolbar.Align := alTop;
  FPoseGroupBar := TPmxPoseCatalogGroupBar.Create(Self, FRightPanel,
    FPoseListView);
  FPoseGroupBar.Bar.Top := 0;
  FPoseToolbar.Top := FPoseGroupBar.Bar.Height;
  FPoseCatalogContextMenu := TPmxPoseCatalogContextMenu.Create(FPoseToolbar);
  FPoseCatalogContextMenu.OnReuseVpd := ReuseVpd;
  FPoseDrag := TMmdPoseObjectDragController.Create(Self, FPoseListView);
  ApplyDpiLayout;
end;

destructor TFrameMmdPoseCatalog.Destroy;
begin
  FPoseDrag.Free;
  FPoseCatalogContextMenu.Free;
  FPoseGroupBar.Free;
  FPoseToolbar.Free;
  FPoseListView.Free;
  FreeAndNil(FPoseCatalog);
  FreeAndNil(FPoseGroups);
  FPmxSelector.Free;
  FThumbnailRenderer.Free;
  FPoseThumbnailCache.Free;
  FModelThumbnailCache.Free;
  inherited;
end;

procedure TFrameMmdPoseCatalog.ApplyDpiLayout;
var
  PPI: Integer;
  ThumbnailSize: Integer;
begin
  if not Assigned(FPmxSelector) or not Assigned(FPoseListView) then Exit;
  PPI := FPmxSelector.ListView.CurrentPPI;
  if (PPI <= 0) or (FLayoutPPI = PPI) then Exit;
  FLayoutPPI := PPI;
  FPmxSelector.Width := PmxListPaneWidth;
  FDivider.Width := PmxDividerWidth;
  ThumbnailSize := MulDiv(PmxThumbnailSize, PPI, 96);
  FPmxSelector.ListView.ImageSize := ThumbnailSize;
  FPmxSelector.ListView.RowHeight := ThumbnailSize +
    MulDiv(PmxCaptionAreaHeight, PPI, 96);
  FPoseListView.ImageSize := ThumbnailSize;
  FPoseListView.RowHeight := ThumbnailSize +
    MulDiv(PmxCaptionAreaHeight, PPI, 96);
end;

procedure TFrameMmdPoseCatalog.PmxSelectionChanged(Sender: TObject);
var
  Model: TPmxCatalogItem;
  ModelFolder: string;
begin
  FPoseToolbar.SetCatalog(nil);
  FPoseGroupBar.SetGroups(nil);
  FPoseListView.SetData(nil, nil, nil);
  FreeAndNil(FPoseGroups);
  FreeAndNil(FPoseCatalog);
  Model := FPmxSelector.SelectedModel;
  if Assigned(FCatalog) and Assigned(Model) then
  begin
    ModelFolder := FCatalog.ModelFolder(Model.Id);
    FPoseCatalog := TPmxPoseCatalogStorage.Create(ModelFolder,
      Model.Id, Model.DisplayName);
    FPoseCatalog.LoadOrCreateDefault;
    FPoseGroups := TPmxPoseCatalogGroups.Create(ModelFolder);
    FPoseGroups.LoadFromFile;
    if FPoseGroups.RemoveUnknownPoses(FPoseCatalog) then
      FPoseGroups.SaveToFile;
  end;
  FPoseListView.SetData(Model, FPoseCatalog, FPoseGroups);
  FPoseGroupBar.SetGroups(FPoseGroups);
  FPoseToolbar.SetCatalog(FPoseCatalog);
  FPoseDrag.SetData(Model, FPoseCatalog);
  if Assigned(FOnPmxSelectionChanged) then FOnPmxSelectionChanged(Self);
end;

procedure TFrameMmdPoseCatalog.PoseListDblClick(Sender: TObject);
var
  Index: Integer;
  Model: TPmxCatalogItem;
  OldPoseData: string;
  Pose: TPmxPoseCatalogItem;
begin
  if not Assigned(FCatalog) or not Assigned(FPoseCatalog) then Exit;
  Index := FPoseListView.SelectedSourceIndex;
  Model := FPmxSelector.SelectedModel;
  if not Assigned(Model) or (Index < 0) or
    (Index >= FPoseCatalog.Count) then Exit;
  Pose := FPoseCatalog[Index];
  OldPoseData := Pose.PoseData;
  try
    if Assigned(FOnEditPose) then
    begin
      if not FOnEditPose(Self, Model, Pose) then Exit;
    end
    else if not EditPmxPoseCatalogPose(Model, Pose) then
      Exit;
    if not FPoseCatalog.SaveToFile then
    begin
      Pose.PoseData := OldPoseData;
      raise EInOutError.Create(
        #$30DD#$30FC#$30BA#$30C7#$30FC#$30BF#$3092#$4FDD#$5B58#$3067#$304D#$307E#$305B#$3093#$3067#$3057#$305F);
    end;
    FPoseListView.Reload;
  except
    on E: Exception do
    begin
      Pose.PoseData := OldPoseData;
      MessageBox(Handle, PChar(E.Message),
        #$004D#$004D#$0044' '#$30DD#$30FC#$30BA#$7DE8#$96C6,
        MB_OK or MB_ICONERROR);
    end;
  end;
end;

procedure TFrameMmdPoseCatalog.Resize;
begin
  inherited;
  ApplyDpiLayout;
end;

procedure TFrameMmdPoseCatalog.SelectPmxId(const PmxId: string);
begin
  FPmxSelector.SelectPmxId(PmxId);
end;

function TFrameMmdPoseCatalog.ImportVpdFiles(const Files: TArray<string>;
  const VpdRoot: string): Boolean;
var
  Summary: TMmdVpdImportSummary;
begin
  Result := ImportMmdVpdPoses(Files, VpdRoot, FPoseCatalog,
    FPoseGroups, Summary);
  if not Result then Exit;
  FPoseGroupBar.Combo.ItemIndex := 0;
  FPoseListView.SetGroupIndex(-1);
  FPoseListView.Reload;
  FPoseListView.SelectPoseId(Summary.LastPoseId);
  FPoseGroupBar.Rebuild;
end;

procedure TFrameMmdPoseCatalog.ReuseVpd(Sender: TObject);
var
  Files: TArray<string>;
  Model: TPmxCatalogItem;
  Root: string;
begin
  Model := FPmxSelector.SelectedModel;
  if not Assigned(Model) or not Assigned(FPoseCatalog) then Exit;
  Root := ExcludeTrailingPathDelimiter(GetAppFolder('VPD'));
  if SelectReusableVpdPoses(Self, Model, FPoseCatalog, Root, Files) then
    ImportVpdFiles(Files, Root);
end;

procedure TFrameMmdPoseCatalog.SetCatalog(ACatalog: TPmxCatalogStorage);
begin
  if FCatalog = ACatalog then
  begin
    FPmxSelector.Reload;
    Exit;
  end;
  FCatalog := ACatalog;
  FPmxSelector.SetCatalog(FCatalog);
end;

procedure TFrameMmdPoseCatalog.Show;
begin
  ApplyDpiLayout;
  FPmxSelector.Reload;
  PmxSelectionChanged(FPmxSelector);
  inherited Show;
end;

end.
