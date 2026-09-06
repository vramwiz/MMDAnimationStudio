unit MmdAiPoseSession;

// Codexから届く姿勢を、現在開いているポーズ編集フォームへ安全に中継する。

interface

uses
  Winapi.Messages,
  Winapi.Windows,
  System.JSON;

const
  WM_MMD_AI_PREVIEW_SESSION_POSE = WM_APP + 242;

// 編集フォームをAI対象として登録し、現在姿勢とモデル情報を公開する。
procedure RegisterMmdAiPoseSession(Window: HWND; const SessionId,
  ModelFile, PoseName, PoseData: string);
// 手動編集またはAI適用後の最新姿勢を、次のCodex要求用に更新する。
procedure UpdateMmdAiPoseSession(Window: HWND; const PoseData: string);
// 対応する編集フォームが閉じた場合だけ登録を解除する。
procedure UnregisterMmdAiPoseSession(Window: HWND);
// 現在の編集対象を版番号付きJSONで返す。未登録も正常応答として返す。
function GetMmdAiPoseSessionContext: string;
// 要求姿勢を正規化し、版競合を検査して開いている編集フォームへ仮適用する。
function PreviewMmdAiPoseInSession(const Request: TJSONObject): string;
// VCLメッセージ受信側が保留中の候補を1件取得する。
function TakePendingMmdAiSessionPose(out PresentationText: string): Boolean;
// VCL側の適用結果を待機中のPipe要求へ返す。
procedure CompleteMmdAiSessionPose(const ErrorText: string);
// ポーズ編集画面が開いているかを返す。
function HasActiveMmdAiPoseSession: Boolean;

implementation

uses
  System.SyncObjs,
  System.SysUtils,
  MmdAiProviderClient,
  PmxPose,
  PmxPoseCodec;

var
  SessionLock: TCriticalSection;
  SessionWindow: HWND;
  ActiveSessionId: string;
  ActiveModelFile: string;
  ActivePoseName: string;
  ActivePoseData: string;
  ActiveRevision: Int64;
  PendingBusy: Boolean;
  PendingError: string;
  PendingText: string;

function CloneJson(const Value: TJSONValue): TJSONValue;
begin
  if Value = nil then
    Exit(nil);
  Result := TJSONObject.ParseJSONValue(Value.ToJSON);
end;

function ReadString(const Root: TJSONObject; const Name,
  DefaultValue: string): string;
var
  Value: TJSONValue;
begin
  Result := DefaultValue;
  Value := Root.GetValue(Name);
  if Value is TJSONString then
    Result := TJSONString(Value).Value;
end;

function ErrorJson(const Code, MessageText: string): string;
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

procedure RegisterMmdAiPoseSession(Window: HWND; const SessionId,
  ModelFile, PoseName, PoseData: string);
begin
  SessionLock.Acquire;
  try
    SessionWindow := Window;
    ActiveSessionId := SessionId;
    ActiveModelFile := ModelFile;
    ActivePoseName := PoseName;
    ActivePoseData := PoseData;
    ActiveRevision := 1;
  finally
    SessionLock.Release;
  end;
end;

procedure UpdateMmdAiPoseSession(Window: HWND; const PoseData: string);
begin
  SessionLock.Acquire;
  try
    if SessionWindow <> Window then
      Exit;
    ActivePoseData := PoseData;
    Inc(ActiveRevision);
  finally
    SessionLock.Release;
  end;
end;

procedure UnregisterMmdAiPoseSession(Window: HWND);
begin
  SessionLock.Acquire;
  try
    if SessionWindow <> Window then
      Exit;
    SessionWindow := 0;
    ActiveSessionId := '';
    ActiveModelFile := '';
    ActivePoseName := '';
    ActivePoseData := '';
    ActiveRevision := 0;
  finally
    SessionLock.Release;
  end;
end;

function HasActiveMmdAiPoseSession: Boolean;
begin
  SessionLock.Acquire;
  try
    Result := (SessionWindow <> 0) and IsWindow(SessionWindow);
  finally
    SessionLock.Release;
  end;
end;

function GetMmdAiPoseSessionContext: string;
var
  Root: TJSONObject;
begin
  Root := TJSONObject.Create;
  try
    Root.AddPair('status', 'ok');
    Root.AddPair('operation', 'get_active_pose_context');
    SessionLock.Acquire;
    try
      Root.AddPair('active', TJSONBool.Create(
        (SessionWindow <> 0) and IsWindow(SessionWindow)));
      if SessionWindow <> 0 then
      begin
        Root.AddPair('session_id', ActiveSessionId);
        Root.AddPair('model_file', ActiveModelFile);
        Root.AddPair('pose_name', ActivePoseName);
        Root.AddPair('pose_data', ActivePoseData);
        Root.AddPair('revision', TJSONNumber.Create(ActiveRevision));
      end;
    finally
      SessionLock.Release;
    end;
    Result := Root.ToJSON;
  finally
    Root.Free;
  end;
end;

function ResolvePose(const Request: TJSONObject; const ModelFile,
  CurrentPose: string; out PoseData, ErrorText: string): Boolean;
var
  NamedPoses: TPmxNamedBonePoses;
  Preview, PreviewRoot: TJSONObject;
  PreviewText: string;
  PreviewValue, Value: TJSONValue;
begin
  Result := False;
  ErrorText := '';
  PoseData := ReadString(Request, 'pose_data', '');
  if PoseData <> '' then
  begin
    if not TryDecodePoseData(PoseData, NamedPoses) then
      ErrorText := 'pose_data must be mmd.pose version 1.'
    else
    begin
      PoseData := EncodePoseData(NamedPoses);
      Result := True;
    end;
    Exit;
  end;
  Value := Request.GetValue('payload');
  if not (Value is TJSONObject) then
  begin
    ErrorText := 'pose_data or payload is required.';
    Exit;
  end;
  Preview := TJSONObject.Create;
  try
    Preview.AddPair('operation', 'preview_pose');
    Preview.AddPair('model_file', ModelFile);
    Preview.AddPair('current_pose', CurrentPose);
    Preview.AddPair('payload', CloneJson(Value));
    PreviewText := InvokeMmdAiProvider(Preview.ToJSON);
  finally
    Preview.Free;
  end;
  PreviewValue := TJSONObject.ParseJSONValue(PreviewText);
  try
    if not (PreviewValue is TJSONObject) then
    begin
      ErrorText := 'MMD provider returned invalid JSON.';
      Exit;
    end;
    PreviewRoot := TJSONObject(PreviewValue);
    if not SameText(ReadString(PreviewRoot, 'status', ''), 'ok') then
    begin
      ErrorText := ReadString(PreviewRoot, 'message', PreviewText);
      Exit;
    end;
    PoseData := ReadString(PreviewRoot, 'pose_data', '');
    if not TryDecodePoseData(PoseData, NamedPoses) then
    begin
      ErrorText := 'MMD provider returned invalid pose_data.';
      Exit;
    end;
    PoseData := EncodePoseData(NamedPoses);
    Result := True;
  finally
    PreviewValue.Free;
  end;
end;

function QueueSessionPose(const Text: string; Window: HWND;
  out ErrorText: string): Boolean;
var
  MessageResult: DWORD_PTR;
begin
  Result := False;
  SessionLock.Acquire;
  try
    if PendingBusy then
    begin
      ErrorText := 'Another pose is being applied.';
      Exit;
    end;
    PendingBusy := True;
    PendingText := Text;
    PendingError := '';
  finally
    SessionLock.Release;
  end;
  try
    if SendMessageTimeout(Window, WM_MMD_AI_PREVIEW_SESSION_POSE, 0, 0,
      SMTO_ABORTIFHUNG or SMTO_BLOCK, 10000, @MessageResult) = 0 then
      ErrorText := 'The pose editor did not respond.'
    else
    begin
      SessionLock.Acquire;
      try
        ErrorText := PendingError;
      finally
        SessionLock.Release;
      end;
    end;
    Result := ErrorText = '';
  finally
    SessionLock.Acquire;
    try
      PendingBusy := False;
      PendingText := '';
      PendingError := '';
    finally
      SessionLock.Release;
    end;
  end;
end;

function PreviewMmdAiPoseInSession(const Request: TJSONObject): string;
var
  CandidateId, ErrorText, ModelFile, PoseData, PoseName, RequestedSession,
    SessionId: string;
  BaseRevision, Revision: Int64;
  HasBaseRevision: Boolean;
  Presentation, Response: TJSONObject;
  Value: TJSONValue;
  Window: HWND;
begin
  BaseRevision := 0;
  SessionLock.Acquire;
  try
    Window := SessionWindow;
    SessionId := ActiveSessionId;
    ModelFile := ActiveModelFile;
    PoseData := ActivePoseData;
    Revision := ActiveRevision;
  finally
    SessionLock.Release;
  end;
  if (Window = 0) or not IsWindow(Window) then
    Exit(ErrorJson('pose_editor_unavailable',
      'The MMD pose settings window is not open.'));
  RequestedSession := ReadString(Request, 'session_id', '');
  if (RequestedSession <> '') and not SameText(RequestedSession, SessionId) then
    Exit(ErrorJson('pose_session_changed', 'The pose editor session changed.'));
  Value := Request.GetValue('base_revision');
  HasBaseRevision := Value is TJSONNumber;
  if HasBaseRevision then
  begin
    BaseRevision := Trunc(TJSONNumber(Value).AsDouble);
    if BaseRevision <> Revision then
      Exit(ErrorJson('pose_revision_changed',
        'The pose was edited after this request started.'));
  end;
  if not ResolvePose(Request, ModelFile, PoseData, PoseData, ErrorText) then
    Exit(ErrorJson('invalid_pose_request', ErrorText));
  SessionLock.Acquire;
  try
    if (SessionWindow <> Window) or
      not SameText(ActiveSessionId, SessionId) then
      Exit(ErrorJson('pose_session_changed', 'The pose editor session changed.'));
    if HasBaseRevision and (ActiveRevision <> BaseRevision) then
      Exit(ErrorJson('pose_revision_changed',
        'The pose was edited while this request was being generated.'));
  finally
    SessionLock.Release;
  end;
  PoseName := ReadString(Request, 'pose_name', ActivePoseName);
  CandidateId := ReadString(Request, 'candidate_id', '');
  Presentation := TJSONObject.Create;
  try
    Presentation.AddPair('session_id', SessionId);
    Presentation.AddPair('candidate_id', CandidateId);
    Presentation.AddPair('pose_name', PoseName);
    Presentation.AddPair('pose_data', PoseData);
    if not QueueSessionPose(Presentation.ToJSON, Window, ErrorText) then
      Exit(ErrorJson('pose_apply_failed', ErrorText));
  finally
    Presentation.Free;
  end;
  Response := TJSONObject.Create;
  try
    Response.AddPair('status', 'ok');
    Response.AddPair('operation', 'preview_pose_in_session');
    Response.AddPair('session_id', SessionId);
    Response.AddPair('pose_name', PoseName);
    Response.AddPair('pose_data', PoseData);
    SessionLock.Acquire;
    try
      Response.AddPair('revision', TJSONNumber.Create(ActiveRevision));
    finally
      SessionLock.Release;
    end;
    Result := Response.ToJSON;
  finally
    Response.Free;
  end;
end;

function TakePendingMmdAiSessionPose(
  out PresentationText: string): Boolean;
begin
  SessionLock.Acquire;
  try
    Result := PendingBusy and (PendingText <> '');
    if Result then
      PresentationText := PendingText
    else
      PresentationText := '';
  finally
    SessionLock.Release;
  end;
end;

procedure CompleteMmdAiSessionPose(const ErrorText: string);
begin
  SessionLock.Acquire;
  try
    PendingError := ErrorText;
  finally
    SessionLock.Release;
  end;
end;

initialization
  SessionLock := TCriticalSection.Create;

finalization
  SessionLock.Free;

end.
