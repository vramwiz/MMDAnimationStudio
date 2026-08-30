unit MmdVmdCatalogCodec;

// VMD共通ライブラリの索引とVmdUID別メタデータJSONを読み書きする。

interface

uses
  MmdVmdCatalogItem;

// 共通VMD索引を読み込む。未作成は空一覧として成功する。
function LoadMmdVmdCatalogIndex(const FileName: string;
  out Ids: TArray<string>): Boolean;
// 共通VMDの表示順をUTF-8 JSONへ保存する。
function SaveMmdVmdCatalogIndex(const FileName: string;
  const Ids: TArray<string>): Boolean;
// VmdUID別メタデータを読み込み、不正時はnilを返す。
function LoadMmdVmdCatalogItem(const FileName: string): TMmdVmdCatalogItem;
// VmdUID別メタデータをUTF-8 JSONへ保存する。
function SaveMmdVmdCatalogItem(const FileName: string;
  Item: TMmdVmdCatalogItem): Boolean;

implementation

uses
  System.Generics.Collections,
  System.IOUtils,
  System.JSON,
  System.SysUtils;

const
  VmdCatalogFormatVersion = 1;

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

function LoadMmdVmdCatalogIndex(const FileName: string;
  out Ids: TArray<string>): Boolean;
var
  Array_: TJSONArray;
  I: Integer;
  Root: TJSONValue;
begin
  Result := False;
  Ids := nil;
  try
    if not TFile.Exists(FileName) then Exit(True);
    Root := TJSONObject.ParseJSONValue(TFile.ReadAllText(FileName,
      TEncoding.UTF8));
    try
      if not (Root is TJSONObject) then Exit;
      Array_ := TJSONObject(Root).GetValue<TJSONArray>('vmdIds');
      if not Assigned(Array_) then Exit;
      SetLength(Ids, Array_.Count);
      for I := 0 to Array_.Count - 1 do
      begin
        if not (Array_.Items[I] is TJSONString) then Exit;
        Ids[I] := TJSONString(Array_.Items[I]).Value;
        if Ids[I] = '' then Exit;
      end;
      Result := True;
    finally
      Root.Free;
    end;
  except
    Ids := nil;
  end;
end;

function SaveMmdVmdCatalogIndex(const FileName: string;
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
      Root.AddPair('formatVersion', TJSONNumber.Create(VmdCatalogFormatVersion));
      Array_ := TJSONArray.Create;
      Root.AddPair('vmdIds', Array_);
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

function LoadMmdVmdCatalogItem(const FileName: string): TMmdVmdCatalogItem;
var
  Root: TJSONValue;
begin
  Result := nil;
  try
    if not TFile.Exists(FileName) then Exit;
    Root := TJSONObject.ParseJSONValue(TFile.ReadAllText(FileName,
      TEncoding.UTF8));
    try
      if not (Root is TJSONObject) then Exit;
      Result := TMmdVmdCatalogItem.Create;
      Result.Id := JsonString(Root, 'vmdId');
      Result.Name := JsonString(Root, 'name');
      Result.CategoryName := JsonString(Root, 'categoryName');
      Result.OriginalFileName := JsonString(Root, 'originalFileName');
      Result.OriginalPath := JsonString(Root, 'originalPath');
      Result.ContentHash := JsonString(Root, 'contentHash');
      Result.ImportedAt := JsonString(Root, 'importedAt');
      Result.ModelName := JsonString(Root, 'modelName');
      if (Result.Id = '') or (Result.Name = '') or
        (Result.ContentHash = '') then FreeAndNil(Result);
    finally
      Root.Free;
    end;
  except
    FreeAndNil(Result);
  end;
end;

function SaveMmdVmdCatalogItem(const FileName: string;
  Item: TMmdVmdCatalogItem): Boolean;
var
  Root: TJSONObject;
begin
  Result := False;
  if not Assigned(Item) or (Item.Id = '') then Exit;
  try
    if not ForceDirectories(TPath.GetDirectoryName(FileName)) then Exit;
    Root := TJSONObject.Create;
    try
      Root.AddPair('formatVersion', TJSONNumber.Create(VmdCatalogFormatVersion));
      Root.AddPair('vmdId', Item.Id);
      Root.AddPair('name', Item.Name);
      Root.AddPair('categoryName', Item.CategoryName);
      Root.AddPair('originalFileName', Item.OriginalFileName);
      Root.AddPair('originalPath', Item.OriginalPath);
      Root.AddPair('contentHash', Item.ContentHash);
      Root.AddPair('importedAt', Item.ImportedAt);
      Root.AddPair('modelName', Item.ModelName);
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
