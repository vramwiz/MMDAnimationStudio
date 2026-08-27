unit PmxCatalogThumbnailRenderer;

// 1つの非表示D3D描画面でPMXの正面・標準姿勢・全身画像を生成する。

interface

uses
  System.Classes,
  Vcl.Controls,
  Vcl.Graphics,
  MmdD3DRenderer;

type
  TPmxCatalogThumbnailRenderer = class(TCustomControl)
  private
    FRenderer: TMmdD3DRenderer;
  protected
    procedure CreateWnd; override;
    procedure DestroyWnd; override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    function RenderPmx(const FileName: string; Width, Height: Integer;
      Bitmap: TBitmap): Boolean;
    function RenderPmxPose(const FileName, PoseData: string; Width,
      Height: Integer; Bitmap: TBitmap): Boolean;
  end;

implementation

uses
  Winapi.Windows,
  System.SysUtils,
  PmxModel,
  PmxMorph,
  PmxPose,
  PmxPoseCodec,
  PmxReader,
  MmdD3DScene;

constructor TPmxCatalogThumbnailRenderer.Create(AOwner: TComponent);
begin
  inherited;
  Visible := False;
  SetBounds(-10000, -10000, 128, 128);
end;

procedure TPmxCatalogThumbnailRenderer.CreateWnd;
begin
  inherited;
  FreeAndNil(FRenderer);
  FRenderer := TMmdD3DRenderer.Create(Handle, ClientWidth, ClientHeight);
end;

procedure TPmxCatalogThumbnailRenderer.DestroyWnd;
begin
  FreeAndNil(FRenderer);
  inherited;
end;

procedure TPmxCatalogThumbnailRenderer.Resize;
begin
  inherited;
  if Assigned(FRenderer) then
    FRenderer.Resize(ClientWidth, ClientHeight);
end;

function TPmxCatalogThumbnailRenderer.RenderPmx(const FileName: string;
  Width, Height: Integer; Bitmap: Vcl.Graphics.TBitmap): Boolean;
begin
  Result := RenderPmxPose(FileName, '', Width, Height, Bitmap);
end;

function TPmxCatalogThumbnailRenderer.RenderPmxPose(const FileName,
  PoseData: string; Width, Height: Integer;
  Bitmap: Vcl.Graphics.TBitmap): Boolean;
var
  Camera: TMmdPreviewCamera;
  Model: TPmxModel;
  MorphWeights: TPmxMorphWeights;
  NamedPoses: TPmxNamedBonePoses;
  Poses: TPmxBonePoses;
  Target: TMmdPreviewTarget;
  WindowHandle: HWND;
begin
  Result := False;
  if (Bitmap = nil) or (Width <= 0) or (Height <= 0) or
    not FileExists(FileName) then
    Exit;
  try
    if (ClientWidth <> Width) or (ClientHeight <> Height) then
      SetBounds(Left, Top, Width, Height);
    WindowHandle := Handle;
    if (WindowHandle = 0) or not Assigned(FRenderer) or
      (FRenderer.ErrorText <> '') then
      Exit;

    Model := GetCachedPmxModel(FileName);
    InitializeBonePoses(Model, Poses);
    if (PoseData <> '') and TryDecodePoseData(PoseData, NamedPoses) then
      ApplyNamedBonePoses(Model, NamedPoses, Poses);
    InitializeMorphWeights(Model, MorphWeights);
    Target := EmptyPreviewTarget;
    Camera := DefaultPreviewCamera;
    FRenderer.SetScene(Model, Poses, MorphWeights, Target, Target);
    FRenderer.SetCamera(Camera);
    FRenderer.SetDisplayVisibility(True, False);
    Result := FRenderer.CaptureModelImage(Bitmap);
  except
    Result := False;
  end;
end;

end.
