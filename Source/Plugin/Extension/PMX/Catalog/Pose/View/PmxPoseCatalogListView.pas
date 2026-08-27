unit PmxPoseCatalogListView;

// 選択PMXに属するポーズを、ポーズ適用後の画像付きで表示する。

interface

uses
  System.Classes,
  System.Types,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.Graphics,
  ItemListView,
  PmxCatalogStorage,
  PmxPoseCatalogStorage,
  PmxCatalogThumbnailCache,
  PmxCatalogThumbnailRenderer;

type
  TPmxPoseCatalogListView = class(TCustomItemListView)
  private
    FFailedIds: TStringList;
    FModel: TPmxCatalogItem;
    FPoseCatalog: TPmxPoseCatalogStorage;
    FThumbnailCache: TPmxCatalogThumbnailCache;
    FThumbnailQueue: TStringList;
    FThumbnailRenderer: TPmxCatalogThumbnailRenderer;
    FThumbnailTimer: TTimer;
    function FindPoseIndex(const Id: string): Integer;
    function VariantKey(Index: Integer): string;
    procedure QueueThumbnail(const Id: string);
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
    procedure SetData(AModel: TPmxCatalogItem;
      APoseCatalog: TPmxPoseCatalogStorage);
    procedure SetThumbnailServices(ACache: TPmxCatalogThumbnailCache;
      ARenderer: TPmxCatalogThumbnailRenderer);
  end;

implementation

uses
  System.Math,
  System.SysUtils,
  AviUtl2StyleColors;

constructor TPmxPoseCatalogListView.Create(AOwner: TComponent);
begin
  inherited;
  Layout := illIcon;
  SelectionStyle := ilssImageOverlay;
  CaptionVisible := True;
  ImageSize := ScaleValue(96);
  RowHeight := ImageSize + ScaleValue(28);
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
end;

destructor TPmxPoseCatalogListView.Destroy;
begin
  FThumbnailTimer.Free;
  FThumbnailQueue.Free;
  FFailedIds.Free;
  inherited;
end;

function TPmxPoseCatalogListView.DisplayName(Index: Integer): string;
begin
  Result := GetItemText(Index);
end;

procedure TPmxPoseCatalogListView.DrawItemImage(Index: Integer;
  const Bounds: TRect; Target: TCanvas);
var
  Bitmap: TBitmap;
begin
  Target.Brush.Color := A2SCListViewAltBackground;
  Target.FillRect(Bounds);
  if (FModel = nil) or (FPoseCatalog = nil) or (Index < 0) or
    (Index >= FPoseCatalog.Count) or not FileExists(FModel.SourcePath) then
    Exit;

  Bitmap := TBitmap.Create;
  try
    Bitmap.PixelFormat := pf32bit;
    Bitmap.SetSize(Max(1, Bounds.Width), Max(1, Bounds.Height));
    Bitmap.Canvas.Brush.Color := A2SCListViewAltBackground;
    Bitmap.Canvas.FillRect(Rect(0, 0, Bitmap.Width, Bitmap.Height));
    if not Assigned(FThumbnailCache) or
      not FThumbnailCache.LoadVariant(FModel.SourcePath, VariantKey(Index),
        Bitmap.Width, Bitmap.Height, Bitmap) then
      QueueThumbnail(FPoseCatalog[Index].Id);
    Target.StretchDraw(Bounds, Bitmap);
  finally
    Bitmap.Free;
  end;
end;

function TPmxPoseCatalogListView.FindPoseIndex(const Id: string): Integer;
begin
  if Assigned(FPoseCatalog) then
    for Result := 0 to FPoseCatalog.Count - 1 do
      if SameText(FPoseCatalog[Result].Id, Id) then
        Exit;
  Result := -1;
end;

function TPmxPoseCatalogListView.GetItemCount: Integer;
begin
  if Assigned(FPoseCatalog) then
    Result := FPoseCatalog.Count
  else
    Result := 0;
end;

function TPmxPoseCatalogListView.GetItemText(Index: Integer): string;
begin
  Result := '';
  if (FPoseCatalog = nil) or (Index < 0) or
    (Index >= FPoseCatalog.Count) then
    Exit;
  Result := FPoseCatalog[Index].Name;
end;

procedure TPmxPoseCatalogListView.QueueThumbnail(const Id: string);
begin
  if (Id = '') or (FFailedIds.IndexOf(Id) >= 0) or
    (FThumbnailQueue.IndexOf(Id) >= 0) then
    Exit;
  FThumbnailQueue.Add(Id);
  FThumbnailTimer.Enabled := True;
end;

procedure TPmxPoseCatalogListView.Reload;
begin
  FThumbnailTimer.Enabled := False;
  FThumbnailQueue.Clear;
  FFailedIds.Clear;
  InvalidateList;
end;

procedure TPmxPoseCatalogListView.SetData(AModel: TPmxCatalogItem;
  APoseCatalog: TPmxPoseCatalogStorage);
begin
  FModel := AModel;
  FPoseCatalog := APoseCatalog;
  Reload;
  if GetItemCount > 0 then
    ItemIndex := 0
  else
    ItemIndex := -1;
end;

procedure TPmxPoseCatalogListView.SetThumbnailServices(
  ACache: TPmxCatalogThumbnailCache;
  ARenderer: TPmxCatalogThumbnailRenderer);
begin
  FThumbnailCache := ACache;
  FThumbnailRenderer := ARenderer;
  Reload;
end;

procedure TPmxPoseCatalogListView.ThumbnailTimer(Sender: TObject);
var
  Bitmap: TBitmap;
  Index: Integer;
  PoseId: string;
  R: TRect;
begin
  FThumbnailTimer.Enabled := False;
  if (FThumbnailQueue.Count = 0) or (FModel = nil) or
    not Assigned(FPoseCatalog) or not Assigned(FThumbnailCache) or
    not Assigned(FThumbnailRenderer) then
    Exit;

  PoseId := FThumbnailQueue[0];
  FThumbnailQueue.Delete(0);
  Index := FindPoseIndex(PoseId);
  if Index >= 0 then
  begin
    R := ItemImageRect(Index);
    Bitmap := TBitmap.Create;
    try
      if FThumbnailRenderer.RenderPmxPose(FModel.SourcePath,
        FPoseCatalog[Index].PoseData, Max(1, R.Width), Max(1, R.Height),
        Bitmap) then
      begin
        FThumbnailCache.SaveVariant(FModel.SourcePath, VariantKey(Index),
          Bitmap.Width, Bitmap.Height, Bitmap);
        ReloadItem(Index);
      end
      else if FFailedIds.IndexOf(PoseId) < 0 then
        FFailedIds.Add(PoseId);
    finally
      Bitmap.Free;
    end;
  end;
  FThumbnailTimer.Enabled := FThumbnailQueue.Count > 0;
end;

function TPmxPoseCatalogListView.VariantKey(Index: Integer): string;
begin
  Result := '';
  if (FPoseCatalog = nil) or (Index < 0) or
    (Index >= FPoseCatalog.Count) then
    Exit;
  Result := FPoseCatalog[Index].Id + '|' + FPoseCatalog[Index].PoseData;
end;

end.
