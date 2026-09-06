unit MmdAiPoseEditorForm;

// 既存のモデル設定フォームへ、Codex候補の受信状態とライブ姿勢適用を追加する。

interface

uses
  Winapi.Messages,
  System.Classes,
  Vcl.StdCtrls,
  DarkLabel,
  DarkPanel,
  MmdAiPoseSession,
  MmdModelSettingEditor,
  MmdPoseEditorComboTheme;

type
  TMmdAiPoseEditorForm = class(TMmdModelSettingEditorForm)
  private
    FAiPanel: TDarkPanel;
    FCandidateLabel: TDarkLabel;
    FDisplayCombo: TMmdDarkComboBox;
    FModelFile: string;
    FPoseName: string;
    FSessionId: string;
    FSessionRegistered: Boolean;
    FStatusLabel: TDarkLabel;
    procedure ApplyDisplayMode;
    procedure DisplayModeChanged(Sender: TObject);
    procedure WmAiPose(var Message: TMessage);
      message WM_MMD_AI_PREVIEW_SESSION_POSE;
  protected
    procedure DoShow; override;
    procedure PoseStateChanged; override;
  public
    // 共通設定フォームを生成し、Codexが識別するモデルとポーズ名を保持する。
    constructor CreateAiEditor(const ModelFileName, PoseData,
      EditorCaption, PoseName: string);
    destructor Destroy; override;
    property AiStatusLabel: TDarkLabel read FStatusLabel;
    property DisplayCombo: TMmdDarkComboBox read FDisplayCombo;
  end;

// 初期状態の全設定をAI対応フォームで編集し、確定時だけ呼出元へ返す。
function EditMmdAiInitialStateSettings(const ModelFileName, CurrentPoseData,
  CurrentExpressionData, CurrentEyeBlinkData, CurrentLipSyncData,
  EditorCaption, PoseName: string; out NewPoseData, NewExpressionData,
  NewEyeBlinkData, NewLipSyncData: string): Boolean;
// ポーズ専用のAI対応フォームを開き、確定時だけ姿勢を返す。
function EditMmdAiPoseOnlySettings(const ModelFileName, CurrentPoseData,
  EditorCaption, PoseName: string; out NewPoseData: string): Boolean;

implementation

uses
  Winapi.Windows,
  System.JSON,
  System.SysUtils,
  Vcl.Controls,
  Vcl.Graphics,
  MmdMorphSettingCodec,
  MmdPoseEditorTheme;

function ReadString(const Root: TJSONObject; const Name,
  DefaultValue: string): string;
var
  Value: TJSONValue;
begin
  Result := DefaultValue;
  Value := Root.GetValue(Name);
  if Value is TJSONString then
    Result := TJSONString(Value).Value;
end;

function NewSessionId: string;
var
  Id: TGUID;
begin
  Result := '';
  if CreateGUID(Id) <> S_OK then
    Exit;
  Result := LowerCase(GUIDToString(Id));
  Result := Result.Replace('{', '').Replace('}', '').Replace('-', '');
end;

constructor TMmdAiPoseEditorForm.CreateAiEditor(const ModelFileName,
  PoseData, EditorCaption, PoseName: string);
var
  PPI: Integer;
begin
  inherited CreateEditor(ModelFileName, PoseData, EditorCaption);
  FModelFile := ModelFileName;
  FPoseName := PoseName;
  FSessionId := NewSessionId;
  PPI := CurrentPPI;
  if PPI <= 0 then
    PPI := 96;

  FAiPanel := TDarkPanel.Create(Self);
  FAiPanel.Parent := Self;
  FAiPanel.Align := alTop;
  FAiPanel.Height := MulDiv(42, PPI, 96);
  FAiPanel.BevelOuter := bvNone;
  FAiPanel.ParentBackground := False;
  FAiPanel.Color := MmdEditorPanel;

  FDisplayCombo := TMmdDarkComboBox.Create(Self);
  FDisplayCombo.Parent := FAiPanel;
  FDisplayCombo.Style := csOwnerDrawFixed;
  FDisplayCombo.Items.Add('通常');
  FDisplayCombo.Items.Add('ボーンのみ');
  FDisplayCombo.Items.Add('通常＋ボーン');
  FDisplayCombo.ItemIndex := 2;
  FDisplayCombo.SetBounds(MulDiv(8, PPI, 96), MulDiv(7, PPI, 96),
    MulDiv(135, PPI, 96), MulDiv(28, PPI, 96));
  FDisplayCombo.OnChange := DisplayModeChanged;

  FCandidateLabel := TDarkLabel.Create(Self);
  FCandidateLabel.Parent := FAiPanel;
  FCandidateLabel.UseThemeFont := False;
  FCandidateLabel.ParentFont := True;
  FCandidateLabel.Caption := 'AI候補: 未受信';
  FCandidateLabel.SetBounds(MulDiv(155, PPI, 96), MulDiv(5, PPI, 96),
    MulDiv(300, PPI, 96), MulDiv(18, PPI, 96));

  FStatusLabel := TDarkLabel.Create(Self);
  FStatusLabel.Parent := FAiPanel;
  FStatusLabel.UseThemeFont := False;
  FStatusLabel.ParentFont := True;
  FStatusLabel.Caption := 'Codexからのポーズを待機中';
  FStatusLabel.SetBounds(MulDiv(155, PPI, 96), MulDiv(21, PPI, 96),
    MulDiv(600, PPI, 96), MulDiv(18, PPI, 96));
  FStatusLabel.Anchors := [akLeft, akTop, akRight];
  ApplyDisplayMode;
end;

destructor TMmdAiPoseEditorForm.Destroy;
begin
  if FSessionRegistered and HandleAllocated then
    UnregisterMmdAiPoseSession(Handle);
  inherited Destroy;
end;

procedure TMmdAiPoseEditorForm.DoShow;
begin
  inherited DoShow;
  if FSessionRegistered then
    Exit;
  RegisterMmdAiPoseSession(Handle, FSessionId, FModelFile, FPoseName,
    EncodeCurrentPose);
  FSessionRegistered := True;
end;

procedure TMmdAiPoseEditorForm.PoseStateChanged;
begin
  inherited PoseStateChanged;
  if FSessionRegistered and HandleAllocated then
    UpdateMmdAiPoseSession(Handle, EncodeCurrentPose);
end;

procedure TMmdAiPoseEditorForm.ApplyDisplayMode;
begin
  case FDisplayCombo.ItemIndex of
    0: FViewport.SetDisplayVisibility(True, False);
    1: FViewport.SetDisplayVisibility(False, True);
  else
    FViewport.SetDisplayVisibility(True, True);
  end;
end;

procedure TMmdAiPoseEditorForm.DisplayModeChanged(Sender: TObject);
begin
  ApplyDisplayMode;
end;

procedure TMmdAiPoseEditorForm.WmAiPose(var Message: TMessage);
var
  CandidateId, ErrorText, PoseData, PoseName, SessionId, Text: string;
  Root: TJSONObject;
  Value: TJSONValue;
begin
  ErrorText := '';
  try
    if not TakePendingMmdAiSessionPose(Text) then
      ErrorText := 'AI候補データがありません。'
    else
    begin
      Value := TJSONObject.ParseJSONValue(Text);
      try
        if not (Value is TJSONObject) then
          raise EArgumentException.Create('AI候補がJSON objectではありません。');
        Root := TJSONObject(Value);
        SessionId := ReadString(Root, 'session_id', '');
        if not SameText(SessionId, FSessionId) then
          raise EInvalidOperation.Create('ポーズ編集セッションが変更されました。');
        PoseData := ReadString(Root, 'pose_data', '');
        if not ApplyExternalPose(PoseData) then
          raise EArgumentException.Create('AI候補のポーズデータが不正です。');
        PoseName := ReadString(Root, 'pose_name', FPoseName);
        CandidateId := ReadString(Root, 'candidate_id', '');
        FCandidateLabel.Caption := 'AI候補: ' + PoseName;
        if CandidateId <> '' then
          FStatusLabel.Caption := '反映済み: ' + CandidateId
        else
          FStatusLabel.Caption := 'AI候補を反映しました。';
        FStatusLabel.TextColor := MmdEditorText;
        ApplyDisplayMode;
      finally
        Value.Free;
      end;
    end;
  except
    on E: Exception do
    begin
      ErrorText := E.Message;
      FStatusLabel.Caption := 'AI候補の反映エラー: ' + ErrorText;
      FStatusLabel.TextColor := clRed;
    end;
  end;
  CompleteMmdAiSessionPose(ErrorText);
  Message.Result := Ord(ErrorText = '');
end;

function EditMmdAiInitialStateSettings(const ModelFileName, CurrentPoseData,
  CurrentExpressionData, CurrentEyeBlinkData, CurrentLipSyncData,
  EditorCaption, PoseName: string; out NewPoseData, NewExpressionData,
  NewEyeBlinkData, NewLipSyncData: string): Boolean;
var
  Form: TMmdAiPoseEditorForm;
  PoseData: string;
begin
  Result := False;
  NewPoseData := CurrentPoseData;
  NewExpressionData := CurrentExpressionData;
  NewEyeBlinkData := CurrentEyeBlinkData;
  NewLipSyncData := CurrentLipSyncData;
  PoseData := CurrentPoseData;
  if PoseData = '' then
    PoseData := '{"version":1,"bones":[]}';
  Form := TMmdAiPoseEditorForm.CreateAiEditor(ModelFileName, PoseData,
    EditorCaption, PoseName);
  try
    Form.ConfigureSettingControls(True);
    Form.InitializeExpression(CurrentExpressionData);
    Form.InitializeEyeBlink(CurrentEyeBlinkData);
    Form.InitializeLipSync(CurrentLipSyncData);
    if Form.ShowModal <> mrOk then
      Exit;
    NewPoseData := Form.EncodeCurrentPose;
    NewExpressionData := Form.EncodeExpression;
    NewEyeBlinkData := Form.EncodeEyeBlink;
    NewLipSyncData := Form.EncodeLipSync;
    Result := True;
  finally
    Form.Free;
  end;
end;

function EditMmdAiPoseOnlySettings(const ModelFileName, CurrentPoseData,
  EditorCaption, PoseName: string; out NewPoseData: string): Boolean;
var
  Form: TMmdAiPoseEditorForm;
  PoseData: string;
begin
  Result := False;
  NewPoseData := CurrentPoseData;
  PoseData := CurrentPoseData;
  if PoseData = '' then
    PoseData := '{"version":1,"bones":[]}';
  Form := TMmdAiPoseEditorForm.CreateAiEditor(ModelFileName, PoseData,
    EditorCaption, PoseName);
  try
    Form.ConfigureSettingControls(False, True);
    if Form.ShowModal <> mrOk then
      Exit;
    NewPoseData := Form.EncodeCurrentPose;
    Result := True;
  finally
    Form.Free;
  end;
end;

end.
