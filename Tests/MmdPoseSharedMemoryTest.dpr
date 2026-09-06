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
  RequestedLayer: Integer;
  RequestedOffset: Double;

function TestGetImageObject(Layer: Integer;
  Offset: Double): OBJECT_HANDLE; cdecl;
begin
  RequestedLayer := Layer;
  RequestedOffset := Offset;
  if PoseObjectAvailable then
    Result := Pointer(1)
  else
    Result := nil;
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
  Snapshot: TMmdPoseSharedSnapshot;
  Video: TFILTER_PROC_VIDEO;
begin
  ObjectInfo := Default(TOBJECT_INFO);
  ObjectInfo.FrameS := 900;
  ObjectInfo.Frame := 45;
  Video := Default(TFILTER_PROC_VIDEO);
  Video.Object_ := @ObjectInfo;
  Video.GetImageObject := TestGetImageObject;
  Snapshot.WriterObjectID := 301;
  Snapshot.WriterEffectID := 401;
  // PoseとModelの配置開始位置が異なっても、存在中なら姿勢を受理する。
  Snapshot.TimelineFrame := 123;
  Snapshot.ModelPathHash := HashModelPath(ModelFileName);
  Snapshot.PoseData := PoseData;
  Check(PublishPoseSnapshot(903, Snapshot),
    'model pose input publish failed');
  PoseObjectAvailable := True;
  RequestedLayer := -1;
  RequestedOffset := -1;
  Check(TryGetReferencedPoseData(@Video, 904, ModelFileName,
    ReadPoseData), 'model did not read referenced pose layer');
  Check(RequestedLayer = 903, 'display layer was not converted to SDK layer');
  Check(RequestedOffset = 0, 'pose layer was not evaluated at current time');
  Check(ReadPoseData = PoseData, 'model pose input data mismatch');
  PoseObjectAvailable := False;
  Check(not TryGetReferencedPoseData(@Video, 904, ModelFileName,
    ReadPoseData), 'model accepted pose data without a pose object');
  PoseObjectAvailable := True;
  Check(not TryGetReferencedPoseData(@Video, 904,
    'C:\model\different.pmx', ReadPoseData),
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

procedure TestPoseReleaseTransition;
var
  BasePoses: TPmxBonePoses;
  Current, Resolved: TPmxNamedBonePoses;
  Model: TPmxModel;
  Transition: TMmdModelPoseTransition;
  Weight: Single;
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
    Check(Transition.Resolve(True, Current, 3, 'C:\model\pose.pmx',
      100, 30, 1.0, Resolved, Weight), 'active pose was not resolved');
    Check(Abs(Weight - 1) < 0.0001, 'active pose weight mismatch');
    Check(Transition.Resolve(False, nil, 3, 'C:\model\pose.pmx',
      115, 30, 1.0, Resolved, Weight), 'release midpoint was not resolved');
    Check(Abs(Weight - 0.5) < 0.0001, 'release midpoint weight mismatch');
    InitializeBonePoses(Model, BasePoses);
    Check(ApplyWeightedNamedBonePoses(Model, Resolved, Weight, BasePoses),
      'weighted pose was not applied');
    Check(Abs(BasePoses[0].Translation.X - 5) < 0.0001,
      'translation was not blended toward base pose');
    Check((Abs(BasePoses[0].Rotation.Z - Sqrt(0.5)) < 0.0001) and
      (Abs(BasePoses[0].Rotation.W - Sqrt(0.5)) < 0.0001),
      'rotation did not use quaternion interpolation');
    Check(not Transition.Resolve(False, nil, 3, 'C:\model\pose.pmx',
      130, 30, 1.0, Resolved, Weight), 'release did not finish on time');
    Check(not Transition.Resolve(False, nil, 3, 'C:\model\pose.pmx',
      131, 30, 0, Resolved, Weight), 'zero duration did not disable release');
    Check(Transition.Resolve(True, Current, 3, 'C:\model\pose.pmx',
      200, 30, 1.0, Resolved, Weight), 'second active pose was not resolved');
    Check(not Transition.Resolve(False, nil, 4, 'C:\model\pose.pmx',
      201, 30, 1.0, Resolved, Weight),
      'pose survived a reference layer change');
    Check(Transition.Resolve(True, Current, 3, 'C:\model\pose.pmx',
      300, 30, 1.0, Resolved, Weight), 'third active pose was not resolved');
    Check(not Transition.Resolve(False, nil, 3, 'C:\model\pose.pmx',
      299, 30, 1.0, Resolved, Weight),
      'pose survived a backwards seek without a source object');
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
    TestPoseReleaseTransition;
    Writeln('MmdPoseSharedMemoryTest: PASS');
  except
    on E: Exception do
    begin
      Writeln('MmdPoseSharedMemoryTest: FAIL: ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
