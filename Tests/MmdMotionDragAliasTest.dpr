program MmdMotionDragAliasTest;

{$APPTYPE CONSOLE}

uses
  System.IOUtils,
  System.SysUtils,
  PmxModel in '..\..\AviUtl2PluginLib\MMD\Core\PmxModel.pas',
  PmxPoseTypes in '..\..\AviUtl2PluginLib\MMD\Core\PmxPoseTypes.pas',
  PmxPoseMath in '..\..\AviUtl2PluginLib\MMD\Core\PmxPoseMath.pas',
  PmxBoneSolver in '..\..\AviUtl2PluginLib\MMD\Core\PmxBoneSolver.pas',
  PmxMorph in '..\..\AviUtl2PluginLib\MMD\Core\PmxMorph.pas',
  PmxPose in '..\..\AviUtl2PluginLib\MMD\Core\PmxPose.pas',
  MmdMotionDocument in
    '..\..\AviUtl2PluginLib\MMD\Common\Motion\MmdMotionDocument.pas',
  MmdMotionDocumentCodec in
    '..\..\AviUtl2PluginLib\MMD\Common\Motion\MmdMotionDocumentCodec.pas',
  MmdMotionObjectDragAlias in
    '..\Source\Plugin\Extension\Motion\Catalog\Drag\MmdMotionObjectDragAlias.pas';

procedure Check(Condition: Boolean; const Message_: string);
begin
  if not Condition then raise Exception.Create(Message_);
end;

procedure Run;
var
  AliasBytes: TBytes;
  AliasFileName, AliasText, ModelFileName, MotionData, TestFolder: string;
  Document: TMmdMotionDocument;
  Key: TMmdMotionMorphKey;
  Track: TMmdMotionMorphTrack;
begin
  TestFolder := TPath.Combine(TPath.GetTempPath,
    'MmdMotionDragAlias-' + TPath.GetRandomFileName);
  AliasFileName := TPath.Combine(TestFolder, 'Motion.object');
  ModelFileName := TPath.Combine(TestFolder, 'Model.pmx');
  Document := TMmdMotionDocument.Create;
  try
    TDirectory.CreateDirectory(TestFolder);
    TFile.WriteAllBytes(ModelFileName, nil);
    Track := TMmdMotionMorphTrack.Create('smile');
    Key.Frame := 35;
    Key.Weight := 0.75;
    Track.Keys.Add(Key);
    Document.MorphTracks.Add(Track);
    MotionData := EncodeMmdMotionDocument(Document);
    Check(TryBuildMmdMotionObjectAlias(ModelFileName, MotionData,
      AliasText), 'valid motion alias was rejected');
    Check(Pos('frame=0,36', AliasText) > 0,
      'motion frame length does not include the final key');
    Check(Pos('effect.name=MMD' + #$30E2#$30FC#$30B7#$30E7#$30F3 +
      '@MMD_Script', AliasText) > 0, 'motion script effect is missing');
    Check(Pos(#$30E2#$30C7#$30EB#$30D5#$30A1#$30A4#$30EB + '=' +
      ModelFileName, AliasText) > 0, 'model path is missing');
    Check(Pos(#$30E2#$30FC#$30B7#$30E7#$30F3#$30C7#$30FC#$30BF + '=' +
      MotionData, AliasText) > 0, 'serialized motion data is missing');
    Check(Pos('effect.name=' + #$6A19#$6E96#$63CF#$753B,
      AliasText) > 0, 'standard drawing is missing');
    Check(not TryBuildMmdMotionObjectAlias(ModelFileName, '{broken',
      AliasText), 'invalid motion JSON was accepted');
    Check(not TryBuildMmdMotionObjectAlias(ModelFileName + #10,
      MotionData, AliasText), 'line break in model path was accepted');
    Check(TryWriteMmdMotionObjectAlias(ModelFileName, MotionData,
      AliasFileName), 'motion alias file was not written');
    AliasBytes := TFile.ReadAllBytes(AliasFileName);
    Check(not ((Length(AliasBytes) >= 3) and (AliasBytes[0] = $EF) and
      (AliasBytes[1] = $BB) and (AliasBytes[2] = $BF)),
      'motion alias contains a UTF-8 BOM');
  finally
    Document.Free;
    if TDirectory.Exists(TestFolder) then
      TDirectory.Delete(TestFolder, True);
  end;
end;

begin
  try
    Run;
    Writeln('MmdMotionDragAliasTest: PASS');
  except
    on E: Exception do
    begin
      Writeln('MmdMotionDragAliasTest: FAIL: ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
