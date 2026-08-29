unit PmxCatalogFrame;
// PMX管理ページの表示と、PMXファイル受信イベントの境界を担当する。
interface
uses
  System.Classes,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.Forms,
  Vcl.StdCtrls,
  PmxCatalogStorage,
  PmxCatalogCharacterFilter,
  PmxCatalogContextMenu,
  PmxCatalogListView,
  PmxPoseCatalogStorage,
  PmxPoseCatalogListView,
  PmxPoseCatalogEditor,
  DragAgent,
  PmxCatalogThumbnailCache,
  PmxCatalogThumbnailRenderer;
type
  TPmxCatalogFilesDroppedEvent = procedure(Sender: TObject; const Files: TArray<string>) of object;
  TFramePmxCatalog = class(TFrame)
    PanelHeader: TPanel;
    LabelTitle: TLabel;
    LabelDropHint: TLabel;
    LabelDropStatus: TLabel;
  private
    FCatalog: TPmxCatalogStorage;
    FCatalogContextMenu: TPmxCatalogContextMenu;
    FCharacterCombo: TPmxCatalogCharacterCombo;
    FCatalogListView: TPmxCatalogListView;
    FDivider: TSplitter;
    FLeftPanel: TPanel;
    FPoseCatalog: TPmxPoseCatalogStorage;
    FPoseCatalogListView: TPmxPoseCatalogListView;
    FPoseThumbnailCache: TPmxCatalogThumbnailCache;
    FRightPanel: TPanel;
    FPoseDrag: TDragShellFile;
    FDragAliasFileName: string;
    FDropEventCount: Integer;
    FLastDroppedFile: string;
    FOnFilesDropped: TPmxCatalogFilesDroppedEvent;
    FThumbnailCache: TPmxCatalogThumbnailCache;
    FThumbnailRenderer: TPmxCatalogThumbnailRenderer;
    FLayoutPPI: Integer;
    procedure ApplyDpiLayout;
    procedure CharacterComboChanged(Sender: TObject);
    procedure CatalogSelectionChanged(Sender: TObject);
    function PoseDragCanStart(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer): Boolean;
    procedure PoseDragRequest(Sender: TObject; FileNames: TStringList);
    procedure PoseListDblClick(Sender: TObject);
    procedure DoFilesDropped(const Files: TArray<string>);
    procedure RefreshList;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // PMXファイルだけを受理し、受信表示を更新してOnFilesDroppedを通知する。
    function DropFiles(const Files: TArray<string>): Boolean;
    // 指定した永続化ファイルを読み直す。通常は既定のPMX管理ファイルを使用する。
    procedure OpenCatalog(const FileName: string);
    procedure Resize; override;
    procedure Show; reintroduce;
    property Catalog: TPmxCatalogStorage read FCatalog;
    property CharacterCombo: TPmxCatalogCharacterCombo read FCharacterCombo;
    property CatalogListView: TPmxCatalogListView read FCatalogListView;
    property PoseCatalog: TPmxPoseCatalogStorage read FPoseCatalog;
    property PoseCatalogListView: TPmxPoseCatalogListView read FPoseCatalogListView;
    property DropEventCount: Integer read FDropEventCount;
    property LastDroppedFile: string read FLastDroppedFile;
    property OnFilesDropped: TPmxCatalogFilesDroppedEvent read FOnFilesDropped
      write FOnFilesDropped;
  end;
implementation
uses
  Winapi.Windows,
  System.IOUtils,
  System.SysUtils,
  System.Types,
  Vcl.Graphics,
  AppFolderUtils,
  PmxPoseCatalogDragAlias;

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
  if not Assigned(FLeftPanel) or not Assigned(FDivider) or
    not Assigned(FCatalogListView) or not Assigned(FPoseCatalogListView) then
    Exit;
  // AviUtl2の親フレームと子コントロールでCurrentPPIが異なる場合があるため、
  // 実際に寸法を描画する一覧コントロールのDPIへ統一する。
  PPI := FCatalogListView.CurrentPPI;
  if (PPI <= 0) or (FLayoutPPI = PPI) then
    Exit;

  FLayoutPPI := PPI;
  // AviUtl2のドッキング領域は既に実表示座標なので、外枠とベベル幅を
  // さらにDPI拡大しない。内部サムネイル寸法だけを下で拡大する。
  FLeftPanel.Width := PmxListPaneWidth;
  FDivider.Width := PmxDividerWidth;
  FDivider.Left := FLeftPanel.Width;

  ThumbnailSize := MulDiv(PmxThumbnailSize, PPI, 96);
  FCatalogListView.ImageSize := ThumbnailSize;
  FCatalogListView.RowHeight := ThumbnailSize +
    MulDiv(PmxCaptionAreaHeight, PPI, 96);
  FPoseCatalogListView.ImageSize := ThumbnailSize;
  FPoseCatalogListView.RowHeight := ThumbnailSize +
    MulDiv(PmxCaptionAreaHeight, PPI, 96);
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

  FLeftPanel := TPanel.Create(Self);
  FLeftPanel.Parent := Self;
  FLeftPanel.Align := alLeft;
  FLeftPanel.Width := PmxListPaneWidth;
  FLeftPanel.BevelOuter := bvNone;
  FLeftPanel.ParentBackground := False;
  FLeftPanel.Color := Color;

  FDivider := TSplitter.Create(Self);
  FDivider.Parent := Self;
  FDivider.Align := alLeft;
  FDivider.Width := PmxDividerWidth;
  FDivider.Beveled := True;
  FDivider.Left := FLeftPanel.Width;

  FRightPanel := TPanel.Create(Self);
  FRightPanel.Parent := Self;
  FRightPanel.Align := alClient;
  FRightPanel.BevelOuter := bvNone;
  FRightPanel.ParentBackground := False;
  FRightPanel.Color := Color;

  FCharacterCombo := TPmxCatalogCharacterCombo.Create(Self);
  FCharacterCombo.Parent := FLeftPanel;
  FCharacterCombo.Align := alTop;
  FCharacterCombo.OnChange := CharacterComboChanged;

  FPoseCatalogListView := TPmxPoseCatalogListView.Create(Self);
  FPoseCatalogListView.Parent := FRightPanel;
  FPoseCatalogListView.Align := alClient;
  FPoseCatalogListView.SetThumbnailServices(FPoseThumbnailCache,
    FThumbnailRenderer);
  FPoseCatalogListView.OnDblClick := PoseListDblClick;

  FCatalogListView := TPmxCatalogListView.Create(Self);
  FCatalogListView.Parent := FLeftPanel;
  FCatalogListView.Align := alClient;
  FCatalogListView.SetThumbnailServices(FThumbnailCache,
    FThumbnailRenderer);

  FCatalogListView.OnSelectionChanged := CatalogSelectionChanged;
  FCatalogListView.SetCatalog(FCatalog);
  FCatalogContextMenu := TPmxCatalogContextMenu.Create(FCatalogListView,
    FPoseCatalogListView, FThumbnailCache, FPoseThumbnailCache);
  FCatalogContextMenu.SetCatalog(FCatalog);
  FCatalogContextMenu.OnChanged := RefreshList;

  FDragAliasFileName := GetAppFolder('Temp') + 'PmxPose-' +
    IntToHex(NativeUInt(Self), SizeOf(Pointer) * 2) + '.object';
  FPoseDrag := TDragShellFile.Create(Self);
  FPoseDrag.Attach(FPoseCatalogListView);
  FPoseDrag.OnCanStart := PoseDragCanStart;
  FPoseDrag.OnDragRequest := PoseDragRequest;
  ApplyDpiLayout;
  RefreshList;
end;

destructor TFramePmxCatalog.Destroy;
begin
  if Assigned(FPoseDrag) then
    FPoseDrag.Detach;
  FPoseDrag.Free;
  try
    if TFile.Exists(FDragAliasFileName) then
      TFile.Delete(FDragAliasFileName);
  except
    { 一時エイリアスの後始末失敗は終了処理へ影響させない。 }
  end;
  FCatalogContextMenu.Free;
  FPoseCatalogListView.Free;
  FCatalogListView.Free;
  FPoseCatalog.Free;
  FThumbnailRenderer.Free;
  FPoseThumbnailCache.Free;
  FThumbnailCache.Free;
  FCatalog.Free;
  inherited;
end;

procedure TFramePmxCatalog.CharacterComboChanged(Sender: TObject);
begin
  FCatalogListView.SetCharacterFilter(FCharacterCombo.Text);
  if FCatalogListView.DisplayCount > 0 then
    FCatalogListView.ItemIndex := 0
  else
    FCatalogListView.ItemIndex := -1;
  CatalogSelectionChanged(FCatalogListView);
end;

function TFramePmxCatalog.PoseDragCanStart(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer): Boolean;
var
  Index: Integer;
  Model: TPmxCatalogItem;
  Pose: TPmxPoseCatalogItem;
begin
  Result := False;
  if (Button <> mbLeft) or not Assigned(FCatalog) or
    not Assigned(FPoseCatalog) then
    Exit;
  Index := FPoseCatalogListView.ItemAtPos(Point(X, Y));
  if (Index < 0) or (Index >= FPoseCatalog.Count) or
    (Index <> FPoseCatalogListView.ItemIndex) or
    (FCatalogListView.SelectedSourceIndex < 0) or
    (FCatalogListView.SelectedSourceIndex >= FCatalog.Count) then
    Exit;
  Model := FCatalog.Items[FCatalogListView.SelectedSourceIndex];
  Pose := FPoseCatalog[Index];
  Result := TryWritePmxPoseObjectAlias(Model.SourcePath, Pose.PoseData,
    Pose.InitialExpressionData, Pose.InitialEyeBlinkData,
    Pose.InitialLipSyncData,
    FDragAliasFileName);
end;

procedure TFramePmxCatalog.PoseDragRequest(Sender: TObject;
  FileNames: TStringList);
begin
  FileNames.Clear;
  if TFile.Exists(FDragAliasFileName) then
    FileNames.Add(FDragAliasFileName);
end;

procedure TFramePmxCatalog.CatalogSelectionChanged(Sender: TObject);
var
  Index: Integer;
  Model: TPmxCatalogItem;
begin
  FreeAndNil(FPoseCatalog);
  Model := nil;
  Index := FCatalogListView.SelectedSourceIndex;
  if Assigned(FCatalog) and (Index >= 0) and (Index < FCatalog.Count) then
  begin
    Model := FCatalog.Items[Index];
    FPoseCatalog := TPmxPoseCatalogStorage.Create(
      FCatalog.ModelFolder(Model.Id), Model.Id, Model.DisplayName);
    FPoseCatalog.LoadOrCreateDefault;
  end;
  FPoseCatalogListView.SetData(Model, FPoseCatalog);
end;

procedure TFramePmxCatalog.PoseListDblClick(Sender: TObject);
var
  Index: Integer;
  Model: TPmxCatalogItem;
  OldInitialExpressionData: string;
  OldPoseData: string;
  Pose: TPmxPoseCatalogItem;
begin
  if not Assigned(FCatalog) or not Assigned(FPoseCatalog) then
    Exit;
  Index := FPoseCatalogListView.ItemIndex;
  if (Index < 0) or (Index >= FPoseCatalog.Count) or
    (FCatalogListView.SelectedSourceIndex < 0) or
    (FCatalogListView.SelectedSourceIndex >= FCatalog.Count) then
    Exit;
  Model := FCatalog.Items[FCatalogListView.SelectedSourceIndex];
  Pose := FPoseCatalog[Index];
  OldInitialExpressionData := Pose.InitialExpressionData;
  OldPoseData := Pose.PoseData;
  try
    if not EditPmxPoseCatalogItem(Model, Pose) then
      Exit;
    if not FPoseCatalog.SaveToFile then
    begin
      Pose.InitialExpressionData := OldInitialExpressionData;
      Pose.PoseData := OldPoseData;
      raise EInOutError.Create(
        #$30DD#$30FC#$30BA#$30C7#$30FC#$30BF#$3092#$4FDD#$5B58#$3067#$304D#$307E#$305B#$3093#$3067#$3057#$305F);
    end;
    FPoseCatalogListView.Reload;
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
  FCatalogListView.SetCatalog(FCatalog);
  FCatalogContextMenu.SetCatalog(FCatalog);
  RefreshList;
end;

procedure TFramePmxCatalog.RefreshList;
begin
  PanelHeader.Visible := FCatalog.Count = 0;
  FLeftPanel.Visible := FCatalog.Count > 0;
  FDivider.Visible := FCatalog.Count > 0;
  FRightPanel.Visible := FCatalog.Count > 0;
  // TComboBox.Itemsはハンドルを要求するため、フレームの親接続後だけ候補を構築する。
  if Assigned(Parent) then
  begin
    FCharacterCombo.Rebuild(FCatalog);
    FCatalogListView.SetCharacterFilter(FCharacterCombo.Text);
  end
  else
    FCatalogListView.SetCharacterFilter(PmxCatalogAllCharactersCaption);
  FCatalogListView.Reload;
  if (FCatalogListView.DisplayCount > 0) and Assigned(Parent) then
  begin
    if FCatalogListView.ItemIndex < 0 then
      FCatalogListView.ItemIndex := 0;
    CatalogSelectionChanged(FCatalogListView);
  end
  else if FCatalog.Count = 0 then
    CatalogSelectionChanged(FCatalogListView);
end;

procedure TFramePmxCatalog.Resize;
begin
  inherited;
  ApplyDpiLayout;
end;

procedure TFramePmxCatalog.Show;
begin
  ApplyDpiLayout;
  RefreshList;
  inherited Show;
end;

end.
