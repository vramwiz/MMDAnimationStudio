unit PmxPoseCatalogDragAlias;

// PMXとポーズの選択内容から、AviUtl2へD&Dする単一モデル表示エイリアスを生成する。

interface

// モデル表示と標準描画を持つUTF-8エイリアスを組み立てる。
function TryBuildPmxPoseObjectAlias(const ModelFileName, PoseData,
  InitialExpressionData, InitialEyeBlinkData, InitialLipSyncData: string;
  out AliasText: string): Boolean;
// エイリアスをUTF-8 BOMなしの実ファイルとして保存する。
function TryWritePmxPoseObjectAlias(const ModelFileName, PoseData,
  InitialExpressionData, InitialEyeBlinkData, InitialLipSyncData,
  FileName: string): Boolean;

implementation

uses
  System.Classes,
  System.IOUtils,
  System.JSON,
  System.SysUtils,
  MmdEyeBlinkSettingCodec,
  MmdLipSyncSettingCodec,
  MmdMorphSettingCodec;

function HasLineBreak(const Value: string): Boolean;
begin
  Result := (Pos(#13, Value) > 0) or (Pos(#10, Value) > 0);
end;

function NormalizePoseData(const Value: string; out Normalized: string): Boolean;
var
  Json: TJSONValue;
begin
  Result := False;
  Normalized := '';
  Json := nil;
  try
    Json := TJSONObject.ParseJSONValue(Value);
    if not (Json is TJSONObject) then
      Exit;
    Normalized := Json.ToJSON;
    Result := not HasLineBreak(Normalized);
  finally
    Json.Free;
  end;
end;

function TryBuildPmxPoseObjectAlias(const ModelFileName, PoseData,
  InitialExpressionData, InitialEyeBlinkData, InitialLipSyncData: string;
  out AliasText: string): Boolean;
var
  EyeBlinkSetting: TMmdEyeBlinkSetting;
  FormatSettings: TFormatSettings;
  LipSyncSetting: TMmdLipSyncSetting;
  Lines: TStringList;
  NamedMorphs: TMmdNamedMorphWeights;
  NormalizedInitialExpressionData: string;
  NormalizedInitialEyeBlinkData: string;
  NormalizedInitialLipSyncData: string;
  NormalizedPoseData: string;
begin
  Result := False;
  AliasText := '';
  if (ModelFileName = '') or HasLineBreak(ModelFileName) or
    not TFile.Exists(ModelFileName) or
    not NormalizePoseData(PoseData, NormalizedPoseData) or
    not TryDecodeMmdMorphSettingData(InitialExpressionData, NamedMorphs) or
    not NormalizePoseData(InitialExpressionData,
      NormalizedInitialExpressionData) or
    not TryDecodeMmdEyeBlinkSettingData(InitialEyeBlinkData,
      EyeBlinkSetting) or
    not NormalizePoseData(InitialEyeBlinkData,
      NormalizedInitialEyeBlinkData) or
    not TryDecodeMmdLipSyncSettingData(InitialLipSyncData, LipSyncSetting) or
    not NormalizePoseData(InitialLipSyncData,
      NormalizedInitialLipSyncData) then
    Exit;

  FormatSettings := TFormatSettings.Create;
  FormatSettings.DecimalSeparator := '.';

  Lines := TStringList.Create;
  try
    Lines.Add('[0]');
    Lines.Add('layer=0');
    Lines.Add('frame=0,80');
    Lines.Add('[0.0]');
    Lines.Add('effect.name=' + #$30E2#$30C7#$30EB#$8868#$793A);
    Lines.Add(#$30E2#$30C7#$30EB#$30D5#$30A1#$30A4#$30EB + '=' +
      ModelFileName);
    Lines.Add(#$8868#$793A#$30E2#$30FC#$30C9 + '=' +
      #$6A19#$6E96);
    Lines.Add('MMD' + #$500D#$7387 + '=15.0');
    Lines.Add(#$30DD#$30FC#$30BA#$53C2#$7167#$30EC#$30A4#$30E4#$30FC +
      '=0');
    Lines.Add(#$30DD#$30FC#$30BA + '=' +
      NormalizedPoseData);
    Lines.Add(#$8A2D#$5B9A + '=');
    Lines.Add(#$8868#$60C5 + '=' +
      NormalizedInitialExpressionData);
    Lines.Add(#$76EE#$30D1#$30C1#$30C7#$30FC#$30BF + '=' +
      NormalizedInitialEyeBlinkData);
    Lines.Add(#$76EE#$30D1#$30C1#$9593#$9694 + #$FF08#$79D2#$FF09 + '=' +
      FloatToStr(EyeBlinkSetting.IntervalSec, FormatSettings));
    Lines.Add(#$76EE#$30D1#$30C1#$901F#$5EA6 + #$FF08#$79D2#$FF09 + '=' +
      FloatToStr(EyeBlinkSetting.SpeedSec, FormatSettings));
    Lines.Add(#$76EE#$30D1#$30C1#$30AA#$30D5#$30BB#$30C3#$30C8 +
      #$FF08#$79D2#$FF09 + '=' +
      FloatToStr(EyeBlinkSetting.OffsetSec, FormatSettings));
    Lines.Add(#$53E3#$30D1#$30AF#$30C7#$30FC#$30BF + '=' +
      NormalizedInitialLipSyncData);
    Lines.Add(#$53E3#$30D1#$30AF#$901F#$5EA6 + #$FF08#$79D2#$FF09 + '=' +
      FloatToStr(LipSyncSetting.SpeedSec, FormatSettings));
    Lines.Add(#$53E3#$30D1#$30AF#$5F37#$3055 + #$FF08'%'#$FF09 + '=' +
      FloatToStr(LipSyncSetting.Strength * 100, FormatSettings));
    Lines.Add(#$6BD4#$8F03#$7528#$9AA8#$683C + 'X' +
      #$305A#$3089#$3057 + '=30');
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

function TryWritePmxPoseObjectAlias(const ModelFileName, PoseData,
  InitialExpressionData, InitialEyeBlinkData, InitialLipSyncData,
  FileName: string): Boolean;
var
  AliasText: string;
  Encoding: TEncoding;
begin
  Result := False;
  if (FileName = '') or not TryBuildPmxPoseObjectAlias(ModelFileName,
    PoseData, InitialExpressionData, InitialEyeBlinkData,
    InitialLipSyncData, AliasText) then
    Exit;
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
