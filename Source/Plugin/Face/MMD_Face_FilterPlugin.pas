unit MMD_Face_FilterPlugin;

// 表情レイヤーのPMX参照とシリアライズ済みモーフ設定を保持する。

interface

uses
  AviUtl2FilterTypes;

function GetFaceFilterTable: PFILTER_PLUGIN_TABLE;

implementation

uses
  Winapi.Windows,
  System.SysUtils,
  PluginFilterTable,
  MmdFaceSharedMemory,
  MmdModelSettingDialogs,
  MmdMorphSettingCodec;

var
  FaceButtonItem: TFILTER_ITEM_BUTTON;
  FaceDataItem: TFILTER_ITEM_STRING;
  ModelFileItem: TFILTER_ITEM_FILE;
  PluginTableInitialized: Boolean;

const
  FACE_EDITOR_CAPTION = 'MMD ' + #$8868#$60C5#$7DE8#$96C6;
  FACE_EFFECT_NAME = #$8868#$60C5;
  FACE_ITEM_FACE_DATA = #$8868#$60C5;
  FACE_ITEM_MODEL_FILE = #$30E2#$30C7#$30EB#$30D5#$30A1#$30A4#$30EB;
  TRANSPARENT_PIXEL: TPIXEL_RGBA = (R: 0; G: 0; B: 0; A: 0);

function GetFocusedItem(Edit: PEDIT_SECTION; Obj: OBJECT_HANDLE;
  ItemName: PWideChar): string;
var
  Value: PAnsiChar;
begin
  Result := '';
  if (Edit = nil) or not Assigned(Edit^.GetObjectItemValue) then Exit;
  Value := Edit^.GetObjectItemValue(Obj, FACE_EFFECT_NAME, ItemName);
  if Value <> nil then Result := UTF8ToString(Value);
end;

procedure FaceButtonCallback(Edit: PEDIT_SECTION); cdecl;
var
  FaceData: string;
  ModelFileName: string;
  NewFaceData: string;
  Obj: OBJECT_HANDLE;
  Utf8FaceData: UTF8String;
begin
  try
    if (Edit = nil) or not Assigned(Edit^.GetFocusObject) or
      not Assigned(Edit^.SetObjectItemValue) then Exit;
    Obj := Edit^.GetFocusObject;
    if Obj = nil then Exit;
    ModelFileName := GetFocusedItem(Edit, Obj, FACE_ITEM_MODEL_FILE);
    if ModelFileName = '' then
    begin
      MessageBox(0, #$5148#$306B#$30E2#$30C7#$30EB#$30D5#$30A1#$30A4 +
        #$30EB#$3092#$9078#$629E#$3057#$3066#$304F#$3060#$3055#$3044 +
        #$3002,
        FACE_EDITOR_CAPTION, MB_OK or MB_ICONINFORMATION);
      Exit;
    end;
    FaceData := GetFocusedItem(Edit, Obj, FACE_ITEM_FACE_DATA);
    if FaceData = '' then FaceData := EmptyMmdMorphSettingData;
    if not EditMmdFaceOnlySettings(ModelFileName, FaceData,
      string(FACE_EDITOR_CAPTION), NewFaceData) then Exit;
    Utf8FaceData := UTF8String(NewFaceData);
    Edit^.SetObjectItemValue(Obj, FACE_EFFECT_NAME, FACE_ITEM_FACE_DATA,
      PAnsiChar(Utf8FaceData));
  except
    on E: Exception do
      MessageBox(0, PChar(E.Message), FACE_EDITOR_CAPTION,
        MB_OK or MB_ICONERROR);
  end;
end;

function FaceProcVideo(Video: PFILTER_PROC_VIDEO): Byte; cdecl;
var
  Snapshot: TMmdFaceSharedSnapshot;
begin
  Result := 1;
  try
    if (Video = nil) or not Assigned(Video^.SetImageData) then Exit;
    if (Video^.Object_ <> nil) and (ModelFileItem.Value <> nil) and
      (FaceDataItem.Value <> nil) then
    begin
      Snapshot.WriterObjectID := Video^.Object_^.ID;
      Snapshot.WriterEffectID := Video^.Object_^.EffectID;
      Snapshot.TimelineFrame := GetFaceTimelineFrame(Video^.Object_);
      Snapshot.ModelPathHash := HashFaceModelPath(
        string(ModelFileItem.Value));
      Snapshot.FaceData := string(FaceDataItem.Value);
      PublishFaceSnapshot(Video^.Object_^.Layer, Snapshot);
    end;
    Video^.SetImageData(@TRANSPARENT_PIXEL, 1, 1);
    if Assigned(Video^.SetDefaultAnchor) then
      Video^.SetDefaultAnchor(1, 1);
  except
    // Delphi例外をAviUtl2のコールバック境界より外へ漏らさない。
  end;
end;

function GetFaceFilterTable: PFILTER_PLUGIN_TABLE;
begin
  if not PluginTableInitialized then
  begin
    SetupPluginTable(FILTER_FLAG_VIDEO or FILTER_FLAG_INPUT,
      FACE_EFFECT_NAME, 'MMD', 'MMD' + #$30E2#$30C7#$30EB#$3078 +
      #$9069#$7528#$3059#$308B#$8868#$60C5#$30E2#$30FC#$30D5#$3092 +
      #$4FDD#$6301#$3059#$308B#$30D5#$30A3#$30EB#$30BF#$30FC,
      FaceProcVideo, nil);
    AddFile(ModelFileItem, FACE_ITEM_MODEL_FILE, '',
      'PMX' + #$30E2#$30C7#$30EB + ' (*.pmx)'#0'*.pmx'#0 +
      #$3059#$3079#$3066#$306E#$30D5#$30A1#$30A4#$30EB +
      ' (*.*)'#0'*.*'#0#0);
    AddString(FaceDataItem, FACE_ITEM_FACE_DATA,
      EmptyMmdMorphSettingData);
    AddButton(FaceButtonItem, #$8A2D#$5B9A, FaceButtonCallback);
    PluginTableInitialized := True;
  end;
  Result := GetPluginTable;
end;

end.
