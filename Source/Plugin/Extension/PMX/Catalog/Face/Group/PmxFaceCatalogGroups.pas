unit PmxFaceCatalogGroups;

// PMX別表情グループの名称、表示順、FaceUID所属順をJSONへ保存する。

interface

uses
  System.Classes, System.Generics.Collections,
  PmxFaceCatalogStorage;

type
  TPmxFaceCatalogGroup = class
  private
    FFaceIds: TStringList;
    FId: string;
    FName: string;
  public
    // FaceUIDを重複なしで保持する空グループを生成する。
    constructor Create;
    // グループが所有するFaceUID一覧を解放する。
    destructor Destroy; override;
    // FaceUIDを未登録時だけ指定位置または末尾へ追加する。
    procedure AddFaceId(const Value: string; Index: Integer = -1);
    // グループ内の2つのFaceUID表示順を交換する。
    procedure ExchangeFace(Index1, Index2: Integer);
    // FaceUIDのグループ内番号を返し、未登録では-1を返す。
    function IndexOfFaceId(const Value: string): Integer;
    // 一致するFaceUIDをグループから取り除く。
    procedure RemoveFaceId(const Value: string);
    // グループ識別子、表示名、所属FaceUID順を読み書きする。
    property FaceIds: TStringList read FFaceIds;
    property Id: string read FId write FId;
    property Name: string read FName write FName;
  end;

  TPmxFaceCatalogGroups = class
  private
    FFileName: string;
    FItems: TObjectList<TPmxFaceCatalogGroup>;
    function CreateId: string;
    function GetCount: Integer;
    function GetItem(Index: Integer): TPmxFaceCatalogGroup;
  public
    // モデルフォルダー配下のFaces\Groups.jsonを保存先として初期化する。
    constructor Create(const ModelFolder: string);
    // 読み込んだ全グループを解放する。
    destructor Destroy; override;
    // 空でない名称のグループを追加し、生成した項目またはnilを返す。
    function Add(const GroupName: string): TPmxFaceCatalogGroup;
    // FaceUIDを全グループから外し、指定番号が有効ならそのグループへ挿入する。
    procedure AssignFaceToGroup(const FaceId: string; GroupIndex: Integer;
      InsertIndex: Integer = -1);
    // 指定番号のグループを削除する。
    procedure Delete(Index: Integer);
    // 2グループの表示順を交換する。
    procedure Exchange(Index1, Index2: Integer);
    // FaceUIDが所属する最初のグループ番号を返し、未所属では-1を返す。
    function GroupIndexOfFace(const FaceId: string): Integer;
    // 識別子または名称に一致するグループ番号を返し、未登録では-1を返す。
    function IndexOfId(const Value: string): Integer;
    // 表示名に一致するグループ番号を返し、未登録では-1を返す。
    function IndexOfName(const Value: string): Integer;
    // Groups.jsonを検証して読み込み、成功時だけTrueを返す。
    function LoadFromFile: Boolean;
    // カタログに存在しないFaceUIDを全グループから除き、変更時にTrueを返す。
    function RemoveUnknownFaces(Catalog: TPmxFaceCatalogStorage): Boolean;
    // 指定FaceUIDを全グループから取り除く。
    procedure RemoveFaceFromAll(const FaceId: string);
    // 現在の名称、順序、FaceUID所属順をGroups.jsonへ保存する。
    function SaveToFile: Boolean;
    // 現在読み込まれているグループ数と順序付き項目を公開する。
    property Count: Integer read GetCount;
    property Items[Index: Integer]: TPmxFaceCatalogGroup read GetItem; default;
  end;

implementation

uses
  Winapi.Windows,
  System.IOUtils, System.JSON, System.SysUtils;

const
  GroupFormatVersion = 1;

constructor TPmxFaceCatalogGroup.Create;
begin
  inherited;
  FFaceIds := TStringList.Create;
  FFaceIds.CaseSensitive := False;
  FFaceIds.Duplicates := dupIgnore;
end;

destructor TPmxFaceCatalogGroup.Destroy;
begin
  FFaceIds.Free;
  inherited;
end;

procedure TPmxFaceCatalogGroup.AddFaceId(const Value: string; Index: Integer);
var
  S: string;
begin
  S := Trim(Value);
  if (S = '') or (FFaceIds.IndexOf(S) >= 0) then Exit;
  if (Index >= 0) and (Index <= FFaceIds.Count) then FFaceIds.Insert(Index, S)
  else FFaceIds.Add(S);
end;

procedure TPmxFaceCatalogGroup.ExchangeFace(Index1, Index2: Integer);
begin
  if (Index1 < 0) or (Index1 >= FFaceIds.Count) or
    (Index2 < 0) or (Index2 >= FFaceIds.Count) then Exit;
  FFaceIds.Exchange(Index1, Index2);
end;

function TPmxFaceCatalogGroup.IndexOfFaceId(const Value: string): Integer;
begin
  Result := FFaceIds.IndexOf(Trim(Value));
end;

procedure TPmxFaceCatalogGroup.RemoveFaceId(const Value: string);
var
  Index: Integer;
begin
  Index := IndexOfFaceId(Value);
  if Index >= 0 then FFaceIds.Delete(Index);
end;

constructor TPmxFaceCatalogGroups.Create(const ModelFolder: string);
begin
  inherited Create;
  FFileName := TPath.Combine(TPath.Combine(ModelFolder, 'Faces'),
    'Groups.json');
  FItems := TObjectList<TPmxFaceCatalogGroup>.Create(True);
end;

destructor TPmxFaceCatalogGroups.Destroy;
begin
  FItems.Free;
  inherited;
end;

function TPmxFaceCatalogGroups.CreateId: string;
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

function TPmxFaceCatalogGroups.GetCount: Integer;
begin
  Result := FItems.Count;
end;

function TPmxFaceCatalogGroups.GetItem(Index: Integer): TPmxFaceCatalogGroup;
begin
  Result := FItems[Index];
end;

function TPmxFaceCatalogGroups.Add(
  const GroupName: string): TPmxFaceCatalogGroup;
begin
  Result := nil;
  if (Trim(GroupName) = '') or (IndexOfName(GroupName) >= 0) then Exit;
  Result := TPmxFaceCatalogGroup.Create;
  Result.Id := CreateId;
  if Result.Id = '' then
  begin
    Result.Free;
    Exit(nil);
  end;
  Result.Name := Trim(GroupName);
  FItems.Add(Result);
end;

procedure TPmxFaceCatalogGroups.AssignFaceToGroup(const FaceId: string;
  GroupIndex, InsertIndex: Integer);
begin
  if GroupIndexOfFace(FaceId) = GroupIndex then Exit;
  RemoveFaceFromAll(FaceId);
  if (GroupIndex >= 0) and (GroupIndex < Count) then
    FItems[GroupIndex].AddFaceId(FaceId, InsertIndex);
end;

procedure TPmxFaceCatalogGroups.Delete(Index: Integer);
begin
  if (Index >= 0) and (Index < Count) then FItems.Delete(Index);
end;

procedure TPmxFaceCatalogGroups.Exchange(Index1, Index2: Integer);
begin
  if (Index1 < 0) or (Index1 >= Count) or
    (Index2 < 0) or (Index2 >= Count) then Exit;
  FItems.Exchange(Index1, Index2);
end;

function TPmxFaceCatalogGroups.GroupIndexOfFace(
  const FaceId: string): Integer;
begin
  for Result := 0 to Count - 1 do
    if FItems[Result].IndexOfFaceId(FaceId) >= 0 then Exit;
  Result := -1;
end;

function TPmxFaceCatalogGroups.IndexOfId(const Value: string): Integer;
begin
  for Result := 0 to Count - 1 do
    if SameText(FItems[Result].Id, Trim(Value)) then Exit;
  Result := -1;
end;

function TPmxFaceCatalogGroups.IndexOfName(const Value: string): Integer;
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

function TPmxFaceCatalogGroups.LoadFromFile: Boolean;
var
  FaceArray, GroupArray: TJSONArray;
  FaceValue, GroupValue, RootValue: TJSONValue;
  Group: TPmxFaceCatalogGroup;
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
        Group := TPmxFaceCatalogGroup.Create;
        Group.Id := JsonString(Obj, 'id');
        Group.Name := Trim(JsonString(Obj, 'name'));
        FaceArray := Obj.GetValue<TJSONArray>('faceIds');
        if Assigned(FaceArray) then
          for J := 0 to FaceArray.Count - 1 do
          begin
            FaceValue := FaceArray.Items[J];
            if FaceValue is TJSONString then
              Group.AddFaceId(TJSONString(FaceValue).Value);
          end;
        if (Group.Id = '') or (Group.Name = '') or
          (IndexOfId(Group.Id) >= 0) or (IndexOfName(Group.Name) >= 0) then
          Group.Free
        else FItems.Add(Group);
      end;
      Result := True;
    finally
      RootValue.Free;
    end;
  except
    FItems.Clear;
  end;
end;

function TPmxFaceCatalogGroups.RemoveUnknownFaces(
  Catalog: TPmxFaceCatalogStorage): Boolean;
var
  Found: Boolean;
  I, J, K: Integer;
begin
  Result := False;
  if not Assigned(Catalog) then Exit;
  for I := 0 to Count - 1 do
    for J := FItems[I].FaceIds.Count - 1 downto 0 do
    begin
      Found := False;
      for K := 0 to Catalog.Count - 1 do
        if SameText(Catalog[K].Id, FItems[I].FaceIds[J]) then
        begin
          Found := True;
          Break;
        end;
      if not Found then
      begin
        FItems[I].FaceIds.Delete(J);
        Result := True;
      end;
    end;
end;

procedure TPmxFaceCatalogGroups.RemoveFaceFromAll(const FaceId: string);
var
  I: Integer;
begin
  for I := 0 to Count - 1 do FItems[I].RemoveFaceId(FaceId);
end;

function TPmxFaceCatalogGroups.SaveToFile: Boolean;
var
  FaceArray, GroupArray: TJSONArray;
  Group: TPmxFaceCatalogGroup;
  I: Integer;
  Obj, Root: TJSONObject;
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
        FaceArray := TJSONArray.Create;
        Obj.AddPair('faceIds', FaceArray);
        for I := 0 to Group.FaceIds.Count - 1 do
          FaceArray.Add(Group.FaceIds[I]);
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

