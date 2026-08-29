unit PmxCatalogModelCodec;

// PmxUID別Model.jsonとTPmxCatalogItemの相互変換だけを担当する。

interface

uses
  PmxCatalogItem;

// Model.jsonを読み込み、必須値が揃った項目を返す。失敗時はnilを返す。
function LoadPmxCatalogModel(const FileName: string): TPmxCatalogItem;
// 項目をModel.jsonへUTF-8で保存する。保存完了時だけTrueを返す。
function SavePmxCatalogModel(const FileName: string;
  Item: TPmxCatalogItem): Boolean;

implementation

uses
  System.IOUtils,
  System.JSON,
  System.SysUtils;

const
  ModelFormatVersion = 1;

function JsonString(Value: TJSONValue; const Name: string): string;
var
  Pair: TJSONPair;
begin
  Result := '';
  if not (Value is TJSONObject) then Exit;
  Pair := TJSONObject(Value).Get(Name);
  if Assigned(Pair) and (Pair.JsonValue is TJSONString) then
    Result := TJSONString(Pair.JsonValue).Value;
end;

function LoadPmxCatalogModel(const FileName: string): TPmxCatalogItem;
var
  Json: TJSONValue;
begin
  Result := nil;
  try
    if not TFile.Exists(FileName) then Exit;
    Json := TJSONObject.ParseJSONValue(TFile.ReadAllText(
      FileName, TEncoding.UTF8));
    try
      if not (Json is TJSONObject) then Exit;
      Result := TPmxCatalogItem.Create;
      Result.Id := JsonString(Json, 'id');
      Result.SourcePath := JsonString(Json, 'sourcePath');
      Result.DisplayName := JsonString(Json, 'displayName');
      if (Result.Id = '') or (Result.SourcePath = '') then FreeAndNil(Result);
    finally
      Json.Free;
    end;
  except
    FreeAndNil(Result);
  end;
end;

function SavePmxCatalogModel(const FileName: string;
  Item: TPmxCatalogItem): Boolean;
var
  Json: TJSONObject;
begin
  Result := False;
  if not Assigned(Item) or (Item.Id = '') then Exit;
  try
    if not ForceDirectories(TPath.GetDirectoryName(FileName)) then Exit;
    Json := TJSONObject.Create;
    try
      Json.AddPair('formatVersion', TJSONNumber.Create(ModelFormatVersion));
      Json.AddPair('id', Item.Id);
      Json.AddPair('sourcePath', Item.SourcePath);
      Json.AddPair('displayName', Item.DisplayName);
      TFile.WriteAllText(FileName, Json.ToJSON, TEncoding.UTF8);
      Result := True;
    finally
      Json.Free;
    end;
  except
    Result := False;
  end;
end;

end.
