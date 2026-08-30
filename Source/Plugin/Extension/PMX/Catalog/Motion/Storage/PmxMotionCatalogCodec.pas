unit PmxMotionCatalogCodec;

// PMX別モーションの順序索引とMotionUID別JSONを読み書きする。

interface

uses
  PmxMotionCatalogItem;

// PMX別MotionUID索引を読み込む。未作成は空一覧として成功する。
function LoadPmxMotionCatalogIndex(const FileName: string; out PmxId: string;
  out MotionIds: TArray<string>): Boolean;
// PMX別MotionUIDの表示順をUTF-8 JSONへ保存する。
function SavePmxMotionCatalogIndex(const FileName, PmxId: string;
  const MotionIds: TArray<string>): Boolean;
// MotionUID別のVMD参照と代表状態を読み込み、不正時はnilを返す。
function LoadPmxMotionCatalogItem(const FileName, PmxId,
  PmxName: string): TPmxMotionCatalogItem;
// MotionUID別のVMD参照と代表状態をUTF-8 JSONへ保存する。
function SavePmxMotionCatalogItem(const FileName: string;
  Item: TPmxMotionCatalogItem): Boolean;

implementation

uses
  System.Generics.Collections,
  System.IOUtils,
  System.JSON,
  System.SysUtils,
  PmxPose,
  PmxPoseCodec,
  MmdMorphSettingCodec;

const
  EmptyMotionPoseData = '{"version":1,"bones":[]}';

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

function JsonCardinal(Value: TJSONValue; const Name: string): Cardinal;
var
  Number: TJSONValue;
  Parsed: Int64;
begin
  Result := 0;
  if not (Value is TJSONObject) then Exit;
  Number := TJSONObject(Value).GetValue(Name);
  if (Number is TJSONNumber) and TryStrToInt64(Number.Value, Parsed) and
    (Parsed >= 0) and (Parsed <= High(Cardinal)) then Result := Parsed;
end;

function JsonData(Value: TJSONValue; const Name, DefaultValue: string): string;
var
  Data: TJSONValue;
begin
  Result := DefaultValue;
  if not (Value is TJSONObject) then Exit;
  Data := TJSONObject(Value).GetValue(Name);
  if Assigned(Data) then Result := Data.ToJSON;
end;

function LoadPmxMotionCatalogIndex(const FileName: string; out PmxId: string;
  out MotionIds: TArray<string>): Boolean;
var
  Array_: TJSONArray;
  I: Integer;
  Root: TJSONValue;
begin
  Result := False;
  PmxId := '';
  MotionIds := nil;
  try
    if not TFile.Exists(FileName) then Exit(True);
    Root := TJSONObject.ParseJSONValue(TFile.ReadAllText(FileName,
      TEncoding.UTF8));
    try
      if not (Root is TJSONObject) then Exit;
      PmxId := JsonString(Root, 'pmxId');
      Array_ := TJSONObject(Root).GetValue<TJSONArray>('motionIds');
      if not Assigned(Array_) then Exit;
      SetLength(MotionIds, Array_.Count);
      for I := 0 to Array_.Count - 1 do
      begin
        if not (Array_.Items[I] is TJSONString) then Exit;
        MotionIds[I] := TJSONString(Array_.Items[I]).Value;
        if MotionIds[I] = '' then Exit;
      end;
      Result := True;
    finally
      Root.Free;
    end;
  except
    PmxId := '';
    MotionIds := nil;
  end;
end;

function SavePmxMotionCatalogIndex(const FileName, PmxId: string;
  const MotionIds: TArray<string>): Boolean;
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
      Root.AddPair('formatVersion', TJSONNumber.Create(PmxMotionCatalogFormatVersion));
      Root.AddPair('pmxId', PmxId);
      Array_ := TJSONArray.Create;
      Root.AddPair('motionIds', Array_);
      for Id in MotionIds do Array_.Add(Id);
      TFile.WriteAllText(FileName, Root.ToJSON, TEncoding.UTF8);
      Result := True;
    finally
      Root.Free;
    end;
  except
    Result := False;
  end;
end;

function LoadPmxMotionCatalogItem(const FileName, PmxId,
  PmxName: string): TPmxMotionCatalogItem;
var
  Morphs: TMmdNamedMorphWeights;
  Poses: TPmxNamedBonePoses;
  Root: TJSONValue;
begin
  Result := nil;
  try
    if not TFile.Exists(FileName) then Exit;
    Root := TJSONObject.ParseJSONValue(TFile.ReadAllText(FileName,
      TEncoding.UTF8));
    try
      if not (Root is TJSONObject) then Exit;
      Result := TPmxMotionCatalogItem.Create;
      Result.Id := JsonString(Root, 'motionId');
      Result.PmxId := JsonString(Root, 'pmxId');
      if Result.PmxId = '' then Result.PmxId := PmxId;
      Result.PmxName := JsonString(Root, 'pmxName');
      if Result.PmxName = '' then Result.PmxName := PmxName;
      Result.Name := JsonString(Root, 'name');
      Result.SourceVmdId := JsonString(Root, 'sourceVmdId');
      Result.SourceVmdName := JsonString(Root, 'sourceVmdName');
      Result.SourceCategoryName := JsonString(Root, 'sourceCategoryName');
      Result.FirstFrame := JsonCardinal(Root, 'firstFrame');
      Result.PreviewPoseData := JsonData(Root, 'previewPoseData',
        EmptyMotionPoseData);
      Result.PreviewMorphData := JsonData(Root, 'previewMorphData',
        EmptyMmdMorphSettingData);
      if (Result.Id = '') or (Result.Name = '') or
        (Result.SourceVmdId = '') or
        not TryDecodePoseData(Result.PreviewPoseData, Poses) or
        not TryDecodeMmdMorphSettingData(Result.PreviewMorphData, Morphs) then
        FreeAndNil(Result);
    finally
      Root.Free;
    end;
  except
    FreeAndNil(Result);
  end;
end;

function ObjectData(const Text, DefaultText: string): TJSONValue;
begin
  Result := TJSONObject.ParseJSONValue(Text);
  if Result is TJSONObject then Exit;
  Result.Free;
  Result := TJSONObject.ParseJSONValue(DefaultText);
end;

function SavePmxMotionCatalogItem(const FileName: string;
  Item: TPmxMotionCatalogItem): Boolean;
var
  Root: TJSONObject;
begin
  Result := False;
  if not Assigned(Item) or (Item.Id = '') or (Item.SourceVmdId = '') then Exit;
  try
    if not ForceDirectories(TPath.GetDirectoryName(FileName)) then Exit;
    Root := TJSONObject.Create;
    try
      Root.AddPair('formatVersion', TJSONNumber.Create(PmxMotionCatalogFormatVersion));
      Root.AddPair('motionId', Item.Id);
      Root.AddPair('pmxId', Item.PmxId);
      Root.AddPair('pmxName', Item.PmxName);
      Root.AddPair('name', Item.Name);
      Root.AddPair('sourceVmdId', Item.SourceVmdId);
      Root.AddPair('sourceVmdName', Item.SourceVmdName);
      Root.AddPair('sourceCategoryName', Item.SourceCategoryName);
      Root.AddPair('firstFrame', TJSONNumber.Create(Item.FirstFrame));
      Root.AddPair('previewPoseData', ObjectData(Item.PreviewPoseData,
        EmptyMotionPoseData));
      Root.AddPair('previewMorphData', ObjectData(Item.PreviewMorphData,
        EmptyMmdMorphSettingData));
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
