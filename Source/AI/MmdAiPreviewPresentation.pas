unit MmdAiPreviewPresentation;

// PipeワーカースレッドからVCL確認画面へ、正規化済み候補姿勢を同期提示する。

interface

uses
  Winapi.Messages,
  Winapi.Windows,
  System.JSON;

const
  WM_MMD_AI_PRESENT_POSE = WM_APP + 241;

procedure RegisterMmdAiPresentationWindow(Window: HWND);
procedure UnregisterMmdAiPresentationWindow(Window: HWND);
function TakePendingMmdAiPresentation(out PresentationText: string): Boolean;
procedure CompleteMmdAiPresentation(const ErrorText: string);
function PresentMmdPose(const Request: TJSONObject): string;

implementation

uses
  System.SyncObjs,
  System.SysUtils,
  MmdAiPlaceholderModel,
  MmdAiPoseRepository,
  MmdAiProvider,
  MmdAiProviderClient,
  PmxModel,
  PmxPose,
  PmxPoseCodec;

var
  PresentationLock: TCriticalSection;
  PresentationWindow: HWND;
  PendingBusy: Boolean;
  PendingError: string;
  PendingText: string;

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

function CloneJson(const Value: TJSONValue): TJSONValue;
begin
  if Value = nil then
    Exit(nil);
  Result := TJSONObject.ParseJSONValue(Value.ToJSON);
end;

function ReadString(const Object_: TJSONObject; const Name,
  DefaultValue: string): string;
var
  Value: TJSONValue;
begin
  Result := DefaultValue;
  Value := Object_.GetValue(Name);
  if Value is TJSONString then
    Result := TJSONString(Value).Value;
end;

function BuildPreviewRequest(const Request: TJSONObject): string;
var
  Preview: TJSONObject;
  Value: TJSONValue;
begin
  Preview := TJSONObject.Create;
  try
    Preview.AddPair('operation', 'preview_pose');
    Value := Request.GetValue('model_file');
    if Value <> nil then
      Preview.AddPair('model_file', CloneJson(Value));
    Value := Request.GetValue('current_pose');
    if Value <> nil then
      Preview.AddPair('current_pose', CloneJson(Value));
    Value := Request.GetValue('payload');
    if Value <> nil then
      Preview.AddPair('payload', CloneJson(Value));
    Result := Preview.ToJSON;
  finally
    Preview.Free;
  end;
end;

function BuildDirectPosePreview(const PoseData: string): string;
var
  NamedPoses: TPmxNamedBonePoses;
  ResolvedBones: TJSONArray;
  Root: TJSONObject;
begin
  if not TryDecodePoseData(PoseData, NamedPoses) then
    Exit(ErrorJson('invalid_pose_data',
      'pose_data must be mmd.pose version 1.'));
  Root := TJSONObject.Create;
  try
    Root.AddPair('status', 'ok');
    Root.AddPair('extension', 'mmd.pose');
    Root.AddPair('operation', 'preview_pose');
    Root.AddPair('pose_data', EncodePoseData(NamedPoses));
    Root.AddPair('bone_count', TJSONNumber.Create(Length(NamedPoses)));
    ResolvedBones := TJSONArray.Create;
    Root.AddPair('resolved_bones', ResolvedBones);
    Root.AddPair('model_validation', TJSONBool.Create(False));
    Result := Root.ToJSON;
  finally
    Root.Free;
  end;
end;

function NewCandidateId: string;
var
  Id: TGUID;
begin
  CreateGUID(Id);
  Result := GUIDToString(Id).Replace('{', '').Replace('}', '').ToLower;
end;

procedure RegisterMmdAiPresentationWindow(Window: HWND);
begin
  PresentationLock.Acquire;
  try
    PresentationWindow := Window;
  finally
    PresentationLock.Release;
  end;
end;

procedure UnregisterMmdAiPresentationWindow(Window: HWND);
begin
  PresentationLock.Acquire;
  try
    if PresentationWindow = Window then
      PresentationWindow := 0;
  finally
    PresentationLock.Release;
  end;
end;

function TakePendingMmdAiPresentation(
  out PresentationText: string): Boolean;
begin
  PresentationLock.Acquire;
  try
    Result := PendingBusy and (PendingText <> '');
    if Result then
      PresentationText := PendingText
    else
      PresentationText := '';
  finally
    PresentationLock.Release;
  end;
end;

procedure CompleteMmdAiPresentation(const ErrorText: string);
begin
  PresentationLock.Acquire;
  try
    PendingError := ErrorText;
  finally
    PresentationLock.Release;
  end;
end;

function QueuePresentation(const PresentationText: string;
  out ErrorText: string): Boolean;
var
  MessageResult: DWORD_PTR;
  Window: HWND;
begin
  Result := False;
  ErrorText := '';
  PresentationLock.Acquire;
  try
    Window := PresentationWindow;
    if (Window = 0) or not IsWindow(Window) then
    begin
      ErrorText := 'The 3D preview window is not open.';
      Exit;
    end;
    if PendingBusy then
    begin
      ErrorText := 'Another pose is being presented.';
      Exit;
    end;
    PendingBusy := True;
    PendingText := PresentationText;
    PendingError := '';
  finally
    PresentationLock.Release;
  end;
  try
    if SendMessageTimeout(Window, WM_MMD_AI_PRESENT_POSE, 0, 0,
      SMTO_ABORTIFHUNG or SMTO_BLOCK, 10000, @MessageResult) = 0 then
      ErrorText := 'The 3D preview window did not respond.'
    else
    begin
      PresentationLock.Acquire;
      try
        ErrorText := PendingError;
      finally
        PresentationLock.Release;
      end;
    end;
    Result := ErrorText = '';
  finally
    PresentationLock.Acquire;
    try
      PendingBusy := False;
      PendingText := '';
      PendingError := '';
    finally
      PresentationLock.Release;
    end;
  end;
end;

function PresentMmdPose(const Request: TJSONObject): string;
var
  CandidateId, CurrentPose, DirectPoseData, ErrorText, ModelFile, PoseData,
  PoseFile, PoseName, PreviewText: string;
  PlaceholderModel: TPmxModel;
  Presentation, ResultRoot: TJSONObject;
  PreviewRoot: TJSONObject;
  PreviewValue: TJSONValue;
begin
  try
    ModelFile := ReadString(Request, 'model_file', '');
    DirectPoseData := ReadString(Request, 'pose_data', '');
    if (DirectPoseData = '') and
       not (Request.GetValue('payload') is TJSONObject) then
      Exit(ErrorJson('invalid_payload', 'payload must be an object.'));
    PoseName := ReadString(Request, 'pose_name', '新しいポーズ');
    CandidateId := ReadString(Request, 'candidate_id', '');
    if CandidateId = '' then
      CandidateId := NewCandidateId;
    if DirectPoseData <> '' then
      PreviewText := BuildDirectPosePreview(DirectPoseData)
    else if ModelFile <> '' then
      PreviewText := InvokeMmdAiProvider(BuildPreviewRequest(Request))
    else
    begin
      CurrentPose := ReadString(Request, 'current_pose', '');
      PlaceholderModel := CreateMmdPlaceholderModel;
      try
        PreviewText := PreviewMmdAiPoseForModel(PlaceholderModel,
          CurrentPose, TJSONObject(Request.GetValue('payload')));
      finally
        PlaceholderModel.Free;
      end;
    end;
    PreviewValue := TJSONObject.ParseJSONValue(PreviewText);
    try
      if not (PreviewValue is TJSONObject) then
        Exit(ErrorJson('invalid_preview_response',
          'MMD provider returned invalid JSON.'));
      PreviewRoot := TJSONObject(PreviewValue);
      if not SameText(ReadString(PreviewRoot, 'status', ''), 'ok') then
        Exit(PreviewText);
      PoseData := ReadString(PreviewRoot, 'pose_data', '');
      if PoseData = '' then
        Exit(ErrorJson('missing_pose_data',
          'MMD provider did not return pose_data.'));
      PoseFile := SaveMmdAiPoseFile(PoseName, CandidateId, PoseData);
      Presentation := TJSONObject.Create;
      try
        Presentation.AddPair('candidate_id', CandidateId);
        Presentation.AddPair('pose_name', PoseName);
        Presentation.AddPair('model_file', ModelFile);
        Presentation.AddPair('pose_data', PoseData);
        Presentation.AddPair('pose_file', PoseFile);
        if not QueuePresentation(Presentation.ToJSON, ErrorText) then
          Exit(ErrorJson('preview_ui_unavailable', ErrorText));
      finally
        Presentation.Free;
      end;
      ResultRoot := TJSONObject.Create;
      try
        ResultRoot.AddPair('status', 'ok');
        ResultRoot.AddPair('extension', 'mmd.preview');
        ResultRoot.AddPair('operation', 'present_pose');
        ResultRoot.AddPair('candidate_id', CandidateId);
        ResultRoot.AddPair('pose_name', PoseName);
        ResultRoot.AddPair('pose_data', PoseData);
        ResultRoot.AddPair('pose_file', PoseFile);
        ResultRoot.AddPair('preview', CloneJson(PreviewRoot));
        Result := ResultRoot.ToJSON;
      finally
        ResultRoot.Free;
      end;
    finally
      PreviewValue.Free;
    end;
  except
    on E: Exception do
      Result := ErrorJson('present_pose_failed', E.Message);
  end;
end;

initialization
  PresentationLock := TCriticalSection.Create;

finalization
  PresentationLock.Free;

end.
