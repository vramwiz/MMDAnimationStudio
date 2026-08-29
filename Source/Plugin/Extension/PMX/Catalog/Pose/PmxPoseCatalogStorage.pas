unit PmxPoseCatalogStorage;

// 1つのPMXに属するポーズ要素をPoseUID別ファイルと順序索引で管理する。

interface

uses
  System.Generics.Collections,
  PmxPoseCatalogItem;

type
  // 既存の呼び出し側へ公開するポーズ項目型。実体はStorage配下で共有する。
  TPmxPoseCatalogItem = PmxPoseCatalogItem.TPmxPoseCatalogItem;

  TPmxPoseCatalogStorage = class
  private
    FIndexFileName: string;
    FItems: TObjectList<TPmxPoseCatalogItem>;
    FItemsFolder: string;
    FDefaultPoseId: string;
    FPmxId: string;
    FPmxName: string;
    function CreateId: string;
    function GetCount: Integer;
    function GetItem(Index: Integer): TPmxPoseCatalogItem;
    function ItemFileName(const Id: string): string;
    function LoadItem(const Id: string): TPmxPoseCatalogItem;
    function SaveItem(Item: TPmxPoseCatalogItem): Boolean;
  public
    // 指定モデルフォルダーに属するポーズ索引と個別データの保存先を初期化する。
    constructor Create(const ModelFolder: string; const APmxId: string = '';
      const APmxName: string = '');
    // 読み込んだポーズ項目を解放する。保存は自動実行しない。
    destructor Destroy; override;
    // 保存データが0件なら、空ポーズデータの「初期状態」を1件作成する。
    function LoadOrCreateDefault: Boolean;
    // 空姿勢を持つ通常ポーズを追加し、保存後の位置または-1を返す。
    function Add: Integer;
    // VPD由来の姿勢を追加し、保存後の位置または-1を返す。
    function AddImported(const Name, PoseData, SourceVpdId, SourceVpdName,
      SourceCategoryName: string; SaveNow: Boolean = True): Integer;
    // 指定ポーズを新しいPoseUIDで複製し、保存後の位置または-1を返す。
    function Duplicate(Index: Integer): Integer;
    // 指定位置が削除禁止の初期状態かを返す。
    function IsInitial(Index: Integer): Boolean;
    function IndexOfSourceVpdId(const Value: string): Integer;
    // 指定位置をOffset分だけ移動し、保存後の位置または-1を返す。
    function Move(Index, Offset: Integer): Integer;
    // 空でない名称へ変更し、JSON保存まで完了した場合だけTrueを返す。
    function Rename(Index: Integer; const Value: string): Boolean;
    // 初期状態以外を一覧と個別JSONから削除する。
    function Remove(Index: Integer): Boolean;
    // 全項目を個別JSONへ保存し、順序と初期状態IDを索引JSONへ書き出す。
    function SaveToFile: Boolean;
    property Count: Integer read GetCount;
    property Items[Index: Integer]: TPmxPoseCatalogItem read GetItem; default;
  end;

implementation

uses
  Winapi.Windows,
  System.IOUtils,
  System.SysUtils,
  MmdMorphSettingCodec,
  MmdEyeBlinkSettingCodec,
  MmdLipSyncSettingCodec,
  PmxPoseCatalogDataValidation,
  PmxPoseCatalogIndexCodec,
  PmxPoseCatalogItemCodec;

const
  InitialPoseName = #$521D#$671F#$72B6#$614B;
  InitialPoseKind = 'initial';
  NormalPoseKind = 'pose';
  NewPoseName = #$65B0#$3057#$3044#$30DD#$30FC#$30BA;

constructor TPmxPoseCatalogStorage.Create(const ModelFolder, APmxId,
  APmxName: string);
var
  PosesFolder: string;
begin
  inherited Create;
  PosesFolder := TPath.Combine(ModelFolder, 'Poses');
  FIndexFileName := TPath.Combine(PosesFolder, 'Index.json');
  FItemsFolder := TPath.Combine(PosesFolder, 'Items');
  FPmxId := APmxId;
  FPmxName := APmxName;
  FItems := TObjectList<TPmxPoseCatalogItem>.Create(True);
end;

destructor TPmxPoseCatalogStorage.Destroy;
begin
  FItems.Free;
  inherited;
end;

function TPmxPoseCatalogStorage.CreateId: string;
var
  Guid: TGUID;
begin
  Result := '';
  if CreateGUID(Guid) = S_OK then
  begin
    Result := LowerCase(GUIDToString(Guid));
    Result := StringReplace(Result, '{', '', [rfReplaceAll]);
    Result := StringReplace(Result, '}', '', [rfReplaceAll]);
    Result := StringReplace(Result, '-', '', [rfReplaceAll]);
  end;
end;

function TPmxPoseCatalogStorage.AddImported(const Name, PoseData,
  SourceVpdId, SourceVpdName, SourceCategoryName: string;
  SaveNow: Boolean): Integer;
var
  Item: TPmxPoseCatalogItem;
begin
  Result := -1;
  if (Trim(Name) = '') or (Trim(SourceVpdId) = '') or
    (IndexOfSourceVpdId(SourceVpdId) >= 0) then Exit;
  Item := TPmxPoseCatalogItem.Create;
  Item.Id := CreateId;
  if Item.Id = '' then
  begin
    Item.Free;
    Exit;
  end;
  Item.Name := Trim(Name);
  Item.Kind := NormalPoseKind;
  Item.PmxId := FPmxId;
  Item.PmxName := FPmxName;
  Item.PoseData := NormalizePoseData(PoseData);
  Item.SourceVpdId := Trim(SourceVpdId);
  Item.SourceVpdName := Trim(SourceVpdName);
  Item.SourceCategoryName := Trim(SourceCategoryName);
  Item.InitialEyeBlinkData := EmptyMmdEyeBlinkSettingData;
  Item.InitialExpressionData := EmptyMmdMorphSettingData;
  Item.InitialLipSyncData := EmptyMmdLipSyncSettingData;
  Result := FItems.Add(Item);
  if SaveNow and not SaveToFile then
  begin
    FItems.Delete(Result);
    Result := -1;
  end;
end;
function TPmxPoseCatalogStorage.GetCount: Integer;
begin
  Result := FItems.Count;
end;
function TPmxPoseCatalogStorage.GetItem(Index: Integer): TPmxPoseCatalogItem;
begin
  Result := FItems[Index];
end;
function TPmxPoseCatalogStorage.ItemFileName(const Id: string): string;
begin
  Result := TPath.Combine(FItemsFolder, Id + '.json');
end;

function TPmxPoseCatalogStorage.LoadItem(
  const Id: string): TPmxPoseCatalogItem;
begin
  Result := LoadPmxPoseCatalogItem(ItemFileName(Id), FPmxId, FPmxName);
end;

function TPmxPoseCatalogStorage.Add: Integer;
var
  Item: TPmxPoseCatalogItem;
begin
  Result := -1;
  Item := TPmxPoseCatalogItem.Create;
  Item.Id := CreateId;
  if Item.Id = '' then
  begin
    Item.Free;
    Exit;
  end;
  Item.Name := NewPoseName;
  Item.Kind := NormalPoseKind;
  Item.PmxId := FPmxId;
  Item.PmxName := FPmxName;
  Item.PoseData := EmptyPmxPoseData;
  Item.InitialEyeBlinkData := EmptyMmdEyeBlinkSettingData;
  Item.InitialExpressionData := EmptyMmdMorphSettingData;
  Item.InitialLipSyncData := EmptyMmdLipSyncSettingData;
  Result := FItems.Add(Item);
  if not SaveToFile then
  begin
    FItems.Delete(Result);
    Result := -1;
  end;
end;

function TPmxPoseCatalogStorage.Duplicate(Index: Integer): Integer;
var
  Item: TPmxPoseCatalogItem;
  Source: TPmxPoseCatalogItem;
begin
  Result := -1;
  if (Index < 0) or (Index >= FItems.Count) then Exit;
  Source := FItems[Index];
  Item := TPmxPoseCatalogItem.Create;
  Item.Id := CreateId;
  if Item.Id = '' then
  begin
    Item.Free;
    Exit;
  end;
  Item.Name := Source.Name + '(Copy)';
  Item.Kind := NormalPoseKind;
  Item.PmxId := FPmxId;
  Item.PmxName := FPmxName;
  Item.PoseData := Source.PoseData;
  Item.InitialEyeBlinkData := Source.InitialEyeBlinkData;
  Item.InitialExpressionData := Source.InitialExpressionData;
  Item.InitialLipSyncData := Source.InitialLipSyncData;
  Item.SourceVpdId := '';
  Item.SourceVpdName := '';
  Item.SourceCategoryName := '';
  Result := FItems.Add(Item);
  if not SaveToFile then
  begin
    FItems.Delete(Result);
    Result := -1;
  end;
end;

function TPmxPoseCatalogStorage.IsInitial(Index: Integer): Boolean;
begin
  Result := (Index >= 0) and (Index < FItems.Count) and
    (SameText(FItems[Index].Id, FDefaultPoseId) or
    SameText(FItems[Index].Kind, InitialPoseKind));
end;

function TPmxPoseCatalogStorage.IndexOfSourceVpdId(
  const Value: string): Integer;
begin
  for Result := 0 to FItems.Count - 1 do
    if SameText(FItems[Result].SourceVpdId, Trim(Value)) then Exit;
  Result := -1;
end;

function TPmxPoseCatalogStorage.Move(Index, Offset: Integer): Integer;
var
  NewIndex: Integer;
begin
  Result := -1;
  NewIndex := Index + Offset;
  if (Index < 0) or (Index >= FItems.Count) or (NewIndex < 0) or
    (NewIndex >= FItems.Count) then Exit;
  FItems.Exchange(Index, NewIndex);
  if SaveToFile then
    Result := NewIndex
  else
    FItems.Exchange(Index, NewIndex);
end;

function TPmxPoseCatalogStorage.Remove(Index: Integer): Boolean;
var
  FileName: string;
  Item: TPmxPoseCatalogItem;
begin
  Result := False;
  if (Index < 0) or (Index >= FItems.Count) or IsInitial(Index) then Exit;
  FileName := ItemFileName(FItems[Index].Id);
  Item := FItems.Extract(FItems[Index]);
  if not SaveToFile then
  begin
    FItems.Insert(Index, Item);
    Exit;
  end;
  Item.Free;
  try
    if TFile.Exists(FileName) then TFile.Delete(FileName);
  except
    { 索引からの削除は完了済みなので、孤立JSONの削除失敗は許容する。 }
  end;
  Result := True;
end;

function TPmxPoseCatalogStorage.Rename(Index: Integer;
  const Value: string): Boolean;
var
  NewName: string;
  OldName: string;
begin
  Result := False;
  NewName := Trim(Value);
  if (Index < 0) or (Index >= FItems.Count) or (NewName = '') then Exit;
  OldName := FItems[Index].Name;
  FItems[Index].Name := NewName;
  Result := SaveToFile;
  if not Result then FItems[Index].Name := OldName;
end;

function TPmxPoseCatalogStorage.LoadOrCreateDefault: Boolean;
var
  CatalogIndex: TPmxPoseCatalogIndex;
  Id: string;
  Index: Integer;
  Item: TPmxPoseCatalogItem;
  DefaultFound: Boolean;
begin
  Result := False;
  FItems.Clear;
  try
    if TFile.Exists(FIndexFileName) then
    begin
      if not LoadPmxPoseCatalogIndex(FIndexFileName, CatalogIndex) then Exit;
      if FPmxId = '' then FPmxId := CatalogIndex.PmxId;
      FDefaultPoseId := CatalogIndex.DefaultPoseId;
      for Id in CatalogIndex.PoseIds do
      begin
        Item := LoadItem(Id);
        if Assigned(Item) then FItems.Add(Item);
      end;
    end;

    if FItems.Count = 0 then
    begin
      Item := TPmxPoseCatalogItem.Create;
      Item.Id := CreateId;
      if Item.Id = '' then
      begin
        Item.Free;
        Exit(False);
      end;
      Item.Name := InitialPoseName;
      Item.Kind := InitialPoseKind;
      Item.PmxId := FPmxId;
      Item.PmxName := FPmxName;
      Item.PoseData := EmptyPmxPoseData;
      Item.InitialEyeBlinkData := EmptyMmdEyeBlinkSettingData;
      Item.InitialExpressionData := EmptyMmdMorphSettingData;
      Item.InitialLipSyncData := EmptyMmdLipSyncSettingData;
      FItems.Add(Item);
      FDefaultPoseId := Item.Id;
      SaveToFile;
    end;
    DefaultFound := False;
    for Index := 0 to FItems.Count - 1 do
      if SameText(FItems[Index].Id, FDefaultPoseId) then
      begin
        DefaultFound := True;
        Break;
      end;
    if not DefaultFound then
      FDefaultPoseId := FItems[0].Id;
    for Index := 0 to FItems.Count - 1 do
    begin
      Item := FItems[Index];
      if Item.PmxId = '' then Item.PmxId := FPmxId;
      if Item.PmxName = '' then Item.PmxName := FPmxName;
      if SameText(Item.Id, FDefaultPoseId) then
        Item.Kind := InitialPoseKind
      else if Item.Kind = '' then
        Item.Kind := NormalPoseKind;
    end;
    Result := FItems.Count > 0;
  except
    FItems.Clear;
  end;
end;

function TPmxPoseCatalogStorage.SaveItem(
  Item: TPmxPoseCatalogItem): Boolean;
begin
  Result := SavePmxPoseCatalogItem(ItemFileName(Item.Id), Item);
end;

function TPmxPoseCatalogStorage.SaveToFile: Boolean;
var
  CatalogIndex: TPmxPoseCatalogIndex;
  Index: Integer;
  Item: TPmxPoseCatalogItem;
begin
  Result := False;
  try
    if not ForceDirectories(FItemsFolder) then
      Exit;
    CatalogIndex.PmxId := FPmxId;
    CatalogIndex.DefaultPoseId := FDefaultPoseId;
    SetLength(CatalogIndex.PoseIds, FItems.Count);
    for Index := 0 to FItems.Count - 1 do
    begin
      Item := FItems[Index];
      Item.PmxId := FPmxId;
      Item.PmxName := FPmxName;
      if not SaveItem(Item) then Exit;
      CatalogIndex.PoseIds[Index] := Item.Id;
    end;
    Result := SavePmxPoseCatalogIndex(FIndexFileName, CatalogIndex);
  except
    Result := False;
  end;
end;

end.
