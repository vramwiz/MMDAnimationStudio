unit MMD_Model_DebugLog;

// Debugビルドのモデル表示診断をDLL配置先へ追記し、ログ失敗を描画処理から隔離する。

interface

// 呼出スレッドと時刻を付けて1行追記する。Releaseでは副作用のない空処理になる。
procedure MmdModelDebugLog(const Text: string);

implementation

{$IFDEF DEBUG}
uses
  System.Classes,
  System.IOUtils,
  System.SysUtils,
  Winapi.Windows;

var
  LogLock: TObject;
  LogPath: string;

function ModuleDirectory: string;
var
  Buffer: array[0..MAX_PATH - 1] of Char;
  Count: DWORD;
begin
  Count := GetModuleFileName(HInstance, Buffer, Length(Buffer));
  if Count = 0 then
    Exit('');
  SetString(Result, Buffer, Count);
  Result := ExtractFilePath(Result);
end;

procedure MmdModelDebugLog(const Text: string);
var
  Line: string;
begin
  if LogPath = '' then
    Exit;
  Line := FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) +
    Format(' [thread %d] ', [GetCurrentThreadId]) + Text + sLineBreak;
  TMonitor.Enter(LogLock);
  try
    try
      TFile.AppendAllText(LogPath, Line, TEncoding.UTF8);
    except
      // 診断ログ失敗を描画コールバックへ伝播させない。
    end;
  finally
    TMonitor.Exit(LogLock);
  end;
end;

initialization
  LogLock := TObject.Create;
  LogPath := ModuleDirectory + 'MMD_Model_debug.log';
  try
    if LogPath <> '' then
      TFile.WriteAllText(LogPath, 'MMD Model debug log started.' +
        sLineBreak, TEncoding.UTF8);
  except
    LogPath := '';
  end;

finalization
  LogLock.Free;

{$ELSE}

procedure MmdModelDebugLog(const Text: string);
begin
end;

{$ENDIF}

end.
