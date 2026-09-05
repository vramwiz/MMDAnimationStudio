unit PmxPoseCatalogEditSession;

// PMX管理のポーズ編集結果を保存し、失敗時は編集前の全設定へ戻す。

interface

uses
  PmxCatalogStorage,
  PmxPoseCatalogStorage;

// ModelとPoseを設定画面で編集してStorageへ保存する。キャンセル時はFalse、保存失敗時は例外を返す。
function EditAndSavePmxPoseCatalogItem(Model: TPmxCatalogItem;
  Pose: TPmxPoseCatalogItem;
  Storage: TPmxPoseCatalogStorage): Boolean;

implementation

uses
  System.SysUtils,
  PmxPoseCatalogEditor;

function EditAndSavePmxPoseCatalogItem(Model: TPmxCatalogItem;
  Pose: TPmxPoseCatalogItem;
  Storage: TPmxPoseCatalogStorage): Boolean;
var
  OldInitialEyeBlinkData: string;
  OldInitialExpressionData: string;
  OldInitialLipSyncData: string;
  OldPoseData: string;
begin
  Result := False;
  OldInitialEyeBlinkData := Pose.InitialEyeBlinkData;
  OldInitialExpressionData := Pose.InitialExpressionData;
  OldInitialLipSyncData := Pose.InitialLipSyncData;
  OldPoseData := Pose.PoseData;
  if not EditPmxPoseCatalogItem(Model, Pose) then
    Exit;
  if Storage.SaveToFile then
    Exit(True);
  Pose.InitialEyeBlinkData := OldInitialEyeBlinkData;
  Pose.InitialExpressionData := OldInitialExpressionData;
  Pose.InitialLipSyncData := OldInitialLipSyncData;
  Pose.PoseData := OldPoseData;
  raise EInOutError.Create(
    #$30DD#$30FC#$30BA#$30C7#$30FC#$30BF#$3092#$4FDD#$5B58#$3067#$304D#$307E#$305B#$3093#$3067#$3057#$305F);
end;

end.
