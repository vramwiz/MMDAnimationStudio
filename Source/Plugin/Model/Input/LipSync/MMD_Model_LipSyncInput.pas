unit MMD_Model_LipSyncInput;

// Syncroh2互換共有メモリの指定レイヤーを読み、解析済み口パク入力を返す。

interface

uses
  MMD_Model_LipSyncProtocol;

// セリフとソングの共有スロットを読み、参考元と同じくセリフを後段優先して返す。
// 共有文字列は消去・変更しない。共有領域が無い場合や不正値ではFalseを返す。
function ReadMmdLipSyncSample(SerifLayer, SongLayer: Integer;
  FallbackSpeedSec: Double; out Sample: TMmdLipSyncSample): Boolean;

implementation

uses
  SharedMemoryBase;

const
  SharedLineCount = 100;
  SharedLineLength = 4000;

var
  TalkMemory: TSharedMemoryStringList;
  SongMemory: TSharedMemoryStringList;

function ReadTalkSample(Layer: Integer; FallbackSpeedSec: Double;
  out Sample: TMmdLipSyncSample): Boolean;
begin
  Result := (Layer > 0) and (Layer < SharedLineCount) and
    (TalkMemory <> nil) and TalkMemory.IsOpened and
    TryParseMmdLipSyncTalkText(TalkMemory.Strings[Layer],
      FallbackSpeedSec, Sample);
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

procedure OpenSharedMemories;
begin
  try
    TalkMemory := TSharedMemoryStringList.Create('Local\ShareTalk',
      SharedLineCount, SharedLineLength);
  except
    TalkMemory := nil;
  end;
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
  TalkMemory.Free;

end.
