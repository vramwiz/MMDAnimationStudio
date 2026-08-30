unit MmdSerifAviUtlAliasProvider;

{$WARN IMPLICIT_STRING_CAST OFF}
{$WARN IMPLICIT_STRING_CAST_LOSS OFF}

// 共通Serifから要求されたオブジェクトをMMDAnimationStudio形式へ直列化する。
// Syncroh2のAliasManager、モジュール、スクリプトには依存しない。

interface

// MMDAnimationStudio固有のエイリアスProviderを共通Serifへ登録する。
procedure RegisterMmdSerifAviUtlAliasProvider;

implementation

uses
  System.Classes,
  System.IOUtils,
  System.SysUtils,
  AppFolderUtils,
  MmdSerifAviUtlNames,
  SerifAviUtlAliasProvider;

var
  GAliasBatch: TStringList;
  GObjectIndex: Integer;
  GFormatSettings: TFormatSettings;

const
  ALIAS_STANDARD_DRAWING = #$6A19#$6E96#$63CF#$753B;
  ALIAS_CENTER = #$4E2D#$5FC3;
  ALIAS_AXIS_ROTATION = #$8EF8#$56DE#$8EE2;
  ALIAS_SCALE = #$62E1#$5927#$7387;
  ALIAS_ASPECT_RATIO = #$7E26#$6A2A#$6BD4;
  ALIAS_OPACITY = #$900F#$660E#$5EA6;
  ALIAS_BLEND_MODE = #$5408#$6210#$30E2#$30FC#$30C9;
  ALIAS_NORMAL = #$901A#$5E38;
  ALIAS_DIRECTION_NONE = #$306A#$3057;
  ALIAS_AUDIO_FILE = #$97F3#$58F0#$30D5#$30A1#$30A4#$30EB;
  ALIAS_PLAYBACK_POSITION = #$518D#$751F#$4F4D#$7F6E;
  ALIAS_PLAYBACK_RANGE = #$518D#$751F#$7BC4#$56F2;
  ALIAS_PLAYBACK_SPEED = #$518D#$751F#$901F#$5EA6;
  ALIAS_FILE = #$30D5#$30A1#$30A4#$30EB;
  ALIAS_TRACK = #$30C8#$30E9#$30C3#$30AF;
  ALIAS_LOOP_PLAYBACK = #$30EB#$30FC#$30D7#$518D#$751F;
  ALIAS_AUDIO_PLAYBACK = #$97F3#$58F0#$518D#$751F;
  ALIAS_VOLUME = #$97F3#$91CF;
  ALIAS_PAN = #$5DE6#$53F3;
  ALIAS_IMAGE_FILE = #$753B#$50CF#$30D5#$30A1#$30A4#$30EB;
  ALIAS_DISPLAY_NUMBER = #$8868#$793A#$756A#$53F7;
  ALIAS_SEQUENCE_FILE = #$9023#$756A#$30D5#$30A1#$30A4#$30EB;

function EscapeAliasValue(const Value: string): string;
begin
  Result := StringReplace(Value, #13#10, '\n', [rfReplaceAll]);
  Result := StringReplace(Result, #13, '\n', [rfReplaceAll]);
  Result := StringReplace(Result, #10, '\n', [rfReplaceAll]);
end;

function FloatText(const Value: Double; const Digits: Integer): string;
begin
  Result := FormatFloat('0.' + StringOfChar('0', Digits), Value,
    GFormatSettings);
end;

procedure AddObjectHeader(Lines: TStrings; const ObjectIndex, Layer,
  FrameStart, FrameLength, Group: Integer);
begin
  Lines.Add(Format('[%d]', [ObjectIndex]));
  Lines.Add('layer=' + IntToStr(Layer));
  Lines.Add(Format('frame=%d,%d', [FrameStart, FrameStart + FrameLength]));
  if Group <> 0 then
    Lines.Add('group=' + IntToStr(Group));
end;

procedure AddFilterHeader(Lines: TStrings; const ObjectIndex,
  FilterIndex: Integer; const EffectName: string);
begin
  Lines.Add(Format('[%d.%d]', [ObjectIndex, FilterIndex]));
  Lines.Add('effect.name=' + EffectName);
end;

procedure AddStandardDrawing(Lines: TStrings; const ObjectIndex,
  FilterIndex: Integer);
begin
  AddFilterHeader(Lines, ObjectIndex, FilterIndex, ALIAS_STANDARD_DRAWING);
  Lines.Add('X=0.00');
  Lines.Add('Y=0.00');
  Lines.Add('Z=0.00');
  Lines.Add('Group=1');
  Lines.Add(ALIAS_CENTER + 'X=0.00');
  Lines.Add(ALIAS_CENTER + 'Y=0.00');
  Lines.Add(ALIAS_CENTER + 'Z=0.00');
  Lines.Add('Group3=1');
  Lines.Add('X' + ALIAS_AXIS_ROTATION + '=0.00');
  Lines.Add('Y' + ALIAS_AXIS_ROTATION + '=0.00');
  Lines.Add('Z' + ALIAS_AXIS_ROTATION + '=0.00');
  Lines.Add('Group2=1');
  Lines.Add(ALIAS_SCALE + '=100.000');
  Lines.Add(ALIAS_ASPECT_RATIO + '=0.000');
  Lines.Add(ALIAS_OPACITY + '=0.00');
  Lines.Add(ALIAS_BLEND_MODE + '=' + ALIAS_NORMAL);
end;

procedure BeginAliasBatch;
begin
  GAliasBatch.Clear;
  GObjectIndex := 0;
end;

procedure AddAudioAlias(const Data: TSerifAviUtlAudioAliasData);
var
  Index: Integer;
begin
  Index := GObjectIndex;
  Inc(GObjectIndex);
  AddObjectHeader(GAliasBatch, Index, Data.Layer, Data.FrameStart,
    Data.FrameLength, Data.Group);
  AddFilterHeader(GAliasBatch, Index, 0, ALIAS_AUDIO_FILE);
  GAliasBatch.Add(ALIAS_PLAYBACK_POSITION + '=' + FloatText(Data.StartPos, 3) + ',' +
    FloatText(Data.EndPos, 3) + ',' + ALIAS_PLAYBACK_RANGE + ',0');
  GAliasBatch.Add(ALIAS_PLAYBACK_SPEED + '=100.00');
  GAliasBatch.Add(ALIAS_FILE + '=' + EscapeAliasValue(Data.FileName));
  GAliasBatch.Add(ALIAS_TRACK + '=0');
  GAliasBatch.Add(ALIAS_LOOP_PLAYBACK + '=0');
  AddFilterHeader(GAliasBatch, Index, 1, ALIAS_AUDIO_PLAYBACK);
  GAliasBatch.Add(ALIAS_VOLUME + '=' + FloatText(Data.Volume, 2));
  GAliasBatch.Add(ALIAS_PAN + '=' + FloatText(Data.Pan, 2));
end;

procedure AddInputAlias(const Data: TSerifAviUtlInputAliasData;
  out FrameEnd: Integer);
var
  Index: Integer;
begin
  Index := GObjectIndex;
  Inc(GObjectIndex);
  FrameEnd := Data.FrameStart + Data.FrameLength;
  AddObjectHeader(GAliasBatch, Index, Data.Layer, Data.FrameStart,
    Data.FrameLength, Data.Group);
  // セリフ入力Scriptをオブジェクトの基底エフェクトとして生成する。
  AddFilterHeader(GAliasBatch, Index, 0, MMD_SERIF_EFFECT_NAME);
  GAliasBatch.Add(MMD_SERIF_CHARACTER_ITEM + '=' +
    EscapeAliasValue(Data.Character));
  GAliasBatch.Add(MMD_SERIF_EMOTION_ITEM + '=' +
    EscapeAliasValue(Data.Emotion));
  // select項目は数値ではなく表示名で直列化する。現段階の共通GUIは
  // 演出の選択値を保持しないため、Syncroh2と同じ「なし」を出力する。
  GAliasBatch.Add(MMD_SERIF_DIRECTION_ITEM + '=' + ALIAS_DIRECTION_NONE);
  GAliasBatch.Add(MMD_SERIF_TEXT_ITEM + '=' + EscapeAliasValue(Data.Serif));
  GAliasBatch.Add(MMD_SERIF_AIUEO_ITEM + '=');
  GAliasBatch.Add(MMD_SERIF_LAB_ITEM + '=' + EscapeAliasValue(Data.Lab));
  GAliasBatch.Add(MMD_SERIF_UID_ITEM + '=' + EscapeAliasValue(Data.UID));
  AddStandardDrawing(GAliasBatch, Index, 1);
end;

function BuildAliasBatch: string;
begin
  Result := GAliasBatch.Text;
end;

function SaveLinesToTempFile(const Lines: TStrings;
  const BaseName: string): string;
var
  Encoding: TEncoding;
begin
  Result := GetAppFolder('Temp') + BaseName;
  ForceDirectories(ExtractFilePath(Result));
  Encoding := TUTF8Encoding.Create(False);
  try
    Lines.SaveToFile(Result, Encoding);
  finally
    Encoding.Free;
  end;
end;

function SaveAliasBatch: string;
begin
  Result := SaveLinesToTempFile(GAliasBatch, 'MmdSerif.object');
end;

function CreateBoardAlias(
  const Data: TSerifAviUtlBoardAliasData): string;
var
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  try
    AddObjectHeader(Lines, 0, Data.Layer, Data.FrameStart,
      Data.FrameLength, 0);
    AddFilterHeader(Lines, 0, 0, ALIAS_IMAGE_FILE);
    Lines.Add(ALIAS_FILE + '=' + EscapeAliasValue(Data.FileName));
    Lines.Add(ALIAS_DISPLAY_NUMBER + '=0');
    Lines.Add(ALIAS_SEQUENCE_FILE + '=0');
    AddStandardDrawing(Lines, 0, 1);
    // MMD版はSyncroh2_Moduleを使わないため、連動指定は専用フィルター実装まで
    // 静止画として扱う。
    Result := SaveLinesToTempFile(Lines, 'MmdSerifBoard.object');
  finally
    Lines.Free;
  end;
end;

function CreateOutputAlias(const Layer, FrameLength: Integer): string;
begin
  // MMD側のセリフ表示は現段階では提供しない。
  Result := '';
end;

function BuildDrawAlias: string;
begin
  // 共通画面の呼出し契約だけ満たし、存在しない表示フィルターを生成しない。
  Result := '';
end;

procedure RegisterMmdSerifAviUtlAliasProvider;
var
  Provider: TSerifAviUtlAliasProvider;
begin
  Provider := Default(TSerifAviUtlAliasProvider);
  Provider.ProductID := MMD_SERIF_PRODUCT_ID;
  Provider.BeginAliasBatch := BeginAliasBatch;
  Provider.AddAudioAlias := AddAudioAlias;
  Provider.AddInputAlias := AddInputAlias;
  Provider.BuildAliasBatch := BuildAliasBatch;
  Provider.SaveAliasBatch := SaveAliasBatch;
  Provider.CreateBoardAlias := CreateBoardAlias;
  Provider.CreateOutputAlias := CreateOutputAlias;
  Provider.BuildDrawAlias := BuildDrawAlias;
  RegisterSerifAviUtlAliasProvider(Provider);
end;

initialization
  GAliasBatch := TStringList.Create;
  GFormatSettings := TFormatSettings.Create;
  GFormatSettings.DecimalSeparator := '.';

finalization
  GAliasBatch.Free;

end.
