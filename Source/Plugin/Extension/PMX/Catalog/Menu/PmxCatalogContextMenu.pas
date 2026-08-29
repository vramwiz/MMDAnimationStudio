unit PmxCatalogContextMenu;

// PMX一覧の右クリック操作と、確認・エラー表示の境界を担当する。

interface

uses
  System.Classes,
  Vcl.Menus,
  PmxCatalogStorage,
  PmxCatalogListView,
  PmxPoseCatalogListView,
  PmxCatalogThumbnailCache;

type
  TPmxCatalogChangedEvent = procedure of object;

  TPmxCatalogContextMenu = class
  private
    FCatalog: TPmxCatalogStorage;
    FCatalogList: TPmxCatalogListView;
    FModelCache: TPmxCatalogThumbnailCache;
    FOnChanged: TPmxCatalogChangedEvent;
    FPoseCache: TPmxCatalogThumbnailCache;
    FPoseList: TPmxPoseCatalogListView;
    FPopup: TPopupMenu;
    FRemoveItem: TMenuItem;
    FRevealItem: TMenuItem;
    procedure AddItem(const Caption: string; Handler: TNotifyEvent;
      out Item: TMenuItem);
    function CurrentItem(out Item: TPmxCatalogItem;
      out Index: Integer): Boolean;
    procedure Popup(Sender: TObject);
    procedure Refresh(Sender: TObject);
    procedure RemoveRegistration(Sender: TObject);
    procedure RevealFile(Sender: TObject);
    procedure ShowError(const Text: string);
  public
    // 左一覧へ登録解除、場所表示、再読込のメニューを接続する。
    constructor Create(ACatalogList: TPmxCatalogListView;
      APoseList: TPmxPoseCatalogListView;
      AModelCache, APoseCache: TPmxCatalogThumbnailCache);
    // 一覧からメニューを切り離し、生成したメニュー項目を解放する。
    destructor Destroy; override;
    // メニュー操作対象となる現在のPMXカタログを差し替える。
    procedure SetCatalog(ACatalog: TPmxCatalogStorage);
    property OnChanged: TPmxCatalogChangedEvent read FOnChanged write FOnChanged;
  end;

implementation

uses
  Winapi.ShellAPI,
  Winapi.Windows,
  System.IOUtils,
  System.SysUtils;

constructor TPmxCatalogContextMenu.Create(ACatalogList: TPmxCatalogListView;
  APoseList: TPmxPoseCatalogListView;
  AModelCache, APoseCache: TPmxCatalogThumbnailCache);
var
  Unused: TMenuItem;
begin
  inherited Create;
  FCatalogList := ACatalogList;
  FPoseList := APoseList;
  FModelCache := AModelCache;
  FPoseCache := APoseCache;
  FPopup := TPopupMenu.Create(nil);
  FPopup.OnPopup := Popup;
  AddItem('登録解除', RemoveRegistration, FRemoveItem);
  AddItem('PMXファイルの場所を開く', RevealFile, FRevealItem);
  AddItem('最新の状態に更新', Refresh, Unused);
  FCatalogList.PopupMenu := FPopup;
end;

destructor TPmxCatalogContextMenu.Destroy;
begin
  if Assigned(FCatalogList) and (FCatalogList.PopupMenu = FPopup) then
    FCatalogList.PopupMenu := nil;
  FPopup.Free;
  inherited;
end;

procedure TPmxCatalogContextMenu.AddItem(const Caption: string;
  Handler: TNotifyEvent; out Item: TMenuItem);
begin
  Item := TMenuItem.Create(FPopup);
  Item.Caption := Caption;
  Item.OnClick := Handler;
  FPopup.Items.Add(Item);
end;

function TPmxCatalogContextMenu.CurrentItem(out Item: TPmxCatalogItem;
  out Index: Integer): Boolean;
begin
  Item := nil;
  Index := -1;
  if not Assigned(FCatalog) or not Assigned(FCatalogList) then
    Exit(False);
  Index := FCatalogList.SelectedSourceIndex;
  Result := (Index >= 0) and (Index < FCatalog.Count);
  if Result then
    Item := FCatalog.Items[Index];
end;

procedure TPmxCatalogContextMenu.Popup(Sender: TObject);
var
  Index: Integer;
  Item: TPmxCatalogItem;
begin
  CurrentItem(Item, Index);
  FRemoveItem.Enabled := Assigned(Item);
  FRevealItem.Enabled := Assigned(Item);
end;

procedure TPmxCatalogContextMenu.Refresh(Sender: TObject);
var
  CatalogLoaded: Boolean;
  ModelCleared: Boolean;
  PoseCleared: Boolean;
begin
  ModelCleared := FModelCache.Clear;
  PoseCleared := FPoseCache.Clear;
  CatalogLoaded := Assigned(FCatalog) and FCatalog.LoadFromFile;
  if Assigned(FOnChanged) then
    FOnChanged
  else
  begin
    FCatalogList.Reload;
    FPoseList.Reload;
  end;
  if not CatalogLoaded then
    ShowError('PMXカタログを最新の状態に更新できませんでした。')
  else if not ModelCleared or not PoseCleared then
    ShowError('一部のサムネイルキャッシュを削除できませんでした。');
end;

procedure TPmxCatalogContextMenu.RemoveRegistration(Sender: TObject);
var
  Index: Integer;
  Item: TPmxCatalogItem;
  Prompt: string;
begin
  if not CurrentItem(Item, Index) then
    Exit;
  Prompt := Format('「%s」の登録を解除しますか？'#13#10 +
    'PMXファイル自体は削除されません。', [Item.DisplayName]);
  if MessageBox(FCatalogList.Handle, PChar(Prompt), 'PMX 登録解除',
    MB_YESNO or MB_ICONQUESTION or MB_DEFBUTTON2) <> IDYES then
    Exit;
  if not FCatalog.RemoveAt(Index) then
  begin
    ShowError('PMXの登録を解除できませんでした。');
    Exit;
  end;
  if Assigned(FOnChanged) then
    FOnChanged;
end;

procedure TPmxCatalogContextMenu.RevealFile(Sender: TObject);
var
  FolderPath: string;
  FullPath: string;
  Index: Integer;
  Item: TPmxCatalogItem;
  Params: string;
begin
  if not CurrentItem(Item, Index) then
    Exit;
  FullPath := TPath.GetFullPath(Item.SourcePath);
  FolderPath := TPath.GetDirectoryName(FullPath);
  if not TDirectory.Exists(FolderPath) then
  begin
    ShowError('PMXファイルのフォルダーが見つかりません。');
    Exit;
  end;
  if TFile.Exists(FullPath) then
  begin
    Params := '/select,"' + FullPath + '"';
    ShellExecute(FCatalogList.Handle, 'open', 'explorer.exe', PChar(Params),
      nil, SW_SHOWNORMAL);
  end
  else
    ShellExecute(FCatalogList.Handle, 'open', PChar(FolderPath), nil, nil,
      SW_SHOWNORMAL);
end;

procedure TPmxCatalogContextMenu.SetCatalog(ACatalog: TPmxCatalogStorage);
begin
  FCatalog := ACatalog;
end;

procedure TPmxCatalogContextMenu.ShowError(const Text: string);
begin
  MessageBox(FCatalogList.Handle, PChar(Text), 'PMX カタログ',
    MB_OK or MB_ICONERROR);
end;

end.
