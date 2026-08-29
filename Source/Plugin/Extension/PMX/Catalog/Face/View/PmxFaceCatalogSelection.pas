unit PmxFaceCatalogSelection;

// 表情カタログと任意グループから、一覧表示に使うFaceUID順を解決する。

interface

uses
  System.Generics.Collections,
  PmxFaceCatalogGroups,
  PmxFaceCatalogStorage;

// FaceUIDに対応するカタログ番号を返し、存在しない場合は-1を返す。
function FindPmxFaceCatalogIndex(Catalog: TPmxFaceCatalogStorage;
  const FaceId: string): Integer;
// -1ならカタログ全件、それ以外なら指定グループの有効FaceUIDだけを表示順で返す。
procedure BuildPmxFaceDisplayIndices(Catalog: TPmxFaceCatalogStorage;
  Groups: TPmxFaceCatalogGroups; GroupIndex: Integer;
  Dest: TList<Integer>);

implementation

uses
  System.SysUtils;

function FindPmxFaceCatalogIndex(Catalog: TPmxFaceCatalogStorage;
  const FaceId: string): Integer;
begin
  if Assigned(Catalog) then
    for Result := 0 to Catalog.Count - 1 do
      if SameText(Catalog[Result].Id, FaceId) then
        Exit;
  Result := -1;
end;

procedure BuildPmxFaceDisplayIndices(Catalog: TPmxFaceCatalogStorage;
  Groups: TPmxFaceCatalogGroups; GroupIndex: Integer;
  Dest: TList<Integer>);
var
  I, SourceIndex: Integer;
begin
  if not Assigned(Dest) then
    Exit;
  Dest.Clear;
  if not Assigned(Catalog) then
    Exit;
  if Assigned(Groups) and (GroupIndex >= 0) and
    (GroupIndex < Groups.Count) then
    for I := 0 to Groups[GroupIndex].FaceIds.Count - 1 do
    begin
      SourceIndex := FindPmxFaceCatalogIndex(Catalog,
        Groups[GroupIndex].FaceIds[I]);
      if SourceIndex >= 0 then
        Dest.Add(SourceIndex);
    end
  else
    for I := 0 to Catalog.Count - 1 do
      Dest.Add(I);
end;

end.
