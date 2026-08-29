unit MMD_Model_LipSyncContext;

// 1つのモデル表示オブジェクトに属する口パク設定、モーフ解決、フレーム補間を保持する。

interface

uses
  MmdLipSyncSettingCodec,
  MMD_Model_LipSyncProtocol,
  PmxModel,
  PmxMorph;

type
  TMmdModelLipSyncContext = class
  private
    FCurrentWeights: TPmxMorphWeights;
    FLastFrame: Integer;
    FModel: TPmxModel;
    FOpenCloseIndex: Integer;
    FPhonemeIndices: array[TMmdLipSyncPhoneme] of Integer;
    FSetting: TMmdLipSyncSetting;
    FText: string;
    FValid: Boolean;
    procedure ResetResolution;
  public
    // 未設定の口パク状態を生成する。モデルや共有メモリは所有しない。
    constructor Create;
    // 設定文字列が変わった場合だけ再解析し、解決済みモーフと補間状態を破棄する。
    procedure UpdateSetting(const Text: string);
    // 設定されたモーフ名を現在モデルへ解決し、使用可能な割り当てがあればTrueを返す。
    function Resolve(const Model: TPmxModel): Boolean;
    // 現在入力を目標ウェイトへ変換して速度・強さを反映し、非ゼロ状態ならTrueを返す。
    function UpdateWeights(const Sample: TMmdLipSyncSample; HasSample: Boolean;
      Frame: Integer; Fps, SpeedSec: Double; Strength: Single): Boolean;
    property Weights: TPmxMorphWeights read FCurrentWeights;
  end;

implementation

uses
  System.Math,
  System.SysUtils;

constructor TMmdModelLipSyncContext.Create;
begin
  inherited Create;
  ResetResolution;
end;

procedure TMmdModelLipSyncContext.ResetResolution;
var
  Phoneme: TMmdLipSyncPhoneme;
begin
  FModel := nil;
  FCurrentWeights := nil;
  FLastFrame := -1;
  FOpenCloseIndex := -1;
  for Phoneme := Low(TMmdLipSyncPhoneme) to High(TMmdLipSyncPhoneme) do
    FPhonemeIndices[Phoneme] := -1;
end;

procedure TMmdModelLipSyncContext.UpdateSetting(const Text: string);
begin
  if FText = Text then
    Exit;
  FText := Text;
  ResetResolution;
  FValid := False;
  try
    FValid := TryDecodeMmdLipSyncSettingData(Text, FSetting);
  except
    FValid := False;
  end;
end;

function TMmdModelLipSyncContext.Resolve(const Model: TPmxModel): Boolean;
var
  Phoneme: TMmdLipSyncPhoneme;
begin
  Result := False;
  if not FValid or (Model = nil) then
    Exit;
  if FModel <> Model then
  begin
    FOpenCloseIndex := FindMorphIndex(Model, FSetting.OpenClose.MorphName);
    for Phoneme := Low(TMmdLipSyncPhoneme) to High(TMmdLipSyncPhoneme) do
      FPhonemeIndices[Phoneme] := FindMorphIndex(Model,
        FSetting.Phonemes[Phoneme].MorphName);
    InitializeMorphWeights(Model, FCurrentWeights);
    FLastFrame := -1;
    FModel := Model;
  end;
  Result := FOpenCloseIndex >= 0;
  for Phoneme := Low(TMmdLipSyncPhoneme) to High(TMmdLipSyncPhoneme) do
    Result := Result or (FPhonemeIndices[Phoneme] >= 0);
end;

function TMmdModelLipSyncContext.UpdateWeights(
  const Sample: TMmdLipSyncSample; HasSample: Boolean; Frame: Integer;
  Fps, SpeedSec: Double; Strength: Single): Boolean;
var
  Alpha, TargetWeight: Single;
  I, MorphIndex: Integer;
  Target: TPmxMorphWeights;
begin
  Result := False;
  if not FValid or (FModel = nil) then
    Exit;
  InitializeMorphWeights(FModel, Target);
  Strength := EnsureRange(Strength, 0.0, 1.0);
  if HasSample then
    case Sample.Kind of
      mlskOpenClose:
        begin
          MorphIndex := FOpenCloseIndex;
          if MorphIndex >= 0 then
            Target[MorphIndex] := EnsureRange(Sample.OpenAmount, 0.0, 1.0) *
              FSetting.OpenClose.Weight * Strength;
        end;
      mlskPhoneme:
        begin
          MorphIndex := FPhonemeIndices[Sample.Phoneme];
          if MorphIndex >= 0 then
            Target[MorphIndex] := FSetting.Phonemes[Sample.Phoneme].Weight *
              Strength;
        end;
    end;

  // シークや巻き戻しでは履歴を使わず、そのフレームの入力へ即時同期する。
  if (Length(FCurrentWeights) <> Length(Target)) or (FLastFrame < 0) or
    (Frame <= FLastFrame) or (Frame > FLastFrame + 1) or (Fps <= 0) then
    FCurrentWeights := Copy(Target)
  else
  begin
    SpeedSec := EnsureRange(SpeedSec, 0.01, 100.0);
    Alpha := EnsureRange(1.0 / Max(1.0, SpeedSec * Fps), 0.0, 1.0);
    for I := 0 to High(Target) do
    begin
      TargetWeight := Target[I];
      FCurrentWeights[I] := FCurrentWeights[I] +
        (TargetWeight - FCurrentWeights[I]) * Alpha;
      if Abs(FCurrentWeights[I]) < 0.000001 then
        FCurrentWeights[I] := 0;
    end;
  end;
  FLastFrame := Frame;
  for I := 0 to High(FCurrentWeights) do
    if Abs(FCurrentWeights[I]) > 0.000001 then
      Exit(True);
end;

end.
