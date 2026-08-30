unit MMD_Serif_ModulePlugin;

// MMDセリフ入力Scriptの12引数をShareTalkスナップショットへ発行する。

interface

uses
  MmdSerifModuleTypes;

// 12引数を検証して現在フレームのShareTalk、索引、履歴を発行する。異常入力では発行しない。
procedure MmdSerifSetText(Param: PMMD_SCRIPT_MODULE_PARAM); cdecl;
// DLL有効期間中に保持されるset_text関数表を返す。呼び出し側は解放しない。
function GetMmdSerifScriptModuleTable: PMMD_SCRIPT_MODULE_TABLE;

implementation

uses
  Winapi.Windows,
  System.Math,
  System.SysUtils,
  MmdSerifModuleAdapter,
  SerifTalkSharedCodec,
  SerifTalkSharedIndexPublisher,
  SerifTalkSharedMemory;

const
  PARAM_COUNT = 12;
  PARAM_FRAMERATE = 0;
  PARAM_FRAME = 1;
  PARAM_LAYER = 2;
  PARAM_SERIF = 3;
  PARAM_CHARACTER = 4;
  PARAM_EMOTION = 5;
  PARAM_DIRECTION = 6;
  PARAM_AIUEO = 7;
  PARAM_TOTALTIME = 8;
  PARAM_LAB = 9;
  PARAM_SOURCE_OBJECT = 10;
  PARAM_CURRENT_FRAME = 11;

var
  ModuleFunctions: array[0..1] of TMMD_SCRIPT_MODULE_FUNCTION = (
    (Name: 'set_text'; Func: MmdSerifSetText),
    (Name: nil; Func: nil)
  );
  ModuleTable: TMMD_SCRIPT_MODULE_TABLE = (
    Information: 'MMD Serif Module';
    Functions: @ModuleFunctions[0]
  );

function NewRuntimeUID: string;
var
  Value: TGUID;
begin
  Result := '';
  if CreateGUID(Value) = S_OK then
    Result := GUIDToString(Value);
end;

procedure MmdSerifSetText(Param: PMMD_SCRIPT_MODULE_PARAM); cdecl;
var
  Frame: TSerifTalkFrame;
  Layer: Integer;
  Text: string;
begin
  try
    if (Param = nil) or not Assigned(Param^.GetParamNum) or
      not Assigned(Param^.GetParamInt) or
      not Assigned(Param^.GetParamDouble) or
      (Param^.GetParamNum < PARAM_COUNT) then
      Exit;
    Layer := Param^.GetParamInt(PARAM_LAYER);
    if (Layer < 1) or (Layer >= SERIF_TALK_MAX_LINES) then
      Exit;
    Frame := Default(TSerifTalkFrame);
    Frame.UID := NewRuntimeUID;
    Frame.FrameRate := Param^.GetParamInt(PARAM_FRAMERATE);
    Frame.Frame := Param^.GetParamInt(PARAM_FRAME);
    Frame.CurrentFrame := Param^.GetParamInt(PARAM_CURRENT_FRAME);
    Frame.TotalTime := Param^.GetParamDouble(PARAM_TOTALTIME);
    Frame.TotalFrames := Max(1, Ceil(Frame.TotalTime * Frame.FrameRate));
    Frame.Serif := MmdModuleParamString(Param, PARAM_SERIF);
    Frame.Character := MmdModuleParamString(Param, PARAM_CHARACTER);
    Frame.Emotion := MmdModuleParamString(Param, PARAM_EMOTION);
    Frame.Direction := MmdModuleParamString(Param, PARAM_DIRECTION);
    Frame.Aiueo := MmdModuleParamString(Param, PARAM_AIUEO);
    Frame.Lab := MmdModuleParamString(Param, PARAM_LAB);
    if not TryStrToInt64(MmdModuleParamString(Param, PARAM_SOURCE_OBJECT),
      Frame.SourceObjectID) or (Frame.SourceObjectID = 0) then
      Exit;
    Text := EncodeSerifTalkFrame(Frame);
    if PublishSerifTalkText(Layer, Text) then
      PublishSerifTalkIndex(Frame.CurrentFrame, Layer, Frame.Character,
        Frame.Emotion, Frame.Direction, Frame.Serif);
  except
    // Delphi例外をAviUtl2 Script Module境界から漏らさない。
  end;
end;

function GetMmdSerifScriptModuleTable: PMMD_SCRIPT_MODULE_TABLE;
begin
  Result := @ModuleTable;
end;

end.
