unit MmdAccessoryPmxImporter;

// PMXファイル／フォルダを列挙し、内容検証後にアクセサリカタログへ登録する。

interface

uses
  MmdAccessoryCatalog;

type
  TMmdAccessoryPmxImportSummary = record
    // 複数形式のImporterで加算可能な登録件数と、最後に選択するUIDを保持する。
    Added: Integer;
    AlreadyRegistered: Integer;
    Failed: Integer;
    LastAccessoryId: string;
    MissingDependencies: Integer;
    Scanned: Integer;
    WithBones: Integer;
    WithoutBones: Integer;
  end;

// 入力中のPMXを再帰列挙し、有効な形状だけを登録して集計結果を返す。
function ImportMmdAccessoryPmxFiles(const Inputs: TArray<string>;
  Catalog: TMmdAccessoryCatalog;
  out Summary: TMmdAccessoryPmxImportSummary): Boolean;

implementation

uses
  System.Classes,
  System.IOUtils,
  System.SysUtils,
  MmdAccessoryCatalogItem,
  MmdAccessoryPmxInspector;

procedure CopyPmxDependencies(const ModelFile, ManagedFile: string;
  const TextureFiles: TArray<string>; var Missing: Integer);
var
  Destination, DestinationRoot, RelativeName, SourceRoot, TextureFile: string;
begin
  SourceRoot := IncludeTrailingPathDelimiter(
    TPath.GetFullPath(TPath.GetDirectoryName(ModelFile)));
  DestinationRoot := IncludeTrailingPathDelimiter(
    TPath.GetFullPath(TPath.GetDirectoryName(ManagedFile)));
  for TextureFile in TextureFiles do
    try
      if not TFile.Exists(TextureFile) or
        not TPath.GetFullPath(TextureFile).StartsWith(SourceRoot, True) then
      begin
        Inc(Missing);
        Continue;
      end;
      RelativeName := Copy(TPath.GetFullPath(TextureFile),
        Length(SourceRoot) + 1, MaxInt);
      Destination := TPath.GetFullPath(
        TPath.Combine(DestinationRoot, RelativeName));
      if not Destination.StartsWith(DestinationRoot, True) then
      begin
        Inc(Missing);
        Continue;
      end;
      ForceDirectories(TPath.GetDirectoryName(Destination));
      TFile.Copy(TextureFile, Destination, True);
    except
      Inc(Missing);
    end;
end;

procedure CollectPmxFiles(const Inputs: TArray<string>; Files: TStrings;
  var Failed: Integer);
var
  Candidate, Input: string;
  Found: TArray<string>;
begin
  for Input in Inputs do
    try
      if TFile.Exists(Input) then
      begin
        if SameText(TPath.GetExtension(Input), '.pmx') and
          (Files.IndexOf(TPath.GetFullPath(Input)) < 0) then
          Files.Add(TPath.GetFullPath(Input));
      end
      else if TDirectory.Exists(Input) then
      begin
        Found := TDirectory.GetFiles(Input, '*.pmx',
          TSearchOption.soAllDirectories);
        for Candidate in Found do
          if Files.IndexOf(TPath.GetFullPath(Candidate)) < 0 then
            Files.Add(TPath.GetFullPath(Candidate));
      end;
    except
      Inc(Failed);
    end;
end;

function ImportMmdAccessoryPmxFiles(const Inputs: TArray<string>;
  Catalog: TMmdAccessoryCatalog;
  out Summary: TMmdAccessoryPmxImportSummary): Boolean;
var
  FileName: string;
  Files: TStringList;
  Inspection: TMmdAccessoryPmxInspection;
  IsNewItem, IsNewSource: Boolean;
  Item: TMmdAccessoryCatalogItem;
begin
  Result := False;
  Summary := Default(TMmdAccessoryPmxImportSummary);
  if not Assigned(Catalog) then Exit;
  Files := TStringList.Create;
  try
    Files.CaseSensitive := False;
    CollectPmxFiles(Inputs, Files, Summary.Failed);
    Summary.Scanned := Files.Count;
    for FileName in Files do
    begin
      if not InspectMmdAccessoryPmx(FileName, Inspection) or
        not Catalog.ImportFile(FileName, Item, IsNewSource, IsNewItem) or
        not Catalog.UpdateSourceInspection(Item.SourceId,
          Inspection.VertexCount, Inspection.MaterialCount,
          Inspection.BoneCount) then
      begin
        Inc(Summary.Failed);
        Continue;
      end;
      if IsNewItem then Inc(Summary.Added)
      else Inc(Summary.AlreadyRegistered);
      CopyPmxDependencies(FileName, Catalog.SourceFileName(Item.SourceId),
        Inspection.TextureFiles, Summary.MissingDependencies);
      if Inspection.BoneCount = 0 then Inc(Summary.WithoutBones)
      else Inc(Summary.WithBones);
      Summary.LastAccessoryId := Item.Id;
    end;
    Result := (Summary.Added > 0) or (Summary.AlreadyRegistered > 0);
  finally
    Files.Free;
  end;
end;

end.
