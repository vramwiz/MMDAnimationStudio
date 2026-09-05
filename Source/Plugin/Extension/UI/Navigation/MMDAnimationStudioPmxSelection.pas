unit MMDAnimationStudioPmxSelection;

// PMX管理・ポーズ・モーション・表情ページ間で選択中PmxUIDを同期する。

interface

uses
  System.Classes,
  PmxCatalogFrame,
  MmdPoseCatalogFrame,
  MmdMotionCatalogFrame,
  MmdFaceCatalogFrame;

// Senderの選択を正本として他ページへ反映する。再入中は何も変更しない。
procedure SynchronizeMmdStudioPmxSelection(Sender: TObject;
  PmxFrame: TFramePmxCatalog; PoseFrame: TFrameMmdPoseCatalog;
  MotionFrame: TFrameMmdMotionCatalog; FaceFrame: TFrameMmdFaceCatalog;
  var SelectedPmxId: string; var Syncing: Boolean);

implementation

procedure SynchronizeMmdStudioPmxSelection(Sender: TObject;
  PmxFrame: TFramePmxCatalog; PoseFrame: TFrameMmdPoseCatalog;
  MotionFrame: TFrameMmdMotionCatalog; FaceFrame: TFrameMmdFaceCatalog;
  var SelectedPmxId: string; var Syncing: Boolean);
begin
  if Syncing then
    Exit;
  Syncing := True;
  try
    if Sender = PmxFrame then
    begin
      SelectedPmxId := PmxFrame.SelectedPmxId;
      if Assigned(PoseFrame) then
        PoseFrame.SetCatalog(PmxFrame.Catalog);
      if Assigned(FaceFrame) then
        FaceFrame.SetCatalog(PmxFrame.Catalog);
      if Assigned(MotionFrame) then
        MotionFrame.SetCatalog(PmxFrame.Catalog);
    end
    else if Sender = PoseFrame then
      SelectedPmxId := PoseFrame.PmxSelector.SelectedPmxId
    else if Sender = MotionFrame then
      SelectedPmxId := MotionFrame.PmxSelector.SelectedPmxId
    else if Sender = FaceFrame then
      SelectedPmxId := FaceFrame.PmxSelector.SelectedPmxId;
    if Assigned(PmxFrame) and (Sender <> PmxFrame) then
      PmxFrame.SelectPmxId(SelectedPmxId);
    if Assigned(PoseFrame) and (Sender <> PoseFrame) then
      PoseFrame.SelectPmxId(SelectedPmxId);
    if Assigned(MotionFrame) and (Sender <> MotionFrame) then
      MotionFrame.SelectPmxId(SelectedPmxId);
    if Assigned(FaceFrame) and (Sender <> FaceFrame) then
      FaceFrame.SelectPmxId(SelectedPmxId);
  finally
    Syncing := False;
  end;
end;

end.
