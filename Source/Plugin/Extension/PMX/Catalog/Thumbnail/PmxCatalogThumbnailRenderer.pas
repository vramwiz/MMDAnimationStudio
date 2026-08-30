unit PmxCatalogThumbnailRenderer;

// 1つの非表示D3D描画面でPMXの正面・標準姿勢・全身画像を生成する。

interface

uses
  System.Classes,
  Vcl.Controls,
  Vcl.Graphics,
  MmdD3DRenderer,
  PmxPose,
  MmdMorphSettingCodec;

type
  TPmxCatalogThumbnailRenderer = class(TCustomControl)
  private
    FRenderer: TMmdD3DRenderer;
    function RenderPmxInternal(const FileName, PoseData, FaceData: string;
      Width, Height: Integer; Bitmap: TBitmap; FocusHead: Boolean): Boolean;
    function RenderPmxNamedInternal(const FileName: string;
      const NamedPoses: TPmxNamedBonePoses;
      const NamedMorphs: TMmdNamedMorphWeights; Width, Height: Integer;
      Bitmap: TBitmap; FocusHead: Boolean): Boolean;
  protected
    procedure CreateWnd; override;
    procedure DestroyWnd; override;
    procedure Resize; override;
  public
    // 画面外のD3D描画面を作成し、サムネイル生成専用として初期化する。
    constructor Create(AOwner: TComponent); override;
    // PMXを正面表示し、頭ボーンが判明する場合は頭中心の画像をBitmapへ返す。
    function RenderPmx(const FileName: string; Width, Height: Integer;
      Bitmap: TBitmap): Boolean;
    // 指定姿勢を適用したPMX全身画像をBitmapへ返す。
    function RenderPmxPose(const FileName, PoseData: string; Width,
      Height: Integer; Bitmap: TBitmap): Boolean;
    // 指定姿勢とモーフを同時適用したPMX全身画像をBitmapへ返す。
    function RenderPmxState(const FileName, PoseData, MorphData: string;
      Width, Height: Integer; Bitmap: TBitmap): Boolean;
    // 名前付き姿勢とモーフを直接適用し、ホバー再生用のPMX全身画像を返す。
    function RenderPmxNamedState(const FileName: string;
      const NamedPoses: TPmxNamedBonePoses;
      const NamedMorphs: TMmdNamedMorphWeights; Width, Height: Integer;
      Bitmap: TBitmap): Boolean;
    // 指定表情を適用したPMXの頭部中心画像をBitmapへ返す。
    function RenderPmxFace(const FileName, FaceData: string; Width,
      Height: Integer; Bitmap: TBitmap): Boolean;
  end;

implementation

uses
  Winapi.Windows,
  System.SysUtils,
  PmxModel,
  PmxMorph,
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
  Result := RenderPmxInternal(FileName, '', '', Width, Height, Bitmap, True);
end;

function TPmxCatalogThumbnailRenderer.RenderPmxPose(const FileName,
  PoseData: string; Width, Height: Integer;
  Bitmap: Vcl.Graphics.TBitmap): Boolean;
begin
  Result := RenderPmxInternal(FileName, PoseData, '', Width, Height, Bitmap,
    False);
end;

function TPmxCatalogThumbnailRenderer.RenderPmxState(const FileName,
  PoseData, MorphData: string; Width, Height: Integer;
  Bitmap: Vcl.Graphics.TBitmap): Boolean;
begin
  Result := RenderPmxInternal(FileName, PoseData, MorphData, Width, Height,
    Bitmap, False);
end;

function TPmxCatalogThumbnailRenderer.RenderPmxNamedState(
  const FileName: string; const NamedPoses: TPmxNamedBonePoses;
  const NamedMorphs: TMmdNamedMorphWeights; Width, Height: Integer;
  Bitmap: Vcl.Graphics.TBitmap): Boolean;
begin
  Result := RenderPmxNamedInternal(FileName, NamedPoses, NamedMorphs,
    Width, Height, Bitmap, False);
end;

function TPmxCatalogThumbnailRenderer.RenderPmxFace(const FileName,
  FaceData: string; Width, Height: Integer;
  Bitmap: Vcl.Graphics.TBitmap): Boolean;
begin
  Result := RenderPmxInternal(FileName, '', FaceData, Width, Height, Bitmap,
    True);
end;

function TryHeadCamera(Model: TPmxModel; const Poses: TPmxBonePoses;
  const MorphWeights: TPmxMorphWeights; Width, Height: Integer;
  out Camera: TMmdPreviewCamera): Boolean;
const
  HeadZoom = 4.0;
var
  HeadIndex: Integer;
  Index: Integer;
  Joint: TMmdPreviewJoint;
  Point: TPmxVector3;
  Scene: TMmdPreviewScene;
begin
  Result := False;
  HeadIndex := -1;
  for Index := 0 to High(Model.Bones) do
    if SameText(Model.Bones[Index].Name, #$982D) or
      SameText(Model.Bones[Index].Name, 'head') then
    begin
      HeadIndex := Index;
      Break;
    end;
  if HeadIndex < 0 then
    Exit;

  BuildPreviewScene(Model, Poses, MorphWeights, EmptyPreviewTarget,
    EmptyPreviewTarget, Scene);
  for Joint in Scene.Joints do
    if Joint.BoneIndex = HeadIndex then
    begin
      Camera := DefaultPreviewCamera;
      Point := ProjectPreviewPosition(Joint.Position, Scene.Projection,
        Camera, Width, Height);
      Camera.Zoom := HeadZoom;
      Camera.PanX := -Point.X * Camera.Zoom * Width * 0.5;
      Camera.PanY := Point.Y * Camera.Zoom * Height * 0.5;
      Exit(True);
    end;
end;

function TPmxCatalogThumbnailRenderer.RenderPmxInternal(const FileName,
  PoseData, FaceData: string; Width, Height: Integer;
  Bitmap: Vcl.Graphics.TBitmap; FocusHead: Boolean): Boolean;
var
  NamedMorphs: TMmdNamedMorphWeights;
  NamedPoses: TPmxNamedBonePoses;
begin
  NamedPoses := nil;
  NamedMorphs := nil;
  if PoseData <> '' then TryDecodePoseData(PoseData, NamedPoses);
  if FaceData <> '' then
    TryDecodeMmdMorphSettingData(FaceData, NamedMorphs);
  Result := RenderPmxNamedInternal(FileName, NamedPoses, NamedMorphs,
    Width, Height, Bitmap, FocusHead);
end;

function TPmxCatalogThumbnailRenderer.RenderPmxNamedInternal(
  const FileName: string; const NamedPoses: TPmxNamedBonePoses;
  const NamedMorphs: TMmdNamedMorphWeights; Width, Height: Integer;
  Bitmap: Vcl.Graphics.TBitmap; FocusHead: Boolean): Boolean;
var
  Camera: TMmdPreviewCamera;
  Model: TPmxModel;
  MorphWeights: TPmxMorphWeights;
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
    if Length(NamedPoses) > 0 then
      ApplyNamedBonePoses(Model, NamedPoses, Poses);
    InitializeMorphWeights(Model, MorphWeights);
    if Length(NamedMorphs) > 0 then
      ApplyMmdNamedMorphWeights(Model, NamedMorphs, MorphWeights);
    Target := EmptyPreviewTarget;
    Camera := DefaultPreviewCamera;
    FRenderer.SetScene(Model, Poses, MorphWeights, Target, Target);
    if FocusHead then
      TryHeadCamera(Model, Poses, MorphWeights, Width, Height, Camera);
    FRenderer.SetCamera(Camera);
    FRenderer.SetDisplayVisibility(True, False);
    Result := FRenderer.CaptureModelImage(Bitmap);
  except
    Result := False;
  end;
end;

end.
