unit MmdAccessoryObjImporter;

// OBJと同一フォルダ内のMTL／テクスチャを検証・登録する。

interface

uses
  MmdAccessoryCatalog,
  MmdAccessoryPmxImporter;

// 入力中のOBJを再帰列挙し、MTL／テクスチャ依存を保管して登録結果を集計する。
function ImportMmdAccessoryObjFiles(const Inputs: TArray<string>;
  Catalog: TMmdAccessoryCatalog;
  out Summary: TMmdAccessoryPmxImportSummary): Boolean;

implementation

uses
  System.Classes,
  System.IOUtils,
  System.SysUtils,
  PmxModel,
  ObjReader,
  MmdAccessoryCatalogItem;

procedure CollectObjFiles(const Inputs: TArray<string>; Files: TStrings;
  var Failed: Integer);
var
  Candidate, Input: string;
begin
  for Input in Inputs do
    try
      if TFile.Exists(Input) then
      begin
        if SameText(TPath.GetExtension(Input), '.obj') and
          (Files.IndexOf(TPath.GetFullPath(Input)) < 0) then
          Files.Add(TPath.GetFullPath(Input));
      end
      else if TDirectory.Exists(Input) then
        for Candidate in TDirectory.GetFiles(Input, '*.obj',
          TSearchOption.soAllDirectories) do
          if Files.IndexOf(TPath.GetFullPath(Candidate)) < 0 then
            Files.Add(TPath.GetFullPath(Candidate));
    except
      Inc(Failed);
    end;
end;

procedure CopyDependencies(const ModelFile, ManagedFile: string;
  const Dependencies: TArray<string>; var Missing: Integer);
var
  Dependency, Destination, DestinationRoot, RelativeName, SourceRoot,
  Source: string;
begin
  SourceRoot := IncludeTrailingPathDelimiter(TPath.GetFullPath(
    TPath.GetDirectoryName(ModelFile)));
  DestinationRoot := IncludeTrailingPathDelimiter(TPath.GetFullPath(
    TPath.GetDirectoryName(ManagedFile)));
  for Dependency in Dependencies do
    try
      Source := TPath.GetFullPath(Dependency);
      if not TFile.Exists(Source) or not Source.StartsWith(SourceRoot, True) then
      begin
        Inc(Missing);
        Continue;
      end;
      RelativeName := Copy(Source, Length(SourceRoot) + 1, MaxInt);
      Destination := TPath.GetFullPath(TPath.Combine(DestinationRoot,
        RelativeName));
      if not Destination.StartsWith(DestinationRoot, True) then
      begin
        Inc(Missing);
        Continue;
      end;
      ForceDirectories(TPath.GetDirectoryName(Destination));
      TFile.Copy(Source, Destination, True);
    except
      Inc(Missing);
    end;
end;

function ImportMmdAccessoryObjFiles(const Inputs: TArray<string>;
  Catalog: TMmdAccessoryCatalog;
  out Summary: TMmdAccessoryPmxImportSummary): Boolean;
var
  Dependencies: TArray<string>;
  FileName: string;
  Files: TStringList;
  IsNewItem, IsNewSource: Boolean;
  Item: TMmdAccessoryCatalogItem;
  Model: TPmxModel;
begin
  Result := False;
  Summary := Default(TMmdAccessoryPmxImportSummary);
  if not Assigned(Catalog) then Exit;
  Files := TStringList.Create;
  try
    Files.CaseSensitive := False;
    CollectObjFiles(Inputs, Files, Summary.Failed);
    Summary.Scanned := Files.Count;
    for FileName in Files do
    begin
      Model := nil;
      try
        try
          Model := LoadObjModel(FileName, Dependencies);
          if not Catalog.ImportFile(FileName, Item, IsNewSource, IsNewItem) or
            not Catalog.UpdateSourceInspection(Item.SourceId,
              Length(Model.Vertices), Length(Model.Materials), 0) then
            raise EInOutError.Create('Cannot register OBJ');
          CopyDependencies(FileName, Catalog.SourceFileName(Item.SourceId),
            Dependencies, Summary.MissingDependencies);
          if IsNewItem then Inc(Summary.Added)
          else Inc(Summary.AlreadyRegistered);
          Inc(Summary.WithoutBones);
          Summary.LastAccessoryId := Item.Id;
        except
          Inc(Summary.Failed);
        end;
      finally
        Model.Free;
      end;
    end;
    Result := (Summary.Added > 0) or (Summary.AlreadyRegistered > 0);
  finally
    Files.Free;
  end;
end;

end.
