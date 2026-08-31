unit MMD_Animation_ModulePlugin;

// MMDポーズ／モーションScriptの評価値をレイヤー別共有メモリへ発行する。

interface

uses
  MmdSerifModuleTypes;

// Scriptの5引数を検証し、指定レイヤーへ現在フレームのポーズを発行する。異常入力では発行しない。
procedure MmdSetPose(Param: PMMD_SCRIPT_MODULE_PARAM); cdecl;
// Scriptの6引数を検証し、モーションを評価して指定レイヤーへ発行する。異常入力では発行しない。
procedure MmdSetMotion(Param: PMMD_SCRIPT_MODULE_PARAM); cdecl;

implementation

uses
  MmdSerifModuleAdapter,
  MmdPoseSharedMemory,
  MmdMotionSharedMemory,
  MMD_Motion_Runtime;

const
  POSE_PARAM_COUNT = 5;
  POSE_PARAM_LAYER = 0;
  POSE_PARAM_TIMELINE_FRAME = 1;
  POSE_PARAM_SOURCE_OBJECT = 2;
  POSE_PARAM_MODEL_FILE = 3;
  POSE_PARAM_DATA = 4;

  MOTION_PARAM_COUNT = 6;
  MOTION_PARAM_LAYER = 0;
  MOTION_PARAM_FRAME = 1;
  MOTION_PARAM_TIMELINE_FRAME = 2;
  MOTION_PARAM_SOURCE_OBJECT = 3;
  MOTION_PARAM_MODEL_FILE = 4;
  MOTION_PARAM_DATA = 5;

procedure MmdSetPose(Param: PMMD_SCRIPT_MODULE_PARAM); cdecl;
var
  ModelFileName, PoseData, SourceObject: string;
  ObjectID: Int64;
  Snapshot: TMmdPoseSharedSnapshot;
begin
  try
    if (Param = nil) or not Assigned(Param^.GetParamNum) or
      not Assigned(Param^.GetParamInt) or
      not Assigned(Param^.GetParamString) or
      (Param^.GetParamNum < POSE_PARAM_COUNT) then Exit;
    ModelFileName := MmdModuleParamString(Param, POSE_PARAM_MODEL_FILE);
    PoseData := MmdModuleParamString(Param, POSE_PARAM_DATA);
    if (ModelFileName = '') or (PoseData = '') then Exit;
    SourceObject := MmdModuleParamString(Param, POSE_PARAM_SOURCE_OBJECT);
    ObjectID := MmdModuleObjectID(SourceObject);
    Snapshot := Default(TMmdPoseSharedSnapshot);
    Snapshot.WriterObjectID := ObjectID;
    Snapshot.WriterEffectID := ObjectID;
    Snapshot.TimelineFrame := Param^.GetParamInt(POSE_PARAM_TIMELINE_FRAME);
    Snapshot.ModelPathHash := HashModelPath(ModelFileName);
    Snapshot.PoseData := PoseData;
    PublishPoseSnapshot(Param^.GetParamInt(POSE_PARAM_LAYER), Snapshot);
  except
    // Delphi例外をAviUtl2 Script Module境界から漏らさない。
  end;
end;

procedure MmdSetMotion(Param: PMMD_SCRIPT_MODULE_PARAM); cdecl;
var
  ModelFileName, MotionData, SourceObject: string;
  MotionFrame: Single;
  ObjectID: Int64;
  Runtime: TMmdMotionRuntime;
  Snapshot: TMmdMotionSharedSnapshot;
begin
  try
    if (Param = nil) or not Assigned(Param^.GetParamNum) or
      not Assigned(Param^.GetParamInt) or
      not Assigned(Param^.GetParamDouble) or
      not Assigned(Param^.GetParamString) or
      (Param^.GetParamNum < MOTION_PARAM_COUNT) then Exit;
    ModelFileName := MmdModuleParamString(Param, MOTION_PARAM_MODEL_FILE);
    MotionData := MmdModuleParamString(Param, MOTION_PARAM_DATA);
    if (ModelFileName = '') or (MotionData = '') then Exit;
    MotionFrame := Param^.GetParamDouble(MOTION_PARAM_FRAME);
    if MotionFrame < 0 then MotionFrame := 0;
    SourceObject := MmdModuleParamString(Param,
      MOTION_PARAM_SOURCE_OBJECT);
    ObjectID := MmdModuleObjectID(SourceObject);
    Runtime := AcquireMotionRuntime(ObjectID);
    try
      Snapshot := Default(TMmdMotionSharedSnapshot);
      if not Runtime.Evaluate(ObjectID, MotionData, MotionFrame,
        Snapshot.Poses, Snapshot.Morphs) then Exit;
      Snapshot.WriterObjectID := ObjectID;
      Snapshot.WriterEffectID := ObjectID;
      Snapshot.TimelineFrame := Param^.GetParamInt(
        MOTION_PARAM_TIMELINE_FRAME);
      Snapshot.MotionFrame := MotionFrame;
      Snapshot.ModelPathHash := HashMotionModelPath(ModelFileName);
      PublishMotionSnapshot(Param^.GetParamInt(MOTION_PARAM_LAYER),
        Snapshot);
    finally
      ReleaseMotionRuntime(Runtime);
    end;
  except
    // Delphi例外をAviUtl2 Script Module境界から漏らさない。
  end;
end;

end.
