unit MmdVmdMotionImporter;

// VMDファイル／フォルダを共通保管し、選択PMX用モーション一覧へ登録する。

interface

uses
  PmxMotionCatalogStorage;

type
  TMmdVmdImportSummary = record
    AlreadyRegistered: Integer;
    Failed: Integer;
    LastMotionId: string;
    LibraryAdded: Integer;
    MotionAdded: Integer;
    Scanned: Integer;
  end;

function ImportMmdVmdMotions(const Inputs: TArray<string>;
  const VmdRoot: string; MotionCatalog: TPmxMotionCatalogStorage;
  out Summary: TMmdVmdImportSummary): Boolean;

implementation

uses
  System.Classes,
  System.IOUtils,
  System.JSON,
  System.SysUtils,
  AppFolderUtils,
  PmxPose,
  PmxPoseCodec,
  MmdMorphSettingCodec,
  MmdVmdCatalog,
  MmdVmdCatalogItem;

procedure CollectVmdFiles(const Inputs: TArray<string>; Files: TStrings;
  var Failed: Integer);
var
  Candidate, Input: string;
  Found: TArray<string>;
begin
  for Input in Inputs do
    try
      if TFile.Exists(Input) then
      begin
        if SameText(TPath.GetExtension(Input), '.vmd') and
          (Files.IndexOf(TPath.GetFullPath(Input)) < 0) then
          Files.Add(TPath.GetFullPath(Input));
      end
      else if TDirectory.Exists(Input) then
      begin
        Found := TDirectory.GetFiles(Input, '*.vmd', TSearchOption.soAllDirectories);
        for Candidate in Found do
          if Files.IndexOf(TPath.GetFullPath(Candidate)) < 0 then
            Files.Add(TPath.GetFullPath(Candidate));
      end;
    except
      Inc(Failed);
    end;
end;

function EncodeMorphs(const Morphs: TMmdNamedMorphWeights): string;
var
  Entry, Root: TJSONObject;
  Items: TJSONArray;
  Morph: TMmdNamedMorphWeight;
begin
  Root := TJSONObject.Create;
  try
    Root.AddPair('version', TJSONNumber.Create(1));
    Items := TJSONArray.Create;
    Root.AddPair('morphs', Items);
    for Morph in Morphs do
    begin
      Entry := TJSONObject.Create;
      Entry.AddPair('name', Morph.Name);
      Entry.AddPair('weight', TJSONNumber.Create(Morph.Weight));
      Items.AddElement(Entry);
    end;
    Result := Root.ToJSON;
  finally
    Root.Free;
  end;
end;

function ImportMmdVmdMotions(const Inputs: TArray<string>;
  const VmdRoot: string; MotionCatalog: TPmxMotionCatalogStorage;
  out Summary: TMmdVmdImportSummary): Boolean;
var
  Catalog: TMmdVmdCatalog;
  FileName, MorphData, PoseData, Root: string;
  Files: TStringList;
  FirstFrame: Cardinal;
  IsNew: Boolean;
  Item: TMmdVmdCatalogItem;
  Morphs: TMmdNamedMorphWeights;
  MotionIndex: Integer;
  Poses: TPmxNamedBonePoses;
  Changed: Boolean;
begin
  Summary := Default(TMmdVmdImportSummary);
  Result := False;
  if not Assigned(MotionCatalog) then Exit;
  Root := Trim(VmdRoot);
  if Root = '' then Root := ExcludeTrailingPathDelimiter(GetAppFolder('VMD'));
  if Root = '' then Exit;
  Files := TStringList.Create;
  Catalog := TMmdVmdCatalog.Create(Root);
  try
    Files.CaseSensitive := False;
    CollectVmdFiles(Inputs, Files, Summary.Failed);
    Summary.Scanned := Files.Count;
    if (Files.Count = 0) or not Catalog.LoadFromFile then Exit;
    Changed := False;
    for FileName in Files do
    begin
      if not Catalog.ImportFile(FileName, Item, Poses, Morphs, FirstFrame,
        IsNew) then
      begin
        Inc(Summary.Failed);
        Continue;
      end;
      if IsNew then Inc(Summary.LibraryAdded);
      MotionIndex := MotionCatalog.IndexOfSourceVmdId(Item.Id);
      if MotionIndex >= 0 then
      begin
        Inc(Summary.AlreadyRegistered);
        Summary.LastMotionId := MotionCatalog[MotionIndex].Id;
        Continue;
      end;
      PoseData := EncodePoseData(Poses);
      MorphData := EncodeMorphs(Morphs);
      MotionIndex := MotionCatalog.AddImported(Item.Name, Item.Id,
        Item.OriginalFileName, Item.CategoryName, PoseData, MorphData,
        FirstFrame, False);
      if MotionIndex < 0 then
      begin
        Inc(Summary.Failed);
        Continue;
      end;
      Changed := True;
      Inc(Summary.MotionAdded);
      Summary.LastMotionId := MotionCatalog[MotionIndex].Id;
    end;
    if Changed and not MotionCatalog.SaveToFile then
    begin
      Inc(Summary.Failed, Summary.MotionAdded);
      Summary.MotionAdded := 0;
      MotionCatalog.LoadFromFile;
    end;
    Result := (Summary.MotionAdded > 0) or (Summary.AlreadyRegistered > 0);
  finally
    Catalog.Free;
    Files.Free;
  end;
end;

end.
