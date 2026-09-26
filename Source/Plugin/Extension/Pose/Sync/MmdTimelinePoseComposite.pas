unit MmdTimelinePoseComposite;

// 表示モデルと同じ順序で土台姿勢を組み立て、Scriptには差分だけを書き戻す。

interface

uses
  PmxModel,
  PmxPose;

// モデル初期ポーズ、現在モーション、選択ポーズを合成する。失敗時はFalseと空姿勢を返す。
function TryComposeTimelinePose(Model: TPmxModel;
  const StandardPoseData, MotionData: string; MotionFrame: Integer;
  const ScriptPoseData: string; out BasePoses,
  CurrentPoses: TPmxBonePoses): Boolean; overload;
// 全身回転も含めて、モデル側の基準姿勢とScript姿勢を合成する。
function TryComposeTimelinePose(Model: TPmxModel;
  const StandardPoseData, MotionData: string; MotionFrame: Integer;
  const ScriptPoseData: string; out BasePoses,
  CurrentPoses: TPmxBonePoses; out BaseRoot,
  CurrentRoot: TPmxQuaternion): Boolean; overload;
// ポーズ固有の相対アングルも標準姿勢から継承し、Scriptの明示値で上書きする。
function TryComposeTimelinePose(Model: TPmxModel;
  const StandardPoseData, MotionData: string; MotionFrame: Integer;
  const ScriptPoseData: string; out BasePoses,
  CurrentPoses: TPmxBonePoses; out BaseRoot,
  CurrentRoot: TPmxQuaternion; out BaseYaw, BasePitch,
  CurrentYaw, CurrentPitch: Single): Boolean; overload;
// 土台から変更されたボーンだけをScript用の姿勢JSONとして返す。
function EncodeTimelinePoseOverlay(Model: TPmxModel;
  const BasePoses, CurrentPoses: TPmxBonePoses): string; overload;
// 変更されたボーンと全身回転だけをScript姿勢へ保存する。
function EncodeTimelinePoseOverlay(Model: TPmxModel;
  const BasePoses, CurrentPoses: TPmxBonePoses;
  const BaseRoot, CurrentRoot: TPmxQuaternion): string; overload;
// 全身回転と相対アングルの差分もScriptのJSONへ含める。
function EncodeTimelinePoseOverlay(Model: TPmxModel;
  const BasePoses, CurrentPoses: TPmxBonePoses;
  const BaseRoot, CurrentRoot: TPmxQuaternion;
  BaseYaw, BasePitch, CurrentYaw, CurrentPitch: Single): string; overload;

implementation

uses
  System.Math,
  MmdMorphSettingCodec,
  MmdMotionDocument,
  MmdMotionDocumentCodec,
  MmdMotionDocumentEvaluator,
  PmxPoseCodec;

function TryComposeTimelinePose(Model: TPmxModel;
  const StandardPoseData, MotionData: string; MotionFrame: Integer;
  const ScriptPoseData: string; out BasePoses,
  CurrentPoses: TPmxBonePoses): Boolean;
var
  BaseRoot, CurrentRoot: TPmxQuaternion;
begin
  Result := TryComposeTimelinePose(Model, StandardPoseData, MotionData,
    MotionFrame, ScriptPoseData, BasePoses, CurrentPoses, BaseRoot,
    CurrentRoot);
end;

function TryComposeTimelinePose(Model: TPmxModel;
  const StandardPoseData, MotionData: string; MotionFrame: Integer;
  const ScriptPoseData: string; out BasePoses,
  CurrentPoses: TPmxBonePoses; out BaseRoot,
  CurrentRoot: TPmxQuaternion): Boolean;
var
  BaseYaw, BasePitch, CurrentYaw, CurrentPitch: Single;
begin
  Result := TryComposeTimelinePose(Model, StandardPoseData, MotionData,
    MotionFrame, ScriptPoseData, BasePoses, CurrentPoses, BaseRoot,
    CurrentRoot, BaseYaw, BasePitch, CurrentYaw, CurrentPitch);
end;

function TryComposeTimelinePose(Model: TPmxModel;
  const StandardPoseData, MotionData: string; MotionFrame: Integer;
  const ScriptPoseData: string; out BasePoses,
  CurrentPoses: TPmxBonePoses; out BaseRoot,
  CurrentRoot: TPmxQuaternion; out BaseYaw, BasePitch,
  CurrentYaw, CurrentPitch: Single): Boolean;
var
  Document: TMmdMotionDocument;
  HasRoot, HasAngle: Boolean;
  Morphs: TMmdNamedMorphWeights;
  NamedPoses: TPmxNamedBonePoses;
  ScriptRoot: TPmxQuaternion;
begin
  Result := False;
  BasePoses := nil;
  CurrentPoses := nil;
  BaseRoot := IdentityQuaternion;
  CurrentRoot := IdentityQuaternion;
  BaseYaw := 0;
  BasePitch := 0;
  CurrentYaw := 0;
  CurrentPitch := 0;
  if Model = nil then Exit;
  InitializeBonePoses(Model, BasePoses);
  if StandardPoseData <> '' then
  begin
    if not TryDecodePoseDataWithRootAndAngle(StandardPoseData, NamedPoses,
      BaseRoot, HasRoot, BaseYaw, BasePitch, HasAngle) then Exit;
    ApplyNamedBonePoses(Model, NamedPoses, BasePoses);
  end;
  if MotionData <> '' then
  begin
    Document := nil;
    if not TryDecodeMmdMotionDocument(MotionData, Document) then Exit;
    try
      if not EvaluateMmdMotionDocument(Document, Max(0, MotionFrame),
        NamedPoses, Morphs) then Exit;
      ApplyNamedBonePoses(Model, NamedPoses, BasePoses);
    finally
      Document.Free;
    end;
  end;
  CurrentPoses := Copy(BasePoses);
  CurrentRoot := BaseRoot;
  CurrentYaw := BaseYaw;
  CurrentPitch := BasePitch;
  if ScriptPoseData = '' then NamedPoses := nil
  else
  begin
    if not TryDecodePoseDataWithRootAndAngle(ScriptPoseData, NamedPoses,
      ScriptRoot, HasRoot, CurrentYaw, CurrentPitch, HasAngle) then Exit;
    if HasRoot then CurrentRoot := ScriptRoot;
    if not HasAngle then
    begin
      CurrentYaw := BaseYaw;
      CurrentPitch := BasePitch;
    end;
  end;
  ApplyNamedBonePoses(Model, NamedPoses, CurrentPoses);
  Result := True;
end;

function SameBonePose(const A, B: TPmxBonePose): Boolean;
const
  Epsilon = 0.00001;
var
  Direct, Negated: Boolean;
begin
  Direct := (Abs(A.Rotation.X - B.Rotation.X) < Epsilon) and
    (Abs(A.Rotation.Y - B.Rotation.Y) < Epsilon) and
    (Abs(A.Rotation.Z - B.Rotation.Z) < Epsilon) and
    (Abs(A.Rotation.W - B.Rotation.W) < Epsilon);
  Negated := (Abs(A.Rotation.X + B.Rotation.X) < Epsilon) and
    (Abs(A.Rotation.Y + B.Rotation.Y) < Epsilon) and
    (Abs(A.Rotation.Z + B.Rotation.Z) < Epsilon) and
    (Abs(A.Rotation.W + B.Rotation.W) < Epsilon);
  Result := (Abs(A.Translation.X - B.Translation.X) < Epsilon) and
    (Abs(A.Translation.Y - B.Translation.Y) < Epsilon) and
    (Abs(A.Translation.Z - B.Translation.Z) < Epsilon) and
    (Direct or Negated);
end;

function EncodeTimelinePoseOverlay(Model: TPmxModel;
  const BasePoses, CurrentPoses: TPmxBonePoses): string;
begin
  Result := EncodeTimelinePoseOverlay(Model, BasePoses, CurrentPoses,
    IdentityQuaternion, IdentityQuaternion);
end;

function EncodeTimelinePoseOverlay(Model: TPmxModel;
  const BasePoses, CurrentPoses: TPmxBonePoses;
  const BaseRoot, CurrentRoot: TPmxQuaternion): string;
begin
  Result := EncodeTimelinePoseOverlay(Model, BasePoses, CurrentPoses,
    BaseRoot, CurrentRoot, 0, 0, 0, 0);
end;

function EncodeTimelinePoseOverlay(Model: TPmxModel;
  const BasePoses, CurrentPoses: TPmxBonePoses;
  const BaseRoot, CurrentRoot: TPmxQuaternion;
  BaseYaw, BasePitch, CurrentYaw, CurrentPitch: Single): string;
var
  BoneIndex, Count, Limit: Integer;
  NamedPoses: TPmxNamedBonePoses;
  IncludeRoot: Boolean;
begin
  Result := '';
  if Model = nil then Exit;
  Limit := Min(Length(Model.Bones),
    Min(Length(BasePoses), Length(CurrentPoses)));
  SetLength(NamedPoses, Limit);
  Count := 0;
  for BoneIndex := 0 to Limit - 1 do
    if not SameBonePose(BasePoses[BoneIndex],
      CurrentPoses[BoneIndex]) then
    begin
      NamedPoses[Count].BoneName := Model.Bones[BoneIndex].Name;
      NamedPoses[Count].Pose := CurrentPoses[BoneIndex];
      Inc(Count);
    end;
  SetLength(NamedPoses, Count);
  IncludeRoot := (Abs(BaseRoot.X - CurrentRoot.X) +
      Abs(BaseRoot.Y - CurrentRoot.Y) +
      Abs(BaseRoot.Z - CurrentRoot.Z) +
      Abs(BaseRoot.W - CurrentRoot.W) > 0.00001) and
    (Abs(BaseRoot.X + CurrentRoot.X) +
      Abs(BaseRoot.Y + CurrentRoot.Y) +
      Abs(BaseRoot.Z + CurrentRoot.Z) +
      Abs(BaseRoot.W + CurrentRoot.W) > 0.00001);
  Result := EncodePoseDataWithRootAndAngle(NamedPoses, CurrentRoot,
    IncludeRoot, CurrentYaw, CurrentPitch,
    (Abs(CurrentYaw - BaseYaw) > 0.0001) or
    (Abs(CurrentPitch - BasePitch) > 0.0001));
end;

end.
