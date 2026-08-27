program MmdPoseSharedMemoryTest;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  AviUtl2FilterTypes in 'Source\Lib\AviUtl2FilterTypes.pas',
  MmdPoseSharedMemory in '..\AviUtl2PluginLib\MMD\IPC\MmdPoseSharedMemory.pas',
  PmxModel in '..\AviUtl2PluginLib\MMD\Core\PmxModel.pas',
  PmxPoseTypes in '..\AviUtl2PluginLib\MMD\Core\PmxPoseTypes.pas',
  PmxPoseMath in '..\AviUtl2PluginLib\MMD\Core\PmxPoseMath.pas',
  PmxBoneSolver in '..\AviUtl2PluginLib\MMD\Core\PmxBoneSolver.pas',
  PmxPose in '..\AviUtl2PluginLib\MMD\Core\PmxPose.pas',
  PmxPoseCodec in '..\AviUtl2PluginLib\MMD\IO\PmxPoseCodec.pas',
  MMD_Model_Context in 'Source\Plugin\Model\Context\MMD_Model_Context.pas';

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
  Check(TryReadPoseSnapshot(876, 345, Snapshot.ModelPathHash, ReadBack),
    'read failed');
  Check(ReadBack.WriterObjectID = 101, 'object id mismatch');
  Check(ReadBack.WriterEffectID = 201, 'effect id mismatch');
  Check(ReadBack.PoseData = Snapshot.PoseData, 'pose data mismatch');
  Check(not TryReadPoseSnapshot(876, 346, Snapshot.ModelPathHash, ReadBack),
    'stale frame was accepted');
  Check(not TryReadPoseSnapshot(876, 345, Snapshot.ModelPathHash + 1, ReadBack),
    'different model was accepted');
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

begin
  try
    TestSharedMemory;
    TestObjectContexts;
    Writeln('MmdPoseSharedMemoryTest: PASS');
  except
    on E: Exception do
    begin
      Writeln('MmdPoseSharedMemoryTest: FAIL: ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
