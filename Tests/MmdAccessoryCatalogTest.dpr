program MmdAccessoryCatalogTest;

{$APPTYPE CONSOLE}

uses
  Winapi.Windows,
  System.IOUtils,
  System.SysUtils,
  MmdAccessoryCatalogItem in
    '..\Source\Plugin\Extension\Accessory\Catalog\Storage\MmdAccessoryCatalogItem.pas',
  MmdAccessoryCatalogCodec in
    '..\Source\Plugin\Extension\Accessory\Catalog\Storage\MmdAccessoryCatalogCodec.pas',
  MmdAccessoryCatalogOperations in
    '..\Source\Plugin\Extension\Accessory\Catalog\Storage\MmdAccessoryCatalogOperations.pas',
  MmdAccessoryCatalogImport in
    '..\Source\Plugin\Extension\Accessory\Catalog\Storage\Import\MmdAccessoryCatalogImport.pas',
  MmdAccessoryCatalog in
    '..\Source\Plugin\Extension\Accessory\Catalog\Storage\MmdAccessoryCatalog.pas';

procedure WriteSample(const FileName, Value: string);
begin
  TFile.WriteAllText(FileName, Value, TEncoding.UTF8);
end;

procedure Run;
var
  Catalog, Reloaded: TMmdAccessoryCatalog;
  DuplicateFile, DuplicateId, DuplicateMetadata, ObjFile, PmxFile, Root,
  SourceId, UnsupportedFile: string;
  DuplicateIndex: Integer;
  IsNewItem, IsNewSource: Boolean;
  Item: TMmdAccessoryCatalogItem;
begin
  Root := TPath.Combine(TPath.GetTempPath,
    'MmdAccessoryCatalogTest-' + IntToHex(GetCurrentProcessId, 8));
  if TDirectory.Exists(Root) then TDirectory.Delete(Root, True);
  ForceDirectories(Root);
  try
    PmxFile := TPath.Combine(Root, 'sample.pmx');
    DuplicateFile := TPath.Combine(Root, 'same-content.pmx');
    ObjFile := TPath.Combine(Root, 'sample.obj');
    UnsupportedFile := TPath.Combine(Root, 'sample.fbx');
    WriteSample(PmxFile, 'same geometry');
    WriteSample(DuplicateFile, 'same geometry');
    WriteSample(ObjFile, 'same geometry');
    WriteSample(UnsupportedFile, 'unsupported');

    Catalog := TMmdAccessoryCatalog.Create(TPath.Combine(Root, 'Accessories'));
    try
      if not Catalog.LoadFromFile or (Catalog.Count <> 0) or
        (Catalog.SourceCount <> 0) then
        raise Exception.Create('empty catalog load failed');
      if not Catalog.ImportFile(PmxFile, Item, IsNewSource, IsNewItem) or
        not IsNewSource or not IsNewItem or (Catalog.Count <> 1) or
        (Catalog.SourceCount <> 1) or (Item.Name <> 'sample') or
        (Item.SourceId = '') or (Item.Id = '') or (Item.Id = Item.SourceId) then
        raise Exception.Create('PMX source and item import failed');
      SourceId := Item.SourceId;
      if (Catalog.Sources[0].Format <> asfPmx) or
        not SameText(Catalog.Sources[0].OriginalFileName, 'sample.pmx') or
        not TFile.Exists(Catalog.SourceFileName(SourceId)) or
        not SameText(TPath.GetFileName(Catalog.SourceFileName(SourceId)),
          'sample.pmx') or
        not TFile.Exists(TPath.Combine(TPath.Combine(Root,
          'Accessories\SourceItems'), SourceId + '.json')) or
        not TFile.Exists(TPath.Combine(TPath.Combine(Root,
          'Accessories\Items'), Item.Id + '.json')) then
        raise Exception.Create('PMX managed files are missing');
      if not Catalog.ImportFile(DuplicateFile, Item, IsNewSource,
        IsNewItem) or IsNewSource or IsNewItem or
        (Item.SourceId <> SourceId) or (Catalog.Count <> 1) or
        (Catalog.SourceCount <> 1) then
        raise Exception.Create('same-format duplicate was added');
      if not Catalog.ImportFile(ObjFile, Item, IsNewSource, IsNewItem) or
        not IsNewSource or not IsNewItem or (Catalog.Count <> 2) or
        (Catalog.SourceCount <> 2) or (Catalog.Sources[1].Format <> asfObj) or
        not SameText(TPath.GetExtension(Catalog.SourceFileName(Item.SourceId)),
          '.obj') then
        raise Exception.Create('OBJ format identity was not separated');
      if Catalog.ImportFile(UnsupportedFile, Item, IsNewSource, IsNewItem) then
        raise Exception.Create('unsupported source was accepted');
      if not Catalog.Rename(0, 'renamed accessory') or
        Catalog.Rename(0, '  ') or (Catalog[0].Name <> 'renamed accessory') then
        raise Exception.Create('accessory rename failed');
      DuplicateIndex := Catalog.Duplicate(0);
      if (DuplicateIndex <> 2) or (Catalog.Count <> 3) or
        (Catalog[DuplicateIndex].Id = Catalog[0].Id) or
        (Catalog[DuplicateIndex].SourceId <> Catalog[0].SourceId) or
        (Catalog[DuplicateIndex].Name <> 'renamed accessory (' +
          #$30B3#$30D4#$30FC + ')') then
        raise Exception.Create('accessory duplicate failed');
      DuplicateId := Catalog[DuplicateIndex].Id;
      DuplicateMetadata := TPath.Combine(TPath.Combine(Root,
        'Accessories\Items'), DuplicateId + '.json');
      if not TFile.Exists(DuplicateMetadata) or
        (Catalog.Move(DuplicateIndex, -1) <> 1) or
        (Catalog[1].Id <> DuplicateId) then
        raise Exception.Create('accessory move failed');
      if not Catalog.Remove(1) or (Catalog.Count <> 2) or
        TFile.Exists(DuplicateMetadata) or
        not TFile.Exists(Catalog.SourceFileName(SourceId)) then
        raise Exception.Create('accessory remove failed');
    finally
      Catalog.Free;
    end;

    Reloaded := TMmdAccessoryCatalog.Create(
      TPath.Combine(Root, 'Accessories'));
    try
      if not Reloaded.LoadFromFile or (Reloaded.Count <> 2) or
        (Reloaded.SourceCount <> 2) or
        not SameText(Reloaded[0].Name, 'renamed accessory') or
        (Reloaded[0].SourceId <> SourceId) or
        (Reloaded.Sources[0].ContentHash = '') then
        raise Exception.Create('catalog persistence failed');
    finally
      Reloaded.Free;
    end;
  finally
    if TDirectory.Exists(Root) then TDirectory.Delete(Root, True);
  end;
end;

begin
  try
    Run;
    Writeln('MmdAccessoryCatalogTest: PASS');
  except
    on E: Exception do
    begin
      Writeln('MmdAccessoryCatalogTest: FAIL: ' + E.Message);
      ExitCode := 1;
    end;
  end;
end.
