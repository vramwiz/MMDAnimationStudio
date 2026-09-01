unit PmxCatalogThumbnailRenderer;

// 1つの非表示D3D描画面でPMXの正面・標準姿勢・全身画像を生成する。

interface

uses
  System.Classes,
  Vcl.Controls,
  Vcl.Graphics,
  MmdD3DRenderer,
  PmxModel,
  PmxPose,
  MmdMorphSettingCodec;

type
  TPmxCatalogThumbnailRenderer = class(TCustomControl)
  private
    FObjFileName: string;
    FObjModel: TPmxModel;
    FRenderer: TMmdD3DRenderer;
    function RenderObjInternal(const FileName: string; CameraYaw: Single;
      Width, Height: Integer; Bitmap: TBitmap): Boolean;
    function RenderPmxInternal(const FileName, PoseData, FaceData: string;
      Width, Height: Integer; Bitmap: TBitmap; FocusHead: Boolean;
      CameraYaw: Single = 0): Boolean;
    function RenderPmxNamedInternal(const FileName: string;
      const NamedPoses: TPmxNamedBonePoses;
      const NamedMorphs: TMmdNamedMorphWeights; Width, Height: Integer;
      Bitmap: TBitmap; FocusHead: Boolean; CameraYaw: Single = 0): Boolean;
  protected
    procedure CreateWnd; override;
    procedure DestroyWnd; override;
    procedure Resize; override;
  public
    // 画面外のD3D描画面を作成し、サムネイル生成専用として初期化する。
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // PMXまたはOBJを判別して全体の静止画像を返す。
    function RenderAccessoryFull(const FileName: string; Width,
      Height: Integer; Bitmap: TBitmap): Boolean;
    // PMXまたはOBJを判別して指定Yaw角の画像を返す。
    function RenderAccessoryFullAngle(const FileName: string;
      CameraYaw: Single; Width, Height: Integer; Bitmap: TBitmap): Boolean;
    // PMXを正面表示し、頭ボーンが判明する場合は頭中心の画像をBitmapへ返す。
    function RenderPmx(const FileName: string; Width, Height: Integer;
      Bitmap: TBitmap): Boolean;
    // PMXをボーン名に依存せず境界全体が収まる正面画像として返す。
    function RenderPmxFull(const FileName: string; Width, Height: Integer;
      Bitmap: TBitmap): Boolean;
    // PMX全体を指定Yaw角で描画し、アクセサリのホバー回転画像を返す。
    function RenderPmxFullAngle(const FileName: string; CameraYaw: Single;
      Width, Height: Integer; Bitmap: TBitmap): Boolean;
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
  PmxMorph,
  PmxPoseCodec,
  PmxReader,
  ObjReader,
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

destructor TPmxCatalogThumbnailRenderer.Destroy;
begin
  FObjModel.Free;
  inherited;
end;

function TPmxCatalogThumbnailRenderer.RenderAccessoryFull(
  const FileName: string; Width, Height: Integer;
  Bitmap: Vcl.Graphics.TBitmap): Boolean;
begin
  if SameText(ExtractFileExt(FileName), '.obj') then
    Result := RenderObjInternal(FileName, 0, Width, Height, Bitmap)
  else
    Result := RenderPmxFull(FileName, Width, Height, Bitmap);
end;

function TPmxCatalogThumbnailRenderer.RenderAccessoryFullAngle(
  const FileName: string; CameraYaw: Single; Width, Height: Integer;
  Bitmap: Vcl.Graphics.TBitmap): Boolean;
begin
  if SameText(ExtractFileExt(FileName), '.obj') then
    Result := RenderObjInternal(FileName, CameraYaw, Width, Height, Bitmap)
  else
    Result := RenderPmxFullAngle(FileName, CameraYaw, Width, Height, Bitmap);
end;

function TPmxCatalogThumbnailRenderer.RenderObjInternal(
  const FileName: string; CameraYaw: Single; Width, Height: Integer;
  Bitmap: Vcl.Graphics.TBitmap): Boolean;
var
  Camera: TMmdPreviewCamera;
  Dependencies: TArray<string>;
  MorphWeights: TPmxMorphWeights;
  Poses: TPmxBonePoses;
  Target: TMmdPreviewTarget;
  WindowHandle: HWND;
begin
  Result := False;
  if (Bitmap = nil) or (Width <= 0) or (Height <= 0) or
    not FileExists(FileName) then Exit;
  try
    if not SameText(FObjFileName, FileName) or not Assigned(FObjModel) then
    begin
      FreeAndNil(FObjModel);
      FObjFileName := '';
      FObjModel := LoadObjModel(FileName, Dependencies);
      FObjFileName := FileName;
    end;
    if (ClientWidth <> Width) or (ClientHeight <> Height) then
      SetBounds(Left, Top, Width, Height);
    WindowHandle := Handle;
    if (WindowHandle = 0) or not Assigned(FRenderer) or
      (FRenderer.ErrorText <> '') then Exit;
    InitializeBonePoses(FObjModel, Poses);
    InitializeMorphWeights(FObjModel, MorphWeights);
    Target := EmptyPreviewTarget;
    Camera := DefaultPreviewCamera;
    Camera.Yaw := CameraYaw;
    FRenderer.SetScene(FObjModel, Poses, MorphWeights, Target, Target);
    FRenderer.SetCamera(Camera);
    FRenderer.SetDisplayVisibility(True, False);
    Result := FRenderer.CaptureModelImage(Bitmap);
  except
    Result := False;
  end;
end;

function TPmxCatalogThumbnailRenderer.RenderPmxFull(const FileName: string;
  Width, Height: Integer; Bitmap: Vcl.Graphics.TBitmap): Boolean;
begin
  Result := RenderPmxInternal(FileName, '', '', Width, Height, Bitmap, False);
end;

function TPmxCatalogThumbnailRenderer.RenderPmxFullAngle(
  const FileName: string; CameraYaw: Single; Width, Height: Integer;
  Bitmap: Vcl.Graphics.TBitmap): Boolean;
begin
  Result := RenderPmxInternal(FileName, '', '', Width, Height, Bitmap, False,
    CameraYaw);
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
  Bitmap: Vcl.Graphics.TBitmap; FocusHead: Boolean;
  CameraYaw: Single): Boolean;
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
    Width, Height, Bitmap, FocusHead, CameraYaw);
end;

function TPmxCatalogThumbnailRenderer.RenderPmxNamedInternal(
  const FileName: string; const NamedPoses: TPmxNamedBonePoses;
  const NamedMorphs: TMmdNamedMorphWeights; Width, Height: Integer;
  Bitmap: Vcl.Graphics.TBitmap; FocusHead: Boolean;
  CameraYaw: Single): Boolean;
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
    Camera.Yaw := CameraYaw;
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
