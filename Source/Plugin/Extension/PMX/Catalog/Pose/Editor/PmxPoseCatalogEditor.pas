unit PmxPoseCatalogEditor;

// PMXカタログのポーズ要素を共通のモデル設定フォームへ接続する。

interface

uses
  PmxCatalogStorage,
  PmxPoseCatalogStorage;

// 共通フォームを閉じたとき、Itemへポーズと表情JSONを書き戻す。
function EditPmxPoseCatalogItem(Model: TPmxCatalogItem;
  Item: TPmxPoseCatalogItem): Boolean;

implementation

uses
  System.SysUtils,
  MmdModelSettingDialogs;

function EditPmxPoseCatalogItem(Model: TPmxCatalogItem;
  Item: TPmxPoseCatalogItem): Boolean;
var
  NewExpressionData, NewEyeBlinkData, NewLipSyncData, NewPoseData: string;
begin
  Result := False;
  if not Assigned(Model) or not Assigned(Item) or
    not FileExists(Model.SourcePath) then
    Exit;
  if not EditMmdInitialStateSettings(Model.SourcePath, Item.PoseData,
    Item.InitialExpressionData, Item.InitialEyeBlinkData,
    Item.InitialLipSyncData,
    Format('MMD %s - %s', [#$8A2D#$5B9A, Item.Name]), NewPoseData,
    NewExpressionData, NewEyeBlinkData, NewLipSyncData) then
    Exit;
  Item.PoseData := NewPoseData;
  Item.InitialExpressionData := NewExpressionData;
  Item.InitialEyeBlinkData := NewEyeBlinkData;
  Item.InitialLipSyncData := NewLipSyncData;
  Result := True;
end;

end.
