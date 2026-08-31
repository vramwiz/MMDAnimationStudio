unit MMD_Motion_FilterPlugin;

// モーションレイヤーのPMX参照とモーションデータを保持する。

interface

uses
  AviUtl2FilterTypes;

// 初回呼出時に最小構成のモーション項目を登録し、Filterテーブルを返す。
function GetMotionFilterTable: PFILTER_PLUGIN_TABLE;

implementation

uses
  PluginFilterTable,
  MmdMotionSharedMemory,
  MMD_Motion_Runtime;

var
  ModelFileItem: TFILTER_ITEM_FILE;
  MotionDataItem: TFILTER_ITEM_STRING;
  PluginTableInitialized: Boolean;

const
  MOTION_EFFECT_NAME = #$30E2#$30FC#$30B7#$30E7#$30F3;
  MOTION_ITEM_MODEL_FILE = #$30E2#$30C7#$30EB#$30D5#$30A1#$30A4#$30EB;
  MOTION_ITEM_MOTION_DATA = #$30E2#$30FC#$30B7#$30E7#$30F3#$30C7#$30FC#$30BF;
  TRANSPARENT_PIXEL: TPIXEL_RGBA = (R: 0; G: 0; B: 0; A: 0);

function MotionProcVideo(Video: PFILTER_PROC_VIDEO): Byte; cdecl;
var
  MotionFrame: Single;
  Runtime: TMmdMotionRuntime;
  Snapshot: TMmdMotionSharedSnapshot;
begin
  Result := 1;
  try
    if (Video = nil) or not Assigned(Video^.SetImageData) then Exit;
    if (Video^.Object_ <> nil) and (ModelFileItem.Value <> nil) and
      (MotionDataItem.Value <> nil) then
    begin
      Runtime := AcquireMotionRuntime(Video^.Object_^.EffectID);
      try
        MotionFrame := Video^.Object_^.Frame;
        if MotionFrame < 0 then MotionFrame := 0;
        if Runtime.Evaluate(Video^.Object_^.ID,
          string(MotionDataItem.Value), MotionFrame,
          Snapshot.Poses, Snapshot.Morphs) then
        begin
          Snapshot.WriterObjectID := Video^.Object_^.ID;
          Snapshot.WriterEffectID := Video^.Object_^.EffectID;
          Snapshot.TimelineFrame := Video^.Object_^.FrameS +
            Video^.Object_^.Frame;
          Snapshot.MotionFrame := MotionFrame;
          Snapshot.ModelPathHash := HashMotionModelPath(
            string(ModelFileItem.Value));
          PublishMotionSnapshot(Video^.Object_^.Layer, Snapshot);
        end;
      finally
        ReleaseMotionRuntime(Runtime);
      end;
    end;
    Video^.SetImageData(@TRANSPARENT_PIXEL, 1, 1);
    if Assigned(Video^.SetDefaultAnchor) then
      Video^.SetDefaultAnchor(1, 1);
  except
    // Delphi例外をAviUtl2のコールバック境界より外へ漏らさない。
  end;
end;

function GetMotionFilterTable: PFILTER_PLUGIN_TABLE;
begin
  if not PluginTableInitialized then
  begin
    SetupPluginTable(FILTER_FLAG_VIDEO or FILTER_FLAG_INPUT,
      MOTION_EFFECT_NAME, 'MMD',
      'MMD' + #$30E2#$30C7#$30EB#$3078#$9069#$7528#$3059#$308B +
      #$30E2#$30FC#$30B7#$30E7#$30F3#$30C7#$30FC#$30BF#$3092 +
      #$4FDD#$6301#$3059#$308B#$30D5#$30A3#$30EB#$30BF#$30FC,
      MotionProcVideo, nil);
    SetFilterLifecycle(CreateMotionRuntime, DestroyMotionRuntime);
    AddFile(ModelFileItem, MOTION_ITEM_MODEL_FILE, '',
      'PMX' + #$30E2#$30C7#$30EB + ' (*.pmx)'#0'*.pmx'#0 +
      #$3059#$3079#$3066#$306E#$30D5#$30A1#$30A4#$30EB +
      ' (*.*)'#0'*.*'#0#0);
    AddString(MotionDataItem, MOTION_ITEM_MOTION_DATA, '');
    PluginTableInitialized := True;
  end;
  Result := GetPluginTable;
end;

end.
