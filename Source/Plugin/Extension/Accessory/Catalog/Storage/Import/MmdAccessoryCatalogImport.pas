unit MmdAccessoryCatalogImport;

// 原本コピー、重複判定、索引更新を1回のアクセサリ取込トランザクションとして扱う。

interface

uses
  System.Generics.Collections,
  MmdAccessoryCatalogItem,
  MmdAccessoryCatalogOperations;

type
  TMmdAccessoryCatalogImport = class
  private
    FItems: TObjectList<TMmdAccessoryCatalogItem>;
    FItemsFolder: string;
    FOperations: TMmdAccessoryCatalogOperations;
    FSourceIndexFileName: string;
    FSourceItems: TObjectList<TMmdAccessorySourceItem>;
    FSourceItemsFolder: string;
    FSourcesFolder: string;
    function CreateId: string;
    function FindItemBySourceId(const SourceId: string):
      TMmdAccessoryCatalogItem;
    function FindSource(Format: TMmdAccessorySourceFormat;
      const Hash: string): TMmdAccessorySourceItem;
    function ItemFileName(const Id: string): string;
    function SaveSourceIndex: Boolean;
    function SourceFileName(const Source: TMmdAccessorySourceItem): string;
    function SourceItemFileName(const Id: string): string;
  public
    // カタログ所有の一覧、原本一覧、保存先を非所有参照として受け取る。
    constructor Create(AItems: TObjectList<TMmdAccessoryCatalogItem>;
      ASourceItems: TObjectList<TMmdAccessorySourceItem>;
      AOperations: TMmdAccessoryCatalogOperations; const AItemsFolder,
      ASourceIndexFileName, ASourceItemsFolder, ASourcesFolder: string);
    // 対応原本を管理下へコピーし、必要ならSourceUIDとAccessoryUIDを作成する。
    // 失敗時は今回追加したファイルと索引参照を可能な範囲で巻き戻す。
    function Execute(const FileName: string;
      out Item: TMmdAccessoryCatalogItem; out IsNewSource,
      IsNewItem: Boolean): Boolean;
  end;

implementation

uses
  Winapi.Windows,
  System.DateUtils,
  System.Hash,
  System.IOUtils,
  System.SysUtils,
  MmdAccessoryCatalogCodec;

constructor TMmdAccessoryCatalogImport.Create(
  AItems: TObjectList<TMmdAccessoryCatalogItem>;
  ASourceItems: TObjectList<TMmdAccessorySourceItem>;
  AOperations: TMmdAccessoryCatalogOperations; const AItemsFolder,
  ASourceIndexFileName, ASourceItemsFolder, ASourcesFolder: string);
begin
  inherited Create;
  FItems := AItems;
  FSourceItems := ASourceItems;
  FOperations := AOperations;
  FItemsFolder := AItemsFolder;
  FSourceIndexFileName := ASourceIndexFileName;
  FSourceItemsFolder := ASourceItemsFolder;
  FSourcesFolder := ASourcesFolder;
end;

function TMmdAccessoryCatalogImport.CreateId: string;
var
  Guid: TGUID;
begin
  Result := '';
  if CreateGUID(Guid) <> S_OK then Exit;
  Result := LowerCase(GUIDToString(Guid)).Replace('{', '').Replace('}', '')
    .Replace('-', '');
end;

function TMmdAccessoryCatalogImport.FindItemBySourceId(
  const SourceId: string): TMmdAccessoryCatalogItem;
var
  Candidate: TMmdAccessoryCatalogItem;
begin
  Result := nil;
  for Candidate in FItems do
    if SameText(Candidate.SourceId, SourceId) then Exit(Candidate);
end;

function TMmdAccessoryCatalogImport.FindSource(
  Format: TMmdAccessorySourceFormat;
  const Hash: string): TMmdAccessorySourceItem;
var
  Candidate: TMmdAccessorySourceItem;
begin
  Result := nil;
  for Candidate in FSourceItems do
    if (Candidate.Format = Format) and SameText(Candidate.ContentHash, Hash) then
      Exit(Candidate);
end;

function TMmdAccessoryCatalogImport.ItemFileName(const Id: string): string;
begin
  Result := TPath.Combine(FItemsFolder, Id + '.json');
end;

function TMmdAccessoryCatalogImport.SaveSourceIndex: Boolean;
var
  I: Integer;
  Ids: TArray<string>;
begin
  SetLength(Ids, FSourceItems.Count);
  for I := 0 to FSourceItems.Count - 1 do Ids[I] := FSourceItems[I].Id;
  Result := SaveMmdAccessorySourceIndex(FSourceIndexFileName, Ids);
end;

function TMmdAccessoryCatalogImport.SourceFileName(
  const Source: TMmdAccessorySourceItem): string;
begin
  Result := TPath.Combine(TPath.Combine(FSourcesFolder, Source.Id),
    Source.OriginalFileName);
end;

function TMmdAccessoryCatalogImport.SourceItemFileName(
  const Id: string): string;
begin
  Result := TPath.Combine(FSourceItemsFolder, Id + '.json');
end;

function TMmdAccessoryCatalogImport.Execute(const FileName: string;
  out Item: TMmdAccessoryCatalogItem; out IsNewSource,
  IsNewItem: Boolean): Boolean;
var
  Format: TMmdAccessorySourceFormat;
  Hash, ItemMetadataFile, ManagedFile, ParentFolder,
    SourceMetadataFile: string;
  AddedItem, AddedSource: Boolean;
  NewItem: TMmdAccessoryCatalogItem;
  NewSource, Source: TMmdAccessorySourceItem;
begin
  Result := False;
  Item := nil;
  IsNewSource := False;
  IsNewItem := False;
  NewSource := nil;
  NewItem := nil;
  Source := nil;
  AddedItem := False;
  AddedSource := False;
  ManagedFile := '';
  SourceMetadataFile := '';
  ItemMetadataFile := '';
  try
    if not TFile.Exists(FileName) or
      not TryMmdAccessorySourceFormat(TPath.GetExtension(FileName),
        Format) then Exit;
    Hash := LowerCase(THashSHA2.GetHashStringFromFile(FileName));
    Source := FindSource(Format, Hash);
    if not Assigned(Source) then
    begin
      NewSource := TMmdAccessorySourceItem.Create;
      NewSource.Id := CreateId;
      if NewSource.Id = '' then Exit;
      NewSource.Format := Format;
      NewSource.OriginalFileName := TPath.GetFileName(FileName);
      NewSource.OriginalPath := TPath.GetFullPath(FileName);
      NewSource.ContentHash := Hash;
      NewSource.ImportedAt := DateToISO8601(
        TTimeZone.Local.ToUniversalTime(Now), True);
      ManagedFile := TPath.Combine(TPath.Combine(FSourcesFolder,
        NewSource.Id), NewSource.OriginalFileName);
      ForceDirectories(TPath.GetDirectoryName(ManagedFile));
      TFile.Copy(FileName, ManagedFile, False);
      FSourceItems.Add(NewSource);
      Source := NewSource;
      NewSource := nil;
      AddedSource := True;
      SourceMetadataFile := SourceItemFileName(Source.Id);
      if not SaveMmdAccessorySourceItem(SourceMetadataFile, Source) or
        not SaveSourceIndex then
        raise EInOutError.Create('Cannot save accessory source');
      IsNewSource := True;
    end
    else
    begin
      ManagedFile := SourceFileName(Source);
      if not TFile.Exists(ManagedFile) then
      begin
        ForceDirectories(TPath.GetDirectoryName(ManagedFile));
        TFile.Copy(FileName, ManagedFile, False);
      end;
    end;
    Item := FindItemBySourceId(Source.Id);
    if Assigned(Item) then Exit(True);
    NewItem := TMmdAccessoryCatalogItem.Create;
    NewItem.Id := CreateId;
    if NewItem.Id = '' then
      raise EInOutError.Create('Cannot create accessory UID');
    NewItem.SourceId := Source.Id;
    NewItem.Name := TPath.GetFileNameWithoutExtension(FileName);
    ParentFolder := TPath.GetDirectoryName(TPath.GetFullPath(FileName));
    NewItem.CategoryName := TPath.GetFileName(
      ExcludeTrailingPathDelimiter(ParentFolder));
    FItems.Add(NewItem);
    Item := NewItem;
    NewItem := nil;
    AddedItem := True;
    ItemMetadataFile := ItemFileName(Item.Id);
    if not SaveMmdAccessoryCatalogItem(ItemMetadataFile, Item) or
      not FOperations.SaveIndex then
      raise EInOutError.Create('Cannot save accessory item');
    IsNewItem := True;
    Result := True;
  except
    Result := False;
    try
      NewItem.Free;
      NewSource.Free;
      if AddedItem and Assigned(Item) then
      begin
        FItems.Extract(Item);
        Item.Free;
        if (ItemMetadataFile <> '') and TFile.Exists(ItemMetadataFile) then
          TFile.Delete(ItemMetadataFile);
        FOperations.SaveIndex;
      end;
      if AddedSource and Assigned(Source) then
      begin
        FSourceItems.Extract(Source);
        Source.Free;
        if (SourceMetadataFile <> '') and TFile.Exists(SourceMetadataFile) then
          TFile.Delete(SourceMetadataFile);
        if (ManagedFile <> '') and TFile.Exists(ManagedFile) then
          TFile.Delete(ManagedFile);
        if (ManagedFile <> '') and
          TDirectory.Exists(TPath.GetDirectoryName(ManagedFile)) and
          (Length(TDirectory.GetFiles(TPath.GetDirectoryName(ManagedFile))) = 0)
          then TDirectory.Delete(TPath.GetDirectoryName(ManagedFile), False);
        SaveSourceIndex;
      end;
    except
      { 巻戻し失敗による孤立ファイルは次回Loadで採用しない。 }
    end;
    Item := nil;
    IsNewSource := False;
    IsNewItem := False;
  end;
end;

end.
