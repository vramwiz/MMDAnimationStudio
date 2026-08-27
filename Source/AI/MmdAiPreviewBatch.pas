unit MmdAiPreviewBatch;

// 複数視点・診断パス・注目対象の組合せを一要求でBMPへ出力する。

interface

uses
  System.JSON;

function CaptureMmdPoseSet(const Request: TJSONObject): string;

implementation

uses
  System.Generics.Collections,
  System.IOUtils,
  System.SysUtils,
  MmdAiPreviewCapture;

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
  if Object_ = nil then
    Exit;
  Value := Object_.GetValue(Name);
  if Value is TJSONString then
    Result := TJSONString(Value).Value;
end;

function ReadNames(const Capture: TJSONObject; const Name,
  DefaultValue: string): TArray<string>;
var
  Array_: TJSONArray;
  Index: Integer;
  Value: TJSONValue;
begin
  Value := nil;
  if Capture <> nil then
    Value := Capture.GetValue(Name);
  if Value = nil then
  begin
    SetLength(Result, 1);
    Result[0] := DefaultValue;
    Exit;
  end;
  if not (Value is TJSONArray) then
    raise EArgumentException.CreateFmt('%s must be an array.', [Name]);
  Array_ := TJSONArray(Value);
  if Array_.Count = 0 then
    raise EArgumentException.CreateFmt('%s must not be empty.', [Name]);
  SetLength(Result, Array_.Count);
  for Index := 0 to Array_.Count - 1 do
  begin
    if not (Array_.Items[Index] is TJSONString) then
      raise EArgumentException.CreateFmt('%s entries must be strings.', [Name]);
    Result[Index] := TJSONString(Array_.Items[Index]).Value;
  end;
end;

function SafeFilePart(const Value: string): string;
var
  Ch: Char;
begin
  Result := '';
  for Ch in Value do
    if CharInSet(Ch, ['a'..'z', 'A'..'Z', '0'..'9', '-', '_']) then
      Result := Result + Ch
    else
      Result := Result + '_';
  if Result = '' then
    Result := 'capture';
end;

function BuildSingleRequest(const Request, SetCapture: TJSONObject;
  const ViewName, PassName, FocusName, FilePath: string): TJSONObject;
var
  Capture: TJSONObject;
  Value: TJSONValue;
begin
  Result := TJSONObject.Create;
  Result.AddPair('operation', 'capture_pose');
  Value := Request.GetValue('model_file');
  if Value <> nil then
    Result.AddPair('model_file', CloneJson(Value));
  Value := Request.GetValue('current_pose');
  if Value <> nil then
    Result.AddPair('current_pose', CloneJson(Value));
  Value := Request.GetValue('payload');
  if Value <> nil then
    Result.AddPair('payload', CloneJson(Value));
  Capture := TJSONObject.Create;
  Value := SetCapture.GetValue('width');
  if Value <> nil then
    Capture.AddPair('width', CloneJson(Value));
  Value := SetCapture.GetValue('height');
  if Value <> nil then
    Capture.AddPair('height', CloneJson(Value));
  Capture.AddPair('view', ViewName);
  Capture.AddPair('pass', PassName);
  Capture.AddPair('focus', FocusName);
  Capture.AddPair('file_path', FilePath);
  Result.AddPair('capture', Capture);
end;

function CaptureMmdPoseSet(const Request: TJSONObject): string;
var
  Capture: TJSONObject;
  FileName, FocusName, OutputDirectory, PassName, Prefix: string;
  Focuses, Passes, Views: TArray<string>;
  FocusIndex, PassIndex, ViewIndex: Integer;
  ImageValue, ResponseValue: TJSONValue;
  Images: TJSONArray;
  ResultRoot, SingleRequest, SingleResponse: TJSONObject;
begin
  try
    if not (Request.GetValue('capture') is TJSONObject) then
      Exit(ErrorJson('invalid_capture', 'capture must be an object.'));
    Capture := TJSONObject(Request.GetValue('capture'));
    OutputDirectory := ReadString(Capture, 'output_directory', '');
    if (OutputDirectory = '') or not TPath.IsPathRooted(OutputDirectory) then
      Exit(ErrorJson('invalid_output_directory',
        'capture.output_directory must be an absolute path.'));
    TDirectory.CreateDirectory(OutputDirectory);
    Prefix := SafeFilePart(ReadString(Capture, 'file_prefix', 'pose'));
    Views := ReadNames(Capture, 'views', 'front');
    Passes := ReadNames(Capture, 'passes', 'normal');
    Focuses := ReadNames(Capture, 'focuses', 'all');
    Images := TJSONArray.Create;
    ResultRoot := TJSONObject.Create;
    try
      for FocusIndex := 0 to High(Focuses) do
        for ViewIndex := 0 to High(Views) do
          for PassIndex := 0 to High(Passes) do
          begin
            FocusName := Focuses[FocusIndex];
            PassName := Passes[PassIndex];
            FileName := Format('%s-%s-%s-%s.bmp', [Prefix,
              SafeFilePart(FocusName), SafeFilePart(Views[ViewIndex]),
              SafeFilePart(PassName)]);
            SingleRequest := BuildSingleRequest(Request, Capture,
              Views[ViewIndex], PassName, FocusName,
              TPath.Combine(OutputDirectory, FileName));
            try
              ResponseValue := TJSONObject.ParseJSONValue(
                CaptureMmdPose(SingleRequest));
              try
                if not (ResponseValue is TJSONObject) then
                  raise Exception.Create('capture_pose returned invalid JSON.');
                SingleResponse := TJSONObject(ResponseValue);
                if not SameText(ReadString(SingleResponse, 'status', ''), 'ok') then
                  Exit(SingleResponse.ToJSON);
                if ResultRoot.GetValue('pose_data') = nil then
                begin
                  ResultRoot.AddPair('pose_data',
                    ReadString(SingleResponse, 'pose_data', ''));
                  ImageValue := SingleResponse.GetValue('preview');
                  if ImageValue <> nil then
                    ResultRoot.AddPair('preview', CloneJson(ImageValue));
                end;
                ImageValue := SingleResponse.GetValue('image');
                Images.AddElement(CloneJson(ImageValue));
              finally
                ResponseValue.Free;
              end;
            finally
              SingleRequest.Free;
            end;
          end;
      ResultRoot.AddPair('status', 'ok');
      ResultRoot.AddPair('extension', 'mmd.preview');
      ResultRoot.AddPair('operation', 'capture_pose_set');
      ResultRoot.AddPair('image_count', TJSONNumber.Create(Images.Count));
      ResultRoot.AddPair('images', Images);
      Images := nil;
      Result := ResultRoot.ToJSON;
    finally
      Images.Free;
      ResultRoot.Free;
    end;
  except
    on E: Exception do
      Result := ErrorJson('capture_set_failed', E.Message);
  end;
end;

end.
