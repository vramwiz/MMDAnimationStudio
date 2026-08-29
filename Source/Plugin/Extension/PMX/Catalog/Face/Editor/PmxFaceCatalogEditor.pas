unit PmxFaceCatalogEditor;

// PMX別FaceUID項目を共通のモーフ設定フォームへ接続する。

interface

uses
  PmxCatalogStorage,
  PmxFaceCatalogStorage;

// 共通画面を表情専用構成で開き、確定時だけItemのモーフJSONを書き換える。
function EditPmxFaceCatalogFace(Model: TPmxCatalogItem;
  Item: TPmxFaceCatalogItem): Boolean;

implementation

uses
  System.SysUtils,
  MmdModelSettingDialogs;

function EditPmxFaceCatalogFace(Model: TPmxCatalogItem;
  Item: TPmxFaceCatalogItem): Boolean;
var
  NewFaceData: string;
begin
  Result := False;
  if not Assigned(Model) or not Assigned(Item) or
    not FileExists(Model.SourcePath) then Exit;
  if not EditMmdFaceOnlySettings(Model.SourcePath, Item.FaceData,
    Format('MMD %s - %s', [#$8868#$60C5, Item.Name]), NewFaceData) then Exit;
  Item.FaceData := NewFaceData;
  Result := True;
end;

end.
