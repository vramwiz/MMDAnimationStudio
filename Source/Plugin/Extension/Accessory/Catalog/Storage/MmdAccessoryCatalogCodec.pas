unit MmdAccessoryCatalogCodec;

// アクセサリの原本メタデータ、一覧項目、両UID索引を版付きJSONへ保存する。

interface

uses
  MmdAccessoryCatalogItem;

// 表示順のAccessoryUID索引を読み込み、版や構造が不正ならFalseを返す。
function LoadMmdAccessoryCatalogIndex(const FileName: string;
  out Ids: TArray<string>): Boolean;
// 表示順のAccessoryUID索引を版付きJSONとして置換保存する。
function SaveMmdAccessoryCatalogIndex(const FileName: string;
  const Ids: TArray<string>): Boolean;
// 共有原本のSourceUID索引を読み込み、版や構造が不正ならFalseを返す。
function LoadMmdAccessorySourceIndex(const FileName: string;
  out Ids: TArray<string>): Boolean;
// 共有原本のSourceUID索引を版付きJSONとして置換保存する。
function SaveMmdAccessorySourceIndex(const FileName: string;
  const Ids: TArray<string>): Boolean;
// 個別アクセサリJSONを読み込み、不正または欠落時はnilを返す。
function LoadMmdAccessoryCatalogItem(const FileName: string):
  TMmdAccessoryCatalogItem;
// 個別アクセサリJSONを版付き形式で置換保存する。
function SaveMmdAccessoryCatalogItem(const FileName: string;
  Item: TMmdAccessoryCatalogItem): Boolean;
// 共有原本メタデータJSONを読み込み、不正または欠落時はnilを返す。
function LoadMmdAccessorySourceItem(const FileName: string):
  TMmdAccessorySourceItem;
// 共有原本メタデータJSONを版付き形式で置換保存する。
function SaveMmdAccessorySourceItem(const FileName: string;
  Item: TMmdAccessorySourceItem): Boolean;

implementation

uses
  System.Generics.Collections,
  System.IOUtils,
  System.JSON,
  System.SysUtils;

const
  AccessoryCatalogFormatVersion = 1;

function JsonString(Value: TJSONValue; const Name: string): string;
var
  Item: TJSONValue;
begin
  Result := '';
  if Value is TJSONObject then
  begin
    Item := TJSONObject(Value).GetValue(Name);
    if Item is TJSONString then Result := TJSONString(Item).Value;
  end;
end;

function JsonInteger(Value: TJSONValue; const Name: string;
  DefaultValue: Integer): Integer;
var
  Item: TJSONValue;
begin
  Result := DefaultValue;
  if Value is TJSONObject then
  begin
    Item := TJSONObject(Value).GetValue(Name);
    if Item is TJSONNumber then
      Result := StrToIntDef(TJSONNumber(Item).Value, DefaultValue);
  end;
end;

function JsonBoolean(Value: TJSONValue; const Name: string): Boolean;
var
  Item: TJSONValue;
begin
  Result := False;
  if Value is TJSONObject then
  begin
    Item := TJSONObject(Value).GetValue(Name);
    if Assigned(Item) then Result := SameText(Item.Value, 'true');
  end;
end;

function ValidVersion(Value: TJSONValue): Boolean;
var
  Item: TJSONValue;
begin
  Result := False;
  if not (Value is TJSONObject) then Exit;
  Item := TJSONObject(Value).GetValue('formatVersion');
  Result := (Item is TJSONNumber) and
    (StrToIntDef(TJSONNumber(Item).Value, -1) = AccessoryCatalogFormatVersion);
end;

function LoadIds(const FileName, ArrayName: string;
  out Ids: TArray<string>): Boolean;
var
  Array_: TJSONArray;
  I: Integer;
  Known: TDictionary<string, Byte>;
  Root: TJSONValue;
begin
  Result := False;
  Ids := nil;
  try
    if not TFile.Exists(FileName) then Exit(True);
    Root := TJSONObject.ParseJSONValue(TFile.ReadAllText(FileName,
      TEncoding.UTF8));
    try
      if not ValidVersion(Root) then Exit;
      Array_ := TJSONObject(Root).GetValue<TJSONArray>(ArrayName);
      if not Assigned(Array_) then Exit;
      Known := TDictionary<string, Byte>.Create;
      try
        SetLength(Ids, Array_.Count);
        for I := 0 to Array_.Count - 1 do
        begin
          if not (Array_.Items[I] is TJSONString) then Exit;
          Ids[I] := TJSONString(Array_.Items[I]).Value;
          if (Ids[I] = '') or Known.ContainsKey(LowerCase(Ids[I])) then Exit;
          Known.Add(LowerCase(Ids[I]), 0);
        end;
        Result := True;
      finally
        Known.Free;
      end;
    finally
      Root.Free;
    end;
  except
    Ids := nil;
  end;
end;

function SaveIds(const FileName, ArrayName: string;
  const Ids: TArray<string>): Boolean;
var
  Array_: TJSONArray;
  Id: string;
  Root: TJSONObject;
begin
  Result := False;
  try
    if not ForceDirectories(TPath.GetDirectoryName(FileName)) then Exit;
    Root := TJSONObject.Create;
    try
      Root.AddPair('formatVersion',
        TJSONNumber.Create(AccessoryCatalogFormatVersion));
      Array_ := TJSONArray.Create;
      Root.AddPair(ArrayName, Array_);
      for Id in Ids do Array_.Add(Id);
      TFile.WriteAllText(FileName, Root.ToJSON, TEncoding.UTF8);
      Result := True;
    finally
      Root.Free;
    end;
  except
    Result := False;
  end;
end;

function LoadMmdAccessoryCatalogIndex(const FileName: string;
  out Ids: TArray<string>): Boolean;
begin
  Result := LoadIds(FileName, 'accessoryIds', Ids);
end;

function SaveMmdAccessoryCatalogIndex(const FileName: string;
  const Ids: TArray<string>): Boolean;
begin
  Result := SaveIds(FileName, 'accessoryIds', Ids);
end;

function LoadMmdAccessorySourceIndex(const FileName: string;
  out Ids: TArray<string>): Boolean;
begin
  Result := LoadIds(FileName, 'sourceIds', Ids);
end;

function SaveMmdAccessorySourceIndex(const FileName: string;
  const Ids: TArray<string>): Boolean;
begin
  Result := SaveIds(FileName, 'sourceIds', Ids);
end;

function LoadMmdAccessoryCatalogItem(const FileName: string):
  TMmdAccessoryCatalogItem;
var
  Root: TJSONValue;
begin
  Result := nil;
  try
    if not TFile.Exists(FileName) then Exit;
    Root := TJSONObject.ParseJSONValue(TFile.ReadAllText(FileName,
      TEncoding.UTF8));
    try
      if not ValidVersion(Root) then Exit;
      Result := TMmdAccessoryCatalogItem.Create;
      Result.Id := JsonString(Root, 'accessoryId');
      Result.SourceId := JsonString(Root, 'sourceId');
      Result.Name := JsonString(Root, 'name');
      Result.CategoryName := JsonString(Root, 'categoryName');
      if (Result.Id = '') or (Result.SourceId = '') or
        (Result.Name = '') then FreeAndNil(Result);
    finally
      Root.Free;
    end;
  except
    FreeAndNil(Result);
  end;
end;

function SaveMmdAccessoryCatalogItem(const FileName: string;
  Item: TMmdAccessoryCatalogItem): Boolean;
var
  Root: TJSONObject;
begin
  Result := False;
  if not Assigned(Item) or (Item.Id = '') or (Item.SourceId = '') then Exit;
  try
    if not ForceDirectories(TPath.GetDirectoryName(FileName)) then Exit;
    Root := TJSONObject.Create;
    try
      Root.AddPair('formatVersion',
        TJSONNumber.Create(AccessoryCatalogFormatVersion));
      Root.AddPair('accessoryId', Item.Id);
      Root.AddPair('sourceId', Item.SourceId);
      Root.AddPair('name', Item.Name);
      Root.AddPair('categoryName', Item.CategoryName);
      TFile.WriteAllText(FileName, Root.ToJSON, TEncoding.UTF8);
      Result := True;
    finally
      Root.Free;
    end;
  except
    Result := False;
  end;
end;

function LoadMmdAccessorySourceItem(const FileName: string):
  TMmdAccessorySourceItem;
var
  Format: TMmdAccessorySourceFormat;
  Root: TJSONValue;
begin
  Result := nil;
  try
    if not TFile.Exists(FileName) then Exit;
    Root := TJSONObject.ParseJSONValue(TFile.ReadAllText(FileName,
      TEncoding.UTF8));
    try
      if not ValidVersion(Root) or
        not TryMmdAccessorySourceFormat(JsonString(Root, 'format'),
          Format) then Exit;
      Result := TMmdAccessorySourceItem.Create;
      Result.Id := JsonString(Root, 'sourceId');
      Result.Format := Format;
      Result.OriginalFileName := JsonString(Root, 'originalFileName');
      Result.OriginalPath := JsonString(Root, 'originalPath');
      Result.ContentHash := JsonString(Root, 'contentHash');
      Result.ImportedAt := JsonString(Root, 'importedAt');
      Result.Validated := JsonBoolean(Root, 'validated');
      Result.VertexCount := JsonInteger(Root, 'vertexCount', -1);
      Result.MaterialCount := JsonInteger(Root, 'materialCount', -1);
      Result.BoneCount := JsonInteger(Root, 'boneCount', -1);
      if (Result.Id = '') or (Result.OriginalFileName = '') or
        (Result.OriginalFileName <> TPath.GetFileName(
          Result.OriginalFileName)) or (Result.ContentHash = '') then
        FreeAndNil(Result);
    finally
      Root.Free;
    end;
  except
    FreeAndNil(Result);
  end;
end;

function SaveMmdAccessorySourceItem(const FileName: string;
  Item: TMmdAccessorySourceItem): Boolean;
var
  Root: TJSONObject;
begin
  Result := False;
  if not Assigned(Item) or (Item.Id = '') then Exit;
  try
    if not ForceDirectories(TPath.GetDirectoryName(FileName)) then Exit;
    Root := TJSONObject.Create;
    try
      Root.AddPair('formatVersion',
        TJSONNumber.Create(AccessoryCatalogFormatVersion));
      Root.AddPair('sourceId', Item.Id);
      Root.AddPair('format', MmdAccessorySourceFormatName(Item.Format));
      Root.AddPair('originalFileName', Item.OriginalFileName);
      Root.AddPair('originalPath', Item.OriginalPath);
      Root.AddPair('contentHash', Item.ContentHash);
      Root.AddPair('importedAt', Item.ImportedAt);
      Root.AddPair('validated', TJSONBool.Create(Item.Validated));
      Root.AddPair('vertexCount', TJSONNumber.Create(Item.VertexCount));
      Root.AddPair('materialCount', TJSONNumber.Create(Item.MaterialCount));
      Root.AddPair('boneCount', TJSONNumber.Create(Item.BoneCount));
      TFile.WriteAllText(FileName, Root.ToJSON, TEncoding.UTF8);
      Result := True;
    finally
      Root.Free;
    end;
  except
    Result := False;
  end;
end;

end.
