unit MmdAiPoseRepository;

// AIとGUIが共有するVPDポーズフォルダと、内部姿勢JSONとの変換を管理する。

interface

function GetMmdAiPoseDirectory: string;
function ConvertLegacyMmdAiPoseFiles: Integer;
function LoadMmdAiPoseFile(const FilePath: string; out PoseData: string): Boolean;
function SaveMmdAiPoseFile(const PoseName, PoseData: string): string;
procedure UpdateMmdAiPoseFile(const FilePath, PoseData: string);

implementation

uses
  System.Classes,
  System.IOUtils,
  System.JSON,
  System.SysUtils,
  PmxPose,
  PmxPoseCodec,
  MmdVpdDirectory,
  VpdPoseCodec;

function GetMmdAiPoseDirectory: string;
begin
  // 取得したパスへ直ちにアクセスできることを、この境界で保証する。
  Result := EnsureMmdVpdDirectory;
end;

function MakeSafeFileName(const Value: string): string;
var
  C: Char;
  InvalidChars: TArray<Char>;
begin
  Result := Trim(Value);
  InvalidChars := TPath.GetInvalidFileNameChars;
  for C in InvalidChars do
    Result := Result.Replace(C, '_');
  while (Result <> '') and CharInSet(Result[Length(Result)], [' ', '.']) do
    Delete(Result, Length(Result), 1);
  if Result = '' then
    Result := 'pose';
  if SameText(Result, 'CON') or SameText(Result, 'PRN') or
     SameText(Result, 'AUX') or SameText(Result, 'NUL') or
     SameText(Copy(Result, 1, 3), 'COM') or
     SameText(Copy(Result, 1, 3), 'LPT') then
    Result := '_' + Result;
end;

function NewPoseFilePath(const PoseName: string): string;
var
  BaseName: string;
  Number: Integer;
begin
  BaseName := MakeSafeFileName(PoseName);
  Result := TPath.Combine(GetMmdAiPoseDirectory, BaseName + '.vpd');
  Number := 2;
  while TFile.Exists(Result) do
  begin
    Result := TPath.Combine(GetMmdAiPoseDirectory,
      Format('%s-%d.vpd', [BaseName, Number]));
    Inc(Number);
  end;
end;

function ReadVpdText(const FilePath: string): string;
var
  Bytes: TBytes;
  Encoding: TEncoding;
begin
  Bytes := TFile.ReadAllBytes(FilePath);
  if (Length(Bytes) >= 3) and (Bytes[0] = $EF) and (Bytes[1] = $BB) and
    (Bytes[2] = $BF) then
    Exit(TEncoding.UTF8.GetString(Bytes, 3, Length(Bytes) - 3));
  Encoding := TEncoding.GetEncoding(932);
  try
    Result := Encoding.GetString(Bytes);
  finally
    Encoding.Free;
  end;
end;

procedure WriteVpdText(const FilePath, Text: string);
var
  Bytes: TBytes;
  Encoding: TEncoding;
begin
  Encoding := TEncoding.GetEncoding(932);
  try
    Bytes := Encoding.GetBytes(Text);
  finally
    Encoding.Free;
  end;
  TFile.WriteAllBytes(FilePath, Bytes);
end;

function LoadMmdAiPoseFile(const FilePath: string;
  out PoseData: string): Boolean;
var
  Poses: TPmxNamedBonePoses;
begin
  PoseData := '';
  Result := TryDecodeVpdPose(ReadVpdText(FilePath), Poses);
  if Result then
    PoseData := EncodePoseData(Poses);
end;

function SaveMmdAiPoseFile(const PoseName, PoseData: string): string;
begin
  Result := NewPoseFilePath(PoseName);
  UpdateMmdAiPoseFile(Result, PoseData);
end;

procedure UpdateMmdAiPoseFile(const FilePath, PoseData: string);
var
  Poses: TPmxNamedBonePoses;
begin
  if PoseData = '' then
    raise EArgumentException.Create('pose_data must not be empty.');
  if FilePath = '' then
    raise EArgumentException.Create('file path must not be empty.');
  if not SameText(TPath.GetExtension(FilePath), '.vpd') then
    raise EArgumentException.Create('pose file extension must be .vpd.');
  if not TryDecodePoseData(PoseData, Poses) then
    raise EArgumentException.Create('pose_data must be mmd.pose version 1.');
  TDirectory.CreateDirectory(TPath.GetDirectoryName(FilePath));
  WriteVpdText(FilePath, EncodeVpdPose('MMDAIPreview', Poses));
end;

function ReadJsonString(const Object_: TJSONObject; const Name: string): string;
var
  Value: TJSONValue;
begin
  Result := '';
  Value := Object_.GetValue(Name);
  if Value is TJSONString then
    Result := TJSONString(Value).Value;
end;

function ConvertLegacyMmdAiPoseFiles: Integer;
var
  FilePath, PoseData, VpdPath, VerifiedData: string;
  Files: TArray<string>;
  RootValue: TJSONValue;
begin
  Result := 0;
  Files := TDirectory.GetFiles(GetMmdAiPoseDirectory, '*.json');
  for FilePath in Files do
  begin
    VpdPath := ChangeFileExt(FilePath, '.vpd');
    if TFile.Exists(VpdPath) then
      Continue;
    RootValue := TJSONObject.ParseJSONValue(
      TFile.ReadAllText(FilePath, TEncoding.UTF8));
    try
      if not (RootValue is TJSONObject) then
        raise EArgumentException.CreateFmt('Legacy pose is not a JSON object: %s',
          [FilePath]);
      PoseData := ReadJsonString(TJSONObject(RootValue), 'pose_data');
      if PoseData = '' then
        raise EArgumentException.CreateFmt('Legacy pose has no pose_data: %s',
          [FilePath]);
      UpdateMmdAiPoseFile(VpdPath, PoseData);
      if not LoadMmdAiPoseFile(VpdPath, VerifiedData) then
      begin
        TFile.Delete(VpdPath);
        raise EInvalidOperation.CreateFmt('Converted VPD verification failed: %s',
          [VpdPath]);
      end;
      Inc(Result);
    finally
      RootValue.Free;
    end;
  end;
end;

end.
