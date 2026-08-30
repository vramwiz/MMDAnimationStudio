unit MMD_Model_LipSyncInput;

// Syncroh2互換共有メモリの指定レイヤーを読み、解析済み口パク入力を返す。

interface

uses
  AviUtl2FilterTypes,
  MMD_Model_LipSyncProtocol;

// セリフとソングの共有スロットを読み、参考元と同じくセリフを後段優先して返す。
// 共有文字列は消去・変更しない。共有領域が無い場合や不正値ではFalseを返す。
function ReadMmdLipSyncSample(SerifLayer, SongLayer: Integer;
  FallbackSpeedSec: Double; out Sample: TMmdLipSyncSample): Boolean;

// 参照レイヤーのセリフオブジェクトを現在位置で評価し、送信元の実在とフレーム一致を検証する。
// セリフが無効ならSongLayerへフォールバックし、どちらも無効ならSampleを初期化してFalseを返す。
function ReadReferencedMmdLipSyncSample(Video: PFILTER_PROC_VIDEO;
  SerifLayer, SongLayer: Integer; FallbackSpeedSec: Double;
  out Sample: TMmdLipSyncSample): Boolean;

implementation

uses
  System.SysUtils,
  KeyValueText,
  SerifTalkSharedMemory,
  SharedMemoryBase
{$IFDEF DEBUG}
  , MMD_Model_DebugLog,
  Winapi.Windows
{$ENDIF}
  ;

const
  SharedLineCount = 100;
  SharedLineLength = 4000;

var
  SongMemory: TSharedMemoryStringList;
{$IFDEF DEBUG}
  LipSyncInputLogCount: Integer;
{$ENDIF}

function ReadTalkSample(Layer: Integer; FallbackSpeedSec: Double;
  out Sample: TMmdLipSyncSample): Boolean;
var
  Text: string;
begin
  Result := (Layer > 0) and (Layer < SharedLineCount) and
    TryReadSerifTalkText(Layer, Text) and
    TryParseMmdLipSyncTalkText(Text, FallbackSpeedSec, Sample);
end;

function ReadSongSample(Layer: Integer;
  out Sample: TMmdLipSyncSample): Boolean;
begin
  Result := (Layer > 0) and (Layer < SharedLineCount) and
    (SongMemory <> nil) and SongMemory.IsOpened and
    TryParseMmdLipSyncSongText(SongMemory.Strings[Layer], Sample);
end;

function ReadMmdLipSyncSample(SerifLayer, SongLayer: Integer;
  FallbackSpeedSec: Double; out Sample: TMmdLipSyncSample): Boolean;
begin
  Result := ReadTalkSample(SerifLayer, FallbackSpeedSec, Sample);
  if not Result then
    Result := ReadSongSample(SongLayer, Sample);
  if not Result then
    Sample := Default(TMmdLipSyncSample);
end;

function ReadReferencedMmdLipSyncSample(Video: PFILTER_PROC_VIDEO;
  SerifLayer, SongLayer: Integer; FallbackSpeedSec: Double;
  out Sample: TMmdLipSyncSample): Boolean;
var
{$IFDEF DEBUG}
  ObjectID: Int64;
{$ENDIF}
  SharedCurrentFrame: Integer;
  SharedSourceObject: string;
  SerifObject: OBJECT_HANDLE;
  Text: string;
  TimelineFrame: Integer;
begin
  Result := False;
  Sample := Default(TMmdLipSyncSample);
  Text := '';
{$IFDEF DEBUG}
  ObjectID := -1;
{$ENDIF}
  SharedCurrentFrame := -1;
  SharedSourceObject := '';
  if (Video <> nil) and Assigned(Video^.GetImageObject) and
    (Video^.Object_ <> nil) and (SerifLayer > 0) and
    (SerifLayer < SharedLineCount) then
  begin
    TimelineFrame := Video^.Object_^.FrameS + Video^.Object_^.Frame;
    try
      // 画面表示の1始まりをSDKの0始まりに直し、送信元を先に評価する。
      SerifObject := Video^.GetImageObject(SerifLayer - 1, 0.0);
{$IFDEF DEBUG}
      if SerifObject <> nil then
        ObjectID := POBJECT_INFO(SerifObject)^.ID;
{$ENDIF}
      if TryReadSerifTalkText(SerifLayer, Text) then
      begin
        SharedCurrentFrame := GetKeyValueInt(Text, 'current_frame');
        SharedSourceObject := GetKeyValue(Text, 'source_object');
      end;
      Result := (SerifObject <> nil) and (Text <> '') and
        (SharedCurrentFrame = TimelineFrame) and
        (SharedSourceObject <> '') and
        TryParseMmdLipSyncTalkText(Text, FallbackSpeedSec, Sample);
{$IFDEF DEBUG}
      if InterlockedIncrement(LipSyncInputLogCount) <= 300 then
        MmdModelDebugLog(Format(
          'LipSync input: timeline=%d layer=%d object_id=%d shared_frame=%d shared_source=%s text_len=%d result=%d kind=%d phoneme=%d open=%.4f lab=%s speech=%s',
          [TimelineFrame, SerifLayer, ObjectID, SharedCurrentFrame,
           SharedSourceObject, Length(Text), Ord(Result), Ord(Sample.Kind),
           Ord(Sample.Phoneme), Sample.OpenAmount,
           GetKeyValue(Text, 'lab'), GetKeyValue(Text, 'speech_active')]));
{$ENDIF}
    except
      on E: Exception do
      begin
{$IFDEF DEBUG}
        if InterlockedIncrement(LipSyncInputLogCount) <= 300 then
          MmdModelDebugLog('LipSync input exception: ' + E.ClassName +
            ': ' + E.Message);
{$ENDIF}
      Result := False;
      Sample := Default(TMmdLipSyncSample);
      end;
    end;
  end;
  if not Result then
    Result := ReadSongSample(SongLayer, Sample);
  if not Result then
    Sample := Default(TMmdLipSyncSample);
end;

procedure OpenSharedMemories;
begin
  try
    SongMemory := TSharedMemoryStringList.Create('Local\GSharedSong',
      SharedLineCount, SharedLineLength);
  except
    SongMemory := nil;
  end;
end;

initialization
  OpenSharedMemories;

finalization
  SongMemory.Free;

end.
