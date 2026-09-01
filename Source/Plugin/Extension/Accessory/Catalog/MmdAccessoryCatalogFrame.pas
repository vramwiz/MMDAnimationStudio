unit MmdAccessoryCatalogFrame;

// アクセサリページの保存層を所有し、PMXドロップの登録結果を表示する。

interface

uses
  System.Classes,
  Vcl.Controls,
  Vcl.Forms,
  DarkPanel,
  DarkLabel,
  MmdAccessoryCatalog,
  MmdAccessoryCatalogListView,
  MmdAccessoryCatalogToolbar,
  MmdAccessoryCatalogContextMenu,
  MmdAccessoryObjectDragController,
  PmxCatalogThumbnailCache,
  PmxCatalogThumbnailRenderer,
  MmdAccessoryPmxImporter,
  MmdAccessoryImporter;

type
  TFrameMmdAccessoryCatalog = class(TFrame)
    LabelDropHint: TDarkLabel;
    LabelDropStatus: TDarkLabel;
    LabelTitle: TDarkLabel;
    PanelHeader: TDarkPanel;
  private
    FCatalog: TMmdAccessoryCatalog;
    FContextMenu: TMmdAccessoryCatalogContextMenu;
    FDragController: TMmdAccessoryObjectDragController;
    FListView: TMmdAccessoryCatalogListView;
    FLastSummary: TMmdAccessoryPmxImportSummary;
    FThumbnailCache: TPmxCatalogThumbnailCache;
    FThumbnailRenderer: TPmxCatalogThumbnailRenderer;
    FToolbar: TMmdAccessoryCatalogToolbar;
    procedure AddAccessory(Sender: TObject);
    procedure ShowSummary;
    procedure UpdateEmptyState(Sender: TObject = nil);
  public
    // 共有アプリフォルダのAccessoriesカタログを読み込み、空ページを初期化する。
    constructor Create(AOwner: TComponent); override;
    // D&D、一覧、描画サービス、保存層の順にページ資源を切り離して解放する。
    destructor Destroy; override;
    // PMX単体・複数・フォルダを検証して登録し、集計を状態欄へ反映する。
    procedure DropFiles(const Files: TArray<string>);
    // ページ内で所有する保存層と操作用UIを、テストや親画面から参照する。
    property Catalog: TMmdAccessoryCatalog read FCatalog;
    property ListView: TMmdAccessoryCatalogListView read FListView;
    property LastSummary: TMmdAccessoryPmxImportSummary read FLastSummary;
    property Toolbar: TMmdAccessoryCatalogToolbar read FToolbar;
  end;

implementation

uses
  System.IOUtils,
  System.SysUtils,
  Vcl.Dialogs,
  AppFolderUtils;

{$R *.dfm}

constructor TFrameMmdAccessoryCatalog.Create(AOwner: TComponent);
var
  Root: string;
begin
  inherited;
  FThumbnailRenderer := TPmxCatalogThumbnailRenderer.Create(Self);
  FThumbnailRenderer.Parent := Self;
  FListView := TMmdAccessoryCatalogListView.Create(Self);
  FListView.Parent := Self;
  FListView.Align := alClient;
  FDragController := TMmdAccessoryObjectDragController.Create(Self, FListView);
  FToolbar := TMmdAccessoryCatalogToolbar.Create(Self, FListView);
  FToolbar.Parent := Self;
  FToolbar.Align := alTop;
  FToolbar.Top := PanelHeader.Height;
  FToolbar.OnAddAccessory := AddAccessory;
  FToolbar.OnChanged := UpdateEmptyState;
  FContextMenu := TMmdAccessoryCatalogContextMenu.Create(FToolbar);
  Root := GetAppFolder('Accessories');
  if Root = '' then
  begin
    LabelDropStatus.Caption :=
      #$30A2#$30AF#$30BB#$30B5#$30EA#$4FDD#$5B58#$5148#$3092#$521D#$671F#$5316#$3067#$304D#$307E#$305B#$3093#$3067#$3057#$305F;
    Exit;
  end;
  FCatalog := TMmdAccessoryCatalog.Create(ExcludeTrailingPathDelimiter(Root));
  FThumbnailCache := TPmxCatalogThumbnailCache.Create(
    TPath.Combine(Root, 'Cache\Accessory'));
  FListView.SetThumbnailServices(FThumbnailCache, FThumbnailRenderer);
  FListView.SetCatalog(FCatalog);
  FDragController.SetCatalog(FCatalog);
  FToolbar.SetCatalog(FCatalog);
  if FCatalog.LoadFromFile then
  begin
    FListView.Reload;
    LabelDropStatus.Caption := Format('登録済み: %d件', [FCatalog.Count]);
  end
  else
    LabelDropStatus.Caption := 'アクセサリカタログを読み込めませんでした';
  UpdateEmptyState;
end;

destructor TFrameMmdAccessoryCatalog.Destroy;
begin
  FContextMenu.Free;
  FDragController.Free;
  FToolbar.Free;
  FListView.Free;
  FThumbnailRenderer.Free;
  FThumbnailCache.Free;
  FCatalog.Free;
  inherited;
end;

procedure TFrameMmdAccessoryCatalog.AddAccessory(Sender: TObject);
var
  Dialog: TOpenDialog;
begin
  Dialog := TOpenDialog.Create(Self);
  try
    Dialog.Filter := 'アクセサリ (*.pmx;*.obj)|*.pmx;*.obj|PMX (*.pmx)|*.pmx|OBJ (*.obj)|*.obj';
    Dialog.Options := Dialog.Options + [ofAllowMultiSelect, ofFileMustExist];
    if Dialog.Execute then DropFiles(Dialog.Files.ToStringArray);
  finally
    Dialog.Free;
  end;
end;

procedure TFrameMmdAccessoryCatalog.DropFiles(const Files: TArray<string>);
begin
  try
    ImportMmdAccessoryFiles(Files, FCatalog, FLastSummary);
    if Assigned(FListView) then
    begin
      FListView.Reload;
      if FLastSummary.LastAccessoryId <> '' then
        FListView.SelectItemId(FLastSummary.LastAccessoryId);
    end;
    ShowSummary;
    UpdateEmptyState;
  except
    FLastSummary := Default(TMmdAccessoryPmxImportSummary);
    FLastSummary.Failed := Length(Files);
    LabelDropStatus.Caption := 'アクセサリの登録中にエラーが発生しました';
  end;
end;

procedure TFrameMmdAccessoryCatalog.UpdateEmptyState(Sender: TObject);
begin
  PanelHeader.Visible := not Assigned(FCatalog) or (FCatalog.Count = 0);
  if PanelHeader.Visible then FToolbar.Top := PanelHeader.Height
  else FToolbar.Top := 0;
end;

procedure TFrameMmdAccessoryCatalog.ShowSummary;
begin
  LabelDropStatus.Caption := '確認 ' + IntToStr(FLastSummary.Scanned) +
    '件 / 追加 ' + IntToStr(FLastSummary.Added) +
    '件 / 登録済み ' + IntToStr(FLastSummary.AlreadyRegistered) +
    '件 / 失敗 ' + IntToStr(FLastSummary.Failed) +
    '件 / ボーンなし ' + IntToStr(FLastSummary.WithoutBones) +
    '件 / ボーンあり ' + IntToStr(FLastSummary.WithBones) +
    '件 / 素材不足 ' + IntToStr(FLastSummary.MissingDependencies) + '件';
end;

end.
