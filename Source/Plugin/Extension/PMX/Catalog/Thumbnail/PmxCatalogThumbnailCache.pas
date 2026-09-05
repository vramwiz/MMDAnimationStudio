unit PmxCatalogThumbnailCache;

// PMX本体の更新状態と画像寸法を含むキーでPNGサムネイルを管理する。

interface

uses
  Vcl.Graphics;

type
  TPmxCatalogThumbnailCache = class
  private
    FFolder: string;
    function CacheFileName(const PmxFileName, VariantKey: string; Width,
      Height: Integer): string;
  public
    // 指定フォルダをこのキャッシュインスタンスのPNG保存先として設定する。
    constructor Create(const AFolder: string);
    // このキャッシュ領域のPNGを全て削除する。
    function Clear: Boolean;
    // PMX更新状態と寸法が一致する標準サムネイルを読み込む。
    function Load(const PmxFileName: string; Width, Height: Integer;
      Bitmap: TBitmap): Boolean;
    // PMX更新状態と寸法を含むキーで標準サムネイルを保存する。
    function Save(const PmxFileName: string; Width, Height: Integer;
      Bitmap: TBitmap): Boolean;
    // ポーズ等のVariantKeyを加えたサムネイルを読み込む。
    function LoadVariant(const PmxFileName, VariantKey: string; Width,
      Height: Integer; Bitmap: TBitmap): Boolean;
    // ポーズ等のVariantKeyを加えたサムネイルを保存する。
    function SaveVariant(const PmxFileName, VariantKey: string; Width,
      Height: Integer; Bitmap: TBitmap): Boolean;
  end;

implementation

uses
  Winapi.Windows,
  System.Hash,
  System.IOUtils,
  System.SysUtils,
  Vcl.Imaging.pngimage;

const
  // v2: 材質モーフを反映したサムネイル。v1画像を再利用しない。
  ThumbnailFormatVersion = 2;

function FileIdentity(const FileName: string): string;
var
  Data: WIN32_FILE_ATTRIBUTE_DATA;
  FileSize: UInt64;
  ModifiedTime: UInt64;
begin
  Result := '';
  if not GetFileAttributesEx(PChar(FileName), GetFileExInfoStandard,
    @Data) then
    Exit;
  ModifiedTime := UInt64(Data.ftLastWriteTime.dwHighDateTime) shl 32 or
    Data.ftLastWriteTime.dwLowDateTime;
  FileSize := UInt64(Data.nFileSizeHigh) shl 32 or Data.nFileSizeLow;
  Result := IntToHex(ModifiedTime, 16) + '-' + IntToHex(FileSize, 16);
end;

constructor TPmxCatalogThumbnailCache.Create(const AFolder: string);
begin
  inherited Create;
  FFolder := IncludeTrailingPathDelimiter(AFolder);
end;

function TPmxCatalogThumbnailCache.Clear: Boolean;
var
  FileName: string;
begin
  Result := True;
  if not TDirectory.Exists(FFolder) then
    Exit;
  try
    for FileName in TDirectory.GetFiles(FFolder, '*.png',
      TSearchOption.soTopDirectoryOnly) do
      try
        TFile.Delete(FileName);
      except
        Result := False;
      end;
  except
    Result := False;
  end;
end;

function TPmxCatalogThumbnailCache.CacheFileName(const PmxFileName,
  VariantKey: string; Width, Height: Integer): string;
var
  Key: string;
begin
  Result := '';
  Key := FileIdentity(PmxFileName);
  if Key = '' then
    Exit;
  Key := LowerCase(TPath.GetFullPath(PmxFileName)) + '|' + Key + '|' +
    VariantKey + '|' +
    IntToStr(Width) + 'x' + IntToStr(Height) + '|v' +
    IntToStr(ThumbnailFormatVersion);
  Result := FFolder + THashSHA2.GetHashString(Key) + '.png';
end;

function TPmxCatalogThumbnailCache.Load(const PmxFileName: string; Width,
  Height: Integer; Bitmap: Vcl.Graphics.TBitmap): Boolean;
begin
  Result := LoadVariant(PmxFileName, '', Width, Height, Bitmap);
end;

function TPmxCatalogThumbnailCache.LoadVariant(const PmxFileName,
  VariantKey: string; Width, Height: Integer;
  Bitmap: Vcl.Graphics.TBitmap): Boolean;
var
  FileName: string;
  Png: TPngImage;
begin
  Result := False;
  if Bitmap = nil then
    Exit;
  try
    FileName := CacheFileName(PmxFileName, VariantKey, Width, Height);
    if (FileName = '') or not TFile.Exists(FileName) then
      Exit;
    Png := TPngImage.Create;
    try
      Png.LoadFromFile(FileName);
      Bitmap.Assign(Png);
      Result := True;
    finally
      Png.Free;
    end;
  except
    Result := False;
  end;
end;

function TPmxCatalogThumbnailCache.Save(const PmxFileName: string; Width,
  Height: Integer; Bitmap: Vcl.Graphics.TBitmap): Boolean;
begin
  Result := SaveVariant(PmxFileName, '', Width, Height, Bitmap);
end;

function TPmxCatalogThumbnailCache.SaveVariant(const PmxFileName,
  VariantKey: string; Width, Height: Integer;
  Bitmap: Vcl.Graphics.TBitmap): Boolean;
var
  FileName: string;
  Png: TPngImage;
begin
  Result := False;
  if (Bitmap = nil) or Bitmap.Empty then
    Exit;
  try
    FileName := CacheFileName(PmxFileName, VariantKey, Width, Height);
    if FileName = '' then
      Exit;
    if not ForceDirectories(FFolder) then
      Exit;
    Png := TPngImage.Create;
    try
      Png.Assign(Bitmap);
      Png.SaveToFile(FileName);
      Result := True;
    finally
      Png.Free;
    end;
  except
    Result := False;
  end;
end;

end.
