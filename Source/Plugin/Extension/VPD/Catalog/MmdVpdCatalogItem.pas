unit MmdVpdCatalogItem;

// 共通VPDライブラリのVpdUID別メタデータを定義する。

interface

type
  TMmdVpdCatalogItem = class
  private
    FCategoryName: string;
    FContentHash: string;
    FId: string;
    FImportedAt: string;
    FName: string;
    FOriginalFileName: string;
    FOriginalPath: string;
  public
    property CategoryName: string read FCategoryName write FCategoryName;
    property ContentHash: string read FContentHash write FContentHash;
    property Id: string read FId write FId;
    property ImportedAt: string read FImportedAt write FImportedAt;
    property Name: string read FName write FName;
    property OriginalFileName: string read FOriginalFileName
      write FOriginalFileName;
    property OriginalPath: string read FOriginalPath write FOriginalPath;
  end;

implementation

end.
