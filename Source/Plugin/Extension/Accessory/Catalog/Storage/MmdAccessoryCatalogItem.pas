unit MmdAccessoryCatalogItem;

// アクセサリ原本と一覧項目を別UIDで保持する永続化データ型を定義する。

interface

type
  TMmdAccessorySourceFormat = (asfPmx, asfObj);

  TMmdAccessorySourceItem = class
  private
    FBoneCount: Integer;
    FContentHash: string;
    FFormat: TMmdAccessorySourceFormat;
    FId: string;
    FImportedAt: string;
    FMaterialCount: Integer;
    FOriginalFileName: string;
    FOriginalPath: string;
    FValidated: Boolean;
    FVertexCount: Integer;
  public
    // Readerで未検査の件数を-1として原本メタデータを初期化する。
    constructor Create;
    // 内容ハッシュ、元ファイル情報、形式Readerの検査結果を永続化する。
    property BoneCount: Integer read FBoneCount write FBoneCount;
    property ContentHash: string read FContentHash write FContentHash;
    property Format: TMmdAccessorySourceFormat read FFormat write FFormat;
    property Id: string read FId write FId;
    property ImportedAt: string read FImportedAt write FImportedAt;
    property MaterialCount: Integer read FMaterialCount write FMaterialCount;
    property OriginalFileName: string read FOriginalFileName
      write FOriginalFileName;
    property OriginalPath: string read FOriginalPath write FOriginalPath;
    property Validated: Boolean read FValidated write FValidated;
    property VertexCount: Integer read FVertexCount write FVertexCount;
  end;

  TMmdAccessoryCatalogItem = class
  private
    FCategoryName: string;
    FId: string;
    FName: string;
    FSourceId: string;
  public
    // 一覧固有のUID、表示名、分類名と、共有原本のSourceUIDを保持する。
    property CategoryName: string read FCategoryName write FCategoryName;
    property Id: string read FId write FId;
    property Name: string read FName write FName;
    property SourceId: string read FSourceId write FSourceId;
  end;

// 保存形式名をJSON用の小文字文字列へ変換する。
function MmdAccessorySourceFormatName(
  Value: TMmdAccessorySourceFormat): string;
// 拡張子または保存形式名を対応形式へ変換し、未対応値ではFalseを返す。
function TryMmdAccessorySourceFormat(const Value: string;
  out Format: TMmdAccessorySourceFormat): Boolean;
// 原本コピーに使用するドット付き標準拡張子を返す。
function MmdAccessorySourceExtension(
  Value: TMmdAccessorySourceFormat): string;

implementation

uses
  System.SysUtils;

constructor TMmdAccessorySourceItem.Create;
begin
  inherited;
  FBoneCount := -1;
  FMaterialCount := -1;
  FVertexCount := -1;
end;

function MmdAccessorySourceExtension(
  Value: TMmdAccessorySourceFormat): string;
begin
  Result := '.' + MmdAccessorySourceFormatName(Value);
end;

function MmdAccessorySourceFormatName(
  Value: TMmdAccessorySourceFormat): string;
begin
  case Value of
    asfObj: Result := 'obj';
  else
    Result := 'pmx';
  end;
end;

function TryMmdAccessorySourceFormat(const Value: string;
  out Format: TMmdAccessorySourceFormat): Boolean;
var
  Normalized: string;
begin
  Normalized := LowerCase(Trim(Value));
  if Normalized.StartsWith('.') then Delete(Normalized, 1, 1);
  Result := True;
  if Normalized = 'pmx' then Format := asfPmx
  else if Normalized = 'obj' then Format := asfObj
  else Result := False;
end;

end.
