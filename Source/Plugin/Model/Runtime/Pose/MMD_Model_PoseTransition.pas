unit MMD_Model_PoseTransition;

// 外部ポーズ終了後の姿勢を保持し、モデル側の基準姿勢へ時間補間する。

interface

uses
  PmxModel,
  PmxPose;

const
  DefaultMmdPoseReleaseTimeSec = 0.30;

type
  TMmdModelPoseTransition = class
  private
    FLastFrame: Integer;
    FLastModelFile: string;
    FLastPoseFrame: Integer;
    FLastPoses: TPmxNamedBonePoses;
    FLastPoseLayer: Integer;
    procedure Clear;
  public
    constructor Create;
    // 現在入力を記録し、不在時は解除時間内の直前姿勢と残存率を返す。
    function Resolve(Received: Boolean; const CurrentPoses: TPmxNamedBonePoses;
      PoseLayer: Integer; const ModelFile: string; TimelineFrame: Integer;
      Fps, ReleaseTimeSec: Double; out Poses: TPmxNamedBonePoses;
      out Weight: Single): Boolean;
  end;

// BasePosesを補間先として、名前付き外部姿勢をWeightだけ上書きする。
function ApplyWeightedNamedBonePoses(const Model: TPmxModel;
  const NamedPoses: TPmxNamedBonePoses; Weight: Single;
  var BasePoses: TPmxBonePoses): Boolean;

implementation

uses
  System.Math,
  System.SysUtils,
  PmxPoseMath;

constructor TMmdModelPoseTransition.Create;
begin
  inherited Create;
  Clear;
end;

procedure TMmdModelPoseTransition.Clear;
begin
  FLastFrame := -1;
  FLastModelFile := '';
  FLastPoseFrame := -1;
  FLastPoses := nil;
  FLastPoseLayer := -1;
end;

function TMmdModelPoseTransition.Resolve(Received: Boolean;
  const CurrentPoses: TPmxNamedBonePoses; PoseLayer: Integer;
  const ModelFile: string; TimelineFrame: Integer; Fps,
  ReleaseTimeSec: Double; out Poses: TPmxNamedBonePoses;
  out Weight: Single): Boolean;
var
  DurationFrames, ElapsedFrames: Double;
begin
  Result := False;
  Poses := nil;
  Weight := 0;
  if (FLastFrame >= 0) and (TimelineFrame < FLastFrame) then
    Clear;
  if (FLastPoseLayer <> -1) and ((FLastPoseLayer <> PoseLayer) or
    not SameText(FLastModelFile, ModelFile)) then
    Clear;
  FLastFrame := TimelineFrame;

  if Received then
  begin
    FLastModelFile := ModelFile;
    FLastPoseFrame := TimelineFrame;
    FLastPoses := Copy(CurrentPoses);
    FLastPoseLayer := PoseLayer;
    Poses := Copy(CurrentPoses);
    Weight := 1;
    Exit(Length(Poses) > 0);
  end;

  if (Length(FLastPoses) = 0) or (Fps <= 0) or
    (ReleaseTimeSec <= 0) then
  begin
    Clear;
    Exit;
  end;
  ElapsedFrames := TimelineFrame - FLastPoseFrame;
  DurationFrames := ReleaseTimeSec * Fps;
  if (ElapsedFrames < 0) or (ElapsedFrames >= DurationFrames) then
  begin
    Clear;
    Exit;
  end;
  Weight := EnsureRange(1.0 - ElapsedFrames / DurationFrames, 0.0, 1.0);
  Poses := Copy(FLastPoses);
  Result := Weight > 0;
end;

function SlerpShortest(const A, B: TPmxQuaternion;
  Amount: Single): TPmxQuaternion;
var
  Angle, Dot, ScaleA, ScaleB, SinAngle: Single;
  EndRotation: TPmxQuaternion;
begin
  Result := NormalizeQuaternion(A);
  EndRotation := NormalizeQuaternion(B);
  Dot := Result.X * EndRotation.X + Result.Y * EndRotation.Y +
    Result.Z * EndRotation.Z + Result.W * EndRotation.W;
  if Dot < 0 then
  begin
    Dot := -Dot;
    EndRotation.X := -EndRotation.X;
    EndRotation.Y := -EndRotation.Y;
    EndRotation.Z := -EndRotation.Z;
    EndRotation.W := -EndRotation.W;
  end;
  if Dot > 0.9995 then
  begin
    Result.X := Result.X + (EndRotation.X - Result.X) * Amount;
    Result.Y := Result.Y + (EndRotation.Y - Result.Y) * Amount;
    Result.Z := Result.Z + (EndRotation.Z - Result.Z) * Amount;
    Result.W := Result.W + (EndRotation.W - Result.W) * Amount;
    Exit(NormalizeQuaternion(Result));
  end;
  Angle := ArcCos(EnsureRange(Dot, -1.0, 1.0));
  SinAngle := Sin(Angle);
  if Abs(SinAngle) <= 0.000001 then Exit;
  ScaleA := Sin((1.0 - Amount) * Angle) / SinAngle;
  ScaleB := Sin(Amount * Angle) / SinAngle;
  Result.X := Result.X * ScaleA + EndRotation.X * ScaleB;
  Result.Y := Result.Y * ScaleA + EndRotation.Y * ScaleB;
  Result.Z := Result.Z * ScaleA + EndRotation.Z * ScaleB;
  Result.W := Result.W * ScaleA + EndRotation.W * ScaleB;
  Result := NormalizeQuaternion(Result);
end;

function ApplyWeightedNamedBonePoses(const Model: TPmxModel;
  const NamedPoses: TPmxNamedBonePoses; Weight: Single;
  var BasePoses: TPmxBonePoses): Boolean;
var
  BoneIndex: Integer;
  NamedPose: TPmxNamedBonePose;
begin
  Result := False;
  if (Model = nil) or (Length(BasePoses) <> Length(Model.Bones)) then Exit;
  Weight := EnsureRange(Weight, 0.0, 1.0);
  for NamedPose in NamedPoses do
  begin
    BoneIndex := FindBoneIndex(Model, NamedPose.BoneName);
    if BoneIndex < 0 then Continue;
    BasePoses[BoneIndex].Translation.X :=
      BasePoses[BoneIndex].Translation.X +
      (NamedPose.Pose.Translation.X - BasePoses[BoneIndex].Translation.X) * Weight;
    BasePoses[BoneIndex].Translation.Y :=
      BasePoses[BoneIndex].Translation.Y +
      (NamedPose.Pose.Translation.Y - BasePoses[BoneIndex].Translation.Y) * Weight;
    BasePoses[BoneIndex].Translation.Z :=
      BasePoses[BoneIndex].Translation.Z +
      (NamedPose.Pose.Translation.Z - BasePoses[BoneIndex].Translation.Z) * Weight;
    BasePoses[BoneIndex].Rotation := SlerpShortest(
      BasePoses[BoneIndex].Rotation, NamedPose.Pose.Rotation, Weight);
    Result := True;
  end;
end;

end.
