program MmdAiPoseBridgeTest;

{$APPTYPE CONSOLE}

uses
  Winapi.Messages,
  Winapi.Windows,
  System.Classes,
  System.JSON,
  System.SysUtils,
  MmdAiPoseCatalogBridge,
  MmdAiPoseSession;

type
  TBridgeWindow = class
  private
    FHandle: HWND;
    FLastCatalogRequest: string;
    FLastSessionPose: string;
    procedure WindowProc(var Message: TMessage);
  public
    constructor Create;
    destructor Destroy; override;
    property Handle: HWND read FHandle;
    property LastCatalogRequest: string read FLastCatalogRequest;
    property LastSessionPose: string read FLastSessionPose;
  end;

procedure Check(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

function JsonString(const JsonText, Name: string): string;
var
  Root: TJSONObject;
  Value, RootValue: TJSONValue;
begin
  Result := '';
  RootValue := TJSONObject.ParseJSONValue(JsonText);
  try
    Check(RootValue is TJSONObject, 'response is not a JSON object');
    Root := TJSONObject(RootValue);
    Value := Root.GetValue(Name);
    if Value is TJSONString then
      Result := TJSONString(Value).Value;
  finally
    RootValue.Free;
  end;
end;

function JsonInt(const JsonText, Name: string): Int64;
var
  Root: TJSONObject;
  Value, RootValue: TJSONValue;
begin
  Result := -1;
  RootValue := TJSONObject.ParseJSONValue(JsonText);
  try
    Check(RootValue is TJSONObject, 'response is not a JSON object');
    Root := TJSONObject(RootValue);
    Value := Root.GetValue(Name);
    if Value is TJSONNumber then
      Result := Trunc(TJSONNumber(Value).AsDouble);
  finally
    RootValue.Free;
  end;
end;

constructor TBridgeWindow.Create;
begin
  inherited Create;
  FHandle := AllocateHWnd(WindowProc);
end;

destructor TBridgeWindow.Destroy;
begin
  if FHandle <> 0 then
    DeallocateHWnd(FHandle);
  inherited Destroy;
end;

procedure TBridgeWindow.WindowProc(var Message: TMessage);
var
  RequestText: string;
  Root, RootValue: TJSONValue;
begin
  case Message.Msg of
    WM_MMD_AI_PREVIEW_SESSION_POSE:
      begin
        if not TakePendingMmdAiSessionPose(RequestText) then
        begin
          CompleteMmdAiSessionPose('missing session request');
          Exit;
        end;
        RootValue := TJSONObject.ParseJSONValue(RequestText);
        try
          if RootValue is TJSONObject then
          begin
            Root := TJSONObject(RootValue).GetValue('pose_data');
            if Root is TJSONString then
              FLastSessionPose := TJSONString(Root).Value;
          end;
        finally
          RootValue.Free;
        end;
        UpdateMmdAiPoseSession(FHandle, FLastSessionPose);
        CompleteMmdAiSessionPose('');
        Message.Result := 1;
      end;
    WM_MMD_AI_CREATE_POSE_FILE:
      begin
        if not TakePendingMmdAiPoseFile(FLastCatalogRequest) then
        begin
          CompleteMmdAiPoseFile('', 'missing catalog request');
          Exit;
        end;
        CompleteMmdAiPoseFile(
          '{"status":"ok","operation":"create_pose_file",' +
          '"pose_uid":"pose-test"}', '');
        Message.Result := 1;
      end;
  else
    Message.Result := DefWindowProc(FHandle, Message.Msg, Message.WParam,
      Message.LParam);
  end;
end;

procedure RunTests;
const
  EmptyPose = '{"version":1,"bones":[]}';
var
  Bridge: TBridgeWindow;
  Request: TJSONObject;
  ResponseText: string;
begin
  Bridge := TBridgeWindow.Create;
  try
    RegisterMmdAiPoseSession(Bridge.Handle, 'session-test',
      'D:\models\test.pmx', 'test pose', EmptyPose);
    ResponseText := GetMmdAiPoseSessionContext;
    Check(JsonString(ResponseText, 'session_id') = 'session-test',
      'active session was not published');
    Check(JsonInt(ResponseText, 'revision') = 1,
      'initial revision changed');

    Request := TJSONObject.Create;
    try
      Request.AddPair('session_id', 'session-test');
      Request.AddPair('base_revision', TJSONNumber.Create(1));
      Request.AddPair('pose_name', 'AI test pose');
      Request.AddPair('candidate_id', 'candidate-1');
      Request.AddPair('pose_data', EmptyPose);
      ResponseText := PreviewMmdAiPoseInSession(Request);
    finally
      Request.Free;
    end;
    Check(JsonString(ResponseText, 'status') = 'ok',
      'session preview failed: ' + ResponseText);
    Check(JsonInt(ResponseText, 'revision') = 2,
      'applied pose did not advance revision');
    Check(Bridge.LastSessionPose = EmptyPose,
      'session window did not receive pose data');

    Request := TJSONObject.Create;
    try
      Request.AddPair('session_id', 'session-test');
      Request.AddPair('base_revision', TJSONNumber.Create(1));
      Request.AddPair('pose_data', EmptyPose);
      ResponseText := PreviewMmdAiPoseInSession(Request);
    finally
      Request.Free;
    end;
    Check(JsonString(ResponseText, 'code') = 'pose_revision_changed',
      'stale revision was accepted');
    UnregisterMmdAiPoseSession(Bridge.Handle);

    RegisterMmdAiPoseCatalogWindow(Bridge.Handle);
    UpdateMmdAiPoseCatalogContext('pmx-test', 'D:\models\test.pmx',
      'Test Model');
    ResponseText := GetMmdAiPoseCatalogContext;
    Check(JsonString(ResponseText, 'pmx_id') = 'pmx-test',
      'catalog context was not published');
    Request := TJSONObject.Create;
    try
      Request.AddPair('pose_name', 'AI generated pose');
      Request.AddPair('pose_data', EmptyPose);
      ResponseText := CreateMmdAiPoseFile(Request);
    finally
      Request.Free;
    end;
    Check(JsonString(ResponseText, 'pose_uid') = 'pose-test',
      'catalog response was not returned');
    Check(JsonString(Bridge.LastCatalogRequest, 'pmx_id') = 'pmx-test',
      'selected PMX was not supplied to registration');
    Check(JsonString(Bridge.LastCatalogRequest, 'pose_name') =
      'AI generated pose', 'pose name was not supplied to registration');
    UnregisterMmdAiPoseCatalogWindow(Bridge.Handle);
  finally
    UnregisterMmdAiPoseSession(Bridge.Handle);
    UnregisterMmdAiPoseCatalogWindow(Bridge.Handle);
    Bridge.Free;
  end;
end;

begin
  try
    RunTests;
    Writeln('MmdAiPoseBridgeTest: PASS');
  except
    on E: Exception do
    begin
      Writeln(E.ClassName + ': ' + E.Message);
      ExitCode := 1;
    end;
  end;
end.
