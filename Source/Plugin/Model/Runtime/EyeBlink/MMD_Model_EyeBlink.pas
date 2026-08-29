unit MMD_Model_EyeBlink;

// モデルオブジェクトごとに再現可能な目パチ時刻と閉眼量を計算する。

interface

type
  TMmdEyeBlinkRuntimeState = record
    Initialized: Boolean;
    Seed: UInt64;
    LastFrame: Int64;
    NextBlinkStart: Int64;
    BlinkEnd: Int64;
    CycleIndex: Int64;
    Fps: Double;
    IntervalSec: Double;
    SpeedSec: Double;
    OffsetSec: Double;
  end;

// シークや設定変更時に、呼出側が保持する目パチ進行状態を未初期化へ戻す。
procedure ResetMmdEyeBlinkState(var State: TMmdEyeBlinkRuntimeState);
// EffectIDとObjectIDから、整数オーバーフローを起こさない安定シードを返す。
function BuildMmdEyeBlinkSeed(EffectID, ObjectID: Int64): UInt64;
// 現在フレームの閉眼量0..1を返し、次回計算に必要な進行状態を更新する。
function CalculateMmdEyeBlinkAmount(Frame: Integer; Fps, IntervalSec,
  SpeedSec, OffsetSec: Double; Seed: UInt64;
  var State: TMmdEyeBlinkRuntimeState): Single;

implementation

uses
  System.Math;

function Int64Bits(Value: Int64): UInt64;
begin
  Move(Value, Result, SizeOf(Result));
end;

function BuildMmdEyeBlinkSeed(EffectID, ObjectID: Int64): UInt64;
var
  ObjectBits: UInt64;
begin
  // 乗算による混合はオーバーフロー検査有効時に描画コールバックを中断するため、ビット演算だけを使う。
  ObjectBits := Int64Bits(ObjectID);
  Result := Int64Bits(EffectID) xor ((ObjectBits shl 17) or
    (ObjectBits shr 47)) xor UInt64($9E3779B97F4A7C15);
  Result := Result xor (Result shr 30);
  Result := Result xor (Result shl 27);
  Result := Result xor (Result shr 31);
end;

function StableRandomValue(CycleIndex: Int64; Seed: UInt64): Cardinal;
var
  Value: Cardinal;
begin
  Value := Cardinal(UInt64(CycleIndex) and $FFFFFFFF) xor
    Cardinal((UInt64(CycleIndex) shr 32) and $FFFFFFFF) xor
    Cardinal(Seed and $FFFFFFFF) xor Cardinal(Seed shr 32);
  Value := Value xor (Value shr 16);
  Value := Cardinal((UInt64(Value) * $7FEB352D) and $FFFFFFFF);
  Value := Value xor (Value shr 15);
  Value := Cardinal((UInt64(Value) * $846CA68B) and $FFFFFFFF);
  Result := Value xor (Value shr 16);
end;

function BlinkDelayFrames(Fps, IntervalSec: Double; Seed: UInt64;
  CycleIndex: Int64): Int64;
var
  JitterSec, JitterWidth, RandomUnit, WaitSec: Double;
begin
  JitterWidth := Min(1.0, Max(0.0, IntervalSec - 0.1));
  RandomUnit := StableRandomValue(CycleIndex, Seed) / High(Cardinal);
  JitterSec := (RandomUnit * 2.0 - 1.0) * JitterWidth;
  WaitSec := Max(0.1, IntervalSec + JitterSec);
  Result := Max(1, Round(WaitSec * Fps));
end;

function SameParameters(const State: TMmdEyeBlinkRuntimeState; Fps,
  IntervalSec, SpeedSec, OffsetSec: Double; Seed: UInt64): Boolean;
begin
  Result := State.Initialized and (State.Seed = Seed) and
    SameValue(State.Fps, Fps, 0.000001) and
    SameValue(State.IntervalSec, IntervalSec, 0.000001) and
    SameValue(State.SpeedSec, SpeedSec, 0.000001) and
    SameValue(State.OffsetSec, OffsetSec, 0.000001);
end;

procedure ResetMmdEyeBlinkState(var State: TMmdEyeBlinkRuntimeState);
begin
  State := Default(TMmdEyeBlinkRuntimeState);
  State.LastFrame := -1;
  State.NextBlinkStart := -1;
  State.BlinkEnd := -1;
end;

function CalculateMmdEyeBlinkAmount(Frame: Integer; Fps, IntervalSec,
  SpeedSec, OffsetSec: Double; Seed: UInt64;
  var State: TMmdEyeBlinkRuntimeState): Single;
var
  BlinkFrames, EffectiveFrame, Elapsed, HalfFrames, PeakFirstFrame,
    PeakLastFrame, PreviousFrame: Int64;
  CrossedPeak: Boolean;
begin
  Result := 0;
  if IsNan(Fps) or IsInfinite(Fps) or IsNan(IntervalSec) or
    IsInfinite(IntervalSec) or IsNan(SpeedSec) or
    IsInfinite(SpeedSec) or IsNan(OffsetSec) or
    IsInfinite(OffsetSec) or (Fps <= 0) then
    Exit;
  IntervalSec := EnsureRange(IntervalSec, 1.0, 20.0);
  SpeedSec := EnsureRange(SpeedSec, 0.01, 100.0);
  OffsetSec := EnsureRange(OffsetSec, -20.0, 20.0);
  EffectiveFrame := Int64(Frame) - Round(OffsetSec * Fps);
  BlinkFrames := Max(1, Round(SpeedSec * Fps));

  if not SameParameters(State, Fps, IntervalSec, SpeedSec, OffsetSec,
    Seed) or (EffectiveFrame < State.LastFrame) then
  begin
    ResetMmdEyeBlinkState(State);
    State.Initialized := True;
    State.Seed := Seed;
    State.Fps := Fps;
    State.IntervalSec := IntervalSec;
    State.SpeedSec := SpeedSec;
    State.OffsetSec := OffsetSec;
    State.CycleIndex := 0;
    State.NextBlinkStart := BlinkDelayFrames(Fps, IntervalSec, Seed, 0);
    State.BlinkEnd := State.NextBlinkStart + BlinkFrames - 1;
  end;

  PreviousFrame := State.LastFrame;
  if EffectiveFrame < 0 then
  begin
    State.LastFrame := EffectiveFrame;
    Exit;
  end;

  // 再生時に中間フレームが省略されても、閉じ切る区間を飛び越えた場合は現在フレームで100%を補う。
  PeakFirstFrame := State.NextBlinkStart + (BlinkFrames - 1) div 2;
  PeakLastFrame := State.NextBlinkStart + BlinkFrames div 2;
  CrossedPeak := (PreviousFrame >= 0) and
    (PreviousFrame < PeakFirstFrame) and
    (EffectiveFrame > PeakLastFrame) and
    (EffectiveFrame <= State.BlinkEnd);

  while EffectiveFrame > State.BlinkEnd do
  begin
    Inc(State.CycleIndex);
    State.NextBlinkStart := State.BlinkEnd + BlinkDelayFrames(Fps,
      IntervalSec, Seed, State.CycleIndex);
    State.BlinkEnd := State.NextBlinkStart + BlinkFrames - 1;
  end;

  State.LastFrame := EffectiveFrame;
  if CrossedPeak then
    Exit(1.0);
  if EffectiveFrame < State.NextBlinkStart then
    Exit;
  Elapsed := EffectiveFrame - State.NextBlinkStart;
  if BlinkFrames = 1 then
    Exit(1.0);

  // 奇数長は1フレーム、偶数長は2フレームを100%にし、中央がフレーム間に落ちる浅い瞬きを防ぐ。
  HalfFrames := (BlinkFrames + 1) div 2;
  if Elapsed < HalfFrames then
    Result := (Elapsed + 1) / HalfFrames
  else
    Result := (BlinkFrames - Elapsed) / HalfFrames;
  Result := EnsureRange(Result, 0.0, 1.0);
end;

end.
