unit PmxPoseCatalogStorage;

// 1つのPMXに属するポーズ要素をPoseUID別ファイルと順序索引で管理する。

interface

uses
  System.Generics.Collections;

type
  TPmxPoseCatalogItem = class
  private
    FId: string;
    FInitialEyeBlinkData: string;
    FInitialExpressionData: string;
    FInitialLipSyncData: string;
    FKind: string;
    FName: string;
    FPmxId: string;
    FPmxName: string;
    FPoseData: string;
  public
    property Id: string read FId write FId;
    property InitialEyeBlinkData: string read FInitialEyeBlinkData
      write FInitialEyeBlinkData;
    property InitialExpressionData: string read FInitialExpressionData
      write FInitialExpressionData;
    property InitialLipSyncData: string read FInitialLipSyncData
      write FInitialLipSyncData;
    property Kind: string read FKind write FKind;
    property Name: string read FName write FName;
    property PmxId: string read FPmxId write FPmxId;
    property PmxName: string read FPmxName write FPmxName;
    property PoseData: string read FPoseData write FPoseData;
  end;

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
    // 全項目を個別JSONへ保存し、順序と初期状態IDを索引JSONへ書き出す。
    function SaveToFile: Boolean;
    property Count: Integer read GetCount;
    property Items[Index: Integer]: TPmxPoseCatalogItem read GetItem; default;
  end;

implementation

uses
  Winapi.Windows,
  System.IOUtils,
  System.JSON,
  System.SysUtils,
  MmdMorphSettingCodec,
  MmdEyeBlinkSettingCodec,
  MmdLipSyncSettingCodec,
  PmxPoseCatalogDataValidation;

const
  PoseCatalogFormatVersion = 5;
  InitialPoseName = #$521D#$671F#$72B6#$614B;
  InitialPoseKind = 'initial';
  NormalPoseKind = 'pose';

function JsonString(Value: TJSONValue; const Name: string): string;
var
  Pair: TJSONPair;
begin
  Result := '';
  if not (Value is TJSONObject) then
    Exit;
  Pair := TJSONObject(Value).Get(Name);
  if Assigned(Pair) and (Pair.JsonValue is TJSONString) then
    Result := TJSONString(Pair.JsonValue).Value;
end;

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
var
  Json: TJSONValue;
  PoseValue: TJSONValue;
begin
  Result := nil;
  try
    if not TFile.Exists(ItemFileName(Id)) then
      Exit;
    Json := TJSONObject.ParseJSONValue(TFile.ReadAllText(
      ItemFileName(Id), TEncoding.UTF8));
    try
      if not (Json is TJSONObject) then
        Exit;
      Result := TPmxPoseCatalogItem.Create;
      Result.Id := JsonString(Json, 'poseId');
      if Result.Id = '' then
        Result.Id := JsonString(Json, 'id');
      Result.PmxId := JsonString(Json, 'pmxId');
      if Result.PmxId = '' then
        Result.PmxId := FPmxId;
      Result.PmxName := JsonString(Json, 'pmxName');
      if Result.PmxName = '' then
        Result.PmxName := FPmxName;
      Result.Name := JsonString(Json, 'name');
      Result.Kind := JsonString(Json, 'kind');
      PoseValue := TJSONObject(Json).GetValue('initialEyeBlinkData');
      if PoseValue is TJSONString then
        Result.InitialEyeBlinkData := TJSONString(PoseValue).Value
      else if Assigned(PoseValue) then
        Result.InitialEyeBlinkData := PoseValue.ToJSON;
      Result.InitialEyeBlinkData := NormalizeInitialEyeBlinkData(
        Result.InitialEyeBlinkData);
      PoseValue := TJSONObject(Json).GetValue('initialLipSyncData');
      if PoseValue is TJSONString then
        Result.InitialLipSyncData := TJSONString(PoseValue).Value
      else if Assigned(PoseValue) then
        Result.InitialLipSyncData := PoseValue.ToJSON;
      Result.InitialLipSyncData := NormalizeInitialLipSyncData(
        Result.InitialLipSyncData);
      PoseValue := TJSONObject(Json).GetValue('initialExpressionData');
      if PoseValue is TJSONString then
        Result.InitialExpressionData := TJSONString(PoseValue).Value
      else if Assigned(PoseValue) then
        Result.InitialExpressionData := PoseValue.ToJSON;
      Result.InitialExpressionData := NormalizeInitialExpressionData(
        Result.InitialExpressionData);
      PoseValue := TJSONObject(Json).GetValue('poseData');
      if PoseValue is TJSONString then
        Result.PoseData := TJSONString(PoseValue).Value
      else if Assigned(PoseValue) then
        Result.PoseData := PoseValue.ToJSON;
      Result.PoseData := NormalizePoseData(Result.PoseData);
      if Result.Id = '' then
        FreeAndNil(Result);
    finally
      Json.Free;
    end;
  except
    FreeAndNil(Result);
  end;
end;

function TPmxPoseCatalogStorage.LoadOrCreateDefault: Boolean;
var
  Id: string;
  Ids: TJSONArray;
  Index: Integer;
  Item: TPmxPoseCatalogItem;
  Json: TJSONValue;
  DefaultFound: Boolean;
begin
  Result := False;
  FItems.Clear;
  try
    if TFile.Exists(FIndexFileName) then
    begin
      Json := TJSONObject.ParseJSONValue(TFile.ReadAllText(
        FIndexFileName, TEncoding.UTF8));
      try
        if Json is TJSONObject then
        begin
          if FPmxId = '' then
            FPmxId := JsonString(Json, 'pmxId');
          FDefaultPoseId := JsonString(Json, 'defaultPoseId');
          Ids := TJSONObject(Json).GetValue<TJSONArray>('poseIds');
          if Assigned(Ids) then
            for Index := 0 to Ids.Count - 1 do
            begin
              Id := Ids.Items[Index].Value;
              Item := LoadItem(Id);
              if Assigned(Item) then
                FItems.Add(Item);
            end;
        end;
      finally
        Json.Free;
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
var
  ExpressionJson: TJSONValue;
  Json: TJSONObject;
  PoseJson: TJSONValue;
begin
  Result := False;
  if not Assigned(Item) or (Item.Id = '') then
    Exit;
  try
    if not ForceDirectories(FItemsFolder) then
      Exit;
    Json := TJSONObject.Create;
    try
      Json.AddPair('formatVersion',
        TJSONNumber.Create(PoseCatalogFormatVersion));
      Json.AddPair('poseId', Item.Id);
      Json.AddPair('pmxId', Item.PmxId);
      Json.AddPair('pmxName', Item.PmxName);
      Json.AddPair('name', Item.Name);
      Json.AddPair('kind', Item.Kind);
      Item.InitialEyeBlinkData := NormalizeInitialEyeBlinkData(
        Item.InitialEyeBlinkData);
      ExpressionJson := TJSONObject.ParseJSONValue(Item.InitialEyeBlinkData);
      if not (ExpressionJson is TJSONObject) then
      begin
        ExpressionJson.Free;
        ExpressionJson := TJSONObject.ParseJSONValue(
          EmptyMmdEyeBlinkSettingData);
      end;
      Json.AddPair('initialEyeBlinkData', ExpressionJson);
      Item.InitialLipSyncData := NormalizeInitialLipSyncData(
        Item.InitialLipSyncData);
      ExpressionJson := TJSONObject.ParseJSONValue(Item.InitialLipSyncData);
      if not (ExpressionJson is TJSONObject) then
      begin
        ExpressionJson.Free;
        ExpressionJson := TJSONObject.ParseJSONValue(
          EmptyMmdLipSyncSettingData);
      end;
      Json.AddPair('initialLipSyncData', ExpressionJson);
      Item.InitialExpressionData := NormalizeInitialExpressionData(
        Item.InitialExpressionData);
      ExpressionJson := TJSONObject.ParseJSONValue(
        Item.InitialExpressionData);
      if not (ExpressionJson is TJSONObject) then
      begin
        ExpressionJson.Free;
        ExpressionJson := TJSONObject.ParseJSONValue(
          EmptyMmdMorphSettingData);
      end;
      Json.AddPair('initialExpressionData', ExpressionJson);
      Item.PoseData := NormalizePoseData(Item.PoseData);
      PoseJson := TJSONObject.ParseJSONValue(Item.PoseData);
      if not (PoseJson is TJSONObject) then
      begin
        PoseJson.Free;
        PoseJson := TJSONObject.ParseJSONValue(EmptyPmxPoseData);
      end;
      Json.AddPair('poseData', PoseJson);
      TFile.WriteAllText(ItemFileName(Item.Id), Json.ToJSON,
        TEncoding.UTF8);
      Result := True;
    finally
      Json.Free;
    end;
  except
    Result := False;
  end;
end;

function TPmxPoseCatalogStorage.SaveToFile: Boolean;
var
  Ids: TJSONArray;
  Item: TPmxPoseCatalogItem;
  Json: TJSONObject;
begin
  Result := False;
  try
    if not ForceDirectories(FItemsFolder) then
      Exit;
    Json := TJSONObject.Create;
    try
      Json.AddPair('formatVersion',
        TJSONNumber.Create(PoseCatalogFormatVersion));
      Json.AddPair('pmxId', FPmxId);
      Json.AddPair('defaultPoseId', FDefaultPoseId);
      Ids := TJSONArray.Create;
      Json.AddPair('poseIds', Ids);
      for Item in FItems do
      begin
        Item.PmxId := FPmxId;
        Item.PmxName := FPmxName;
        if not SaveItem(Item) then
          Exit;
        Ids.Add(Item.Id);
      end;
      TFile.WriteAllText(FIndexFileName, Json.ToJSON, TEncoding.UTF8);
      Result := True;
    finally
      Json.Free;
    end;
  except
    Result := False;
  end;
end;

end.
