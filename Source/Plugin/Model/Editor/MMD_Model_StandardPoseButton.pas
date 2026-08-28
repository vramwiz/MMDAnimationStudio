unit MMD_Model_StandardPoseButton;

// モデル表示の設定ボタンからポーズGUIを開き、OK時だけJSONを保存する。

interface

uses
  AviUtl2FilterTypes;

// フォーカス中のモデル設定を作業用GUIで編集し、OK時だけUTF-8 JSONを書き戻す。
procedure StandardPoseButtonCallback(Edit: PEDIT_SECTION); cdecl;

implementation

uses
  Winapi.Windows,
  System.SysUtils,
  MmdPoseEditor;

const
  MODEL_EFFECT_NAME = 'モデル表示';
  MODEL_ITEM_MODEL_FILE = 'モデルファイル';
  MODEL_ITEM_POSE = 'ポーズ';

function GetFocusedItem(Edit: PEDIT_SECTION; Obj: OBJECT_HANDLE;
  const ItemName: string): string;
var
  Value: PAnsiChar;
begin
  Result := '';
  if (Edit = nil) or not Assigned(Edit^.GetObjectItemValue) then
    Exit;
  Value := Edit^.GetObjectItemValue(Obj, MODEL_EFFECT_NAME, PWideChar(ItemName));
  if Value <> nil then
    Result := UTF8ToString(Value);
end;

procedure StandardPoseButtonCallback(Edit: PEDIT_SECTION); cdecl;
var
  ModelFileName: string;
  NewPoseData: string;
  Obj: OBJECT_HANDLE;
  PoseData: string;
  Utf8PoseData: UTF8String;
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
      MessageBox(0, '先にモデルファイルを選択してください。', 'MMD ポーズ編集',
        MB_OK or MB_ICONINFORMATION);
      Exit;
    end;
    PoseData := GetFocusedItem(Edit, Obj, MODEL_ITEM_POSE);
    if PoseData = '' then
      PoseData := '{"version":1,"bones":[]}';
    if not EditPose(ModelFileName, PoseData, 'MMD ポーズ編集',
      NewPoseData) then
      Exit;
    Utf8PoseData := UTF8String(NewPoseData);
    Edit^.SetObjectItemValue(Obj, MODEL_EFFECT_NAME,
      MODEL_ITEM_POSE, PAnsiChar(Utf8PoseData));
  except
    on E: Exception do
      MessageBox(0, PChar(E.Message), 'MMD ポーズ編集',
        MB_OK or MB_ICONERROR);
  end;
end;

end.
