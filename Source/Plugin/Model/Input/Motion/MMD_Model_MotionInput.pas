unit MMD_Model_MotionInput;

// 現在フレームのMotion Scriptを評価し、共有スナップショットをPMXへ解決する。

interface

uses
  AviUtl2FilterTypes,
  MmdMorphSettingCodec,
  PmxModel,
  PmxMorph,
  PmxPose;

// 1始まりの参照レイヤーを評価し、同一PMX・同一タイムラインフレームの値を返す。
function TryGetReferencedMotion(Video: PFILTER_PROC_VIDEO;
  MotionLayer: Integer; const ModelFileName: string;
  out MotionPoses: TPmxNamedBonePoses;
  out MotionMorphs: TMmdNamedMorphWeights): Boolean;
// 名前付きMotion値を現在のローカル姿勢とモデル寸法のモーフ配列へ解決する。
procedure ResolveMotionForModel(const Model: TPmxModel;
  const MotionPoses: TPmxNamedBonePoses;
  const MotionMorphs: TMmdNamedMorphWeights; var BonePoses: TPmxBonePoses;
  out MorphWeights: TPmxMorphWeights; out PoseActive, MorphActive: Boolean);

implementation

uses
  MmdMotionSharedMemory;

function TryGetReferencedMotion(Video: PFILTER_PROC_VIDEO;
  MotionLayer: Integer; const ModelFileName: string;
  out MotionPoses: TPmxNamedBonePoses;
  out MotionMorphs: TMmdNamedMorphWeights): Boolean;
var
  MotionObject: OBJECT_HANDLE;
  Snapshot: TMmdMotionSharedSnapshot;
  TimelineFrame: Integer;
begin
  Result := False;
  MotionPoses := nil;
  MotionMorphs := nil;
  if (Video = nil) or not Assigned(Video^.GetImageObject) or
    (Video^.Object_ = nil) or (MotionLayer <= 0) then Exit;
  try
    MotionObject := Video^.GetImageObject(MotionLayer - 1, 0.0);
    if MotionObject = nil then Exit;
    if not TryReadMotionSnapshot(MotionLayer - 1,
      HashMotionModelPath(ModelFileName), Snapshot) then Exit;
    TimelineFrame := Video^.Object_^.FrameS + Video^.Object_^.Frame;
    if Snapshot.TimelineFrame <> TimelineFrame then Exit;
    MotionPoses := Snapshot.Poses;
    MotionMorphs := Snapshot.Morphs;
    Result := True;
  except
    MotionPoses := nil;
    MotionMorphs := nil;
    Result := False;
  end;
end;

procedure ResolveMotionForModel(const Model: TPmxModel;
  const MotionPoses: TPmxNamedBonePoses;
  const MotionMorphs: TMmdNamedMorphWeights; var BonePoses: TPmxBonePoses;
  out MorphWeights: TPmxMorphWeights; out PoseActive, MorphActive: Boolean);
begin
  PoseActive := False;
  MorphActive := False;
  MorphWeights := nil;
  if Model = nil then Exit;
  InitializeMorphWeights(Model, MorphWeights);
  PoseActive := ApplyNamedBonePoses(Model, MotionPoses, BonePoses);
  MorphActive := ApplyMmdNamedMorphWeights(Model, MotionMorphs,
    MorphWeights);
end;

end.
