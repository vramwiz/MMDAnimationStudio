unit MMD_Pose_FilterPlugin;

// ポーズレイヤーのPMX参照とシリアライズ済み姿勢データを保持する。

interface

uses
  AviUtl2FilterTypes;

// 初回呼出時にポーズ保持項目を登録し、DLL有効期間中のFilterテーブルを返す。
function GetPoseFilterTable: PFILTER_PLUGIN_TABLE;

implementation

uses
  Winapi.Windows,
  System.SysUtils,
  PluginFilterTable,
  MmdPoseSharedMemory,
  MmdPoseEditor;

var
  ModelFileItem: TFILTER_ITEM_FILE;
  PluginTableInitialized: Boolean;
  PoseButtonItem: TFILTER_ITEM_BUTTON;
  PoseDataItem: TFILTER_ITEM_STRING;

const
  POSE_EFFECT_NAME = 'ポーズ';
  POSE_ITEM_MODEL_FILE = 'モデルファイル';
  POSE_ITEM_POSE_DATA = '姿勢データ';
  TRANSPARENT_PIXEL: TPIXEL_RGBA = (R: 0; G: 0; B: 0; A: 0);

function GetFocusedItem(Edit: PEDIT_SECTION; Obj: OBJECT_HANDLE;
  const ItemName: string): string;
var
  Value: PAnsiChar;
begin
  Result := '';
  if (Edit = nil) or not Assigned(Edit^.GetObjectItemValue) then
    Exit;
  Value := Edit^.GetObjectItemValue(Obj, POSE_EFFECT_NAME, PWideChar(ItemName));
  if Value <> nil then
    Result := UTF8ToString(Value);
end;

procedure PoseButtonCallback(Edit: PEDIT_SECTION); cdecl;
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
    ModelFileName := GetFocusedItem(Edit, Obj, POSE_ITEM_MODEL_FILE);
    if ModelFileName = '' then
    begin
      MessageBox(0, '先にモデルファイルを選択してください。', 'MMD ポーズ編集',
        MB_OK or MB_ICONINFORMATION);
      Exit;
    end;
    PoseData := GetFocusedItem(Edit, Obj, POSE_ITEM_POSE_DATA);
    if PoseData = '' then
      PoseData := '{"version":1,"bones":[]}';
    if not EditPose(ModelFileName, PoseData, 'MMD ポーズ編集', NewPoseData) then
      Exit;
    Utf8PoseData := UTF8String(NewPoseData);
    Edit^.SetObjectItemValue(Obj, POSE_EFFECT_NAME, POSE_ITEM_POSE_DATA,
      PAnsiChar(Utf8PoseData));
  except
    on E: Exception do
      MessageBox(0, PChar(E.Message), 'MMD ポーズ編集', MB_OK or MB_ICONERROR);
  end;
end;

function PoseProcVideo(Video: PFILTER_PROC_VIDEO): Byte; cdecl;
var
  Snapshot: TMmdPoseSharedSnapshot;
begin
  Result := 1;
  try
    if (Video = nil) or not Assigned(Video^.SetImageData) then
      Exit;
    if (Video^.Object_ <> nil) and (ModelFileItem.Value <> nil) and
      (PoseDataItem.Value <> nil) then
    begin
      Snapshot.WriterObjectID := Video^.Object_^.ID;
      Snapshot.WriterEffectID := Video^.Object_^.EffectID;
      Snapshot.TimelineFrame := GetTimelineFrame(Video^.Object_);
      Snapshot.ModelPathHash := HashModelPath(string(ModelFileItem.Value));
      Snapshot.PoseData := string(PoseDataItem.Value);
      PublishPoseSnapshot(Video^.Object_^.Layer, Snapshot);
    end;
    // 参照可能な画像オブジェクトとして存在しつつ、シーンには何も表示しない。
    Video^.SetImageData(@TRANSPARENT_PIXEL, 1, 1);
    if Assigned(Video^.SetDefaultAnchor) then
      Video^.SetDefaultAnchor(1, 1);
  except
    // Delphi例外をAviUtl2のコールバック境界より外へ漏らさない。
  end;
end;

function GetPoseFilterTable: PFILTER_PLUGIN_TABLE;
begin
  if not PluginTableInitialized then
  begin
    SetupPluginTable(FILTER_FLAG_VIDEO or FILTER_FLAG_INPUT,
      'ポーズ', 'MMD', 'MMDモデルへ適用するポーズデータを保持するフィルター',
      PoseProcVideo, nil);
    AddFile(ModelFileItem, 'モデルファイル', '',
      'PMXモデル (*.pmx)'#0'*.pmx'#0 +
      'すべてのファイル (*.*)'#0'*.*'#0#0);
    AddString(PoseDataItem, '姿勢データ', '{"version":1,"bones":[]}');
    AddButton(PoseButtonItem, 'ポーズ設定', PoseButtonCallback);
    PluginTableInitialized := True;
  end;
  Result := GetPluginTable;
end;

end.
