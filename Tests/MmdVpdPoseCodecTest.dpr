program MmdVpdPoseCodecTest;

{$APPTYPE CONSOLE}

uses
  System.IOUtils,
  System.Math,
  System.SysUtils,
  PmxModel in '..\..\AviUtl2PluginLib\MMD\Core\PmxModel.pas',
  PmxPose in '..\..\AviUtl2PluginLib\MMD\Core\PmxPose.pas',
  PmxPoseTypes in '..\..\AviUtl2PluginLib\MMD\Core\PmxPoseTypes.pas',
  PmxPoseMath in '..\..\AviUtl2PluginLib\MMD\Core\PmxPoseMath.pas',
  PmxBoneSolver in '..\..\AviUtl2PluginLib\MMD\Core\PmxBoneSolver.pas',
  PmxMorph in '..\..\AviUtl2PluginLib\MMD\Core\PmxMorph.pas',
  PmxPoseCodec in '..\..\AviUtl2PluginLib\MMD\IO\PmxPoseCodec.pas',
  MmdAiPoseRepository in '..\Source\AI\MmdAiPoseRepository.pas',
  MmdVpdDirectory in '..\..\AviUtl2PluginLib\MMD\VPD\IO\MmdVpdDirectory.pas',
  VpdPoseCodec in '..\..\AviUtl2PluginLib\MMD\VPD\IO\VpdPoseCodec.pas';

procedure Check(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

procedure CheckNear(Expected, Actual: Single; const MessageText: string);
begin
  Check(Abs(Expected - Actual) < 0.00001, MessageText);
end;

procedure CheckDirectoryCreation;
var
  CollisionPath, CreatedPath, TestRoot, VpdDirectory: string;
  CollisionRejected: Boolean;
begin
  TestRoot := TPath.Combine(TPath.GetTempPath,
    'MmdVpdDirectoryTest-' + TPath.GetRandomFileName);
  VpdDirectory := TPath.Combine(TestRoot, 'VPD');
  try
    Check(not TDirectory.Exists(VpdDirectory),
      'temporary VPD directory unexpectedly exists');
    CreatedPath := EnsureMmdVpdDirectoryAt(VpdDirectory);
    Check(TDirectory.Exists(CreatedPath), 'VPD directory was not created');
    Check(SameText(CreatedPath, EnsureMmdVpdDirectoryAt(VpdDirectory)),
      'existing VPD directory was not reusable');

    CollisionPath := TPath.Combine(TestRoot, 'VPD-file');
    TFile.WriteAllText(CollisionPath, 'not a directory', TEncoding.UTF8);
    CollisionRejected := False;
    try
      EnsureMmdVpdDirectoryAt(CollisionPath);
    except
      on E: EInOutError do
        CollisionRejected := True;
    end;
    Check(CollisionRejected, 'file collision was accepted as a directory');
  finally
    if TDirectory.Exists(TestRoot) then
      TDirectory.Delete(TestRoot, True);
  end;
end;

procedure CheckRepositoryRoundTrip(const Source: TPmxNamedBonePoses);
var
  LoadedData, SourceData, TempFile, VpdFile: string;
  LoadedPoses: TPmxNamedBonePoses;
begin
  TempFile := TPath.GetTempFileName;
  VpdFile := ChangeFileExt(TempFile, '.vpd');
  TFile.Delete(TempFile);
  try
    SourceData := EncodePoseData(Source);
    UpdateMmdAiPoseFile(VpdFile, SourceData);
    Check(TFile.Exists(VpdFile), 'repository did not write VPD');
    Check(LoadMmdAiPoseFile(VpdFile, LoadedData),
      'repository did not read its CP932 VPD');
    Check(TryDecodePoseData(LoadedData, LoadedPoses),
      'repository returned invalid internal pose data');
    Check((Length(LoadedPoses) = 2) and
      (LoadedPoses[1].BoneName = '左腕'), 'repository round trip changed bones');
  finally
    if TFile.Exists(VpdFile) then
      TFile.Delete(VpdFile);
  end;
end;

procedure RunTests;
var
  Decoded, Source: TPmxNamedBonePoses;
  Text: string;
begin
  CheckDirectoryCreation;
  SetLength(Source, 2);
  Source[0].BoneName := 'センター';
  Source[0].Pose.Translation.X := 1.25;
  Source[0].Pose.Translation.Y := -2.5;
  Source[0].Pose.Translation.Z := 3.75;
  Source[0].Pose.Rotation.W := 1;
  Source[1].BoneName := '左腕';
  Source[1].Pose.Rotation.Z := 0.38268343;
  Source[1].Pose.Rotation.W := 0.92387953;

  Text := EncodeVpdPose('テストモデル', Source);
  Check(Text.StartsWith('Vocaloid Pose Data file'), 'VPD header changed');
  Check(TryDecodeVpdPose(Text, Decoded), 'round trip decode failed');
  Check(Length(Decoded) = 2, 'bone count changed');
  Check(Decoded[0].BoneName = 'センター', 'first bone name changed');
  CheckNear(1.25, Decoded[0].Pose.Translation.X, 'translation changed');
  CheckNear(0.38268343, Decoded[1].Pose.Rotation.Z, 'rotation changed');
  CheckNear(0.92387953, Decoded[1].Pose.Rotation.W, 'rotation W changed');
  CheckRepositoryRoundTrip(Source);

  Check(not TryDecodeVpdPose('not a vpd', Decoded),
    'invalid header was accepted');
  Text := 'Vocaloid Pose Data file' + sLineBreak + 'model.osm;' +
    sLineBreak + '1;' + sLineBreak + 'Bone0{bone' + sLineBreak +
    '0,0,0;' + sLineBreak + '0,0,0,0;' + sLineBreak + '}';
  Check(not TryDecodeVpdPose(Text, Decoded),
    'zero quaternion was accepted');
end;

begin
  try
    RunTests;
    Writeln('MmdVpdPoseCodecTest: PASS');
  except
    on E: Exception do
    begin
      Writeln(E.ClassName + ': ' + E.Message);
      ExitCode := 1;
    end;
  end;
end.
