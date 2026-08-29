program MmdPmxPoseDragAliasTest;

{$APPTYPE CONSOLE}

uses
  System.IOUtils,
  System.SysUtils,
  MmdMorphSettingCodec in
    '..\AviUtl2PluginLib\MMD\Common\IO\MmdMorphSettingCodec.pas',
  MmdEyeBlinkSettingCodec in
    '..\AviUtl2PluginLib\MMD\Common\IO\MmdEyeBlinkSettingCodec.pas',
  MmdLipSyncSettingCodec in
    '..\AviUtl2PluginLib\MMD\Common\IO\MmdLipSyncSettingCodec.pas',
  PmxModel in '..\AviUtl2PluginLib\MMD\Core\PmxModel.pas',
  PmxMorph in '..\AviUtl2PluginLib\MMD\Core\PmxMorph.pas',
  PmxPoseTypes in '..\AviUtl2PluginLib\MMD\Core\PmxPoseTypes.pas',
  PmxPoseMath in '..\AviUtl2PluginLib\MMD\Core\PmxPoseMath.pas',
  PmxPose in '..\AviUtl2PluginLib\MMD\Core\PmxPose.pas',
  PmxPoseCodec in '..\AviUtl2PluginLib\MMD\IO\PmxPoseCodec.pas',
  PmxPoseCatalogStorage in
    '..\Source\Plugin\Extension\PMX\Catalog\Pose\PmxPoseCatalogStorage.pas',
  PmxPoseCatalogDataValidation in
    '..\Source\Plugin\Extension\PMX\Catalog\Pose\Storage\PmxPoseCatalogDataValidation.pas',
  PmxPoseCatalogDragAlias in
    '..\Source\Plugin\Extension\PMX\Catalog\Pose\Drag\PmxPoseCatalogDragAlias.pas',
  MmdPoseObjectDragAlias in
    '..\Source\Plugin\Extension\Pose\Catalog\Drag\MmdPoseObjectDragAlias.pas';

var
  AliasBytes: TBytes;
  AliasFileName: string;
  AliasText: string;
  DragEyeBlinkData: string;
  LipSyncData: string;
  LipSyncSetting: TMmdLipSyncSetting;
  ModelFileName: string;
  PoseObjectAliasFileName: string;
  PoseObjectAliasText: string;
  TestFolder: string;

procedure TestPoseCatalogStorage(const ModelFolder: string);
const
  EyeBlinkData = '{"version":1,"morph":"blink","closedWeight":0.8}';
  ExpressionData = '{"version":1,"morphs":[' +
    '{"name":"smile","weight":0.75}]}';
var
  LipSyncData: string;
  LipSyncSetting: TMmdLipSyncSetting;
  Storage: TPmxPoseCatalogStorage;
begin
  LipSyncSetting := DefaultMmdLipSyncSetting;
  LipSyncSetting.Initialized := True;
  LipSyncSetting.OpenClose.MorphName := 'open';
  LipSyncSetting.OpenClose.Weight := 1.0;
  LipSyncData := EncodeMmdLipSyncSettingData(LipSyncSetting);
  Storage := TPmxPoseCatalogStorage.Create(ModelFolder, 'pmx-id', 'model');
  try
    if not Storage.LoadOrCreateDefault or (Storage.Count <> 1) then
      raise Exception.Create('default pose catalog was not created');
    if Storage[0].InitialExpressionData <> EmptyMmdMorphSettingData then
      raise Exception.Create('default initial expression is invalid');
    if Storage[0].InitialEyeBlinkData <> EmptyMmdEyeBlinkSettingData then
      raise Exception.Create('default initial eye blink is invalid');
    if Storage[0].InitialLipSyncData <> EmptyMmdLipSyncSettingData then
      raise Exception.Create('default initial lip sync is invalid');
    Storage[0].InitialExpressionData := ExpressionData;
    Storage[0].InitialEyeBlinkData := EyeBlinkData;
    Storage[0].InitialLipSyncData := LipSyncData;
    if not Storage.SaveToFile then
      raise Exception.Create('initial expression was not saved');
  finally
    Storage.Free;
  end;
  Storage := TPmxPoseCatalogStorage.Create(ModelFolder, 'pmx-id', 'model');
  try
    if not Storage.LoadOrCreateDefault or
      (Storage[0].InitialExpressionData <> ExpressionData) or
      (Storage[0].InitialEyeBlinkData <> EyeBlinkData) then
      raise Exception.Create('initial morph settings were not restored');
    if Storage[0].InitialLipSyncData <> LipSyncData then
      raise Exception.Create('initial lip sync setting was not restored');
  finally
    Storage.Free;
  end;
end;

begin
  TestFolder := TPath.Combine(TPath.GetTempPath,
    'MmdPmxPoseDragAlias-' + TPath.GetRandomFileName);
  AliasFileName := TPath.Combine(TestFolder, 'Pose.object');
  PoseObjectAliasFileName := TPath.Combine(TestFolder, 'PoseObject.object');
  ModelFileName := TPath.Combine(TestFolder, 'Model.pmx');
  try
    TDirectory.CreateDirectory(TestFolder);
    TFile.WriteAllBytes(ModelFileName, nil);
    LipSyncSetting := DefaultMmdLipSyncSetting;
    LipSyncSetting.Initialized := True;
    LipSyncSetting.OpenClose.MorphName := #$3042;
    LipSyncSetting.OpenClose.Weight := 1.0;
    LipSyncSetting.SpeedSec := 0.2;
    LipSyncSetting.Strength := 0.75;
    LipSyncData := EncodeMmdLipSyncSettingData(LipSyncSetting);
    DragEyeBlinkData := EncodeMmdEyeBlinkSettingData(
      #$307E#$3070#$305F#$304D, 0.8, 5.5, 0.25, -0.5);
    if not TryBuildPmxPoseObjectAlias(ModelFileName,
      '{"version":1,"bones":[]}',
      '{"version":1,"morphs":[{"name":"smile","weight":1}]}',
      DragEyeBlinkData,
      LipSyncData,
      AliasText) then
      raise Exception.Create('valid alias was rejected');
    if Pos('effect.name=' + #$30E2#$30C7#$30EB#$8868#$793A,
      AliasText) = 0 then
      raise Exception.Create('model effect is missing');
    if Pos(#$30E2#$30C7#$30EB#$30D5#$30A1#$30A4#$30EB + '=' +
      ModelFileName, AliasText) = 0 then
      raise Exception.Create('model path is missing');
    if Pos(#$30DD#$30FC#$30BA + '=' +
      '{"version":1,"bones":[]}', AliasText) = 0 then
      raise Exception.Create('pose data is missing');
    if Pos(#$8A2D#$5B9A + '=', AliasText) = 0 then
      raise Exception.Create('settings button entry is missing');
    if Pos(#$8868#$60C5 + '=' +
      '{"version":1,"morphs":[{"name":"smile","weight":1}]}',
      AliasText) = 0 then
      raise Exception.Create('initial expression data is missing');
    if Pos(#$76EE#$30D1#$30C1#$30C7#$30FC#$30BF + '=' +
      DragEyeBlinkData, AliasText) = 0 then
      raise Exception.Create('eye blink data is missing');
    if Pos(#$76EE#$30D1#$30C1#$9593#$9694 + #$FF08#$79D2#$FF09 +
      '=5.5', AliasText) = 0 then
      raise Exception.Create('eye blink interval is missing');
    if Pos(#$76EE#$30D1#$30C1#$901F#$5EA6 + #$FF08#$79D2#$FF09 +
      '=0.25', AliasText) = 0 then
      raise Exception.Create('eye blink speed is missing');
    if Pos(#$76EE#$30D1#$30C1#$30AA#$30D5#$30BB#$30C3#$30C8 +
      #$FF08#$79D2#$FF09 + '=-0.5', AliasText) = 0 then
      raise Exception.Create('eye blink offset is missing');
    if Pos(#$53E3#$30D1#$30AF#$30C7#$30FC#$30BF + '=' + LipSyncData,
      AliasText) = 0 then
      raise Exception.Create('lip sync data is missing');
    if Pos(#$53E3#$30D1#$30AF#$901F#$5EA6 + #$FF08#$79D2#$FF09 +
      '=0.2', AliasText) = 0 then
      raise Exception.Create('lip sync speed is missing');
    if Pos(#$53E3#$30D1#$30AF#$5F37#$3055 + #$FF08'%'#$FF09 +
      '=75', AliasText) = 0 then
      raise Exception.Create('lip sync strength is missing');
    if TryBuildPmxPoseObjectAlias(ModelFileName, '{broken',
      EmptyMmdMorphSettingData, DragEyeBlinkData, LipSyncData,
      AliasText) then
      raise Exception.Create('invalid pose JSON was accepted');
    if TryBuildPmxPoseObjectAlias(ModelFileName,
      '{"version":1,"bones":[]}', '{broken', DragEyeBlinkData,
      LipSyncData,
      AliasText) then
      raise Exception.Create('invalid initial expression JSON was accepted');
    if TryBuildPmxPoseObjectAlias(ModelFileName,
      '{"version":1,"bones":[]}', EmptyMmdMorphSettingData, '{broken',
      LipSyncData, AliasText) then
      raise Exception.Create('invalid eye blink JSON was accepted');
    if TryBuildPmxPoseObjectAlias(ModelFileName,
      '{"version":1,"bones":[]}', EmptyMmdMorphSettingData,
      DragEyeBlinkData, '{broken',
      AliasText) then
      raise Exception.Create('invalid lip sync JSON was accepted');
    if not TryWritePmxPoseObjectAlias(ModelFileName,
      '{"version":1,"bones":[]}', EmptyMmdMorphSettingData,
      EmptyMmdEyeBlinkSettingData,
      EmptyMmdLipSyncSettingData, AliasFileName) then
      raise Exception.Create('alias file was not written');
    AliasBytes := TFile.ReadAllBytes(AliasFileName);
    if (Length(AliasBytes) >= 3) and (AliasBytes[0] = $EF) and
      (AliasBytes[1] = $BB) and (AliasBytes[2] = $BF) then
      raise Exception.Create('alias file contains a UTF-8 BOM');
    if not TryBuildMmdPoseObjectAlias(ModelFileName,
      '{"version":1,"bones":[]}', PoseObjectAliasText) then
      raise Exception.Create('pose object alias was rejected');
    if Pos('effect.name=' + #$30DD#$30FC#$30BA,
      PoseObjectAliasText) = 0 then
      raise Exception.Create('pose object effect is missing');
    if Pos(#$30E2#$30C7#$30EB#$30D5#$30A1#$30A4#$30EB + '=' +
      ModelFileName, PoseObjectAliasText) = 0 then
      raise Exception.Create('pose object model path is missing');
    if Pos(#$30DD#$30FC#$30BA + '={"version":1,"bones":[]}',
      PoseObjectAliasText) = 0 then
      raise Exception.Create('renamed pose item is missing');
    if Pos(#$8A2D#$5B9A + '=', PoseObjectAliasText) = 0 then
      raise Exception.Create('renamed settings item is missing');
    if Pos('effect.name=' + #$6A19#$6E96#$63CF#$753B,
      PoseObjectAliasText) = 0 then
      raise Exception.Create('pose object standard drawing is missing');
    if (Pos('effect.name=' + #$30E2#$30C7#$30EB#$8868#$793A,
      PoseObjectAliasText) > 0) or
      (Pos(#$59FF#$52E2#$30C7#$30FC#$30BF + '=',
        PoseObjectAliasText) > 0) or
      (Pos(#$30DD#$30FC#$30BA#$8A2D#$5B9A + '=',
        PoseObjectAliasText) > 0) then
      raise Exception.Create('pose drag still creates a model object');
    if TryBuildMmdPoseObjectAlias(ModelFileName, '{broken',
      PoseObjectAliasText) then
      raise Exception.Create('invalid pose object JSON was accepted');
    if not TryWriteMmdPoseObjectAlias(ModelFileName,
      '{"version":1,"bones":[]}', PoseObjectAliasFileName) then
      raise Exception.Create('pose object alias file was not written');
    AliasBytes := TFile.ReadAllBytes(PoseObjectAliasFileName);
    if (Length(AliasBytes) >= 3) and (AliasBytes[0] = $EF) and
      (AliasBytes[1] = $BB) and (AliasBytes[2] = $BF) then
      raise Exception.Create('pose object alias contains a UTF-8 BOM');
    TestPoseCatalogStorage(TestFolder);
    Writeln('MmdPmxPoseDragAliasTest: PASS');
  except
    on E: Exception do
    begin
      Writeln(E.ClassName + ': ' + E.Message);
      ExitCode := 1;
    end;
  end;
  if TDirectory.Exists(TestFolder) then
    TDirectory.Delete(TestFolder, True);
end.
