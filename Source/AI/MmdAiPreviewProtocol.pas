unit MmdAiPreviewProtocol;

// MMDAIPreview固有命令を処理し、それ以外をMMD共通AIプロバイダーへ委譲する。

interface

// 一件のJSON要求を処理し、一件のJSON応答を返す。
function DispatchMmdAiPreviewRequest(const RequestText: string): string;

implementation

uses
  System.JSON,
  System.SysUtils,
  MmdAiPreviewCapture,
  MmdAiPreviewBatch,
  MmdAiFingerIdValidation,
  MmdAiPreviewPresentation,
  MmdAiProviderClient;

function ReadOperation(const Root: TJSONObject): string;
var
  Value: TJSONValue;
begin
  Result := '';
  Value := Root.GetValue('operation');
  if Value is TJSONString then
    Result := TJSONString(Value).Value;
end;

function AddHostCapabilities(const ProviderText: string): string;
var
  Host, Pipe: TJSONObject;
  Focuses, Operations, Views: TJSONArray;
  RootValue: TJSONValue;
  Root: TJSONObject;
begin
  RootValue := TJSONObject.ParseJSONValue(ProviderText);
  try
    if not (RootValue is TJSONObject) then
      Exit(ProviderText);
    Root := TJSONObject(RootValue);
    Host := TJSONObject.Create;
    Host.AddPair('name', 'MMDAIPreview');
    Operations := TJSONArray.Create;
    Operations.Add('capture_pose');
    Operations.Add('capture_pose_set');
    Operations.Add('validate_finger_id');
    Operations.Add('present_pose');
    Host.AddPair('operations', Operations);
    Views := TJSONArray.Create;
    Views.Add('front');
    Views.Add('back');
    Views.Add('side');
    Views.Add('opposite_side');
    Views.Add('top');
    Views.Add('bottom');
    Views.Add('front_left_3q');
    Views.Add('front_right_3q');
    Host.AddPair('views', Views);
    Views := TJSONArray.Create;
    Views.Add('normal');
    Views.Add('bones');
    Views.Add('bone_overlay');
    Views.Add('silhouette');
    Views.Add('finger_id');
    Views.Add('body_only');
    Host.AddPair('passes', Views);
    Focuses := TJSONArray.Create;
    Focuses.Add('all');
    Focuses.Add('left_hand');
    Focuses.Add('right_hand');
    Focuses.Add('hands');
    Host.AddPair('focuses', Focuses);
    Host.AddPair('capture_format', 'bmp');
    Host.AddPair('auto_fit', TJSONBool.Create(True));
    Pipe := TJSONObject.Create;
    Pipe.AddPair('name', 'MMD.AI.Preview.v1');
    Pipe.AddPair('framing', 'utf8_ndjson');
    Pipe.AddPair('max_request_bytes', TJSONNumber.Create(4 * 1024 * 1024));
    Pipe.AddPair('request_id_echo', TJSONBool.Create(True));
    Host.AddPair('pipe', Pipe);
    Root.AddPair('preview_host', Host);
    Result := Root.ToJSON;
  finally
    RootValue.Free;
  end;
end;

function DispatchMmdAiPreviewRequest(const RequestText: string): string;
var
  Operation: string;
  RootValue: TJSONValue;
begin
  RootValue := TJSONObject.ParseJSONValue(RequestText);
  try
    if RootValue is TJSONObject then
    begin
      Operation := ReadOperation(TJSONObject(RootValue));
      if SameText(Operation, 'capture_pose') then
        Exit(CaptureMmdPose(TJSONObject(RootValue)));
      if SameText(Operation, 'capture_pose_set') then
        Exit(CaptureMmdPoseSet(TJSONObject(RootValue)));
      if SameText(Operation, 'validate_finger_id') then
        Exit(ValidateFingerIdImages(TJSONObject(RootValue)));
      if SameText(Operation, 'present_pose') then
        Exit(PresentMmdPose(TJSONObject(RootValue)));
      if SameText(Operation, 'get_capabilities') then
        Exit(AddHostCapabilities(InvokeMmdAiProvider(RequestText)));
    end;
  finally
    RootValue.Free;
  end;
  Result := InvokeMmdAiProvider(RequestText);
end;

end.
