unit MmdAiPoseCatalogBridge;

// Codexのポーズファイル生成要求を、MMDAnimationStudioのPMX別カタログ登録へ中継する。

interface

uses
  Winapi.Messages,
  Winapi.Windows,
  System.JSON;

const
  WM_MMD_AI_CREATE_POSE_FILE = WM_APP + 243;

// MMDAnimationStudioの受信ウィンドウを登録する。
procedure RegisterMmdAiPoseCatalogWindow(Window: HWND);
// 対応する受信ウィンドウが破棄される場合だけ登録を解除する。
procedure UnregisterMmdAiPoseCatalogWindow(Window: HWND);
// 画面間で同期された現在PMXを、Codexから取得できる状態へ更新する。
procedure UpdateMmdAiPoseCatalogContext(const PmxId, ModelFile,
  ModelName: string);
// 現在選択中のPMX情報をJSONで返す。
function GetMmdAiPoseCatalogContext: string;
// 完全な姿勢JSONを、対象PMXのVPDおよびPoseUIDとして登録する。
function CreateMmdAiPoseFile(const Request: TJSONObject): string;
// MMDAnimationStudio側が保留中の登録要求を取得する。
function TakePendingMmdAiPoseFile(out RequestText: string): Boolean;
// MMDAnimationStudio側の登録結果を待機中のPipe要求へ返す。
procedure CompleteMmdAiPoseFile(const ResponseText, ErrorText: string);

implementation

uses
  System.SyncObjs,
  System.SysUtils,
  PmxPose,
  PmxPoseCodec;

var
  CatalogLock: TCriticalSection;
  CatalogWindow: HWND;
  CurrentPmxId: string;
  CurrentModelFile: string;
  CurrentModelName: string;
  PendingBusy: Boolean;
  PendingError: string;
  PendingRequest: string;
  PendingResponse: string;

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

procedure RegisterMmdAiPoseCatalogWindow(Window: HWND);
begin
  CatalogLock.Acquire;
  try
    CatalogWindow := Window;
  finally
    CatalogLock.Release;
  end;
end;

procedure UnregisterMmdAiPoseCatalogWindow(Window: HWND);
begin
  CatalogLock.Acquire;
  try
    if CatalogWindow = Window then
      CatalogWindow := 0;
  finally
    CatalogLock.Release;
  end;
end;

procedure UpdateMmdAiPoseCatalogContext(const PmxId, ModelFile,
  ModelName: string);
begin
  CatalogLock.Acquire;
  try
    CurrentPmxId := PmxId;
    CurrentModelFile := ModelFile;
    CurrentModelName := ModelName;
  finally
    CatalogLock.Release;
  end;
end;

function GetMmdAiPoseCatalogContext: string;
var
  Root: TJSONObject;
begin
  Root := TJSONObject.Create;
  try
    Root.AddPair('status', 'ok');
    Root.AddPair('operation', 'get_pose_catalog_context');
    CatalogLock.Acquire;
    try
      Root.AddPair('active', TJSONBool.Create(CurrentPmxId <> ''));
      if CurrentPmxId <> '' then
      begin
        Root.AddPair('pmx_id', CurrentPmxId);
        Root.AddPair('model_file', CurrentModelFile);
        Root.AddPair('model_name', CurrentModelName);
      end;
    finally
      CatalogLock.Release;
    end;
    Result := Root.ToJSON;
  finally
    Root.Free;
  end;
end;

function CreateMmdAiPoseFile(const Request: TJSONObject): string;
var
  ErrorText, ModelFile, PmxId, PoseData, PoseName, ResponseText: string;
  MessageResult: DWORD_PTR;
  NamedPoses: TPmxNamedBonePoses;
  RootRotation: TPmxQuaternion;
  HasRootRotation: Boolean;
  RelativeYaw, RelativePitch: Single;
  HasRelativeAngle: Boolean;
  Normalized: TJSONObject;
  Window: HWND;
begin
  PoseData := ReadString(Request, 'pose_data', '');
  if not TryDecodePoseDataWithRootAndAngle(PoseData, NamedPoses,
    RootRotation, HasRootRotation, RelativeYaw, RelativePitch,
    HasRelativeAngle) then
    Exit(ErrorJson('invalid_pose_data',
      'pose_data must be a complete mmd.pose version 1 object.'));
  PoseData := EncodePoseDataWithRootAndAngle(NamedPoses,
    RootRotation, HasRootRotation, RelativeYaw, RelativePitch,
    HasRelativeAngle);
  PoseName := ReadString(Request, 'pose_name', '新しいポーズ');
  if Trim(PoseName) = '' then
    PoseName := '新しいポーズ';
  PmxId := ReadString(Request, 'pmx_id', '');
  ModelFile := ReadString(Request, 'model_file', '');
  CatalogLock.Acquire;
  try
    Window := CatalogWindow;
    if PmxId = '' then
      PmxId := CurrentPmxId;
    if ModelFile = '' then
      ModelFile := CurrentModelFile;
    if PendingBusy then
      Exit(ErrorJson('pose_catalog_busy',
        'Another pose file is being registered.'));
    if (Window = 0) or not IsWindow(Window) then
      Exit(ErrorJson('pose_catalog_unavailable',
        'MMDAnimationStudio is not running.'));
    PendingBusy := True;
    PendingError := '';
    PendingResponse := '';
  finally
    CatalogLock.Release;
  end;
  Normalized := TJSONObject.Create;
  try
    Normalized.AddPair('pmx_id', PmxId);
    Normalized.AddPair('model_file', ModelFile);
    Normalized.AddPair('pose_name', PoseName);
    Normalized.AddPair('pose_data', PoseData);
    CatalogLock.Acquire;
    try
      PendingRequest := Normalized.ToJSON;
    finally
      CatalogLock.Release;
    end;
    ErrorText := '';
    if SendMessageTimeout(Window, WM_MMD_AI_CREATE_POSE_FILE, 0, 0,
      SMTO_ABORTIFHUNG or SMTO_BLOCK, 10000, @MessageResult) = 0 then
      ErrorText := 'MMDAnimationStudio did not respond.'
    else
    begin
      CatalogLock.Acquire;
      try
        ErrorText := PendingError;
        ResponseText := PendingResponse;
      finally
        CatalogLock.Release;
      end;
    end;
    if ErrorText <> '' then
      Result := ErrorJson('pose_file_registration_failed', ErrorText)
    else if ResponseText = '' then
      Result := ErrorJson('pose_file_registration_failed',
        'MMDAnimationStudio returned no registration result.')
    else
      Result := ResponseText;
  finally
    Normalized.Free;
    CatalogLock.Acquire;
    try
      PendingBusy := False;
      PendingError := '';
      PendingRequest := '';
      PendingResponse := '';
    finally
      CatalogLock.Release;
    end;
  end;
end;

function TakePendingMmdAiPoseFile(out RequestText: string): Boolean;
begin
  CatalogLock.Acquire;
  try
    Result := PendingBusy and (PendingRequest <> '');
    if Result then
      RequestText := PendingRequest
    else
      RequestText := '';
  finally
    CatalogLock.Release;
  end;
end;

procedure CompleteMmdAiPoseFile(const ResponseText, ErrorText: string);
begin
  CatalogLock.Acquire;
  try
    PendingResponse := ResponseText;
    PendingError := ErrorText;
  finally
    CatalogLock.Release;
  end;
end;

initialization
  CatalogLock := TCriticalSection.Create;

finalization
  CatalogLock.Free;

end.
