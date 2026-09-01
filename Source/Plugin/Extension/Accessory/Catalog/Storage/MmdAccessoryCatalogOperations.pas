unit MmdAccessoryCatalogOperations;

// AccessoryUID一覧の複製、削除、順序、名称をJSONと同期する。

interface

uses
  System.Generics.Collections,
  MmdAccessoryCatalogItem;

type
  TMmdAccessoryCatalogOperations = class
  private
    FIndexFileName: string;
    FItems: TObjectList<TMmdAccessoryCatalogItem>;
    FItemsFolder: string;
    function CreateId: string;
    function ItemFileName(const Id: string): string;
  public
    // 非所有の項目一覧と保存先を受け取り、一覧変更の永続化境界を作る。
    constructor Create(AItems: TObjectList<TMmdAccessoryCatalogItem>;
      const AIndexFileName, AItemsFolder: string);
    // Index項目を別UIDとして末尾へ複製し、保存後の位置を返す。
    function Duplicate(Index: Integer): Integer;
    // Index項目をOffset分移動し、保存後の位置を返す。
    function Move(Index, Offset: Integer): Integer;
    // Index項目の個別JSONと索引参照を削除する。原本は削除しない。
    function Remove(Index: Integer): Boolean;
    // Index項目へ空でない表示名を設定し、個別JSONへ保存する。
    function Rename(Index: Integer; const Value: string): Boolean;
    // 現在の項目順を一覧索引JSONへ保存する。
    function SaveIndex: Boolean;
  end;

implementation

uses
  Winapi.Windows,
  System.IOUtils,
  System.SysUtils,
  MmdAccessoryCatalogCodec;

constructor TMmdAccessoryCatalogOperations.Create(
  AItems: TObjectList<TMmdAccessoryCatalogItem>;
  const AIndexFileName, AItemsFolder: string);
begin
  inherited Create;
  FItems := AItems;
  FIndexFileName := AIndexFileName;
  FItemsFolder := AItemsFolder;
end;

function TMmdAccessoryCatalogOperations.CreateId: string;
var
  Guid: TGUID;
begin
  Result := '';
  if CreateGUID(Guid) <> S_OK then Exit;
  Result := LowerCase(GUIDToString(Guid)).Replace('{', '').Replace('}', '')
    .Replace('-', '');
end;

function TMmdAccessoryCatalogOperations.Duplicate(Index: Integer): Integer;
var
  FileName: string;
  Item, Source: TMmdAccessoryCatalogItem;
begin
  Result := -1;
  if not Assigned(FItems) or (Index < 0) or (Index >= FItems.Count) then Exit;
  Source := FItems[Index];
  Item := TMmdAccessoryCatalogItem.Create;
  try
    Item.Id := CreateId;
    if Item.Id = '' then Exit;
    Item.SourceId := Source.SourceId;
    Item.Name := Source.Name + ' (コピー)';
    Item.CategoryName := Source.CategoryName;
    Result := FItems.Add(Item);
    Item := nil;
    FileName := ItemFileName(FItems[Result].Id);
    if not SaveMmdAccessoryCatalogItem(FileName, FItems[Result]) or
      not SaveIndex then
    begin
      FItems.Delete(Result);
      Result := -1;
      try
        if TFile.Exists(FileName) then TFile.Delete(FileName);
      except
        { 索引から参照されない孤立JSONは読込で無視する。 }
      end;
    end;
  except
    if Result >= 0 then FItems.Delete(Result);
    Result := -1;
  end;
  Item.Free;
end;

function TMmdAccessoryCatalogOperations.ItemFileName(
  const Id: string): string;
begin
  Result := TPath.Combine(FItemsFolder, Id + '.json');
end;

function TMmdAccessoryCatalogOperations.Move(Index, Offset: Integer): Integer;
var
  NewIndex: Integer;
begin
  Result := -1;
  NewIndex := Index + Offset;
  if not Assigned(FItems) or (Index < 0) or (Index >= FItems.Count) or
    (NewIndex < 0) or (NewIndex >= FItems.Count) then Exit;
  FItems.Exchange(Index, NewIndex);
  if SaveIndex then Result := NewIndex
  else FItems.Exchange(Index, NewIndex);
end;

function TMmdAccessoryCatalogOperations.Remove(Index: Integer): Boolean;
var
  FileName: string;
  Item: TMmdAccessoryCatalogItem;
begin
  Result := False;
  if not Assigned(FItems) or (Index < 0) or (Index >= FItems.Count) then Exit;
  FileName := ItemFileName(FItems[Index].Id);
  Item := FItems.Extract(FItems[Index]);
  if not SaveIndex then
  begin
    FItems.Insert(Index, Item);
    Exit;
  end;
  Item.Free;
  try
    if TFile.Exists(FileName) then TFile.Delete(FileName);
  except
    { 索引から外れた孤立JSONは次回読込で採用しない。 }
  end;
  Result := True;
end;

function TMmdAccessoryCatalogOperations.Rename(Index: Integer;
  const Value: string): Boolean;
var
  NewName, OldName: string;
begin
  Result := False;
  NewName := Trim(Value);
  if not Assigned(FItems) or (Index < 0) or (Index >= FItems.Count) or
    (NewName = '') then Exit;
  OldName := FItems[Index].Name;
  FItems[Index].Name := NewName;
  Result := SaveMmdAccessoryCatalogItem(
    ItemFileName(FItems[Index].Id), FItems[Index]);
  if not Result then FItems[Index].Name := OldName;
end;

function TMmdAccessoryCatalogOperations.SaveIndex: Boolean;
var
  I: Integer;
  Ids: TArray<string>;
begin
  SetLength(Ids, FItems.Count);
  for I := 0 to FItems.Count - 1 do Ids[I] := FItems[I].Id;
  Result := SaveMmdAccessoryCatalogIndex(FIndexFileName, Ids);
end;

end.
