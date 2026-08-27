unit PmxCatalogStorage;

// PMX UIDの表示順と、UID別モデル情報の永続化・旧パス一覧移行を担当する。

interface

uses
  System.Generics.Collections;

type
  TPmxCatalogItem = class
  private
    FDisplayName: string;
    FId: string;
    FSourcePath: string;
  public
    property DisplayName: string read FDisplayName write FDisplayName;
    property Id: string read FId write FId;
    property SourcePath: string read FSourcePath write FSourcePath;
  end;

  TPmxCatalogStorage = class
  private
    FCatalogFileName: string;
    FLegacyFileName: string;
    FModelsFolder: string;
    FItems: TObjectList<TPmxCatalogItem>;
    function CreateId: string;
    function GetCount: Integer;
    function GetItem(Index: Integer): TPmxCatalogItem;
    function GetPath(Index: Integer): string;
    function LoadCatalog: Boolean;
    function LoadLegacyCatalog: Boolean;
    function LoadModel(const Id: string): TPmxCatalogItem;
    function ModelFileName(const Id: string): string;
    function NormalizePmxPath(const FileName: string): string;
    function SaveModel(Item: TPmxCatalogItem): Boolean;
  public
    constructor Create(const AFileName: string;
      const ALegacyFileName: string = '');
    destructor Destroy; override;
    // 未登録のPMX絶対パスへPmxUIDを発行し、モデル情報を保存する。
    function Add(const FileName: string): Boolean;
    function FindById(const Id: string): TPmxCatalogItem;
    function IndexOfPath(const FileName: string): Integer;
    function LoadFromFile: Boolean;
    function ModelFolder(const Id: string): string;
    function SaveToFile: Boolean;
    property Count: Integer read GetCount;
    property FileName: string read FCatalogFileName;
    property Items[Index: Integer]: TPmxCatalogItem read GetItem;
    property Paths[Index: Integer]: string read GetPath; default;
  end;

implementation

uses
  Winapi.Windows,
  System.Classes,
  System.IOUtils,
  System.JSON,
  System.SysUtils;

const
  CatalogFormatVersion = 1;

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

constructor TPmxCatalogStorage.Create(const AFileName,
  ALegacyFileName: string);
begin
  inherited Create;
  FCatalogFileName := AFileName;
  FLegacyFileName := ALegacyFileName;
  FModelsFolder := TPath.Combine(TPath.GetDirectoryName(AFileName), 'Models');
  FItems := TObjectList<TPmxCatalogItem>.Create(True);
end;

destructor TPmxCatalogStorage.Destroy;
begin
  FItems.Free;
  inherited;
end;

function TPmxCatalogStorage.Add(const FileName: string): Boolean;
var
  Item: TPmxCatalogItem;
  NormalizedPath: string;
begin
  NormalizedPath := NormalizePmxPath(FileName);
  Result := (NormalizedPath <> '') and (IndexOfPath(NormalizedPath) < 0);
  if not Result then
    Exit;

  Item := TPmxCatalogItem.Create;
  Item.Id := CreateId;
  if Item.Id = '' then
  begin
    Item.Free;
    Exit(False);
  end;
  Item.SourcePath := NormalizedPath;
  Item.DisplayName := ChangeFileExt(ExtractFileName(NormalizedPath), '');
  if not SaveModel(Item) then
  begin
    Item.Free;
    Exit(False);
  end;
  FItems.Add(Item);
end;

function TPmxCatalogStorage.CreateId: string;
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

function TPmxCatalogStorage.FindById(const Id: string): TPmxCatalogItem;
var
  Item: TPmxCatalogItem;
begin
  for Item in FItems do
    if SameText(Item.Id, Id) then
      Exit(Item);
  Result := nil;
end;

function TPmxCatalogStorage.GetCount: Integer;
begin
  Result := FItems.Count;
end;

function TPmxCatalogStorage.GetItem(Index: Integer): TPmxCatalogItem;
begin
  Result := FItems[Index];
end;

function TPmxCatalogStorage.GetPath(Index: Integer): string;
begin
  Result := FItems[Index].SourcePath;
end;

function TPmxCatalogStorage.IndexOfPath(const FileName: string): Integer;
var
  NormalizedPath: string;
begin
  Result := -1;
  NormalizedPath := NormalizePmxPath(FileName);
  if NormalizedPath = '' then
    Exit;
  for Result := 0 to FItems.Count - 1 do
    if SameText(FItems[Result].SourcePath, NormalizedPath) then
      Exit;
  Result := -1;
end;

function TPmxCatalogStorage.LoadCatalog: Boolean;
var
  ArrayValue: TJSONArray;
  Id: string;
  Index: Integer;
  Item: TPmxCatalogItem;
  Json: TJSONValue;
  Text: string;
begin
  Result := False;
  try
    Text := TFile.ReadAllText(FCatalogFileName, TEncoding.UTF8);
    Json := TJSONObject.ParseJSONValue(Text);
    try
      if not (Json is TJSONObject) then
        Exit;
      ArrayValue := TJSONObject(Json).GetValue<TJSONArray>('modelIds');
      if not Assigned(ArrayValue) then
        Exit;
      for Index := 0 to ArrayValue.Count - 1 do
      begin
        Id := ArrayValue.Items[Index].Value;
        Item := LoadModel(Id);
        if Assigned(Item) and (IndexOfPath(Item.SourcePath) < 0) then
          FItems.Add(Item)
        else
          Item.Free;
      end;
      Result := True;
    finally
      Json.Free;
    end;
  except
    FItems.Clear;
  end;
end;

function TPmxCatalogStorage.LoadFromFile: Boolean;
begin
  FItems.Clear;
  if (FCatalogFileName <> '') and TFile.Exists(FCatalogFileName) then
    Exit(LoadCatalog);
  Result := LoadLegacyCatalog;
  if Result and (FItems.Count > 0) then
    SaveToFile;
end;

function TPmxCatalogStorage.LoadLegacyCatalog: Boolean;
var
  LegacyPaths: TStringList;
  Path: string;
begin
  Result := True;
  if (FLegacyFileName = '') or not TFile.Exists(FLegacyFileName) then
    Exit;
  LegacyPaths := TStringList.Create;
  try
    try
      LegacyPaths.LoadFromFile(FLegacyFileName, TEncoding.UTF8);
      for Path in LegacyPaths do
        Add(Path);
    except
      FItems.Clear;
      Result := False;
    end;
  finally
    LegacyPaths.Free;
  end;
end;

function TPmxCatalogStorage.LoadModel(const Id: string): TPmxCatalogItem;
var
  Json: TJSONValue;
  Text: string;
begin
  Result := nil;
  try
    if not TFile.Exists(ModelFileName(Id)) then
      Exit;
    Text := TFile.ReadAllText(ModelFileName(Id), TEncoding.UTF8);
    Json := TJSONObject.ParseJSONValue(Text);
    try
      if not (Json is TJSONObject) then
        Exit;
      Result := TPmxCatalogItem.Create;
      Result.Id := JsonString(Json, 'id');
      Result.SourcePath := NormalizePmxPath(JsonString(Json, 'sourcePath'));
      Result.DisplayName := JsonString(Json, 'displayName');
      if (Result.Id = '') or (Result.SourcePath = '') then
        FreeAndNil(Result)
      else if Result.DisplayName = '' then
        Result.DisplayName := ChangeFileExt(ExtractFileName(
          Result.SourcePath), '');
    finally
      Json.Free;
    end;
  except
    FreeAndNil(Result);
  end;
end;

function TPmxCatalogStorage.ModelFileName(const Id: string): string;
begin
  Result := TPath.Combine(ModelFolder(Id), 'Model.json');
end;

function TPmxCatalogStorage.ModelFolder(const Id: string): string;
begin
  Result := TPath.Combine(FModelsFolder, Id);
end;

function TPmxCatalogStorage.NormalizePmxPath(const FileName: string): string;
begin
  Result := '';
  try
    if not SameText(TPath.GetExtension(Trim(FileName)), '.pmx') then
      Exit;
    Result := TPath.GetFullPath(Trim(FileName));
  except
    Result := '';
  end;
end;

function TPmxCatalogStorage.SaveModel(Item: TPmxCatalogItem): Boolean;
var
  Json: TJSONObject;
begin
  Result := False;
  if not Assigned(Item) or (Item.Id = '') then
    Exit;
  try
    if not ForceDirectories(ModelFolder(Item.Id)) then
      Exit;
    Json := TJSONObject.Create;
    try
      Json.AddPair('formatVersion', TJSONNumber.Create(CatalogFormatVersion));
      Json.AddPair('id', Item.Id);
      Json.AddPair('sourcePath', Item.SourcePath);
      Json.AddPair('displayName', Item.DisplayName);
      TFile.WriteAllText(ModelFileName(Item.Id), Json.ToJSON,
        TEncoding.UTF8);
      Result := True;
    finally
      Json.Free;
    end;
  except
    Result := False;
  end;
end;

function TPmxCatalogStorage.SaveToFile: Boolean;
var
  Ids: TJSONArray;
  Item: TPmxCatalogItem;
  Json: TJSONObject;
begin
  Result := False;
  if FCatalogFileName = '' then
    Exit;
  try
    if not ForceDirectories(TPath.GetDirectoryName(FCatalogFileName)) then
      Exit;
    Json := TJSONObject.Create;
    try
      Json.AddPair('formatVersion', TJSONNumber.Create(CatalogFormatVersion));
      Ids := TJSONArray.Create;
      Json.AddPair('modelIds', Ids);
      for Item in FItems do
      begin
        SaveModel(Item);
        Ids.Add(Item.Id);
      end;
      TFile.WriteAllText(FCatalogFileName, Json.ToJSON, TEncoding.UTF8);
      Result := True;
    finally
      Json.Free;
    end;
  except
    Result := False;
  end;
end;

end.
