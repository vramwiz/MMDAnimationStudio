unit MmdAiPreviewHost;

// CodexとMMD共通AIプロバイダーを、AviUtl2に依存しない標準入出力JSON境界で接続する。

interface

// コマンドラインを解釈し、単発要求または改行区切りJSONセッションを実行する。
procedure RunMmdAiPreviewHost;

implementation

uses
  System.Classes,
  System.IOUtils,
  System.JSON,
  System.SysUtils,
  Winapi.Windows,
  MmdAiPoseRepository,
  MmdAiPreviewPipeProtocol,
  MmdAiPreviewPipeServer,
  MmdAiPreviewProtocol;

const
  CAPABILITIES_REQUEST = '{"operation":"get_capabilities"}';

var
  PipeStopEvent: THandle;

function PipeConsoleHandler(ControlType: DWORD): BOOL; stdcall;
begin
  Result := ControlType in [CTRL_C_EVENT, CTRL_BREAK_EVENT, CTRL_CLOSE_EVENT,
    CTRL_LOGOFF_EVENT, CTRL_SHUTDOWN_EVENT];
  if Result and (PipeStopEvent <> 0) then
    SetEvent(PipeStopEvent);
end;

function HostErrorJson(const MessageText: string): string;
var
  Root: TJSONObject;
begin
  Root := TJSONObject.Create;
  try
    Root.AddPair('status', 'error');
    Root.AddPair('code', 'preview_host_error');
    Root.AddPair('message', MessageText);
    Result := Root.ToJSON;
  finally
    Root.Free;
  end;
end;

procedure WriteUtf8Line(const Text: string);
var
  Encoding: TUTF8Encoding;
  OutputStream: THandleStream;
  Writer: TStreamWriter;
begin
  OutputStream := THandleStream.Create(GetStdHandle(STD_OUTPUT_HANDLE));
  Encoding := TUTF8Encoding.Create(False);
  Writer := TStreamWriter.Create(OutputStream, Encoding, 65536);
  try
    Writer.WriteLine(Text);
    Writer.Flush;
  finally
    Writer.Free;
    OutputStream.Free;
    Encoding.Free;
  end;
end;

procedure RunStandardIo;
var
  Encoding: TUTF8Encoding;
  InputStream, OutputStream: THandleStream;
  Reader: TStreamReader;
  RequestText, ResponseText: string;
  Writer: TStreamWriter;
begin
  InputStream := THandleStream.Create(GetStdHandle(STD_INPUT_HANDLE));
  OutputStream := THandleStream.Create(GetStdHandle(STD_OUTPUT_HANDLE));
  Encoding := TUTF8Encoding.Create(False);
  Reader := TStreamReader.Create(InputStream, Encoding, True, 65536);
  Writer := TStreamWriter.Create(OutputStream, Encoding, 65536);
  try
    Writer.AutoFlush := True;
    while not Reader.EndOfStream do
    begin
      RequestText := Reader.ReadLine;
      if Trim(RequestText) = '' then
        Continue;
      try
        ResponseText := DispatchMmdAiPreviewRequest(RequestText);
      except
        on E: Exception do
          ResponseText := HostErrorJson(E.Message);
      end;
      Writer.WriteLine(ResponseText);
    end;
  finally
    Writer.Free;
    Reader.Free;
    OutputStream.Free;
    InputStream.Free;
    Encoding.Free;
  end;
end;

procedure RunPipeServer;
var
  Server: TMmdAiPreviewPipeServer;
begin
  PipeStopEvent := CreateEvent(nil, True, False, nil);
  if PipeStopEvent = 0 then
    RaiseLastOSError;
  Server := TMmdAiPreviewPipeServer.Create;
  try
    SetConsoleCtrlHandler(@PipeConsoleHandler, True);
    Server.Start;
    Writeln(ErrOutput, 'MMDAIPreview listening on ',
      MMD_AI_PREVIEW_PIPE_NAME, ' (Ctrl+C to stop).');
    WaitForSingleObject(PipeStopEvent, INFINITE);
    Server.Stop;
  finally
    SetConsoleCtrlHandler(@PipeConsoleHandler, False);
    Server.Free;
    CloseHandle(PipeStopEvent);
    PipeStopEvent := 0;
  end;
end;

procedure PrintUsage;
begin
  Writeln('MMDAIPreview - direct Codex/MMD experiment host');
  Writeln('  --self-test              Query MMD provider capabilities.');
  Writeln('  --convert-legacy-poses   Convert legacy JSON poses to VPD.');
  Writeln('  --request <json>         Process one JSON request.');
  Writeln('  --request-file <path>    Process one UTF-8 JSON file.');
  Writeln('  --stdio                  Process one JSON object per input line.');
  Writeln('  --pipe                   Listen on MMD.AI.Preview.v1.');
end;

procedure RunMmdAiPreviewHost;
var
  Converted: Integer;
  ResultRoot: TJSONObject;
  RequestText: string;
begin
  if ParamCount = 0 then
  begin
    PrintUsage;
    Exit;
  end;
  if SameText(ParamStr(1), '--self-test') then
    RequestText := CAPABILITIES_REQUEST
  else if SameText(ParamStr(1), '--convert-legacy-poses') then
  begin
    if ParamCount <> 1 then
      raise EArgumentException.Create(
        '--convert-legacy-poses does not accept arguments.');
    Converted := ConvertLegacyMmdAiPoseFiles;
    ResultRoot := TJSONObject.Create;
    try
      ResultRoot.AddPair('status', 'ok');
      ResultRoot.AddPair('converted', TJSONNumber.Create(Converted));
      ResultRoot.AddPair('directory', GetMmdAiPoseDirectory);
      WriteUtf8Line(ResultRoot.ToJSON);
    finally
      ResultRoot.Free;
    end;
    Exit;
  end
  else if SameText(ParamStr(1), '--request') then
  begin
    if ParamCount <> 2 then
      raise EArgumentException.Create('--request requires exactly one JSON argument.');
    RequestText := ParamStr(2);
  end
  else if SameText(ParamStr(1), '--request-file') then
  begin
    if ParamCount <> 2 then
      raise EArgumentException.Create('--request-file requires exactly one path.');
    RequestText := TFile.ReadAllText(ParamStr(2), TEncoding.UTF8);
  end
  else if SameText(ParamStr(1), '--stdio') then
  begin
    RunStandardIo;
    Exit;
  end
  else if SameText(ParamStr(1), '--pipe') then
  begin
    RunPipeServer;
    Exit;
  end
  else
    raise EArgumentException.Create('Unknown command. Run without arguments for usage.');
  WriteUtf8Line(DispatchMmdAiPreviewRequest(RequestText));
end;

end.
