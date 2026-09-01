program MmdAccessoryPmxImportTest;

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
  PmxPose in '..\..\AviUtl2PluginLib\MMD\Core\PmxPose.pas',
  PmxMorph in '..\..\AviUtl2PluginLib\MMD\Core\PmxMorph.pas',
  PmxBinaryStream in '..\..\AviUtl2PluginLib\MMD\IO\PmxBinaryStream.pas',
  PmxGeometryReader in '..\..\AviUtl2PluginLib\MMD\IO\PmxGeometryReader.pas',
  PmxMaterialReader in '..\..\AviUtl2PluginLib\MMD\IO\PmxMaterialReader.pas',
  PmxBoneReader in '..\..\AviUtl2PluginLib\MMD\IO\PmxBoneReader.pas',
  PmxMorphReader in '..\..\AviUtl2PluginLib\MMD\IO\PmxMorphReader.pas',
  PmxReader in '..\..\AviUtl2PluginLib\MMD\IO\PmxReader.pas',
  MtlReader in '..\..\AviUtl2PluginLib\MMD\OBJ\IO\MtlReader.pas',
  ObjReader in '..\..\AviUtl2PluginLib\MMD\OBJ\IO\ObjReader.pas',
  MmdD3DDeform in '..\..\AviUtl2PluginLib\MMD\Editor\D3D\MmdD3DDeform.pas',
  MmdD3DScene in '..\..\AviUtl2PluginLib\MMD\Editor\D3D\MmdD3DScene.pas',
  MmdAccessoryCatalogItem in
    '..\Source\Plugin\Extension\Accessory\Catalog\Storage\MmdAccessoryCatalogItem.pas',
  MmdAccessoryCatalogCodec in
    '..\Source\Plugin\Extension\Accessory\Catalog\Storage\MmdAccessoryCatalogCodec.pas',
  MmdAccessoryCatalogOperations in
    '..\Source\Plugin\Extension\Accessory\Catalog\Storage\MmdAccessoryCatalogOperations.pas',
  MmdAccessoryCatalogImport in
    '..\Source\Plugin\Extension\Accessory\Catalog\Storage\Import\MmdAccessoryCatalogImport.pas',
  MmdAccessoryCatalog in
    '..\Source\Plugin\Extension\Accessory\Catalog\Storage\MmdAccessoryCatalog.pas',
  MmdAccessoryPmxInspector in
    '..\Source\Plugin\Extension\Accessory\PMX\Import\MmdAccessoryPmxInspector.pas',
  MmdAccessoryPmxImporter in
    '..\Source\Plugin\Extension\Accessory\PMX\Import\MmdAccessoryPmxImporter.pas',
  MmdAccessoryObjImporter in
    '..\Source\Plugin\Extension\Accessory\OBJ\Import\MmdAccessoryObjImporter.pas',
  MmdAccessoryImporter in
    '..\Source\Plugin\Extension\Accessory\Import\MmdAccessoryImporter.pas';

procedure WriteByte(Stream: TStream; Value: Byte);
begin
  Stream.WriteBuffer(Value, SizeOf(Value));
end;

procedure WriteInt32(Stream: TStream; Value: Integer);
begin
  Stream.WriteBuffer(Value, SizeOf(Value));
end;

procedure WriteSingle(Stream: TStream; Value: Single);
begin
  Stream.WriteBuffer(Value, SizeOf(Value));
end;

procedure WriteText(Stream: TStream; const Value: string);
var
  Bytes: TBytes;
begin
  Bytes := TEncoding.UTF8.GetBytes(Value);
  WriteInt32(Stream, Length(Bytes));
  if Length(Bytes) > 0 then Stream.WriteBuffer(Bytes[0], Length(Bytes));
end;

procedure WriteVector2(Stream: TStream; X, Y: Single);
begin
  WriteSingle(Stream, X);
  WriteSingle(Stream, Y);
end;

procedure WriteVector3(Stream: TStream; X, Y, Z: Single);
begin
  WriteSingle(Stream, X);
  WriteSingle(Stream, Y);
  WriteSingle(Stream, Z);
end;

procedure WriteVector4(Stream: TStream; X, Y, Z, W: Single);
begin
  WriteVector3(Stream, X, Y, Z);
  WriteSingle(Stream, W);
end;

procedure CreateMinimalPmx(const FileName: string; HasBone,
  HasTexture: Boolean);
const
  Signature: AnsiString = 'PMX ';
var
  BoneIndex, I: Integer;
  Flags: Word;
  Stream: TFileStream;
begin
  Stream := TFileStream.Create(FileName, fmCreate);
  try
    Stream.WriteBuffer(Signature[1], 4);
    WriteSingle(Stream, 2.0);
    WriteByte(Stream, 8);
    WriteByte(Stream, 1);
    WriteByte(Stream, 0);
    for I := 1 to 6 do WriteByte(Stream, 1);
    WriteText(Stream, 'accessory');
    WriteText(Stream, 'accessory');
    WriteText(Stream, '');
    WriteText(Stream, '');
    WriteInt32(Stream, 3);
    BoneIndex := -1;
    if HasBone then BoneIndex := 0;
    for I := 0 to 2 do
    begin
      case I of
        0: WriteVector3(Stream, -1, 0, 0);
        1: WriteVector3(Stream, 1, 0, 0);
      else
        WriteVector3(Stream, 0, 1, 0);
      end;
      WriteVector3(Stream, 0, 0, 1);
      WriteVector2(Stream, 0, 0);
      WriteByte(Stream, 0);
      WriteByte(Stream, Byte(ShortInt(BoneIndex)));
      WriteSingle(Stream, 1);
    end;
    WriteInt32(Stream, 3);
    WriteByte(Stream, 0);
    WriteByte(Stream, 1);
    WriteByte(Stream, 2);
    if HasTexture then
    begin
      WriteInt32(Stream, 1);
      WriteText(Stream, 'textures\sample.png');
    end
    else WriteInt32(Stream, 0);
    WriteInt32(Stream, 1);
    WriteText(Stream, 'material');
    WriteText(Stream, 'material');
    WriteVector4(Stream, 1, 1, 1, 1);
    WriteVector3(Stream, 0, 0, 0);
    WriteSingle(Stream, 0);
    WriteVector3(Stream, 0, 0, 0);
    WriteByte(Stream, 0);
    WriteVector4(Stream, 0, 0, 0, 1);
    WriteSingle(Stream, 0);
    if HasTexture then WriteByte(Stream, 0)
    else WriteByte(Stream, $FF);
    WriteByte(Stream, $FF);
    WriteByte(Stream, 0);
    WriteByte(Stream, 1);
    WriteByte(Stream, 0);
    WriteText(Stream, '');
    WriteInt32(Stream, 3);
    if HasBone then
    begin
      WriteInt32(Stream, 1);
      WriteText(Stream, 'root');
      WriteText(Stream, 'root');
      WriteVector3(Stream, 0, 0, 0);
      WriteByte(Stream, $FF);
      WriteInt32(Stream, 0);
      Flags := 0;
      Stream.WriteBuffer(Flags, SizeOf(Flags));
      WriteVector3(Stream, 0, 1, 0);
    end
    else WriteInt32(Stream, 0);
    WriteInt32(Stream, 0);
  finally
    Stream.Free;
  end;
end;

procedure Run;
var
  BonePmx, InputRoot, InvalidPmx, ManagedObj, ManagedTexture, MtlFile,
  NoBonePmx, ObjFile, Root, TextureFile: string;
  Catalog: TMmdAccessoryCatalog;
  Model: TPmxModel;
  MorphWeights: TPmxMorphWeights;
  Poses: TPmxBonePoses;
  Scene: TMmdPreviewScene;
  Summary: TMmdAccessoryPmxImportSummary;
  SummaryDependencies: TArray<string>;
begin
  Root := TPath.Combine(TPath.GetTempPath,
    'MmdAccessoryPmxImportTest-' + IntToHex(GetCurrentProcessId, 8));
  if TDirectory.Exists(Root) then TDirectory.Delete(Root, True);
  ForceDirectories(Root);
  try
    InputRoot := TPath.Combine(Root, 'Input');
    ForceDirectories(InputRoot);
    NoBonePmx := TPath.Combine(InputRoot, 'no-bone.pmx');
    BonePmx := TPath.Combine(InputRoot, 'with-bone.pmx');
    InvalidPmx := TPath.Combine(InputRoot, 'invalid.pmx');
    TextureFile := TPath.Combine(InputRoot, 'textures\sample.png');
    ForceDirectories(TPath.GetDirectoryName(TextureFile));
    TFile.WriteAllText(TextureFile, 'texture-test', TEncoding.ASCII);
    CreateMinimalPmx(NoBonePmx, False, True);
    CreateMinimalPmx(BonePmx, True, False);
    TFile.WriteAllText(InvalidPmx, 'invalid', TEncoding.UTF8);
    Model := LoadPmxModel(NoBonePmx);
    try
      InitializeBonePoses(Model, Poses);
      InitializeMorphWeights(Model, MorphWeights);
      BuildPreviewScene(Model, Poses, MorphWeights, EmptyPreviewTarget,
        EmptyPreviewTarget, Scene);
      if (Length(Scene.Triangles) = 0) or
        (Scene.Projection.ModelWidth <= 0) or
        (Scene.Projection.ModelHeight <= 0) then
        raise Exception.Create('bone-less PMX preview scene failed');
    finally
      Model.Free;
    end;
    Catalog := TMmdAccessoryCatalog.Create(TPath.Combine(Root, 'Accessories'));
    try
      if not Catalog.LoadFromFile or
        not ImportMmdAccessoryPmxFiles([NoBonePmx, InvalidPmx], Catalog,
          Summary) or (Summary.Scanned <> 2) or (Summary.Added <> 1) or
        (Summary.Failed <> 1) or (Summary.WithoutBones <> 1) or
        (Summary.MissingDependencies <> 0) or
        (Catalog.Count <> 1) or not Catalog.Sources[0].Validated or
        (Catalog.Sources[0].VertexCount <> 3) or
        (Catalog.Sources[0].MaterialCount <> 1) or
        (Catalog.Sources[0].BoneCount <> 0) then
        raise Exception.Create('bone-less PMX import failed');
      ManagedTexture := TPath.Combine(TPath.GetDirectoryName(
        Catalog.SourceFileName(Catalog.Sources[0].Id)),
        'textures\sample.png');
      if not TFile.Exists(ManagedTexture) or
        (TFile.ReadAllText(ManagedTexture, TEncoding.ASCII) <> 'texture-test') then
        raise Exception.Create('PMX texture dependency copy failed');
      if not ImportMmdAccessoryPmxFiles([InputRoot], Catalog, Summary) or
        (Summary.Scanned <> 3) or (Summary.Added <> 1) or
        (Summary.AlreadyRegistered <> 1) or (Summary.Failed <> 1) or
        (Summary.WithBones <> 1) or (Summary.WithoutBones <> 1) or
        (Catalog.Count <> 2) then
        raise Exception.CreateFmt(
          'folder summary mismatch: scanned=%d added=%d existing=%d failed=%d bones=%d noBones=%d count=%d',
          [Summary.Scanned, Summary.Added, Summary.AlreadyRegistered,
          Summary.Failed, Summary.WithBones, Summary.WithoutBones,
          Catalog.Count]);
      ObjFile := TPath.Combine(InputRoot, 'sample.obj');
      MtlFile := TPath.Combine(InputRoot, 'sample.mtl');
      TFile.WriteAllText(MtlFile, 'newmtl material' + sLineBreak +
        'Kd 0.2 0.4 0.6' + sLineBreak +
        'map_Kd textures/sample.png' + sLineBreak, TEncoding.UTF8);
      TFile.WriteAllText(ObjFile, 'mtllib sample.mtl' + sLineBreak +
        'v -1 0 0' + sLineBreak + 'v 1 0 0' + sLineBreak +
        'v 1 1 0' + sLineBreak + 'v -1 1 0' + sLineBreak +
        'vt 0 0' + sLineBreak + 'vt 1 0' + sLineBreak +
        'vt 1 1' + sLineBreak + 'vt 0 1' + sLineBreak +
        'usemtl material' + sLineBreak +
        'f 1/1 2/2 3/3 4/4' + sLineBreak, TEncoding.UTF8);
      if not ImportMmdAccessoryFiles([ObjFile], Catalog, Summary) or
        (Summary.Scanned <> 1) or (Summary.Added <> 1) or
        (Summary.Failed <> 0) or (Summary.WithoutBones <> 1) or
        (Summary.MissingDependencies <> 0) or (Catalog.Count <> 3) then
        raise Exception.Create('OBJ import failed');
      ManagedObj := Catalog.SourceFileName(Catalog[2].SourceId);
      if not TFile.Exists(TPath.Combine(TPath.GetDirectoryName(ManagedObj),
        'sample.mtl')) or
        not TFile.Exists(TPath.Combine(TPath.GetDirectoryName(ManagedObj),
        'textures\sample.png')) then
        raise Exception.Create('OBJ dependencies were not copied');
      Model := LoadObjModel(ManagedObj, SummaryDependencies);
      try
        InitializeBonePoses(Model, Poses);
        InitializeMorphWeights(Model, MorphWeights);
        BuildPreviewScene(Model, Poses, MorphWeights, EmptyPreviewTarget,
          EmptyPreviewTarget, Scene);
        if (Length(Model.Vertices) <> 6) or
          (Length(Scene.Triangles) <> 6) or
          (Length(Model.Materials) <> 1) or
          (Length(Model.Textures) <> 1) then
          raise Exception.Create('OBJ preview scene failed');
      finally
        Model.Free;
      end;
    finally
      Catalog.Free;
    end;
  finally
    if TDirectory.Exists(Root) then TDirectory.Delete(Root, True);
  end;
end;

begin
  try
    Run;
    Writeln('MmdAccessoryPmxImportTest: PASS');
  except
    on E: Exception do
    begin
      Writeln('MmdAccessoryPmxImportTest: FAIL: ' + E.Message);
      ExitCode := 1;
    end;
  end;
end.
