unit PmxMotionCatalogStorage;

// 1つのPMXへ登録したモーションをMotionUID別ファイルと順序索引で管理する。

interface

uses
  System.Generics.Collections,
  PmxMotionCatalogItem;

type
  TPmxMotionCatalogItem = PmxMotionCatalogItem.TPmxMotionCatalogItem;
  TPmxMotionCatalogStorage = class
  private
    FIndexFileName: string;
    FDataFolder: string;
    FItems: TObjectList<TPmxMotionCatalogItem>;
    FItemsFolder: string;
    FPmxId: string;
    FPmxName: string;
    function CreateId: string;
    function DataFileName(const Id: string): string;
    function GetCount: Integer;
    function GetItem(Index: Integer): TPmxMotionCatalogItem;
    function ItemFileName(const Id: string): string;
  public
    constructor Create(const ModelFolder: string; const APmxId,
      APmxName: string);
    destructor Destroy; override;
    // 保存済み一覧を読み込む。ポーズと異なり0件でも既定項目は作成しない。
    function LoadFromFile: Boolean;
    // VMD参照と静止代表状態を新しいMotionUIDとして末尾へ追加する。
    function AddImported(const Name, SourceVmdId, SourceVmdName,
      SourceCategoryName, MotionData, PreviewPoseData,
      PreviewMorphData: string; FirstFrame: Cardinal;
      SaveNow: Boolean = True): Integer;
    // 指定項目を別MotionUIDとして複製し、追加位置を返す。
    function Duplicate(Index: Integer): Integer;
    // 選択項目にMotionUID別の全トラックファイルがあるか返す。
    function HasMotionData(Index: Integer): Boolean;
    // 同じVmdUIDを参照する登録位置を返し、未登録なら-1を返す。
    function IndexOfSourceVmdId(const Value: string): Integer;
    // 選択項目の全トラックを必要時だけデシリアライズして返す。
    function LoadMotionData(Index: Integer; out MotionData: string): Boolean;
    // 項目をOffset分だけ移動し、保存後の位置を返す。
    function Move(Index, Offset: Integer): Integer;
    // 指定項目を索引と個別JSONから削除する。
    function Remove(Index: Integer): Boolean;
    // 指定項目名を変更し、個別JSONへ保存する。
    function Rename(Index: Integer; const Value: string): Boolean;
    // 現在の全項目と表示順をPMX別フォルダへ保存する。
    function SaveToFile: Boolean;
    // 選択項目の編集済み全トラックを検証し、MotionUID別ファイルへ保存する。
    function SaveMotionData(Index: Integer; const MotionData: string): Boolean;
    property Count: Integer read GetCount;
    property Items[Index: Integer]: TPmxMotionCatalogItem read GetItem; default;
  end;

implementation

uses
  Winapi.Windows,
  System.IOUtils,
  System.SysUtils,
  MmdMotionDocument,
  MmdMotionDocumentCodec,
  PmxMotionCatalogCodec;

constructor TPmxMotionCatalogStorage.Create(const ModelFolder: string;
  const APmxId, APmxName: string);
var
  Folder: string;
begin
  inherited Create;
  Folder := TPath.Combine(ModelFolder, 'Motions');
  FIndexFileName := TPath.Combine(Folder, 'Index.json');
  FItemsFolder := TPath.Combine(Folder, 'Items');
  FDataFolder := TPath.Combine(Folder, 'Data');
  FPmxId := APmxId;
  FPmxName := APmxName;
  FItems := TObjectList<TPmxMotionCatalogItem>.Create(True);
end;

function TPmxMotionCatalogStorage.DataFileName(const Id: string): string;
begin
  Result := TPath.Combine(FDataFolder, Id + '.json');
end;

destructor TPmxMotionCatalogStorage.Destroy;
begin
  FItems.Free;
  inherited;
end;

function TPmxMotionCatalogStorage.CreateId: string;
var
  Guid: TGUID;
begin
  Result := '';
  if CreateGUID(Guid) <> S_OK then Exit;
  Result := LowerCase(GUIDToString(Guid)).Replace('{', '').Replace('}', '').Replace('-', '');
end;

function TPmxMotionCatalogStorage.GetCount: Integer;
begin
  Result := FItems.Count;
end;

function TPmxMotionCatalogStorage.GetItem(Index: Integer): TPmxMotionCatalogItem;
begin
  Result := FItems[Index];
end;

function TPmxMotionCatalogStorage.ItemFileName(const Id: string): string;
begin
  Result := TPath.Combine(FItemsFolder, Id + '.json');
end;

function TPmxMotionCatalogStorage.LoadFromFile: Boolean;
var
  Id, StoredPmxId: string;
  Ids: TArray<string>;
  Item: TPmxMotionCatalogItem;
begin
  Result := False;
  FItems.Clear;
  try
    if not LoadPmxMotionCatalogIndex(FIndexFileName, StoredPmxId, Ids) then Exit;
    if FPmxId = '' then FPmxId := StoredPmxId;
    for Id in Ids do
    begin
      Item := LoadPmxMotionCatalogItem(ItemFileName(Id), FPmxId, FPmxName);
      if Assigned(Item) then FItems.Add(Item);
    end;
    Result := True;
  except
    FItems.Clear;
  end;
end;

function TPmxMotionCatalogStorage.AddImported(const Name, SourceVmdId,
  SourceVmdName, SourceCategoryName, MotionData, PreviewPoseData,
  PreviewMorphData: string; FirstFrame: Cardinal; SaveNow: Boolean): Integer;
var
  Item: TPmxMotionCatalogItem;
begin
  Result := -1;
  if (Trim(Name) = '') or (Trim(SourceVmdId) = '') or
    (IndexOfSourceVmdId(SourceVmdId) >= 0) then Exit;
  Item := TPmxMotionCatalogItem.Create;
  Item.Id := CreateId;
  if Item.Id = '' then begin Item.Free; Exit; end;
  Item.Name := Trim(Name);
  Item.PmxId := FPmxId;
  Item.PmxName := FPmxName;
  Item.SourceVmdId := Trim(SourceVmdId);
  Item.SourceVmdName := Trim(SourceVmdName);
  Item.SourceCategoryName := Trim(SourceCategoryName);
  Item.PreviewPoseData := PreviewPoseData;
  Item.PreviewMorphData := PreviewMorphData;
  Item.FirstFrame := FirstFrame;
  Result := FItems.Add(Item);
  if not SaveMotionData(Result, MotionData) then
  begin
    FItems.Delete(Result);
    Exit(-1);
  end;
  if SaveNow and not SaveToFile then
  begin
    try
      if TFile.Exists(DataFileName(Item.Id)) then TFile.Delete(DataFileName(Item.Id));
    except
      { 保存失敗時の孤立データは次回の同一MotionUID保存で上書きする。 }
    end;
    FItems.Delete(Result);
    Result := -1;
  end;
end;

function TPmxMotionCatalogStorage.Duplicate(Index: Integer): Integer;
var
  Item, Source: TPmxMotionCatalogItem;
  MotionData: string;
begin
  Result := -1;
  if (Index < 0) or (Index >= FItems.Count) or
    not LoadMotionData(Index, MotionData) then Exit;
  Source := FItems[Index];
  Item := TPmxMotionCatalogItem.Create;
  Item.Id := CreateId;
  if Item.Id = '' then begin Item.Free; Exit; end;
  Item.Name := Source.Name + '(Copy)';
  Item.PmxId := FPmxId;
  Item.PmxName := FPmxName;
  Item.SourceVmdId := Source.SourceVmdId;
  Item.SourceVmdName := Source.SourceVmdName;
  Item.SourceCategoryName := Source.SourceCategoryName;
  Item.PreviewPoseData := Source.PreviewPoseData;
  Item.PreviewMorphData := Source.PreviewMorphData;
  Item.FirstFrame := Source.FirstFrame;
  Result := FItems.Add(Item);
  if not SaveMotionData(Result, MotionData) or not SaveToFile then
  begin
    try
      if TFile.Exists(DataFileName(Item.Id)) then TFile.Delete(DataFileName(Item.Id));
    except
      { 孤立データは索引から参照されない。 }
    end;
    FItems.Delete(Result);
    Result := -1;
  end;
end;

function TPmxMotionCatalogStorage.IndexOfSourceVmdId(const Value: string): Integer;
begin
  for Result := 0 to FItems.Count - 1 do
    if SameText(FItems[Result].SourceVmdId, Trim(Value)) then Exit;
  Result := -1;
end;

function TPmxMotionCatalogStorage.HasMotionData(Index: Integer): Boolean;
begin
  Result := (Index >= 0) and (Index < FItems.Count) and
    TFile.Exists(DataFileName(FItems[Index].Id));
end;

function TPmxMotionCatalogStorage.LoadMotionData(Index: Integer;
  out MotionData: string): Boolean;
var
  Document: TMmdMotionDocument;
begin
  Result := False;
  MotionData := '';
  if (Index < 0) or (Index >= FItems.Count) then Exit;
  Document := nil;
  try
    if not LoadMmdMotionDocument(DataFileName(FItems[Index].Id), Document) then Exit;
    MotionData := EncodeMmdMotionDocument(Document);
    Result := MotionData <> '';
  finally
    Document.Free;
  end;
end;

function TPmxMotionCatalogStorage.Move(Index, Offset: Integer): Integer;
var
  NewIndex: Integer;
begin
  Result := -1;
  NewIndex := Index + Offset;
  if (Index < 0) or (Index >= FItems.Count) or (NewIndex < 0) or
    (NewIndex >= FItems.Count) then Exit;
  FItems.Exchange(Index, NewIndex);
  if SaveToFile then Result := NewIndex else FItems.Exchange(Index, NewIndex);
end;

function TPmxMotionCatalogStorage.Remove(Index: Integer): Boolean;
var
  DataFile, FileName: string;
  Item: TPmxMotionCatalogItem;
begin
  Result := False;
  if (Index < 0) or (Index >= FItems.Count) then Exit;
  FileName := ItemFileName(FItems[Index].Id);
  DataFile := DataFileName(FItems[Index].Id);
  Item := FItems.Extract(FItems[Index]);
  if not SaveToFile then begin FItems.Insert(Index, Item); Exit; end;
  Item.Free;
  try
    if TFile.Exists(FileName) then TFile.Delete(FileName);
    if TFile.Exists(DataFile) then TFile.Delete(DataFile);
  except
    { 索引から外れた孤立JSONは次回保存へ影響させない。 }
  end;
  Result := True;
end;

function TPmxMotionCatalogStorage.SaveMotionData(Index: Integer;
  const MotionData: string): Boolean;
var
  Document: TMmdMotionDocument;
begin
  Result := False;
  if (Index < 0) or (Index >= FItems.Count) then Exit;
  Document := nil;
  try
    if not TryDecodeMmdMotionDocument(MotionData, Document) then Exit;
    Result := SaveMmdMotionDocument(DataFileName(FItems[Index].Id), Document);
  finally
    Document.Free;
  end;
end;

function TPmxMotionCatalogStorage.Rename(Index: Integer;
  const Value: string): Boolean;
var
  NewName, OldName: string;
begin
  Result := False;
  NewName := Trim(Value);
  if (Index < 0) or (Index >= FItems.Count) or (NewName = '') then Exit;
  OldName := FItems[Index].Name;
  FItems[Index].Name := NewName;
  Result := SaveToFile;
  if not Result then FItems[Index].Name := OldName;
end;

function TPmxMotionCatalogStorage.SaveToFile: Boolean;
var
  I: Integer;
  Ids: TArray<string>;
begin
  Result := False;
  try
    if not ForceDirectories(FItemsFolder) then Exit;
    SetLength(Ids, FItems.Count);
    for I := 0 to FItems.Count - 1 do
    begin
      FItems[I].PmxId := FPmxId;
      FItems[I].PmxName := FPmxName;
      if not SavePmxMotionCatalogItem(ItemFileName(FItems[I].Id), FItems[I]) then Exit;
      Ids[I] := FItems[I].Id;
    end;
    Result := SavePmxMotionCatalogIndex(FIndexFileName, FPmxId, Ids);
  except
    Result := False;
  end;
end;

end.
