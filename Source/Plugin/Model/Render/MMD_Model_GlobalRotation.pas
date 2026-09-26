unit MMD_Model_GlobalRotation;

// ポーズ固有の相対アングルと全身回転を、描画用の骨と頂点へ適用する。

interface

uses
  PmxModel,
  PmxPose;

// モデル表示に対する相対Yaw/Pitchを原点まわりのPMX回転へ変換する。
function PoseRelativeRotation(YawDegrees, PitchDegrees: Single): TPmxQuaternion;
// 原点まわりの回転を描画用配列へ適用する。入力配列だけを変更する。
procedure RotateModelGeometry(const Rotation: TPmxQuaternion;
  var Transforms: TPmxBoneTransforms; var Vertices: TPmxSkinnedVertices);
// 回転が単位Quaternionかを判定する。
function HasModelRotation(const Rotation: TPmxQuaternion): Boolean;

implementation

uses
  PmxPoseMath;

function PoseRelativeRotation(YawDegrees, PitchDegrees: Single): TPmxQuaternion;
begin
  Result := QuaternionFromYawPitchDegrees(YawDegrees, PitchDegrees);
end;

function HasModelRotation(const Rotation: TPmxQuaternion): Boolean;
begin
  Result := (Abs(Rotation.X) + Abs(Rotation.Y) + Abs(Rotation.Z) > 0.000001) or
    (Abs(Abs(Rotation.W) - 1) > 0.000001);
end;

procedure RotateModelGeometry(const Rotation: TPmxQuaternion;
  var Transforms: TPmxBoneTransforms; var Vertices: TPmxSkinnedVertices);
var
  Index: Integer;
begin
  if not HasModelRotation(Rotation) then Exit;
  for Index := 0 to High(Transforms) do
  begin
    Transforms[Index].Position := RotateVector(Rotation,
      Transforms[Index].Position);
    Transforms[Index].Rotation := NormalizeQuaternion(
      MultiplyQuaternion(Rotation, Transforms[Index].Rotation));
  end;
  for Index := 0 to High(Vertices) do
  begin
    Vertices[Index].Position := RotateVector(Rotation,
      Vertices[Index].Position);
    Vertices[Index].Normal := RotateVector(Rotation,
      Vertices[Index].Normal);
  end;
end;

end.
