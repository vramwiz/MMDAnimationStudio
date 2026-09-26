unit MmdProControllerOutput;

// Switch Pro Controller のHID出力レポートを構築して送信する。

interface

uses
  System.SysUtils;

// 指定長の無振動HID出力報告を返す。不正な長さでは空配列を返す。
function BuildProSubcommandReport(OutputLength: Word;
  PacketNumber, Command, Argument: Byte): TBytes;
// 指定デバイスへサブコマンドを送信し、成功時にPacketNumberを進める。
function SendProSubcommand(const Path: string; OutputLength: Word;
  var PacketNumber: Byte; Command, Argument: Byte): Boolean;
// Debug版でデバイス制御の診断情報を記録する。ログ失敗は通知しない。
procedure TraceProOutput(const EventName, Details: string);

implementation

uses
  Winapi.Windows
  {$IFDEF DEBUG}, System.IOUtils{$ENDIF};

function BuildProSubcommandReport(OutputLength: Word;
  PacketNumber, Command, Argument: Byte): TBytes;
begin
  Result := nil;
  if (OutputLength < 12) or (OutputLength > 4096) then Exit;
  SetLength(Result, OutputLength);
  FillChar(Result[0], OutputLength, 0);
  Result[0] := $01;
  Result[1] := PacketNumber and $0F;
  // 左右とも無振動のペイロード。
  Result[3] := $01; Result[4] := $40; Result[5] := $40;
  Result[7] := $01; Result[8] := $40; Result[9] := $40;
  Result[10] := Command;
  Result[11] := Argument;
end;

procedure TraceProOutput(const EventName, Details: string);
{$IFDEF DEBUG}
var
  Folder, FileName: string;
begin
  try
    Folder := TPath.Combine(TPath.GetDocumentsPath,
      'MMDAnimationStudio\Logs');
    ForceDirectories(Folder);
    FileName := TPath.Combine(Folder, 'ProControllerInput.log');
    if TFile.Exists(FileName) and (TFile.GetSize(FileName) > 1024 * 1024) then
      Exit;
    TFile.AppendAllText(FileName,
      FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) + ' ' + EventName +
      ' ' + Details + sLineBreak, TEncoding.UTF8);
  except
    // ログ書込み失敗はコントローラー入力に影響させない。
  end;
end;
{$ELSE}
begin
end;
{$ENDIF}

function SendProSubcommand(const Path: string; OutputLength: Word;
  var PacketNumber: Byte; Command, Argument: Byte): Boolean;
var
  WriteHandle: THandle;
  Output: TBytes;
  Written: Cardinal;
  ErrorCode: Cardinal;
begin
  Result := False;
  if Path = '' then Exit;
  Output := BuildProSubcommandReport(OutputLength,
    PacketNumber, Command, Argument);
  if Length(Output) = 0 then Exit;
  PacketNumber := (PacketNumber + 1) and $0F;
  WriteHandle := CreateFileW(PWideChar(Path), GENERIC_WRITE,
    FILE_SHARE_READ or FILE_SHARE_WRITE, nil, OPEN_EXISTING, 0, 0);
  if WriteHandle = INVALID_HANDLE_VALUE then
  begin
    TraceProOutput('open_write_failed',
      'command=' + IntToHex(Command, 2) +
      ' winerr=' + IntToStr(GetLastError));
    Exit;
  end;
  try
    Written := 0;
    Result := WriteFile(WriteHandle, Output[0], OutputLength,
      Written, nil) and (Written = OutputLength);
    if Result then ErrorCode := 0 else ErrorCode := GetLastError;
    TraceProOutput('subcommand',
      'command=' + IntToHex(Command, 2) +
      ' argument=' + IntToHex(Argument, 2) +
      ' success=' + BoolToStr(Result, True) +
      ' written=' + IntToStr(Written) +
      ' winerr=' + IntToStr(ErrorCode));
  finally
    CloseHandle(WriteHandle);
  end;
end;

end.
