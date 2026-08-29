unit PmxPoseCatalogDragController;

// ポーズ一覧のD&D開始判定、AviUtl2用エイリアス生成、一時ファイル破棄を担当する。

interface

uses
  System.Classes,
  Vcl.Controls,
  DragAgent,
  PmxCatalogStorage,
  PmxCatalogListView,
  PmxPoseCatalogStorage,
  PmxPoseCatalogListView;

type
  TPmxPoseCatalogDragController = class
  private
    FAliasFileName: string;
    FCatalog: TPmxCatalogStorage;
    FCatalogList: TPmxCatalogListView;
    FDrag: TDragShellFile;
    FPoseCatalog: TPmxPoseCatalogStorage;
    FPoseList: TPmxPoseCatalogListView;
    function CanStart(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer): Boolean;
    procedure DragRequest(Sender: TObject; FileNames: TStringList);
  public
    // 一覧へドラッグ処理を接続し、インスタンス固有の一時エイリアス名を確保する。
    constructor Create(AOwner: TComponent; ACatalogList: TPmxCatalogListView;
      APoseList: TPmxPoseCatalogListView);
    // 一覧との接続を解除し、生成済みの一時エイリアスを可能な範囲で削除する。
    destructor Destroy; override;
    // 現在選択中のPMXカタログとポーズカタログを次回D&Dの入力へ設定する。
    procedure SetData(ACatalog: TPmxCatalogStorage;
      APoseCatalog: TPmxPoseCatalogStorage);
  end;

implementation

uses
  System.IOUtils,
  System.SysUtils,
  System.Types,
  AppFolderUtils,
  PmxPoseCatalogDragAlias;

constructor TPmxPoseCatalogDragController.Create(AOwner: TComponent;
  ACatalogList: TPmxCatalogListView; APoseList: TPmxPoseCatalogListView);
begin
  inherited Create;
  FCatalogList := ACatalogList;
  FPoseList := APoseList;
  FAliasFileName := GetAppFolder('Temp') + 'PmxPose-' +
    IntToHex(NativeUInt(Self), SizeOf(Pointer) * 2) + '.object';
  FDrag := TDragShellFile.Create(AOwner);
  FDrag.Attach(FPoseList);
  FDrag.OnCanStart := CanStart;
  FDrag.OnDragRequest := DragRequest;
end;

destructor TPmxPoseCatalogDragController.Destroy;
begin
  if Assigned(FDrag) then FDrag.Detach;
  FDrag.Free;
  try
    if TFile.Exists(FAliasFileName) then TFile.Delete(FAliasFileName);
  except
    { 一時ファイルの削除失敗はプラグイン終了処理へ影響させない。 }
  end;
  inherited;
end;

function TPmxPoseCatalogDragController.CanStart(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer): Boolean;
var
  DisplayIndex, Index: Integer;
  Model: TPmxCatalogItem;
  Pose: TPmxPoseCatalogItem;
begin
  Result := False;
  try
    if (Button <> mbLeft) or not Assigned(FCatalog) or
      not Assigned(FPoseCatalog) then Exit;
    DisplayIndex := FPoseList.ItemAtPos(Point(X, Y));
    if (DisplayIndex < 0) or (DisplayIndex <> FPoseList.ItemIndex) or
      (FCatalogList.SelectedSourceIndex < 0) or
      (FCatalogList.SelectedSourceIndex >= FCatalog.Count) then Exit;
    Index := FPoseList.SelectedSourceIndex;
    if (Index < 0) or (Index >= FPoseCatalog.Count) then Exit;
    Model := FCatalog.Items[FCatalogList.SelectedSourceIndex];
    Pose := FPoseCatalog[Index];
    Result := TryWritePmxPoseObjectAlias(Model.SourcePath, Pose.PoseData,
      Pose.InitialExpressionData, Pose.InitialEyeBlinkData,
      Pose.InitialLipSyncData, FAliasFileName);
  except
    Result := False;
  end;
end;

procedure TPmxPoseCatalogDragController.DragRequest(Sender: TObject;
  FileNames: TStringList);
begin
  try
    FileNames.Clear;
    if TFile.Exists(FAliasFileName) then FileNames.Add(FAliasFileName);
  except
    FileNames.Clear;
  end;
end;

procedure TPmxPoseCatalogDragController.SetData(ACatalog: TPmxCatalogStorage;
  APoseCatalog: TPmxPoseCatalogStorage);
begin
  FCatalog := ACatalog;
  FPoseCatalog := APoseCatalog;
end;

end.
