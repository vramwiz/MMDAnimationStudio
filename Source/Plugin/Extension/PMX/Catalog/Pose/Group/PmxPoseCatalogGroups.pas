unit PmxPoseCatalogGroups;

// PMX別ポーズグループの名称、表示順、PoseUID所属順をJSONへ保存する。

interface

uses
  System.Classes,
  System.Generics.Collections,
  PmxPoseCatalogStorage;

type
  TPmxPoseCatalogGroup = class
  private
    FId: string;
    FName: string;
    FPoseIds: TStringList;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AddPoseId(const Value: string; Index: Integer = -1);
    procedure ExchangePose(Index1, Index2: Integer);
    function IndexOfPoseId(const Value: string): Integer;
    procedure RemovePoseId(const Value: string);
    property Id: string read FId write FId;
    property Name: string read FName write FName;
    property PoseIds: TStringList read FPoseIds;
  end;

  TPmxPoseCatalogGroups = class
  private
    FFileName: string;
    FItems: TObjectList<TPmxPoseCatalogGroup>;
    function CreateId: string;
    function GetCount: Integer;
    function GetItem(Index: Integer): TPmxPoseCatalogGroup;
  public
    // モデルフォルダー配下のPoses\Groups.jsonを保存先として初期化する。
    constructor Create(const ModelFolder: string);
    destructor Destroy; override;
    function Add(const GroupName: string): TPmxPoseCatalogGroup;
    procedure AssignPoseToGroup(const PoseId: string; GroupIndex: Integer;
      InsertIndex: Integer = -1);
    procedure Delete(Index: Integer);
    procedure Exchange(Index1, Index2: Integer);
    function GroupIndexOfPose(const PoseId: string): Integer;
    function IndexOfId(const Value: string): Integer;
    function IndexOfName(const Value: string): Integer;
    function LoadFromFile: Boolean;
    function RemoveUnknownPoses(Catalog: TPmxPoseCatalogStorage): Boolean;
    procedure RemovePoseFromAll(const PoseId: string);
    function SaveToFile: Boolean;
    property Count: Integer read GetCount;
    property FileName: string read FFileName;
    property Items[Index: Integer]: TPmxPoseCatalogGroup read GetItem; default;
  end;

implementation

uses
  System.IOUtils,
  System.JSON,
  System.SysUtils;

const
  GroupFormatVersion = 1;

constructor TPmxPoseCatalogGroup.Create;
begin
  inherited;
  FPoseIds := TStringList.Create;
  FPoseIds.CaseSensitive := False;
  FPoseIds.Duplicates := dupIgnore;
end;

destructor TPmxPoseCatalogGroup.Destroy;
begin
  FPoseIds.Free;
  inherited;
end;

procedure TPmxPoseCatalogGroup.AddPoseId(const Value: string; Index: Integer);
var
  S: string;
begin
  S := Trim(Value);
  if (S = '') or (FPoseIds.IndexOf(S) >= 0) then Exit;
  if (Index >= 0) and (Index <= FPoseIds.Count) then
    FPoseIds.Insert(Index, S)
  else
    FPoseIds.Add(S);
end;

procedure TPmxPoseCatalogGroup.ExchangePose(Index1, Index2: Integer);
begin
  if (Index1 < 0) or (Index1 >= FPoseIds.Count) or
    (Index2 < 0) or (Index2 >= FPoseIds.Count) then Exit;
  FPoseIds.Exchange(Index1, Index2);
end;

function TPmxPoseCatalogGroup.IndexOfPoseId(const Value: string): Integer;
begin
  Result := FPoseIds.IndexOf(Trim(Value));
end;

procedure TPmxPoseCatalogGroup.RemovePoseId(const Value: string);
var
  Index: Integer;
begin
  Index := IndexOfPoseId(Value);
  if Index >= 0 then FPoseIds.Delete(Index);
end;

constructor TPmxPoseCatalogGroups.Create(const ModelFolder: string);
begin
  inherited Create;
  FFileName := TPath.Combine(TPath.Combine(ModelFolder, 'Poses'),
    'Groups.json');
  FItems := TObjectList<TPmxPoseCatalogGroup>.Create(True);
end;

destructor TPmxPoseCatalogGroups.Destroy;
begin
  FItems.Free;
  inherited;
end;

function TPmxPoseCatalogGroups.CreateId: string;
var
  Guid: TGUID;
begin
  Result := '';
  if CreateGUID(Guid) <> S_OK then Exit;
  Result := LowerCase(GUIDToString(Guid));
  Result := StringReplace(Result, '{', '', [rfReplaceAll]);
  Result := StringReplace(Result, '}', '', [rfReplaceAll]);
  Result := StringReplace(Result, '-', '', [rfReplaceAll]);
end;

function TPmxPoseCatalogGroups.GetCount: Integer;
begin
  Result := FItems.Count;
end;

function TPmxPoseCatalogGroups.GetItem(Index: Integer): TPmxPoseCatalogGroup;
begin
  Result := FItems[Index];
end;

function TPmxPoseCatalogGroups.Add(
  const GroupName: string): TPmxPoseCatalogGroup;
begin
  Result := nil;
  if (Trim(GroupName) = '') or (IndexOfName(GroupName) >= 0) then Exit;
  Result := TPmxPoseCatalogGroup.Create;
  Result.Id := CreateId;
  if Result.Id = '' then
  begin
    Result.Free;
    Exit(nil);
  end;
  Result.Name := Trim(GroupName);
  FItems.Add(Result);
end;

procedure TPmxPoseCatalogGroups.AssignPoseToGroup(const PoseId: string;
  GroupIndex, InsertIndex: Integer);
begin
  if GroupIndexOfPose(PoseId) = GroupIndex then Exit;
  RemovePoseFromAll(PoseId);
  if (GroupIndex >= 0) and (GroupIndex < Count) then
    FItems[GroupIndex].AddPoseId(PoseId, InsertIndex);
end;

procedure TPmxPoseCatalogGroups.Delete(Index: Integer);
begin
  if (Index >= 0) and (Index < Count) then FItems.Delete(Index);
end;

procedure TPmxPoseCatalogGroups.Exchange(Index1, Index2: Integer);
begin
  if (Index1 < 0) or (Index1 >= Count) or
    (Index2 < 0) or (Index2 >= Count) then Exit;
  FItems.Exchange(Index1, Index2);
end;

function TPmxPoseCatalogGroups.GroupIndexOfPose(
  const PoseId: string): Integer;
begin
  for Result := 0 to Count - 1 do
    if FItems[Result].IndexOfPoseId(PoseId) >= 0 then Exit;
  Result := -1;
end;

function TPmxPoseCatalogGroups.IndexOfId(const Value: string): Integer;
begin
  for Result := 0 to Count - 1 do
    if SameText(FItems[Result].Id, Trim(Value)) then Exit;
  Result := -1;
end;

function TPmxPoseCatalogGroups.IndexOfName(const Value: string): Integer;
begin
  for Result := 0 to Count - 1 do
    if SameText(Trim(FItems[Result].Name), Trim(Value)) then Exit;
  Result := -1;
end;

function JsonString(Obj: TJSONObject; const Name: string): string;
var
  Value: TJSONValue;
begin
  Result := '';
  Value := Obj.GetValue(Name);
  if Value is TJSONString then Result := TJSONString(Value).Value;
end;

function TPmxPoseCatalogGroups.LoadFromFile: Boolean;
var
  Group: TPmxPoseCatalogGroup;
  GroupArray, PoseArray: TJSONArray;
  GroupValue, PoseValue, RootValue: TJSONValue;
  I, J: Integer;
  Obj: TJSONObject;
begin
  Result := False;
  FItems.Clear;
  if not TFile.Exists(FFileName) then Exit(True);
  try
    RootValue := TJSONObject.ParseJSONValue(TFile.ReadAllText(FFileName,
      TEncoding.UTF8));
    try
      if not (RootValue is TJSONObject) then Exit;
      GroupArray := TJSONObject(RootValue).GetValue<TJSONArray>('groups');
      if not Assigned(GroupArray) then Exit;
      for I := 0 to GroupArray.Count - 1 do
      begin
        GroupValue := GroupArray.Items[I];
        if not (GroupValue is TJSONObject) then Continue;
        Obj := TJSONObject(GroupValue);
        Group := TPmxPoseCatalogGroup.Create;
        Group.Id := JsonString(Obj, 'id');
        Group.Name := Trim(JsonString(Obj, 'name'));
        PoseArray := Obj.GetValue<TJSONArray>('poseIds');
        if Assigned(PoseArray) then
          for J := 0 to PoseArray.Count - 1 do
          begin
            PoseValue := PoseArray.Items[J];
            if PoseValue is TJSONString then
              Group.AddPoseId(TJSONString(PoseValue).Value);
          end;
        if (Group.Id = '') or (Group.Name = '') or
          (IndexOfId(Group.Id) >= 0) or (IndexOfName(Group.Name) >= 0) then
          Group.Free
        else
          FItems.Add(Group);
      end;
      Result := True;
    finally
      RootValue.Free;
    end;
  except
    FItems.Clear;
  end;
end;

function TPmxPoseCatalogGroups.RemoveUnknownPoses(
  Catalog: TPmxPoseCatalogStorage): Boolean;
var
  Found: Boolean;
  I, J, K: Integer;
begin
  Result := False;
  if not Assigned(Catalog) then Exit;
  for I := 0 to Count - 1 do
    for J := FItems[I].PoseIds.Count - 1 downto 0 do
    begin
      Found := False;
      for K := 0 to Catalog.Count - 1 do
        if SameText(Catalog[K].Id, FItems[I].PoseIds[J]) then
        begin
          Found := True;
          Break;
        end;
      if not Found then
      begin
        FItems[I].PoseIds.Delete(J);
        Result := True;
      end;
    end;
end;

procedure TPmxPoseCatalogGroups.RemovePoseFromAll(const PoseId: string);
var
  I: Integer;
begin
  for I := 0 to Count - 1 do FItems[I].RemovePoseId(PoseId);
end;

function TPmxPoseCatalogGroups.SaveToFile: Boolean;
var
  Group: TPmxPoseCatalogGroup;
  GroupArray, PoseArray: TJSONArray;
  I: Integer;
  Obj, Root: TJSONObject;
  PoseId: string;
begin
  Result := False;
  try
    if not ForceDirectories(TPath.GetDirectoryName(FFileName)) then Exit;
    Root := TJSONObject.Create;
    try
      Root.AddPair('formatVersion', TJSONNumber.Create(GroupFormatVersion));
      GroupArray := TJSONArray.Create;
      Root.AddPair('groups', GroupArray);
      for Group in FItems do
      begin
        Obj := TJSONObject.Create;
        GroupArray.AddElement(Obj);
        Obj.AddPair('id', Group.Id);
        Obj.AddPair('name', Group.Name);
        PoseArray := TJSONArray.Create;
        Obj.AddPair('poseIds', PoseArray);
        for I := 0 to Group.PoseIds.Count - 1 do
        begin
          PoseId := Group.PoseIds[I];
          PoseArray.Add(PoseId);
        end;
      end;
      TFile.WriteAllText(FFileName, Root.ToJSON, TEncoding.UTF8);
      Result := True;
    finally
      Root.Free;
    end;
  except
    Result := False;
  end;
end;

end.
