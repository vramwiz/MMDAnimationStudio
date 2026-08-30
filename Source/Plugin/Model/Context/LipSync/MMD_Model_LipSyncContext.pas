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
  System.SysUtils
{$IFDEF DEBUG}
  , MMD_Model_DebugLog,
  Winapi.Windows
{$ENDIF}
  ;

{$IFDEF DEBUG}
var
  LipSyncContextLogCount: Integer;
{$ENDIF}

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
{$IFDEF DEBUG}
  if InterlockedIncrement(LipSyncContextLogCount) <= 300 then
    MmdModelDebugLog(Format(
      'LipSync setting: length=%d valid=%d initialized=%d open=%s weight=%.4f',
      [Length(Text), Ord(FValid), Ord(FSetting.Initialized),
       FSetting.OpenClose.MorphName, FSetting.OpenClose.Weight]));
{$ENDIF}
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
{$IFDEF DEBUG}
  if InterlockedIncrement(LipSyncContextLogCount) <= 300 then
    MmdModelDebugLog(Format(
      'LipSync resolve: valid=%d result=%d morphs=%d open=%s:%d A=%s:%d I=%s:%d U=%s:%d E=%s:%d O=%s:%d N=%s:%d',
      [Ord(FValid), Ord(Result), Length(Model.Morphs),
       FSetting.OpenClose.MorphName, FOpenCloseIndex,
       FSetting.Phonemes[mlpA].MorphName, FPhonemeIndices[mlpA],
       FSetting.Phonemes[mlpI].MorphName, FPhonemeIndices[mlpI],
       FSetting.Phonemes[mlpU].MorphName, FPhonemeIndices[mlpU],
       FSetting.Phonemes[mlpE].MorphName, FPhonemeIndices[mlpE],
       FSetting.Phonemes[mlpO].MorphName, FPhonemeIndices[mlpO],
       FSetting.Phonemes[mlpN].MorphName, FPhonemeIndices[mlpN]]));
{$ENDIF}
end;

function TMmdModelLipSyncContext.UpdateWeights(
  const Sample: TMmdLipSyncSample; HasSample: Boolean; Frame: Integer;
  Fps, SpeedSec: Double; Strength: Single): Boolean;
var
{$IFDEF DEBUG}
  ActiveIndex: Integer;
  ActiveWeight: Single;
{$ENDIF}
  Alpha, TargetWeight: Single;
  I, MorphIndex: Integer;
  Target: TPmxMorphWeights;
begin
  Result := False;
{$IFDEF DEBUG}
  ActiveIndex := -1;
  ActiveWeight := 0;
{$ENDIF}
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
    begin
{$IFDEF DEBUG}
      if Abs(FCurrentWeights[I]) > Abs(ActiveWeight) then
      begin
        ActiveIndex := I;
        ActiveWeight := FCurrentWeights[I];
      end;
{$ENDIF}
      Result := True;
    end;
{$IFDEF DEBUG}
  if InterlockedIncrement(LipSyncContextLogCount) <= 300 then
    MmdModelDebugLog(Format(
      'LipSync weights: frame=%d has_sample=%d kind=%d phoneme=%d open=%.4f strength=%.4f result=%d active_index=%d active_weight=%.4f',
      [Frame, Ord(HasSample), Ord(Sample.Kind), Ord(Sample.Phoneme),
       Sample.OpenAmount, Strength, Ord(Result), ActiveIndex, ActiveWeight]));
{$ENDIF}
end;

end.
