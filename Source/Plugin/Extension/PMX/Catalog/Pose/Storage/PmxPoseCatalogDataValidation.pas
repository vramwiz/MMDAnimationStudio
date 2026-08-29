unit PmxPoseCatalogDataValidation;

// PMXポーズカタログが保持する姿勢・表情・目パチ・口パクJSONを正規化する。

interface

const
  EmptyPmxPoseData = '{"version":1,"bones":[]}';

// 姿勢JSONを検証し、不正値では正規の空姿勢JSONを返す。
function NormalizePoseData(const Value: string): string;
// 初期表情JSONを検証し、不正値では正規の空設定JSONを返す。
function NormalizeInitialExpressionData(const Value: string): string;
// 目パチJSONを検証し、不正値では正規の空設定JSONを返す。
function NormalizeInitialEyeBlinkData(const Value: string): string;
// 口パクJSONを検証し、不正値では正規の空設定JSONを返す。
function NormalizeInitialLipSyncData(const Value: string): string;

implementation

uses
  MmdEyeBlinkSettingCodec,
  MmdLipSyncSettingCodec,
  MmdMorphSettingCodec,
  PmxPose,
  PmxPoseCodec;

function NormalizePoseData(const Value: string): string;
var
  Poses: TPmxNamedBonePoses;
begin
  Result := Value;
  if not TryDecodePoseData(Result, Poses) then
    Result := EmptyPmxPoseData;
end;

function NormalizeInitialExpressionData(const Value: string): string;
var
  Values: TMmdNamedMorphWeights;
begin
  Result := Value;
  if not TryDecodeMmdMorphSettingData(Result, Values) then
    Result := EmptyMmdMorphSettingData;
end;

function NormalizeInitialEyeBlinkData(const Value: string): string;
var
  Setting: TMmdEyeBlinkSetting;
begin
  Result := Value;
  if not TryDecodeMmdEyeBlinkSettingData(Result, Setting) then
    Result := EmptyMmdEyeBlinkSettingData;
end;

function NormalizeInitialLipSyncData(const Value: string): string;
var
  Setting: TMmdLipSyncSetting;
begin
  Result := Value;
  if not TryDecodeMmdLipSyncSettingData(Result, Setting) then
    Result := EmptyMmdLipSyncSettingData;
end;

end.
