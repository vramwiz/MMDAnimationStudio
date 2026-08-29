unit PmxCatalogItem;

// PMXカタログが保持する、PmxUID・表示名・元ファイルパスのデータ型を定義する。

interface

type
  TPmxCatalogItem = class
  private
    FDisplayName: string;
    FId: string;
    FSourcePath: string;
  public
    property DisplayName: string read FDisplayName write FDisplayName;
    property Id: string read FId write FId;
    property SourcePath: string read FSourcePath write FSourcePath;
  end;

implementation

end.
