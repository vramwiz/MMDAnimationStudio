unit MmdAiPreviewMainForm;

// 共通MMDポーズ編集GUIに、AI候補一覧とNamed Pipe受信だけを追加する。

interface

uses
  Winapi.Messages,
  System.Classes,
  Vcl.StdCtrls,
  MmdAiPreviewPipeServer,
  MmdAiPreviewPresentation,
  MmdPoseEditor,
  PmxModel;

type
  TMmdAiPreviewMainForm = class(TStandardPoseEditorForm)
  private
    FCandidateLabel: TLabel;
    FCurrentCandidateId: string;
    FCurrentModelFile: string;
    FCurrentPoseName: string;
    FDisplayCombo: TComboBox;
    FLoadingPose: Boolean;
    FLoadingPoseList: Boolean;
    FOpenModelButton: TButton;
    FPipeServer: TMmdAiPreviewPipeServer;
    FPlaceholderModel: TPmxModel;
    FPoseFiles: TArray<string>;
    FPoseList: TListBox;
    FRuntimeStarted: Boolean;
    FSelectedPoseFile: string;
    FStatusLabel: TLabel;
    procedure ApplyDisplayMode;
    procedure DisplayModeChanged(Sender: TObject);
    function ExtractPoseFile(const FilePath: string; out PoseData,
      PoseName, CandidateId: string): Boolean;
    function GetSettingsFile: string;
    procedure LoadLastModel;
    procedure LoadModel(const FilePath: string; SaveAsLast: Boolean);
    procedure LoadPoseFile(const FilePath: string);
    procedure LoadPresentation(const PresentationText: string);
    procedure OpenModelClick(Sender: TObject);
    procedure PoseListClick(Sender: TObject);
    procedure RefreshPoseList(SelectNewest: Boolean;
      const SelectedFile: string = '');
    procedure SaveSettings;
    procedure SetStatus(const Text: string; Error: Boolean = False);
    procedure WmPresentPose(var Message: TMessage); message WM_MMD_AI_PRESENT_POSE;
  protected
    procedure DoShow; override;
    procedure PoseStateChanged; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  MainForm: TMmdAiPreviewMainForm;

implementation

uses
  System.IOUtils,
  System.JSON,
  System.SysUtils,
  Vcl.Controls,
  Vcl.Dialogs,
  Vcl.ExtCtrls,
  Vcl.Graphics,
  MmdAiPlaceholderModel,
  MmdAiPoseRepository,
  PmxReader;

function ReadJsonString(const Object_: TJSONObject; const Name,
  DefaultValue: string): string;
var
  Value: TJSONValue;
begin
  Result := DefaultValue;
  Value := Object_.GetValue(Name);
  if Value is TJSONString then
    Result := TJSONString(Value).Value;
end;

constructor TMmdAiPreviewMainForm.Create(AOwner: TComponent);
var
  PosePanel, ToolPanel: TPanel;
begin
  inherited Create(AOwner);
  Caption := 'MMDアニメーションスタジオ';
  ShowInTaskBar := True;
  Width := 1180;
  Height := 760;
  Constraints.MinWidth := 900;
  Constraints.MinHeight := 630;
  FButtonPanel.Visible := False;

  ToolPanel := TPanel.Create(Self);
  ToolPanel.Parent := Self;
  ToolPanel.Align := alTop;
  ToolPanel.Height := 52;
  ToolPanel.BevelOuter := bvNone;
  FOpenModelButton := TButton.Create(Self);
  FOpenModelButton.Parent := ToolPanel;
  FOpenModelButton.Caption := 'PMXを開く';
  FOpenModelButton.SetBounds(12, 10, 100, 32);
  FOpenModelButton.OnClick := OpenModelClick;
  FDisplayCombo := TComboBox.Create(Self);
  FDisplayCombo.Parent := ToolPanel;
  FDisplayCombo.Style := csDropDownList;
  FDisplayCombo.Items.Add('通常');
  FDisplayCombo.Items.Add('ボーンのみ');
  FDisplayCombo.Items.Add('通常＋ボーン');
  // 編集アプリではボーンを操作できる状態を初期値にする。
  // 「通常」を明示的に選んだ場合だけ骨格オーバーレイを隠す。
  FDisplayCombo.ItemIndex := 2;
  FDisplayCombo.SetBounds(120, 12, 140, 28);
  FDisplayCombo.OnChange := DisplayModeChanged;
  FCandidateLabel := TLabel.Create(Self);
  FCandidateLabel.Parent := ToolPanel;
  FCandidateLabel.Caption := '候補: 未受信';
  FCandidateLabel.SetBounds(278, 17, 850, 24);

  PosePanel := TPanel.Create(Self);
  PosePanel.Parent := FLeftPanel;
  PosePanel.Align := alTop;
  PosePanel.Height := 220;
  PosePanel.BevelOuter := bvNone;
  FPoseList := TListBox.Create(Self);
  FPoseList.Parent := PosePanel;
  FPoseList.Align := alClient;
  FPoseList.OnClick := PoseListClick;
  FStatusLabel := TLabel.Create(Self);
  FStatusLabel.Parent := PosePanel;
  FStatusLabel.Align := alBottom;
  FStatusLabel.AutoSize := False;
  FStatusLabel.Height := 60;
  FStatusLabel.WordWrap := True;
  FStatusLabel.Caption := '保存ポーズを読み込んでいます。';

  FViewport.ShowHint := True;
  FViewport.Hint := 'ボーン選択とドラッグで編集 / 右ドラッグ: 回転 / ホイール: 拡大縮小';
  FPipeServer := TMmdAiPreviewPipeServer.Create;
  FPlaceholderModel := CreateMmdPlaceholderModel;
  FLoadingPose := True;
  try
    LoadEditorModel(FPlaceholderModel, '');
    LoadLastModel;
    RefreshPoseList(True);
  finally
    FLoadingPose := False;
  end;
end;

destructor TMmdAiPreviewMainForm.Destroy;
begin
  if FRuntimeStarted then
    UnregisterMmdAiPresentationWindow(Handle);
  FPipeServer.Free;
  FViewport.SetScene(nil, FPoses, -1);
  FPlaceholderModel.Free;
  inherited Destroy;
end;

procedure TMmdAiPreviewMainForm.DoShow;
begin
  inherited DoShow;
  if FRuntimeStarted then Exit;
  RegisterMmdAiPresentationWindow(Handle);
  try
    FPipeServer.Start;
    FRuntimeStarted := True;
  except
    UnregisterMmdAiPresentationWindow(Handle);
    raise;
  end;
end;

procedure TMmdAiPreviewMainForm.SetStatus(const Text: string; Error: Boolean);
begin
  FStatusLabel.Caption := Text;
  if Error then FStatusLabel.Font.Color := clRed
  else FStatusLabel.Font.Color := clWindowText;
end;

function TMmdAiPreviewMainForm.GetSettingsFile: string;
var
  BaseDirectory: string;
begin
  BaseDirectory := GetEnvironmentVariable('LOCALAPPDATA');
  if BaseDirectory = '' then BaseDirectory := TPath.GetHomePath;
  Result := TPath.Combine(TPath.Combine(BaseDirectory,
    'MMDAnimationStudio'), 'settings.json');
end;

procedure TMmdAiPreviewMainForm.SaveSettings;
var
  Root: TJSONObject;
  SettingsFile: string;
begin
  if FCurrentModelFile = '' then Exit;
  SettingsFile := GetSettingsFile;
  TDirectory.CreateDirectory(TPath.GetDirectoryName(SettingsFile));
  Root := TJSONObject.Create;
  try
    Root.AddPair('last_model_file', FCurrentModelFile);
    TFile.WriteAllText(SettingsFile, Root.Format(2), TEncoding.UTF8);
  finally
    Root.Free;
  end;
end;

procedure TMmdAiPreviewMainForm.LoadLastModel;
var
  FilePath, SettingsFile: string;
  RootValue: TJSONValue;
begin
  SettingsFile := GetSettingsFile;
  if not TFile.Exists(SettingsFile) then Exit;
  RootValue := TJSONObject.ParseJSONValue(
    TFile.ReadAllText(SettingsFile, TEncoding.UTF8));
  try
    if not (RootValue is TJSONObject) then Exit;
    FilePath := ReadJsonString(TJSONObject(RootValue),
      'last_model_file', '');
    if (FilePath <> '') and TFile.Exists(FilePath) then
      LoadModel(FilePath, False);
  finally
    RootValue.Free;
  end;
end;

procedure TMmdAiPreviewMainForm.LoadModel(const FilePath: string;
  SaveAsLast: Boolean);
var
  FullPath, PoseData: string;
begin
  FullPath := TPath.GetFullPath(FilePath);
  if not TFile.Exists(FullPath) then
    raise EFileNotFoundException.CreateFmt('PMXが見つかりません: %s', [FullPath]);
  PoseData := EncodeCurrentPose;
  FLoadingPose := True;
  try
    LoadEditorModel(GetCachedPmxModel(FullPath), PoseData);
  finally
    FLoadingPose := False;
  end;
  FCurrentModelFile := FullPath;
  ApplyDisplayMode;
  if SaveAsLast then SaveSettings;
  SetStatus(Format('%s / ボーン %d / テクスチャ %d',
    [ExtractFileName(FCurrentModelFile), Length(FModel.Bones),
     FViewport.LoadedTextureCount]));
end;

procedure TMmdAiPreviewMainForm.ApplyDisplayMode;
begin
  case FDisplayCombo.ItemIndex of
    0: FViewport.SetDisplayVisibility(True, False);
    1: FViewport.SetDisplayVisibility(False, True);
  else
    FViewport.SetDisplayVisibility(True, True);
  end;
end;

procedure TMmdAiPreviewMainForm.DisplayModeChanged(Sender: TObject);
begin
  ApplyDisplayMode;
end;

procedure TMmdAiPreviewMainForm.LoadPoseFile(const FilePath: string);
var
  CandidateId, PoseData, PoseName: string;
begin
  if not ExtractPoseFile(FilePath, PoseData, PoseName, CandidateId) then
    raise EArgumentException.Create('ポーズデータが空です。');
  FLoadingPose := True;
  try
    LoadEditorModel(FModel, PoseData);
  finally
    FLoadingPose := False;
  end;
  FSelectedPoseFile := FilePath;
  FCurrentPoseName := PoseName;
  FCurrentCandidateId := CandidateId;
  FCandidateLabel.Caption := '候補: ' + PoseName;
  ApplyDisplayMode;
  SetStatus('ポーズを選択しました: ' + ExtractFileName(FilePath));
end;

procedure TMmdAiPreviewMainForm.PoseListClick(Sender: TObject);
begin
  if FLoadingPoseList or (FPoseList.ItemIndex < 0) or
     (FPoseList.ItemIndex >= Length(FPoseFiles)) then Exit;
  try
    LoadPoseFile(FPoseFiles[FPoseList.ItemIndex]);
  except
    on E: Exception do SetStatus('ポーズ読込みエラー: ' + E.Message, True);
  end;
end;

procedure TMmdAiPreviewMainForm.RefreshPoseList(SelectNewest: Boolean;
  const SelectedFile: string);
var
  I, J, SelectedIndex: Integer;
  Files: TArray<string>;
  Temp: string;
begin
  TDirectory.CreateDirectory(GetMmdAiPoseDirectory);
  Files := TDirectory.GetFiles(GetMmdAiPoseDirectory, '*.json');
  for I := 0 to High(Files) - 1 do
    for J := I + 1 to High(Files) do
      if TFile.GetLastWriteTimeUtc(Files[J]) > TFile.GetLastWriteTimeUtc(Files[I]) then
      begin
        Temp := Files[I]; Files[I] := Files[J]; Files[J] := Temp;
      end;
  FPoseFiles := Files;
  SelectedIndex := -1;
  FLoadingPoseList := True;
  FPoseList.Items.BeginUpdate;
  try
    FPoseList.Clear;
    for I := 0 to High(FPoseFiles) do
    begin
      FPoseList.Items.Add(ExtractFileName(FPoseFiles[I]));
      if (SelectedFile <> '') and SameText(TPath.GetFullPath(FPoseFiles[I]),
        TPath.GetFullPath(SelectedFile)) then SelectedIndex := I;
    end;
    if (SelectedIndex < 0) and SelectNewest and (Length(FPoseFiles) > 0) then
      SelectedIndex := 0;
    FPoseList.ItemIndex := SelectedIndex;
  finally
    FPoseList.Items.EndUpdate;
    FLoadingPoseList := False;
  end;
  if SelectedIndex >= 0 then LoadPoseFile(FPoseFiles[SelectedIndex]);
end;

procedure TMmdAiPreviewMainForm.OpenModelClick(Sender: TObject);
var
  Dialog: TOpenDialog;
begin
  Dialog := TOpenDialog.Create(Self);
  try
    Dialog.Filter := 'PMXモデル (*.pmx)|*.pmx|すべてのファイル (*.*)|*.*';
    if FCurrentModelFile <> '' then Dialog.FileName := FCurrentModelFile;
    if Dialog.Execute then
      try LoadModel(Dialog.FileName, True);
      except on E: Exception do SetStatus('PMX読込みエラー: ' + E.Message, True); end;
  finally
    Dialog.Free;
  end;
end;

function TMmdAiPreviewMainForm.ExtractPoseFile(const FilePath: string;
  out PoseData, PoseName, CandidateId: string): Boolean;
var
  RootValue: TJSONValue;
  Text: string;
begin
  Text := TFile.ReadAllText(FilePath, TEncoding.UTF8);
  PoseData := Text;
  PoseName := ChangeFileExt(ExtractFileName(FilePath), '');
  CandidateId := '';
  RootValue := TJSONObject.ParseJSONValue(Text);
  try
    if RootValue is TJSONObject then
    begin
      if TJSONObject(RootValue).GetValue('pose_data') is TJSONString then
        PoseData := TJSONString(TJSONObject(RootValue).GetValue('pose_data')).Value;
      PoseName := ReadJsonString(TJSONObject(RootValue), 'name', PoseName);
      CandidateId := ReadJsonString(TJSONObject(RootValue), 'candidate_id', '');
    end;
  finally
    RootValue.Free;
  end;
  Result := PoseData <> '';
end;

procedure TMmdAiPreviewMainForm.PoseStateChanged;
begin
  inherited PoseStateChanged;
  if FLoadingPose or (FSelectedPoseFile = '') then Exit;
  try
    UpdateMmdAiPoseFile(FSelectedPoseFile, FCurrentPoseName,
      FCurrentCandidateId, EncodeCurrentPose);
    SetStatus('微調整を自動保存しました: ' + ExtractFileName(FSelectedPoseFile));
  except
    on E: Exception do SetStatus('ポーズ保存エラー: ' + E.Message, True);
  end;
end;

procedure TMmdAiPreviewMainForm.LoadPresentation(const PresentationText: string);
var
  ModelFile, PoseData, PoseFile: string;
  RootValue: TJSONValue;
begin
  RootValue := TJSONObject.ParseJSONValue(PresentationText);
  try
    if not (RootValue is TJSONObject) then
      raise EArgumentException.Create('提示データがJSON objectではありません。');
    ModelFile := ReadJsonString(TJSONObject(RootValue), 'model_file', '');
    PoseData := ReadJsonString(TJSONObject(RootValue), 'pose_data', '');
    PoseFile := ReadJsonString(TJSONObject(RootValue), 'pose_file', '');
    if PoseData = '' then raise EArgumentException.Create('pose_dataがありません。');
    if (ModelFile <> '') and not SameText(FCurrentModelFile,
      TPath.GetFullPath(ModelFile)) then LoadModel(ModelFile, True);
    FLoadingPose := True;
    try LoadEditorModel(FModel, PoseData);
    finally FLoadingPose := False; end;
    FSelectedPoseFile := PoseFile;
    RefreshPoseList(False, PoseFile);
    FCurrentCandidateId := ReadJsonString(TJSONObject(RootValue), 'candidate_id', '');
    FCurrentPoseName := ReadJsonString(TJSONObject(RootValue), 'pose_name', '新しいポーズ');
    FCandidateLabel.Caption := '候補: ' + FCurrentPoseName;
    ApplyDisplayMode;
    SetStatus('AIが作成した最新ポーズを編集表示しています: ' + ExtractFileName(PoseFile));
  finally
    RootValue.Free;
  end;
end;

procedure TMmdAiPreviewMainForm.WmPresentPose(var Message: TMessage);
var
  ErrorText, PresentationText: string;
begin
  ErrorText := '';
  try
    if not TakePendingMmdAiPresentation(PresentationText) then
      ErrorText := '提示待ちデータがありません。'
    else LoadPresentation(PresentationText);
  except
    on E: Exception do
    begin ErrorText := E.Message; SetStatus('候補表示エラー: ' + ErrorText, True); end;
  end;
  CompleteMmdAiPresentation(ErrorText);
  Message.Result := Ord(ErrorText = '');
end;

end.
