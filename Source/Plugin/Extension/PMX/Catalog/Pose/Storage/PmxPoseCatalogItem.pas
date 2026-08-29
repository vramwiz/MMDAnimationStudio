unit PmxPoseCatalogItem;

// PoseUID別に保存する姿勢・初期表情・目パチ・口パク設定のデータ型を定義する。

interface

const
  PmxPoseCatalogFormatVersion = 6;

type
  TPmxPoseCatalogItem = class
  private
    FId: string;
    FInitialEyeBlinkData: string;
    FInitialExpressionData: string;
    FInitialLipSyncData: string;
    FKind: string;
    FName: string;
    FPmxId: string;
    FPmxName: string;
    FPoseData: string;
    FSourceCategoryName: string;
    FSourceVpdId: string;
    FSourceVpdName: string;
  public
    property Id: string read FId write FId;
    property InitialEyeBlinkData: string read FInitialEyeBlinkData write FInitialEyeBlinkData;
    property InitialExpressionData: string read FInitialExpressionData write FInitialExpressionData;
    property InitialLipSyncData: string read FInitialLipSyncData write FInitialLipSyncData;
    property Kind: string read FKind write FKind;
    property Name: string read FName write FName;
    property PmxId: string read FPmxId write FPmxId;
    property PmxName: string read FPmxName write FPmxName;
    property PoseData: string read FPoseData write FPoseData;
    property SourceCategoryName: string read FSourceCategoryName
      write FSourceCategoryName;
    property SourceVpdId: string read FSourceVpdId write FSourceVpdId;
    property SourceVpdName: string read FSourceVpdName write FSourceVpdName;
  end;

implementation

end.
