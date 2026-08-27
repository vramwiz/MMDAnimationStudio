unit MmdAiDiagnosticOverlay;

// 最終ボーン位置をD3Dプレビューと同じ投影でBMPへ描き、左右と中央を識別可能にする。

interface

uses
  Vcl.Graphics,
  PmxModel,
  PmxPose,
  MmdD3DScene;

// Bitmapを診断背景で初期化する。
procedure ClearDiagnosticBitmap(Bitmap: Vcl.Graphics.TBitmap;
  Width, Height: Integer);
// 最終姿勢の骨格を、モデル本人基準の左青・右赤・中央黄で描く。
procedure DrawDiagnosticBones(Bitmap: Vcl.Graphics.TBitmap; Model: TPmxModel;
  const Poses: TPmxBonePoses; const Camera: TMmdPreviewCamera);
// 計算済みシーンの骨格を任意Canvasへ描き、対話Viewportでも同じ凡例を使う。
procedure DrawDiagnosticBoneScene(Canvas: Vcl.Graphics.TCanvas;
  Width, Height: Integer; Model: TPmxModel; const Scene: TMmdPreviewScene;
  const Camera: TMmdPreviewCamera);

implementation

uses
  Winapi.Windows,
  System.Math,
  System.Types,
  System.UITypes,
  System.StrUtils;

procedure ClearDiagnosticBitmap(Bitmap: Vcl.Graphics.TBitmap;
  Width, Height: Integer);
begin
  Bitmap.PixelFormat := pf32bit;
  Bitmap.SetSize(Width, Height);
  Bitmap.Canvas.Brush.Color := RGB(14, 15, 19);
  Bitmap.Canvas.FillRect(Rect(0, 0, Width, Height));
end;

function BoneColor(const Name: string): Vcl.Graphics.TColor;
begin
  if StartsText(#$5DE6, Name) then
    Result := RGB(26, 115, 255)
  else if StartsText(#$53F3, Name) then
    Result := RGB(255, 51, 38)
  else
    Result := RGB(255, 217, 26);
end;

function ScreenPoint(const Position: TPmxVector3;
  const Projection: TMmdPreviewProjection; const Camera: TMmdPreviewCamera;
  Width, Height: Integer): TPoint;
var
  Projected: TPmxVector3;
begin
  Projected := ProjectPreviewPosition(Position, Projection, Camera,
    Width, Height);
  Result.X := Round((Projected.X + 1.0) * Width * 0.5);
  Result.Y := Round((1.0 - Projected.Y) * Height * 0.5);
end;

procedure DrawDiagnosticBones(Bitmap: Vcl.Graphics.TBitmap; Model: TPmxModel;
  const Poses: TPmxBonePoses; const Camera: TMmdPreviewCamera);
var
  Scene: TMmdPreviewScene;
begin
  BuildPreviewScene(Model, Poses, nil, EmptyPreviewTarget,
    EmptyPreviewTarget, Scene);
  DrawDiagnosticBoneScene(Bitmap.Canvas, Bitmap.Width, Bitmap.Height, Model,
    Scene, Camera);
end;

procedure DrawDiagnosticBoneScene(Canvas: Vcl.Graphics.TCanvas;
  Width, Height: Integer; Model: TPmxModel; const Scene: TMmdPreviewScene;
  const Camera: TMmdPreviewCamera);
var
  EndPoint, StartPoint: TPoint;
  Joint: TMmdPreviewJoint;
  Radius: Integer;
  Segment: TMmdPreviewBoneSegment;
begin
  Canvas.Pen.Width := Max(2, Min(Width, Height) div 240);
  for Segment in Scene.BoneSegments do
  begin
    StartPoint := ScreenPoint(Segment.StartPosition, Scene.Projection,
      Camera, Width, Height);
    EndPoint := ScreenPoint(Segment.EndPosition, Scene.Projection,
      Camera, Width, Height);
    Canvas.Pen.Color := BoneColor(Model.Bones[Segment.BoneIndex].Name);
    Canvas.MoveTo(StartPoint.X, StartPoint.Y);
    Canvas.LineTo(EndPoint.X, EndPoint.Y);
  end;
  Radius := Max(2, Min(Width, Height) div 300);
  Canvas.Pen.Width := 1;
  for Joint in Scene.Joints do
  begin
    EndPoint := ScreenPoint(Joint.Position, Scene.Projection, Camera,
      Width, Height);
    Canvas.Brush.Color := BoneColor(Model.Bones[Joint.BoneIndex].Name);
    Canvas.Pen.Color := Canvas.Brush.Color;
    Canvas.Ellipse(EndPoint.X - Radius, EndPoint.Y - Radius,
      EndPoint.X + Radius + 1, EndPoint.Y + Radius + 1);
  end;
end;

end.
