program MmdFaceDragAliasTest;

{$APPTYPE CONSOLE}

uses
  System.IOUtils,
  System.SysUtils,
  MmdMorphSettingCodec in
    '..\AviUtl2PluginLib\MMD\Common\IO\MmdMorphSettingCodec.pas',
  PmxModel in '..\AviUtl2PluginLib\MMD\Core\PmxModel.pas',
  PmxMorph in '..\AviUtl2PluginLib\MMD\Core\PmxMorph.pas',
  MmdFaceObjectDragAlias in
    '..\Source\Plugin\Extension\Face\Catalog\Drag\MmdFaceObjectDragAlias.pas';

procedure Check(Condition: Boolean; const Message_: string);
begin
  if not Condition then raise Exception.Create(Message_);
end;

procedure Run;
const
  FaceData = '{"version":1,"morphs":[' +
    '{"name":"smile","weight":0.75}]}';
var
  AliasBytes: TBytes;
  AliasFileName, AliasText, ModelFileName, TestFolder: string;
begin
  TestFolder := TPath.Combine(TPath.GetTempPath,
    'MmdFaceDragAlias-' + TPath.GetRandomFileName);
  AliasFileName := TPath.Combine(TestFolder, 'Face.object');
  ModelFileName := TPath.Combine(TestFolder, 'Model.pmx');
  try
    TDirectory.CreateDirectory(TestFolder);
    TFile.WriteAllBytes(ModelFileName, nil);
    Check(TryBuildMmdFaceObjectAlias(ModelFileName, FaceData, AliasText),
      'valid face alias was rejected');
    Check(Pos('effect.name=' + #$8868#$60C5, AliasText) > 0,
      'face effect is missing');
    Check(Pos(#$30E2#$30C7#$30EB#$30D5#$30A1#$30A4#$30EB + '=' +
      ModelFileName, AliasText) > 0, 'model path is missing');
    Check(Pos(#$8868#$60C5 + '=' + FaceData, AliasText) > 0,
      'face data is missing');
    Check(Pos(#$8A2D#$5B9A + '=', AliasText) > 0,
      'settings entry is missing');
    Check(Pos('effect.name=' + #$6A19#$6E96#$63CF#$753B,
      AliasText) > 0, 'standard drawing is missing');
    Check(Pos('effect.name=' + #$30DD#$30FC#$30BA, AliasText) = 0,
      'face drag created a pose object');
    Check(not TryBuildMmdFaceObjectAlias(ModelFileName, '{broken',
      AliasText), 'invalid face JSON was accepted');
    Check(not TryBuildMmdFaceObjectAlias(ModelFileName + #10, FaceData,
      AliasText), 'line break in model path was accepted');
    Check(TryWriteMmdFaceObjectAlias(ModelFileName, FaceData,
      AliasFileName), 'face alias file was not written');
    AliasBytes := TFile.ReadAllBytes(AliasFileName);
    Check(not ((Length(AliasBytes) >= 3) and (AliasBytes[0] = $EF) and
      (AliasBytes[1] = $BB) and (AliasBytes[2] = $BF)),
      'face alias contains a UTF-8 BOM');
  finally
    if TDirectory.Exists(TestFolder) then
      TDirectory.Delete(TestFolder, True);
  end;
end;

begin
  try
    Run;
    Writeln('MmdFaceDragAliasTest: PASS');
  except
    on E: Exception do
    begin
      Writeln('MmdFaceDragAliasTest: FAIL: ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
