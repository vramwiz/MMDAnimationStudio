unit PmxMotionCatalogItem;

// MotionUID別に保存するPMXとの関連、VMD原本参照、代表フレーム姿勢を定義する。

interface

const
  PmxMotionCatalogFormatVersion = 1;

type
  TPmxMotionCatalogItem = class
  private
    FFirstFrame: Cardinal;
    FId: string;
    FName: string;
    FPmxId: string;
    FPmxName: string;
    FPreviewMorphData: string;
    FPreviewPoseData: string;
    FSourceCategoryName: string;
    FSourceVmdId: string;
    FSourceVmdName: string;
  public
    property FirstFrame: Cardinal read FFirstFrame write FFirstFrame;
    property Id: string read FId write FId;
    property Name: string read FName write FName;
    property PmxId: string read FPmxId write FPmxId;
    property PmxName: string read FPmxName write FPmxName;
    property PreviewMorphData: string read FPreviewMorphData write FPreviewMorphData;
    property PreviewPoseData: string read FPreviewPoseData write FPreviewPoseData;
    property SourceCategoryName: string read FSourceCategoryName write FSourceCategoryName;
    property SourceVmdId: string read FSourceVmdId write FSourceVmdId;
    property SourceVmdName: string read FSourceVmdName write FSourceVmdName;
  end;

implementation

end.
