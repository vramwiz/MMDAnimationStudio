unit MmdTimelinePoseSyncTrace;

// 選択オブジェクトの再接続と書き戻しを、姿勢本文の長さとハッシュで記録する。

interface

uses MmdTimelinePoseBinding;

// 編集開始・再接続・書き戻し前後の識別情報を診断ログへ追記する。
procedure TracePoseSync(const EventName: string;
  const Before, After: TMmdTimelinePoseSnapshot);

implementation

uses
  System.IOUtils,
  System.SysUtils;

function PoseTextHash(const Value: string): Cardinal;
var
  Character: Char;
begin
  Result := $811C9DC5;
  for Character in Value do
    Result := (Result xor Ord(Character)) * $01000193;
end;

procedure TracePoseSync(const EventName: string;
  const Before, After: TMmdTimelinePoseSnapshot);
var
  Folder, FileName, Line: string;
begin
  try
    Folder := TPath.Combine(TPath.GetDocumentsPath,
      'MMDAnimationStudio\Logs');
    ForceDirectories(Folder);
    FileName := TPath.Combine(Folder, 'TimelinePoseSync.log');
    Line := FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) + ' ' +
      EventName + ' obj=' + IntToHex(Before.ObjectId, 16) + '>' +
      IntToHex(After.ObjectId, 16) + ' model=' +
      IntToHex(Before.BaseModelObjectId, 16) + '>' +
      IntToHex(After.BaseModelObjectId, 16) + ' layer=' +
      IntToStr(Before.Layer) + '>' + IntToStr(After.Layer) +
      ' frame=' + IntToStr(Before.StartFrame) + '>' +
      IntToStr(After.StartFrame) + ' pose=' +
      IntToStr(Length(Before.PoseData)) + ':' +
      IntToHex(PoseTextHash(Before.PoseData), 8) + '>' +
      IntToStr(Length(After.PoseData)) + ':' +
      IntToHex(PoseTextHash(After.PoseData), 8) +
      ' base=' + IntToStr(Length(Before.StandardPoseData)) + '>' +
      IntToStr(Length(After.StandardPoseData)) +
      ' motion=' + IntToStr(Before.MotionFrame) + '>' +
      IntToStr(After.MotionFrame) + sLineBreak;
    TFile.AppendAllText(FileName, Line, TEncoding.UTF8);
  except
    // 診断ファイルを作れなくても編集中の姿勢操作は続ける。
  end;
end;

end.
