unit MmdAiPreviewMcpHost;

// CodexのSTDIO MCP要求を、起動中MMDAnimationStudioのNamed Pipe操作へ変換する。

interface

// 改行区切りJSON-RPC 2.0を標準入出力で処理し、EOFまで待機する。
procedure RunMmdAiPreviewMcp;

implementation

uses
  Winapi.Windows,
  System.Classes,
  System.Generics.Collections,
  System.JSON,
  System.SysUtils,
  MmdAiPreviewPipeClient;

const
  MCP_PROTOCOL_VERSION = '2025-06-18';
  MCP_SERVER_NAME = 'mmd-animation-studio';
  MCP_SERVER_VERSION = '1.0.0';

function CloneJson(const Value: TJSONValue): TJSONValue;
begin
  if Value = nil then
    Exit(nil);
  Result := TJSONObject.ParseJSONValue(Value.ToJSON);
end;

function JsonString(const Root: TJSONObject; const Name: string): string;
var
  Value: TJSONValue;
begin
  Result := '';
  Value := Root.GetValue(Name);
  if Value is TJSONString then
    Result := TJSONString(Value).Value;
end;

function RpcEnvelope(const Id, Payload: TJSONValue;
  const PayloadName: string): string;
var
  Root: TJSONObject;
begin
  Root := TJSONObject.Create;
  try
    Root.AddPair('jsonrpc', '2.0');
    if Assigned(Id) then
      Root.AddPair('id', CloneJson(Id))
    else
      Root.AddPair('id', TJSONNull.Create);
    Root.AddPair(PayloadName, Payload);
    Result := Root.ToJSON;
  finally
    Root.Free;
  end;
end;

function RpcError(const Id: TJSONValue; Code: Integer;
  const MessageText: string): string;
var
  ErrorObject: TJSONObject;
begin
  ErrorObject := TJSONObject.Create;
  ErrorObject.AddPair('code', TJSONNumber.Create(Code));
  ErrorObject.AddPair('message', MessageText);
  Result := RpcEnvelope(Id, ErrorObject, 'error');
end;

function EmptyResult(const Id: TJSONValue): string;
begin
  Result := RpcEnvelope(Id, TJSONObject.Create, 'result');
end;

function InitializeResult(const Id: TJSONValue): string;
var
  Capabilities, ResultObject, ServerInfo, Tools: TJSONObject;
begin
  ResultObject := TJSONObject.Create;
  ResultObject.AddPair('protocolVersion', MCP_PROTOCOL_VERSION);
  Capabilities := TJSONObject.Create;
  Tools := TJSONObject.Create;
  Tools.AddPair('listChanged', TJSONBool.Create(False));
  Capabilities.AddPair('tools', Tools);
  ResultObject.AddPair('capabilities', Capabilities);
  ServerInfo := TJSONObject.Create;
  ServerInfo.AddPair('name', MCP_SERVER_NAME);
  ServerInfo.AddPair('version', MCP_SERVER_VERSION);
  ResultObject.AddPair('serverInfo', ServerInfo);
  ResultObject.AddPair('instructions',
    'MMDAnimationStudio用ポーズツール。まずget_pose_catalog_contextで' +
    '選択PMXを取得する。バックグラウンド作成はget_model_schema、' +
    'preview_pose、create_pose_fileの順に使う。設定画面が開いている' +
    '場合はget_active_pose_contextのsession_idとrevisionを取得し、' +
    'preview_pose_in_sessionへ渡す。古いrevisionを再利用しない。' +
    'create_pose_fileはカタログを書き換える。');
  Result := RpcEnvelope(Id, ResultObject, 'result');
end;

function ParseSchema(const Text: string): TJSONObject;
var
  Value: TJSONValue;
begin
  Value := TJSONObject.ParseJSONValue(Text);
  if not (Value is TJSONObject) then
  begin
    Value.Free;
    raise EInvalidOperation.Create('Invalid internal MCP schema.');
  end;
  Result := TJSONObject(Value);
end;

procedure AddTool(Tools: TJSONArray; const Name, Description,
  Schema: string; ReadOnly: Boolean);
var
  Annotations: TJSONObject;
  Tool: TJSONObject;
begin
  Tool := TJSONObject.Create;
  Tool.AddPair('name', Name);
  Tool.AddPair('description', Description);
  Tool.AddPair('inputSchema', ParseSchema(Schema));
  Annotations := TJSONObject.Create;
  Annotations.AddPair('readOnlyHint', TJSONBool.Create(ReadOnly));
  Annotations.AddPair('destructiveHint', TJSONBool.Create(False));
  Annotations.AddPair('idempotentHint', TJSONBool.Create(ReadOnly));
  Annotations.AddPair('openWorldHint', TJSONBool.Create(False));
  Tool.AddPair('annotations', Annotations);
  Tools.AddElement(Tool);
end;

function ToolsListResult(const Id: TJSONValue): string;
var
  ResultObject: TJSONObject;
  Tools: TJSONArray;
begin
  ResultObject := TJSONObject.Create;
  Tools := TJSONArray.Create;
  AddTool(Tools, 'get_pose_catalog_context',
    '選択中PMXのID、モデルファイル、表示名を取得する。',
    '{"type":"object","properties":{},"additionalProperties":false}',
    True);
  AddTool(Tools, 'get_active_pose_context',
    '開いているポーズ設定画面のセッション、現在姿勢、版番号を取得する。',
    '{"type":"object","properties":{},"additionalProperties":false}',
    True);
  AddTool(Tools, 'get_model_schema',
    'PMXの全ボーン、親子関係、IK等を取得する。',
    '{"type":"object","properties":{"model_file":{"type":"string"}},' +
    '"required":["model_file"],"additionalProperties":false}', True);
  AddTool(Tools, 'preview_pose',
    'モデル固有の候補を検証し、完全な正規化pose_dataを生成する。',
    '{"type":"object","properties":{"model_file":{"type":"string"},' +
    '"current_pose":{"type":"string"},"payload":{"type":"object"}},' +
    '"required":["model_file","payload"],"additionalProperties":false}',
    True);
  AddTool(Tools, 'preview_pose_in_session',
    '候補姿勢を開いている設定画面へUndo可能な編集として反映する。',
    '{"type":"object","properties":{"session_id":{"type":"string"},' +
    '"base_revision":{"type":"integer"},"candidate_id":{"type":"string"},' +
    '"pose_name":{"type":"string"},"pose_data":{"type":"string"},' +
    '"payload":{"type":"object"}},"required":["session_id",' +
    '"base_revision"],"additionalProperties":false}', False);
  AddTool(Tools, 'create_pose_file',
    '完成pose_dataをVPDと選択PMXのPoseUIDへ登録し、一覧を更新する。',
    '{"type":"object","properties":{"pmx_id":{"type":"string"},' +
    '"model_file":{"type":"string"},"pose_name":{"type":"string"},' +
    '"pose_data":{"type":"string"}},"required":["pose_name",' +
    '"pose_data"],"additionalProperties":false}', False);
  ResultObject.AddPair('tools', Tools);
  Result := RpcEnvelope(Id, ResultObject, 'result');
end;

function BuildPipeRequest(const ToolName: string;
  Arguments: TJSONObject): string;
var
  I: Integer;
  Pair: TJSONPair;
  Request: TJSONObject;
begin
  Request := TJSONObject.Create;
  try
    Request.AddPair('operation', ToolName);
    if Assigned(Arguments) then
      for I := 0 to Arguments.Count - 1 do
      begin
        Pair := Arguments.Pairs[I];
        if not SameText(Pair.JsonString.Value, 'operation') then
          Request.AddPair(Pair.JsonString.Value, CloneJson(Pair.JsonValue));
      end;
    Result := Request.ToJSON;
  finally
    Request.Free;
  end;
end;

function IsSupportedTool(const Name: string): Boolean;
begin
  Result := SameText(Name, 'get_pose_catalog_context') or
    SameText(Name, 'get_active_pose_context') or
    SameText(Name, 'get_model_schema') or
    SameText(Name, 'preview_pose') or
    SameText(Name, 'preview_pose_in_session') or
    SameText(Name, 'create_pose_file');
end;

function ToolCallResult(const Id: TJSONValue; Params: TJSONObject): string;
var
  Arguments: TJSONObject;
  Content: TJSONArray;
  IsError: Boolean;
  Name, PipeResponse: string;
  ParsedResponse, Value: TJSONValue;
  PipeError, ResultObject, TextContent: TJSONObject;
begin
  Name := JsonString(Params, 'name');
  if not IsSupportedTool(Name) then
    Exit(RpcError(Id, -32602, 'Unknown MMD tool: ' + Name));
  Value := Params.GetValue('arguments');
  if Assigned(Value) and not (Value is TJSONObject) then
    Exit(RpcError(Id, -32602, 'Tool arguments must be an object.'));
  Arguments := TJSONObject(Value);
  try
    PipeResponse := InvokeMmdAiPreviewPipe(
      BuildPipeRequest(Name, Arguments));
  except
    on E: Exception do
    begin
      PipeError := TJSONObject.Create;
      try
        PipeError.AddPair('status', 'error');
        PipeError.AddPair('code', 'pipe_unavailable');
        PipeError.AddPair('message', E.Message);
        PipeResponse := PipeError.ToJSON;
      finally
        PipeError.Free;
      end;
    end;
  end;
  IsError := True;
  ParsedResponse := TJSONObject.ParseJSONValue(PipeResponse);
  try
    if ParsedResponse is TJSONObject then
      IsError := SameText(JsonString(TJSONObject(ParsedResponse), 'status'),
        'error');
    ResultObject := TJSONObject.Create;
    Content := TJSONArray.Create;
    TextContent := TJSONObject.Create;
    TextContent.AddPair('type', 'text');
    TextContent.AddPair('text', PipeResponse);
    Content.AddElement(TextContent);
    ResultObject.AddPair('content', Content);
    if ParsedResponse is TJSONObject then
      ResultObject.AddPair('structuredContent', CloneJson(ParsedResponse));
    ResultObject.AddPair('isError', TJSONBool.Create(IsError));
    Result := RpcEnvelope(Id, ResultObject, 'result');
  finally
    ParsedResponse.Free;
  end;
end;

function DispatchMcpRequest(const RequestText: string): string;
var
  Id, ParamsValue, RootValue: TJSONValue;
  Method: string;
  Root: TJSONObject;
begin
  Result := '';
  RootValue := TJSONObject.ParseJSONValue(RequestText);
  try
    if not (RootValue is TJSONObject) then
      Exit(RpcError(nil, -32700, 'Parse error.'));
    Root := TJSONObject(RootValue);
    Id := Root.GetValue('id');
    Method := JsonString(Root, 'method');
    if SameText(Method, 'notifications/initialized') or
      SameText(Method, 'notifications/cancelled') then
      Exit('');
    if SameText(Method, 'initialize') then
      Exit(InitializeResult(Id));
    if SameText(Method, 'ping') then
      Exit(EmptyResult(Id));
    if SameText(Method, 'tools/list') then
      Exit(ToolsListResult(Id));
    if SameText(Method, 'tools/call') then
    begin
      ParamsValue := Root.GetValue('params');
      if not (ParamsValue is TJSONObject) then
        Exit(RpcError(Id, -32602, 'tools/call params must be an object.'));
      Exit(ToolCallResult(Id, TJSONObject(ParamsValue)));
    end;
    if not Assigned(Id) then
      Exit('');
    Result := RpcError(Id, -32601, 'Method not found: ' + Method);
  finally
    RootValue.Free;
  end;
end;

procedure RunMmdAiPreviewMcp;
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
        ResponseText := DispatchMcpRequest(RequestText);
      except
        on E: Exception do
          ResponseText := RpcError(nil, -32603, E.Message);
      end;
      if ResponseText <> '' then
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

end.
