unit MMD_Model_SettingsButton;

// モデル表示の設定ボタンから共通のポーズ・表情フォームを開く。

interface

uses
  AviUtl2FilterTypes;

// フォーカス中のモデル設定を編集し、閉じた時点のポーズと表情を書き戻す。
procedure ModelSettingsButtonCallback(Edit: PEDIT_SECTION); cdecl;

implementation

uses
  Winapi.Windows,
  System.Classes,
  System.SysUtils,
  System.UITypes,
  Vcl.Forms,
  MmdModelSettingEditor,
  MmdMorphSettingCodec;

const
  MODEL_EDITOR_CAPTION: string = 'MMD 設定';
  MODEL_EFFECT_NAME: string = 'モデル表示';
  MODEL_ITEM_EXPRESSION: string = '表情';
  MODEL_ITEM_MODEL_FILE: string = 'モデルファイル';
  MODEL_ITEM_POSE: string = 'ポーズ';

type
  TModelSettingsSession = class(TComponent)
  private
    FForm: TMmdModelSettingEditorForm;
    FObject: OBJECT_HANDLE;
    FSetObjectItemValue: TSetObjectItemValueFunc;
    FWriteFailed: Boolean;
  public
    constructor Create(AOwner: TComponent; Edit: PEDIT_SECTION;
      Obj: OBJECT_HANDLE; Form: TMmdModelSettingEditorForm);
      reintroduce;
    procedure CloseButtonClick(Sender: TObject);
    procedure ExpressionChanged(Sender: TObject;
      const ExpressionData: string);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
  end;

var
  ActiveModelSettingsForm: TMmdModelSettingEditorForm;

function GetFocusedItem(Edit: PEDIT_SECTION; Obj: OBJECT_HANDLE;
  const ItemName: string): string;
var
  Value: PAnsiChar;
begin
  Result := '';
  if (Edit = nil) or not Assigned(Edit^.GetObjectItemValue) then
    Exit;
  Value := Edit^.GetObjectItemValue(Obj, PWideChar(MODEL_EFFECT_NAME),
    PWideChar(ItemName));
  if Value <> nil then
    Result := UTF8ToString(Value);
end;

function SetFocusedItem(Edit: PEDIT_SECTION; Obj: OBJECT_HANDLE;
  const ItemName, Value: string): Boolean;
var
  Utf8Value: UTF8String;
begin
  Result := False;
  if (Edit = nil) or not Assigned(Edit^.SetObjectItemValue) or (Obj = nil) then
    Exit;
  Utf8Value := UTF8String(Value);
  Result := Edit^.SetObjectItemValue(Obj, PWideChar(MODEL_EFFECT_NAME),
    PWideChar(ItemName), PAnsiChar(Utf8Value));
end;

constructor TModelSettingsSession.Create(AOwner: TComponent;
  Edit: PEDIT_SECTION; Obj: OBJECT_HANDLE; Form: TMmdModelSettingEditorForm);
begin
  inherited Create(AOwner);
  FObject := Obj;
  FForm := Form;
  FSetObjectItemValue := Edit^.SetObjectItemValue;
end;

procedure TModelSettingsSession.CloseButtonClick(Sender: TObject);
begin
  FForm.Close;
end;

procedure TModelSettingsSession.ExpressionChanged(Sender: TObject;
  const ExpressionData: string);
begin
  if not Assigned(FSetObjectItemValue) then
  begin
    FWriteFailed := True;
    Exit;
  end;
  if not FSetObjectItemValue(FObject, PWideChar(MODEL_EFFECT_NAME),
    PWideChar(MODEL_ITEM_EXPRESSION),
    PAnsiChar(UTF8String(ExpressionData))) then
    FWriteFailed := True;
end;

procedure TModelSettingsSession.FormClose(Sender: TObject;
  var Action: TCloseAction);
var
  ExpressionData, PoseData: string;
begin
  PoseData := FForm.EncodeCurrentPose;
  ExpressionData := FForm.EncodeExpression;
  if not Assigned(FSetObjectItemValue) or
    not FSetObjectItemValue(FObject, PWideChar(MODEL_EFFECT_NAME),
      PWideChar(MODEL_ITEM_POSE), PAnsiChar(UTF8String(PoseData))) or
    not FSetObjectItemValue(FObject, PWideChar(MODEL_EFFECT_NAME),
      PWideChar(MODEL_ITEM_EXPRESSION),
      PAnsiChar(UTF8String(ExpressionData))) then
    FWriteFailed := True;
  ActiveModelSettingsForm := nil;
  Action := caFree;
  if FWriteFailed then
    MessageBox(0, '設定をモデル表示へ反映できませんでした。',
      PChar(MODEL_EDITOR_CAPTION), MB_OK or MB_ICONERROR);
end;

procedure ModelSettingsButtonCallback(Edit: PEDIT_SECTION); cdecl;
var
  ExpressionData, ModelFileName: string;
  Form: TMmdModelSettingEditorForm;
  Obj: OBJECT_HANDLE;
  PoseData: string;
  Session: TModelSettingsSession;
begin
  try
    if Assigned(ActiveModelSettingsForm) then
    begin
      ActiveModelSettingsForm.Show;
      SetForegroundWindow(ActiveModelSettingsForm.Handle);
      Exit;
    end;
    if (Edit = nil) or not Assigned(Edit^.GetFocusObject) or
      not Assigned(Edit^.SetObjectItemValue) then
      Exit;
    Obj := Edit^.GetFocusObject;
    if Obj = nil then
      Exit;
    ModelFileName := GetFocusedItem(Edit, Obj, MODEL_ITEM_MODEL_FILE);
    if ModelFileName = '' then
    begin
      MessageBox(0, '先にモデルファイルを選択してください。',
        PChar(MODEL_EDITOR_CAPTION),
        MB_OK or MB_ICONINFORMATION);
      Exit;
    end;
    PoseData := GetFocusedItem(Edit, Obj, MODEL_ITEM_POSE);
    if PoseData = '' then
      PoseData := '{"version":1,"bones":[]}';
    ExpressionData := GetFocusedItem(Edit, Obj, MODEL_ITEM_EXPRESSION);
    if ExpressionData = '' then
      ExpressionData := EmptyMmdMorphSettingData;
    Form := TMmdModelSettingEditorForm.CreateEditor(ModelFileName, PoseData,
      MODEL_EDITOR_CAPTION);
    try
      Form.ConfigureSettingControls(False);
      Form.InitializeExpression(ExpressionData);
      Session := TModelSettingsSession.Create(Form, Edit, Obj, Form);
      Form.OnExpressionDataChanged := Session.ExpressionChanged;
      Form.OnClose := Session.FormClose;
      Form.SaveButton.ModalResult := mrNone;
      Form.SaveButton.OnClick := Session.CloseButtonClick;
      ActiveModelSettingsForm := Form;
      Form.Show;
      Form := nil;
    finally
      Form.Free;
    end;
  except
    on E: Exception do
      MessageBox(0, PChar(E.Message), PChar(MODEL_EDITOR_CAPTION),
        MB_OK or MB_ICONERROR);
  end;
end;

end.
