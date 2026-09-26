unit MmdAiPreviewPipeClient;

// Codexの単発CLI要求を、起動中MMDAnimationStudioのNamed Pipeへ転送する。

interface

// UTF-8 JSONを1件送信し、改行区切りの応答JSONを返す。
function InvokeMmdAiPreviewPipe(const RequestText: string): string;

implementation

uses
  Winapi.Windows,
  System.Classes,
  System.SysUtils,
  MmdAiPreviewPipeProtocol;

function OpenPipe: THandle;
var
  ErrorCode: DWORD;
begin
  Result := CreateFile(PChar(MMD_AI_PREVIEW_PIPE_NAME),
    GENERIC_READ or GENERIC_WRITE, 0, nil, OPEN_EXISTING, 0, 0);
  if Result <> INVALID_HANDLE_VALUE then
    Exit;
  ErrorCode := GetLastError;
  if (ErrorCode = ERROR_PIPE_BUSY) and
    WaitNamedPipe(PChar(MMD_AI_PREVIEW_PIPE_NAME), 10000) then
    Result := CreateFile(PChar(MMD_AI_PREVIEW_PIPE_NAME),
      GENERIC_READ or GENERIC_WRITE, 0, nil, OPEN_EXISTING, 0, 0);
  if Result = INVALID_HANDLE_VALUE then
    raise EInOutError.CreateFmt(
      'MMDAnimationStudio pipe is unavailable: %s',
      [SysErrorMessage(GetLastError)]);
end;

procedure WriteRequest(Pipe: THandle; const RequestText: string);
var
  Bytes: TBytes;
  Offset: Integer;
  Written: DWORD;
begin
  Bytes := TEncoding.UTF8.GetBytes(RequestText + #10);
  Offset := 0;
  while Offset < Length(Bytes) do
  begin
    Written := 0;
    if not WriteFile(Pipe, Bytes[Offset], Length(Bytes) - Offset,
      Written, nil) or (Written = 0) then
      RaiseLastOSError;
    Inc(Offset, Written);
  end;
end;

function ReadResponse(Pipe: THandle): string;
var
  Buffer: array[0..4095] of Byte;
  Bytes: TBytes;
  BytesRead: DWORD;
  I, OldLength: Integer;
begin
  SetLength(Bytes, 0);
  while Length(Bytes) <= MMD_AI_PREVIEW_PIPE_MAX_REQUEST_BYTES do
  begin
    BytesRead := 0;
    if not ReadFile(Pipe, Buffer[0], SizeOf(Buffer), BytesRead, nil) or
      (BytesRead = 0) then
      RaiseLastOSError;
    OldLength := Length(Bytes);
    SetLength(Bytes, OldLength + Integer(BytesRead));
    Move(Buffer[0], Bytes[OldLength], BytesRead);
    for I := OldLength to High(Bytes) do
      if Bytes[I] = 10 then
      begin
        SetLength(Bytes, I);
        if (Length(Bytes) > 0) and (Bytes[High(Bytes)] = 13) then
          SetLength(Bytes, Length(Bytes) - 1);
        Exit(TEncoding.UTF8.GetString(Bytes));
      end;
  end;
  raise EInOutError.Create('MMDAnimationStudio pipe response is too large.');
end;

function InvokeMmdAiPreviewPipe(const RequestText: string): string;
var
  Pipe: THandle;
begin
  if Length(TEncoding.UTF8.GetBytes(RequestText)) >
    MMD_AI_PREVIEW_PIPE_MAX_REQUEST_BYTES then
    raise EArgumentException.Create('Pipe request is too large.');
  Pipe := OpenPipe;
  try
    WriteRequest(Pipe, RequestText);
    Result := ReadResponse(Pipe);
  finally
    CloseHandle(Pipe);
  end;
end;

end.
