unit MmdMotionObjectDragController;

// モーション画面右一覧からAviUtl2へ渡すモーションオブジェクトのD&Dと、
// インスタンス固有一時エイリアスの後始末を担当する。

interface

uses
  System.Classes,
  Vcl.Controls,
  DragAgent,
  PmxCatalogStorage,
  PmxMotionCatalogStorage,
  PmxMotionCatalogListView;

type
  TMmdMotionObjectDragController = class
  private
    FAliasFileName: string;
    FDrag: TDragShellFile;
    FModel: TPmxCatalogItem;
    FMotionCatalog: TPmxMotionCatalogStorage;
    FMotionList: TPmxMotionCatalogListView;
    function CanStart(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer): Boolean;
    procedure DragRequest(Sender: TObject; FileNames: TStringList);
  public
    // 右一覧へドラッグ開始判定と一時ファイル提供を接続する。
    constructor Create(AOwner: TComponent; AList: TPmxMotionCatalogListView);
    // 一覧との接続を解除し、生成済み一時ファイルを削除する。
    destructor Destroy; override;
    // 選択中のPMXとモーションカタログを次回D&Dの入力へ設定する。
    procedure SetData(AModel: TPmxCatalogItem;
      AMotionCatalog: TPmxMotionCatalogStorage);
  end;

implementation

uses
  System.IOUtils,
  System.SysUtils,
  System.Types,
  AppFolderUtils,
  MmdMotionObjectDragAlias;

constructor TMmdMotionObjectDragController.Create(AOwner: TComponent;
  AList: TPmxMotionCatalogListView);
begin
  inherited Create;
  FMotionList := AList;
  FAliasFileName := GetAppFolder('Temp') + 'MmdMotion-' +
    IntToHex(NativeUInt(Self), SizeOf(Pointer) * 2) + '.object';
  FDrag := TDragShellFile.Create(AOwner);
  FDrag.Attach(FMotionList);
  FDrag.OnCanStart := CanStart;
  FDrag.OnDragRequest := DragRequest;
end;

destructor TMmdMotionObjectDragController.Destroy;
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

function TMmdMotionObjectDragController.CanStart(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer): Boolean;
var
  DisplayIndex, Index: Integer;
  MotionData: string;
begin
  Result := False;
  try
    if (Button <> mbLeft) or not Assigned(FModel) or
      not Assigned(FMotionCatalog) then Exit;
    DisplayIndex := FMotionList.ItemAtPos(Point(X, Y));
    if (DisplayIndex < 0) or
      (DisplayIndex <> FMotionList.ItemIndex) then Exit;
    Index := FMotionList.SelectedSourceIndex;
    if (Index < 0) or (Index >= FMotionCatalog.Count) or
      not FMotionCatalog.LoadMotionData(Index, MotionData) then Exit;
    Result := TryWriteMmdMotionObjectAlias(FModel.SourcePath,
      MotionData, FAliasFileName);
  except
    Result := False;
  end;
end;

procedure TMmdMotionObjectDragController.DragRequest(Sender: TObject;
  FileNames: TStringList);
begin
  try
    FileNames.Clear;
    if TFile.Exists(FAliasFileName) then FileNames.Add(FAliasFileName);
  except
    FileNames.Clear;
  end;
end;

procedure TMmdMotionObjectDragController.SetData(AModel: TPmxCatalogItem;
  AMotionCatalog: TPmxMotionCatalogStorage);
begin
  FModel := AModel;
  FMotionCatalog := AMotionCatalog;
end;

end.
