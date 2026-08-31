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
  MmdMotionDocument in
    '..\..\AviUtl2PluginLib\MMD\Common\Motion\MmdMotionDocument.pas',
  MmdMotionDocumentCodec in
    '..\..\AviUtl2PluginLib\MMD\Common\Motion\MmdMotionDocumentCodec.pas',
  VmdFirstFrameReader in
    '..\..\AviUtl2PluginLib\MMD\VMD\IO\VmdFirstFrameReader.pas',
  VmdMotionReader in
    '..\..\AviUtl2PluginLib\MMD\VMD\IO\VmdMotionReader.pas',
  VmdMotionDocumentReader in
    '..\..\AviUtl2PluginLib\MMD\VMD\IO\VmdMotionDocumentReader.pas',
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
  Interpolation: array[0..63] of Byte;
  Stream: TFileStream;
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
    FillChar(Interpolation, SizeOf(Interpolation), 0);
    Interpolation[0] := 10;
    Interpolation[4] := 20;
    Interpolation[8] := 100;
    Interpolation[12] := 110;
    Interpolation[1] := 11;
    Interpolation[5] := 21;
    Interpolation[9] := 101;
    Interpolation[13] := 111;
    Interpolation[2] := 12;
    Interpolation[6] := 22;
    Interpolation[10] := 102;
    Interpolation[14] := 112;
    Interpolation[3] := 13;
    Interpolation[7] := 23;
    Interpolation[11] := 103;
    Interpolation[15] := 113;
    Stream.WriteBuffer(Interpolation, SizeOf(Interpolation));
    WriteFixed(Stream, 'center', 15);
    WriteCardinal(Stream, 33);
    WriteSingle(Stream, 3.0);
    WriteSingle(Stream, 4.0);
    WriteSingle(Stream, 5.0);
    WriteSingle(Stream, 0.0);
    WriteSingle(Stream, 0.0);
    WriteSingle(Stream, 0.0);
    WriteSingle(Stream, 1.0);
    Stream.WriteBuffer(Interpolation, SizeOf(Interpolation));
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
  BoneKey: TMmdMotionBoneKey;
  DecodedDocument, Document: TMmdMotionDocument;
  DuplicateIndex: Integer;
  EncodedMotion, OriginalMotion: string;
  FirstFrame: Cardinal;
  ModelName: string;
  ModelRoot, MotionDataFile, Root, SourceDataFile, VmdFile: string;
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
  Document := nil;
  DecodedDocument := nil;
  try
    if not TryReadVmdMotionDocument(VmdFile, Document) or
      (Document.BoneTracks.Count <> 1) or
      (Document.BoneTracks[0].Keys.Count <> 2) or
      (Document.MorphTracks.Count <> 1) or
      (Document.BoneTracks[0].Keys[0].TranslationXCurve.X1 <> 10) or
      (Document.BoneTracks[0].Keys[0].TranslationYCurve.Y1 <> 21) or
      (Document.BoneTracks[0].Keys[0].TranslationZCurve.X2 <> 102) or
      (Document.BoneTracks[0].Keys[0].RotationCurve.Y2 <> 113) then
      raise Exception.Create('editable VMD document mismatch');
    EncodedMotion := EncodeMmdMotionDocument(Document);
    if not TryDecodeMmdMotionDocument(EncodedMotion, DecodedDocument) or
      (DecodedDocument.MaxFrame <> 35) or
      (DecodedDocument.BoneTracks[0].Keys[1].RotationCurve.X1 <> 13) then
      raise Exception.Create('motion document round trip failed');
  finally
    DecodedDocument.Free;
    Document.Free;
  end;
  Document := nil;
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
    SourceDataFile := TPath.Combine(TPath.Combine(Root, 'VMD\Data'),
      Motions[0].SourceVmdId + '.json');
    MotionDataFile := TPath.Combine(TPath.Combine(ModelRoot, 'Motions\Data'),
      Motions[0].Id + '.json');
    if not TFile.Exists(SourceDataFile) or not TFile.Exists(MotionDataFile) then
      raise Exception.Create('serialized motion files are missing');
    TFile.Delete(MotionDataFile);
    if not EnsureMmdVmdMotionData(TPath.Combine(Root, 'VMD'), Motions) or
      not TFile.Exists(MotionDataFile) then
      raise Exception.Create('legacy motion data migration failed');
    if not ImportMmdVmdMotions([VmdFile], TPath.Combine(Root, 'VMD'),
      Motions, Summary) or (Summary.AlreadyRegistered <> 1) or
      (Motions.Count <> 1) then raise Exception.Create('duplicate VMD was added');
    if not Motions.LoadMotionData(0, OriginalMotion) or
      not TryDecodeMmdMotionDocument(OriginalMotion, Document) then
      raise Exception.Create('motion data was not persisted');
    Document.Free;
    Document := nil;
    DuplicateIndex := Motions.Duplicate(0);
    if (DuplicateIndex <> 1) or (Motions.Count <> 2) or
      (Motions[0].Id = Motions[1].Id) or
      (Motions[0].SourceVmdId <> Motions[1].SourceVmdId) or
      not Motions.LoadMotionData(DuplicateIndex, EncodedMotion) or
      not TryDecodeMmdMotionDocument(EncodedMotion, Document) then
      raise Exception.Create('motion data duplication failed');
    BoneKey := Document.BoneTracks[0].Keys[0];
    BoneKey.Translation.X := 99;
    Document.BoneTracks[0].Keys[0] := BoneKey;
    EncodedMotion := EncodeMmdMotionDocument(Document);
    if not Motions.SaveMotionData(DuplicateIndex, EncodedMotion) or
      not Motions.LoadMotionData(0, EncodedMotion) or
      (EncodedMotion <> OriginalMotion) then
      raise Exception.Create('duplicated motion changed its source');
    Document.Free;
    Document := nil;
  finally
    Document.Free;
    Motions.Free;
  end;
  Reloaded := TPmxMotionCatalogStorage.Create(ModelRoot, 'pmx1', 'sample');
  try
    if not Reloaded.LoadFromFile or (Reloaded.Count <> 2) or
      (Reloaded[0].FirstFrame <> 3) then
      raise Exception.Create('motion catalog persistence failed');
    if not Reloaded.LoadMotionData(1, EncodedMotion) or
      not TryDecodeMmdMotionDocument(EncodedMotion, Document) then
      raise Exception.Create('duplicated motion reload failed');
    Document.Free;
    Document := nil;
  finally
    Document.Free;
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
