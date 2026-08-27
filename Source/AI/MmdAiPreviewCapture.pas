unit MmdAiPreviewCapture;

// MMD共通ポーズ正規化とD3Dプレビューを接続し、AviUtl2なしで一時BMPを生成する。

interface

uses
  System.JSON;

// capture_pose要求を処理し、正規化結果と生成画像情報をJSONで返す。
function CaptureMmdPose(const Request: TJSONObject): string;

implementation

uses
  Winapi.ActiveX,
  Winapi.Windows,
  System.IOUtils,
  System.Math,
  System.SysUtils,
  Vcl.Graphics,
  MmdAiDiagnosticModel,
  MmdAiDiagnosticOverlay,
  MmdAiPreviewFocus,
  MmdAiProviderClient,
  MmdD3DInteraction,
  MmdD3DRenderer,
  MmdD3DScene,
  PmxModel,
  PmxMorph,
  PmxPose,
  PmxPoseCodec,
  PmxReader;

const
  DEFAULT_CAPTURE_SIZE = 1024;
  MAX_CAPTURE_SIZE = 4096;
  MIN_CAPTURE_SIZE = 64;

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

function DiagnosticLegend(Pass: TMmdAiPreviewPass): TJSONObject;
begin
  Result := nil;
  if Pass in [appBones, appBoneOverlay] then
  begin
    Result := TJSONObject.Create;
    Result.AddPair('model_left_is_character_left', TJSONBool.Create(True));
    Result.AddPair('left', 'blue');
    Result.AddPair('right', 'red');
    Result.AddPair('center', 'yellow');
  end
  else if Pass = appFingerId then
  begin
    Result := TJSONObject.Create;
    Result.AddPair('thumb', 'red');
    Result.AddPair('index', 'yellow');
    Result.AddPair('middle', 'green');
    Result.AddPair('ring', 'blue');
    Result.AddPair('little', 'purple');
    Result.AddPair('other', 'gray');
    Result.AddPair('right_side_brightness', '65%');
  end
  else if Pass = appBodyOnly then
  begin
    Result := TJSONObject.Create;
    Result.AddPair('body', 'peach');
    Result.AddPair('clothing', 'excluded');
  end
  else if Pass = appSilhouette then
  begin
    Result := TJSONObject.Create;
    Result.AddPair('model', 'pale_blue');
    Result.AddPair('textures', 'excluded');
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
  if Object_ = nil then
    Exit;
  Value := Object_.GetValue(Name);
  if Value is TJSONString then
    Result := TJSONString(Value).Value;
end;

function ReadSize(const Object_: TJSONObject; const Name: string): Integer;
var
  Value: TJSONValue;
begin
  Result := DEFAULT_CAPTURE_SIZE;
  if Object_ = nil then
    Exit;
  Value := Object_.GetValue(Name);
  if Value is TJSONNumber then
    Result := TJSONNumber(Value).AsInt;
  if (Result < MIN_CAPTURE_SIZE) or (Result > MAX_CAPTURE_SIZE) then
    raise EArgumentOutOfRangeException.CreateFmt(
      '%s must be between %d and %d.', [Name, MIN_CAPTURE_SIZE,
      MAX_CAPTURE_SIZE]);
end;

function DefaultCapturePath: string;
var
  Id: TGUID;
  Name, OutputDirectory: string;
begin
  CreateGUID(Id);
  Name := GUIDToString(Id).Replace('{', '').Replace('}', '') + '.bmp';
  OutputDirectory := TPath.Combine(TPath.GetTempPath, 'MMDAIPreview');
  TDirectory.CreateDirectory(OutputDirectory);
  Result := TPath.Combine(OutputDirectory, Name);
end;

procedure ApplyCaptureView(var Camera: TMmdPreviewCamera;
  const ViewName: string);
begin
  if SameText(ViewName, 'front') then
    ApplyFixedPreviewView(Camera, fvFront, False)
  else if SameText(ViewName, 'back') then
    ApplyFixedPreviewView(Camera, fvFront, True)
  else if SameText(ViewName, 'side') then
    ApplyFixedPreviewView(Camera, fvSide, False)
  else if SameText(ViewName, 'opposite_side') then
    ApplyFixedPreviewView(Camera, fvSide, True)
  else if SameText(ViewName, 'top') then
    ApplyFixedPreviewView(Camera, fvVertical, False)
  else if SameText(ViewName, 'bottom') then
    ApplyFixedPreviewView(Camera, fvVertical, True)
  else if SameText(ViewName, 'front_left_3q') then
  begin
    Camera.Yaw := Pi * 0.25;
    Camera.Pitch := 0;
  end
  else if SameText(ViewName, 'front_right_3q') then
  begin
    Camera.Yaw := -Pi * 0.25;
    Camera.Pitch := 0;
  end
  else
    raise EArgumentException.Create(
      'view must be front, back, side, opposite_side, top, bottom, ' +
      'front_left_3q, or front_right_3q.');
end;

function BuildPreviewRequest(const Request: TJSONObject): string;
var
  Payload: TJSONValue;
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
    Payload := Request.GetValue('payload');
    if Payload <> nil then
      Preview.AddPair('payload', CloneJson(Payload));
    Result := Preview.ToJSON;
  finally
    Preview.Free;
  end;
end;

procedure LoadCapturePoses(const Model: TPmxModel; const PoseData: string;
  out Poses: TPmxBonePoses);
var
  NamedPoses: TPmxNamedBonePoses;
begin
  if not TryDecodePoseData(PoseData, NamedPoses) then
    raise EArgumentException.Create('Normalized pose_data is invalid.');
  InitializeBonePoses(Model, Poses);
  ApplyNamedBonePoses(Model, NamedPoses, Poses);
end;

procedure RenderCapture(const ModelFile, PoseData, ViewName, FocusName,
  FilePath: string;
  Pass: TMmdAiPreviewPass; Width, Height: Integer;
  out LoadedTextureCount: Integer);
var
  Bitmap: TBitmap;
  Camera: TMmdPreviewCamera;
  DiagnosticModel: TPmxModel;
  Model: TPmxModel;
  OleResult: HRESULT;
  Poses: TPmxBonePoses;
  Renderer: TMmdD3DRenderer;
  RenderModel: TPmxModel;
  Window: HWND;
begin
  OleResult := OleInitialize(nil);
  Window := CreateWindowEx(WS_EX_TOOLWINDOW, 'STATIC', 'MMDAIPreview',
    WS_POPUP, 0, 0, Width, Height, 0, 0, HInstance, nil);
  if Window = 0 then
  begin
    if OleResult >= 0 then
      OleUninitialize;
    RaiseLastOSError;
  end;
  Renderer := nil;
  Bitmap := nil;
  DiagnosticModel := nil;
  try
    Model := GetCachedPmxModel(ModelFile);
    LoadCapturePoses(Model, PoseData, Poses);
    Camera := DefaultPreviewCamera;
    ApplyCaptureView(Camera, ViewName);
    ApplyPreviewFocus(Model, Poses, FocusName, Width, Height, Camera);
    Bitmap := TBitmap.Create;
    LoadedTextureCount := 0;
    if Pass = appBones then
    begin
      ClearDiagnosticBitmap(Bitmap, Width, Height);
      DrawDiagnosticBones(Bitmap, Model, Poses, Camera);
    end
    else
    begin
      DiagnosticModel := CreateDiagnosticModel(Model, Pass, FocusName);
      if DiagnosticModel = nil then
        RenderModel := Model
      else
        RenderModel := DiagnosticModel;
      Renderer := TMmdD3DRenderer.Create(Window, Width, Height);
      if Renderer.ErrorText <> '' then
        raise Exception.Create(Renderer.ErrorText);
      Renderer.SetScene(RenderModel, Poses, nil, EmptyPreviewTarget,
        EmptyPreviewTarget);
      if Renderer.ErrorText <> '' then
        raise Exception.Create(Renderer.ErrorText);
      Renderer.SetCamera(Camera);
      if not Renderer.CaptureModelImage(Bitmap) then
        raise Exception.Create(Renderer.ErrorText);
      LoadedTextureCount := Renderer.LoadedTextureCount;
      if Pass = appBoneOverlay then
        DrawDiagnosticBones(Bitmap, Model, Poses, Camera);
    end;
    Bitmap.SaveToFile(FilePath);
  finally
    Bitmap.Free;
    Renderer.Free;
    DiagnosticModel.Free;
    DestroyWindow(Window);
    if OleResult >= 0 then
      OleUninitialize;
  end;
end;

function CaptureMmdPose(const Request: TJSONObject): string;
var
  Capture: TJSONObject;
  FilePath, FocusName, ModelFile, PassName, PoseData, PreviewText,
    ViewName: string;
  Height, LoadedTextureCount, Width: Integer;
  Image, Legend, ResultRoot: TJSONObject;
  Pass: TMmdAiPreviewPass;
  PreviewJson: TJSONValue;
  PreviewRoot: TJSONObject;
begin
  try
    ModelFile := ReadString(Request, 'model_file', '');
    if ModelFile = '' then
      Exit(ErrorJson('invalid_model_file', 'model_file is required.'));
    if not (Request.GetValue('payload') is TJSONObject) then
      Exit(ErrorJson('invalid_payload', 'payload must be an object.'));
    Capture := nil;
    if Request.GetValue('capture') is TJSONObject then
      Capture := TJSONObject(Request.GetValue('capture'));
    Width := ReadSize(Capture, 'width');
    Height := ReadSize(Capture, 'height');
    ViewName := ReadString(Capture, 'view', 'front');
    FocusName := ReadString(Capture, 'focus', 'all');
    PassName := ReadString(Capture, 'pass', 'normal');
    if not TryParsePreviewPass(PassName, Pass) then
      Exit(ErrorJson('invalid_pass', 'pass must be normal, bones, ' +
        'bone_overlay, silhouette, finger_id, or body_only.'));
    FilePath := ReadString(Capture, 'file_path', '');
    if FilePath = '' then
      FilePath := DefaultCapturePath
    else
    begin
      if not TPath.IsPathRooted(FilePath) then
        Exit(ErrorJson('invalid_file_path', 'file_path must be absolute.'));
      TDirectory.CreateDirectory(TPath.GetDirectoryName(FilePath));
    end;
    PreviewText := InvokeMmdAiProvider(BuildPreviewRequest(Request));
    PreviewJson := TJSONObject.ParseJSONValue(PreviewText);
    try
      if not (PreviewJson is TJSONObject) then
        Exit(ErrorJson('invalid_preview_response',
          'MMD provider returned invalid JSON.'));
      PreviewRoot := TJSONObject(PreviewJson);
      if not SameText(ReadString(PreviewRoot, 'status', ''), 'ok') then
        Exit(PreviewText);
      PoseData := ReadString(PreviewRoot, 'pose_data', '');
      if PoseData = '' then
        Exit(ErrorJson('missing_pose_data',
          'MMD provider did not return pose_data.'));
      RenderCapture(ModelFile, PoseData, ViewName, FocusName, FilePath, Pass,
        Width, Height, LoadedTextureCount);
      ResultRoot := TJSONObject.Create;
      try
        ResultRoot.AddPair('status', 'ok');
        ResultRoot.AddPair('extension', 'mmd.preview');
        ResultRoot.AddPair('operation', 'capture_pose');
        ResultRoot.AddPair('pose_data', PoseData);
        ResultRoot.AddPair('preview', CloneJson(PreviewRoot));
        Image := TJSONObject.Create;
        Image.AddPair('file_path', FilePath);
        Image.AddPair('format', 'bmp');
        Image.AddPair('width', TJSONNumber.Create(Width));
        Image.AddPair('height', TJSONNumber.Create(Height));
        Image.AddPair('view', ViewName);
        Image.AddPair('pass', PassName);
        Image.AddPair('focus', FocusName);
        Image.AddPair('auto_fit', TJSONBool.Create(True));
        Image.AddPair('loaded_texture_count',
          TJSONNumber.Create(LoadedTextureCount));
        Image.AddPair('file_size', TJSONNumber.Create(TFile.GetSize(FilePath)));
        ResultRoot.AddPair('image', Image);
        Legend := DiagnosticLegend(Pass);
        if Legend <> nil then
          ResultRoot.AddPair('legend', Legend);
        Result := ResultRoot.ToJSON;
      finally
        ResultRoot.Free;
      end;
    finally
      PreviewJson.Free;
    end;
  except
    on E: Exception do
      Result := ErrorJson('capture_failed', E.Message);
  end;
end;

end.
