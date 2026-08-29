unit MmdPoseObjectDragController;

// ポーズ画面右一覧からAviUtl2へ渡すポーズオブジェクトのD&Dと、
// インスタンス固有一時エイリアスの後始末を担当する。

interface

uses
  System.Classes,
  Vcl.Controls,
  DragAgent,
  PmxCatalogStorage,
  PmxPoseCatalogStorage,
  PmxPoseCatalogListView;

type
  TMmdPoseObjectDragController = class
  private
    FAliasFileName: string;
    FDrag: TDragShellFile;
    FModel: TPmxCatalogItem;
    FPoseCatalog: TPmxPoseCatalogStorage;
    FPoseList: TPmxPoseCatalogListView;
    function CanStart(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer): Boolean;
    procedure DragRequest(Sender: TObject; FileNames: TStringList);
  public
    // 右一覧へドラッグ開始判定と一時ファイル提供を接続する。
    constructor Create(AOwner: TComponent; AList: TPmxPoseCatalogListView);
    // 一覧との接続を解除し、生成済み一時ファイルを削除する。
    destructor Destroy; override;
    // 選択中のPMXとポーズカタログを次回D&Dの入力へ設定する。
    procedure SetData(AModel: TPmxCatalogItem;
      APoseCatalog: TPmxPoseCatalogStorage);
  end;

implementation

uses
  System.IOUtils,
  System.SysUtils,
  System.Types,
  AppFolderUtils,
  MmdPoseObjectDragAlias;

constructor TMmdPoseObjectDragController.Create(AOwner: TComponent;
  AList: TPmxPoseCatalogListView);
begin
  inherited Create;
  FPoseList := AList;
  FAliasFileName := GetAppFolder('Temp') + 'MmdPose-' +
    IntToHex(NativeUInt(Self), SizeOf(Pointer) * 2) + '.object';
  FDrag := TDragShellFile.Create(AOwner);
  FDrag.Attach(FPoseList);
  FDrag.OnCanStart := CanStart;
  FDrag.OnDragRequest := DragRequest;
end;

destructor TMmdPoseObjectDragController.Destroy;
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

function TMmdPoseObjectDragController.CanStart(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer): Boolean;
var
  DisplayIndex, Index: Integer;
begin
  Result := False;
  try
    if (Button <> mbLeft) or not Assigned(FModel) or
      not Assigned(FPoseCatalog) then Exit;
    DisplayIndex := FPoseList.ItemAtPos(Point(X, Y));
    if (DisplayIndex < 0) or (DisplayIndex <> FPoseList.ItemIndex) then Exit;
    Index := FPoseList.SelectedSourceIndex;
    if (Index < 0) or (Index >= FPoseCatalog.Count) then Exit;
    Result := TryWriteMmdPoseObjectAlias(FModel.SourcePath,
      FPoseCatalog[Index].PoseData, FAliasFileName);
  except
    Result := False;
  end;
end;

procedure TMmdPoseObjectDragController.DragRequest(Sender: TObject;
  FileNames: TStringList);
begin
  try
    FileNames.Clear;
    if TFile.Exists(FAliasFileName) then FileNames.Add(FAliasFileName);
  except
    FileNames.Clear;
  end;
end;

procedure TMmdPoseObjectDragController.SetData(AModel: TPmxCatalogItem;
  APoseCatalog: TPmxPoseCatalogStorage);
begin
  FModel := AModel;
  FPoseCatalog := APoseCatalog;
end;

end.
