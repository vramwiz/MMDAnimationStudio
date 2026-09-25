program MmdSimpleControllerSolverTest;

{$APPTYPE CONSOLE}

uses
  System.IOUtils,
  System.Math,
  System.SysUtils,
  PmxBoneSolver,
  PmxModel,
  PmxPose,
  PmxPoseCodec,
  PmxPoseMath,
  PmxReader,
  MmdSimpleControllerSolver;

procedure Check(Value: Boolean; const Text: string);
begin
  if not Value then raise Exception.Create(Text);
end;

function Distance(const A, B: TPmxVector3): Single;
begin
  Result := Sqrt(Sqr(A.X - B.X) + Sqr(A.Y - B.Y) + Sqr(A.Z - B.Z));
end;

function RotationAlignment(const A, B: TPmxQuaternion): Single;
begin
  Result := Abs(A.X * B.X + A.Y * B.Y + A.Z * B.Z + A.W * B.W);
end;

function ScreenY(const Position: TPmxVector3;
  Yaw, Pitch: Single): Single;
begin
  Result := Position.Y * Cos(Pitch) +
    (Position.X * Sin(Yaw) - Position.Z * Cos(Yaw)) * Sin(Pitch);
end;

function HandTipForTest(const Model: TPmxModel; Wrist: Integer): Integer;
var
  I, Parent, Steps: Integer;
  CandidateDistance, BestDistance: Single;
begin
  Result := -1;
  BestDistance := 0;
  for I := 0 to High(Model.Bones) do
  begin
    Parent := Model.Bones[I].ParentIndex;
    Steps := 0;
    while (Parent >= 0) and (Parent < Length(Model.Bones)) and
      (Parent <> Wrist) and (Steps < Length(Model.Bones)) do
    begin
      Parent := Model.Bones[Parent].ParentIndex;
      Inc(Steps);
    end;
    if Parent <> Wrist then Continue;
    CandidateDistance := Distance(Model.Bones[I].Position,
      Model.Bones[Wrist].Position);
    if CandidateDistance > BestDistance then
    begin
      Result := I;
      BestDistance := CandidateDistance;
    end;
  end;
end;

procedure CheckBendAdjustment(const Model: TPmxModel;
  const BasePoses: TPmxBonePoses; Controller: TMmdSimpleController);
var
  MovedPoses, BentPoses, ReversePoses,
    WrongPoses, CorrectedPoses: TPmxBonePoses;
  BeforeTransforms, AfterTransforms, ReverseTransforms,
    CorrectedTransforms: TPmxBoneTransforms;
  WorldMove, WorldTurn, Axis, Direction, Pole,
    BindDirection: TPmxVector3;
  Root, Joint, Tip: Integer;
  IsFoot, LeftSide: Boolean;
  BendDirection: Single;
begin
  IsFoot := Controller in [scLeftFoot, scRightFoot];
  LeftSide := Controller in [scLeftHand, scLeftFoot];
  if IsFoot then
  begin
    if LeftSide then
    begin
      Root := FindBoneIndex(Model, '左足');
      Joint := FindBoneIndex(Model, '左ひざ');
      Tip := FindBoneIndex(Model, '左足首');
    end
    else
    begin
      Root := FindBoneIndex(Model, '右足');
      Joint := FindBoneIndex(Model, '右ひざ');
      Tip := FindBoneIndex(Model, '右足首');
    end;
  end
  else if LeftSide then
  begin
    Root := FindBoneIndex(Model, '左腕');
    Joint := FindBoneIndex(Model, '左ひじ');
    Tip := FindBoneIndex(Model, '左手首');
  end
  else
  begin
    Root := FindBoneIndex(Model, '右腕');
    Joint := FindBoneIndex(Model, '右ひじ');
    Tip := FindBoneIndex(Model, '右手首');
  end;
  Check((Root >= 0) and (Joint >= 0) and (Tip >= 0),
    'bend test chain is unavailable');
  WorldMove := Default(TPmxVector3);
  WorldTurn := Default(TPmxVector3);
  if IsFoot then WorldMove.Y := 0.5
  else if LeftSide then WorldMove.X := -0.5
  else WorldMove.X := 0.5;
  Check(ApplySimpleControllerWorldWithTwistAndBend(Model, BasePoses,
    Controller, WorldMove, WorldTurn, 0, 0, MovedPoses),
    'natural limb bend failed');
  CalculateInteractiveBoneTransforms(Model, MovedPoses, BeforeTransforms);
  Direction := SubtractVector(BeforeTransforms[Tip].Position,
    BeforeTransforms[Root].Position);
  Direction := NormalizeVector(Direction);
  BindDirection := NormalizeVector(SubtractVector(
    Model.Bones[Tip].Position, Model.Bones[Root].Position));
  Axis := SubtractVector(Model.Bones[Joint].Position,
    Model.Bones[Root].Position);
  Axis := SubtractVector(Axis, ScaleVector(BindDirection,
    DotVector(Axis, BindDirection)));
  if Distance(Axis, Default(TPmxVector3)) <
    Distance(Model.Bones[Tip].Position,
      Model.Bones[Root].Position) * 0.01 then
  begin
    Axis := Default(TPmxVector3);
    Axis.Z := 1;
  end;
  Axis := SubtractVector(Axis, ScaleVector(Direction,
    DotVector(Axis, Direction)));
  Pole := SubtractVector(BeforeTransforms[Joint].Position,
    BeforeTransforms[Root].Position);
  Pole := SubtractVector(Pole, ScaleVector(Direction,
    DotVector(Pole, Direction)));
  Check(DotVector(Pole, Axis) > 0.01,
    Format('elbow or knee bent behind the natural side '+
      '(model=%s controller=%d dot=%g)',
      [Model.Name, Ord(Controller), DotVector(Pole, Axis)]));
  // 手足を一度広げなくても、逆へ折れた姿勢から次の入力で自然な側へ戻る。
  WrongPoses := Copy(MovedPoses);
  WrongPoses[Root].Rotation := NormalizeQuaternion(MultiplyQuaternion(
    QuaternionFromAxisAngle(Direction, Pi),
    WrongPoses[Root].Rotation));
  WorldMove := Default(TPmxVector3);
  WorldMove.Y := 0.1;
  Check(ApplySimpleControllerWorldWithTwistAndBend(Model, WrongPoses,
    Controller, WorldMove, WorldTurn, 0, 0, CorrectedPoses),
    'wrong-side bend recovery failed');
  CalculateInteractiveBoneTransforms(Model, CorrectedPoses,
    CorrectedTransforms);
  Direction := NormalizeVector(SubtractVector(
    CorrectedTransforms[Tip].Position,
    CorrectedTransforms[Root].Position));
  Pole := SubtractVector(CorrectedTransforms[Joint].Position,
    CorrectedTransforms[Root].Position);
  Pole := SubtractVector(Pole, ScaleVector(Direction,
    DotVector(Pole, Direction)));
  Axis := SubtractVector(Axis, ScaleVector(Direction,
    DotVector(Axis, Direction)));
  Check(DotVector(Pole, Axis) > 0.01,
    Format('wrong-side joint did not recover '+
      '(model=%s controller=%d dot=%g)',
      [Model.Name, Ord(Controller), DotVector(Pole, Axis)]));
  Direction := NormalizeVector(SubtractVector(
    BeforeTransforms[Tip].Position,
    BeforeTransforms[Root].Position));
  Pole := SubtractVector(BeforeTransforms[Joint].Position,
    BeforeTransforms[Root].Position);
  Pole := SubtractVector(Pole, ScaleVector(Direction,
    DotVector(Pole, Direction)));
  Axis := SubtractVector(Axis, ScaleVector(Direction,
    DotVector(Axis, Direction)));
  BendDirection := 1;
  if ArcTan2(DotVector(CrossVector(NormalizeVector(Axis),
    NormalizeVector(Pole)), Direction),
    DotVector(NormalizeVector(Axis), NormalizeVector(Pole))) > 0 then
    BendDirection := -1;
  WorldMove := Default(TPmxVector3);
  Check(ApplySimpleControllerWorldWithTwistAndBend(Model, MovedPoses,
    Controller, WorldMove, WorldTurn, 0, BendDirection * 0.5, BentPoses),
    'manual pole adjustment failed');
  CalculateInteractiveBoneTransforms(Model, BentPoses, AfterTransforms);
  Check(Distance(BeforeTransforms[Joint].Position,
    AfterTransforms[Joint].Position) > 0.01,
    Format('manual pole adjustment did not move the elbow or knee '+
      '(model=%s controller=%d delta=%g)',
      [Model.Name, Ord(Controller),
      Distance(BeforeTransforms[Joint].Position,
        AfterTransforms[Joint].Position)]));
  Check(Distance(BeforeTransforms[Tip].Position,
    AfterTransforms[Tip].Position) < 0.02,
    'manual pole adjustment moved the hand or foot target');
  Check(RotationAlignment(BeforeTransforms[Tip].Rotation,
    AfterTransforms[Tip].Rotation) > 0.9999,
    'manual pole adjustment turned the hand or foot');
  Check(ApplySimpleControllerWorldWithTwistAndBend(Model, BentPoses,
    Controller, WorldMove, WorldTurn, 0, -BendDirection * 0.5,
    ReversePoses),
    'reverse pole adjustment failed');
  CalculateInteractiveBoneTransforms(Model, ReversePoses, ReverseTransforms);
  Check(Distance(AfterTransforms[Joint].Position,
    ReverseTransforms[Joint].Position) > 0.01,
    'reverse pole adjustment did not move the joint');
  Check(Distance(AfterTransforms[Tip].Position,
    ReverseTransforms[Tip].Position) < 0.02,
    'reverse pole adjustment moved the endpoint');
end;

procedure CheckEyeGaze(const Model: TPmxModel;
  const BasePoses: TPmxBonePoses);
var
  MovedPoses, StepPoses, ResetPoses, HeadPoses: TPmxBonePoses;
  BeforeTransforms, AfterTransforms: TPmxBoneTransforms;
  ForwardAxis, BeforeForward, AfterForward, Angles: TPmxVector3;
  SharedEye, LeftEye, RightEye, Head, StepIndex: Integer;
  LimitYaw: Single;
  FallbackModel: TPmxModel;
begin
  SharedEye := FindBoneIndex(Model, '両目');
  LeftEye := FindBoneIndex(Model, '左目');
  RightEye := FindBoneIndex(Model, '右目');
  Head := FindBoneIndex(Model, '頭');
  Check((SharedEye >= 0) and (LeftEye >= 0) and (RightEye >= 0),
    'eye gaze test bones are unavailable');
  Check(CanUseSimpleController(Model, scEyes), 'eye gaze is unavailable');
  Check(SimpleControllerTargetBone(Model, scEyes) = LeftEye,
    'eye marker is not on an eye');
  Check(ApplySimpleController3D(Model, BasePoses, scEyes,
    0.4, 0.3, 0, 0, 0, MovedPoses), 'eye gaze input failed');
  CalculateInteractiveBoneTransforms(Model, BasePoses, BeforeTransforms);
  CalculateInteractiveBoneTransforms(Model, MovedPoses, AfterTransforms);
  ForwardAxis := Default(TPmxVector3);
  ForwardAxis.Z := -1;
  BeforeForward := RotateVector(BeforeTransforms[LeftEye].Rotation,
    ForwardAxis);
  AfterForward := RotateVector(AfterTransforms[LeftEye].Rotation,
    ForwardAxis);
  Check((AfterForward.X > BeforeForward.X + 0.03) and
    (AfterForward.Y > BeforeForward.Y + 0.03),
    'left eye did not look screen right and up');
  BeforeForward := RotateVector(BeforeTransforms[RightEye].Rotation,
    ForwardAxis);
  AfterForward := RotateVector(AfterTransforms[RightEye].Rotation,
    ForwardAxis);
  Check((AfterForward.X > BeforeForward.X + 0.03) and
    (AfterForward.Y > BeforeForward.Y + 0.03),
    'right eye did not follow shared gaze');
  Check(Distance(BeforeTransforms[LeftEye].Position,
    AfterTransforms[LeftEye].Position) < 0.001,
    'eye gaze moved the eye pivot');
  Check(RotationAlignment(BasePoses[Head].Rotation,
    MovedPoses[Head].Rotation) > 0.99999,
    'eye gaze changed the head pose');
  Check(ApplySimpleController3D(Model, BasePoses, scEyes,
    0.4, 0.3, 0, Pi * 0.5, 0.3, StepPoses),
    'eye gaze from a side view failed');
  Check(RotationAlignment(StepPoses[SharedEye].Rotation,
    MovedPoses[SharedEye].Rotation) > 0.99999,
    'camera angle changed face-relative eye input');
  HeadPoses := Copy(BasePoses);
  HeadPoses[Head].Rotation := QuaternionFromEulerXYZ(0.2, 0.5, 0);
  Check(ApplySimpleController3D(Model, HeadPoses, scEyes,
    0.4, 0.3, 0, 0, 0, StepPoses),
    'eye gaze with a turned head failed');
  Check(RotationAlignment(StepPoses[SharedEye].Rotation,
    MovedPoses[SharedEye].Rotation) > 0.99999,
    'head rotation changed face-relative eye input');
  for StepIndex := 1 to 100 do
  begin
    Check(ApplySimpleController3D(Model, MovedPoses, scEyes,
      1, 1, 0, 0, 0, StepPoses), 'eye gaze limit step failed');
    MovedPoses := StepPoses;
  end;
  Angles := QuaternionToEulerXYZ(MovedPoses[SharedEye].Rotation);
  Check((Abs(Angles.X) <= 0.351) and (Abs(Angles.Y) <= 0.451),
    'eye gaze exceeded its angle limits');
  LimitYaw := Angles.Y;
  Check(ApplySimpleController3D(Model, MovedPoses, scEyes,
    -0.5, 0, 0, 0, 0, StepPoses), 'reverse eye gaze failed');
  Angles := QuaternionToEulerXYZ(StepPoses[SharedEye].Rotation);
  Check(Angles.Y > LimitYaw + 0.01,
    'eye gaze did not reverse immediately at its limit');
  Check(ResetSimpleController(Model, StepPoses, scEyes, ResetPoses),
    'eye gaze reset failed');
  Check(RotationAlignment(ResetPoses[SharedEye].Rotation,
    IdentityQuaternion) > 0.99999, 'eye gaze reset left a rotation');
  FallbackModel := TPmxModel.Create;
  try
    FallbackModel.Bones := Copy(Model.Bones);
    FallbackModel.Bones[LeftEye].Flags :=
      FallbackModel.Bones[LeftEye].Flags and
      not PMX_BONE_FLAG_INHERIT_ROTATION;
    FallbackModel.Bones[RightEye].Flags :=
      FallbackModel.Bones[RightEye].Flags and
      not PMX_BONE_FLAG_INHERIT_ROTATION;
    Check(ApplySimpleController3D(FallbackModel, BasePoses, scEyes,
      0.4, 0.3, 0, 0, 0, StepPoses),
      'separate-eye gaze input failed');
    Check((RotationAlignment(StepPoses[LeftEye].Rotation,
      IdentityQuaternion) < 0.999) and
      (RotationAlignment(StepPoses[RightEye].Rotation,
      IdentityQuaternion) < 0.999) and
      (RotationAlignment(StepPoses[SharedEye].Rotation,
      IdentityQuaternion) > 0.99999),
      'separate-eye gaze did not use both eye bones');
  finally
    FallbackModel.Free;
  end;
end;

procedure CheckModel(const Path: string; ModelNumber: Integer);
var
  BasePoses, NewPoses, RepeatedPoses, ResetPoses,
    TwistPoses, CombinedPoses, PitchPoses, ZeroPoses, ViewPoses,
    RaisedPoses, LoweredPoses: TPmxBonePoses;
  BaseTransforms, NewTransforms, TwistTransforms,
    FinalTransforms: TPmxBoneTransforms;
  Controller: TMmdSimpleController;
  Model: TPmxModel;
  NamedPoses: TPmxNamedBonePoses;
  BoneIndex, Count, Elbow, StepIndex, Wrist, HandTip,
    Leg, Knee, Ankle, OtherAnkle: Integer;
  TwistChanged: Boolean;
  PreviousY, Yaw, Pitch, BeforeScreenY, AfterScreenY: Single;
  ExtremePoses: array[0..1] of TPmxBonePoses;
  ExtremeIndex, InputSign, ViewIndex, AxisIndex, AngleIndex, Arm: Integer;
  Axis, FootForward, PitchedForward: TPmxVector3;
  WorldMove, WorldTurn: TPmxVector3;
begin
  Check(FileExists(Path), 'model file is missing: ' + Path);
  Model := GetCachedPmxModel(Path);
  Check(Model <> nil, 'PMX could not be loaded');
  InitializeBonePoses(Model, BasePoses);
  CalculateInteractiveBoneTransforms(Model, BasePoses, BaseTransforms);
  CheckEyeGaze(Model, BasePoses);
  // カメラを回した後の追加入力だけが新しい画面方向へ動く。
  WorldMove := Default(TPmxVector3);
  WorldTurn := Default(TPmxVector3);
  AccumulateSimpleControllerViewInput(scCenter, 0.3, 0, 0,
    0, 0, WorldMove, WorldTurn);
  Check(ApplySimpleControllerWorldWithTwist(Model, BasePoses,
    scCenter, WorldMove, WorldTurn, 0, ViewPoses),
    'first view movement failed');
  BoneIndex := FindBoneIndex(Model, 'センター');
  Check((BoneIndex >= 0) and
    (ViewPoses[BoneIndex].Translation.X > 0.01) and
    (Abs(ViewPoses[BoneIndex].Translation.Z) < 0.001),
    'front view right movement is not screen-aligned');
  AccumulateSimpleControllerViewInput(scCenter, 0.3, 0, 0,
    Pi * 0.5, 0, WorldMove, WorldTurn);
  Check(ApplySimpleControllerWorldWithTwist(Model, BasePoses,
    scCenter, WorldMove, WorldTurn, 0, ViewPoses),
    'rotated view movement failed');
  Check((ViewPoses[BoneIndex].Translation.X > 0.01) and
    (ViewPoses[BoneIndex].Translation.Z > 0.01),
    'camera rotation changed previous movement or ignored new view');
  WorldMove := Default(TPmxVector3);
  WorldTurn := Default(TPmxVector3);
  AccumulateSimpleControllerViewInput(scCenter, 0, 0, 0.3,
    Pi * 0.5, 0, WorldMove, WorldTurn);
  Check((WorldMove.X < -0.29) and (Abs(WorldMove.Z) < 0.001),
    'R depth is not relative to rotated view');
  WorldMove := Default(TPmxVector3);
  WorldTurn := Default(TPmxVector3);
  AccumulateSimpleControllerViewInput(scCenter, 0, 0.3, 0,
    0, Pi * 0.25, WorldMove, WorldTurn);
  Check((WorldMove.Y > 0.2) and (WorldMove.Z < -0.2),
    'up movement is not relative to camera pitch');
  WorldMove := Default(TPmxVector3);
  WorldTurn := Default(TPmxVector3);
  AccumulateSimpleControllerViewInput(scHead, 0, 0.3, 0.2,
    Pi * 0.5, 0, WorldMove, WorldTurn);
  Check((WorldTurn.Z < -0.1) and (WorldMove.X < -0.19),
    'head turn and depth are not relative to side view');
  Check(ApplySimpleControllerWorldWithTwist(Model, BasePoses,
    scHead, WorldMove, WorldTurn, 0, ViewPoses),
    'view-relative head movement failed');
  WorldMove := Default(TPmxVector3);
  WorldTurn := Default(TPmxVector3);
  AccumulateSimpleControllerViewInput(scUpperBody, 0.3, 0, 0.2,
    Pi * 0.5, 0, WorldMove, WorldTurn);
  Check((WorldTurn.X > 0.07) and (WorldMove.X < -0.19),
    'upper body turn and depth are not relative to side view');
  Check(ApplySimpleControllerWorldWithTwist(Model, BasePoses,
    scUpperBody, WorldMove, WorldTurn, 0, ViewPoses),
    'view-relative upper body movement failed');
  BoneIndex := FindBoneIndex(Model, '上半身');
  Wrist := FindBoneIndex(Model, '左手首');
  Ankle := FindBoneIndex(Model, '左足首');
  Check((BoneIndex >= 0) and (Wrist >= 0) and (Ankle >= 0),
    'waist test bones are unavailable');
  Check(ApplySimpleController3D(Model, BasePoses, scWaist,
    0.5, 0, 0, 0, 0, ViewPoses), 'waist rotation failed');
  CalculateInteractiveBoneTransforms(Model, ViewPoses, NewTransforms);
  Check(Abs(ViewPoses[BoneIndex].Rotation.Y) > 0.05,
    'waist horizontal input did not turn the lower torso');
  Check(Distance(BaseTransforms[Wrist].Position,
    NewTransforms[Wrist].Position) > 0.02,
    'waist rotation did not move the upper body');
  Check(Distance(BaseTransforms[Ankle].Position,
    NewTransforms[Ankle].Position) < 0.001,
    'waist rotation moved the leg');
  Check(ApplySimpleController3D(Model, BasePoses, scWaist,
    0, 0.5, 0, 0, 0, ViewPoses), 'waist forward lean failed');
  Check(Abs(ViewPoses[BoneIndex].Rotation.X) > 0.04,
    'waist vertical input did not bend the lower torso');
  Check(ResetSimpleController(Model, ViewPoses, scWaist, ResetPoses),
    'waist reset failed');
  Check(Abs(ResetPoses[BoneIndex].Rotation.X) < 0.0001,
    'waist reset left a rotation');
  for Controller := Low(TMmdSimpleController) to High(TMmdSimpleController) do
  begin
    Check(CanUseSimpleController(Model, Controller),
      Format('controller %d is unavailable in %s', [Ord(Controller), Path]));
    Check(SimpleControllerTargetBone(Model, Controller) >= 0,
      Format('controller %d has no visible target', [Ord(Controller)]));
    Check(ApplySimpleController(Model, BasePoses, Controller,
      0.35, 0.45, 0, 0, NewPoses),
      Format('controller %d failed', [Ord(Controller)]));
    Check(Length(NewPoses) = Length(BasePoses),
      'controller changed the bone count');
    for BoneIndex := 0 to High(BasePoses) do
      Check((BasePoses[BoneIndex].Rotation.W = 1.0) and
        (BasePoses[BoneIndex].Translation.X = 0.0) and
        (BasePoses[BoneIndex].Translation.Y = 0.0) and
        (BasePoses[BoneIndex].Translation.Z = 0.0),
        'controller modified its input pose');
    Check(ApplySimpleController(Model, BasePoses, Controller,
      0, 0, 0, 0, ZeroPoses), 'zero input failed');
    Check(ApplySimpleController3DWithTwist(Model, BasePoses,
      Controller, 0, 0, 0, 0.5, 0, 0, TwistPoses),
      'axis rotation failed');
    TwistChanged := False;
    for BoneIndex := 0 to High(TwistPoses) do
      if Abs(TwistPoses[BoneIndex].Rotation.W -
        BasePoses[BoneIndex].Rotation.W) > 0.01 then
        TwistChanged := True;
    if Controller <> scEyes then
      Check(TwistChanged, 'axis rotation changed no bone');
    Check(ApplySimpleController(Model, BasePoses, Controller,
      0.35, 0.45, 0, 0, RepeatedPoses), 'repeat input failed');
    for BoneIndex := 0 to High(BasePoses) do
    begin
      Check((ZeroPoses[BoneIndex].Rotation.X = BasePoses[BoneIndex].Rotation.X) and
        (ZeroPoses[BoneIndex].Rotation.Y = BasePoses[BoneIndex].Rotation.Y) and
        (ZeroPoses[BoneIndex].Rotation.Z = BasePoses[BoneIndex].Rotation.Z) and
        (ZeroPoses[BoneIndex].Rotation.W = BasePoses[BoneIndex].Rotation.W),
        'zero input changed the pose');
      Check((RepeatedPoses[BoneIndex].Rotation.X = NewPoses[BoneIndex].Rotation.X) and
        (RepeatedPoses[BoneIndex].Rotation.Y = NewPoses[BoneIndex].Rotation.Y) and
        (RepeatedPoses[BoneIndex].Rotation.Z = NewPoses[BoneIndex].Rotation.Z) and
        (RepeatedPoses[BoneIndex].Rotation.W = NewPoses[BoneIndex].Rotation.W),
        'repeat input is not deterministic');
    end;
    Check(ResetSimpleController(Model, NewPoses, Controller, ResetPoses),
      'controller reset failed');
    Check(Length(ResetPoses) = Length(BasePoses),
      'controller reset changed the bone count');
    if Controller = scCenter then
    begin
      Check(ApplySimpleController3D(Model, BasePoses, Controller,
        0, 0, 0.5, 0, 0, RepeatedPoses), 'depth input failed');
      BoneIndex := FindBoneIndex(Model, 'センター');
      Check((BoneIndex >= 0) and
        (RepeatedPoses[BoneIndex].Translation.Z > 0.01),
        'depth input did not move the center');
    end;
    if Controller in [scLeftHand, scRightHand] then
    begin
      if Controller = scLeftHand then
      begin
        Elbow := FindBoneIndex(Model, '左ひじ');
        Wrist := FindBoneIndex(Model, '左手首')
      end
      else
      begin
        Elbow := FindBoneIndex(Model, '右ひじ');
        Wrist := FindBoneIndex(Model, '右手首');
      end;
      Check((Elbow >= 0) and (Wrist >= 0),
        'test forearm is unavailable');
      Check(SimpleControllerTargetBone(Model, Controller) = Wrist,
        'hand marker is not on the wrist');
      CalculateInteractiveBoneTransforms(Model, NewPoses, NewTransforms);
      Check(Distance(BaseTransforms[Wrist].Position,
        NewTransforms[Wrist].Position) > 0.02,
        'hand target did not move the wrist');
      Check(ApplySimpleController3DWithTwist(Model, BasePoses,
        Controller, 0, 0, 0, 0.5, 0, 0, TwistPoses),
        'hand axial rotation failed');
      Check(Abs(TwistPoses[Elbow].Rotation.W -
        BasePoses[Elbow].Rotation.W) > 0.01,
        'hand axial rotation did not twist the forearm');
      CalculateInteractiveBoneTransforms(Model, TwistPoses,
        TwistTransforms);
      Check(Distance(BaseTransforms[Wrist].Position,
        TwistTransforms[Wrist].Position) < 0.001,
        'hand axial rotation moved the wrist');
      HandTip := HandTipForTest(Model, Wrist);
      Check(HandTip >= 0, 'hand has no finger tip for pitch test');
      WorldMove := Default(TPmxVector3);
      WorldTurn := Default(TPmxVector3);
      Check(ApplySimpleControllerWorldWithExtras(Model, BasePoses,
        Controller, WorldMove, WorldTurn, 0, 0, 0.5,
        0, 0, PitchPoses), 'hand tip pitch failed');
      CalculateInteractiveBoneTransforms(Model, PitchPoses,
        NewTransforms);
      Check(Distance(BaseTransforms[Wrist].Position,
        NewTransforms[Wrist].Position) < 0.001,
        'hand tip pitch moved the wrist');
      Check(Distance(BaseTransforms[Elbow].Position,
        NewTransforms[Elbow].Position) < 0.001,
        'hand tip pitch moved the elbow');
      Check(ScreenY(NewTransforms[HandTip].Position, 0, 0) >
        ScreenY(BaseTransforms[HandTip].Position, 0, 0) + 0.05,
        'X+vertical did not lift the hand tip');
      Check(ApplySimpleControllerWorldWithExtras(Model, BasePoses,
        Controller, WorldMove, WorldTurn, 0, 0, -0.5,
        0, 0, PitchPoses), 'reverse hand tip pitch failed');
      CalculateInteractiveBoneTransforms(Model, PitchPoses,
        NewTransforms);
      Check(ScreenY(NewTransforms[HandTip].Position, 0, 0) <
        ScreenY(BaseTransforms[HandTip].Position, 0, 0) - 0.05,
        'X+vertical did not lower the hand tip');
      Check(ApplySimpleControllerWorldWithExtras(Model, BasePoses,
        Controller, WorldMove, WorldTurn, 0, 0, 0.5,
        Pi * 0.5, 0.4, PitchPoses),
        'view-relative hand tip pitch failed');
      CalculateInteractiveBoneTransforms(Model, PitchPoses,
        NewTransforms);
      Check(ScreenY(NewTransforms[HandTip].Position, Pi * 0.5, 0.4) >
        ScreenY(BaseTransforms[HandTip].Position, Pi * 0.5, 0.4) + 0.05,
        'hand tip pitch did not follow the camera up direction');
      CalculateInteractiveBoneTransforms(Model, NewPoses, NewTransforms);
      Check(ApplySimpleController3DWithTwist(Model, BasePoses,
        Controller, 0.35, 0.45, 0, 0.5, 0, 0, CombinedPoses),
        'combined hand translation and rotation failed');
      CalculateInteractiveBoneTransforms(Model, CombinedPoses,
        TwistTransforms);
      Check(Distance(NewTransforms[Wrist].Position,
        TwistTransforms[Wrist].Position) < 0.001,
        'axial rotation changed the hand target');
      Check(ApplySimpleController3D(Model, BasePoses, Controller,
        0, 1, 0, 0, 0, RaisedPoses), 'raising hand failed');
      Check(ApplySimpleController3D(Model, RaisedPoses, Controller,
        0, -1, 0, 0, 0, LoweredPoses),
        'lowering raised hand failed');
      CalculateInteractiveBoneTransforms(Model, RaisedPoses, NewTransforms);
      CalculateInteractiveBoneTransforms(Model, LoweredPoses,
        TwistTransforms);
      Check(TwistTransforms[Wrist].Position.Y <
        NewTransforms[Wrist].Position.Y - 0.05,
        'raising then lowering did not move the wrist down');
      Check(ApplySimpleController3D(Model, BasePoses, Controller,
        0, -1, 0, 0, 0, LoweredPoses), 'lowering hand failed');
      Check(ApplySimpleController3D(Model, LoweredPoses, Controller,
        0, 1, 0, 0, 0, RaisedPoses),
        'raising lowered hand failed');
      CalculateInteractiveBoneTransforms(Model, LoweredPoses,
        NewTransforms);
      CalculateInteractiveBoneTransforms(Model, RaisedPoses,
        TwistTransforms);
      Check(TwistTransforms[Wrist].Position.Y >
        NewTransforms[Wrist].Position.Y + 0.05,
        'lowering then raising did not move the wrist up');
      RaisedPoses := Copy(BasePoses);
      for StepIndex := 1 to 8 do
      begin
        Check(ApplySimpleController3D(Model, RaisedPoses, Controller,
          0, 1, 0, 0, 0, ViewPoses),
          'repeated hand raising failed');
        RaisedPoses := ViewPoses;
      end;
      CalculateInteractiveBoneTransforms(Model, RaisedPoses,
        NewTransforms);
      ExtremePoses[0] := Copy(RaisedPoses);
      PreviousY := NewTransforms[Wrist].Position.Y;
      Check(ApplySimpleController3D(Model, RaisedPoses, Controller,
        0, -0.3, 0, 0, 0, LoweredPoses),
        'reversing fully raised hand failed');
      CalculateInteractiveBoneTransforms(Model, LoweredPoses,
        TwistTransforms);
      Check(TwistTransforms[Wrist].Position.Y < PreviousY - 0.03,
        'fully raised hand did not reverse down');
      LoweredPoses := Copy(BasePoses);
      for StepIndex := 1 to 8 do
      begin
        Check(ApplySimpleController3D(Model, LoweredPoses, Controller,
          0, -1, 0, 0, 0, ViewPoses),
          'repeated hand lowering failed');
        LoweredPoses := ViewPoses;
      end;
      CalculateInteractiveBoneTransforms(Model, LoweredPoses,
        NewTransforms);
      ExtremePoses[1] := Copy(LoweredPoses);
      PreviousY := NewTransforms[Wrist].Position.Y;
      Check(ApplySimpleController3D(Model, LoweredPoses, Controller,
        0, 0.3, 0, 0, 0, RaisedPoses),
        'reversing fully lowered hand failed');
      CalculateInteractiveBoneTransforms(Model, RaisedPoses,
        TwistTransforms);
      Check(TwistTransforms[Wrist].Position.Y > PreviousY + 0.03,
        'fully lowered hand did not reverse up');
      // スティックを長く倒して可動端に当てた直後でも逆方向へ進める。
      for InputSign := -1 to 1 do
      begin
        if InputSign = 0 then Continue;
        ViewPoses := Copy(BasePoses);
        for StepIndex := 1 to 60 do
        begin
          WorldMove := Default(TPmxVector3);
          WorldTurn := Default(TPmxVector3);
          AccumulateSimpleControllerViewInput(Controller, 0,
            InputSign * 0.1, 0, 0, 0, WorldMove, WorldTurn);
          Check(ApplySimpleControllerWorldWithTwist(Model, ViewPoses,
            Controller, WorldMove, WorldTurn, 0, RaisedPoses),
            'continuous hand step failed');
          ViewPoses := RaisedPoses;
        end;
        CalculateInteractiveBoneTransforms(Model, ViewPoses,
          NewTransforms);
        BeforeScreenY := NewTransforms[Wrist].Position.Y;
        WorldMove := Default(TPmxVector3);
        WorldTurn := Default(TPmxVector3);
        AccumulateSimpleControllerViewInput(Controller, 0,
          -InputSign * 0.1, 0, 0, 0, WorldMove, WorldTurn);
        Check(ApplySimpleControllerWorldWithTwist(Model, ViewPoses,
          Controller, WorldMove, WorldTurn, 0, LoweredPoses),
          'reversing continuous hand step failed');
        CalculateInteractiveBoneTransforms(Model, LoweredPoses,
          TwistTransforms);
        Check((TwistTransforms[Wrist].Position.Y - BeforeScreenY) *
          InputSign < -0.005,
          Format('hand did not reverse after held input '+
            '(model=%d side=%d sign=%d delta=%g)',
            [ModelNumber, Ord(Controller), InputSign,
            TwistTransforms[Wrist].Position.Y - BeforeScreenY]));
      end;
      for ExtremeIndex := 0 to 1 do
        for ViewIndex := 0 to 5 do
        begin
          Yaw := (ViewIndex mod 3) * Pi * 0.5;
          Pitch := ((ViewIndex div 3) * 2 - 1) * 0.6;
          CalculateInteractiveBoneTransforms(Model,
            ExtremePoses[ExtremeIndex], NewTransforms);
          BeforeScreenY := ScreenY(NewTransforms[Wrist].Position,
            Yaw, Pitch);
          for InputSign := -1 to 1 do
          begin
            if InputSign = 0 then Continue;
            Check(ApplySimpleController3D(Model,
              ExtremePoses[ExtremeIndex], Controller,
              0, InputSign * 0.3, 0, Yaw, Pitch, ViewPoses),
              'angled hand movement failed');
            CalculateInteractiveBoneTransforms(Model, ViewPoses,
              TwistTransforms);
            AfterScreenY := ScreenY(TwistTransforms[Wrist].Position,
              Yaw, Pitch);
            Check((AfterScreenY - BeforeScreenY) * InputSign > 0.005,
              Format('hand did not follow view up/down (model=%d side=%d '+
                'extreme=%d view=%d sign=%d delta=%g)',
                [ModelNumber, Ord(Controller), ExtremeIndex, ViewIndex,
                InputSign, AfterScreenY - BeforeScreenY]));
          end;
        end;
      if Controller = scLeftHand then
        Arm := FindBoneIndex(Model, '左腕')
      else
        Arm := FindBoneIndex(Model, '右腕');
      for AxisIndex := 0 to 2 do
        for AngleIndex := -4 to 4 do
        begin
          Axis := Default(TPmxVector3);
          case AxisIndex of
            0: Axis.X := 1;
            1: Axis.Y := 1;
            2: Axis.Z := 1;
          end;
          ViewPoses := Copy(BasePoses);
          ViewPoses[Arm].Rotation := QuaternionFromAxisAngle(Axis,
            AngleIndex * 0.4);
          CalculateInteractiveBoneTransforms(Model, ViewPoses,
            NewTransforms);
          BeforeScreenY := NewTransforms[Wrist].Position.Y;
          for InputSign := -1 to 1 do
          begin
            if InputSign = 0 then Continue;
            Check(ApplySimpleController3D(Model, ViewPoses,
              Controller, 0, InputSign * 0.3, 0, 0, 0,
              RaisedPoses), 'posed arm hand movement failed');
            CalculateInteractiveBoneTransforms(Model, RaisedPoses,
              TwistTransforms);
            AfterScreenY := TwistTransforms[Wrist].Position.Y;
            Check((AfterScreenY - BeforeScreenY) * InputSign > 0.005,
              Format('posed arm did not follow hand target '+
                '(model=%d side=%d axis=%d angle=%d sign=%d delta=%g)',
                [ModelNumber, Ord(Controller), AxisIndex, AngleIndex,
                InputSign, AfterScreenY - BeforeScreenY]));
          end;
        end;
    end;
    if Controller in [scLeftFoot, scRightFoot] then
    begin
      if Controller = scLeftFoot then
      begin
        Leg := FindBoneIndex(Model, '左足');
        Knee := FindBoneIndex(Model, '左ひざ');
        Ankle := FindBoneIndex(Model, '左足首');
        OtherAnkle := FindBoneIndex(Model, '右足首');
      end
      else
      begin
        Leg := FindBoneIndex(Model, '右足');
        Knee := FindBoneIndex(Model, '右ひざ');
        Ankle := FindBoneIndex(Model, '右足首');
        OtherAnkle := FindBoneIndex(Model, '左足首');
      end;
      Check((Leg >= 0) and (Knee >= 0) and (Ankle >= 0) and
        (OtherAnkle >= 0), 'leg chain is unavailable');
      Check(SimpleControllerTargetBone(Model, Controller) = Ankle,
        'foot marker is not on the ankle');
      CalculateInteractiveBoneTransforms(Model, NewPoses, NewTransforms);
      Check(Distance(BaseTransforms[Ankle].Position,
        NewTransforms[Ankle].Position) > 0.02,
        'foot target did not move the ankle');
      Check(Distance(BaseTransforms[OtherAnkle].Position,
        NewTransforms[OtherAnkle].Position) < 0.001,
        'moving one foot moved the other');
      Check(RotationAlignment(BaseTransforms[Ankle].Rotation,
        NewTransforms[Ankle].Rotation) > 0.9999,
        'moving the ankle turned the toes toward the shin');
      CalculateBoneTransforms(Model, NewPoses, FinalTransforms);
      Check(Distance(NewTransforms[Ankle].Position,
        FinalTransforms[Ankle].Position) < 0.01,
        'PMX foot IK replaced the puppet foot pose');
      Check(RotationAlignment(BaseTransforms[Ankle].Rotation,
        FinalTransforms[Ankle].Rotation) > 0.9999,
        'final PMX pose changed the preserved foot direction');
      Check(ApplySimpleController3DWithTwist(Model, BasePoses,
        Controller, 0, 0, 0, 0.5, 0, 0, TwistPoses),
        'foot axial rotation failed');
      Check(Abs(TwistPoses[Ankle].Rotation.W -
        BasePoses[Ankle].Rotation.W) > 0.01,
        'foot axial rotation did not turn the ankle');
      CalculateInteractiveBoneTransforms(Model, TwistPoses,
        TwistTransforms);
      Check(Distance(BaseTransforms[Ankle].Position,
        TwistTransforms[Ankle].Position) < 0.001,
        'foot axial rotation moved the ankle');
      WorldMove := Default(TPmxVector3);
      WorldTurn := Default(TPmxVector3);
      Check(ApplySimpleControllerWorldWithExtras(Model, BasePoses,
        Controller, WorldMove, WorldTurn, 0, 0, 0.5,
        0, 0, PitchPoses), 'foot tip pitch failed');
      CalculateInteractiveBoneTransforms(Model, PitchPoses,
        NewTransforms);
      Check(Distance(BaseTransforms[Ankle].Position,
        NewTransforms[Ankle].Position) < 0.001,
        'foot tip pitch moved the ankle');
      Check(Distance(BaseTransforms[Knee].Position,
        NewTransforms[Knee].Position) < 0.001,
        'foot tip pitch moved the knee');
      FootForward := Default(TPmxVector3);
      FootForward.Z := -1;
      PitchedForward := RotateVector(NewTransforms[Ankle].Rotation,
        FootForward);
      FootForward := RotateVector(BaseTransforms[Ankle].Rotation,
        FootForward);
      Check(PitchedForward.Y > FootForward.Y + 0.05,
        'X+vertical did not lift the foot tip');
      Check(ApplySimpleControllerWorldWithExtras(Model, BasePoses,
        Controller, WorldMove, WorldTurn, 0, 0, -0.5,
        0, 0, PitchPoses), 'reverse foot tip pitch failed');
      CalculateInteractiveBoneTransforms(Model, PitchPoses,
        NewTransforms);
      Axis := Default(TPmxVector3);
      Axis.Z := -1;
      PitchedForward := RotateVector(NewTransforms[Ankle].Rotation,
        Axis);
      Check(PitchedForward.Y < FootForward.Y - 0.05,
        'X+vertical did not lower the foot tip');
      Check(ApplySimpleControllerWorldWithExtras(Model, BasePoses,
        Controller, WorldMove, WorldTurn, 0, 0, 0.5,
        Pi * 0.5, 0.4, PitchPoses),
        'view-relative foot tip pitch failed');
      CalculateInteractiveBoneTransforms(Model, PitchPoses,
        NewTransforms);
      PitchedForward := RotateVector(NewTransforms[Ankle].Rotation,
        Axis);
      Check(ScreenY(PitchedForward, Pi * 0.5, 0.4) >
        ScreenY(FootForward, Pi * 0.5, 0.4) + 0.05,
        'foot tip pitch did not follow the camera up direction');
      WorldMove := Default(TPmxVector3);
      WorldTurn := Default(TPmxVector3);
      AccumulateSimpleControllerViewInput(Controller, 0.12, 0.16, 0,
        Pi * 0.25, 0.2, WorldMove, WorldTurn);
      Check(ApplySimpleControllerWorldWithTwist(Model, TwistPoses,
        Controller, WorldMove, WorldTurn, 0, RaisedPoses),
        'moving an already rotated foot failed');
      CalculateInteractiveBoneTransforms(Model, RaisedPoses,
        NewTransforms);
      Check(RotationAlignment(TwistTransforms[Ankle].Rotation,
        NewTransforms[Ankle].Rotation) > 0.9999,
        'moving an already rotated foot lost its selected direction');
      ViewPoses := Copy(BasePoses);
      for StepIndex := 1 to 40 do
      begin
        WorldMove := Default(TPmxVector3);
        WorldTurn := Default(TPmxVector3);
        AccumulateSimpleControllerViewInput(Controller, 0, 0.08, 0,
          0, 0, WorldMove, WorldTurn);
        Check(ApplySimpleControllerWorldWithTwist(Model, ViewPoses,
          Controller, WorldMove, WorldTurn, 0, RaisedPoses),
          'continuous foot raise failed');
        ViewPoses := RaisedPoses;
      end;
      CalculateInteractiveBoneTransforms(Model, ViewPoses,
        NewTransforms);
      PreviousY := NewTransforms[Ankle].Position.Y;
      Check(RotationAlignment(BaseTransforms[Ankle].Rotation,
        NewTransforms[Ankle].Rotation) > 0.999,
        'continuous foot raise drifted the toe direction');
      WorldMove := Default(TPmxVector3);
      WorldTurn := Default(TPmxVector3);
      AccumulateSimpleControllerViewInput(Controller, 0, -0.08, 0,
        0, 0, WorldMove, WorldTurn);
      Check(ApplySimpleControllerWorldWithTwist(Model, ViewPoses,
        Controller, WorldMove, WorldTurn, 0, LoweredPoses),
        'foot reversal failed');
      CalculateInteractiveBoneTransforms(Model, LoweredPoses,
        TwistTransforms);
      Check(TwistTransforms[Ankle].Position.Y < PreviousY - 0.005,
        'raised foot did not lower immediately');
      ViewPoses := Copy(BasePoses);
      for StepIndex := 1 to 40 do
      begin
        WorldMove := Default(TPmxVector3);
        WorldTurn := Default(TPmxVector3);
        AccumulateSimpleControllerViewInput(Controller, 0, -0.08, 0,
          0, 0, WorldMove, WorldTurn);
        Check(ApplySimpleControllerWorldWithTwist(Model, ViewPoses,
          Controller, WorldMove, WorldTurn, 0, LoweredPoses),
          'continuous foot lower failed');
        ViewPoses := LoweredPoses;
      end;
      CalculateInteractiveBoneTransforms(Model, ViewPoses,
        NewTransforms);
      PreviousY := NewTransforms[Ankle].Position.Y;
      Check(RotationAlignment(BaseTransforms[Ankle].Rotation,
        NewTransforms[Ankle].Rotation) > 0.999,
        'continuous foot lower drifted the toe direction');
      WorldMove := Default(TPmxVector3);
      WorldTurn := Default(TPmxVector3);
      AccumulateSimpleControllerViewInput(Controller, 0, 0.08, 0,
        0, 0, WorldMove, WorldTurn);
      Check(ApplySimpleControllerWorldWithTwist(Model, ViewPoses,
        Controller, WorldMove, WorldTurn, 0, RaisedPoses),
        'lowered foot reversal failed');
      CalculateInteractiveBoneTransforms(Model, RaisedPoses,
        TwistTransforms);
      Check(TwistTransforms[Ankle].Position.Y > PreviousY + 0.005,
        Format('lowered foot did not raise immediately '+
          '(model=%d side=%d before=%g delta=%g)',
          [ModelNumber, Ord(Controller), PreviousY,
          TwistTransforms[Ankle].Position.Y - PreviousY]));
    end;
    if Controller = scRightHand then
    begin
      SetLength(NamedPoses, Length(NewPoses));
      Count := 0;
      for BoneIndex := 0 to High(NewPoses) do
        if (Abs(NewPoses[BoneIndex].Rotation.X) > 0.000001) or
          (Abs(NewPoses[BoneIndex].Rotation.Y) > 0.000001) or
          (Abs(NewPoses[BoneIndex].Rotation.Z) > 0.000001) then
        begin
          NamedPoses[Count].BoneName := Model.Bones[BoneIndex].Name;
          NamedPoses[Count].Pose := NewPoses[BoneIndex];
          Inc(Count);
        end;
      SetLength(NamedPoses, Count);
      TFile.WriteAllText(Format(
        'TestArtifacts\SimpleController\Solver\pose-%d.json',
        [ModelNumber]), EncodePoseData(NamedPoses), TEncoding.UTF8);
    end;
  end;
  CheckBendAdjustment(Model, BasePoses, scLeftHand);
  CheckBendAdjustment(Model, BasePoses, scRightHand);
  CheckBendAdjustment(Model, BasePoses, scLeftFoot);
  CheckBendAdjustment(Model, BasePoses, scRightFoot);
  Writeln('PASS: ', Model.Name);
end;

var
  I: Integer;
begin
  try
    Check(ParamCount >= 2, 'two model paths are required');
    for I := 1 to ParamCount do CheckModel(ParamStr(I), I);
  except
    on E: Exception do
    begin
      Writeln(E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
