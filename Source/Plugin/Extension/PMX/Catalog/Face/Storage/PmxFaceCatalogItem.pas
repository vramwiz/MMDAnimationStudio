unit PmxFaceCatalogItem;

// FaceUID別に保存するPMX固有の表情モーフ設定を定義する。

interface

const
  PmxFaceCatalogFormatVersion = 1;

type
  TPmxFaceCatalogItem = class
  private
    FFaceData: string;
    FId: string;
    FKind: string;
    FName: string;
    FPmxId: string;
    FPmxName: string;
  public
    // FaceUID項目として永続化する表情JSON、識別情報、表示名、所属PMX情報を保持する。
    property FaceData: string read FFaceData write FFaceData;
    property Id: string read FId write FId;
    property Kind: string read FKind write FKind;
    property Name: string read FName write FName;
    property PmxId: string read FPmxId write FPmxId;
    property PmxName: string read FPmxName write FPmxName;
  end;

implementation

end.

