program MmdAiPoseEditorSessionTest;

{$APPTYPE CONSOLE}

uses
  Winapi.Windows,
  Winapi.Messages,
  System.JSON,
  System.SysUtils,
  System.UITypes,
  Vcl.ExtCtrls,
  Vcl.Forms,
  Vcl.StdCtrls,
  MmdPoseEditorButtonTheme,
  MmdSimpleControllerPanel,
  MmdSimpleControllerSolver,
  MmdAiPoseEditorForm,
  MmdAiPoseSession;

type
  TTestAiPoseEditor = class(TMmdAiPoseEditorForm)
  private
    FTestConnected: Boolean;
  protected
    function ProControllerAvailable: Boolean; override;
  public
    function FirstBoneName: string;
    function DetailedVisible: Boolean;
    procedure ClickModeButton;
    function MarkerBone: Integer;
    function SelectedSimpleTarget: Integer;
    procedure SelectNextSimpleController;
    procedure SelectEyeController;
    procedure SetupSimpleMode;
    property TestConnected: Boolean read FTestConnected write FTestConnected;
    function UndoEnabled: Boolean;
    procedure UndoForTest;
  end;

  TAutoClose = class
  private
    FTimer: TTimer;
    FApplied: Boolean;
    FCancelInstead: Boolean;
    procedure Tick(Sender: TObject);
  public
    constructor Create;
    destructor Destroy; override;
    property Applied: Boolean read FApplied;
    property CancelInstead: Boolean read FCancelInstead
      write FCancelInstead;
  end;

constructor TAutoClose.Create;
begin
  inherited Create;
  FTimer := TTimer.Create(nil);
  FTimer.Interval := 50;
  FTimer.OnTimer := Tick;
end;

destructor TAutoClose.Destroy;
begin
  FTimer.Free;
  inherited;
end;

procedure TAutoClose.Tick(Sender: TObject);
begin
  if Screen.ActiveForm is TMmdAiPoseEditorForm then
  begin
    FTimer.Enabled := False;
    FApplied := TMmdAiPoseEditorForm(Screen.ActiveForm).ApplyExternalPose(
      '{"version":1,"bones":[{"name":"センター",' +
      '"translation":[1,0,0],"rotation":[0,0,0,1]}]}');
    if FCancelInstead then
      Screen.ActiveForm.ModalResult := mrCancel
    else
      PostMessage(Screen.ActiveForm.Handle, WM_CLOSE, 0, 0);
  end;
end;

procedure Check(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

function JsonInt(const JsonText, Name: string): Int64;
var
  RootValue, Value: TJSONValue;
begin
  Result := -1;
  RootValue := TJSONObject.ParseJSONValue(JsonText);
  try
    Check(RootValue is TJSONObject, 'response is not a JSON object');
    Value := TJSONObject(RootValue).GetValue(Name);
    if Value is TJSONNumber then
      Result := Trunc(TJSONNumber(Value).AsDouble);
  finally
    RootValue.Free;
  end;
end;

function JsonString(const JsonText, Name: string): string;
var
  RootValue, Value: TJSONValue;
begin
  Result := '';
  RootValue := TJSONObject.ParseJSONValue(JsonText);
  try
    Check(RootValue is TJSONObject, 'response is not a JSON object');
    Value := TJSONObject(RootValue).GetValue(Name);
    if Value is TJSONString then
      Result := TJSONString(Value).Value;
  finally
    RootValue.Free;
  end;
end;

function TTestAiPoseEditor.UndoEnabled: Boolean;
begin
  Result := FUndoButton.Enabled;
end;

function TTestAiPoseEditor.ProControllerAvailable: Boolean;
begin
  Result := FTestConnected;
end;

function TTestAiPoseEditor.DetailedVisible: Boolean;
begin
  Result := FBoneList.Visible;
end;

procedure TTestAiPoseEditor.ClickModeButton;
var
  I: Integer;
  Button: TMmdDarkButton;
begin
  for I := 0 to ComponentCount - 1 do
    if Components[I] is TMmdDarkButton then
    begin
      Button := TMmdDarkButton(Components[I]);
      if (Button.Caption = '簡易操作へ') or
        (Button.Caption = '詳細ボーン編集へ') then
      begin
        Check(Assigned(Button.OnClick), 'mode button has no handler');
        Button.OnClick(Button);
        Exit;
      end;
    end;
  raise Exception.Create('mode button was not found');
end;

procedure TTestAiPoseEditor.SetupSimpleMode;
begin
  EnableSimpleControls;
end;

function TTestAiPoseEditor.MarkerBone: Integer;
begin
  Result := FViewport.SelectedBone;
end;

function TTestAiPoseEditor.SelectedSimpleTarget: Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to ComponentCount - 1 do
    if Components[I] is TMmdSimpleControllerPanel then
      Exit(SimpleControllerTargetBone(FModel,
        TMmdSimpleControllerPanel(Components[I]).SelectedController));
end;

procedure TTestAiPoseEditor.SelectNextSimpleController;
var
  I: Integer;
begin
  for I := 0 to ComponentCount - 1 do
    if Components[I] is TMmdSimpleControllerPanel then
    begin
      TMmdSimpleControllerPanel(Components[I]).Navigate(18000);
      Exit;
    end;
  raise Exception.Create('simple controller panel was not found');
end;

procedure TTestAiPoseEditor.SelectEyeController;
var
  I, J: Integer;
  Panel: TMmdSimpleControllerPanel;
begin
  for I := 0 to ComponentCount - 1 do
    if Components[I] is TMmdSimpleControllerPanel then
    begin
      Panel := TMmdSimpleControllerPanel(Components[I]);
      for J := 0 to Panel.ControlCount - 1 do
        if Panel.Controls[J] is TListBox then
        begin
          Check((TListBox(Panel.Controls[J]).Items.Count > Ord(scEyes)) and
            (TListBox(Panel.Controls[J]).Items[Ord(scEyes)] = '目を動かす'),
            'eye controller row is missing from the visible list');
          Panel.SelectController(scEyes);
          Exit;
        end;
      raise Exception.Create('simple controller list was not found');
    end;
  raise Exception.Create('simple controller panel was not found');
end;

function TTestAiPoseEditor.FirstBoneName: string;
begin
  Check(Assigned(FModel) and (Length(FModel.Bones) > 0),
    'editor model has no bones');
  Result := FModel.Bones[0].Name;
end;

procedure TTestAiPoseEditor.UndoForTest;
begin
  FUndoButton.Click;
end;

procedure RunTest(const ModelPath: string);
const
  EmptyPose = '{"version":1,"bones":[]}';
var
  Bone, PoseRoot: TJSONObject;
  Bones, Rotation, Translation: TJSONArray;
  ContextText, PoseData, ResponseText, SessionId: string;
  ExpressionData, EyeBlinkData, LipSyncData: string;
  Form: TTestAiPoseEditor;
  Request: TJSONObject;
  Revision: Int64;
  AutoClose: TAutoClose;
  AppliedPose: string;
begin
  Check(FileExists(ModelPath), 'model file does not exist');
  Form := TTestAiPoseEditor.CreateAiEditor(ModelPath, EmptyPose,
    'AI pose session test', 'test pose');
  try
    Form.ConfigureSettingControls(False, True);
    Form.Show;
    Application.ProcessMessages;
    Form.TestConnected := False;
    Form.SetupSimpleMode;
    Check(Form.DetailedVisible,
      'missing controller did not start in detailed bone mode');
    Form.ClickModeButton;
    Check(Form.DetailedVisible,
      'mode button entered simple mode without a controller');
    Form.TestConnected := True;
    Form.ClickModeButton;
    Check(not Form.DetailedVisible,
      'connected controller did not permit simple mode');
    Check((Form.MarkerBone >= 0) and
      (Form.MarkerBone = Form.SelectedSimpleTarget),
      'initial simple controller marker is misplaced');
    Form.SelectNextSimpleController;
    Check((Form.MarkerBone >= 0) and
      (Form.MarkerBone = Form.SelectedSimpleTarget),
      'controller selection did not move the model marker');
    Form.SelectEyeController;
    Check((Form.MarkerBone >= 0) and
      (Form.MarkerBone = Form.SelectedSimpleTarget),
      'eye selection did not mark the eye bone');
    Form.TestConnected := False;
    Form.ClickModeButton;
    Check(Form.DetailedVisible,
      'switching back to detailed bone mode failed');
    ContextText := GetMmdAiPoseSessionContext;
    SessionId := JsonString(ContextText, 'session_id');
    Revision := JsonInt(ContextText, 'revision');
    Check(SessionId <> '', 'editor session was not registered');
    Check(Revision = 1, 'initial editor revision changed');

    PoseRoot := TJSONObject.Create;
    try
      PoseRoot.AddPair('version', TJSONNumber.Create(1));
      Bones := TJSONArray.Create;
      Bone := TJSONObject.Create;
      Bone.AddPair('name', Form.FirstBoneName);
      Translation := TJSONArray.Create;
      Translation.Add(1.0);
      Translation.Add(2.0);
      Translation.Add(3.0);
      Bone.AddPair('translation', Translation);
      Rotation := TJSONArray.Create;
      Rotation.Add(0.0);
      Rotation.Add(0.0);
      Rotation.Add(0.0);
      Rotation.Add(1.0);
      Bone.AddPair('rotation', Rotation);
      Bones.AddElement(Bone);
      PoseRoot.AddPair('bones', Bones);
      PoseData := PoseRoot.ToJSON;
    finally
      PoseRoot.Free;
    end;

    Request := TJSONObject.Create;
    try
      Request.AddPair('session_id', SessionId);
      Request.AddPair('base_revision', TJSONNumber.Create(Revision));
      Request.AddPair('pose_name', 'center test');
      Request.AddPair('candidate_id', 'candidate-live-1');
      Request.AddPair('pose_data', PoseData);
      ResponseText := PreviewMmdAiPoseInSession(Request);
    finally
      Request.Free;
    end;
    Check(JsonString(ResponseText, 'status') = 'ok',
      'live preview failed: ' + ResponseText);
    Check(JsonInt(ResponseText, 'revision') = 2,
      'live preview did not advance revision');
    Check(Form.EncodeCurrentPose <> EmptyPose,
      'live preview did not change the editor pose');
    Check(Form.AiStatusLabel.Caption = '反映済み: candidate-live-1',
      'candidate status was not displayed');
    Check(Form.UndoEnabled, 'AI candidate was not added to Undo history');
    Form.UndoForTest;
    Check(Form.EncodeCurrentPose = EmptyPose,
      'Undo did not restore the pose before the AI candidate');
  finally
    Form.Free;
  end;
  Check(JsonString(GetMmdAiPoseSessionContext, 'session_id') = '',
    'editor session remained registered after close');
  AutoClose := TAutoClose.Create;
  try
    Check(EditMmdAiPoseOnlySettings(ModelPath, EmptyPose,
      'Window close test', 'test pose', AppliedPose),
      'window X did not adopt the edited pose');
    Check(AutoClose.Applied and (AppliedPose <> EmptyPose),
      'window X lost the pose displayed in the editor');
  finally
    AutoClose.Free;
  end;
  AutoClose := TAutoClose.Create;
  try
    Check(EditMmdAiInitialStateSettings(ModelPath, EmptyPose,
      '', '', '', 'Initial state window close test', 'initial state',
      AppliedPose, ExpressionData, EyeBlinkData, LipSyncData),
      'initial state window X did not adopt the edited pose');
    Check(AutoClose.Applied and (AppliedPose <> EmptyPose),
      'initial state window X lost the displayed pose');
  finally
    AutoClose.Free;
  end;
  AutoClose := TAutoClose.Create;
  try
    AutoClose.CancelInstead := True;
    Check(not EditMmdAiPoseOnlySettings(ModelPath, EmptyPose,
      'Explicit cancel test', 'test pose', AppliedPose),
      'explicit cancel adopted the edited pose');
    Check(AppliedPose = EmptyPose,
      'explicit cancel changed the returned pose');
  finally
    AutoClose.Free;
  end;
end;

begin
  try
    Check(ParamCount = 1, 'model path argument is required');
    Application.Initialize;
    Application.ShowMainForm := False;
    RunTest(ParamStr(1));
    Writeln('MmdAiPoseEditorSessionTest: PASS');
  except
    on E: Exception do
    begin
      Writeln(E.ClassName + ': ' + E.Message);
      ExitCode := 1;
    end;
  end;
end.
