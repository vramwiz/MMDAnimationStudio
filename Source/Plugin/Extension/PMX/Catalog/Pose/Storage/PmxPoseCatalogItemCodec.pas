unit PmxPoseCatalogItemCodec;

// PoseUID別JSONとポーズ項目の相互変換だけを担当する。

interface

uses
  PmxPoseCatalogItem;

const
  PmxPoseCatalogFormatVersion = PmxPoseCatalogItem.PmxPoseCatalogFormatVersion;

// PoseUID別JSONを読み込み、値を正規化した項目を返す。失敗時はnilを返す。
function LoadPmxPoseCatalogItem(const FileName, PmxId,
  PmxName: string): TPmxPoseCatalogItem;
// ポーズ項目をPoseUID別JSONへUTF-8で保存する。
function SavePmxPoseCatalogItem(const FileName: string;
  Item: TPmxPoseCatalogItem): Boolean;

implementation

uses
  System.Classes,
  System.IOUtils,
  System.JSON,
  System.SysUtils,
  MmdMorphSettingCodec,
  MmdEyeBlinkSettingCodec,
  MmdLipSyncSettingCodec,
  PmxPoseCatalogDataValidation;

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

function JsonData(Value: TJSONValue; const Name: string): string;
var
  Data: TJSONValue;
begin
  Result := '';
  if not (Value is TJSONObject) then Exit;
  Data := TJSONObject(Value).GetValue(Name);
  if Data is TJSONString then
    Result := TJSONString(Data).Value
  else if Assigned(Data) then
    Result := Data.ToJSON;
end;

function LoadPmxPoseCatalogItem(const FileName, PmxId,
  PmxName: string): TPmxPoseCatalogItem;
var
  Json: TJSONValue;
begin
  Result := nil;
  try
    if not TFile.Exists(FileName) then Exit;
    Json := TJSONObject.ParseJSONValue(TFile.ReadAllText(FileName,
      TEncoding.UTF8));
    try
      if not (Json is TJSONObject) then Exit;
      Result := TPmxPoseCatalogItem.Create;
      Result.Id := JsonString(Json, 'poseId');
      if Result.Id = '' then Result.Id := JsonString(Json, 'id');
      Result.PmxId := JsonString(Json, 'pmxId');
      if Result.PmxId = '' then Result.PmxId := PmxId;
      Result.PmxName := JsonString(Json, 'pmxName');
      if Result.PmxName = '' then Result.PmxName := PmxName;
      Result.Name := JsonString(Json, 'name');
      Result.Kind := JsonString(Json, 'kind');
      Result.SourceVpdId := JsonString(Json, 'sourceVpdId');
      Result.SourceVpdName := JsonString(Json, 'sourceVpdName');
      Result.SourceCategoryName := JsonString(Json, 'sourceCategoryName');
      Result.InitialEyeBlinkData := NormalizeInitialEyeBlinkData(
        JsonData(Json, 'initialEyeBlinkData'));
      Result.InitialLipSyncData := NormalizeInitialLipSyncData(
        JsonData(Json, 'initialLipSyncData'));
      Result.InitialExpressionData := NormalizeInitialExpressionData(
        JsonData(Json, 'initialExpressionData'));
      Result.PoseData := NormalizePoseData(JsonData(Json, 'poseData'));
      if Result.Id = '' then FreeAndNil(Result);
    finally
      Json.Free;
    end;
  except
    FreeAndNil(Result);
  end;
end;

function ObjectData(const Data, DefaultData: string): TJSONValue;
begin
  Result := TJSONObject.ParseJSONValue(Data);
  if Result is TJSONObject then Exit;
  Result.Free;
  Result := TJSONObject.ParseJSONValue(DefaultData);
end;

function SavePmxPoseCatalogItem(const FileName: string;
  Item: TPmxPoseCatalogItem): Boolean;
var
  Json: TJSONObject;
begin
  Result := False;
  if not Assigned(Item) or (Item.Id = '') then Exit;
  try
    if not ForceDirectories(TPath.GetDirectoryName(FileName)) then Exit;
    Json := TJSONObject.Create;
    try
      Json.AddPair('formatVersion',
        TJSONNumber.Create(PmxPoseCatalogFormatVersion));
      Json.AddPair('poseId', Item.Id);
      Json.AddPair('pmxId', Item.PmxId);
      Json.AddPair('pmxName', Item.PmxName);
      Json.AddPair('name', Item.Name);
      Json.AddPair('kind', Item.Kind);
      Json.AddPair('sourceVpdId', Item.SourceVpdId);
      Json.AddPair('sourceVpdName', Item.SourceVpdName);
      Json.AddPair('sourceCategoryName', Item.SourceCategoryName);
      Item.InitialEyeBlinkData := NormalizeInitialEyeBlinkData(
        Item.InitialEyeBlinkData);
      Json.AddPair('initialEyeBlinkData', ObjectData(
        Item.InitialEyeBlinkData, EmptyMmdEyeBlinkSettingData));
      Item.InitialLipSyncData := NormalizeInitialLipSyncData(
        Item.InitialLipSyncData);
      Json.AddPair('initialLipSyncData', ObjectData(
        Item.InitialLipSyncData, EmptyMmdLipSyncSettingData));
      Item.InitialExpressionData := NormalizeInitialExpressionData(
        Item.InitialExpressionData);
      Json.AddPair('initialExpressionData', ObjectData(
        Item.InitialExpressionData, EmptyMmdMorphSettingData));
      Item.PoseData := NormalizePoseData(Item.PoseData);
      Json.AddPair('poseData', ObjectData(Item.PoseData, EmptyPmxPoseData));
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
