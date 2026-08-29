unit PmxFaceCatalogCodec;

// FaceUID別JSONと、表示順を保持するIndex.jsonの相互変換を担当する。

interface

uses
  PmxFaceCatalogItem;

type
  TPmxFaceCatalogIndex = record
    DefaultFaceId: string;
    FaceIds: TArray<string>;
    PmxId: string;
  end;

// FaceUID別JSONを読み込み、正規化した項目を返す。失敗時はnilを返す。
function LoadPmxFaceCatalogItem(const FileName, PmxId,
  PmxName: string): TPmxFaceCatalogItem;
// 表情項目をFaceUID別JSONへUTF-8で保存する。
function SavePmxFaceCatalogItem(const FileName: string;
  Item: TPmxFaceCatalogItem): Boolean;
// Index.jsonから表情の表示順と初期状態IDを読み込む。
function LoadPmxFaceCatalogIndex(const FileName: string;
  out Data: TPmxFaceCatalogIndex): Boolean;
// 表情の表示順と初期状態IDをIndex.jsonへUTF-8で保存する。
function SavePmxFaceCatalogIndex(const FileName: string;
  const Data: TPmxFaceCatalogIndex): Boolean;

implementation

uses
  System.Generics.Collections, System.IOUtils, System.JSON, System.SysUtils,
  MmdMorphSettingCodec;

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

function NormalizeFaceData(const Value: string): string;
var
  Weights: TMmdNamedMorphWeights;
begin
  Result := Value;
  if not TryDecodeMmdMorphSettingData(Result, Weights) then
    Result := EmptyMmdMorphSettingData;
end;

function LoadPmxFaceCatalogItem(const FileName, PmxId,
  PmxName: string): TPmxFaceCatalogItem;
var
  DataValue: TJSONValue;
  Json: TJSONValue;
begin
  Result := nil;
  try
    if not TFile.Exists(FileName) then Exit;
    Json := TJSONObject.ParseJSONValue(TFile.ReadAllText(FileName,
      TEncoding.UTF8));
    try
      if not (Json is TJSONObject) then Exit;
      Result := TPmxFaceCatalogItem.Create;
      Result.Id := JsonString(Json, 'faceId');
      Result.PmxId := JsonString(Json, 'pmxId');
      if Result.PmxId = '' then Result.PmxId := PmxId;
      Result.PmxName := JsonString(Json, 'pmxName');
      if Result.PmxName = '' then Result.PmxName := PmxName;
      Result.Name := JsonString(Json, 'name');
      Result.Kind := JsonString(Json, 'kind');
      DataValue := TJSONObject(Json).GetValue('faceData');
      if DataValue is TJSONString then
        Result.FaceData := NormalizeFaceData(TJSONString(DataValue).Value)
      else if Assigned(DataValue) then
        Result.FaceData := NormalizeFaceData(DataValue.ToJSON)
      else
        Result.FaceData := EmptyMmdMorphSettingData;
      if Result.Id = '' then FreeAndNil(Result);
    finally
      Json.Free;
    end;
  except
    FreeAndNil(Result);
  end;
end;

function ObjectData(const Data: string): TJSONValue;
begin
  Result := TJSONObject.ParseJSONValue(NormalizeFaceData(Data));
end;

function SavePmxFaceCatalogItem(const FileName: string;
  Item: TPmxFaceCatalogItem): Boolean;
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
        TJSONNumber.Create(PmxFaceCatalogFormatVersion));
      Json.AddPair('faceId', Item.Id);
      Json.AddPair('pmxId', Item.PmxId);
      Json.AddPair('pmxName', Item.PmxName);
      Json.AddPair('name', Item.Name);
      Json.AddPair('kind', Item.Kind);
      Json.AddPair('faceData', ObjectData(Item.FaceData));
      TFile.WriteAllText(FileName, Json.ToJSON, TEncoding.UTF8);
      Result := True;
    finally
      Json.Free;
    end;
  except
    Result := False;
  end;
end;

function LoadPmxFaceCatalogIndex(const FileName: string;
  out Data: TPmxFaceCatalogIndex): Boolean;
var
  Ids: TJSONArray;
  Index: Integer;
  Json: TJSONValue;
begin
  Result := False;
  Data := Default(TPmxFaceCatalogIndex);
  try
    Json := TJSONObject.ParseJSONValue(TFile.ReadAllText(FileName,
      TEncoding.UTF8));
    try
      if not (Json is TJSONObject) then Exit;
      Ids := TJSONObject(Json).GetValue<TJSONArray>('faceIds');
      if not Assigned(Ids) then Exit;
      Data.PmxId := JsonString(Json, 'pmxId');
      Data.DefaultFaceId := JsonString(Json, 'defaultFaceId');
      SetLength(Data.FaceIds, Ids.Count);
      for Index := 0 to Ids.Count - 1 do
        Data.FaceIds[Index] := Ids.Items[Index].Value;
      Result := True;
    finally
      Json.Free;
    end;
  except
    Data := Default(TPmxFaceCatalogIndex);
  end;
end;

function SavePmxFaceCatalogIndex(const FileName: string;
  const Data: TPmxFaceCatalogIndex): Boolean;
var
  Id: string;
  Ids: TJSONArray;
  Json: TJSONObject;
begin
  Result := False;
  try
    if not ForceDirectories(TPath.GetDirectoryName(FileName)) then Exit;
    Json := TJSONObject.Create;
    try
      Json.AddPair('formatVersion',
        TJSONNumber.Create(PmxFaceCatalogFormatVersion));
      Json.AddPair('pmxId', Data.PmxId);
      Json.AddPair('defaultFaceId', Data.DefaultFaceId);
      Ids := TJSONArray.Create;
      Json.AddPair('faceIds', Ids);
      for Id in Data.FaceIds do Ids.Add(Id);
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

