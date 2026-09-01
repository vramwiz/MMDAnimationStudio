unit MmdAccessoryObjectDragAlias;

// 登録済みPMX／OBJからアクセサリ表示と標準描画を持つエイリアスを生成する。

interface

// モデルファイルを持つUTF-8エイリアス文字列を組み立てる。
function TryBuildMmdAccessoryObjectAlias(const ModelFileName: string;
  out AliasText: string): Boolean;
// エイリアスをBOMなしUTF-8の一時ファイルへ保存する。
function TryWriteMmdAccessoryObjectAlias(const ModelFileName,
  FileName: string): Boolean;

implementation

uses
  System.Classes,
  System.IOUtils,
  System.SysUtils;

function HasLineBreak(const Value: string): Boolean;
begin
  Result := (Pos(#13, Value) > 0) or (Pos(#10, Value) > 0);
end;

function TryBuildMmdAccessoryObjectAlias(const ModelFileName: string;
  out AliasText: string): Boolean;
var
  Lines: TStringList;
begin
  Result := False;
  AliasText := '';
  if (ModelFileName = '') or HasLineBreak(ModelFileName) or
    not TFile.Exists(ModelFileName) then Exit;
  Lines := TStringList.Create;
  try
    Lines.Add('[0]');
    Lines.Add('layer=0');
    Lines.Add('frame=0,80');
    Lines.Add('[0.0]');
    Lines.Add('effect.name=' + #$30A2#$30AF#$30BB#$30B5#$30EA);
    Lines.Add(#$30E2#$30C7#$30EB#$30D5#$30A1#$30A4#$30EB + '=' +
      ModelFileName);
    Lines.Add('MMD' + #$500D#$7387 + '=15.0');
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

function TryWriteMmdAccessoryObjectAlias(const ModelFileName,
  FileName: string): Boolean;
var
  AliasText: string;
  Encoding: TEncoding;
begin
  Result := False;
  if (FileName = '') or not TryBuildMmdAccessoryObjectAlias(ModelFileName,
    AliasText) then Exit;
  try
    ForceDirectories(TPath.GetDirectoryName(FileName));
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
