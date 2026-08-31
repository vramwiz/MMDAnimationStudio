unit MmdPoseObjectDragAlias;

// 選択PMXとポーズから、AviUtl2の単一ポーズオブジェクトを生成する
// UTF-8エイリアスを構築・保存する。

interface

// モデルファイルと姿勢JSONを持つポーズオブジェクトを組み立てる。
function TryBuildMmdPoseObjectAlias(const ModelFileName, PoseData: string;
  out AliasText: string): Boolean;
// エイリアスをUTF-8 BOMなしの一時ファイルとして保存する。
function TryWriteMmdPoseObjectAlias(const ModelFileName, PoseData,
  FileName: string): Boolean;

implementation

uses
  System.Classes,
  System.IOUtils,
  System.JSON,
  System.SysUtils,
  PmxPose,
  PmxPoseCodec;

function HasLineBreak(const Value: string): Boolean;
begin
  Result := (Pos(#13, Value) > 0) or (Pos(#10, Value) > 0);
end;

function NormalizePoseData(const Value: string;
  out Normalized: string): Boolean;
var
  Json: TJSONValue;
  Poses: TPmxNamedBonePoses;
begin
  Result := False;
  Normalized := '';
  if not TryDecodePoseData(Value, Poses) then Exit;
  Json := TJSONObject.ParseJSONValue(Value);
  try
    if not (Json is TJSONObject) then Exit;
    Normalized := Json.ToJSON;
    Result := not HasLineBreak(Normalized);
  finally
    Json.Free;
  end;
end;

function TryBuildMmdPoseObjectAlias(const ModelFileName, PoseData: string;
  out AliasText: string): Boolean;
var
  Lines: TStringList;
  NormalizedPoseData: string;
begin
  Result := False;
  AliasText := '';
  if (ModelFileName = '') or HasLineBreak(ModelFileName) or
    not TFile.Exists(ModelFileName) or
    not NormalizePoseData(PoseData, NormalizedPoseData) then Exit;
  Lines := TStringList.Create;
  try
    Lines.Add('[0]');
    Lines.Add('layer=0');
    Lines.Add('frame=0,80');
    Lines.Add('[0.0]');
    Lines.Add('effect.name=' + #$30DD#$30FC#$30BA);
    Lines.Add(#$30E2#$30C7#$30EB#$30D5#$30A1#$30A4#$30EB + '=' +
      ModelFileName);
    Lines.Add(#$30DD#$30FC#$30BA#$30C7#$30FC#$30BF + '=' +
      NormalizedPoseData);
    Lines.Add(#$8A2D#$5B9A + '=');
    Lines.Add('[0.1]');
    Lines.Add('effect.name=' + #$6A19#$6E96#$63CF#$753B);
    Lines.Add('X=0.00');
    Lines.Add('Y=0.00');
    Lines.Add('Z=0.00');
    Lines.Add('Group=1');
    Lines.Add(#$4E2D#$5FC3 + 'X=0.00');
    Lines.Add(#$4E2D#$5FC3 + 'Y=0.00');
    Lines.Add(#$4E2D#$5FC3 + 'Z=0.00');
    Lines.Add('Group3=1');
    Lines.Add('X' + #$8EF8#$56DE#$8EE2 + '=0.00');
    Lines.Add('Y' + #$8EF8#$56DE#$8EE2 + '=0.00');
    Lines.Add('Z' + #$8EF8#$56DE#$8EE2 + '=0.00');
    Lines.Add('Group2=1');
    Lines.Add(#$62E1#$5927#$7387 + '=100.000');
    Lines.Add(#$7E26#$6A2A#$6BD4 + '=0.000');
    Lines.Add(#$900F#$660E#$5EA6 + '=0.00');
    Lines.Add(#$5408#$6210#$30E2#$30FC#$30C9 + '=' + #$901A#$5E38);
    AliasText := Lines.Text;
    Result := True;
  finally
    Lines.Free;
  end;
end;

function TryWriteMmdPoseObjectAlias(const ModelFileName, PoseData,
  FileName: string): Boolean;
var
  AliasText: string;
  Encoding: TEncoding;
begin
  Result := False;
  if (FileName = '') or not TryBuildMmdPoseObjectAlias(ModelFileName,
    PoseData, AliasText) then Exit;
  try
    ForceDirectories(ExtractFilePath(FileName));
    Encoding := TUTF8Encoding.Create(False);
    try
      TFile.WriteAllText(FileName, AliasText, Encoding);
      Result := TFile.Exists(FileName);
    finally
      Encoding.Free;
    end;
  except
    Result := False;
  end;
end;

end.
