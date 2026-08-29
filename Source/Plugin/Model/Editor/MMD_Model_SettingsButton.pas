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
  System.SysUtils,
  MmdModelSettingDialogs;

const
  MODEL_EDITOR_CAPTION: string = 'MMD 設定';
  MODEL_EFFECT_NAME: string = 'モデル表示';
  MODEL_ITEM_EXPRESSION: string = '表情';
  MODEL_ITEM_MODEL_FILE: string = 'モデルファイル';
  MODEL_ITEM_POSE: string = 'ポーズ';

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

procedure SetFocusedItem(Edit: PEDIT_SECTION; Obj: OBJECT_HANDLE;
  const ItemName, Value: string);
var
  Utf8Value: UTF8String;
begin
  Utf8Value := UTF8String(Value);
  Edit^.SetObjectItemValue(Obj, PWideChar(MODEL_EFFECT_NAME),
    PWideChar(ItemName), PAnsiChar(Utf8Value));
end;

procedure ModelSettingsButtonCallback(Edit: PEDIT_SECTION); cdecl;
var
  ExpressionData, ModelFileName, NewExpressionData, NewPoseData: string;
  Obj: OBJECT_HANDLE;
  PoseData: string;
begin
  try
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
    ExpressionData := GetFocusedItem(Edit, Obj, MODEL_ITEM_EXPRESSION);
    if not EditMmdModelSettings(ModelFileName, PoseData, ExpressionData,
      MODEL_EDITOR_CAPTION, NewPoseData, NewExpressionData) then
      Exit;
    SetFocusedItem(Edit, Obj, MODEL_ITEM_POSE, NewPoseData);
    SetFocusedItem(Edit, Obj, MODEL_ITEM_EXPRESSION, NewExpressionData);
  except
    on E: Exception do
      MessageBox(0, PChar(E.Message), PChar(MODEL_EDITOR_CAPTION),
        MB_OK or MB_ICONERROR);
  end;
end;

end.
