unit MmdVpdPoseImporter;

// VPDファイル／フォルダを列挙し、共通保管と選択PMX用ポーズ登録を行う。

interface

uses
  PmxPoseCatalogStorage, PmxPoseCatalogGroups;

type
  // 一括取込の走査数、追加数、重複数、失敗数と最後の選択候補を返す。
  TMmdVpdImportSummary = record
    AlreadyRegistered: Integer;
    Failed: Integer;
    LastPoseId: string;
    LibraryAdded: Integer;
    PoseAdded: Integer;
    Scanned: Integer;
  end;

// VPDファイル／フォルダを共通保管へ取り込み、選択PMXのポーズへ一括登録する。
function ImportMmdVpdPoses(const Inputs: TArray<string>;
  const VpdRoot: string; PoseCatalog: TPmxPoseCatalogStorage;
  Groups: TPmxPoseCatalogGroups; out Summary: TMmdVpdImportSummary): Boolean;

implementation

uses
  System.Classes, System.IOUtils, System.SysUtils,
  AppFolderUtils, MmdVpdCatalog, MmdVpdCatalogItem;

procedure CollectVpdFiles(const Inputs: TArray<string>; Files: TStrings;
  var Failed: Integer);
var
  Candidate, Input: string;
  Found: TArray<string>;
begin
  for Input in Inputs do
    try
      if TFile.Exists(Input) then
      begin
        if SameText(TPath.GetExtension(Input), '.vpd') and
          (Files.IndexOf(TPath.GetFullPath(Input)) < 0) then
          Files.Add(TPath.GetFullPath(Input));
      end
      else if TDirectory.Exists(Input) then
      begin
        Found := TDirectory.GetFiles(Input, '*.vpd',
          TSearchOption.soAllDirectories);
        for Candidate in Found do
          if Files.IndexOf(TPath.GetFullPath(Candidate)) < 0 then
            Files.Add(TPath.GetFullPath(Candidate));
      end;
    except
      Inc(Failed);
    end;
end;

function EnsureGroup(Groups: TPmxPoseCatalogGroups;
  const Name: string): Integer;
begin
  Result := -1;
  if not Assigned(Groups) or (Trim(Name) = '') then Exit;
  Result := Groups.IndexOfName(Name);
  if (Result < 0) and Assigned(Groups.Add(Name)) then
    Result := Groups.Count - 1;
end;

function ImportMmdVpdPoses(const Inputs: TArray<string>;
  const VpdRoot: string; PoseCatalog: TPmxPoseCatalogStorage;
  Groups: TPmxPoseCatalogGroups; out Summary: TMmdVpdImportSummary): Boolean;
var
  Catalog: TMmdVpdCatalog;
  CategoryIndex, PoseIndex: Integer;
  FileName, PoseData, Root: string;
  Files: TStringList;
  IsNew: Boolean;
  Item: TMmdVpdCatalogItem;
  PoseChanged: Boolean;
begin
  Summary := Default(TMmdVpdImportSummary);
  Result := False;
  if not Assigned(PoseCatalog) or not Assigned(Groups) then Exit;
  Root := Trim(VpdRoot);
  if Root = '' then Root := ExcludeTrailingPathDelimiter(GetAppFolder('VPD'));
  if Root = '' then Exit;
  Files := TStringList.Create;
  Catalog := TMmdVpdCatalog.Create(Root);
  try
    Files.CaseSensitive := False;
    CollectVpdFiles(Inputs, Files, Summary.Failed);
    Summary.Scanned := Files.Count;
    if (Files.Count = 0) or not Catalog.LoadFromFile then Exit;
    PoseChanged := False;
    for FileName in Files do
    begin
      if not Catalog.ImportFile(FileName, Item, PoseData, IsNew) then
      begin
        Inc(Summary.Failed);
        Continue;
      end;
      if IsNew then Inc(Summary.LibraryAdded);
      PoseIndex := PoseCatalog.IndexOfSourceVpdId(Item.Id);
      if PoseIndex >= 0 then
      begin
        Inc(Summary.AlreadyRegistered);
        Summary.LastPoseId := PoseCatalog[PoseIndex].Id;
      end
      else
      begin
        PoseIndex := PoseCatalog.AddImported(Item.Name, PoseData, Item.Id,
          Item.OriginalFileName, Item.CategoryName, False);
        if PoseIndex < 0 then
        begin
          Inc(Summary.Failed);
          Continue;
        end;
        PoseChanged := True;
        Inc(Summary.PoseAdded);
        Summary.LastPoseId := PoseCatalog[PoseIndex].Id;
      end;
      CategoryIndex := EnsureGroup(Groups, Item.CategoryName);
      if CategoryIndex >= 0 then
        Groups.AssignPoseToGroup(PoseCatalog[PoseIndex].Id, CategoryIndex);
    end;
    if PoseChanged and not PoseCatalog.SaveToFile then
    begin
      Inc(Summary.Failed, Summary.PoseAdded);
      Summary.PoseAdded := 0;
      PoseCatalog.LoadOrCreateDefault;
    end;
    if Groups.RemoveUnknownPoses(PoseCatalog) then
      Summary.LastPoseId := '';
    if not Groups.SaveToFile then Inc(Summary.Failed);
    Result := (Summary.PoseAdded > 0) or (Summary.AlreadyRegistered > 0);
  finally
    Catalog.Free;
    Files.Free;
  end;
end;

end.
