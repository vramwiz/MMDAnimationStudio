unit MmdAccessoryCatalog;

// PMX／OBJ原本を内容ハッシュで共通保管し、表示用アクセサリ項目を別UIDで管理する。

interface

uses
  System.Generics.Collections,
  MmdAccessoryCatalogItem,
  MmdAccessoryCatalogImport,
  MmdAccessoryCatalogOperations;

type
  TMmdAccessoryCatalog = class
  private
    FIndexFileName: string;
    FImporter: TMmdAccessoryCatalogImport;
    FItems: TObjectList<TMmdAccessoryCatalogItem>;
    FItemsFolder: string;
    FOperations: TMmdAccessoryCatalogOperations;
    FSourceIndexFileName: string;
    FSourceItems: TObjectList<TMmdAccessorySourceItem>;
    FSourceItemsFolder: string;
    FSourcesFolder: string;
    function CatalogItemFileName(const Id: string): string;
    function FindSource(Format: TMmdAccessorySourceFormat;
      const Hash: string): TMmdAccessorySourceItem;
    function FindSourceById(const Id: string): TMmdAccessorySourceItem;
    function GetCount: Integer;
    function GetItem(Index: Integer): TMmdAccessoryCatalogItem;
    function GetSource(Index: Integer): TMmdAccessorySourceItem;
    function GetSourceCount: Integer;
    function SourceItemFileName(const Id: string): string;
  public
    // 保存ルートを正規化し、原本と一覧項目を所有する空カタログを生成する。
    constructor Create(const RootFolder: string);
    // 登録処理と一覧操作を先に切り離し、所有する原本・一覧項目を解放する。
    destructor Destroy; override;
    // 選択項目と同じ原本を参照する別AccessoryUIDを末尾へ作る。
    function Duplicate(Index: Integer): Integer;
    // 対応拡張子の原本を保管して一覧項目を作る。同一形式・内容は既存項目を返す。
    // 形式内容の妥当性検証は後段のPMX／OBJ読込境界で行う。
    function ImportFile(const FileName: string;
      out Item: TMmdAccessoryCatalogItem; out IsNewSource,
      IsNewItem: Boolean): Boolean;
    // 原本索引と一覧順を読み込み、欠落・不正参照を除外して復元する。
    function LoadFromFile: Boolean;
    // 項目の表示順をOffset分移動し、新しい位置を返す。
    function Move(Index, Offset: Integer): Integer;
    // 一覧項目だけを削除し、共有するSourceUID原本は保持する。
    function Remove(Index: Integer): Boolean;
    // 空でない表示名を個別JSONへ保存する。
    function Rename(Index: Integer; const Value: string): Boolean;
    // SourceUIDの管理下原本パスを返し、未知UIDでは空文字列を返す。
    function SourceFileName(const SourceId: string): string;
    // 形式Readerで確認した形状数とボーン数を原本メタデータへ保存する。
    function UpdateSourceInspection(const SourceId: string; VertexCount,
      MaterialCount, BoneCount: Integer): Boolean;
    // 表示順に並ぶアクセサリ項目を、Countと既定添字プロパティで参照する。
    property Count: Integer read GetCount;
    property Items[Index: Integer]: TMmdAccessoryCatalogItem read GetItem;
      default;
    // 内容ハッシュで共有する管理下原本を、SourceCountと添字で参照する。
    property SourceCount: Integer read GetSourceCount;
    property Sources[Index: Integer]: TMmdAccessorySourceItem read GetSource;
  end;

implementation

uses
  System.IOUtils,
  System.SysUtils,
  MmdAccessoryCatalogCodec;

constructor TMmdAccessoryCatalog.Create(const RootFolder: string);
var
  NormalizedRoot: string;
begin
  inherited Create;
  NormalizedRoot := ExcludeTrailingPathDelimiter(TPath.GetFullPath(RootFolder));
  FIndexFileName := TPath.Combine(NormalizedRoot, 'Index.json');
  FItemsFolder := TPath.Combine(NormalizedRoot, 'Items');
  FSourceIndexFileName := TPath.Combine(NormalizedRoot, 'SourceIndex.json');
  FSourceItemsFolder := TPath.Combine(NormalizedRoot, 'SourceItems');
  FSourcesFolder := TPath.Combine(NormalizedRoot, 'Sources');
  FItems := TObjectList<TMmdAccessoryCatalogItem>.Create(True);
  FOperations := TMmdAccessoryCatalogOperations.Create(FItems,
    FIndexFileName, FItemsFolder);
  FSourceItems := TObjectList<TMmdAccessorySourceItem>.Create(True);
  FImporter := TMmdAccessoryCatalogImport.Create(FItems, FSourceItems,
    FOperations, FItemsFolder, FSourceIndexFileName, FSourceItemsFolder,
    FSourcesFolder);
end;

destructor TMmdAccessoryCatalog.Destroy;
begin
  FImporter.Free;
  FOperations.Free;
  FSourceItems.Free;
  FItems.Free;
  inherited;
end;

function TMmdAccessoryCatalog.Duplicate(Index: Integer): Integer;
begin
  Result := FOperations.Duplicate(Index);
end;

function TMmdAccessoryCatalog.CatalogItemFileName(const Id: string): string;
begin
  Result := TPath.Combine(FItemsFolder, Id + '.json');
end;

function TMmdAccessoryCatalog.FindSource(Format: TMmdAccessorySourceFormat;
  const Hash: string): TMmdAccessorySourceItem;
var
  Candidate: TMmdAccessorySourceItem;
begin
  Result := nil;
  for Candidate in FSourceItems do
    if (Candidate.Format = Format) and SameText(Candidate.ContentHash, Hash) then
      Exit(Candidate);
end;

function TMmdAccessoryCatalog.FindSourceById(const Id: string):
  TMmdAccessorySourceItem;
var
  Candidate: TMmdAccessorySourceItem;
begin
  Result := nil;
  for Candidate in FSourceItems do
    if SameText(Candidate.Id, Id) then Exit(Candidate);
end;

function TMmdAccessoryCatalog.GetCount: Integer;
begin
  Result := FItems.Count;
end;

function TMmdAccessoryCatalog.GetItem(Index: Integer):
  TMmdAccessoryCatalogItem;
begin
  Result := FItems[Index];
end;

function TMmdAccessoryCatalog.GetSource(Index: Integer):
  TMmdAccessorySourceItem;
begin
  Result := FSourceItems[Index];
end;

function TMmdAccessoryCatalog.GetSourceCount: Integer;
begin
  Result := FSourceItems.Count;
end;

function TMmdAccessoryCatalog.SourceItemFileName(const Id: string): string;
begin
  Result := TPath.Combine(FSourceItemsFolder, Id + '.json');
end;

function TMmdAccessoryCatalog.SourceFileName(const SourceId: string): string;
var
  Source: TMmdAccessorySourceItem;
begin
  Result := '';
  Source := FindSourceById(SourceId);
  if Assigned(Source) then
    Result := TPath.Combine(TPath.Combine(FSourcesFolder, Source.Id),
      Source.OriginalFileName);
end;

function TMmdAccessoryCatalog.UpdateSourceInspection(const SourceId: string;
  VertexCount, MaterialCount, BoneCount: Integer): Boolean;
var
  Source: TMmdAccessorySourceItem;
begin
  Result := False;
  Source := FindSourceById(SourceId);
  if not Assigned(Source) or (VertexCount < 0) or (MaterialCount < 0) or
    (BoneCount < 0) then Exit;
  Source.Validated := True;
  Source.VertexCount := VertexCount;
  Source.MaterialCount := MaterialCount;
  Source.BoneCount := BoneCount;
  Result := SaveMmdAccessorySourceItem(SourceItemFileName(Source.Id), Source);
end;

function TMmdAccessoryCatalog.LoadFromFile: Boolean;
var
  Id: string;
  Ids: TArray<string>;
  Item: TMmdAccessoryCatalogItem;
  Source: TMmdAccessorySourceItem;
begin
  Result := False;
  FItems.Clear;
  FSourceItems.Clear;
  if not LoadMmdAccessorySourceIndex(FSourceIndexFileName, Ids) then Exit;
  for Id in Ids do
  begin
    Source := LoadMmdAccessorySourceItem(SourceItemFileName(Id));
    if Assigned(Source) and SameText(Source.Id, Id) and
      not Assigned(FindSource(Source.Format, Source.ContentHash)) then
    begin
      FSourceItems.Add(Source);
      if not TFile.Exists(SourceFileName(Source.Id)) then
      begin
        FSourceItems.Extract(Source);
        Source.Free;
      end;
    end
    else Source.Free;
  end;
  if not LoadMmdAccessoryCatalogIndex(FIndexFileName, Ids) then
  begin
    FSourceItems.Clear;
    Exit;
  end;
  for Id in Ids do
  begin
    Item := LoadMmdAccessoryCatalogItem(CatalogItemFileName(Id));
    if Assigned(Item) and SameText(Item.Id, Id) and
      Assigned(FindSourceById(Item.SourceId)) then FItems.Add(Item)
    else Item.Free;
  end;
  Result := True;
end;

function TMmdAccessoryCatalog.Move(Index, Offset: Integer): Integer;
begin
  Result := FOperations.Move(Index, Offset);
end;

function TMmdAccessoryCatalog.Remove(Index: Integer): Boolean;
begin
  Result := FOperations.Remove(Index);
end;

function TMmdAccessoryCatalog.Rename(Index: Integer;
  const Value: string): Boolean;
begin
  Result := FOperations.Rename(Index, Value);
end;

function TMmdAccessoryCatalog.ImportFile(const FileName: string;
  out Item: TMmdAccessoryCatalogItem; out IsNewSource,
  IsNewItem: Boolean): Boolean;
begin
  Result := FImporter.Execute(FileName, Item, IsNewSource, IsNewItem);
end;

end.
