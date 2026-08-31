unit MmdMotionObjectDragAlias;

// 選択PMXとMotionUIDの内部データから、MMDモーションScript
// オブジェクトを生成するUTF-8エイリアスを構築・保存する。

interface

// モデルファイルと版付きモーションJSONを持つオブジェクトを組み立てる。
function TryBuildMmdMotionObjectAlias(const ModelFileName,
  MotionData: string; out AliasText: string): Boolean;
// エイリアスをUTF-8 BOMなしの一時ファイルとして保存する。
function TryWriteMmdMotionObjectAlias(const ModelFileName, MotionData,
  FileName: string): Boolean;

implementation

uses
  System.Classes,
  System.IOUtils,
  System.SysUtils,
  MmdMotionDocument,
  MmdMotionDocumentCodec;

function HasLineBreak(const Value: string): Boolean;
begin
  Result := (Pos(#13, Value) > 0) or (Pos(#10, Value) > 0);
end;

function NormalizeMotionData(const Value: string; out Normalized: string;
  out FrameLength: Integer): Boolean;
var
  Document: TMmdMotionDocument;
begin
  Result := False;
  Normalized := '';
  FrameLength := 0;
  Document := nil;
  try
    if not TryDecodeMmdMotionDocument(Value, Document) then Exit;
    if Document.MaxFrame >= Cardinal(MaxInt) then Exit;
    Normalized := EncodeMmdMotionDocument(Document);
    if (Normalized = '') or HasLineBreak(Normalized) then Exit;
    FrameLength := Integer(Document.MaxFrame) + 1;
    Result := True;
  finally
    Document.Free;
  end;
end;

function TryBuildMmdMotionObjectAlias(const ModelFileName,
  MotionData: string; out AliasText: string): Boolean;
var
  FrameLength: Integer;
  Lines: TStringList;
  NormalizedMotionData: string;
begin
  Result := False;
  AliasText := '';
  if (ModelFileName = '') or HasLineBreak(ModelFileName) or
    not TFile.Exists(ModelFileName) or
    not NormalizeMotionData(MotionData, NormalizedMotionData,
      FrameLength) then Exit;
  Lines := TStringList.Create;
  try
    Lines.Add('[0]');
    Lines.Add('layer=0');
    Lines.Add('frame=0,' + IntToStr(FrameLength));
    Lines.Add('[0.0]');
    Lines.Add('effect.name=MMD' + #$30E2#$30FC#$30B7#$30E7#$30F3 +
      '@MMD_Script');
    Lines.Add(#$30E2#$30C7#$30EB#$30D5#$30A1#$30A4#$30EB + '=' +
      ModelFileName);
    Lines.Add(#$30E2#$30FC#$30B7#$30E7#$30F3#$30C7#$30FC#$30BF + '=' +
      NormalizedMotionData);
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

function TryWriteMmdMotionObjectAlias(const ModelFileName, MotionData,
  FileName: string): Boolean;
var
  AliasText: string;
  Encoding: TEncoding;
begin
  Result := False;
  if (FileName = '') or not TryBuildMmdMotionObjectAlias(ModelFileName,
    MotionData, AliasText) then Exit;
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
