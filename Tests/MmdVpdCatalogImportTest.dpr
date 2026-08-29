program MmdVpdCatalogImportTest;

{$APPTYPE CONSOLE}

uses
  System.Classes,
  System.IOUtils,
  System.SysUtils,
  PmxPose in '..\..\AviUtl2PluginLib\MMD\Core\PmxPose.pas',
  PmxPoseCodec in '..\..\AviUtl2PluginLib\MMD\IO\PmxPoseCodec.pas',
  VpdPoseCodec in '..\..\AviUtl2PluginLib\MMD\VPD\IO\VpdPoseCodec.pas',
  MmdMorphSettingCodec in
    '..\..\AviUtl2PluginLib\MMD\Common\IO\MmdMorphSettingCodec.pas',
  MmdEyeBlinkSettingCodec in
    '..\..\AviUtl2PluginLib\MMD\Common\IO\MmdEyeBlinkSettingCodec.pas',
  MmdLipSyncSettingCodec in
    '..\..\AviUtl2PluginLib\MMD\Common\IO\MmdLipSyncSettingCodec.pas',
  PmxPoseCatalogStorage in
    '..\Source\Plugin\Extension\PMX\Catalog\Pose\PmxPoseCatalogStorage.pas',
  PmxPoseCatalogDataValidation in
    '..\Source\Plugin\Extension\PMX\Catalog\Pose\Storage\PmxPoseCatalogDataValidation.pas',
  PmxPoseCatalogItem in
    '..\Source\Plugin\Extension\PMX\Catalog\Pose\Storage\PmxPoseCatalogItem.pas',
  PmxPoseCatalogIndexCodec in
    '..\Source\Plugin\Extension\PMX\Catalog\Pose\Storage\PmxPoseCatalogIndexCodec.pas',
  PmxPoseCatalogItemCodec in
    '..\Source\Plugin\Extension\PMX\Catalog\Pose\Storage\PmxPoseCatalogItemCodec.pas',
  PmxPoseCatalogGroups in
    '..\Source\Plugin\Extension\PMX\Catalog\Pose\Group\PmxPoseCatalogGroups.pas',
  MmdVpdCatalogItem in
    '..\Source\Plugin\Extension\VPD\Catalog\MmdVpdCatalogItem.pas',
  MmdVpdCatalogCodec in
    '..\Source\Plugin\Extension\VPD\Catalog\MmdVpdCatalogCodec.pas',
  MmdVpdCatalog in
    '..\Source\Plugin\Extension\VPD\Catalog\MmdVpdCatalog.pas',
  MmdVpdPoseImporter in
    '..\Source\Plugin\Extension\VPD\Import\MmdVpdPoseImporter.pas';

procedure Check(Value: Boolean; const MessageText: string);
begin
  if not Value then raise Exception.Create(MessageText);
end;

procedure WriteVpd(const FileName, BoneName: string; X: Single);
var
  Encoding: TEncoding;
  Poses: TPmxNamedBonePoses;
begin
  SetLength(Poses, 1);
  Poses[0].BoneName := BoneName;
  Poses[0].Pose.Translation.X := X;
  Poses[0].Pose.Rotation.W := 1;
  TDirectory.CreateDirectory(TPath.GetDirectoryName(FileName));
  Encoding := TEncoding.GetEncoding(932);
  try
    TFile.WriteAllText(FileName, EncodeVpdPose('test', Poses), Encoding);
  finally
    Encoding.Free;
  end;
end;

procedure Run;
var
  Catalog: TMmdVpdCatalog;
  DailyFolder, InputRoot, ModelRoot, Root, VpdRoot: string;
  Files: TArray<string>;
  Groups, LoadedGroups: TPmxPoseCatalogGroups;
  I: Integer;
  NamedPoses: TPmxNamedBonePoses;
  PoseData: string;
  PoseCatalog: TPmxPoseCatalogStorage;
  Summary: TMmdVpdImportSummary;
begin
  Root := TPath.Combine(TPath.GetTempPath,
    'MmdVpdCatalogImport-' + TPath.GetRandomFileName);
  InputRoot := TPath.Combine(Root, 'Input');
  DailyFolder := TPath.Combine(InputRoot, 'Daily');
  VpdRoot := TPath.Combine(Root, 'VPD');
  ModelRoot := TPath.Combine(Root, 'Model');
  try
    WriteVpd(TPath.Combine(DailyFolder, 'Sit.vpd'), 'center', 1);
    WriteVpd(TPath.Combine(DailyFolder, 'Sit-Copy.vpd'), 'center', 1);
    WriteVpd(TPath.Combine(TPath.Combine(InputRoot, 'Combat'),
      'Ready.vpd'), 'arm', 2);
    SetLength(Files, 1);
    Files[0] := InputRoot;
    PoseCatalog := TPmxPoseCatalogStorage.Create(ModelRoot, 'pmx-1', 'model');
    Groups := TPmxPoseCatalogGroups.Create(ModelRoot);
    try
      Check(PoseCatalog.LoadOrCreateDefault, 'default pose was not created');
      Check(Groups.LoadFromFile, 'groups did not initialize');
      Check(ImportMmdVpdPoses(Files, VpdRoot, PoseCatalog, Groups, Summary),
        'VPD folder import failed');
      Check((Summary.Scanned = 3) and (Summary.LibraryAdded = 2) and
        (Summary.PoseAdded = 2) and (Summary.Failed = 0),
        'VPD import counts are invalid');
      Check((PoseCatalog.Count = 3) and (Groups.Count = 2),
        'VPD poses or category groups were not created');
      for I := 1 to PoseCatalog.Count - 1 do
        Check((PoseCatalog[I].SourceVpdId <> '') and
          (PoseCatalog[I].SourceCategoryName <> ''),
          'VPD source metadata was not saved to PoseUID');
      Check(PoseCatalog.LoadOrCreateDefault and (PoseCatalog.Count = 3),
        'VPD poses were not restored');
      for I := 1 to PoseCatalog.Count - 1 do
        Check((PoseCatalog[I].SourceVpdId <> '') and
          (PoseCatalog[I].SourceCategoryName <> ''),
          'VPD source metadata was not restored');
      Check(ImportMmdVpdPoses(Files, VpdRoot, PoseCatalog, Groups, Summary),
        'duplicate VPD import failed');
      Check((Summary.PoseAdded = 0) and (PoseCatalog.Count = 3),
        'duplicate VPD created another PMX pose');
      for I := 1 to 12 do Groups.Add('Extra-' + IntToStr(I));
      Check((Groups.Count = 14) and Groups.SaveToFile,
        'group limit was not removed');
      LoadedGroups := TPmxPoseCatalogGroups.Create(ModelRoot);
      try
        Check(LoadedGroups.LoadFromFile and (LoadedGroups.Count = 14),
          'groups above shortcut range were not restored');
      finally
        LoadedGroups.Free;
      end;
    finally
      Groups.Free;
      PoseCatalog.Free;
    end;
    Catalog := TMmdVpdCatalog.Create(VpdRoot);
    try
      Check(Catalog.LoadFromFile and (Catalog.Count = 2),
        'VPD catalog did not deduplicate content');
      Check(TFile.Exists(Catalog.SourceFileName(Catalog[0].Id)) and
        TFile.Exists(Catalog.SourceFileName(Catalog[1].Id)),
        'managed VPD files were not copied');
      Check(Catalog.LoadPoseData(Catalog[0].Id, PoseData) and
        TryDecodePoseData(PoseData, NamedPoses) and
        (Length(NamedPoses) = 1),
        'managed VPD could not be loaded for reuse preview');
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
    Writeln('MmdVpdCatalogImportTest: PASS');
  except
    on E: Exception do
    begin
      Writeln(E.ClassName + ': ' + E.Message);
      ExitCode := 1;
    end;
  end;
end.
