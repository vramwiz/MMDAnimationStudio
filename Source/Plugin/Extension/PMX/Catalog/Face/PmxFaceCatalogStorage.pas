unit PmxFaceCatalogStorage;

// 1つのPMXに属する表情をFaceUID別ファイルと順序索引で管理する。

interface

uses
  System.Generics.Collections,
  PmxFaceCatalogItem;

type
  TPmxFaceCatalogItem = PmxFaceCatalogItem.TPmxFaceCatalogItem;

  TPmxFaceCatalogStorage = class
  private
    FDefaultFaceId: string;
    FIndexFileName: string;
    FItems: TObjectList<TPmxFaceCatalogItem>;
    FItemsFolder: string;
    FPmxId: string;
    FPmxName: string;
    function CreateId: string;
    function GetCount: Integer;
    function GetItem(Index: Integer): TPmxFaceCatalogItem;
    function ItemFileName(const Id: string): string;
    function SaveItem(Item: TPmxFaceCatalogItem): Boolean;
  public
    // 指定モデルフォルダーにFaces保存領域を用意する。
    constructor Create(const ModelFolder: string; const APmxId: string = '';
      const APmxName: string = '');
    // 読み込んだFaceUID項目と保存先情報を解放する。
    destructor Destroy; override;
    // 保存データが0件なら、空表情の「初期状態」を必ず1件作成する。
    function LoadOrCreateDefault: Boolean;
    // 空表情を追加し、保存後の位置または-1を返す。
    function Add: Integer;
    // 指定表情を新しいFaceUIDで複製し、保存後の位置または-1を返す。
    function Duplicate(Index: Integer): Integer;
    // 指定位置が削除禁止の初期状態かを返す。
    function IsInitial(Index: Integer): Boolean;
    // 指定位置をOffset分だけ移動し、保存後の位置または-1を返す。
    function Move(Index, Offset: Integer): Integer;
    // 空でない名称へ変更し、保存まで完了した場合だけTrueを返す。
    function Rename(Index: Integer; const Value: string): Boolean;
    // 初期状態以外を一覧と個別JSONから削除する。
    function Remove(Index: Integer): Boolean;
    // 全項目と表示順を保存する。
    function SaveToFile: Boolean;
    // 現在読み込まれている表情数と、順序索引に対応する項目を公開する。
    property Count: Integer read GetCount;
    property Items[Index: Integer]: TPmxFaceCatalogItem read GetItem; default;
  end;

implementation

uses
  Winapi.Windows,
  System.IOUtils, System.SysUtils,
  MmdMorphSettingCodec,
  PmxFaceCatalogCodec;

const
  InitialFaceKind = 'initial';
  InitialFaceName = #$521D#$671F#$72B6#$614B;
  NewFaceKind = 'face';
  NewFaceName = #$65B0#$3057#$3044#$8868#$60C5;

constructor TPmxFaceCatalogStorage.Create(const ModelFolder, APmxId,
  APmxName: string);
var
  FacesFolder: string;
begin
  inherited Create;
  FacesFolder := TPath.Combine(ModelFolder, 'Faces');
  FIndexFileName := TPath.Combine(FacesFolder, 'Index.json');
  FItemsFolder := TPath.Combine(FacesFolder, 'Items');
  FPmxId := APmxId;
  FPmxName := APmxName;
  FItems := TObjectList<TPmxFaceCatalogItem>.Create(True);
end;

destructor TPmxFaceCatalogStorage.Destroy;
begin
  FItems.Free;
  inherited;
end;

function TPmxFaceCatalogStorage.CreateId: string;
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

function TPmxFaceCatalogStorage.GetCount: Integer;
begin
  Result := FItems.Count;
end;

function TPmxFaceCatalogStorage.GetItem(Index: Integer): TPmxFaceCatalogItem;
begin
  Result := FItems[Index];
end;

function TPmxFaceCatalogStorage.ItemFileName(const Id: string): string;
begin
  Result := TPath.Combine(FItemsFolder, Id + '.json');
end;

function TPmxFaceCatalogStorage.Add: Integer;
var
  Item: TPmxFaceCatalogItem;
begin
  Result := -1;
  Item := TPmxFaceCatalogItem.Create;
  Item.Id := CreateId;
  if Item.Id = '' then
  begin
    Item.Free;
    Exit;
  end;
  Item.Name := NewFaceName;
  Item.Kind := NewFaceKind;
  Item.PmxId := FPmxId;
  Item.PmxName := FPmxName;
  Item.FaceData := EmptyMmdMorphSettingData;
  Result := FItems.Add(Item);
  if not SaveToFile then
  begin
    FItems.Delete(Result);
    Result := -1;
  end;
end;

function TPmxFaceCatalogStorage.Duplicate(Index: Integer): Integer;
var
  Item, Source: TPmxFaceCatalogItem;
begin
  Result := -1;
  if (Index < 0) or (Index >= FItems.Count) then Exit;
  Source := FItems[Index];
  Item := TPmxFaceCatalogItem.Create;
  Item.Id := CreateId;
  if Item.Id = '' then
  begin
    Item.Free;
    Exit;
  end;
  Item.Name := Source.Name + '(Copy)';
  Item.Kind := NewFaceKind;
  Item.PmxId := FPmxId;
  Item.PmxName := FPmxName;
  Item.FaceData := Source.FaceData;
  Result := FItems.Add(Item);
  if not SaveToFile then
  begin
    FItems.Delete(Result);
    Result := -1;
  end;
end;

function TPmxFaceCatalogStorage.IsInitial(Index: Integer): Boolean;
begin
  Result := (Index >= 0) and (Index < FItems.Count) and
    (SameText(FItems[Index].Id, FDefaultFaceId) or
    SameText(FItems[Index].Kind, InitialFaceKind));
end;

function TPmxFaceCatalogStorage.LoadOrCreateDefault: Boolean;
var
  CatalogIndex: TPmxFaceCatalogIndex;
  DefaultFound: Boolean;
  Id: string;
  Index: Integer;
  Item: TPmxFaceCatalogItem;
begin
  Result := False;
  FItems.Clear;
  try
    if TFile.Exists(FIndexFileName) then
    begin
      if not LoadPmxFaceCatalogIndex(FIndexFileName, CatalogIndex) then Exit;
      if FPmxId = '' then FPmxId := CatalogIndex.PmxId;
      FDefaultFaceId := CatalogIndex.DefaultFaceId;
      for Id in CatalogIndex.FaceIds do
      begin
        Item := LoadPmxFaceCatalogItem(ItemFileName(Id), FPmxId, FPmxName);
        if Assigned(Item) then FItems.Add(Item);
      end;
    end;
    if FItems.Count = 0 then
    begin
      Item := TPmxFaceCatalogItem.Create;
      Item.Id := CreateId;
      if Item.Id = '' then
      begin
        Item.Free;
        Exit;
      end;
      Item.Name := InitialFaceName;
      Item.Kind := InitialFaceKind;
      Item.PmxId := FPmxId;
      Item.PmxName := FPmxName;
      Item.FaceData := EmptyMmdMorphSettingData;
      FItems.Add(Item);
      FDefaultFaceId := Item.Id;
      if not SaveToFile then Exit;
    end;
    DefaultFound := False;
    for Index := 0 to FItems.Count - 1 do
      if SameText(FItems[Index].Id, FDefaultFaceId) then
      begin
        DefaultFound := True;
        Break;
      end;
    if not DefaultFound then FDefaultFaceId := FItems[0].Id;
    for Index := 0 to FItems.Count - 1 do
    begin
      Item := FItems[Index];
      if Item.PmxId = '' then Item.PmxId := FPmxId;
      if Item.PmxName = '' then Item.PmxName := FPmxName;
      if SameText(Item.Id, FDefaultFaceId) then Item.Kind := InitialFaceKind
      else if Item.Kind = '' then Item.Kind := NewFaceKind;
      if Item.FaceData = '' then Item.FaceData := EmptyMmdMorphSettingData;
    end;
    Result := FItems.Count > 0;
  except
    FItems.Clear;
  end;
end;

function TPmxFaceCatalogStorage.Move(Index, Offset: Integer): Integer;
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

function TPmxFaceCatalogStorage.Remove(Index: Integer): Boolean;
var
  FileName: string;
  Item: TPmxFaceCatalogItem;
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
    { 索引から外れた孤立JSONの削除失敗は許容する。 }
  end;
  Result := True;
end;

function TPmxFaceCatalogStorage.Rename(Index: Integer;
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

function TPmxFaceCatalogStorage.SaveItem(Item: TPmxFaceCatalogItem): Boolean;
begin
  Result := SavePmxFaceCatalogItem(ItemFileName(Item.Id), Item);
end;

function TPmxFaceCatalogStorage.SaveToFile: Boolean;
var
  CatalogIndex: TPmxFaceCatalogIndex;
  Index: Integer;
begin
  Result := False;
  try
    if not ForceDirectories(FItemsFolder) then Exit;
    CatalogIndex.PmxId := FPmxId;
    CatalogIndex.DefaultFaceId := FDefaultFaceId;
    SetLength(CatalogIndex.FaceIds, FItems.Count);
    for Index := 0 to FItems.Count - 1 do
    begin
      FItems[Index].PmxId := FPmxId;
      FItems[Index].PmxName := FPmxName;
      if not SaveItem(FItems[Index]) then Exit;
      CatalogIndex.FaceIds[Index] := FItems[Index].Id;
    end;
    Result := SavePmxFaceCatalogIndex(FIndexFileName, CatalogIndex);
  except
    Result := False;
  end;
end;

end.

