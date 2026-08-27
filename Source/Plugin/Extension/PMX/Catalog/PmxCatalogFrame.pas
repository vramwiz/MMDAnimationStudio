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
  PmxCatalogListView,
  PmxPoseCatalogStorage,
  PmxPoseCatalogListView,
  PmxPoseCatalogEditor,
  PmxCatalogThumbnailCache,
  PmxCatalogThumbnailRenderer;

type
  TPmxCatalogFilesDroppedEvent = procedure(Sender: TObject;
    const Files: TArray<string>) of object;

  TFramePmxCatalog = class(TFrame)
    PanelHeader: TPanel;
    LabelTitle: TLabel;
    LabelDropHint: TLabel;
    LabelDropStatus: TLabel;
  private
    FCatalog: TPmxCatalogStorage;
    FCatalogListView: TPmxCatalogListView;
    FDivider: TPanel;
    FLeftPanel: TPanel;
    FPoseCatalog: TPmxPoseCatalogStorage;
    FPoseCatalogListView: TPmxPoseCatalogListView;
    FPoseThumbnailCache: TPmxCatalogThumbnailCache;
    FRightPanel: TPanel;
    FDropEventCount: Integer;
    FLastDroppedFile: string;
    FOnFilesDropped: TPmxCatalogFilesDroppedEvent;
    FThumbnailCache: TPmxCatalogThumbnailCache;
    FThumbnailRenderer: TPmxCatalogThumbnailRenderer;
    procedure CatalogSelectionChanged(Sender: TObject);
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
    procedure Show; reintroduce;
    property Catalog: TPmxCatalogStorage read FCatalog;
    property CatalogListView: TPmxCatalogListView read FCatalogListView;
    property PoseCatalog: TPmxPoseCatalogStorage read FPoseCatalog;
    property PoseCatalogListView: TPmxPoseCatalogListView
      read FPoseCatalogListView;
    property DropEventCount: Integer read FDropEventCount;
    property LastDroppedFile: string read FLastDroppedFile;
    property OnFilesDropped: TPmxCatalogFilesDroppedEvent
      read FOnFilesDropped write FOnFilesDropped;
  end;

implementation

uses
  Winapi.Windows,
  System.SysUtils,
  Vcl.Graphics,
  AppFolderUtils;

{$R *.dfm}

const
  PmxDropEventCaption = 'PMX'#$30C9#$30ED#$30C3#$30D7#$30A4#$30D9#$30F3#$30C8#$767A#$706B;
  PmxListPaneWidth = 128;

constructor TFramePmxCatalog.Create(AOwner: TComponent);
var
  PmxFolder: string;
begin
  inherited;
  PmxFolder := GetAppFolder('PMX');
  FCatalog := TPmxCatalogStorage.Create(
    PmxFolder + 'Catalog.json', PmxFolder + 'PmxCatalog.txt');
  FCatalog.LoadFromFile;

  FThumbnailCache := TPmxCatalogThumbnailCache.Create(
    PmxFolder + 'Cache\Model');
  FPoseThumbnailCache := TPmxCatalogThumbnailCache.Create(
    PmxFolder + 'Cache\Pose');
  FThumbnailRenderer := TPmxCatalogThumbnailRenderer.Create(Self);
  FThumbnailRenderer.Parent := Self;

  FRightPanel := TPanel.Create(Self);
  FRightPanel.Parent := Self;
  FRightPanel.Align := alClient;
  FRightPanel.BevelOuter := bvNone;
  FRightPanel.ParentBackground := False;
  FRightPanel.Color := Color;

  // VCLスタイルでTSplitterのColorが上書きされるため、固定幅のウィンドウを
  // 持つPanelを左右の境界として使用する。
  FDivider := TPanel.Create(Self);
  FDivider.Parent := Self;
  FDivider.Align := alLeft;
  FDivider.Width := 1;
  FDivider.BevelOuter := bvNone;
  FDivider.ParentBackground := False;
  FDivider.ParentColor := False;
  FDivider.Color := clWhite;
  FDivider.Enabled := False;

  FLeftPanel := TPanel.Create(Self);
  FLeftPanel.Parent := Self;
  FLeftPanel.Align := alLeft;
  FLeftPanel.Width := MulDiv(PmxListPaneWidth, CurrentPPI, 96);
  FLeftPanel.BevelOuter := bvNone;
  FLeftPanel.ParentBackground := False;
  FLeftPanel.Color := Color;

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
  RefreshList;
end;

destructor TFramePmxCatalog.Destroy;
begin
  FPoseCatalogListView.Free;
  FCatalogListView.Free;
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
begin
  FreeAndNil(FPoseCatalog);
  Model := nil;
  Index := FCatalogListView.ItemIndex;
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
  OldPoseData: string;
  Pose: TPmxPoseCatalogItem;
begin
  if not Assigned(FCatalog) or not Assigned(FPoseCatalog) then
    Exit;
  Index := FPoseCatalogListView.ItemIndex;
  if (Index < 0) or (Index >= FPoseCatalog.Count) or
    (FCatalogListView.ItemIndex < 0) or
    (FCatalogListView.ItemIndex >= FCatalog.Count) then
    Exit;
  Model := FCatalog.Items[FCatalogListView.ItemIndex];
  Pose := FPoseCatalog[Index];
  OldPoseData := Pose.PoseData;
  try
    if not EditPmxPoseCatalogItem(Model, Pose) then
      Exit;
    if not FPoseCatalog.SaveToFile then
    begin
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
  RefreshList;
end;

procedure TFramePmxCatalog.RefreshList;
begin
  PanelHeader.Visible := FCatalog.Count = 0;
  FLeftPanel.Visible := FCatalog.Count > 0;
  FDivider.Visible := FCatalog.Count > 0;
  FRightPanel.Visible := FCatalog.Count > 0;
  FCatalogListView.Reload;
  if (FCatalog.Count > 0) and Assigned(Parent) then
  begin
    if FCatalogListView.ItemIndex < 0 then
      FCatalogListView.ItemIndex := 0;
    CatalogSelectionChanged(FCatalogListView);
  end
  else if FCatalog.Count = 0 then
    CatalogSelectionChanged(FCatalogListView);
end;

procedure TFramePmxCatalog.Show;
begin
  RefreshList;
  inherited Show;
end;

end.
