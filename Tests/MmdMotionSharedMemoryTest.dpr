program MmdMotionSharedMemoryTest;

{$APPTYPE CONSOLE}

uses
  Winapi.Windows,
  System.SysUtils,
  AviUtl2FilterTypes in '..\Source\Lib\AviUtl2FilterTypes.pas',
  PmxModel in '..\..\AviUtl2PluginLib\MMD\Core\PmxModel.pas',
  PmxPoseTypes in '..\..\AviUtl2PluginLib\MMD\Core\PmxPoseTypes.pas',
  PmxPoseMath in '..\..\AviUtl2PluginLib\MMD\Core\PmxPoseMath.pas',
  PmxBoneSolver in '..\..\AviUtl2PluginLib\MMD\Core\PmxBoneSolver.pas',
  PmxMorph in '..\..\AviUtl2PluginLib\MMD\Core\PmxMorph.pas',
  PmxPose in '..\..\AviUtl2PluginLib\MMD\Core\PmxPose.pas',
  MmdMorphSettingCodec in
    '..\..\AviUtl2PluginLib\MMD\Common\IO\MmdMorphSettingCodec.pas',
  MmdMotionDocument in
    '..\..\AviUtl2PluginLib\MMD\Common\Motion\MmdMotionDocument.pas',
  MmdMotionDocumentCodec in
    '..\..\AviUtl2PluginLib\MMD\Common\Motion\MmdMotionDocumentCodec.pas',
  MmdMotionDocumentEvaluator in
    '..\..\AviUtl2PluginLib\MMD\Common\Motion\MmdMotionDocumentEvaluator.pas',
  MmdMotionSharedCodec in
    '..\..\AviUtl2PluginLib\MMD\IPC\Motion\MmdMotionSharedCodec.pas',
  MmdMotionSharedMemory in
    '..\..\AviUtl2PluginLib\MMD\IPC\Motion\MmdMotionSharedMemory.pas',
  MMD_Motion_Runtime in
    '..\Source\Plugin\Motion\MMD_Motion_Runtime.pas',
  MMD_Model_MotionInput in
    '..\Source\Plugin\Model\Input\Motion\MMD_Model_MotionInput.pas';

var
  MotionObjectAvailable: Boolean;
  RequestedLayer: Integer;
  RequestedOffset: Double;

function TestGetImageObject(Layer: Integer;
  Offset: Double): OBJECT_HANDLE; cdecl;
begin
  RequestedLayer := Layer;
  RequestedOffset := Offset;
  if MotionObjectAvailable then
    Result := Pointer(1)
  else
    Result := nil;
end;

procedure Check(Condition: Boolean; const Message_: string);
begin
  if not Condition then raise Exception.Create(Message_);
end;

procedure TestModelMotionInput(const Snapshot: TMmdMotionSharedSnapshot);
var
  BonePoses: TPmxBonePoses;
  Model: TPmxModel;
  MorphActive, PoseActive: Boolean;
  Morphs: TMmdNamedMorphWeights;
  MorphWeights: TPmxMorphWeights;
  ObjectInfo: TOBJECT_INFO;
  Poses: TPmxNamedBonePoses;
  Published: TMmdMotionSharedSnapshot;
  TestLayer: Integer;
  Video: TFILTER_PROC_VIDEO;
begin
  TestLayer := 12000 + Integer(GetCurrentProcessId mod 10000);
  Published := Snapshot;
  Published.TimelineFrame := 905;
  Published.ModelPathHash := HashMotionModelPath('C:\model\receiver.pmx');
  Check(PublishMotionSnapshot(TestLayer, Published),
    'receiver snapshot publish failed');
  ObjectInfo := Default(TOBJECT_INFO);
  ObjectInfo.FrameS := 900;
  ObjectInfo.Frame := 5;
  Video := Default(TFILTER_PROC_VIDEO);
  Video.Object_ := @ObjectInfo;
  Video.GetImageObject := TestGetImageObject;
  MotionObjectAvailable := True;
  Check(TryGetReferencedMotion(@Video, TestLayer + 1,
    'C:\model\receiver.pmx', Poses, Morphs),
    'model did not receive the current motion snapshot');
  Check((RequestedLayer = TestLayer) and (RequestedOffset = 0),
    'model requested a wrong motion layer');
  Check((Length(Poses) = 1) and (Length(Morphs) = 1),
    'model motion payload mismatch');

  Model := TPmxModel.Create;
  try
    SetLength(Model.Bones, 1);
    Model.Bones[0].Name := 'center';
    Model.Bones[0].ParentIndex := -1;
    SetLength(Model.Morphs, 1);
    Model.Morphs[0].Name := 'smile';
    InitializeBonePoses(Model, BonePoses);
    ResolveMotionForModel(Model, Poses, Morphs, BonePoses, MorphWeights,
      PoseActive, MorphActive);
    Check(PoseActive and MorphActive and
      (Abs(BonePoses[0].Translation.X -
        Poses[0].Pose.Translation.X) < 0.0001) and
      (Abs(MorphWeights[0] - Morphs[0].Weight) < 0.0001),
      'motion values were not resolved against the PMX model');
  finally
    Model.Free;
  end;
  Published.TimelineFrame := 904;
  Check(PublishMotionSnapshot(TestLayer, Published),
    'stale receiver snapshot publish failed');
  Check(not TryGetReferencedMotion(@Video, TestLayer + 1,
    'C:\model\receiver.pmx', Poses, Morphs),
    'stale motion frame was accepted');
  MotionObjectAvailable := False;
  Check(not TryGetReferencedMotion(@Video, TestLayer + 1,
    'C:\model\receiver.pmx', Poses, Morphs),
    'motion outside the object range was accepted');
end;

procedure Run;
var
  BoneKey: TMmdMotionBoneKey;
  BoneTrack: TMmdMotionBoneTrack;
  Curve: TMmdBezierCurve;
  Document: TMmdMotionDocument;
  MotionData: string;
  MorphKey: TMmdMotionMorphKey;
  MorphTrack: TMmdMotionMorphTrack;
  Morphs: TMmdNamedMorphWeights;
  Poses: TPmxNamedBonePoses;
  ReadBack, Snapshot: TMmdMotionSharedSnapshot;
  Runtime: TMmdMotionRuntime;
  TestLayer: Integer;
begin
  Document := TMmdMotionDocument.Create;
  Runtime := TMmdMotionRuntime.Create(5001);
  try
    BoneTrack := TMmdMotionBoneTrack.Create('center');
    BoneKey := Default(TMmdMotionBoneKey);
    BoneKey.Rotation.W := 1;
    BoneKey.TranslationXCurve := LinearMmdBezierCurve;
    BoneKey.TranslationYCurve := LinearMmdBezierCurve;
    BoneKey.TranslationZCurve := LinearMmdBezierCurve;
    BoneKey.RotationCurve := LinearMmdBezierCurve;
    BoneTrack.Keys.Add(BoneKey);
    BoneKey.Frame := 10;
    BoneKey.Translation.X := 10;
    BoneKey.Rotation.W := 0;
    BoneKey.Rotation.Z := 1;
    Curve.X1 := 127;
    Curve.Y1 := 0;
    Curve.X2 := 127;
    Curve.Y2 := 127;
    BoneKey.TranslationXCurve := Curve;
    BoneKey.RotationCurve := Curve;
    BoneTrack.Keys.Add(BoneKey);
    Document.BoneTracks.Add(BoneTrack);

    MorphTrack := TMmdMotionMorphTrack.Create('smile');
    MorphKey.Frame := 0;
    MorphKey.Weight := 0;
    MorphTrack.Keys.Add(MorphKey);
    MorphKey.Frame := 10;
    MorphKey.Weight := 1;
    MorphTrack.Keys.Add(MorphKey);
    Document.MorphTracks.Add(MorphTrack);

    MotionData := EncodeMmdMotionDocument(Document);
    Check(Runtime.Evaluate(6001, MotionData, 5, Poses, Morphs),
      'runtime evaluation failed');
    Check((Length(Poses) = 1) and (Poses[0].BoneName = 'center'),
      'bone result is missing');
    Check(Poses[0].Pose.Translation.X < 4,
      'right-key VMD Bezier was not applied');
    Check((Length(Morphs) = 1) and (Morphs[0].Name = 'smile') and
      (Abs(Morphs[0].Weight - 0.5) < 0.0001),
      'morph interpolation mismatch');
    Check(Runtime.ObjectID = 6001, 'runtime object id mismatch');
    Check(not Runtime.Evaluate(6001, '{broken', 5, Poses, Morphs),
      'invalid motion JSON was accepted');
    Check(Runtime.Evaluate(6001, MotionData, 5, Poses, Morphs),
      'runtime did not recover after invalid JSON');

    Snapshot.WriterObjectID := 6001;
    Snapshot.WriterEffectID := 5001;
    Snapshot.TimelineFrame := 7001;
    Snapshot.MotionFrame := 5;
    Snapshot.ModelPathHash := HashMotionModelPath('C:\model\sample.pmx');
    Snapshot.Poses := Poses;
    Snapshot.Morphs := Morphs;
    TestLayer := 2000 + Integer(GetCurrentProcessId mod 10000);
    Check(PublishMotionSnapshot(TestLayer, Snapshot),
      'motion snapshot publish failed');
    Check(TryReadMotionSnapshot(TestLayer, Snapshot.ModelPathHash, ReadBack),
      'motion snapshot read failed');
    Check((ReadBack.WriterObjectID = 6001) and
      (ReadBack.WriterEffectID = 5001) and
      (ReadBack.TimelineFrame = 7001) and
      (Abs(ReadBack.MotionFrame - 5) < 0.0001),
      'motion snapshot header mismatch');
    Check((Length(ReadBack.Poses) = 1) and
      (ReadBack.Poses[0].BoneName = 'center') and
      (Abs(ReadBack.Poses[0].Pose.Translation.X -
        Poses[0].Pose.Translation.X) < 0.0001),
      'motion snapshot bone payload mismatch');
    Check((Length(ReadBack.Morphs) = 1) and
      (ReadBack.Morphs[0].Name = 'smile') and
      (Abs(ReadBack.Morphs[0].Weight - 0.5) < 0.0001),
      'motion snapshot morph payload mismatch');
    Check(not TryReadMotionSnapshot(TestLayer,
      Snapshot.ModelPathHash + 1, ReadBack),
      'snapshot for a different PMX was accepted');
    TestModelMotionInput(Snapshot);
  finally
    Runtime.Free;
    Document.Free;
  end;
end;

begin
  try
    Run;
    Writeln('MmdMotionSharedMemoryTest: PASS');
  except
    on E: Exception do
    begin
      Writeln('MmdMotionSharedMemoryTest: FAIL: ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
