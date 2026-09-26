unit MMD_Model_PoseTransition;

// 外部ポーズの開始・終了を、モデル側の基準姿勢との間で時間補間する。

interface

uses
  PmxModel,
  PmxPose;

const
  DefaultMmdPoseTransitionTimeSec = 0.30;

type
  TMmdModelPoseTransition = class
  private
    FActivePoseStartFrame: Integer;
    FActivePoseEndFrame: Integer;
    FActiveDurationFrames: Double;
    FEntrySourceBones: TPmxBonePoses;
    FHasEntrySource: Boolean;
    FEntrySourceRoot: TPmxQuaternion;
    FEntrySourceYaw, FEntrySourcePitch: Single;
    FLastFrame: Integer;
    FLastModelFile: string;
    FLastOutputBones: TPmxBonePoses;
    FLastOutputFrame: Integer;
    FLastOutputRoot: TPmxQuaternion;
    FLastOutputYaw, FLastOutputPitch: Single;
    FLastPoseFrame: Integer;
    FLastPoseLayer: Integer;
    FReleaseSourceBones: TPmxBonePoses;
    FHasReleaseSource: Boolean;
    FReleaseSourceRoot: TPmxQuaternion;
    FReleaseSourceYaw, FReleaseSourcePitch: Single;
    FTargetBones: TPmxBonePoses;
    FTargetRoot: TPmxQuaternion;
    FTargetYaw, FTargetPitch: Single;
    procedure Clear;
    procedure RememberOutput(const BonePoses: TPmxBonePoses;
      const RootRotation: TPmxQuaternion; Yaw, Pitch: Single;
      TimelineFrame: Integer);
  public
    constructor Create;
    // 前の表示姿勢または基準姿勢から新Poseへ移行し、不在時は基準姿勢へ戻す。
    function Resolve(const Model: TPmxModel; Received: Boolean;
      const CurrentPoses: TPmxNamedBonePoses;
      const CurrentRootRotation: TPmxQuaternion;
      CurrentYaw, CurrentPitch: Single;
      PoseLayer: Integer; const ModelFile: string; TimelineFrame,
      PoseStartFrame, PoseEndFrame: Integer; Fps, TransitionTimeSec: Double;
      var BonePoses: TPmxBonePoses; var RootRotation: TPmxQuaternion;
      var Yaw, Pitch: Single): Boolean;
  end;

// BasePosesを補間先として、名前付き外部姿勢をWeightだけ上書きする。
function ApplyWeightedNamedBonePoses(const Model: TPmxModel;
  const NamedPoses: TPmxNamedBonePoses; Weight: Single;
  var BasePoses: TPmxBonePoses): Boolean;
// 基準回転から外部回転へ最短経路で補間する。
function BlendRootRotation(const BaseRotation, Rotation: TPmxQuaternion;
  Weight: Single): TPmxQuaternion;

implementation

uses
  System.Math,
  System.SysUtils,
  PmxPoseMath;

function SlerpShortest(const A, B: TPmxQuaternion;
  Amount: Single): TPmxQuaternion; forward;

procedure CopyBonePoses(const Source: TPmxBonePoses;
  var Dest: TPmxBonePoses);
var
  I: Integer;
begin
  SetLength(Dest, Length(Source));
  for I := 0 to High(Source) do
    Dest[I] := Source[I];
end;

procedure BlendBonePoses(const FromPoses, ToPoses: TPmxBonePoses;
  Amount: Single; var Dest: TPmxBonePoses);
var
  I: Integer;
begin
  if Length(FromPoses) <> Length(ToPoses) then Exit;
  Amount := EnsureRange(Amount, 0.0, 1.0);
  for I := 0 to High(ToPoses) do
  begin
    Dest[I].Translation.X := FromPoses[I].Translation.X +
      (ToPoses[I].Translation.X - FromPoses[I].Translation.X) * Amount;
    Dest[I].Translation.Y := FromPoses[I].Translation.Y +
      (ToPoses[I].Translation.Y - FromPoses[I].Translation.Y) * Amount;
    Dest[I].Translation.Z := FromPoses[I].Translation.Z +
      (ToPoses[I].Translation.Z - FromPoses[I].Translation.Z) * Amount;
    Dest[I].Rotation := SlerpShortest(FromPoses[I].Rotation,
      ToPoses[I].Rotation, Amount);
  end;
end;

function BlendAngle(FromAngle, ToAngle, Amount: Single): Single;
var
  Delta: Single;
begin
  Delta := ToAngle - FromAngle;
  if Delta > 180 then Delta := Delta - 360;
  if Delta < -180 then Delta := Delta + 360;
  Result := FromAngle + Delta * Amount;
end;

constructor TMmdModelPoseTransition.Create;
begin
  inherited Create;
  Clear;
end;

procedure TMmdModelPoseTransition.Clear;
begin
  FActivePoseStartFrame := -1;
  FActivePoseEndFrame := -1;
  FActiveDurationFrames := 0;
  FEntrySourceBones := nil;
  FHasEntrySource := False;
  FEntrySourceRoot := IdentityQuaternion;
  FEntrySourceYaw := 0;
  FEntrySourcePitch := 0;
  FLastFrame := -1;
  FLastModelFile := '';
  FLastOutputBones := nil;
  FLastOutputFrame := -1;
  FLastOutputRoot := IdentityQuaternion;
  FLastOutputYaw := 0;
  FLastOutputPitch := 0;
  FLastPoseFrame := -1;
  FLastPoseLayer := -1;
  FReleaseSourceBones := nil;
  FHasReleaseSource := False;
  FReleaseSourceRoot := IdentityQuaternion;
  FReleaseSourceYaw := 0;
  FReleaseSourcePitch := 0;
  FTargetBones := nil;
  FTargetRoot := IdentityQuaternion;
  FTargetYaw := 0;
  FTargetPitch := 0;
end;

procedure TMmdModelPoseTransition.RememberOutput(
  const BonePoses: TPmxBonePoses; const RootRotation: TPmxQuaternion;
  Yaw, Pitch: Single; TimelineFrame: Integer);
begin
  CopyBonePoses(BonePoses, FLastOutputBones);
  FLastOutputRoot := RootRotation;
  FLastOutputYaw := Yaw;
  FLastOutputPitch := Pitch;
  FLastOutputFrame := TimelineFrame;
end;

function TMmdModelPoseTransition.Resolve(const Model: TPmxModel;
  Received: Boolean;
  const CurrentPoses: TPmxNamedBonePoses;
  const CurrentRootRotation: TPmxQuaternion;
  CurrentYaw, CurrentPitch: Single; PoseLayer: Integer;
  const ModelFile: string; TimelineFrame, PoseStartFrame,
  PoseEndFrame: Integer; Fps,
  TransitionTimeSec: Double; var BonePoses: TPmxBonePoses;
  var RootRotation: TPmxQuaternion; var Yaw, Pitch: Single): Boolean;
var
  Amount, DurationFrames, ElapsedFrames: Double;
  ConsecutivePose: Boolean;
  SourceRoot: TPmxQuaternion;
  SourceYaw, SourcePitch: Single;
begin
  Result := False;
  if (Model = nil) or (Length(BonePoses) <> Length(Model.Bones)) then
    Exit;
  if (FLastFrame >= 0) and (TimelineFrame < FLastFrame) then
    Clear;
  if (FLastPoseLayer <> -1) and ((FLastPoseLayer <> PoseLayer) or
    not SameText(FLastModelFile, ModelFile)) then
    Clear;
  FLastFrame := TimelineFrame;

  if Received then
  begin
    if FActivePoseStartFrame <> PoseStartFrame then
    begin
      ConsecutivePose := (FActivePoseEndFrame >= 0) and
        (FActivePoseEndFrame + 1 = PoseStartFrame) and
        (FLastOutputFrame >= FActivePoseStartFrame) and
        (FLastOutputFrame <= FActivePoseEndFrame);
      if (FLastOutputFrame = TimelineFrame - 1) and
        (Length(FLastOutputBones) = Length(BonePoses)) then
      begin
        CopyBonePoses(FLastOutputBones, FEntrySourceBones);
        FEntrySourceRoot := FLastOutputRoot;
        FEntrySourceYaw := FLastOutputYaw;
        FEntrySourcePitch := FLastOutputPitch;
      end;
      if ConsecutivePose and (FLastOutputFrame <> TimelineFrame - 1) and
        FHasEntrySource and
        (Length(FEntrySourceBones) = Length(FTargetBones)) then
      begin
        // 描画を飛ばした場合も、前Poseの終端で見える姿勢から次を始める。
        Amount := 1;
        if FActiveDurationFrames > 0 then
          Amount := EnsureRange((FActivePoseEndFrame -
            FActivePoseStartFrame) / FActiveDurationFrames, 0.0, 1.0);
        BlendBonePoses(FEntrySourceBones, FTargetBones, Amount,
          FEntrySourceBones);
        FEntrySourceRoot := SlerpShortest(FEntrySourceRoot, FTargetRoot,
          Amount);
        FEntrySourceYaw := BlendAngle(FEntrySourceYaw, FTargetYaw, Amount);
        FEntrySourcePitch := FEntrySourcePitch +
          (FTargetPitch - FEntrySourcePitch) * Amount;
      end
      else if (FLastOutputFrame <> TimelineFrame - 1) then
      begin
        FEntrySourceBones := nil;
        FEntrySourceRoot := RootRotation;
        FEntrySourceYaw := Yaw;
        FEntrySourcePitch := Pitch;
      end;
      if Length(FEntrySourceBones) <> Length(BonePoses) then
        CopyBonePoses(BonePoses, FEntrySourceBones);
      FHasEntrySource := True;
      FActivePoseStartFrame := PoseStartFrame;
    end;
    FActivePoseEndFrame := PoseEndFrame;
    Amount := 1;
    if (PoseStartFrame >= 0) and (Fps > 0) and
      (TransitionTimeSec > 0) then
    begin
      DurationFrames := TransitionTimeSec * Fps;
      Amount := EnsureRange((TimelineFrame - PoseStartFrame) /
        DurationFrames, 0.0, 1.0);
    end;
    FActiveDurationFrames := TransitionTimeSec * Fps;
    CopyBonePoses(BonePoses, FTargetBones);
    ApplyWeightedNamedBonePoses(Model, CurrentPoses, 1, FTargetBones);
    FTargetRoot := CurrentRootRotation;
    FTargetYaw := CurrentYaw;
    FTargetPitch := CurrentPitch;
    SourceRoot := RootRotation;
    SourceYaw := Yaw;
    SourcePitch := Pitch;
    if FHasEntrySource and
      (Length(FEntrySourceBones) = Length(BonePoses)) then
    begin
      BlendBonePoses(FEntrySourceBones, FTargetBones, Amount, BonePoses);
      SourceRoot := FEntrySourceRoot;
      SourceYaw := FEntrySourceYaw;
      SourcePitch := FEntrySourcePitch;
    end
    else
      BlendBonePoses(BonePoses, FTargetBones, Amount, BonePoses);
    RootRotation := SlerpShortest(SourceRoot, CurrentRootRotation, Amount);
    Yaw := BlendAngle(SourceYaw, CurrentYaw, Amount);
    Pitch := SourcePitch + (CurrentPitch - SourcePitch) * Amount;
    RememberOutput(BonePoses, RootRotation, Yaw, Pitch, TimelineFrame);
    FLastModelFile := ModelFile;
    FLastPoseFrame := TimelineFrame;
    FLastPoseLayer := PoseLayer;
    FReleaseSourceBones := nil;
    FHasReleaseSource := False;
    Exit(True);
  end;

  if (FLastPoseFrame < 0) or (Fps <= 0) or
    (TransitionTimeSec <= 0) then
  begin
    Clear;
    Exit;
  end;
  ElapsedFrames := TimelineFrame - FLastPoseFrame;
  DurationFrames := TransitionTimeSec * Fps;
  if (ElapsedFrames < 0) or (ElapsedFrames >= DurationFrames) then
  begin
    Clear;
    Exit;
  end;
  if not FHasReleaseSource then
  begin
    CopyBonePoses(FLastOutputBones, FReleaseSourceBones);
    FReleaseSourceRoot := FLastOutputRoot;
    FReleaseSourceYaw := FLastOutputYaw;
    FReleaseSourcePitch := FLastOutputPitch;
    FHasReleaseSource := True;
  end;
  Amount := EnsureRange(1.0 - ElapsedFrames / DurationFrames, 0.0, 1.0);
  BlendBonePoses(BonePoses, FReleaseSourceBones, Amount, BonePoses);
  RootRotation := SlerpShortest(RootRotation, FReleaseSourceRoot, Amount);
  Yaw := BlendAngle(Yaw, FReleaseSourceYaw, Amount);
  Pitch := Pitch + (FReleaseSourcePitch - Pitch) * Amount;
  RememberOutput(BonePoses, RootRotation, Yaw, Pitch, TimelineFrame);
  Result := True;
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

function BlendRootRotation(const BaseRotation, Rotation: TPmxQuaternion;
  Weight: Single): TPmxQuaternion;
begin
  Result := SlerpShortest(BaseRotation, Rotation,
    EnsureRange(Weight, 0.0, 1.0));
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
