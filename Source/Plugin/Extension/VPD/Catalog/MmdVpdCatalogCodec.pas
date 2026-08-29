unit MmdVpdCatalogCodec;

// VPDライブラリの索引JSONとVpdUID別JSONの読み書きを担当する。

interface

uses
  MmdVpdCatalogItem;

// 索引JSONを検証して、保存順を維持したVpdUID配列を返す。
function LoadMmdVpdCatalogIndex(const FileName: string;
  out Ids: TArray<string>): Boolean;
// VpdUID配列を版付き索引JSONとして置換保存する。
function SaveMmdVpdCatalogIndex(const FileName: string;
  const Ids: TArray<string>): Boolean;
// VpdUID別JSONを読み、破損時はnilを返す。
function LoadMmdVpdCatalogItem(const FileName: string): TMmdVpdCatalogItem;
// VPD原本の識別情報と分類をVpdUID別JSONへ置換保存する。
function SaveMmdVpdCatalogItem(const FileName: string;
  Item: TMmdVpdCatalogItem): Boolean;

implementation

uses
  System.Classes, System.Generics.Collections, System.IOUtils, System.JSON,
  System.SysUtils;

const
  VpdCatalogFormatVersion = 1;

function JsonString(Json: TJSONValue; const Name: string): string;
var
  Value: TJSONValue;
begin
  Result := '';
  if not (Json is TJSONObject) then Exit;
  Value := TJSONObject(Json).GetValue(Name);
  if Value is TJSONString then Result := TJSONString(Value).Value;
end;

function LoadMmdVpdCatalogIndex(const FileName: string;
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
      Array_ := TJSONObject(Root).GetValue<TJSONArray>('vpdIds');
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

function SaveMmdVpdCatalogIndex(const FileName: string;
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
      Root.AddPair('formatVersion', TJSONNumber.Create(VpdCatalogFormatVersion));
      Array_ := TJSONArray.Create;
      Root.AddPair('vpdIds', Array_);
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

function LoadMmdVpdCatalogItem(
  const FileName: string): TMmdVpdCatalogItem;
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
      Result := TMmdVpdCatalogItem.Create;
      Result.Id := JsonString(Root, 'vpdId');
      Result.Name := JsonString(Root, 'name');
      Result.CategoryName := JsonString(Root, 'categoryName');
      Result.OriginalFileName := JsonString(Root, 'originalFileName');
      Result.OriginalPath := JsonString(Root, 'originalPath');
      Result.ContentHash := JsonString(Root, 'contentHash');
      Result.ImportedAt := JsonString(Root, 'importedAt');
      if (Result.Id = '') or (Result.Name = '') or
        (Result.ContentHash = '') then FreeAndNil(Result);
    finally
      Root.Free;
    end;
  except
    FreeAndNil(Result);
  end;
end;

function SaveMmdVpdCatalogItem(const FileName: string;
  Item: TMmdVpdCatalogItem): Boolean;
var
  Root: TJSONObject;
begin
  Result := False;
  if not Assigned(Item) or (Item.Id = '') then Exit;
  try
    if not ForceDirectories(TPath.GetDirectoryName(FileName)) then Exit;
    Root := TJSONObject.Create;
    try
      Root.AddPair('formatVersion', TJSONNumber.Create(VpdCatalogFormatVersion));
      Root.AddPair('vpdId', Item.Id);
      Root.AddPair('name', Item.Name);
      Root.AddPair('categoryName', Item.CategoryName);
      Root.AddPair('originalFileName', Item.OriginalFileName);
      Root.AddPair('originalPath', Item.OriginalPath);
      Root.AddPair('contentHash', Item.ContentHash);
      Root.AddPair('importedAt', Item.ImportedAt);
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
