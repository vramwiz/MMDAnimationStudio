unit MmdAiPoseRepository;

// AIとGUIが共有する、Git同期可能なポーズJSONフォルダを管理する。

interface

function GetMmdAiPoseDirectory: string;
function SaveMmdAiPoseFile(const PoseName, CandidateId,
  PoseData: string): string;
procedure UpdateMmdAiPoseFile(const FilePath, PoseName, CandidateId,
  PoseData: string);

implementation

uses
  System.IOUtils,
  System.JSON,
  System.SysUtils;

function GetMmdAiPoseDirectory: string;
begin
  Result := TPath.Combine(ExtractFilePath(ParamStr(0)), 'Poses');
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
  Result := TPath.Combine(GetMmdAiPoseDirectory, BaseName + '.json');
  Number := 2;
  while TFile.Exists(Result) do
  begin
    Result := TPath.Combine(GetMmdAiPoseDirectory,
      Format('%s-%d.json', [BaseName, Number]));
    Inc(Number);
  end;
end;

function SaveMmdAiPoseFile(const PoseName, CandidateId,
  PoseData: string): string;
begin
  TDirectory.CreateDirectory(GetMmdAiPoseDirectory);
  Result := NewPoseFilePath(PoseName);
  UpdateMmdAiPoseFile(Result, PoseName, CandidateId, PoseData);
end;

procedure UpdateMmdAiPoseFile(const FilePath, PoseName, CandidateId,
  PoseData: string);
var
  Root: TJSONObject;
begin
  if PoseData = '' then
    raise EArgumentException.Create('pose_data must not be empty.');
  if FilePath = '' then
    raise EArgumentException.Create('file path must not be empty.');
  TDirectory.CreateDirectory(TPath.GetDirectoryName(FilePath));
  Root := TJSONObject.Create;
  try
    Root.AddPair('format', 'mmd-ai-preview-pose');
    Root.AddPair('version', TJSONNumber.Create(1));
    Root.AddPair('name', PoseName);
    if CandidateId <> '' then
      Root.AddPair('candidate_id', CandidateId);
    Root.AddPair('pose_data', PoseData);
    TFile.WriteAllText(FilePath, Root.Format(2), TEncoding.UTF8);
  finally
    Root.Free;
  end;
end;

end.
