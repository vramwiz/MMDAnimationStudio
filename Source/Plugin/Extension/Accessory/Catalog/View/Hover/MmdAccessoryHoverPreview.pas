unit MmdAccessoryHoverPreview;

// アクセサリ一覧のカーソル下1項目だけを回転描画し、離脱時に静止画へ戻す。

interface

uses
  System.Types,
  Vcl.ExtCtrls,
  Vcl.Graphics,
  ItemListView,
  PmxCatalogThumbnailRenderer;

type
  // 一覧を直接所有せず、対象行の元ファイル・領域・再描画を呼出元から受け取る。
  TAccessoryHoverBoundsEvent = function(Index: Integer): TRect of object;
  TAccessoryHoverReloadEvent = procedure(Index: Integer) of object;
  TAccessoryHoverSourceEvent = function(Index: Integer): string of object;

  TMmdAccessoryHoverPreview = class
  private
    FBitmap: Vcl.Graphics.TBitmap;
    FBounds: TAccessoryHoverBoundsEvent;
    FIndex: Integer;
    FList: TCustomItemListView;
    FReady: Boolean;
    FReload: TAccessoryHoverReloadEvent;
    FRenderer: TPmxCatalogThumbnailRenderer;
    FSourceFile: TAccessoryHoverSourceEvent;
    FStartTick: UInt64;
    FTimer: TTimer;
    procedure Start(Index: Integer);
    procedure Timer(Sender: TObject);
  public
    // 一覧状態の取得と再描画をコールバックで接続し、100msタイマーを開始する。
    constructor Create(AList: TCustomItemListView;
      ASourceFile: TAccessoryHoverSourceEvent;
      ABounds: TAccessoryHoverBoundsEvent;
      AReload: TAccessoryHoverReloadEvent);
    // タイマーと動的Bitmapを解放する。Rendererは所有しない。
    destructor Destroy; override;
    // 現在の回転状態を破棄し、以前の対象行を静止画へ再描画する。
    procedure Reset;
    // 回転描画サービスを非所有参照として設定し、以前の状態を破棄する。
    procedure SetRenderer(ARenderer: TPmxCatalogThumbnailRenderer);
    // Indexが現在の回転対象ならBitmapをBoundsへ描画してTrueを返す。
    function TryDraw(Index: Integer; const Bounds: TRect;
      Target: TCanvas): Boolean;
  end;

implementation

uses
  Winapi.Windows,
  System.Math;

const
  HoverFrameInterval = 100;
  HoverRotationMilliseconds = 4000.0;

constructor TMmdAccessoryHoverPreview.Create(AList: TCustomItemListView;
  ASourceFile: TAccessoryHoverSourceEvent;
  ABounds: TAccessoryHoverBoundsEvent; AReload: TAccessoryHoverReloadEvent);
begin
  inherited Create;
  FList := AList;
  FSourceFile := ASourceFile;
  FBounds := ABounds;
  FReload := AReload;
  FIndex := -1;
  FBitmap := Vcl.Graphics.TBitmap.Create;
  FBitmap.PixelFormat := pf32bit;
  FTimer := TTimer.Create(nil);
  FTimer.Interval := HoverFrameInterval;
  FTimer.OnTimer := Timer;
  FTimer.Enabled := True;
end;

destructor TMmdAccessoryHoverPreview.Destroy;
begin
  FTimer.Free;
  FBitmap.Free;
  inherited;
end;

procedure TMmdAccessoryHoverPreview.Reset;
var
  OldIndex: Integer;
begin
  OldIndex := FIndex;
  FIndex := -1;
  FReady := False;
  FStartTick := 0;
  FBitmap.SetSize(0, 0);
  if Assigned(FReload) and Assigned(FList) and FList.HandleAllocated and
    (OldIndex >= 0) and (OldIndex < FList.DisplayCount) then FReload(OldIndex);
end;

procedure TMmdAccessoryHoverPreview.SetRenderer(
  ARenderer: TPmxCatalogThumbnailRenderer);
begin
  Reset;
  FRenderer := ARenderer;
end;

procedure TMmdAccessoryHoverPreview.Start(Index: Integer);
var
  SourceFileName: string;
begin
  Reset;
  if not Assigned(FSourceFile) or (Index < 0) or
    (Index >= FList.DisplayCount) then Exit;
  SourceFileName := FSourceFile(Index);
  if SourceFileName = '' then Exit;
  FIndex := Index;
  FStartTick := GetTickCount64;
end;

procedure TMmdAccessoryHoverPreview.Timer(Sender: TObject);
var
  Angle: Single;
  Bounds: TRect;
  Elapsed: UInt64;
begin
  if not Assigned(FList) or not FList.Showing or (FList.HotIndex < 0) then
  begin
    if FIndex >= 0 then Reset;
    Exit;
  end;
  if FList.HotIndex <> FIndex then Start(FList.HotIndex);
  if (FIndex < 0) or not Assigned(FRenderer) or not Assigned(FBounds) or
    not Assigned(FSourceFile) then Exit;
  Bounds := FBounds(FIndex);
  if (Bounds.Width <= 0) or (Bounds.Height <= 0) then Exit;
  Elapsed := GetTickCount64 - FStartTick;
  Angle := 2.0 * Pi * (Elapsed / HoverRotationMilliseconds);
  Angle := Angle - Floor(Angle / (2.0 * Pi)) * (2.0 * Pi);
  if FRenderer.RenderAccessoryFullAngle(FSourceFile(FIndex), Angle,
    Bounds.Width, Bounds.Height, FBitmap) then
  begin
    FReady := True;
    if Assigned(FReload) then FReload(FIndex);
  end;
end;

function TMmdAccessoryHoverPreview.TryDraw(Index: Integer;
  const Bounds: TRect; Target: TCanvas): Boolean;
begin
  Result := (Index = FIndex) and FReady and not FBitmap.Empty;
  if Result then Target.StretchDraw(Bounds, FBitmap);
end;

end.
