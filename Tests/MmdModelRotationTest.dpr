program MmdModelRotationTest;

{$APPTYPE CONSOLE}

uses
  System.Math,
  System.SysUtils,
  MMD_Model_GlobalRotation,
  MMD_Model_PoseTransition,
  MmdPoseEditSession,
  MmdPoseHistory,
  PmxModel,
  PmxPose,
  PmxPoseCodec,
  PmxPoseMath,
  PmxReader;

procedure Check(Condition: Boolean; const MessageText: string);
begin
  if not Condition then raise Exception.Create(MessageText);
end;

procedure RunTests;
var
  HasRoot: Boolean;
  HasAngle: Boolean;
  History: TMmdPoseHistory;
  EditSession: TMmdPoseEditSession;
  Model: TPmxModel;
  Named: TPmxNamedBonePoses;
  Point: TPmxVector3;
  Poses, Restored: TPmxBonePoses;
  Rotation, RestoredRoot: TPmxQuaternion;
  Text: string;
  Transforms: TPmxBoneTransforms;
  Transition: TMmdModelPoseTransition;
  Yaw, Pitch: Single;
  RestoredYaw, RestoredPitch: Single;
  Vertices: TPmxSkinnedVertices;
begin
  Rotation := PoseRelativeRotation(90, 0);
  SetLength(Transforms, 1);
  SetLength(Vertices, 1);
  Transforms[0].Position.X := 1;
  Transforms[0].Rotation := IdentityQuaternion;
  Vertices[0].Position.X := 1;
  Vertices[0].Normal.X := 1;
  RotateModelGeometry(Rotation, Transforms, Vertices);
  Check((Abs(Vertices[0].Position.X) < 0.0001) and
    (Abs(Vertices[0].Position.Z + 1) < 0.0001) and
    (Abs(Transforms[0].Position.Z + 1) < 0.0001) and
    (Abs(Vertices[0].Normal.Z + 1) < 0.0001),
    'yaw did not rotate the full model around its origin');
  Rotation := PoseRelativeRotation(0, 90);
  Point := Default(TPmxVector3);
  Check(Abs(RotateVector(Rotation, Point).Y) < 0.0001,
    'pitch shifted the foot origin');
  Point.Y := 1;
  Check(Abs(RotateVector(Rotation, Point).Z - 1) < 0.0001,
    'pitch direction differs from the preview camera');
  Text := EncodePoseDataWithRoot(nil, Rotation);
  Check(TryDecodePoseDataWithRoot(Text, Named, RestoredRoot,
    HasRoot) and HasRoot and
    (Abs(RestoredRoot.X - Rotation.X) < 0.00001),
    'global pose rotation did not roundtrip');
  Check(TryDecodePoseDataWithRoot('{"version":1,"bones":[]}',
    Named, RestoredRoot, HasRoot) and not HasRoot and
    not HasModelRotation(RestoredRoot),
    'legacy pose did not retain the identity rotation');
  Text := EncodePoseDataWithRootAndAngle(nil, Rotation, True,
    45, 20, True);
  Check(TryDecodePoseDataWithRootAndAngle(Text, Named, RestoredRoot,
    HasRoot, Yaw, Pitch, HasAngle) and HasAngle and
    (Abs(Yaw - 45) < 0.0001) and (Abs(Pitch - 20) < 0.0001),
    'relative pose angle did not roundtrip');
  Text := EncodePoseDataWithRootAndAngle(nil, Rotation, True,
    180.00002, 89.00002, True);
  Check(TryDecodePoseDataWithRootAndAngle(Text, Named, RestoredRoot,
    HasRoot, Yaw, Pitch, HasAngle) and
    (Abs(Yaw - 180) < 0.0001) and (Abs(Pitch - 89) < 0.0001),
    'angle boundary rounding was not normalized');
  Text := EncodePoseDataWithRootAndAngle(nil, Rotation, True,
    45, 20, True);
  Model := TPmxModel.Create;
  Transition := TMmdModelPoseTransition.Create;
  try
    Poses := nil;
    RestoredRoot := IdentityQuaternion;
    Yaw := 0;
    Pitch := 0;
    Check(Transition.Resolve(Model, True, nil, Rotation, 45, 20, 1,
      'model', 0, -1, -1, 30, 0.3, Poses, RestoredRoot,
      Yaw, Pitch) and
      (Abs(RestoredRoot.X - Rotation.X) < 0.00001) and
      (Abs(Yaw - 45) < 0.0001),
      'root-only pose was ignored by the transition');
  finally
    Transition.Free;
    Model.Free;
  end;
  Model := GetCachedPmxModel(ParamStr(1));
  EditSession := TMmdPoseEditSession.Create;
  try
    EditSession.Load(Model, Text, Poses);
    Text := EditSession.Encode(Model, Poses);
    Check(TryDecodePoseDataWithRootAndAngle(Text, Named, RestoredRoot,
      HasRoot, Yaw, Pitch, HasAngle) and HasRoot and HasAngle and
      (Abs(RestoredRoot.X - Rotation.X) < 0.00001) and
      (Abs(Yaw - 45) < 0.0001),
      'pose editor discarded the rotation or relative angle');
  finally
    EditSession.Free;
  end;
  SetLength(Poses, 1);
  Poses[0].Rotation := IdentityQuaternion;
  History := TMmdPoseHistory.Create;
  try
    History.RecordBeforeEdit(Poses, Rotation, 45, 20);
    Check(History.Undo(Poses, IdentityQuaternion, 0, 0, Restored,
      RestoredRoot, RestoredYaw, RestoredPitch) and
      (Abs(RestoredRoot.X - Rotation.X) < 0.00001) and
      (Abs(RestoredYaw - 45) < 0.0001),
      'pose rotation or relative angle was lost from Undo');
  finally
    History.Free;
  end;
end;

begin
  try
    RunTests;
    Writeln('MmdModelRotationTest: PASS');
  except
    on E: Exception do
    begin
      Writeln(E.ClassName + ': ' + E.Message);
      ExitCode := 1;
    end;
  end;
end.
