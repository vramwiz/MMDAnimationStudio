program MmdFaceSharedMemoryTest;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  AviUtl2FilterTypes in 'Source\Lib\AviUtl2FilterTypes.pas',
  MmdFaceSharedMemory in
    '..\AviUtl2PluginLib\MMD\IPC\MmdFaceSharedMemory.pas',
  PmxModel in '..\AviUtl2PluginLib\MMD\Core\PmxModel.pas',
  MMD_Model_Context in
    'Source\Plugin\Model\Context\MMD_Model_Context.pas',
  MMD_Model_FaceInput in
    'Source\Plugin\Model\Input\Face\MMD_Model_FaceInput.pas';

var
  FaceObjectAvailable: Boolean;
  RequestedLayer: Integer;
  RequestedOffset: Double;

function TestGetImageObject(Layer: Integer;
  Offset: Double): OBJECT_HANDLE; cdecl;
begin
  RequestedLayer := Layer;
  RequestedOffset := Offset;
  if FaceObjectAvailable then Result := Pointer(1)
  else Result := nil;
end;

procedure Check(Condition: Boolean; const Message_: string);
begin
  if not Condition then raise Exception.Create(Message_);
end;

procedure TestSharedMemory;
const
  FaceData = '{"version":1,"morphs":[' +
    '{"name":"smile","weight":0.75}]}';
var
  ReadBack: TMmdFaceSharedSnapshot;
  Snapshot: TMmdFaceSharedSnapshot;
begin
  Snapshot.WriterObjectID := 111;
  Snapshot.WriterEffectID := 211;
  Snapshot.TimelineFrame := 355;
  Snapshot.ModelPathHash := HashFaceModelPath('C:\model\sample.pmx');
  Snapshot.FaceData := FaceData;
  Check(PublishFaceSnapshot(886, Snapshot), 'publish failed');
  Check(TryReadFaceSnapshot(886, Snapshot.ModelPathHash, ReadBack),
    'read failed');
  Check(ReadBack.WriterObjectID = 111, 'object id mismatch');
  Check(ReadBack.WriterEffectID = 211, 'effect id mismatch');
  Check(ReadBack.TimelineFrame = 355, 'timeline frame mismatch');
  Check(ReadBack.FaceData = FaceData, 'face data mismatch');
  Check(not TryReadFaceSnapshot(886, Snapshot.ModelPathHash + 1, ReadBack),
    'different model was accepted');
end;

procedure TestModelFaceLayerInput;
const
  FaceData = '{"version":1,"morphs":[' +
    '{"name":"wink","weight":1}]}';
  ModelFileName = 'C:\model\face-input.pmx';
var
  ObjectInfo: TOBJECT_INFO;
  ReadFaceData: string;
  Snapshot: TMmdFaceSharedSnapshot;
  Video: TFILTER_PROC_VIDEO;
begin
  ObjectInfo := Default(TOBJECT_INFO);
  ObjectInfo.FrameS := 1000;
  ObjectInfo.Frame := 25;
  Video := Default(TFILTER_PROC_VIDEO);
  Video.Object_ := @ObjectInfo;
  Video.GetImageObject := TestGetImageObject;
  Snapshot.WriterObjectID := 311;
  Snapshot.WriterEffectID := 411;
  Snapshot.TimelineFrame := 222;
  Snapshot.ModelPathHash := HashFaceModelPath(ModelFileName);
  Snapshot.FaceData := FaceData;
  Check(PublishFaceSnapshot(913, Snapshot), 'face input publish failed');
  FaceObjectAvailable := True;
  RequestedLayer := -1;
  RequestedOffset := -1;
  Check(TryGetReferencedFaceData(@Video, 914, ModelFileName,
    ReadFaceData), 'model did not read referenced face layer');
  Check(RequestedLayer = 913, 'display layer was not converted');
  Check(RequestedOffset = 0, 'face layer was not evaluated at current time');
  Check(ReadFaceData = FaceData, 'model face input data mismatch');
  FaceObjectAvailable := False;
  Check(not TryGetReferencedFaceData(@Video, 914, ModelFileName,
    ReadFaceData), 'model accepted data without a face object');
  FaceObjectAvailable := True;
  Check(not TryGetReferencedFaceData(@Video, 914,
    'C:\model\different.pmx', ReadFaceData),
    'model accepted a face for a different PMX');
end;

procedure TestExternalExpressionContext;
var
  Context: TMmdModelContext;
  Model: TPmxModel;
begin
  Model := TPmxModel.Create;
  Context := TMmdModelContext.Create(501);
  try
    SetLength(Model.Morphs, 1);
    Model.Morphs[0].Name := 'smile';
    Context.UpdateInitialExpression('{"version":1,"morphs":[' +
      '{"name":"smile","weight":1}]}');
    Check(Context.ResolveInitialExpression(Model),
      'initial expression was not resolved');
    Context.UpdateExternalExpression('{"version":1,"morphs":[]}');
    Check(not Context.ResolveExternalExpression(Model),
      'empty external expression became active');
    Check(Context.ExternalExpressionValid,
      'empty external expression was not accepted');
    Check((Length(Context.ExternalExpressionWeights) = 1) and
      (Context.ExternalExpressionWeights[0] = 0),
      'empty external expression did not clear the base morph');
    Context.UpdateExternalExpression('{"version":1,"morphs":[' +
      '{"name":"smile","weight":0.5}]}');
    Check(Context.ResolveExternalExpression(Model),
      'external expression was not resolved');
    Check(Abs(Context.ExternalExpressionWeights[0] - 0.5) < 0.0001,
      'external expression weight mismatch');
  finally
    Context.Free;
    Model.Free;
  end;
end;

begin
  try
    TestSharedMemory;
    TestModelFaceLayerInput;
    TestExternalExpressionContext;
    Writeln('MmdFaceSharedMemoryTest: PASS');
  except
    on E: Exception do
    begin
      Writeln('MmdFaceSharedMemoryTest: FAIL: ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
