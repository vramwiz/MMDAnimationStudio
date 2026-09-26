unit MmdAiPoseStudioIntegration;

// AIポーズ要求と、PMX別VPDカタログの永続化・表示更新を接続する。

interface

uses
  PmxCatalogFrame,
  MmdPoseCatalogFrame;

// 選択中PMXの識別情報をCodex向けの読取コンテキストへ公開する。
procedure PublishMmdAiCatalogContext(PmxFrame: TFramePmxCatalog;
  const SelectedPmxId: string);
// 完成姿勢をVPDとPoseUIDへ登録し、表示中の該当一覧を更新する。
function RegisterMmdAiPoseCandidate(PmxFrame: TFramePmxCatalog;
  PoseFrame: TFrameMmdPoseCatalog; const SelectedPmxId, PmxId,
  ModelFile, PoseName, PoseData: string; out RegisteredPmxId, PoseFile,
  PoseId, ErrorText: string): Boolean;

implementation

uses
  System.IOUtils,
  System.SysUtils,
  MmdAiPoseCatalogBridge,
  MmdAiPoseRepository,
  MmdAiPoseSession,
  MmdVpdPoseImporter,
  PmxCatalogStorage,
  PmxPoseCatalogGroups,
  PmxPoseCatalogStorage;

procedure PublishMmdAiCatalogContext(PmxFrame: TFramePmxCatalog;
  const SelectedPmxId: string);
var
  Model: TPmxCatalogItem;
begin
  Model := nil;
  if Assigned(PmxFrame) and Assigned(PmxFrame.Catalog) and
    (SelectedPmxId <> '') then
    Model := PmxFrame.Catalog.FindById(SelectedPmxId);
  if Assigned(Model) then
    UpdateMmdAiPoseCatalogContext(Model.Id, Model.SourcePath,
      Model.DisplayName)
  else
    UpdateMmdAiPoseCatalogContext('', '', '');
end;

function RegisterMmdAiPoseCandidate(PmxFrame: TFramePmxCatalog;
  PoseFrame: TFrameMmdPoseCatalog; const SelectedPmxId, PmxId,
  ModelFile, PoseName, PoseData: string; out RegisteredPmxId, PoseFile,
  PoseId, ErrorText: string): Boolean;
var
  Catalog: TPmxCatalogStorage;
  Groups: TPmxPoseCatalogGroups;
  Index: Integer;
  Model: TPmxCatalogItem;
  Storage: TPmxPoseCatalogStorage;
  Summary: TMmdVpdImportSummary;
begin
  Result := False;
  RegisteredPmxId := '';
  PoseFile := '';
  PoseId := '';
  ErrorText := '';
  Storage := nil;
  Groups := nil;
  try
    try
      if HasActiveMmdAiPoseSession then
      begin
        ErrorText := 'ポーズ設定画面を閉じてからバックグラウンド登録してください。';
        Exit;
      end;
      if not Assigned(PmxFrame) or not Assigned(PmxFrame.Catalog) then
      begin
        ErrorText := 'PMXカタログを読み込めません。';
        Exit;
      end;
      Catalog := PmxFrame.Catalog;
      Model := nil;
      if Trim(PmxId) <> '' then
      begin
        Model := Catalog.FindById(Trim(PmxId));
        if not Assigned(Model) then
        begin
          ErrorText := '指定されたPMX IDは登録されていません。';
          Exit;
        end;
      end
      else if Trim(ModelFile) <> '' then
      begin
        Index := Catalog.IndexOfPath(ModelFile);
        if (Index >= 0) and (Index < Catalog.Count) then
          Model := Catalog.Items[Index];
        if not Assigned(Model) then
        begin
          ErrorText := '指定されたモデルファイルは登録されていません。';
          Exit;
        end;
      end;
      if not Assigned(Model) and (SelectedPmxId <> '') then
        Model := Catalog.FindById(SelectedPmxId);
      if not Assigned(Model) then
      begin
        ErrorText := '登録先PMXを特定できません。';
        Exit;
      end;

      RegisteredPmxId := Model.Id;
      Storage := TPmxPoseCatalogStorage.Create(Catalog.ModelFolder(Model.Id),
        Model.Id, Model.DisplayName);
      if not Storage.LoadOrCreateDefault then
      begin
        ErrorText := '登録先のポーズ一覧を読み込めません。';
        Exit;
      end;
      Groups := TPmxPoseCatalogGroups.Create(Catalog.ModelFolder(Model.Id));
      if not Groups.LoadFromFile then
      begin
        ErrorText := '登録先のポーズグループを読み込めません。';
        Exit;
      end;
      PoseFile := SaveMmdAiPoseFile(PoseName, PoseData);
      if not ImportMmdVpdPoses([PoseFile], '', Storage, Groups, Summary) or
        (Summary.LastPoseId = '') then
      begin
        ErrorText := 'VPDをPMXのポーズ一覧へ登録できません。';
        Exit;
      end;
      PoseId := Summary.LastPoseId;
      // VPDはボーン情報のみなので、独自の全身回転はPoseUID側へ原本を残す。
      for var PoseIndex := 0 to Storage.Count - 1 do
        if Storage[PoseIndex].Id = PoseId then
        begin
          Storage[PoseIndex].PoseData := PoseData;
          if not Storage.SaveToFile then
            raise Exception.Create('全身回転を含むポーズを保存できません。');
          Break;
        end;
      PmxFrame.RefreshPoses(Model.Id, PoseId);
      if Assigned(PoseFrame) then
        PoseFrame.RefreshPoses(Model.Id, PoseId);
      Result := True;
    except
      on E: Exception do
        ErrorText := E.Message;
    end;
    if not Result and (PoseFile <> '') and TFile.Exists(PoseFile) then
      try
        TFile.Delete(PoseFile);
        PoseFile := '';
      except
        { 登録エラーを優先し、作業用VPDの後始末失敗は外へ出さない。 }
      end;
  finally
    Groups.Free;
    Storage.Free;
  end;
end;

end.
