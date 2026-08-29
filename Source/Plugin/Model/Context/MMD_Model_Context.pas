unit MMD_Model_Context;

// 表示モデルの可変状態をEffectID単位に分離し、生成・描画・破棄の寿命を管理する。

interface

uses
  MmdEyeBlinkSettingCodec,
  MmdMorphSettingCodec,
  MMD_Model_LipSyncContext,
  MMD_Model_LipSyncProtocol,
  MMD_Model_EyeBlink,
  PmxModel,
  PmxMorph,
  PmxPose;

type
  TMmdModelContext = class
  private
    FEffectID: Int64;
    FObjectID: Int64;
    FExternalExpressionModel: TPmxModel;
    FExternalExpressionNamed: TMmdNamedMorphWeights;
    FExternalExpressionText: string;
    FExternalExpressionValid: Boolean;
    FExternalExpressionWeights: TPmxMorphWeights;
    FExternalPoseText: string;
    FExternalPoses: TPmxNamedBonePoses;
    FExternalPoseValid: Boolean;
    FEyeBlinkModel: TPmxModel;
    FEyeBlinkMorphIndex: Integer;
    FEyeBlinkRuntime: TMmdEyeBlinkRuntimeState;
    FEyeBlinkSetting: TMmdEyeBlinkSetting;
    FEyeBlinkText: string;
    FEyeBlinkValid: Boolean;
    FInitialExpressionModel: TPmxModel;
    FInitialExpressionNamed: TMmdNamedMorphWeights;
    FInitialExpressionText: string;
    FInitialExpressionValid: Boolean;
    FInitialExpressionWeights: TPmxMorphWeights;
    FLipSync: TMmdModelLipSyncContext;
    FStandardPoseText: string;
    FStandardPoses: TPmxNamedBonePoses;
    FStandardPoseValid: Boolean;
    function GetEyeBlinkClosedWeight: Single;
    function GetLipSyncWeights: TPmxMorphWeights;
  public
    // AviUtl2が割り当てたEffectIDに対応する空の状態を生成する。
    constructor Create(AEffectID: Int64);
    // 所有する口パク状態を破棄する。共有メモリやモデル本体は所有しない。
    destructor Destroy; override;
    // 最新の描画通知に含まれるObjectIDを診断・対応確認用に記録する。
    procedure SetObjectID(AObjectID: Int64);
    // 入力文字列が変化した場合だけ外部姿勢JSONを再解析する。
    procedure UpdateExternalPose(const Text: string);
    // 入力文字列が変化した場合だけ参照表情JSONを再解析する。
    procedure UpdateExternalExpression(const Text: string);
    // 入力文字列が変化した場合だけ標準姿勢JSONを再解析する。
    procedure UpdateStandardPose(const Text: string);
    // 入力文字列が変化した場合だけ初期表情JSONを再解析する。
    procedure UpdateInitialExpression(const Text: string);
    // 入力文字列が変化した場合だけ目パチJSONを再解析し、進行状態を初期化する。
    procedure UpdateEyeBlink(const Text: string);
    // 入力文字列が変化した場合だけ口パクJSONを再解析し、補間状態を初期化する。
    procedure UpdateLipSync(const Text: string);
    // 現在モデルへ名前付き初期表情を解決し、有効な非ゼロ値があればTrueを返す。
    function ResolveInitialExpression(const Model: TPmxModel): Boolean;
    // 現在モデルへ参照表情を解決し、有効な非ゼロ値があればTrueを返す。
    function ResolveExternalExpression(const Model: TPmxModel): Boolean;
    // 現在モデルの目パチ用モーフを解決する。
    function ResolveEyeBlink(const Model: TPmxModel): Boolean;
    // 現在モデルの開閉・音素モーフ名をIndexへ解決する。
    function ResolveLipSync(const Model: TPmxModel): Boolean;
    // オブジェクト相対フレームに対応する閉眼量0..1を返す。
    function EyeBlinkAmount(Frame: Integer; Fps, IntervalSec, SpeedSec,
      OffsetSec: Double): Single;
    // 共有メモリの現在値を口パクウェイトへ変換し、補間後の値を返す。
    function UpdateLipSyncWeights(const Sample: TMmdLipSyncSample;
      HasSample: Boolean; Frame: Integer; Fps, SpeedSec: Double;
      Strength: Single): Boolean;
    property EffectID: Int64 read FEffectID;
    property ObjectID: Int64 read FObjectID;
    property ExternalPoses: TPmxNamedBonePoses read FExternalPoses;
    property ExternalPoseValid: Boolean read FExternalPoseValid;
    property ExternalExpressionValid: Boolean read FExternalExpressionValid;
    property ExternalExpressionWeights: TPmxMorphWeights
      read FExternalExpressionWeights;
    property InitialExpressionValid: Boolean read FInitialExpressionValid;
    property InitialExpressionWeights: TPmxMorphWeights
      read FInitialExpressionWeights;
    property EyeBlinkClosedWeight: Single read GetEyeBlinkClosedWeight;
    property EyeBlinkMorphIndex: Integer read FEyeBlinkMorphIndex;
    property LipSyncWeights: TPmxMorphWeights read GetLipSyncWeights;
    property StandardPoses: TPmxNamedBonePoses read FStandardPoses;
    property StandardPoseValid: Boolean read FStandardPoseValid;
  end;

// AviUtl2のFunc_Createから呼び、EffectIDに対応するコンテキストを登録して返す。
function CreateModelContext(EffectID: Int64): Pointer; cdecl;
// 描画中にEffectIDのコンテキストを取得する。戻り値はReleaseまで呼出側が排他的に所有する。
function AcquireModelContext(EffectID, ObjectID: Int64): TMmdModelContext;
// AcquireModelContextで得た排他所有を解放する。nilは何もしない。
procedure ReleaseModelContext(Context: TMmdModelContext);
// AviUtl2のFunc_Destroyから呼び、進行中の描画完了を待って対応Contextを破棄する。
procedure DestroyModelContext(EffectID: Int64; UserData: Pointer); cdecl;

implementation

uses
  System.Generics.Collections,
  System.SysUtils,
  PmxPoseCodec;

var
  Contexts: TObjectDictionary<Int64, TMmdModelContext>;
  ContextsLock: TObject;

constructor TMmdModelContext.Create(AEffectID: Int64);
begin
  inherited Create;
  FEffectID := AEffectID;
  FEyeBlinkMorphIndex := -1;
  FLipSync := TMmdModelLipSyncContext.Create;
  ResetMmdEyeBlinkState(FEyeBlinkRuntime);
end;

destructor TMmdModelContext.Destroy;
begin
  FLipSync.Free;
  inherited;
end;

procedure TMmdModelContext.SetObjectID(AObjectID: Int64);
begin
  FObjectID := AObjectID;
end;

procedure DecodePoseText(const Text: string; var CachedText: string;
  var CachedPoses: TPmxNamedBonePoses; var CachedValid: Boolean);
begin
  if CachedText = Text then
    Exit;
  CachedText := Text;
  CachedPoses := nil;
  CachedValid := False;
  try
    CachedValid := TryDecodePoseData(Text, CachedPoses);
  except
    CachedPoses := nil;
  end;
end;

procedure TMmdModelContext.UpdateExternalPose(const Text: string);
begin
  DecodePoseText(Text, FExternalPoseText, FExternalPoses, FExternalPoseValid);
end;

procedure TMmdModelContext.UpdateExternalExpression(const Text: string);
begin
  if FExternalExpressionText = Text then Exit;
  FExternalExpressionText := Text;
  FExternalExpressionModel := nil;
  FExternalExpressionNamed := nil;
  FExternalExpressionWeights := nil;
  FExternalExpressionValid := False;
  try
    FExternalExpressionValid := TryDecodeMmdMorphSettingData(Text,
      FExternalExpressionNamed);
  except
    FExternalExpressionNamed := nil;
  end;
end;

procedure TMmdModelContext.UpdateStandardPose(const Text: string);
begin
  DecodePoseText(Text, FStandardPoseText, FStandardPoses, FStandardPoseValid);
end;

function TMmdModelContext.GetEyeBlinkClosedWeight: Single;
begin
  Result := FEyeBlinkSetting.ClosedWeight;
end;

procedure TMmdModelContext.UpdateInitialExpression(const Text: string);
begin
  if FInitialExpressionText = Text then
    Exit;
  FInitialExpressionText := Text;
  FInitialExpressionModel := nil;
  FInitialExpressionNamed := nil;
  FInitialExpressionWeights := nil;
  FInitialExpressionValid := False;
  try
    FInitialExpressionValid := TryDecodeMmdMorphSettingData(Text,
      FInitialExpressionNamed);
  except
    FInitialExpressionNamed := nil;
  end;
end;

procedure TMmdModelContext.UpdateEyeBlink(const Text: string);
begin
  if FEyeBlinkText = Text then
    Exit;
  FEyeBlinkText := Text;
  FEyeBlinkModel := nil;
  FEyeBlinkMorphIndex := -1;
  FEyeBlinkValid := False;
  ResetMmdEyeBlinkState(FEyeBlinkRuntime);
  try
    FEyeBlinkValid := TryDecodeMmdEyeBlinkSettingData(Text,
      FEyeBlinkSetting);
  except
    FEyeBlinkValid := False;
  end;
end;

procedure TMmdModelContext.UpdateLipSync(const Text: string);
begin
  FLipSync.UpdateSetting(Text);
end;

function TMmdModelContext.ResolveInitialExpression(
  const Model: TPmxModel): Boolean;
var
  Weight: Single;
begin
  Result := False;
  if not FInitialExpressionValid or (Model = nil) then
    Exit;
  if FInitialExpressionModel <> Model then
  begin
    ApplyMmdNamedMorphWeights(Model, FInitialExpressionNamed,
      FInitialExpressionWeights);
    FInitialExpressionModel := Model;
  end;
  for Weight in FInitialExpressionWeights do
    if Weight > 0.000001 then
      Exit(True);
end;

function TMmdModelContext.ResolveExternalExpression(
  const Model: TPmxModel): Boolean;
var
  Weight: Single;
begin
  Result := False;
  if not FExternalExpressionValid or (Model = nil) then Exit;
  if FExternalExpressionModel <> Model then
  begin
    ApplyMmdNamedMorphWeights(Model, FExternalExpressionNamed,
      FExternalExpressionWeights);
    FExternalExpressionModel := Model;
  end;
  for Weight in FExternalExpressionWeights do
    if Weight > 0.000001 then Exit(True);
end;

function TMmdModelContext.ResolveEyeBlink(const Model: TPmxModel): Boolean;
begin
  Result := False;
  if not FEyeBlinkValid or (Model = nil) or
    (FEyeBlinkSetting.MorphName = '') or
    (FEyeBlinkSetting.ClosedWeight <= 0) then
    Exit;
  if FEyeBlinkModel <> Model then
  begin
    FEyeBlinkMorphIndex := FindMorphIndex(Model,
      FEyeBlinkSetting.MorphName);
    FEyeBlinkModel := Model;
  end;
  Result := (FEyeBlinkMorphIndex >= 0) and
    (FEyeBlinkMorphIndex < Length(Model.Morphs));
end;

function TMmdModelContext.ResolveLipSync(const Model: TPmxModel): Boolean;
begin
  Result := FLipSync.Resolve(Model);
end;

function TMmdModelContext.UpdateLipSyncWeights(
  const Sample: TMmdLipSyncSample; HasSample: Boolean; Frame: Integer;
  Fps, SpeedSec: Double; Strength: Single): Boolean;
begin
  Result := FLipSync.UpdateWeights(Sample, HasSample, Frame, Fps, SpeedSec,
    Strength);
end;

function TMmdModelContext.GetLipSyncWeights: TPmxMorphWeights;
begin
  Result := FLipSync.Weights;
end;

function TMmdModelContext.EyeBlinkAmount(Frame: Integer; Fps, IntervalSec,
  SpeedSec, OffsetSec: Double): Single;
var
  Seed: UInt64;
begin
  Result := 0;
  if not FEyeBlinkValid then
    Exit;
  Seed := BuildMmdEyeBlinkSeed(FEffectID, FObjectID);
  Result := CalculateMmdEyeBlinkAmount(Frame, Fps, IntervalSec, SpeedSec,
    OffsetSec, Seed, FEyeBlinkRuntime);
end;

function CreateModelContext(EffectID: Int64): Pointer; cdecl;
var
  Context: TMmdModelContext;
  Existing: TMmdModelContext;
begin
  Result := nil;
  try
    Context := TMmdModelContext.Create(EffectID);
    TMonitor.Enter(ContextsLock);
    try
      if Contexts.TryGetValue(EffectID, Existing) then
      begin
        Context.Free;
        Context := Existing;
      end
      else
        Contexts.Add(EffectID, Context);
    finally
      TMonitor.Exit(ContextsLock);
    end;
    Result := Context;
  except
  end;
end;

function AcquireModelContext(EffectID, ObjectID: Int64): TMmdModelContext;
begin
  Result := nil;
  // Registry→Contextの順で固定し、同一Effectの並列描画と破棄の順序を一意にする。
  TMonitor.Enter(ContextsLock);
  try
    if not Contexts.TryGetValue(EffectID, Result) then
    begin
      Result := TMmdModelContext.Create(EffectID);
      Contexts.Add(EffectID, Result);
    end;
    TMonitor.Enter(Result);
  finally
    TMonitor.Exit(ContextsLock);
  end;
  Result.SetObjectID(ObjectID);
end;

procedure ReleaseModelContext(Context: TMmdModelContext);
begin
  if Context <> nil then
    TMonitor.Exit(Context);
end;

procedure DestroyModelContext(EffectID: Int64; UserData: Pointer); cdecl;
var
  Context: TMmdModelContext;
begin
  try
    Context := nil;
    TMonitor.Enter(ContextsLock);
    try
      if Contexts.TryGetValue(EffectID, Context) then
        Contexts.ExtractPair(EffectID);
    finally
      TMonitor.Exit(ContextsLock);
    end;
    if Context = nil then
      Context := TMmdModelContext(UserData);
    if Context <> nil then
    begin
      // 進行中の描画が終わるまで待ってから解放する。
      TMonitor.Enter(Context);
      TMonitor.Exit(Context);
      Context.Free;
    end;
  except
  end;
end;

initialization
  ContextsLock := TObject.Create;
  Contexts := TObjectDictionary<Int64, TMmdModelContext>.Create([doOwnsValues]);

finalization
  Contexts.Free;
  ContextsLock.Free;

end.
