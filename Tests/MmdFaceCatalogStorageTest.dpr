program MmdFaceCatalogStorageTest;

{$APPTYPE CONSOLE}

uses
  System.IOUtils,
  System.SysUtils,
  MmdMorphSettingCodec in
    '..\..\AviUtl2PluginLib\MMD\Common\IO\MmdMorphSettingCodec.pas',
  PmxFaceCatalogItem in
    '..\Source\Plugin\Extension\PMX\Catalog\Face\Storage\PmxFaceCatalogItem.pas',
  PmxFaceCatalogCodec in
    '..\Source\Plugin\Extension\PMX\Catalog\Face\Storage\PmxFaceCatalogCodec.pas',
  PmxFaceCatalogStorage in
    '..\Source\Plugin\Extension\PMX\Catalog\Face\PmxFaceCatalogStorage.pas',
  PmxFaceCatalogGroups in
    '..\Source\Plugin\Extension\PMX\Catalog\Face\Group\PmxFaceCatalogGroups.pas';

procedure Check(Value: Boolean; const MessageText: string);
begin
  if not Value then raise Exception.Create(MessageText);
end;

procedure Run;
var
  FaceId, Root: string;
  Groups, ReloadedGroups: TPmxFaceCatalogGroups;
  Storage, Reloaded: TPmxFaceCatalogStorage;
begin
  Root := TPath.Combine(TPath.GetTempPath,
    'MmdFaceCatalog-' + TPath.GetRandomFileName);
  try
    Storage := TPmxFaceCatalogStorage.Create(Root, 'pmx-1', 'model');
    Groups := TPmxFaceCatalogGroups.Create(Root);
    try
      Check(Storage.LoadOrCreateDefault, 'face catalog did not initialize');
      Check((Storage.Count = 1) and Storage.IsInitial(0),
        'initial face was not created');
      Check((Storage[0].Name = #$521D#$671F#$72B6#$614B) and
        (Storage[0].FaceData = EmptyMmdMorphSettingData),
        'initial face data is invalid');
      Check(Storage.Add = 1, 'face was not added');
      Storage[1].FaceData :=
        '{"version":1,"morphs":[{"name":"smile","weight":0.5}]}';
      Check(Storage.SaveToFile, 'face data was not saved');
      Check(Storage.Duplicate(1) = 2, 'face was not duplicated');
      FaceId := Storage[2].Id;
      Check(Assigned(Groups.Add('basic')), 'face group was not added');
      Groups.AssignFaceToGroup(FaceId, 0);
      Check(Groups.SaveToFile, 'face group was not saved');
      Check(not Storage.Remove(0), 'initial face was removed');
    finally
      Groups.Free;
      Storage.Free;
    end;

    Reloaded := TPmxFaceCatalogStorage.Create(Root, 'pmx-1', 'model');
    ReloadedGroups := TPmxFaceCatalogGroups.Create(Root);
    try
      Check(Reloaded.LoadOrCreateDefault and (Reloaded.Count = 3),
        'face catalog was not restored');
      Check(Reloaded.IsInitial(0) and
        (Reloaded[1].FaceData <>
          EmptyMmdMorphSettingData), 'face values were not restored');
      Check(ReloadedGroups.LoadFromFile and
        (ReloadedGroups.Count = 1) and
        (ReloadedGroups[0].IndexOfFaceId(FaceId) = 0),
        'face group was not restored');
    finally
      ReloadedGroups.Free;
      Reloaded.Free;
    end;
  finally
    if TDirectory.Exists(Root) then TDirectory.Delete(Root, True);
  end;
end;

begin
  try
    Run;
    Writeln('MmdFaceCatalogStorageTest: PASS');
  except
    on E: Exception do
    begin
      Writeln('MmdFaceCatalogStorageTest: FAIL: ' + E.Message);
      Halt(1);
    end;
  end;
end.
