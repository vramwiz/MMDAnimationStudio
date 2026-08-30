unit MmdVmdCatalog;

// ドロップされたVMDを検証し、内容ハッシュで重複排除してVmdUID原本として保存する。

interface

uses
  System.Generics.Collections,
  PmxPose,
  MmdMorphSettingCodec,
  MmdVmdCatalogItem;

type
  TMmdVmdCatalog = class
  private
    FIndexFileName: string;
    FItems: TObjectList<TMmdVmdCatalogItem>;
    FItemsFolder: string;
    FRootFolder: string;
    FSourcesFolder: string;
    function CreateId: string;
    function FindByHash(const Hash: string): TMmdVmdCatalogItem;
    function GetCount: Integer;
    function GetItem(Index: Integer): TMmdVmdCatalogItem;
    function ItemFileName(const Id: string): string;
    function SaveIndex: Boolean;
  public
    constructor Create(const RootFolder: string);
    destructor Destroy; override;
    // VMDを共通保管し、静止サムネイルに使う各トラック先頭キーを返す。
    function ImportFile(const FileName: string; out Item: TMmdVmdCatalogItem;
      out Poses: TPmxNamedBonePoses; out Morphs: TMmdNamedMorphWeights;
      out FirstFrame: Cardinal; out IsNew: Boolean): Boolean;
    // 保存済みVmdUID一覧を読み込む。索引未作成は空一覧として成功する。
    function LoadFromFile: Boolean;
    // VmdUIDから内部コピーした原本VMDのパスを返す。
    function SourceFileName(const Id: string): string;
    property Count: Integer read GetCount;
    property Items[Index: Integer]: TMmdVmdCatalogItem read GetItem; default;
  end;

implementation

uses
  Winapi.Windows,
  System.DateUtils,
  System.Hash,
  System.IOUtils,
  System.SysUtils,
  VmdFirstFrameReader,
  MmdVmdCatalogCodec;

constructor TMmdVmdCatalog.Create(const RootFolder: string);
begin
  inherited Create;
  FRootFolder := ExcludeTrailingPathDelimiter(TPath.GetFullPath(RootFolder));
  FIndexFileName := TPath.Combine(FRootFolder, 'Index.json');
  FItemsFolder := TPath.Combine(FRootFolder, 'Items');
  FSourcesFolder := TPath.Combine(FRootFolder, 'Sources');
  FItems := TObjectList<TMmdVmdCatalogItem>.Create(True);
end;

destructor TMmdVmdCatalog.Destroy;
begin
  FItems.Free;
  inherited;
end;

function TMmdVmdCatalog.CreateId: string;
var
  Guid: TGUID;
begin
  Result := '';
  if CreateGUID(Guid) <> S_OK then Exit;
  Result := LowerCase(GUIDToString(Guid)).Replace('{', '').Replace('}', '').Replace('-', '');
end;

function TMmdVmdCatalog.FindByHash(const Hash: string): TMmdVmdCatalogItem;
var
  Candidate: TMmdVmdCatalogItem;
begin
  Result := nil;
  for Candidate in FItems do
    if SameText(Candidate.ContentHash, Hash) then Exit(Candidate);
end;

function TMmdVmdCatalog.GetCount: Integer;
begin
  Result := FItems.Count;
end;

function TMmdVmdCatalog.GetItem(Index: Integer): TMmdVmdCatalogItem;
begin
  Result := FItems[Index];
end;

function TMmdVmdCatalog.ItemFileName(const Id: string): string;
begin
  Result := TPath.Combine(FItemsFolder, Id + '.json');
end;

function TMmdVmdCatalog.SourceFileName(const Id: string): string;
begin
  Result := TPath.Combine(FSourcesFolder, Id + '.vmd');
end;

function TMmdVmdCatalog.LoadFromFile: Boolean;
var
  Id: string;
  Ids: TArray<string>;
  Item: TMmdVmdCatalogItem;
begin
  Result := False;
  FItems.Clear;
  if not LoadMmdVmdCatalogIndex(FIndexFileName, Ids) then Exit;
  for Id in Ids do
  begin
    Item := LoadMmdVmdCatalogItem(ItemFileName(Id));
    if Assigned(Item) and (FindByHash(Item.ContentHash) = nil) then FItems.Add(Item)
    else Item.Free;
  end;
  Result := True;
end;

function TMmdVmdCatalog.SaveIndex: Boolean;
var
  I: Integer;
  Ids: TArray<string>;
begin
  SetLength(Ids, FItems.Count);
  for I := 0 to FItems.Count - 1 do Ids[I] := FItems[I].Id;
  Result := SaveMmdVmdCatalogIndex(FIndexFileName, Ids);
end;

function TMmdVmdCatalog.ImportFile(const FileName: string;
  out Item: TMmdVmdCatalogItem; out Poses: TPmxNamedBonePoses;
  out Morphs: TMmdNamedMorphWeights; out FirstFrame: Cardinal;
  out IsNew: Boolean): Boolean;
var
  Hash, ManagedFile, ModelName, ParentFolder: string;
  NewIndex: Integer;
  CreatedManagedFile, OwnsItem: Boolean;
begin
  Result := False;
  Item := nil;
  Poses := nil;
  Morphs := nil;
  FirstFrame := 0;
  IsNew := False;
  ManagedFile := '';
  CreatedManagedFile := False;
  OwnsItem := False;
  try
    if not TFile.Exists(FileName) or
      not SameText(TPath.GetExtension(FileName), '.vmd') or
      not TryReadVmdFirstFrame(FileName, Poses, Morphs, FirstFrame,
        ModelName) then Exit;
    Hash := LowerCase(THashSHA2.GetHashStringFromFile(FileName));
    Item := FindByHash(Hash);
    if Assigned(Item) then
    begin
      ManagedFile := SourceFileName(Item.Id);
      if not TFile.Exists(ManagedFile) then
      begin
        ForceDirectories(FSourcesFolder);
        CreatedManagedFile := True;
        TFile.Copy(FileName, ManagedFile, True);
      end;
      Exit(True);
    end;
    Item := TMmdVmdCatalogItem.Create;
    OwnsItem := True;
    Item.Id := CreateId;
    if Item.Id = '' then begin FreeAndNil(Item); Exit; end;
    Item.Name := TPath.GetFileNameWithoutExtension(FileName);
    Item.OriginalFileName := TPath.GetFileName(FileName);
    Item.OriginalPath := TPath.GetFullPath(FileName);
    ParentFolder := TPath.GetDirectoryName(Item.OriginalPath);
    Item.CategoryName := TPath.GetFileName(ExcludeTrailingPathDelimiter(ParentFolder));
    Item.ContentHash := Hash;
    Item.ImportedAt := DateToISO8601(TTimeZone.Local.ToUniversalTime(Now), True);
    Item.ModelName := ModelName;
    ForceDirectories(FSourcesFolder);
    ManagedFile := SourceFileName(Item.Id);
    CreatedManagedFile := True;
    TFile.Copy(FileName, ManagedFile, False);
    NewIndex := FItems.Add(Item);
    if not SaveMmdVmdCatalogItem(ItemFileName(Item.Id), Item) or
      not SaveIndex then
    begin
      FItems.Extract(Item);
      if TFile.Exists(ManagedFile) then TFile.Delete(ManagedFile);
      if TFile.Exists(ItemFileName(Item.Id)) then TFile.Delete(ItemFileName(Item.Id));
      Item.Free;
      Item := nil;
      Exit;
    end;
    Item := FItems[NewIndex];
    IsNew := True;
    Result := True;
  except
    if OwnsItem and Assigned(Item) then
    begin
      NewIndex := FItems.IndexOf(Item);
      if NewIndex >= 0 then FItems.Extract(Item);
      Item.Free;
    end;
    try
      if CreatedManagedFile and (ManagedFile <> '') and
        TFile.Exists(ManagedFile) then
        TFile.Delete(ManagedFile);
    except
      { 取込失敗時の孤立原本は次回の同一ハッシュ取込で上書きする。 }
    end;
    Item := nil;
    Poses := nil;
    Morphs := nil;
  end;
end;

end.
