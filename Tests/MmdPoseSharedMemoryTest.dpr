program MmdPoseSharedMemoryTest;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  AviUtl2FilterTypes in 'Source\Lib\AviUtl2FilterTypes.pas',
  MmdPoseSharedMemory in '..\AviUtl2PluginLib\MMD\IPC\MmdPoseSharedMemory.pas',
  MmdPoseSharedTrace in '..\AviUtl2PluginLib\MMD\IPC\MmdPoseSharedTrace.pas',
  PmxModel in '..\AviUtl2PluginLib\MMD\Core\PmxModel.pas',
  PmxPoseTypes in '..\AviUtl2PluginLib\MMD\Core\PmxPoseTypes.pas',
  PmxPoseMath in '..\AviUtl2PluginLib\MMD\Core\PmxPoseMath.pas',
  PmxBoneSolver in '..\AviUtl2PluginLib\MMD\Core\PmxBoneSolver.pas',
  PmxPose in '..\AviUtl2PluginLib\MMD\Core\PmxPose.pas',
  PmxPoseCodec in '..\AviUtl2PluginLib\MMD\IO\PmxPoseCodec.pas',
  MMD_Model_PoseTransition in
    'Source\Plugin\Model\Runtime\Pose\MMD_Model_PoseTransition.pas',
  MMD_Model_Context in 'Source\Plugin\Model\Context\MMD_Model_Context.pas',
  MMD_Model_PoseInput in
    'Source\Plugin\Model\Input\Pose\MMD_Model_PoseInput.pas';

var
  PoseObjectAvailable: Boolean;
  PoseSourceIsModel: Boolean;
  PoseSourceHandle: OBJECT_HANDLE;
  PoseSourcePosition: TOBJECT_LAYER_FRAME;
  RequestedPositionObject: OBJECT_HANDLE;
  RequestedLayer: Integer;
  RequestedOffset: Double;

function TestGetImageObject(Layer: Integer;
  Offset: Double): OBJECT_HANDLE; cdecl;
begin
  RequestedLayer := Layer;
  RequestedOffset := Offset;
  if PoseObjectAvailable then
    Result := PoseSourceHandle
  else
    Result := nil;
end;

function TestGetObjectLayerFrame(Obj: OBJECT_HANDLE): TOBJECT_LAYER_FRAME;
  cdecl;
begin
  RequestedPositionObject := Obj;
  Result := PoseSourcePosition;
end;

function TestFindObject(Layer, Frame: Integer): OBJECT_HANDLE; cdecl;
begin
  Result := nil;
  if PoseObjectAvailable and (Layer = 903) and (Frame = 945) then
    Result := PoseSourceHandle;
end;

function TestCountObjectEffect(Obj: OBJECT_HANDLE;
  Effect: PWideChar): Integer; cdecl;
begin
  Result := 0;
  if (Obj = PoseSourceHandle) and PoseSourceIsModel and
    (string(Effect) = #$30E2#$30C7#$30EB#$8868#$793A) then
    Result := 1;
end;

procedure Check(Condition: Boolean; const Message_: string);
begin
  if not Condition then
    raise Exception.Create(Message_);
end;

procedure TestSharedMemory;
var
  ReadBack: TMmdPoseSharedSnapshot;
  Snapshot: TMmdPoseSharedSnapshot;
begin
  Snapshot.WriterObjectID := 101;
  Snapshot.WriterEffectID := 201;
  Snapshot.TimelineFrame := 345;
  Snapshot.ModelPathHash := HashModelPath('C:\model\sample.pmx');
  Snapshot.PoseData := '{"version":1,"bones":[]}';
  Check(PublishPoseSnapshot(876, Snapshot), 'publish failed');
  Check(TryReadPoseSnapshot(876, Snapshot.ModelPathHash, ReadBack),
    'read failed');
  Check(ReadBack.WriterObjectID = 101, 'object id mismatch');
  Check(ReadBack.WriterEffectID = 201, 'effect id mismatch');
  Check(ReadBack.PoseData = Snapshot.PoseData, 'pose data mismatch');
  Check(ReadBack.TimelineFrame = 345, 'published frame was not preserved');
  Check(not TryReadPoseSnapshot(876, Snapshot.ModelPathHash + 1, ReadBack),
    'different model was accepted');
end;

procedure TestModelPoseLayerInput;
const
  ModelFileName = 'C:\model\layer-input.pmx';
  PoseData = '{"version":1,"bones":[{"name":"center",' +
    '"translation":[1,2,3],"rotation":[0,0,0,1]}]}';
var
  ObjectInfo: TOBJECT_INFO;
  ReadPoseData: string;
  PoseStartFrame, PoseEndFrame: Integer;
  Snapshot: TMmdPoseSharedSnapshot;
  Video: TFILTER_PROC_VIDEO;
  Edit: TEDIT_SECTION;
begin
  ObjectInfo := Default(TOBJECT_INFO);
  ObjectInfo.FrameS := 900;
  ObjectInfo.Frame := 45;
  Video := Default(TFILTER_PROC_VIDEO);
  Video.Object_ := @ObjectInfo;
  Video.GetImageObject := TestGetImageObject;
  Edit := Default(TEDIT_SECTION);
  Edit.FindObject := TestFindObject;
  Edit.CountObjectEffect := TestCountObjectEffect;
  Edit.GetObjectLayerFrame := TestGetObjectLayerFrame;
  Video.Edit := @Edit;
  Snapshot.WriterObjectID := 301;
  Snapshot.WriterEffectID := 401;
  // PoseとModelの配置開始位置が異なっても、存在中なら姿勢を受理する。
  Snapshot.TimelineFrame := 123;
  Snapshot.ModelPathHash := HashModelPath(ModelFileName);
  Snapshot.PoseData := PoseData;
  Check(PublishPoseSnapshot(903, Snapshot),
    'model pose input publish failed');
  PoseObjectAvailable := True;
  // ハンドルはTOBJECT_INFOへのポインタではない。
  PoseSourceHandle := Pointer(NativeUInt($12345));
  PoseSourcePosition := Default(TOBJECT_LAYER_FRAME);
  PoseSourcePosition.Layer := 903;
  PoseSourcePosition.StartFrame := 930;
  PoseSourcePosition.EndFrame := 980;
  RequestedLayer := -1;
  RequestedOffset := -1;
  RequestedPositionObject := nil;
  Check(TryGetReferencedPoseData(@Video, 904, ModelFileName,
    ReadPoseData, PoseStartFrame, PoseEndFrame),
    'model did not read referenced pose layer');
  Check(RequestedLayer = 903, 'display layer was not converted to SDK layer');
  Check(RequestedOffset = 0, 'pose layer was not evaluated at current time');
  Check(ReadPoseData = PoseData, 'model pose input data mismatch');
  Check(RequestedPositionObject = PoseSourceHandle,
    'pose start frame was not queried through the edit section');
  Check(PoseStartFrame = 930, 'pose object start frame was not returned');
  Check(PoseEndFrame = 980, 'pose object end frame was not returned');
  ObjectInfo.Layer := 903;
  RequestedLayer := -1;
  Check(not TryGetReferencedPoseData(@Video, 904, ModelFileName,
    ReadPoseData, PoseStartFrame, PoseEndFrame),
    'model evaluated its own pose reference layer');
  Check(RequestedLayer = -1, 'self reference called GetImageObject');
  ObjectInfo.Layer := 0;
  PoseSourceIsModel := True;
  RequestedLayer := -1;
  Check(not TryGetReferencedPoseData(@Video, 904, ModelFileName,
    ReadPoseData, PoseStartFrame, PoseEndFrame),
    'model evaluated another model as pose source');
  Check(RequestedLayer = -1, 'model reference called GetImageObject');
  PoseSourceIsModel := False;
  PoseObjectAvailable := False;
  Check(not TryGetReferencedPoseData(@Video, 904, ModelFileName,
    ReadPoseData, PoseStartFrame, PoseEndFrame),
    'model accepted pose data without a pose object');
  Check(PoseStartFrame = -1, 'missing pose retained its start frame');
  Check(PoseEndFrame = -1, 'missing pose retained its end frame');
  PoseObjectAvailable := True;
  Check(not TryGetReferencedPoseData(@Video, 904,
    'C:\model\different.pmx', ReadPoseData, PoseStartFrame, PoseEndFrame),
    'model accepted a pose for a different PMX');
end;

procedure TestObjectContexts;
var
  Context1: TMmdModelContext;
  Context2: TMmdModelContext;
begin
  Context1 := AcquireModelContext(1001, 2001);
  try
    Context1.UpdateStandardPose('{"version":1,"bones":[]}');
    Check(Context1.ObjectID = 2001, 'context 1 object id mismatch');
  finally
    ReleaseModelContext(Context1);
  end;
  Context2 := AcquireModelContext(1002, 2002);
  try
    Check(Context2.ObjectID = 2002, 'context 2 object id mismatch');
    Check(Context1 <> Context2, 'different effects shared a context');
  finally
    ReleaseModelContext(Context2);
  end;
  DestroyModelContext(1001, Context1);
  DestroyModelContext(1002, Context2);
end;

procedure TestPoseTransition;
var
  BasePoses: TPmxBonePoses;
  Current: TPmxNamedBonePoses;
  Model: TPmxModel;
  RootRotation: TPmxQuaternion;
  Transition: TMmdModelPoseTransition;
  Yaw, Pitch: Single;

  function Step(Received: Boolean; Frame, StartFrame: Integer;
    TimeSec: Double; Layer: Integer = 3): Boolean;
  begin
    InitializeBonePoses(Model, BasePoses);
    RootRotation := IdentityQuaternion;
    Yaw := 0;
    Pitch := 0;
    Result := Transition.Resolve(Model, Received, Current,
      IdentityQuaternion, 20, 10, Layer, 'C:\model\pose.pmx',
      Frame, StartFrame, StartFrame + 30, 30, TimeSec,
      BasePoses, RootRotation, Yaw, Pitch);
  end;

  procedure CheckX(Expected: Single; const Message_: string);
  begin
    Check(Abs(BasePoses[0].Translation.X - Expected) < 0.0001,
      Message_);
  end;
begin
  Model := TPmxModel.Create;
  Transition := TMmdModelPoseTransition.Create;
  try
    SetLength(Model.Bones, 1);
    Model.Bones[0].Name := 'center';
    SetLength(Current, 1);
    Current[0].BoneName := 'center';
    Current[0].Pose.Translation.X := 10;
    Current[0].Pose.Rotation.Z := 1;
    Check(Step(True, 100, 100, 1), 'entry start was not resolved');
    CheckX(0, 'entry did not start from standard pose');
    Check(Step(True, 115, 100, 1), 'entry midpoint was not resolved');
    CheckX(5, 'translation was not blended from base pose');
    Check((Abs(BasePoses[0].Rotation.Z - Sqrt(0.5)) < 0.0001) and
      (Abs(BasePoses[0].Rotation.W - Sqrt(0.5)) < 0.0001),
      'rotation did not use quaternion interpolation');
    Check(Step(True, 130, 100, 1), 'full pose was not resolved');
    CheckX(10, 'entry did not finish on time');
    Check(Step(False, 145, -1, 1), 'release midpoint was not resolved');
    CheckX(5, 'release midpoint weight mismatch');
    Check(not Step(False, 160, -1, 1), 'release did not finish');
    Check(Step(True, 206, 200, 1), 'short pose was not resolved');
    CheckX(2, 'short pose entry weight mismatch');
    Check(Step(False, 221, -1, 1), 'short pose release failed');
    CheckX(1, 'short pose release jumped to full weight');
    Check(not Step(False, 222, -1, 0), 'zero duration release failed');
    Check(Step(True, 200, 200, 0), 'zero duration entry failed');
    CheckX(10, 'zero duration did not enter immediately');
    Check(not Step(False, 201, -1, 1, 4), 'layer change kept pose');
    Check(Step(True, 300, 300, 1), 'third pose was not resolved');
    Check(not Step(False, 299, -1, 1), 'backwards seek kept pose');
    Check(Step(True, 315, 300, 1), 'direct seek failed');
    CheckX(5, 'direct seek ignored pose start frame');
  finally
    Transition.Free;
    Model.Free;
  end;
end;

procedure TestConsecutivePoseTransition;
var
  Bones: TPmxBonePoses;
  Current: TPmxNamedBonePoses;
  Model: TPmxModel;
  RootRotation: TPmxQuaternion;
  Transition: TMmdModelPoseTransition;
  Yaw, Pitch: Single;

  function Step(Frame, StartFrame: Integer; Received: Boolean): Boolean;
  begin
    InitializeBonePoses(Model, Bones);
    RootRotation := IdentityQuaternion;
    Yaw := 0;
    Pitch := 0;
    Result := Transition.Resolve(Model, Received, Current,
      IdentityQuaternion, Current[0].Pose.Translation.Y * 2, 0,
      3, 'C:\model\pose.pmx', Frame, StartFrame, StartFrame + 30, 30, 1.0,
      Bones, RootRotation, Yaw, Pitch);
  end;
begin
  Model := TPmxModel.Create;
  Transition := TMmdModelPoseTransition.Create;
  try
    SetLength(Model.Bones, 2);
    Model.Bones[0].Name := 'center';
    Model.Bones[1].Name := 'arm';
    SetLength(Current, 2);
    Current[0].BoneName := 'center';
    Current[0].Pose.Translation.X := 10;
    Current[0].Pose.Translation.Y := 10;
    Current[0].Pose.Rotation := IdentityQuaternion;
    Current[1].BoneName := 'arm';
    Current[1].Pose.Translation.X := 5;
    Current[1].Pose.Rotation := IdentityQuaternion;
    Check(Step(100, 100, True), 'first pose did not start');
    Check(Step(130, 100, True), 'first pose did not finish');
    Check(Abs(Bones[0].Translation.X - 10) < 0.0001,
      'first pose center mismatch');
    SetLength(Current, 1);
    Current[0].Pose.Translation.X := 20;
    Current[0].Pose.Translation.Y := 30;
    Check(Step(131, 131, True), 'second pose did not start');
    Check((Abs(Bones[0].Translation.X - 10) < 0.0001) and
      (Abs(Bones[1].Translation.X - 5) < 0.0001) and
      (Abs(Yaw - 20) < 0.0001),
      'second pose restarted from standard instead of first pose');
    Check(Step(146, 131, True), 'second pose midpoint failed');
    Check((Abs(Bones[0].Translation.X - 15) < 0.0001) and
      (Abs(Bones[1].Translation.X - 2.5) < 0.0001) and
      (Abs(Yaw - 40) < 0.0001),
      'second pose did not crossfade bones and angle');
    Current[0].Pose.Translation.X := 30;
    Current[0].Pose.Translation.Y := 40;
    Check(Step(147, 147, True), 'third pose did not start');
    Check((Abs(Bones[0].Translation.X - 15) < 0.0001) and
      (Abs(Bones[1].Translation.X - 2.5) < 0.0001) and
      (Abs(Yaw - 40) < 0.0001),
      'third pose did not keep the visible midpoint');
    Check(Step(152, 147, True), 'third pose entry failed');
    Check(Abs(Bones[0].Translation.X - 17.5) < 0.0001,
      'third pose entry mismatch');
    Check(Step(167, -1, False), 'third pose release failed');
    Check(Abs(Bones[0].Translation.X - 8.75) < 0.0001,
      'release did not start from the third pose visible state');
  finally
    Transition.Free;
    Model.Free;
  end;
end;

procedure TestSkippedConsecutiveAngle;
var
  Bones: TPmxBonePoses;
  Current: TPmxNamedBonePoses;
  Model: TPmxModel;
  RootRotation: TPmxQuaternion;
  Transition: TMmdModelPoseTransition;
  Yaw, Pitch: Single;
begin
  Model := TPmxModel.Create;
  Transition := TMmdModelPoseTransition.Create;
  try
    SetLength(Model.Bones, 1);
    Model.Bones[0].Name := 'center';
    SetLength(Current, 1);
    Current[0].BoneName := 'center';
    Current[0].Pose.Rotation := IdentityQuaternion;
    Current[0].Pose.Translation.X := 10;
    InitializeBonePoses(Model, Bones);
    RootRotation := IdentityQuaternion;
    Yaw := 5;
    Pitch := -5;
    Check(Transition.Resolve(Model, True, Current, IdentityQuaternion,
      20, 10, 3, 'C:\model\pose.pmx', 120, 100, 130, 30, 1.0,
      Bones, RootRotation, Yaw, Pitch), 'previous pose failed');
    Current[0].Pose.Translation.X := 20;
    InitializeBonePoses(Model, Bones);
    RootRotation := IdentityQuaternion;
    Yaw := 0;
    Pitch := 0;
    // AviUtl2が131..134を描画せず135へ進めても、配置は連続している。
    Check(Transition.Resolve(Model, True, Current, IdentityQuaternion,
      60, 30, 3, 'C:\model\pose.pmx', 135, 131, 160, 30, 1.0,
      Bones, RootRotation, Yaw, Pitch), 'skipped next pose failed');
    Check((Abs(Yaw - (20 + 40 * 4 / 30)) < 0.0001) and
      (Abs(Pitch - (10 + 20 * 4 / 30)) < 0.0001) and
      (Abs(Bones[0].Translation.X - (10 + 10 * 4 / 30)) < 0.0001),
      'skipped frames restarted rotation from the initial pose');
  finally
    Transition.Free;
    Model.Free;
  end;
end;

begin
  try
    TestSharedMemory;
    TestModelPoseLayerInput;
    TestObjectContexts;
    TestPoseTransition;
    TestConsecutivePoseTransition;
    TestSkippedConsecutiveAngle;
    Writeln('MmdPoseSharedMemoryTest: PASS');
  except
    on E: Exception do
    begin
      Writeln('MmdPoseSharedMemoryTest: FAIL: ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
