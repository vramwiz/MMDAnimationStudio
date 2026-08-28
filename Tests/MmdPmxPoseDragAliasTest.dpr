program MmdPmxPoseDragAliasTest;

{$APPTYPE CONSOLE}

uses
  System.IOUtils,
  System.SysUtils,
  PmxPoseCatalogDragAlias in
    '..\Source\Plugin\Extension\PMX\Catalog\Pose\Drag\PmxPoseCatalogDragAlias.pas';

var
  AliasBytes: TBytes;
  AliasFileName: string;
  AliasText: string;
  ModelFileName: string;
  TestFolder: string;

begin
  TestFolder := TPath.Combine(TPath.GetTempPath,
    'MmdPmxPoseDragAlias-' + TPath.GetRandomFileName);
  AliasFileName := TPath.Combine(TestFolder, 'Pose.object');
  ModelFileName := TPath.Combine(TestFolder, 'Model.pmx');
  try
    TDirectory.CreateDirectory(TestFolder);
    TFile.WriteAllBytes(ModelFileName, nil);
    if not TryBuildPmxPoseObjectAlias(ModelFileName,
      '{"version":1,"bones":[]}', AliasText) then
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
    if TryBuildPmxPoseObjectAlias(ModelFileName, '{broken', AliasText) then
      raise Exception.Create('invalid pose JSON was accepted');
    if not TryWritePmxPoseObjectAlias(ModelFileName,
      '{"version":1,"bones":[]}', AliasFileName) then
      raise Exception.Create('alias file was not written');
    AliasBytes := TFile.ReadAllBytes(AliasFileName);
    if (Length(AliasBytes) >= 3) and (AliasBytes[0] = $EF) and
      (AliasBytes[1] = $BB) and (AliasBytes[2] = $BF) then
      raise Exception.Create('alias file contains a UTF-8 BOM');
    Writeln('MmdPmxPoseDragAliasTest: PASS');
  except
    on E: Exception do
    begin
      Writeln(E.ClassName + ': ' + E.Message);
      ExitCode := 1;
    end;
  end;
  if TFile.Exists(AliasFileName) then
    TFile.Delete(AliasFileName);
  if TFile.Exists(ModelFileName) then
    TFile.Delete(ModelFileName);
  if TDirectory.Exists(TestFolder) then
    TDirectory.Delete(TestFolder, False);
end.
