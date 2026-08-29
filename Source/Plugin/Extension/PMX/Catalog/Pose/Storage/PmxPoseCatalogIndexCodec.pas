unit PmxPoseCatalogIndexCodec;

// ポーズ表示順と初期状態IDを保持するIndex.jsonの相互変換だけを担当する。

interface

type
  TPmxPoseCatalogIndex = record
    DefaultPoseId: string;
    PmxId: string;
    PoseIds: TArray<string>;
  end;

// Index.jsonを読み込み、形式が正しい場合だけDataへ値を返す。
function LoadPmxPoseCatalogIndex(const FileName: string;
  out Data: TPmxPoseCatalogIndex): Boolean;
// 表示順と初期状態IDをIndex.jsonへUTF-8で保存する。
function SavePmxPoseCatalogIndex(const FileName: string;
  const Data: TPmxPoseCatalogIndex): Boolean;

implementation

uses
  System.Generics.Collections,
  System.IOUtils,
  System.JSON,
  System.SysUtils,
  PmxPoseCatalogItem;

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

function LoadPmxPoseCatalogIndex(const FileName: string;
  out Data: TPmxPoseCatalogIndex): Boolean;
var
  Ids: TJSONArray;
  Index: Integer;
  Json: TJSONValue;
begin
  Result := False;
  Data := Default(TPmxPoseCatalogIndex);
  try
    Json := TJSONObject.ParseJSONValue(TFile.ReadAllText(
      FileName, TEncoding.UTF8));
    try
      if not (Json is TJSONObject) then Exit;
      Ids := TJSONObject(Json).GetValue<TJSONArray>('poseIds');
      if not Assigned(Ids) then Exit;
      Data.PmxId := JsonString(Json, 'pmxId');
      Data.DefaultPoseId := JsonString(Json, 'defaultPoseId');
      SetLength(Data.PoseIds, Ids.Count);
      for Index := 0 to Ids.Count - 1 do
        Data.PoseIds[Index] := Ids.Items[Index].Value;
      Result := True;
    finally
      Json.Free;
    end;
  except
    Data := Default(TPmxPoseCatalogIndex);
  end;
end;

function SavePmxPoseCatalogIndex(const FileName: string;
  const Data: TPmxPoseCatalogIndex): Boolean;
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
        TJSONNumber.Create(PmxPoseCatalogFormatVersion));
      Json.AddPair('pmxId', Data.PmxId);
      Json.AddPair('defaultPoseId', Data.DefaultPoseId);
      Ids := TJSONArray.Create;
      Json.AddPair('poseIds', Ids);
      for Id in Data.PoseIds do Ids.Add(Id);
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
