program MmdVmdCatalogImportTest;

{$APPTYPE CONSOLE}

uses
  Winapi.Windows,
  System.Classes,
  System.IOUtils,
  System.SysUtils,
  PmxModel in '..\..\AviUtl2PluginLib\MMD\Core\PmxModel.pas',
  PmxPoseTypes in '..\..\AviUtl2PluginLib\MMD\Core\PmxPoseTypes.pas',
  PmxPoseMath in '..\..\AviUtl2PluginLib\MMD\Core\PmxPoseMath.pas',
  PmxBoneSolver in '..\..\AviUtl2PluginLib\MMD\Core\PmxBoneSolver.pas',
  PmxMorph in '..\..\AviUtl2PluginLib\MMD\Core\PmxMorph.pas',
  PmxPose in '..\..\AviUtl2PluginLib\MMD\Core\PmxPose.pas',
  PmxPoseCodec in '..\..\AviUtl2PluginLib\MMD\IO\PmxPoseCodec.pas',
  MmdMorphSettingCodec in
    '..\..\AviUtl2PluginLib\MMD\Common\IO\MmdMorphSettingCodec.pas',
  VmdFirstFrameReader in
    '..\..\AviUtl2PluginLib\MMD\VMD\IO\VmdFirstFrameReader.pas',
  VmdMotionReader in
    '..\..\AviUtl2PluginLib\MMD\VMD\IO\VmdMotionReader.pas',
  AppFolderUtils in
    '..\..\AviUtl2PluginLib\Lib\AppFolderUtils\AppFolderUtils.pas',
  MmdVmdCatalogItem in
    '..\Source\Plugin\Extension\VMD\Catalog\MmdVmdCatalogItem.pas',
  MmdVmdCatalogCodec in
    '..\Source\Plugin\Extension\VMD\Catalog\MmdVmdCatalogCodec.pas',
  MmdVmdCatalog in
    '..\Source\Plugin\Extension\VMD\Catalog\MmdVmdCatalog.pas',
  PmxMotionCatalogItem in
    '..\Source\Plugin\Extension\PMX\Catalog\Motion\Storage\PmxMotionCatalogItem.pas',
  PmxMotionCatalogCodec in
    '..\Source\Plugin\Extension\PMX\Catalog\Motion\Storage\PmxMotionCatalogCodec.pas',
  PmxMotionCatalogStorage in
    '..\Source\Plugin\Extension\PMX\Catalog\Motion\PmxMotionCatalogStorage.pas',
  MmdVmdMotionImporter in
    '..\Source\Plugin\Extension\VMD\Import\MmdVmdMotionImporter.pas';

procedure WriteFixed(Stream: TStream; const Value: AnsiString; Size: Integer);
var
  Bytes: TBytes;
  Count: Integer;
begin
  SetLength(Bytes, Size);
  Count := Length(Value);
  if Count > Size then Count := Size;
  if Count > 0 then Move(Value[1], Bytes[0], Count);
  Stream.WriteBuffer(Bytes[0], Size);
end;

procedure WriteCardinal(Stream: TStream; Value: Cardinal);
begin
  Stream.WriteBuffer(Value, SizeOf(Value));
end;

procedure WriteSingle(Stream: TStream; Value: Single);
begin
  Stream.WriteBuffer(Value, SizeOf(Value));
end;

procedure CreateVmd(const FileName: string);
var
  I: Integer;
  Stream: TFileStream;
  Zero: Byte;
begin
  Stream := TFileStream.Create(FileName, fmCreate);
  try
    WriteFixed(Stream, 'Vocaloid Motion Data 0002', 30);
    WriteFixed(Stream, 'sample', 20);
    WriteCardinal(Stream, 2);
    WriteFixed(Stream, 'center', 15);
    WriteCardinal(Stream, 3);
    WriteSingle(Stream, 1.0);
    WriteSingle(Stream, 2.0);
    WriteSingle(Stream, 3.0);
    WriteSingle(Stream, 0.0);
    WriteSingle(Stream, 0.0);
    WriteSingle(Stream, 0.0);
    WriteSingle(Stream, 1.0);
    Zero := 0;
    for I := 0 to 63 do Stream.WriteBuffer(Zero, 1);
    WriteFixed(Stream, 'center', 15);
    WriteCardinal(Stream, 33);
    WriteSingle(Stream, 3.0);
    WriteSingle(Stream, 4.0);
    WriteSingle(Stream, 5.0);
    WriteSingle(Stream, 0.0);
    WriteSingle(Stream, 0.0);
    WriteSingle(Stream, 0.0);
    WriteSingle(Stream, 1.0);
    for I := 0 to 63 do Stream.WriteBuffer(Zero, 1);
    WriteCardinal(Stream, 2);
    WriteFixed(Stream, 'smile', 15);
    WriteCardinal(Stream, 5);
    WriteSingle(Stream, 0.75);
    WriteFixed(Stream, 'smile', 15);
    WriteCardinal(Stream, 35);
    WriteSingle(Stream, 0.25);
  finally
    Stream.Free;
  end;
end;

procedure Run;
var
  FirstFrame: Cardinal;
  ModelName: string;
  ModelRoot, Root, VmdFile: string;
  Morphs: TMmdNamedMorphWeights;
  Motion: TVmdMotionData;
  Motions, Reloaded: TPmxMotionCatalogStorage;
  Poses: TPmxNamedBonePoses;
  Summary: TMmdVmdImportSummary;
begin
  Root := TPath.Combine(TPath.GetTempPath,
    'MmdVmdCatalogImportTest-' + IntToHex(GetCurrentProcessId, 8));
  ModelRoot := TPath.Combine(Root, 'Model');
  VmdFile := TPath.Combine(Root, 'sample.vmd');
  ForceDirectories(ModelRoot);
  CreateVmd(VmdFile);
  if not TryReadVmdFirstFrame(VmdFile, Poses, Morphs, FirstFrame,
    ModelName) then raise Exception.Create('VMD decode failed');
  if (Length(Poses) <> 1) or (Poses[0].BoneName <> 'center') or
    (Abs(Poses[0].Pose.Translation.Y - 2.0) > 0.0001) or
    (Length(Morphs) <> 1) or (Morphs[0].Name <> 'smile') or
    (Abs(Morphs[0].Weight - 0.75) > 0.0001) or (FirstFrame <> 3) or
    (ModelName <> 'sample') then raise Exception.Create('VMD first state mismatch');
  Motion := TVmdMotionData.Create;
  try
    if not Motion.LoadFromFile(VmdFile) or (Motion.MaxFrame <> 35) then
      raise Exception.Create('VMD motion decode failed');
    if not Motion.Evaluate(18, Poses, Morphs) or
      (Length(Poses) <> 1) or
      (Abs(Poses[0].Pose.Translation.Y - 3.0) > 0.0001) then
      raise Exception.Create('VMD bone interpolation failed');
    if not Motion.Evaluate(20, Poses, Morphs) or
      (Length(Morphs) <> 1) or (Abs(Morphs[0].Weight - 0.5) > 0.0001) then
      raise Exception.Create('VMD morph interpolation failed');
  finally
    Motion.Free;
  end;
  Motions := TPmxMotionCatalogStorage.Create(ModelRoot, 'pmx1', 'sample');
  try
    if not Motions.LoadFromFile or (Motions.Count <> 0) then
      raise Exception.Create('empty motion catalog created a default item');
    if not ImportMmdVmdMotions([VmdFile], TPath.Combine(Root, 'VMD'),
      Motions, Summary) or (Summary.MotionAdded <> 1) or
      (Motions.Count <> 1) then raise Exception.Create('VMD import failed');
    if not ImportMmdVmdMotions([VmdFile], TPath.Combine(Root, 'VMD'),
      Motions, Summary) or (Summary.AlreadyRegistered <> 1) or
      (Motions.Count <> 1) then raise Exception.Create('duplicate VMD was added');
  finally
    Motions.Free;
  end;
  Reloaded := TPmxMotionCatalogStorage.Create(ModelRoot, 'pmx1', 'sample');
  try
    if not Reloaded.LoadFromFile or (Reloaded.Count <> 1) or
      (Reloaded[0].FirstFrame <> 3) then
      raise Exception.Create('motion catalog persistence failed');
  finally
    Reloaded.Free;
  end;
  TDirectory.Delete(Root, True);
end;

begin
  try
    Run;
    Writeln('MmdVmdCatalogImportTest: PASS');
  except
    on E: Exception do
    begin
      Writeln('MmdVmdCatalogImportTest: FAIL: ' + E.Message);
      ExitCode := 1;
    end;
  end;
end.
