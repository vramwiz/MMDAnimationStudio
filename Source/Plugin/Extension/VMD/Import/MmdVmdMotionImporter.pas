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
// 旧カタログで欠落しているMotionUID別内部データをVMD原本から一度だけ生成する。
function EnsureMmdVmdMotionData(const VmdRoot: string;
  MotionCatalog: TPmxMotionCatalogStorage): Boolean;

implementation

uses
  System.Classes,
  System.IOUtils,
  System.JSON,
  System.SysUtils,
  AppFolderUtils,
  MmdMotionDocument,
  MmdMotionDocumentCodec,
  PmxPose,
  PmxPoseCodec,
  MmdMorphSettingCodec,
  MmdVmdCatalog,
  MmdVmdCatalogItem,
  VmdMotionDocumentReader;

function EnsureMmdVmdMotionData(const VmdRoot: string;
  MotionCatalog: TPmxMotionCatalogStorage): Boolean;
var
  DataFile, MotionData, Root, SourceFile: string;
  Document: TMmdMotionDocument;
  I: Integer;
begin
  Result := False;
  Root := ExcludeTrailingPathDelimiter(Trim(VmdRoot));
  if not Assigned(MotionCatalog) or (Root = '') then Exit;
  Result := True;
  for I := 0 to MotionCatalog.Count - 1 do
  begin
    if MotionCatalog.HasMotionData(I) then Continue;
    DataFile := TPath.Combine(TPath.Combine(Root, 'Data'),
      MotionCatalog[I].SourceVmdId + '.json');
    SourceFile := TPath.Combine(TPath.Combine(Root, 'Sources'),
      MotionCatalog[I].SourceVmdId + '.vmd');
    Document := nil;
    try
      if not LoadMmdMotionDocument(DataFile, Document) then
      begin
        if not TryReadVmdMotionDocument(SourceFile, Document) or
          not SaveMmdMotionDocument(DataFile, Document) then
        begin
          Result := False;
          Continue;
        end;
      end;
      MotionData := EncodeMmdMotionDocument(Document);
      if (MotionData = '') or not MotionCatalog.SaveMotionData(I, MotionData) then
        Result := False;
    finally
      Document.Free;
    end;
  end;
end;

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
  ExistingMotionData, FileName, MorphData, MotionData, PoseData, Root: string;
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
        MotionData, IsNew) then
      begin
        Inc(Summary.Failed);
        Continue;
      end;
      if IsNew then Inc(Summary.LibraryAdded);
      MotionIndex := MotionCatalog.IndexOfSourceVmdId(Item.Id);
      if MotionIndex >= 0 then
      begin
        if not MotionCatalog.LoadMotionData(MotionIndex, ExistingMotionData) and
          not MotionCatalog.SaveMotionData(MotionIndex, MotionData) then
        begin
          Inc(Summary.Failed);
          Continue;
        end;
        Inc(Summary.AlreadyRegistered);
        Summary.LastMotionId := MotionCatalog[MotionIndex].Id;
        Continue;
      end;
      PoseData := EncodePoseData(Poses);
      MorphData := EncodeMorphs(Morphs);
      MotionIndex := MotionCatalog.AddImported(Item.Name, Item.Id,
        Item.OriginalFileName, Item.CategoryName, MotionData, PoseData,
        MorphData, FirstFrame, False);
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
