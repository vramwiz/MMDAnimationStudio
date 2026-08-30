unit PmxMotionCatalogListView;

// 選択PMXへ登録したモーションを、VMD先頭状態の静止サムネイル付きで一覧表示する。

interface

uses
  System.Classes,
  System.Types,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.Graphics,
  ItemListView,
  PmxCatalogStorage,
  PmxMotionCatalogStorage,
  PmxCatalogThumbnailCache,
  PmxCatalogThumbnailRenderer,
  PmxPose,
  MmdMorphSettingCodec,
  VmdMotionReader;

type
  TPmxMotionCatalogListView = class(TCustomItemListView)
  private
    FFailedIds: TStringList;
    FAnimationBitmap: TBitmap;
    FAnimationIndex: Integer;
    FAnimationReady: Boolean;
    FAnimationStartTick: UInt64;
    FAnimationTimer: TTimer;
    FAnimationMotion: TVmdMotionData;
    FModel: TPmxCatalogItem;
    FMotionCatalog: TPmxMotionCatalogStorage;
    FThumbnailCache: TPmxCatalogThumbnailCache;
    FThumbnailQueue: TStringList;
    FThumbnailRenderer: TPmxCatalogThumbnailRenderer;
    FThumbnailTimer: TTimer;
    FVmdRoot: string;
    procedure AnimationTimer(Sender: TObject);
    function FindMotionIndex(const Id: string): Integer;
    procedure StartAnimation(Index: Integer);
    procedure StopAnimation;
    function VariantKey(Index: Integer): string;
    procedure QueueThumbnail(const Id: string);
    procedure ThumbnailTimer(Sender: TObject);
  protected
    function GetItemCount: Integer; override;
    function GetItemText(Index: Integer): string; override;
    procedure SetItemText(Index: Integer; const Value: string); override;
    procedure DrawItemImage(Index: Integer; const Bounds: TRect;
      Target: TCanvas); override;
  public
    // 静止サムネイル用キューとタイマーを持つモーション一覧を生成する。
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // 現在PMXのキャッシュを破棄し、代表画像を再生成対象にする。
    function RefreshThumbnails: Boolean;
    // 選択を可能な限り維持して表示件数とサムネイルキューを更新する。
    procedure Reload;
    // 選択中のカタログ位置を返す。
    function SelectedSourceIndex: Integer;
    // MotionUIDに一致する行を選択する。
    procedure SelectMotionId(const MotionId: string);
    // 表示対象PMXとそのPMX用モーション一覧を切り替える。
    procedure SetData(AModel: TPmxCatalogItem;
      AMotionCatalog: TPmxMotionCatalogStorage);
    // PMX状態の描画器とモーション専用画像キャッシュを接続する。
    procedure SetThumbnailServices(ACache: TPmxCatalogThumbnailCache;
      ARenderer: TPmxCatalogThumbnailRenderer);
    // 共通VMDライブラリのルートを設定し、ホバー時の原本解決に使用する。
    procedure SetVmdRoot(const Value: string);
  end;

implementation

uses
  Winapi.Windows,
  System.IOUtils,
  System.Math,
  System.SysUtils,
  AviUtl2StyleColors;

constructor TPmxMotionCatalogListView.Create(AOwner: TComponent);
begin
  inherited;
  Layout := illIcon;
  SelectionStyle := ilssRow;
  CaptionVisible := True;
  MultiSelect := False;
  ImageSize := ScaleValue(96);
  RowHeight := ImageSize + ScaleValue(28);
  FAnimationIndex := -1;
  FAnimationBitmap := Vcl.Graphics.TBitmap.Create;
  FAnimationBitmap.PixelFormat := pf32bit;
  FAnimationMotion := TVmdMotionData.Create;
  FAnimationTimer := TTimer.Create(Self);
  FAnimationTimer.Enabled := True;
  FAnimationTimer.Interval := 100;
  FAnimationTimer.OnTimer := AnimationTimer;
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

destructor TPmxMotionCatalogListView.Destroy;
begin
  FAnimationTimer.Free;
  FAnimationMotion.Free;
  FAnimationBitmap.Free;
  FThumbnailTimer.Free;
  FThumbnailQueue.Free;
  FFailedIds.Free;
  inherited;
end;

function TPmxMotionCatalogListView.GetItemCount: Integer;
begin
  if Assigned(FMotionCatalog) then Result := FMotionCatalog.Count else Result := 0;
end;

function TPmxMotionCatalogListView.GetItemText(Index: Integer): string;
begin
  Result := '';
  if Assigned(FMotionCatalog) and (Index >= 0) and
    (Index < FMotionCatalog.Count) then Result := FMotionCatalog[Index].Name;
end;

procedure TPmxMotionCatalogListView.SetItemText(Index: Integer;
  const Value: string);
begin
  if Assigned(FMotionCatalog) and FMotionCatalog.Rename(Index, Value) then Reload;
end;

function TPmxMotionCatalogListView.FindMotionIndex(const Id: string): Integer;
begin
  if Assigned(FMotionCatalog) then
    for Result := 0 to FMotionCatalog.Count - 1 do
      if SameText(FMotionCatalog[Result].Id, Id) then Exit;
  Result := -1;
end;

function TPmxMotionCatalogListView.SelectedSourceIndex: Integer;
begin
  Result := ItemIndex;
end;

procedure TPmxMotionCatalogListView.SelectMotionId(const MotionId: string);
begin
  ItemIndex := FindMotionIndex(MotionId);
end;

procedure TPmxMotionCatalogListView.SetData(AModel: TPmxCatalogItem;
  AMotionCatalog: TPmxMotionCatalogStorage);
begin
  StopAnimation;
  FModel := AModel;
  FMotionCatalog := AMotionCatalog;
  Reload;
end;

procedure TPmxMotionCatalogListView.Reload;
var
  SelectedId: string;
begin
  StopAnimation;
  SelectedId := '';
  if Assigned(FMotionCatalog) and (ItemIndex >= 0) and
    (ItemIndex < FMotionCatalog.Count) then SelectedId := FMotionCatalog[ItemIndex].Id;
  FThumbnailTimer.Enabled := False;
  FThumbnailQueue.Clear;
  FFailedIds.Clear;
  InvalidateList;
  if SelectedId <> '' then SelectMotionId(SelectedId)
  else if GetItemCount > 0 then ItemIndex := 0 else ItemIndex := -1;
end;

function TPmxMotionCatalogListView.RefreshThumbnails: Boolean;
begin
  Result := Assigned(FThumbnailCache) and FThumbnailCache.Clear;
  Reload;
end;

procedure TPmxMotionCatalogListView.SetThumbnailServices(
  ACache: TPmxCatalogThumbnailCache; ARenderer: TPmxCatalogThumbnailRenderer);
begin
  FThumbnailCache := ACache;
  FThumbnailRenderer := ARenderer;
  Reload;
end;

procedure TPmxMotionCatalogListView.SetVmdRoot(const Value: string);
begin
  StopAnimation;
  FVmdRoot := ExcludeTrailingPathDelimiter(Trim(Value));
end;

function TPmxMotionCatalogListView.VariantKey(Index: Integer): string;
begin
  Result := '';
  if Assigned(FMotionCatalog) and (Index >= 0) and
    (Index < FMotionCatalog.Count) then
    Result := FMotionCatalog[Index].Id + '|' +
      FMotionCatalog[Index].PreviewPoseData + '|' +
      FMotionCatalog[Index].PreviewMorphData;
end;

procedure TPmxMotionCatalogListView.DrawItemImage(Index: Integer;
  const Bounds: TRect; Target: TCanvas);
var
  Bitmap: Vcl.Graphics.TBitmap;
begin
  Target.Brush.Color := A2SCListViewAltBackground;
  Target.FillRect(Bounds);
  if not Assigned(FModel) or not Assigned(FMotionCatalog) or
    (Index < 0) or (Index >= FMotionCatalog.Count) or
    not FileExists(FModel.SourcePath) then Exit;
  if (Index = FAnimationIndex) and FAnimationReady and
    not FAnimationBitmap.Empty then
  begin
    Target.StretchDraw(Bounds, FAnimationBitmap);
    Exit;
  end;
  Bitmap := Vcl.Graphics.TBitmap.Create;
  try
    Bitmap.PixelFormat := pf32bit;
    Bitmap.SetSize(Max(1, Bounds.Width), Max(1, Bounds.Height));
    Bitmap.Canvas.Brush.Color := A2SCListViewAltBackground;
    Bitmap.Canvas.FillRect(Rect(0, 0, Bitmap.Width, Bitmap.Height));
    if not Assigned(FThumbnailCache) or
      not FThumbnailCache.LoadVariant(FModel.SourcePath, VariantKey(Index),
        Bitmap.Width, Bitmap.Height, Bitmap) then
      QueueThumbnail(FMotionCatalog[Index].Id);
    Target.StretchDraw(Bounds, Bitmap);
  finally
    Bitmap.Free;
  end;
end;

procedure TPmxMotionCatalogListView.StopAnimation;
var
  OldIndex: Integer;
begin
  OldIndex := FAnimationIndex;
  FAnimationIndex := -1;
  FAnimationReady := False;
  FAnimationStartTick := 0;
  FAnimationBitmap.SetSize(0, 0);
  if OldIndex >= 0 then ReloadItem(OldIndex);
end;

procedure TPmxMotionCatalogListView.StartAnimation(Index: Integer);
var
  SourceFile: string;
begin
  StopAnimation;
  FAnimationIndex := Index;
  if not Assigned(FMotionCatalog) or (Index < 0) or
    (Index >= FMotionCatalog.Count) or (FVmdRoot = '') then Exit;
  SourceFile := TPath.Combine(TPath.Combine(FVmdRoot, 'Sources'),
    FMotionCatalog[Index].SourceVmdId + '.vmd');
  FAnimationReady := FAnimationMotion.LoadFromFile(SourceFile) and
    (FAnimationMotion.MaxFrame > 0);
  if FAnimationReady then FAnimationStartTick := GetTickCount64;
end;

procedure TPmxMotionCatalogListView.AnimationTimer(Sender: TObject);
var
  Cycle, Frame: Double;
  Elapsed: UInt64;
  ImageBounds: TRect;
  Morphs: TMmdNamedMorphWeights;
  Poses: TPmxNamedBonePoses;
begin
  if not Showing or (HotIndex < 0) then
  begin
    if FAnimationIndex >= 0 then StopAnimation;
    Exit;
  end;
  if HotIndex <> FAnimationIndex then StartAnimation(HotIndex);
  if not FAnimationReady or not Assigned(FModel) or
    not Assigned(FThumbnailRenderer) then Exit;
  Elapsed := GetTickCount64 - FAnimationStartTick;
  Cycle := FAnimationMotion.MaxFrame + 1.0;
  Frame := Elapsed * 30.0 / 1000.0;
  Frame := Frame - Floor(Frame / Cycle) * Cycle;
  if not FAnimationMotion.Evaluate(Frame, Poses, Morphs) then Exit;
  ImageBounds := ItemImageRect(FAnimationIndex);
  if (ImageBounds.Width <= 0) or (ImageBounds.Height <= 0) then Exit;
  if FThumbnailRenderer.RenderPmxNamedState(FModel.SourcePath, Poses,
    Morphs, ImageBounds.Width, ImageBounds.Height, FAnimationBitmap) then
  begin
    FAnimationReady := True;
    ReloadItem(FAnimationIndex);
  end;
end;

procedure TPmxMotionCatalogListView.QueueThumbnail(const Id: string);
begin
  if (Id = '') or (FFailedIds.IndexOf(Id) >= 0) or
    (FThumbnailQueue.IndexOf(Id) >= 0) then Exit;
  FThumbnailQueue.Add(Id);
  FThumbnailTimer.Enabled := True;
end;

procedure TPmxMotionCatalogListView.ThumbnailTimer(Sender: TObject);
var
  Bitmap: Vcl.Graphics.TBitmap;
  Index: Integer;
  MotionId: string;
  R: TRect;
begin
  FThumbnailTimer.Enabled := False;
  if (FThumbnailQueue.Count = 0) or not Assigned(FModel) or
    not Assigned(FMotionCatalog) or not Assigned(FThumbnailCache) or
    not Assigned(FThumbnailRenderer) then Exit;
  MotionId := FThumbnailQueue[0];
  FThumbnailQueue.Delete(0);
  Index := FindMotionIndex(MotionId);
  if Index >= 0 then
  begin
    R := ItemImageRect(Index);
    Bitmap := Vcl.Graphics.TBitmap.Create;
    try
      if FThumbnailRenderer.RenderPmxState(FModel.SourcePath,
        FMotionCatalog[Index].PreviewPoseData,
        FMotionCatalog[Index].PreviewMorphData, Max(1, R.Width),
        Max(1, R.Height), Bitmap) then
      begin
        FThumbnailCache.SaveVariant(FModel.SourcePath, VariantKey(Index),
          Bitmap.Width, Bitmap.Height, Bitmap);
        ReloadItem(Index);
      end
      else if FFailedIds.IndexOf(MotionId) < 0 then FFailedIds.Add(MotionId);
    finally
      Bitmap.Free;
    end;
  end;
  FThumbnailTimer.Enabled := FThumbnailQueue.Count > 0;
end;

end.
