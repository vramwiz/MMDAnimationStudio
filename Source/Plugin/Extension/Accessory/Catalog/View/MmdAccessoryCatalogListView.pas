unit MmdAccessoryCatalogListView;

// 登録済みアクセサリを全体フィットの静止サムネイル付き一覧として表示する。

interface

uses
  System.Classes,
  System.Types,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.Graphics,
  ItemListView,
  MmdAccessoryCatalog,
  MmdAccessoryHoverPreview,
  PmxCatalogThumbnailCache,
  PmxCatalogThumbnailRenderer;

type
  TMmdAccessoryCatalogListView = class(TCustomItemListView)
  private
    FCatalog: TMmdAccessoryCatalog;
    FFailedIds: TStringList;
    FHoverPreview: TMmdAccessoryHoverPreview;
    FThumbnailCache: TPmxCatalogThumbnailCache;
    FThumbnailQueue: TStringList;
    FThumbnailRenderer: TPmxCatalogThumbnailRenderer;
    FThumbnailTimer: TTimer;
    FPendingItemIndex: Integer;
    function FindItemIndex(const Id: string): Integer;
    function HoverBounds(Index: Integer): TRect;
    procedure HoverReload(Index: Integer);
    function ItemSourceFileName(Index: Integer): string;
    procedure QueueThumbnail(const Id: string);
    procedure ThumbnailTimer(Sender: TObject);
  protected
    procedure CreateWnd; override;
    procedure DrawItemImage(Index: Integer; const Bounds: TRect;
      Target: TCanvas); override;
    function GetItemCount: Integer; override;
    function GetItemText(Index: Integer): string; override;
    procedure SetItemText(Index: Integer; const Value: string); override;
  public
    // 一覧表示と遅延サムネイル生成キューを初期化する。
    constructor Create(AOwner: TComponent); override;
    // 遅延生成タイマー、回転プレビュー、生成待ち情報を解放する。
    destructor Destroy; override;
    // 現在表示しているアクセサリ件数を返す。
    function DisplayCount: Integer;
    // キャッシュを破棄し、表示中サムネイルを再生成対象にする。
    function RefreshThumbnails: Boolean;
    // 選択UIDを維持して一覧と生成待ち状態を再構築する。
    procedure Reload;
    // AccessoryUIDに一致する行を選択する。
    procedure SelectItemId(const Id: string);
    // 表示元カタログを非所有参照として接続し、一覧を再構築する。
    procedure SetCatalog(ACatalog: TMmdAccessoryCatalog);
    // キャッシュとRendererを非所有参照として接続し、サムネイルを再読込する。
    procedure SetThumbnailServices(ACache: TPmxCatalogThumbnailCache;
      ARenderer: TPmxCatalogThumbnailRenderer);
    // 選択行に対応するカタログ位置を返す。
    function SelectedSourceIndex: Integer;
  end;

implementation

uses
  System.Math,
  System.SysUtils,
  AviUtl2StyleColors;

const
  AccessoryThumbnailVariant = 'accessory-front-v1';

constructor TMmdAccessoryCatalogListView.Create(AOwner: TComponent);
begin
  inherited;
  Layout := illIcon;
  SelectionStyle := ilssRow;
  CaptionVisible := True;
  MultiSelect := False;
  ImageSize := ScaleValue(96);
  RowHeight := ImageSize + ScaleValue(28);
  FHoverPreview := TMmdAccessoryHoverPreview.Create(Self, ItemSourceFileName,
    HoverBounds, HoverReload);
  FFailedIds := TStringList.Create;
  FFailedIds.CaseSensitive := False;
  FThumbnailQueue := TStringList.Create;
  FThumbnailQueue.CaseSensitive := False;
  FThumbnailQueue.Sorted := True;
  FThumbnailQueue.Duplicates := dupIgnore;
  FThumbnailTimer := TTimer.Create(Self);
  FThumbnailTimer.Enabled := False;
  FThumbnailTimer.Interval := 80;
  FThumbnailTimer.OnTimer := ThumbnailTimer;
  FPendingItemIndex := -1;
end;

procedure TMmdAccessoryCatalogListView.CreateWnd;
var
  PendingIndex: Integer;
begin
  inherited;
  PendingIndex := FPendingItemIndex;
  FPendingItemIndex := -1;
  if PendingIndex >= 0 then ItemIndex := PendingIndex;
end;

destructor TMmdAccessoryCatalogListView.Destroy;
begin
  FHoverPreview.Free;
  FThumbnailTimer.Free;
  FThumbnailQueue.Free;
  FFailedIds.Free;
  inherited;
end;

function TMmdAccessoryCatalogListView.DisplayCount: Integer;
begin
  Result := GetItemCount;
end;

procedure TMmdAccessoryCatalogListView.DrawItemImage(Index: Integer;
  const Bounds: TRect; Target: TCanvas);
var
  Bitmap: Vcl.Graphics.TBitmap;
  FileName: string;
begin
  Target.Brush.Color := A2SCListViewAltBackground;
  Target.FillRect(Bounds);
  FileName := ItemSourceFileName(Index);
  if FileName = '' then Exit;
  if FHoverPreview.TryDraw(Index, Bounds, Target) then Exit;
  Bitmap := Vcl.Graphics.TBitmap.Create;
  try
    Bitmap.PixelFormat := pf32bit;
    Bitmap.SetSize(Max(1, Bounds.Width), Max(1, Bounds.Height));
    Bitmap.Canvas.Brush.Color := A2SCListViewAltBackground;
    Bitmap.Canvas.FillRect(Rect(0, 0, Bitmap.Width, Bitmap.Height));
    if not Assigned(FThumbnailCache) or
      not FThumbnailCache.LoadVariant(FileName, AccessoryThumbnailVariant,
        Bitmap.Width, Bitmap.Height, Bitmap) then
      QueueThumbnail(FCatalog[Index].Id);
    Target.StretchDraw(Bounds, Bitmap);
  finally
    Bitmap.Free;
  end;
end;

function TMmdAccessoryCatalogListView.FindItemIndex(const Id: string): Integer;
begin
  if Assigned(FCatalog) then
    for Result := 0 to FCatalog.Count - 1 do
      if SameText(FCatalog[Result].Id, Id) then Exit;
  Result := -1;
end;

function TMmdAccessoryCatalogListView.GetItemCount: Integer;
begin
  if Assigned(FCatalog) then Result := FCatalog.Count else Result := 0;
end;

function TMmdAccessoryCatalogListView.GetItemText(Index: Integer): string;
begin
  Result := '';
  if Assigned(FCatalog) and (Index >= 0) and (Index < FCatalog.Count) then
    Result := FCatalog[Index].Name;
end;

procedure TMmdAccessoryCatalogListView.SetItemText(Index: Integer;
  const Value: string);
var
  Id: string;
begin
  if not Assigned(FCatalog) or (Index < 0) or (Index >= FCatalog.Count) then
    Exit;
  Id := FCatalog[Index].Id;
  if FCatalog.Rename(Index, Value) then
  begin
    Reload;
    SelectItemId(Id);
  end;
end;

function TMmdAccessoryCatalogListView.HoverBounds(Index: Integer): TRect;
begin
  Result := ItemImageRect(Index);
end;

procedure TMmdAccessoryCatalogListView.HoverReload(Index: Integer);
begin
  if HandleAllocated and (Index >= 0) and (Index < GetItemCount) then
    ReloadItem(Index);
end;

function TMmdAccessoryCatalogListView.ItemSourceFileName(
  Index: Integer): string;
begin
  Result := '';
  if not Assigned(FCatalog) or (Index < 0) or (Index >= FCatalog.Count) then
    Exit;
  Result := FCatalog.SourceFileName(FCatalog[Index].SourceId);
  if not FileExists(Result) then Result := '';
end;

procedure TMmdAccessoryCatalogListView.QueueThumbnail(const Id: string);
begin
  if (Id = '') or (FFailedIds.IndexOf(Id) >= 0) or
    (FThumbnailQueue.IndexOf(Id) >= 0) then Exit;
  FThumbnailQueue.Add(Id);
  FThumbnailTimer.Enabled := True;
end;

function TMmdAccessoryCatalogListView.RefreshThumbnails: Boolean;
begin
  Result := Assigned(FThumbnailCache) and FThumbnailCache.Clear;
  Reload;
end;

procedure TMmdAccessoryCatalogListView.Reload;
var
  NewItemIndex: Integer;
  SelectedId: string;
begin
  FHoverPreview.Reset;
  SelectedId := '';
  if Assigned(FCatalog) and (ItemIndex >= 0) and
    (ItemIndex < FCatalog.Count) then SelectedId := FCatalog[ItemIndex].Id;
  FThumbnailTimer.Enabled := False;
  FThumbnailQueue.Clear;
  FFailedIds.Clear;
  InvalidateList;
  if SelectedId <> '' then NewItemIndex := FindItemIndex(SelectedId)
  else if GetItemCount > 0 then NewItemIndex := 0 else NewItemIndex := -1;
  if HandleAllocated then
  begin
    FPendingItemIndex := -1;
    ItemIndex := NewItemIndex;
  end
  else
    FPendingItemIndex := NewItemIndex;
end;

function TMmdAccessoryCatalogListView.SelectedSourceIndex: Integer;
begin
  Result := ItemIndex;
end;

procedure TMmdAccessoryCatalogListView.SelectItemId(const Id: string);
begin
  ItemIndex := FindItemIndex(Id);
end;

procedure TMmdAccessoryCatalogListView.SetCatalog(
  ACatalog: TMmdAccessoryCatalog);
begin
  FHoverPreview.Reset;
  FCatalog := ACatalog;
  Reload;
end;

procedure TMmdAccessoryCatalogListView.SetThumbnailServices(
  ACache: TPmxCatalogThumbnailCache;
  ARenderer: TPmxCatalogThumbnailRenderer);
begin
  FHoverPreview.SetRenderer(ARenderer);
  FThumbnailCache := ACache;
  FThumbnailRenderer := ARenderer;
  Reload;
end;

procedure TMmdAccessoryCatalogListView.ThumbnailTimer(Sender: TObject);
var
  Bitmap: Vcl.Graphics.TBitmap;
  Id: string;
  Index: Integer;
  R: TRect;
begin
  FThumbnailTimer.Enabled := False;
  if (FThumbnailQueue.Count = 0) or not Assigned(FCatalog) or
    not Assigned(FThumbnailCache) or not Assigned(FThumbnailRenderer) then
    Exit;
  Id := FThumbnailQueue[0];
  FThumbnailQueue.Delete(0);
  Index := FindItemIndex(Id);
  if Index >= 0 then
  begin
    R := ItemImageRect(Index);
    Bitmap := Vcl.Graphics.TBitmap.Create;
    try
      if FThumbnailRenderer.RenderAccessoryFull(ItemSourceFileName(Index),
        Max(1, R.Width), Max(1, R.Height), Bitmap) then
      begin
        FThumbnailCache.SaveVariant(ItemSourceFileName(Index),
          AccessoryThumbnailVariant, Bitmap.Width, Bitmap.Height, Bitmap);
        ReloadItem(Index);
      end
      else if FFailedIds.IndexOf(Id) < 0 then FFailedIds.Add(Id);
    finally
      Bitmap.Free;
    end;
  end;
  FThumbnailTimer.Enabled := FThumbnailQueue.Count > 0;
end;

end.
