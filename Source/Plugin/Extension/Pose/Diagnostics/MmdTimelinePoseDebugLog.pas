unit MmdTimelinePoseDebugLog;

// Debug版だけでタイムライン姿勢同期の入出力を時系列で記録する。

interface

// Debug版の次の操作番号を返す。Release版では0を返す。
function NextPoseTraceId: Integer;
// Debug版で時系列ログを追記する。書込失敗でも編集を止めない。
procedure PoseDebugLog(const EventName, Details: string);
// 文字列の長さとJSON表現を記録する。長い本文は上限で切り詰める。
procedure PoseDebugText(const EventName, Value: string);
// 期待値と実値の最初の差分位置と各本文を記録する。
procedure PoseDebugTextPair(const EventName, Expected, Actual: string);

threadvar
  PoseTraceId: Integer;

implementation

{$IFDEF DEBUG}
uses
  Winapi.Windows,
  System.IOUtils,
  System.JSON,
  System.SysUtils;

var
  NextId: Integer;
  NextLine: Integer;

function Quoted(const Value: string): string;
var
  Json: TJSONString;
begin
  Json := TJSONString.Create(Copy(Value, 1, 16384));
  try
    Result := Json.ToJSON;
    if Length(Value) > 16384 then Result := Result + ' [truncated]';
  finally
    Json.Free;
  end;
end;

function NextPoseTraceId: Integer;
begin
  Result := InterlockedIncrement(NextId);
end;

procedure PoseDebugLog(const EventName, Details: string);
var
  Folder, FileName, Line: string;
begin
  try
    Folder := TPath.Combine(TPath.GetDocumentsPath,
      'MMDAnimationStudio\Logs');
    ForceDirectories(Folder);
    FileName := TPath.Combine(Folder, 'TimelinePoseDebug.log');
    if TFile.Exists(FileName) and (TFile.GetSize(FileName) > 8 * 1024 * 1024) then
      Exit;
    Line := FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) +
      ' seq=' + IntToStr(InterlockedIncrement(NextLine)) +
      ' op=' + IntToStr(PoseTraceId) +
      ' tid=' + IntToStr(GetCurrentThreadId) +
      ' ' + EventName + ' ' + Details + sLineBreak;
    TFile.AppendAllText(FileName, Line, TEncoding.UTF8);
  except
    // ログの失敗で編集処理を止めない。
  end;
end;

procedure PoseDebugText(const EventName, Value: string);
begin
  PoseDebugLog(EventName, 'chars=' + IntToStr(Length(Value)) +
    ' utf8bytes=' + IntToStr(Length(UTF8String(Value))) +
    ' json=' + Quoted(Value));
end;

procedure PoseDebugTextPair(const EventName, Expected, Actual: string);
var
  Index, Limit: Integer;
begin
  Limit := Length(Expected);
  if Length(Actual) < Limit then Limit := Length(Actual);
  Index := 1;
  while (Index <= Limit) and (Expected[Index] = Actual[Index]) do Inc(Index);
  PoseDebugLog(EventName, 'equal=' + BoolToStr(Expected = Actual, True) +
    ' first_diff=' + IntToStr(Index));
  PoseDebugText(EventName + '.expected', Expected);
  PoseDebugText(EventName + '.actual', Actual);
end;
{$ELSE}
function NextPoseTraceId: Integer;
begin
  Result := 0;
end;

procedure PoseDebugLog(const EventName, Details: string);
begin
end;

procedure PoseDebugText(const EventName, Value: string);
begin
end;

procedure PoseDebugTextPair(const EventName, Expected, Actual: string);
begin
end;
{$ENDIF}

end.
