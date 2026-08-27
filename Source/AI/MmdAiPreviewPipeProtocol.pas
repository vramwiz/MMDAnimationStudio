unit MmdAiPreviewPipeProtocol;

// Named Pipe固有の要求識別子を扱い、既存JSONディスパッチへ委譲する。

interface

const
  MMD_AI_PREVIEW_PIPE_SHORT_NAME = 'MMD.AI.Preview.v1';
  MMD_AI_PREVIEW_PIPE_NAME = '\\.\pipe\MMD.AI.Preview.v1';
  MMD_AI_PREVIEW_PIPE_MAX_REQUEST_BYTES = 4 * 1024 * 1024;

// 任意のrequest_idを成功・エラー応答へ引き継ぐ。
function DispatchMmdAiPreviewPipeRequest(const RequestText: string): string;
function BuildMmdAiPreviewPipeError(const Code, MessageText: string): string;

implementation

uses
  System.JSON,
  MmdAiPreviewProtocol;

function BuildMmdAiPreviewPipeError(const Code, MessageText: string): string;
var
  Root: TJSONObject;
begin
  Root := TJSONObject.Create;
  try
    Root.AddPair('status', 'error');
    Root.AddPair('code', Code);
    Root.AddPair('message', MessageText);
    Result := Root.ToJSON;
  finally
    Root.Free;
  end;
end;

function CloneJson(const Value: TJSONValue): TJSONValue;
begin
  if Value = nil then
    Exit(nil);
  Result := TJSONObject.ParseJSONValue(Value.ToJSON);
end;

function DispatchMmdAiPreviewPipeRequest(const RequestText: string): string;
var
  RequestId, RequestValue, ResponseValue: TJSONValue;
  ResponseRoot: TJSONObject;
begin
  RequestId := nil;
  RequestValue := TJSONObject.ParseJSONValue(RequestText);
  try
    if RequestValue is TJSONObject then
      RequestId := TJSONObject(RequestValue).GetValue('request_id');
    Result := DispatchMmdAiPreviewRequest(RequestText);
    if RequestId = nil then
      Exit;
    ResponseValue := TJSONObject.ParseJSONValue(Result);
    try
      if not (ResponseValue is TJSONObject) then
        Exit;
      ResponseRoot := TJSONObject(ResponseValue);
      if ResponseRoot.GetValue('request_id') = nil then
        ResponseRoot.AddPair('request_id', CloneJson(RequestId));
      Result := ResponseRoot.ToJSON;
    finally
      ResponseValue.Free;
    end;
  finally
    RequestValue.Free;
  end;
end;

end.
