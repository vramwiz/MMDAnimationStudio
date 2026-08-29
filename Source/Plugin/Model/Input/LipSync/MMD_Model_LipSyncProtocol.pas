unit MMD_Model_LipSyncProtocol;

// Syncroh2互換のセリフ・ソング文字列を、モデル非依存の口パク入力へ変換する。

interface

uses
  MmdLipSyncSettingCodec;

type
  TMmdLipSyncSampleKind = (mlskNone, mlskOpenClose, mlskPhoneme);
  TMmdLipSyncSample = record
    Kind: TMmdLipSyncSampleKind;
    OpenAmount: Single;
    Phoneme: TMmdLipSyncPhoneme;
  end;

// セリフ共有文字列から音量、音素、aiueo、通常セリフの順で現在の口パク値を解決する。
function TryParseMmdLipSyncTalkText(const Text: string; FallbackSpeedSec: Double;
  out Sample: TMmdLipSyncSample): Boolean;
// ソング共有文字列のnote_labまたはnote_AIUEOを現在の口パク値へ変換する。
function TryParseMmdLipSyncSongText(const Text: string; out Sample: TMmdLipSyncSample): Boolean;
// ASCIIまたは平仮名の単一母音を口パク音素へ変換する。
function TryParseMmdLipSyncPhoneme(const Text: string; out Phoneme: TMmdLipSyncPhoneme): Boolean;

implementation

uses
  System.Math,
  System.StrUtils,
  System.SysUtils,
  KeyValueText;

function TryParseMmdLipSyncPhoneme(const Text: string;
  out Phoneme: TMmdLipSyncPhoneme): Boolean;
var
  Value: string;
begin
  Value := Trim(Text);
  Result := True;
  if SameText(Value, 'A') or (Value = #$3042) then Phoneme := mlpA
  else if SameText(Value, 'I') or (Value = #$3044) then Phoneme := mlpI
  else if SameText(Value, 'U') or (Value = #$3046) then Phoneme := mlpU
  else if SameText(Value, 'E') or (Value = #$3048) then Phoneme := mlpE
  else if SameText(Value, 'O') or (Value = #$304A) then Phoneme := mlpO
  else if SameText(Value, 'N') or (Value = #$3093) then Phoneme := mlpN
  else Result := False;
end;

function LabCommand(const Line: string): string;
var
  Comma: Integer;
begin
  Result := Trim(Line);
  Comma := LastDelimiter(',', Result);
  if Comma > 0 then
    Result := Trim(Copy(Result, Comma + 1, MaxInt));
end;

function TryParseLab(const Line: string; out Sample: TMmdLipSyncSample): Boolean;
var
  Command: string;
  Volume: Integer;
begin
  Result := False;
  if Line = '' then
    Exit;
  Command := LabCommand(Line);
  if StartsText('vol:', Command) then
  begin
    Volume := EnsureRange(StrToIntDef(Copy(Command, 5, MaxInt), 0), 0, 100);
    Sample.Kind := mlskOpenClose;
    Sample.OpenAmount := Volume / 100;
    Exit(True);
  end;
  if TryParseMmdLipSyncPhoneme(Command, Sample.Phoneme) then
  begin
    Sample.Kind := mlskPhoneme;
    Exit(True);
  end;
end;

function TryCurrentAiueo(const Text: string;
  out Phoneme: TMmdLipSyncPhoneme): Boolean;
var
  Aiueo: string;
  CharIndex, Frame, TotalFrames: Integer;
begin
  Result := False;
  Aiueo := GetKeyValue(Text, 'aiueo');
  Frame := GetKeyValueInt(Text, 'frame');
  TotalFrames := GetKeyValueInt(Text, 'total_frames');
  if (Aiueo = '') or (Frame < 0) or (TotalFrames <= 0) then
    Exit;
  Frame := EnsureRange(Frame, 0, TotalFrames - 1);
  CharIndex := (Int64(Frame) * Length(Aiueo)) div TotalFrames + 1;
  Result := TryParseMmdLipSyncPhoneme(Aiueo[CharIndex], Phoneme);
end;

function StableTextSeed(const Text: string): Cardinal;
var
  C: Char;
begin
  Result := $7F4A7C15;
  for C in Text do
  begin
    Result := Result xor Ord(C);
    Result := (Result shl 7) or (Result shr 25);
    Result := Result xor (Result shr 11);
  end;
end;

function StableStageValue(BlockIndex: Int64; Seed, Salt: Cardinal): Cardinal;
begin
  Result := Seed xor Salt xor Cardinal(UInt64(BlockIndex) and $FFFFFFFF) xor
    Cardinal(UInt64(BlockIndex) shr 32);
  Result := Result xor (Result shl 13);
  Result := Result xor (Result shr 17);
  Result := Result xor (Result shl 5);
end;

function TalkFallbackAmount(const Text: string; SpeedSec: Double): Single;
var
  BlockFrames, Frame, Fps, FrameInBlock, Stage, StepIndex: Integer;
  BlockIndex: Int64;
  Seed: Cardinal;
begin
  Result := 0;
  Frame := GetKeyValueInt(Text, 'frame');
  Fps := GetKeyValueInt(Text, 'framerate');
  if (Frame < 0) or (Fps <= 0) then
    Exit;
  BlockFrames := Max(4, Round(EnsureRange(SpeedSec, 0.01, 100.0) * Fps));
  BlockIndex := Frame div BlockFrames;
  FrameInBlock := Frame mod BlockFrames;
  StepIndex := Min(3, (FrameInBlock * 4) div BlockFrames);
  Seed := StableTextSeed(GetKeyValue(Text, 'serif'));
  case StepIndex of
    0: Stage := 4 + Integer(StableStageValue(BlockIndex, Seed, $9E3779B9) mod 2);
    1: Stage := 2 + Integer(StableStageValue(BlockIndex, Seed, $A341316C) mod 3);
    2: Stage := 1 + Integer(StableStageValue(BlockIndex, Seed, $AD90777D) mod 2);
  else
    Stage := 2 + Integer(StableStageValue(BlockIndex, Seed, $C8013EA4) mod 3);
  end;
  Result := (Stage - 1) / 4;
end;

function TryParseMmdLipSyncTalkText(const Text: string; FallbackSpeedSec: Double;
  out Sample: TMmdLipSyncSample): Boolean;
var
  HasSpeechState, SpeechActive: Boolean;
begin
  Sample := Default(TMmdLipSyncSample);
  Result := False;
  if Text = '' then
    Exit;
  HasSpeechState := Pos('speech_active=', Text) > 0;
  SpeechActive := SameText(GetKeyValue(Text, 'speech_active'), 'true') or
    (GetKeyValue(Text, 'speech_active') = '1');
  if HasSpeechState and not SpeechActive then
  begin
    Sample.Kind := mlskOpenClose;
    Exit(True);
  end;
  if TryParseLab(GetKeyValue(Text, 'lab'), Sample) then
    Exit(True);
  if SameText(GetKeyValue(Text, 'lab_data'), 'true') or
    (GetKeyValue(Text, 'lab_data') = '1') then
  begin
    // 元LABがある無音区間では通常セリフ口パクへ戻さず閉じる。
    Sample.Kind := mlskOpenClose;
    Exit(True);
  end;
  if TryCurrentAiueo(Text, Sample.Phoneme) then
  begin
    Sample.Kind := mlskPhoneme;
    Exit(True);
  end;
  if GetKeyValue(Text, 'serif') <> '' then
  begin
    Sample.Kind := mlskOpenClose;
    Sample.OpenAmount := TalkFallbackAmount(Text, FallbackSpeedSec);
    Exit(True);
  end;
end;

function TryParseMmdLipSyncSongText(const Text: string;
  out Sample: TMmdLipSyncSample): Boolean;
begin
  Sample := Default(TMmdLipSyncSample);
  Result := False;
  if Text = '' then
    Exit;
  if TryParseLab(GetKeyValue(Text, 'note_lab'), Sample) then
    Exit(True);
  Result := TryParseMmdLipSyncPhoneme(GetKeyValue(Text, 'note_AIUEO'),
    Sample.Phoneme);
  if Result then
    Sample.Kind := mlskPhoneme;
end;

end.
