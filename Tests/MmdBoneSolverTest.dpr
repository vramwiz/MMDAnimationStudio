program MmdBoneSolverTest;

{$APPTYPE CONSOLE}

uses
  System.Math,
  System.SysUtils,
  PmxModel in '..\AviUtl2PluginLib\MMD\Core\PmxModel.pas',
  PmxPoseTypes in '..\AviUtl2PluginLib\MMD\Core\PmxPoseTypes.pas',
  PmxPoseMath in '..\AviUtl2PluginLib\MMD\Core\PmxPoseMath.pas',
  PmxMorph in '..\AviUtl2PluginLib\MMD\Core\PmxMorph.pas',
  PmxBoneSolver in '..\AviUtl2PluginLib\MMD\Core\PmxBoneSolver.pas',
  PmxPose in '..\AviUtl2PluginLib\MMD\Core\PmxPose.pas',
  PmxReader in '..\AviUtl2PluginLib\MMD\IO\PmxReader.pas',
  PmxBinaryStream in '..\AviUtl2PluginLib\MMD\IO\PmxBinaryStream.pas',
  PmxGeometryReader in '..\AviUtl2PluginLib\MMD\IO\PmxGeometryReader.pas',
  PmxMaterialReader in '..\AviUtl2PluginLib\MMD\IO\PmxMaterialReader.pas',
  PmxBoneReader in '..\AviUtl2PluginLib\MMD\IO\PmxBoneReader.pas',
  PmxMorphReader in '..\AviUtl2PluginLib\MMD\IO\PmxMorphReader.pas';

procedure CheckNear(Actual, Expected, Tolerance: Single; const Name: string);
begin
  if Abs(Actual - Expected) > Tolerance then
    raise Exception.CreateFmt('%s: expected %.6f, got %.6f',
      [Name, Expected, Actual]);
end;

function NewModel(BoneCount: Integer): TPmxModel;
var
  I: Integer;
begin
  Result := TPmxModel.Create;
  SetLength(Result.Bones, BoneCount);
  for I := 0 to BoneCount - 1 do
  begin
    Result.Bones[I].ParentIndex := -1;
    Result.Bones[I].InheritParentIndex := -1;
    Result.Bones[I].IkTargetIndex := -1;
  end;
end;

procedure TestGrant(IsLocal: Boolean);
var
  Model: TPmxModel;
  Poses: TPmxBonePoses;
  Transforms: TPmxBoneTransforms;
begin
  Model := NewModel(4);
  try
    Model.Bones[1].ParentIndex := 0;
    Model.Bones[2].ParentIndex := 0;
    Model.Bones[2].Flags := PMX_BONE_FLAG_INHERIT_ROTATION or
      PMX_BONE_FLAG_INHERIT_TRANSLATION;
    if IsLocal then
      Model.Bones[2].Flags := Model.Bones[2].Flags or
        PMX_BONE_FLAG_LOCAL_APPEND;
    Model.Bones[2].InheritParentIndex := 1;
    Model.Bones[2].InheritWeight := 0.5;
    Model.Bones[3].ParentIndex := 2;
    Model.Bones[3].Position.X := 1;
    InitializeBonePoses(Model, Poses);
    Poses[1].Translation.X := 2;
    Poses[1].Rotation := QuaternionFromEulerXYZ(0, 0, Pi / 2);
    CalculateBoneTransforms(Model, Poses, Transforms);
    CheckNear(Transforms[2].Position.X, 1, 0.001, 'grant translation');
    CheckNear(Transforms[3].Position.X, 1 + Sqrt(0.5), 0.001,
      'grant endpoint x');
    CheckNear(Transforms[3].Position.Y, Sqrt(0.5), 0.001,
      'grant endpoint y');
  finally
    Model.Free;
  end;
end;

procedure TestRealModelIk(Model: TPmxModel);
var
  Bone: TPmxBone;
  BoneIndex: Integer;
  Distance, MaxDistance: Single;
  Poses: TPmxBonePoses;
  Transforms: TPmxBoneTransforms;
begin
  InitializeBonePoses(Model, Poses);
  CalculateBoneTransforms(Model, Poses, Transforms);
  MaxDistance := 0;
  for BoneIndex := 0 to High(Model.Bones) do
  begin
    Bone := Model.Bones[BoneIndex];
    if (Bone.Flags and PMX_BONE_FLAG_IK) <> 0 then
    begin
      Distance := Sqrt(Sqr(Transforms[Bone.IkTargetIndex].Position.X -
        Transforms[BoneIndex].Position.X) +
        Sqr(Transforms[Bone.IkTargetIndex].Position.Y -
        Transforms[BoneIndex].Position.Y) +
        Sqr(Transforms[Bone.IkTargetIndex].Position.Z -
        Transforms[BoneIndex].Position.Z));
      Writeln(Format('  IK %s residual: %.6f', [Bone.Name, Distance]));
      MaxDistance := Max(MaxDistance, Distance);
    end;
  end;
  if MaxDistance > 0.2 then
    raise Exception.CreateFmt('real model IK residual is too large: %.6f',
      [MaxDistance]);
  Writeln(Format('Real model IK max residual: %.6f', [MaxDistance]));
end;

procedure ConfigureIkModel(Model: TPmxModel; HasLimits: Boolean);
begin
  Model.Bones[1].ParentIndex := 0;
  Model.Bones[2].ParentIndex := 1;
  Model.Bones[2].Position.X := 1;
  Model.Bones[3].ParentIndex := 0;
  Model.Bones[3].Position.Y := 1;
  Model.Bones[3].Flags := PMX_BONE_FLAG_IK;
  Model.Bones[3].IkTargetIndex := 2;
  Model.Bones[3].IkLoopCount := 20;
  Model.Bones[3].IkAngleLimit := Pi / 4;
  SetLength(Model.Bones[3].IkLinks, 1);
  Model.Bones[3].IkLinks[0].BoneIndex := 1;
  Model.Bones[3].IkLinks[0].HasLimits := HasLimits;
  if HasLimits then
  begin
    Model.Bones[3].IkLinks[0].LimitMin.Z := 0;
    Model.Bones[3].IkLinks[0].LimitMax.Z := 0.2;
  end;
end;

procedure TestIk;
var
  Model: TPmxModel;
  Poses: TPmxBonePoses;
  Transforms: TPmxBoneTransforms;
begin
  Model := NewModel(4);
  try
    ConfigureIkModel(Model, False);
    InitializeBonePoses(Model, Poses);
    CalculateBoneTransforms(Model, Poses, Transforms);
    CheckNear(Transforms[2].Position.X, 0, 0.002, 'IK effector x');
    CheckNear(Transforms[2].Position.Y, 1, 0.002, 'IK effector y');
  finally
    Model.Free;
  end;
end;

procedure TestIkLimits;
var
  Model: TPmxModel;
  Poses: TPmxBonePoses;
  Transforms: TPmxBoneTransforms;
begin
  Model := NewModel(4);
  try
    ConfigureIkModel(Model, True);
    InitializeBonePoses(Model, Poses);
    CalculateBoneTransforms(Model, Poses, Transforms);
    CheckNear(Transforms[2].Position.X, Cos(0.2), 0.002,
      'limited IK effector x');
    CheckNear(Transforms[2].Position.Y, Sin(0.2), 0.002,
      'limited IK effector y');
  finally
    Model.Free;
  end;
end;

procedure TestExplicitFkDisablesIk;
var
  Model: TPmxModel;
  Poses: TPmxBonePoses;
  Transforms: TPmxBoneTransforms;
begin
  Model := NewModel(4);
  try
    ConfigureIkModel(Model, False);
    InitializeBonePoses(Model, Poses);
    Poses[1].Rotation := QuaternionFromEulerXYZ(0, 0, 0.3);
    CalculateBoneTransforms(Model, Poses, Transforms);
    CheckNear(Transforms[2].Position.X, Cos(0.3), 0.002,
      'explicit FK effector x');
    CheckNear(Transforms[2].Position.Y, Sin(0.3), 0.002,
      'explicit FK effector y');
  finally
    Model.Free;
  end;
end;

procedure PrintRealModelStats;
var
  Bone: TPmxBone;
  GrantCount, IkCount, LocalGrantCount: Integer;
  Model: TPmxModel;
begin
  Model := GetCachedPmxModel(
    'D:\VoiceroidProj\MMD\ふらすこ式風きりたん_ver0.05\ふらすこ式風きりたん_ver0.05.pmx');
  GrantCount := 0;
  IkCount := 0;
  LocalGrantCount := 0;
  for Bone in Model.Bones do
  begin
    if (Bone.Flags and (PMX_BONE_FLAG_INHERIT_ROTATION or
      PMX_BONE_FLAG_INHERIT_TRANSLATION)) <> 0 then
      Inc(GrantCount);
    if (Bone.Flags and PMX_BONE_FLAG_LOCAL_APPEND) <> 0 then
      Inc(LocalGrantCount);
    if (Bone.Flags and PMX_BONE_FLAG_IK) <> 0 then
      Inc(IkCount);
  end;
  Writeln(Format('Real model: bones=%d grants=%d local-grants=%d IK=%d',
    [Length(Model.Bones), GrantCount, LocalGrantCount, IkCount]));
  TestRealModelIk(Model);
end;

begin
  try
    TestGrant(True);
    TestGrant(False);
    TestIk;
    TestIkLimits;
    TestExplicitFkDisablesIk;
    PrintRealModelStats;
    Writeln('MmdBoneSolverTest: PASS');
  except
    on E: Exception do
    begin
      Writeln('MmdBoneSolverTest: FAIL: ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
