unit MmdAiPreviewPipeServer;

// CodexからUTF-8改行区切りJSONを受ける、再接続可能なNamed Pipeサーバー。

interface

uses
  Winapi.Windows,
  System.Classes,
  System.SysUtils;

type
  TMmdAiPreviewPipeServer = class(TThread)
  private
    FLastError: string;
    FPipeHandle: THandle;
    procedure ClosePipe;
    function ConnectClient: Boolean;
    function CreatePipe: Boolean;
    function ProcessLine(const LineBytes: TBytes): Boolean;
    procedure ServeClient;
    function WriteResponse(const ResponseText: string): Boolean;
  protected
    procedure Execute; override;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Stop;
    property LastError: string read FLastError;
  end;

implementation

uses
  MmdAiPreviewPipeProtocol;

const
  PIPE_BUFFER_SIZE = 64 * 1024;
  PIPE_REJECT_REMOTE_CLIENTS_FLAG = $00000008;

constructor TMmdAiPreviewPipeServer.Create;
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FPipeHandle := INVALID_HANDLE_VALUE;
end;

destructor TMmdAiPreviewPipeServer.Destroy;
begin
  Stop;
  inherited Destroy;
end;

procedure TMmdAiPreviewPipeServer.ClosePipe;
begin
  if FPipeHandle = INVALID_HANDLE_VALUE then
    Exit;
  DisconnectNamedPipe(FPipeHandle);
  CloseHandle(FPipeHandle);
  FPipeHandle := INVALID_HANDLE_VALUE;
end;

function TMmdAiPreviewPipeServer.CreatePipe: Boolean;
begin
  ClosePipe;
  FPipeHandle := CreateNamedPipe(PChar(MMD_AI_PREVIEW_PIPE_NAME),
    PIPE_ACCESS_DUPLEX, PIPE_TYPE_BYTE or PIPE_READMODE_BYTE or PIPE_WAIT or
    PIPE_REJECT_REMOTE_CLIENTS_FLAG, 1, PIPE_BUFFER_SIZE, PIPE_BUFFER_SIZE,
    0, nil);
  Result := FPipeHandle <> INVALID_HANDLE_VALUE;
  if not Result then
    FLastError := SysErrorMessage(GetLastError);
end;

function TMmdAiPreviewPipeServer.ConnectClient: Boolean;
var
  ErrorCode: DWORD;
begin
  Result := ConnectNamedPipe(FPipeHandle, nil);
  if Result then
    Exit;
  ErrorCode := GetLastError;
  Result := ErrorCode = ERROR_PIPE_CONNECTED;
  if not Result and not Terminated and (ErrorCode <> ERROR_OPERATION_ABORTED) then
    FLastError := SysErrorMessage(ErrorCode);
end;

function TMmdAiPreviewPipeServer.WriteResponse(
  const ResponseText: string): Boolean;
var
  Bytes: TBytes;
  BytesWritten, Offset, Remaining: DWORD;
begin
  Bytes := TEncoding.UTF8.GetBytes(ResponseText + #10);
  Offset := 0;
  while Offset < DWORD(Length(Bytes)) do
  begin
    Remaining := DWORD(Length(Bytes)) - Offset;
    BytesWritten := 0;
    Result := WriteFile(FPipeHandle, Bytes[Offset], Remaining, BytesWritten,
      nil);
    if not Result or (BytesWritten = 0) then
      Exit(False);
    Inc(Offset, BytesWritten);
  end;
  Result := True;
end;

function TMmdAiPreviewPipeServer.ProcessLine(
  const LineBytes: TBytes): Boolean;
var
  Encoding: TUTF8Encoding;
  RequestText, ResponseText: string;
begin
  Result := True;
  if Length(LineBytes) = 0 then
    Exit;
  Encoding := TUTF8Encoding.Create(False);
  try
    try
      RequestText := Encoding.GetString(LineBytes);
      ResponseText := DispatchMmdAiPreviewPipeRequest(RequestText);
    except
      on E: Exception do
        ResponseText := BuildMmdAiPreviewPipeError('pipe_request_failed',
          E.Message);
    end;
  finally
    Encoding.Free;
  end;
  Result := WriteResponse(ResponseText);
end;

procedure TMmdAiPreviewPipeServer.ServeClient;
var
  Buffer: array[0..PIPE_BUFFER_SIZE - 1] of Byte;
  BytesRead: DWORD;
  Index, SegmentLength, SegmentStart: Integer;
  Line: TMemoryStream;
  LineBytes: TBytes;
  Oversized: Boolean;
begin
  Line := TMemoryStream.Create;
  try
    Oversized := False;
    while not Terminated do
    begin
      BytesRead := 0;
      if not ReadFile(FPipeHandle, Buffer[0], SizeOf(Buffer), BytesRead, nil) or
         (BytesRead = 0) then
        Exit;
      SegmentStart := 0;
      for Index := 0 to Integer(BytesRead) - 1 do
      begin
        if Buffer[Index] <> 10 then
          Continue;
        SegmentLength := Index - SegmentStart;
        if Oversized or (Line.Size + SegmentLength >
           MMD_AI_PREVIEW_PIPE_MAX_REQUEST_BYTES) then
        begin
          if not WriteResponse(BuildMmdAiPreviewPipeError('request_too_large',
            'A pipe request must not exceed 4194304 UTF-8 bytes.')) then
            Exit;
          Line.Clear;
          Oversized := False;
          SegmentStart := Index + 1;
          Continue;
        end;
        if SegmentLength > 0 then
          Line.WriteBuffer(Buffer[SegmentStart], SegmentLength);
        if (Line.Size > 0) and
           (PByte(NativeUInt(Line.Memory) + NativeUInt(Line.Size - 1))^ = 13) then
          Line.Size := Line.Size - 1;
        SetLength(LineBytes, NativeInt(Line.Size));
        if Line.Size > 0 then
          Move(Line.Memory^, LineBytes[0], Line.Size);
        if not ProcessLine(LineBytes) then
          Exit;
        Line.Clear;
        SegmentStart := Index + 1;
      end;
      if SegmentStart < Integer(BytesRead) then
      begin
        SegmentLength := Integer(BytesRead) - SegmentStart;
        if not Oversized and (Line.Size + SegmentLength >
           MMD_AI_PREVIEW_PIPE_MAX_REQUEST_BYTES) then
        begin
          Line.Clear;
          Oversized := True;
        end;
        if not Oversized then
          Line.WriteBuffer(Buffer[SegmentStart], SegmentLength);
      end;
    end;
  finally
    Line.Free;
  end;
end;

procedure TMmdAiPreviewPipeServer.Execute;
begin
  while not Terminated do
  begin
    try
      if not CreatePipe then
      begin
        Sleep(100);
        Continue;
      end;
      try
        if ConnectClient and not Terminated then
          ServeClient;
      finally
        ClosePipe;
      end;
    except
      on E: Exception do
      begin
        FLastError := E.ClassName + ': ' + E.Message;
        ClosePipe;
        if not Terminated then
          Sleep(100);
      end;
    end;
  end;
end;

procedure TMmdAiPreviewPipeServer.Stop;
var
  ClientHandle: THandle;
begin
  if Finished then
    Exit;
  Terminate;
  if Handle <> 0 then
    CancelSynchronousIo(Handle);
  ClientHandle := CreateFile(PChar(MMD_AI_PREVIEW_PIPE_NAME),
    GENERIC_READ or GENERIC_WRITE, 0, nil, OPEN_EXISTING, 0, 0);
  if ClientHandle <> INVALID_HANDLE_VALUE then
    CloseHandle(ClientHandle);
  WaitFor;
end;

end.
