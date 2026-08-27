unit MmdAiPreviewFocus;

// 最終姿勢の手・指ボーン範囲を投影し、診断画像用カメラを自動調整する。

interface

uses
  PmxModel,
  PmxPose,
  MmdD3DScene;

// all、left_hand、right_hand、handsを検証し、手対象ではズームとパンを設定する。
procedure ApplyPreviewFocus(Model: TPmxModel; const Poses: TPmxBonePoses;
  const FocusName: string; Width, Height: Integer;
  var Camera: TMmdPreviewCamera);

implementation

uses
  System.Math,
  System.StrUtils,
  System.SysUtils;

function IsHandBone(const BoneName, FocusName: string): Boolean;
var
  IsLeft, IsRight: Boolean;
begin
  IsLeft := StartsText(#$5DE6, BoneName);
  IsRight := StartsText(#$53F3, BoneName);
  if SameText(FocusName, 'left_hand') then
    Result := IsLeft
  else if SameText(FocusName, 'right_hand') then
    Result := IsRight
  else
    Result := IsLeft or IsRight;
  Result := Result and
    (ContainsText(BoneName, #$624B#$9996) or
     ContainsText(BoneName, #$624B#$6369) or
     ContainsText(BoneName, #$89AA#$6307) or
     ContainsText(BoneName, #$4EBA#$6307) or
     ContainsText(BoneName, #$4E2D#$6307) or
     ContainsText(BoneName, #$85AC#$6307) or
     ContainsText(BoneName, #$5C0F#$6307));
end;

procedure ApplyPreviewFocus(Model: TPmxModel; const Poses: TPmxBonePoses;
  const FocusName: string; Width, Height: Integer;
  var Camera: TMmdPreviewCamera);
const
  TARGET_NDC_SPAN = 1.45;
var
  Count: Integer;
  Joint: TMmdPreviewJoint;
  MaxX, MaxY, MinX, MinY: Single;
  Point: TPmxVector3;
  Scene: TMmdPreviewScene;
  SpanX, SpanY, Zoom: Single;
begin
  if SameText(FocusName, 'all') or (FocusName = '') then
    Exit;
  if not SameText(FocusName, 'left_hand') and
     not SameText(FocusName, 'right_hand') and
     not SameText(FocusName, 'hands') then
    raise EArgumentException.Create(
      'focus must be all, left_hand, right_hand, or hands.');
  BuildPreviewScene(Model, Poses, nil, EmptyPreviewTarget,
    EmptyPreviewTarget, Scene);
  Count := 0;
  MinX := MaxSingle;
  MinY := MaxSingle;
  MaxX := -MaxSingle;
  MaxY := -MaxSingle;
  Camera.Zoom := 1.0;
  Camera.PanX := 0;
  Camera.PanY := 0;
  for Joint in Scene.Joints do
    if IsHandBone(Model.Bones[Joint.BoneIndex].Name, FocusName) then
    begin
      Point := ProjectPreviewPosition(Joint.Position, Scene.Projection,
        Camera, Width, Height);
      MinX := Min(MinX, Point.X);
      MaxX := Max(MaxX, Point.X);
      MinY := Min(MinY, Point.Y);
      MaxY := Max(MaxY, Point.Y);
      Inc(Count);
    end;
  if Count = 0 then
    raise EArgumentException.CreateFmt(
      'No hand or finger bones were found for focus %s.', [FocusName]);
  SpanX := Max(MaxX - MinX, 0.12);
  SpanY := Max(MaxY - MinY, 0.12);
  Zoom := Min(TARGET_NDC_SPAN / SpanX, TARGET_NDC_SPAN / SpanY);
  Camera.Zoom := EnsureRange(Zoom, 0.2, 5.0);
  Camera.PanX := -((MinX + MaxX) * 0.5 * Camera.Zoom) * Width * 0.5;
  Camera.PanY := ((MinY + MaxY) * 0.5 * Camera.Zoom) * Height * 0.5;
end;

end.
