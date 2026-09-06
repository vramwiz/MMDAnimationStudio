program MmdAiPoseEditorSessionTest;

{$APPTYPE CONSOLE}

uses
  System.JSON,
  System.SysUtils,
  Vcl.Forms,
  MmdAiPoseEditorForm,
  MmdAiPoseSession;

type
  TTestAiPoseEditor = class(TMmdAiPoseEditorForm)
  public
    function FirstBoneName: string;
    function UndoEnabled: Boolean;
    procedure UndoForTest;
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
  Form: TTestAiPoseEditor;
  Request: TJSONObject;
  Revision: Int64;
begin
  Check(FileExists(ModelPath), 'model file does not exist');
  Form := TTestAiPoseEditor.CreateAiEditor(ModelPath, EmptyPose,
    'AI pose session test', 'test pose');
  try
    Form.ConfigureSettingControls(False, True);
    Form.Show;
    Application.ProcessMessages;
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
