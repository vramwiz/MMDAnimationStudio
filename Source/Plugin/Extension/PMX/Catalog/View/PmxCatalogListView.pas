unit PmxCatalogListView;

// PMXカタログをモデル正面サムネイル付きで表示し、未生成画像を逐次処理する。

interface

uses
  System.Classes,
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
    procedure QueueThumbnail(const FileName: string);
    procedure ThumbnailTimer(Sender: TObject);
  protected
    function GetItemCount: Integer; override;
    function GetItemText(Index: Integer): string; override;
    procedure DrawItemImage(Index: Integer; const Bounds: TRect;
      Target: TCanvas); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function DisplayName(Index: Integer): string;
    procedure Reload;
    procedure SetCatalog(ACatalog: TPmxCatalogStorage);
    procedure SetThumbnailServices(ACache: TPmxCatalogThumbnailCache;
      ARenderer: TPmxCatalogThumbnailRenderer);
  end;

implementation

uses
  System.Math,
  System.SysUtils,
  AviUtl2StyleColors;

constructor TPmxCatalogListView.Create(AOwner: TComponent);
begin
  inherited;
  Layout := illIcon;
  SelectionStyle := ilssImageOverlay;
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
  inherited;
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
begin
  Target.Brush.Color := A2SCListViewAltBackground;
  Target.FillRect(Bounds);
  if (FCatalog = nil) or (Index < 0) or (Index >= FCatalog.Count) then
    Exit;
  FileName := FCatalog[Index];
  if not FileExists(FileName) then
    Exit;

  Bitmap := TBitmap.Create;
  try
    Bitmap.PixelFormat := pf32bit;
    Bitmap.SetSize(Max(1, Bounds.Width), Max(1, Bounds.Height));
    Bitmap.Canvas.Brush.Color := A2SCListViewAltBackground;
    Bitmap.Canvas.FillRect(Rect(0, 0, Bitmap.Width, Bitmap.Height));
    if not Assigned(FThumbnailCache) or
      not FThumbnailCache.Load(FileName, Bitmap.Width, Bitmap.Height,
        Bitmap) then
      QueueThumbnail(FileName);
    Target.StretchDraw(Bounds, Bitmap);
  finally
    Bitmap.Free;
  end;
end;

function TPmxCatalogListView.GetItemCount: Integer;
begin
  if Assigned(FCatalog) then
    Result := FCatalog.Count
  else
    Result := 0;
end;

function TPmxCatalogListView.GetItemText(Index: Integer): string;
begin
  Result := '';
  if (FCatalog = nil) or (Index < 0) or (Index >= FCatalog.Count) then
    Exit;
  Result := FCatalog.Items[Index].DisplayName;
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
  InvalidateList;
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
  DisplayIndex := FCatalog.IndexOfPath(FileName);
  if DisplayIndex >= 0 then
  begin
    R := ItemImageRect(DisplayIndex);
    Bitmap := TBitmap.Create;
    try
      if FThumbnailRenderer.RenderPmx(FileName, Max(1, R.Width),
        Max(1, R.Height), Bitmap) then
      begin
        FThumbnailCache.Save(FileName, Bitmap.Width, Bitmap.Height, Bitmap);
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

end.
