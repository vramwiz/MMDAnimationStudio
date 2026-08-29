unit PmxCatalogListView;

// PMXカタログをモデル正面サムネイル付きで表示し、未生成画像を逐次処理する。

interface

uses
  System.Classes,
  System.Generics.Collections,
  System.Types,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.Graphics,
  ItemListView,
  PmxCatalogStorage,
  PmxCatalogThumbnailCache,
  PmxCatalogThumbnailRenderer;

type
  TPmxCatalogListView = class(TCustomItemListView)
  private
    FCatalog: TPmxCatalogStorage;
    FFailedPaths: TStringList;
    FThumbnailCache: TPmxCatalogThumbnailCache;
    FThumbnailQueue: TStringList;
    FThumbnailRenderer: TPmxCatalogThumbnailRenderer;
    FThumbnailTimer: TTimer;
    FCharacterFilter: string;
    FVisibleIndexes: TList<Integer>;
    function FilterText(SourceIndex: Integer): string;
    procedure QueueThumbnail(const FileName: string);
    procedure RebuildVisibleIndexes;
    procedure ThumbnailTimer(Sender: TObject);
  protected
    function GetItemCount: Integer; override;
    function GetItemText(Index: Integer): string; override;
    procedure DrawItemImage(Index: Integer; const Bounds: TRect;
      Target: TCanvas); override;
  public
    // PMX用一覧、表示索引、遅延サムネイル生成キューを初期化する。
    constructor Create(AOwner: TComponent); override;
    // タイマー、表示索引、生成待ちキューを停止して解放する。
    destructor Destroy; override;
    // 元カタログ位置に対応する現在の表示位置を返す。非表示では-1を返す。
    function DisplayIndexOfSource(SourceIndex: Integer): Integer;
    // 表示位置に対応するPMX表示名を返す。範囲外では空文字を返す。
    function DisplayName(Index: Integer): string;
    // フィルター済み表示索引とサムネイル状態を再構築する。
    procedure Reload;
    // キャラクター名による表示フィルターを変更する。
    procedure SetCharacterFilter(const CharacterName: string);
    // 表示元のPMXカタログを差し替える。
    procedure SetCatalog(ACatalog: TPmxCatalogStorage);
    // サムネイルの読書き先と非表示レンダラーを設定する。
    procedure SetThumbnailServices(ACache: TPmxCatalogThumbnailCache;
      ARenderer: TPmxCatalogThumbnailRenderer);
    // 現在選択されている項目の元カタログ位置を返す。
    function SelectedSourceIndex: Integer;
    // 表示位置を元カタログ位置へ変換する。範囲外では-1を返す。
    function SourceIndexOfDisplay(DisplayIndex: Integer): Integer;
  end;

implementation

uses
  System.Math,
  System.SysUtils,
  AviUtl2StyleColors,
  PmxCatalogCharacterFilter;

const
  ModelThumbnailVariant = 'head-centered-v1';

constructor TPmxCatalogListView.Create(AOwner: TComponent);
begin
  inherited;
  // Layout設定は即時にGetItemCountを呼ぶため、表示索引を先に用意する。
  FVisibleIndexes := TList<Integer>.Create;
  FCharacterFilter := PmxCatalogAllCharactersCaption;
  Layout := illIcon;
  SelectionStyle := ilssRow;
  CaptionVisible := True;
  ImageSize := ScaleValue(96);
  RowHeight := ImageSize + ScaleValue(28);
  FFailedPaths := TStringList.Create;
  FFailedPaths.CaseSensitive := False;
  FThumbnailQueue := TStringList.Create;
  FThumbnailQueue.CaseSensitive := False;
  FThumbnailQueue.Sorted := True;
  FThumbnailQueue.Duplicates := dupIgnore;
  FThumbnailTimer := TTimer.Create(Self);
  FThumbnailTimer.Enabled := False;
  FThumbnailTimer.Interval := 80;
  FThumbnailTimer.OnTimer := ThumbnailTimer;
end;

destructor TPmxCatalogListView.Destroy;
begin
  FThumbnailTimer.Free;
  FThumbnailQueue.Free;
  FFailedPaths.Free;
  FVisibleIndexes.Free;
  inherited;
end;

function TPmxCatalogListView.DisplayIndexOfSource(SourceIndex: Integer): Integer;
begin
  Result := FVisibleIndexes.IndexOf(SourceIndex);
end;

function TPmxCatalogListView.DisplayName(Index: Integer): string;
begin
  Result := GetItemText(Index);
end;

procedure TPmxCatalogListView.DrawItemImage(Index: Integer;
  const Bounds: TRect; Target: TCanvas);
var
  Bitmap: TBitmap;
  FileName: string;
  SourceIndex: Integer;
begin
  Target.Brush.Color := A2SCListViewAltBackground;
  Target.FillRect(Bounds);
  SourceIndex := SourceIndexOfDisplay(Index);
  if (FCatalog = nil) or (SourceIndex < 0) or
    (SourceIndex >= FCatalog.Count) then
    Exit;
  FileName := FCatalog[SourceIndex];
  if not FileExists(FileName) then
    Exit;

  Bitmap := TBitmap.Create;
  try
    Bitmap.PixelFormat := pf32bit;
    Bitmap.SetSize(Max(1, Bounds.Width), Max(1, Bounds.Height));
    Bitmap.Canvas.Brush.Color := A2SCListViewAltBackground;
    Bitmap.Canvas.FillRect(Rect(0, 0, Bitmap.Width, Bitmap.Height));
    if not Assigned(FThumbnailCache) or
      not FThumbnailCache.LoadVariant(FileName, ModelThumbnailVariant,
        Bitmap.Width, Bitmap.Height, Bitmap) then
      QueueThumbnail(FileName);
    Target.StretchDraw(Bounds, Bitmap);
  finally
    Bitmap.Free;
  end;
end;

function TPmxCatalogListView.GetItemCount: Integer;
begin
  if Assigned(FVisibleIndexes) then
    Result := FVisibleIndexes.Count
  else
    Result := 0;
end;

function TPmxCatalogListView.GetItemText(Index: Integer): string;
begin
  Result := '';
  Index := SourceIndexOfDisplay(Index);
  if (FCatalog = nil) or (Index < 0) or (Index >= FCatalog.Count) then
    Exit;
  Result := FCatalog.Items[Index].DisplayName;
end;

function TPmxCatalogListView.FilterText(SourceIndex: Integer): string;
begin
  Result := '';
  if (FCatalog = nil) or (SourceIndex < 0) or
    (SourceIndex >= FCatalog.Count) then
    Exit;
  Result := FCatalog.Items[SourceIndex].DisplayName + ' ' +
    ExtractFileName(FCatalog.Items[SourceIndex].SourcePath);
end;

procedure TPmxCatalogListView.QueueThumbnail(const FileName: string);
begin
  if (FileName = '') or (FFailedPaths.IndexOf(FileName) >= 0) or
    (FThumbnailQueue.IndexOf(FileName) >= 0) then
    Exit;
  FThumbnailQueue.Add(FileName);
  FThumbnailTimer.Enabled := True;
end;

procedure TPmxCatalogListView.Reload;
begin
  FThumbnailTimer.Enabled := False;
  FThumbnailQueue.Clear;
  FFailedPaths.Clear;
  RebuildVisibleIndexes;
  InvalidateList;
end;

procedure TPmxCatalogListView.RebuildVisibleIndexes;
var
  Def: TPmxCatalogCharacterDef;
  DefIndex: Integer;
  SourceIndex: Integer;
begin
  FVisibleIndexes.Clear;
  if FCatalog = nil then
    Exit;
  DefIndex := PmxCatalogCharacterIndexOfName(FCharacterFilter);
  for SourceIndex := 0 to FCatalog.Count - 1 do
    if PmxCatalogCharacterIsAll(FCharacterFilter) or (DefIndex < 0) then
      FVisibleIndexes.Add(SourceIndex)
    else
    begin
      Def := PmxCatalogCharacterDef(DefIndex);
      if PmxCatalogCharacterMatches(Def, FilterText(SourceIndex)) then
        FVisibleIndexes.Add(SourceIndex);
    end;
end;

procedure TPmxCatalogListView.SetCharacterFilter(
  const CharacterName: string);
begin
  if SameText(FCharacterFilter, CharacterName) then
    Exit;
  FCharacterFilter := CharacterName;
  Reload;
end;

procedure TPmxCatalogListView.SetCatalog(ACatalog: TPmxCatalogStorage);
begin
  FCatalog := ACatalog;
  Reload;
end;

procedure TPmxCatalogListView.SetThumbnailServices(
  ACache: TPmxCatalogThumbnailCache;
  ARenderer: TPmxCatalogThumbnailRenderer);
begin
  FThumbnailCache := ACache;
  FThumbnailRenderer := ARenderer;
  Reload;
end;

function TPmxCatalogListView.SelectedSourceIndex: Integer;
begin
  Result := SourceIndexOfDisplay(ItemIndex);
end;

procedure TPmxCatalogListView.ThumbnailTimer(Sender: TObject);
var
  Bitmap: TBitmap;
  DisplayIndex: Integer;
  FileName: string;
  R: TRect;
begin
  FThumbnailTimer.Enabled := False;
  if (FThumbnailQueue.Count = 0) or not Assigned(FThumbnailCache) or
    not Assigned(FThumbnailRenderer) then
    Exit;

  FileName := FThumbnailQueue[0];
  FThumbnailQueue.Delete(0);
  DisplayIndex := DisplayIndexOfSource(FCatalog.IndexOfPath(FileName));
  if DisplayIndex >= 0 then
  begin
    R := ItemImageRect(DisplayIndex);
    Bitmap := TBitmap.Create;
    try
      if FThumbnailRenderer.RenderPmx(FileName, Max(1, R.Width),
        Max(1, R.Height), Bitmap) then
      begin
        FThumbnailCache.SaveVariant(FileName, ModelThumbnailVariant,
          Bitmap.Width, Bitmap.Height, Bitmap);
        ReloadItem(DisplayIndex);
      end
      else if FFailedPaths.IndexOf(FileName) < 0 then
        FFailedPaths.Add(FileName);
    finally
      Bitmap.Free;
    end;
  end;
  FThumbnailTimer.Enabled := FThumbnailQueue.Count > 0;
end;

function TPmxCatalogListView.SourceIndexOfDisplay(
  DisplayIndex: Integer): Integer;
begin
  if (DisplayIndex >= 0) and (DisplayIndex < FVisibleIndexes.Count) then
    Result := FVisibleIndexes[DisplayIndex]
  else
    Result := -1;
end;

end.
