unit MmdFaceObjectDragController;

// 表情画面右一覧からAviUtl2へ渡す表情オブジェクトのD&Dと、
// インスタンス固有一時エイリアスの後始末を担当する。

interface

uses
  System.Classes,
  Vcl.Controls,
  DragAgent,
  PmxCatalogStorage,
  PmxFaceCatalogStorage,
  PmxFaceCatalogListView;

type
  TMmdFaceObjectDragController = class
  private
    FAliasFileName: string;
    FDrag: TDragShellFile;
    FFaceCatalog: TPmxFaceCatalogStorage;
    FFaceList: TPmxFaceCatalogListView;
    FModel: TPmxCatalogItem;
    function CanStart(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer): Boolean;
    procedure DragRequest(Sender: TObject; FileNames: TStringList);
  public
    // 指定一覧へ左ドラッグを接続し、インスタンス固有の一時エイリアス名を用意する。
    constructor Create(AOwner: TComponent; AList: TPmxFaceCatalogListView);
    // D&D接続を破棄し、生成済み一時エイリアスを削除する。
    destructor Destroy; override;
    // 次回D&Dで使う選択PMXと表情カタログを差し替える。
    procedure SetData(AModel: TPmxCatalogItem;
      AFaceCatalog: TPmxFaceCatalogStorage);
  end;

implementation

uses
  System.IOUtils,
  System.SysUtils,
  System.Types,
  AppFolderUtils,
  MmdFaceObjectDragAlias;

constructor TMmdFaceObjectDragController.Create(AOwner: TComponent;
  AList: TPmxFaceCatalogListView);
begin
  inherited Create;
  FFaceList := AList;
  FAliasFileName := GetAppFolder('Temp') + 'MmdFace-' +
    IntToHex(NativeUInt(Self), SizeOf(Pointer) * 2) + '.object';
  FDrag := TDragShellFile.Create(AOwner);
  FDrag.Attach(FFaceList);
  FDrag.OnCanStart := CanStart;
  FDrag.OnDragRequest := DragRequest;
end;

destructor TMmdFaceObjectDragController.Destroy;
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

function TMmdFaceObjectDragController.CanStart(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer): Boolean;
var
  DisplayIndex, Index: Integer;
begin
  Result := False;
  try
    if (Button <> mbLeft) or not Assigned(FModel) or
      not Assigned(FFaceCatalog) then Exit;
    DisplayIndex := FFaceList.ItemAtPos(Point(X, Y));
    if (DisplayIndex < 0) or (DisplayIndex <> FFaceList.ItemIndex) then Exit;
    Index := FFaceList.SelectedSourceIndex;
    if (Index < 0) or (Index >= FFaceCatalog.Count) then Exit;
    Result := TryWriteMmdFaceObjectAlias(FModel.SourcePath,
      FFaceCatalog[Index].FaceData, FAliasFileName);
  except
    Result := False;
  end;
end;

procedure TMmdFaceObjectDragController.DragRequest(Sender: TObject;
  FileNames: TStringList);
begin
  try
    FileNames.Clear;
    if TFile.Exists(FAliasFileName) then FileNames.Add(FAliasFileName);
  except
    FileNames.Clear;
  end;
end;

procedure TMmdFaceObjectDragController.SetData(AModel: TPmxCatalogItem;
  AFaceCatalog: TPmxFaceCatalogStorage);
begin
  FModel := AModel;
  FFaceCatalog := AFaceCatalog;
end;

end.
