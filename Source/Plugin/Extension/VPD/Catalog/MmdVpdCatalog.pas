unit MmdVpdCatalog;

// ドロップされたVPDの検証、重複判定、VpdUID化、共通保存を担当する。

interface

uses
  System.Generics.Collections,
  MmdVpdCatalogItem;

type
  TMmdVpdCatalog = class
  private
    FIndexFileName: string;
    FItems: TObjectList<TMmdVpdCatalogItem>;
    FItemsFolder: string;
    FRootFolder: string;
    FSourcesFolder: string;
    function CreateId: string;
    function FindByHash(const Hash: string): TMmdVpdCatalogItem;
    function GetCount: Integer;
    function GetItem(Index: Integer): TMmdVpdCatalogItem;
    function ItemFileName(const Id: string): string;
    function SaveIndex: Boolean;
  public
    // 指定ルートを共通VPDライブラリとして扱うカタログを生成する。
    constructor Create(const RootFolder: string);
    // 読み込んだカタログ項目を破棄する。
    destructor Destroy; override;
    // VPDを検証して共通ライブラリへ登録し、内部姿勢JSONを返す。
    function ImportFile(const FileName: string; out Item: TMmdVpdCatalogItem;
      out PoseData: string; out IsNew: Boolean): Boolean;
    // 管理済み原本を読み、プレビュー／再利用用の内部姿勢JSONへ変換する。
    function LoadPoseData(const Id: string; out PoseData: string): Boolean;
    // 管理インデックスと各項目をディスクから読み直す。
    function LoadFromFile: Boolean;
    // 管理IDに対応する保存済みVPD原本のパスを返す。
    function SourceFileName(const Id: string): string;
    property Count: Integer read GetCount;
    property Items[Index: Integer]: TMmdVpdCatalogItem read GetItem; default;
    property RootFolder: string read FRootFolder;
  end;

implementation

uses
  Winapi.Windows, System.Classes, System.DateUtils, System.Hash,
  System.IOUtils, System.SysUtils,
  PmxPose, PmxPoseCodec, VpdPoseCodec, MmdVpdCatalogCodec;

constructor TMmdVpdCatalog.Create(const RootFolder: string);
begin
  inherited Create;
  FRootFolder := ExcludeTrailingPathDelimiter(TPath.GetFullPath(RootFolder));
  FIndexFileName := TPath.Combine(FRootFolder, 'Index.json');
  FItemsFolder := TPath.Combine(FRootFolder, 'Items');
  FSourcesFolder := TPath.Combine(FRootFolder, 'Sources');
  FItems := TObjectList<TMmdVpdCatalogItem>.Create(True);
end;

destructor TMmdVpdCatalog.Destroy;
begin
  FItems.Free;
  inherited;
end;

function TMmdVpdCatalog.CreateId: string;
var
  Guid: TGUID;
begin
  Result := '';
  if CreateGUID(Guid) <> S_OK then Exit;
  Result := LowerCase(GUIDToString(Guid));
  Result := StringReplace(Result, '{', '', [rfReplaceAll]);
  Result := StringReplace(Result, '}', '', [rfReplaceAll]);
  Result := StringReplace(Result, '-', '', [rfReplaceAll]);
end;

function TMmdVpdCatalog.GetCount: Integer;
begin
  Result := FItems.Count;
end;

function TMmdVpdCatalog.GetItem(Index: Integer): TMmdVpdCatalogItem;
begin
  Result := FItems[Index];
end;

function TMmdVpdCatalog.ItemFileName(const Id: string): string;
begin
  Result := TPath.Combine(FItemsFolder, Id + '.json');
end;

function TMmdVpdCatalog.SourceFileName(const Id: string): string;
begin
  Result := TPath.Combine(FSourcesFolder, Id + '.vpd');
end;

function TMmdVpdCatalog.FindByHash(
  const Hash: string): TMmdVpdCatalogItem;
var
  Candidate: TMmdVpdCatalogItem;
begin
  Result := nil;
  for Candidate in FItems do
    if SameText(Candidate.ContentHash, Hash) then Exit(Candidate);
end;

function TMmdVpdCatalog.LoadFromFile: Boolean;
var
  Id: string;
  Ids: TArray<string>;
  Item: TMmdVpdCatalogItem;
begin
  Result := False;
  FItems.Clear;
  if not LoadMmdVpdCatalogIndex(FIndexFileName, Ids) then Exit;
  for Id in Ids do
  begin
    Item := LoadMmdVpdCatalogItem(ItemFileName(Id));
    if Assigned(Item) and (FindByHash(Item.ContentHash) = nil) then
      FItems.Add(Item)
    else
      Item.Free;
  end;
  Result := True;
end;

function TMmdVpdCatalog.SaveIndex: Boolean;
var
  I: Integer;
  Ids: TArray<string>;
begin
  SetLength(Ids, FItems.Count);
  for I := 0 to FItems.Count - 1 do Ids[I] := FItems[I].Id;
  Result := SaveMmdVpdCatalogIndex(FIndexFileName, Ids);
end;

function ReadVpdText(const FileName: string): string;
var
  Bytes: TBytes;
  Encoding: TEncoding;
begin
  Bytes := TFile.ReadAllBytes(FileName);
  if (Length(Bytes) >= 3) and (Bytes[0] = $EF) and (Bytes[1] = $BB) and
    (Bytes[2] = $BF) then
    Exit(TEncoding.UTF8.GetString(Bytes, 3, Length(Bytes) - 3));
  Encoding := TEncoding.GetEncoding(932);
  try
    Result := Encoding.GetString(Bytes);
  finally
    Encoding.Free;
  end;
end;

function TMmdVpdCatalog.ImportFile(const FileName: string;
  out Item: TMmdVpdCatalogItem; out PoseData: string;
  out IsNew: Boolean): Boolean;
var
  Hash, ManagedFile, ParentFolder: string;
  Poses: TPmxNamedBonePoses;
  NewIndex: Integer;
begin
  Result := False;
  Item := nil;
  PoseData := '';
  IsNew := False;
  try
    if not TFile.Exists(FileName) or
      not SameText(TPath.GetExtension(FileName), '.vpd') or
      not TryDecodeVpdPose(ReadVpdText(FileName), Poses) then Exit;
    PoseData := EncodePoseData(Poses);
    Hash := LowerCase(THashSHA2.GetHashStringFromFile(FileName));
    Item := FindByHash(Hash);
    if Assigned(Item) then
    begin
      ManagedFile := SourceFileName(Item.Id);
      if not TFile.Exists(ManagedFile) then
      begin
        ForceDirectories(FSourcesFolder);
        TFile.Copy(FileName, ManagedFile, True);
      end;
      Exit(True);
    end;
    Item := TMmdVpdCatalogItem.Create;
    Item.Id := CreateId;
    if Item.Id = '' then
    begin
      FreeAndNil(Item);
      Exit;
    end;
    Item.Name := TPath.GetFileNameWithoutExtension(FileName);
    Item.OriginalFileName := TPath.GetFileName(FileName);
    Item.OriginalPath := TPath.GetFullPath(FileName);
    ParentFolder := TPath.GetDirectoryName(Item.OriginalPath);
    Item.CategoryName := TPath.GetFileName(
      ExcludeTrailingPathDelimiter(ParentFolder));
    Item.ContentHash := Hash;
    Item.ImportedAt := DateToISO8601(TTimeZone.Local.ToUniversalTime(Now), True);
    ForceDirectories(FSourcesFolder);
    ManagedFile := SourceFileName(Item.Id);
    TFile.Copy(FileName, ManagedFile, False);
    NewIndex := FItems.Add(Item);
    if not SaveMmdVpdCatalogItem(ItemFileName(Item.Id), Item) or
      not SaveIndex then
    begin
      FItems.Extract(Item);
      if TFile.Exists(ManagedFile) then TFile.Delete(ManagedFile);
      if TFile.Exists(ItemFileName(Item.Id)) then
        TFile.Delete(ItemFileName(Item.Id));
      Item.Free;
      Item := nil;
      Exit;
    end;
    Item := FItems[NewIndex];
    IsNew := True;
    Result := True;
  except
    Item := nil;
    PoseData := '';
    Result := False;
  end;
end;

function TMmdVpdCatalog.LoadPoseData(const Id: string;
  out PoseData: string): Boolean;
var
  Poses: TPmxNamedBonePoses;
  Source: string;
begin
  Result := False;
  PoseData := '';
  try
    Source := SourceFileName(Id);
    if not TFile.Exists(Source) or
      not TryDecodeVpdPose(ReadVpdText(Source), Poses) then Exit;
    PoseData := EncodePoseData(Poses);
    Result := True;
  except
    PoseData := '';
  end;
end;

end.
