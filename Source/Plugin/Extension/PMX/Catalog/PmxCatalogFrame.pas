unit PmxCatalogFrame;
// PMX管理ページの表示と、PMXファイル受信イベントの境界を担当する。
interface
uses
  System.Classes,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.Forms,
  Vcl.StdCtrls,
  DarkLabel,
  DarkPanel,
  PmxCatalogStorage,
  PmxCatalogCharacterFilter,
  PmxCatalogContextMenu,
  PmxCatalogSelector,
  PmxCatalogListView,
  PmxPoseCatalogStorage,
  PmxPoseCatalogGroups,
  PmxPoseCatalogGroupBar,
  PmxPoseCatalogListView,
  PmxPoseCatalogContextMenu,
  PmxPoseCatalogDragController,
  PmxPoseCatalogToolbar,
  PmxCatalogThumbnailCache,
  PmxCatalogThumbnailRenderer;
type
  TPmxCatalogFilesDroppedEvent = procedure(Sender: TObject; const Files: TArray<string>) of object;
  TFramePmxCatalog = class(TFrame)
    PanelHeader: TDarkPanel;
    LabelTitle: TDarkLabel;
    LabelDropHint: TDarkLabel;
    LabelDropStatus: TDarkLabel;
  private
    FCatalog: TPmxCatalogStorage;
    FCatalogContextMenu: TPmxCatalogContextMenu;
    FPmxSelector: TPmxCatalogSelector;
    FDivider: TSplitter;
    FPoseCatalog: TPmxPoseCatalogStorage;
    FPoseGroups: TPmxPoseCatalogGroups;
    FPoseGroupBar: TPmxPoseCatalogGroupBar;
    FPoseCatalogContextMenu: TPmxPoseCatalogContextMenu;
    FPoseCatalogListView: TPmxPoseCatalogListView;
    FPoseCatalogToolbar: TPmxPoseCatalogToolbar;
    FPoseThumbnailCache: TPmxCatalogThumbnailCache;
    FRightPanel: TDarkPanel;
    FPoseDrag: TPmxPoseCatalogDragController;
    FDropEventCount: Integer;
    FLastDroppedFile: string;
    FOnFilesDropped: TPmxCatalogFilesDroppedEvent;
    FOnPmxSelectionChanged: TNotifyEvent;
    FThumbnailCache: TPmxCatalogThumbnailCache;
    FThumbnailRenderer: TPmxCatalogThumbnailRenderer;
    FLayoutPPI: Integer;
    procedure ApplyDpiLayout;
    function GetCatalogListView: TPmxCatalogListView;
    function GetCharacterCombo: TPmxCatalogCharacterCombo;
    procedure CatalogSelectionChanged(Sender: TObject);
    procedure PoseListDblClick(Sender: TObject);
    procedure ReuseVpd(Sender: TObject);
    procedure DoFilesDropped(const Files: TArray<string>);
    procedure RefreshList;
  public
    // PMX一覧、ポーズ一覧、操作部品、キャッシュを生成してPMX管理画面を構成する。
    constructor Create(AOwner: TComponent); override;
    // D&D、一時ポーズ、一覧、キャッシュの順に画面固有資源を解放する。
    destructor Destroy; override;
    // PMXファイルだけを受理し、受信表示を更新してOnFilesDroppedを通知する。
    function DropFiles(const Files: TArray<string>): Boolean;
    // VPDまたはフォルダを共通保管し、選択中PMXのポーズへ登録する。
    function ImportVpdFiles(const Files: TArray<string>; const VpdRoot: string = ''): Boolean;
    // 指定した永続化ファイルを読み直す。通常は既定のPMX管理ファイルを使用する。
    procedure OpenCatalog(const FileName: string);
    // AviUtl2のドッキング幅変更に合わせて一覧寸法を再適用する。
    procedure Resize; override;
    // 親接続後にDPI寸法と保存済みカタログを画面へ反映する。
    procedure Show; reintroduce;
    property Catalog: TPmxCatalogStorage read FCatalog;
    property CharacterCombo: TPmxCatalogCharacterCombo read GetCharacterCombo;
    property CatalogListView: TPmxCatalogListView read GetCatalogListView;
    property PoseCatalog: TPmxPoseCatalogStorage read FPoseCatalog;
    property PoseGroups: TPmxPoseCatalogGroups read FPoseGroups;
    property PoseGroupBar: TPmxPoseCatalogGroupBar read FPoseGroupBar;
    property PoseCatalogListView: TPmxPoseCatalogListView read FPoseCatalogListView;
    property DropEventCount: Integer read FDropEventCount;
    property LastDroppedFile: string read FLastDroppedFile;
    property OnFilesDropped: TPmxCatalogFilesDroppedEvent read FOnFilesDropped
      write FOnFilesDropped;
    property OnPmxSelectionChanged: TNotifyEvent read FOnPmxSelectionChanged
      write FOnPmxSelectionChanged;
    // PmxUIDに対応する左一覧の項目を選択する。
    procedure SelectPmxId(const PmxId: string);
    // 現在選択中のPmxUIDを返す。
    function SelectedPmxId: string;
  end;
implementation
uses
  Winapi.Windows,
  System.SysUtils,
  Vcl.Graphics,
  AppFolderUtils,
  MmdVpdPoseImporter,
  MmdVpdReuseForm,
  PmxPoseCatalogEditSession;
{$R *.dfm}
const
  PmxDropEventCaption = 'PMX'#$30C9#$30ED#$30C3#$30D7#$30A4#$30D9#$30F3#$30C8#$767A#$706B;
  PmxListPaneWidth = 105;
  PmxDividerWidth = 3;
  PmxThumbnailSize = 64;
  PmxCaptionAreaHeight = 28;
procedure TFramePmxCatalog.ApplyDpiLayout;
var
  PPI: Integer;
  ThumbnailSize: Integer;
begin
  if not Assigned(FPmxSelector) or not Assigned(FDivider) or
    not Assigned(FPoseCatalogListView) then
    Exit;
  // AviUtl2の親フレームと子コントロールでCurrentPPIが異なる場合があるため、
  // 実際に寸法を描画する一覧コントロールのDPIへ統一する。
  PPI := FPmxSelector.ListView.CurrentPPI;
  if (PPI <= 0) or (FLayoutPPI = PPI) then
    Exit;
  FLayoutPPI := PPI;
  // AviUtl2のドッキング領域は既に実表示座標なので、外枠とベベル幅を
  // さらにDPI拡大しない。内部サムネイル寸法だけを下で拡大する。
  FPmxSelector.Width := PmxListPaneWidth;
  FDivider.Width := PmxDividerWidth;
  FDivider.Left := FPmxSelector.Width;
  ThumbnailSize := MulDiv(PmxThumbnailSize, PPI, 96);
  FPmxSelector.ListView.ImageSize := ThumbnailSize;
  FPmxSelector.ListView.RowHeight := ThumbnailSize +
    MulDiv(PmxCaptionAreaHeight, PPI, 96);
  FPoseCatalogListView.ImageSize := ThumbnailSize;
  FPoseCatalogListView.RowHeight := ThumbnailSize +
    MulDiv(PmxCaptionAreaHeight, PPI, 96);
end;

function TFramePmxCatalog.GetCatalogListView: TPmxCatalogListView;
begin
  Result := FPmxSelector.ListView;
end;

function TFramePmxCatalog.GetCharacterCombo: TPmxCatalogCharacterCombo;
begin
  Result := FPmxSelector.CharacterCombo;
end;

constructor TFramePmxCatalog.Create(AOwner: TComponent);
var
  PmxFolder: string;
begin
  inherited;
  PmxFolder := GetAppFolder('PMX');
  FCatalog := TPmxCatalogStorage.Create(PmxFolder + 'Catalog.json',
    PmxFolder + 'PmxCatalog.txt');
  FCatalog.LoadFromFile;
  FThumbnailCache := TPmxCatalogThumbnailCache.Create(PmxFolder + 'Cache\Model');
  FPoseThumbnailCache := TPmxCatalogThumbnailCache.Create(PmxFolder + 'Cache\Pose');
  FThumbnailRenderer := TPmxCatalogThumbnailRenderer.Create(Self);
  FThumbnailRenderer.Parent := Self;
  FPmxSelector := TPmxCatalogSelector.Create(Self);
  FPmxSelector.Parent := Self;
  FPmxSelector.Width := PmxListPaneWidth;
  FPmxSelector.Color := Color;
  FPmxSelector.SetThumbnailServices(FThumbnailCache, FThumbnailRenderer);
  FPmxSelector.OnSelectionChanged := CatalogSelectionChanged;
  FDivider := TSplitter.Create(Self);
  FDivider.Parent := Self;
  FDivider.Align := alLeft;
  FDivider.Width := PmxDividerWidth;
  FDivider.Beveled := True;
  FDivider.Left := FPmxSelector.Width;
  FRightPanel := TDarkPanel.Create(Self);
  FRightPanel.Parent := Self;
  FRightPanel.Align := alClient;
  FRightPanel.BevelOuter := bvNone;
  FRightPanel.ParentBackground := False;
  FRightPanel.Color := Color;
  FPoseCatalogListView := TPmxPoseCatalogListView.Create(Self);
  FPoseCatalogListView.Parent := FRightPanel;
  FPoseCatalogListView.Align := alClient;
  FPoseCatalogListView.SetThumbnailServices(FPoseThumbnailCache, FThumbnailRenderer);
  FPoseCatalogListView.OnDblClick := PoseListDblClick;

  FPmxSelector.SetCatalog(FCatalog);
  FPoseCatalogToolbar := TPmxPoseCatalogToolbar.Create(Self, FPoseCatalogListView);
  FPoseCatalogToolbar.Parent := FRightPanel;
  FPoseCatalogToolbar.Align := alTop;
  FPoseGroupBar := TPmxPoseCatalogGroupBar.Create(Self, FRightPanel, FPoseCatalogListView);
  FPoseGroupBar.Bar.Top := 0;
  FPoseCatalogToolbar.Top := FPoseGroupBar.Bar.Height;
  FPoseCatalogContextMenu := TPmxPoseCatalogContextMenu.Create(FPoseCatalogToolbar);
  FPoseCatalogContextMenu.OnReuseVpd := ReuseVpd;
  FCatalogContextMenu := TPmxCatalogContextMenu.Create(FPmxSelector.ListView,
    FPoseCatalogListView, FThumbnailCache, FPoseThumbnailCache);
  FCatalogContextMenu.SetCatalog(FCatalog);
  FCatalogContextMenu.OnChanged := RefreshList;

  FPoseDrag := TPmxPoseCatalogDragController.Create(Self, FPmxSelector.ListView, FPoseCatalogListView);
  ApplyDpiLayout;
  RefreshList;
end;

destructor TFramePmxCatalog.Destroy;
begin
  FPoseDrag.Free;
  FCatalogContextMenu.Free;
  FPoseCatalogContextMenu.Free;
  FPoseGroupBar.Free;
  FPoseCatalogToolbar.Free;
  FPoseCatalogListView.Free;
  FPmxSelector.Free;
  FPoseGroups.Free;
  FPoseCatalog.Free;
  FThumbnailRenderer.Free;
  FPoseThumbnailCache.Free;
  FThumbnailCache.Free;
  FCatalog.Free;
  inherited;
end;

procedure TFramePmxCatalog.CatalogSelectionChanged(Sender: TObject);
var
  Index: Integer;
  Model: TPmxCatalogItem;
  ModelFolder: string;
begin
  FPoseCatalogToolbar.SetCatalog(nil);
  FPoseGroupBar.SetGroups(nil);
  FPoseCatalogListView.SetData(nil, nil, nil);
  FreeAndNil(FPoseGroups);
  FreeAndNil(FPoseCatalog);
  Model := nil;
  Index := FPmxSelector.ListView.SelectedSourceIndex;
  if Assigned(FCatalog) and (Index >= 0) and (Index < FCatalog.Count) then
  begin
    Model := FCatalog.Items[Index];
    ModelFolder := FCatalog.ModelFolder(Model.Id);
    FPoseCatalog := TPmxPoseCatalogStorage.Create(ModelFolder,
      Model.Id, Model.DisplayName);
    FPoseCatalog.LoadOrCreateDefault;
    FPoseGroups := TPmxPoseCatalogGroups.Create(ModelFolder);
    FPoseGroups.LoadFromFile;
    if FPoseGroups.RemoveUnknownPoses(FPoseCatalog) then
      FPoseGroups.SaveToFile;
  end;
  FPoseCatalogListView.SetData(Model, FPoseCatalog, FPoseGroups);
  FPoseGroupBar.SetGroups(FPoseGroups);
  FPoseCatalogToolbar.SetCatalog(FPoseCatalog);
  FPoseDrag.SetData(FCatalog, FPoseCatalog);
  if Assigned(FOnPmxSelectionChanged) then FOnPmxSelectionChanged(Self);
end;

procedure TFramePmxCatalog.PoseListDblClick(Sender: TObject);
var
  Index: Integer;
  Model: TPmxCatalogItem;
  Pose: TPmxPoseCatalogItem;
begin
  if not Assigned(FCatalog) or not Assigned(FPoseCatalog) then
    Exit;
  Index := FPoseCatalogListView.SelectedSourceIndex;
  if (Index < 0) or (Index >= FPoseCatalog.Count) or
    (FPmxSelector.ListView.SelectedSourceIndex < 0) or
    (FPmxSelector.ListView.SelectedSourceIndex >= FCatalog.Count) then
    Exit;
  Model := FCatalog.Items[FPmxSelector.ListView.SelectedSourceIndex];
  Pose := FPoseCatalog[Index];
  try
    if not EditAndSavePmxPoseCatalogItem(Model, Pose, FPoseCatalog) then
      Exit;
    // 編集前のPNGを物理的に破棄し、現在のポーズと初期表情から再生成する。
    // VariantKeyだけの変更では、一覧の再描画時機によって旧画像が残るため、
    // 確定操作ではポーズ用キャッシュ領域を明示的に無効化する。
    if not FPoseCatalogListView.RefreshThumbnails then
      raise EInOutError.Create(
        #$30B5#$30E0#$30CD#$30A4#$30EB#$3092#$66F4#$65B0#$3067#$304D#$307E#$305B#$3093#$3067#$3057#$305F);
  except
    on E: Exception do
      MessageBox(Handle, PChar(E.Message),
        #$004D#$004D#$0044' '#$30DD#$30FC#$30BA#$7DE8#$96C6,
        MB_OK or MB_ICONERROR);
  end;
end;

procedure TFramePmxCatalog.DoFilesDropped(const Files: TArray<string>);
begin
  Inc(FDropEventCount);
  FLastDroppedFile := ExtractFileName(Files[High(Files)]);
  LabelDropStatus.Caption := Format('%s: %d'#13#10'%s',
    [PmxDropEventCaption, Length(Files), FLastDroppedFile]);

  if Assigned(FOnFilesDropped) then
    FOnFilesDropped(Self, Files);
end;

function TFramePmxCatalog.DropFiles(const Files: TArray<string>): Boolean;
var
  AddedFiles: TArray<string>;
  FileName: string;
  AddedCount: Integer;
begin
  SetLength(AddedFiles, Length(Files));
  AddedCount := 0;
  for FileName in Files do
    if FCatalog.Add(FileName) then
    begin
      AddedFiles[AddedCount] := FileName;
      Inc(AddedCount);
    end;

  SetLength(AddedFiles, AddedCount);
  Result := AddedCount > 0;
  if Result then
  begin
    FCatalog.SaveToFile;
    RefreshList;
    DoFilesDropped(AddedFiles);
  end;
end;

procedure TFramePmxCatalog.OpenCatalog(const FileName: string);
begin
  FreeAndNil(FCatalog);
  FCatalog := TPmxCatalogStorage.Create(FileName);
  FCatalog.LoadFromFile;
  FPmxSelector.SetCatalog(FCatalog);
  FCatalogContextMenu.SetCatalog(FCatalog);
  RefreshList;
end;

function TFramePmxCatalog.ImportVpdFiles(const Files: TArray<string>; const VpdRoot: string): Boolean;
var
  Summary: TMmdVpdImportSummary;
begin
  Result := ImportMmdVpdPoses(Files, VpdRoot, FPoseCatalog,
    FPoseGroups, Summary);
  if not Result then Exit;
  FPoseGroupBar.Combo.ItemIndex := 0;
  FPoseCatalogListView.SetGroupIndex(-1);
  FPoseCatalogListView.Reload;
  FPoseCatalogListView.SelectPoseId(Summary.LastPoseId);
  FPoseGroupBar.Rebuild;
end;

procedure TFramePmxCatalog.ReuseVpd(Sender: TObject);
var
  Files: TArray<string>;
  Index: Integer;
  Model: TPmxCatalogItem;
  Root: string;
begin
  Index := FPmxSelector.ListView.SelectedSourceIndex;
  if not Assigned(FCatalog) or not Assigned(FPoseCatalog) or
    (Index < 0) or (Index >= FCatalog.Count) then Exit;
  Model := FCatalog.Items[Index];
  Root := ExcludeTrailingPathDelimiter(GetAppFolder('VPD'));
  if SelectReusableVpdPoses(Self, Model, FPoseCatalog, Root, Files) then
    ImportVpdFiles(Files, Root);
end;

procedure TFramePmxCatalog.RefreshList;
begin
  PanelHeader.Visible := FCatalog.Count = 0;
  FPmxSelector.Visible := FCatalog.Count > 0;
  FDivider.Visible := FCatalog.Count > 0;
  FRightPanel.Visible := FCatalog.Count > 0;
  FPmxSelector.Reload;
  if Assigned(Parent) then
    CatalogSelectionChanged(FPmxSelector.ListView);
end;
procedure TFramePmxCatalog.Resize;
begin
  inherited;
  ApplyDpiLayout;
end;

procedure TFramePmxCatalog.SelectPmxId(const PmxId: string);
begin
  FPmxSelector.SelectPmxId(PmxId);
end;

function TFramePmxCatalog.SelectedPmxId: string;
begin
  Result := FPmxSelector.SelectedPmxId;
end;

procedure TFramePmxCatalog.Show;
begin
  ApplyDpiLayout;
  RefreshList;
  inherited Show;
end;
end.
