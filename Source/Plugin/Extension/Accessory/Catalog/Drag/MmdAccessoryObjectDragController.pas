unit MmdAccessoryObjectDragController;

// アクセサリ一覧からAviUtl2へ渡す一時エイリアスの生成とD&Dを担当する。

interface

uses
  System.Classes,
  Vcl.Controls,
  DragAgent,
  MmdAccessoryCatalog,
  MmdAccessoryCatalogListView;

type
  TMmdAccessoryObjectDragController = class
  private
    FAliasFileName: string;
    FCatalog: TMmdAccessoryCatalog;
    FDrag: TDragShellFile;
    FListView: TMmdAccessoryCatalogListView;
    function CanStart(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer): Boolean;
    procedure DragRequest(Sender: TObject; FileNames: TStringList);
  public
    // 一覧へドラッグ処理を接続し、画面インスタンス固有の一時ファイル名を確保する。
    constructor Create(AOwner: TComponent;
      AListView: TMmdAccessoryCatalogListView);
    // D&Dを解除し、生成済み一時ファイルを可能な範囲で削除する。
    destructor Destroy; override;
    // 現在のカタログを次回D&Dの入力へ設定する。
    procedure SetCatalog(ACatalog: TMmdAccessoryCatalog);
  end;

implementation

uses
  System.IOUtils,
  System.SysUtils,
  System.Types,
  AppFolderUtils,
  MmdAccessoryObjectDragAlias;

constructor TMmdAccessoryObjectDragController.Create(AOwner: TComponent;
  AListView: TMmdAccessoryCatalogListView);
begin
  inherited Create;
  FListView := AListView;
  FAliasFileName := GetAppFolder('Temp') + 'MmdAccessory-' +
    IntToHex(NativeUInt(Self), SizeOf(Pointer) * 2) + '.object';
  FDrag := TDragShellFile.Create(AOwner);
  FDrag.Attach(FListView);
  FDrag.OnCanStart := CanStart;
  FDrag.OnDragRequest := DragRequest;
end;

destructor TMmdAccessoryObjectDragController.Destroy;
begin
  if Assigned(FDrag) then FDrag.Detach;
  FDrag.Free;
  try
    if TFile.Exists(FAliasFileName) then TFile.Delete(FAliasFileName);
  except
    { 一時ファイル削除失敗は画面破棄へ影響させない。 }
  end;
  inherited;
end;

function TMmdAccessoryObjectDragController.CanStart(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer): Boolean;
var
  Index: Integer;
  ModelFileName: string;
begin
  Result := False;
  try
    if (Button <> mbLeft) or not Assigned(FCatalog) then Exit;
    Index := FListView.ItemAtPos(Point(X, Y));
    if (Index < 0) or (Index <> FListView.ItemIndex) or
      (Index >= FCatalog.Count) then Exit;
    ModelFileName := FCatalog.SourceFileName(FCatalog[Index].SourceId);
    Result := TryWriteMmdAccessoryObjectAlias(ModelFileName, FAliasFileName);
  except
    Result := False;
  end;
end;

procedure TMmdAccessoryObjectDragController.DragRequest(Sender: TObject;
  FileNames: TStringList);
begin
  try
    FileNames.Clear;
    if TFile.Exists(FAliasFileName) then FileNames.Add(FAliasFileName);
  except
    FileNames.Clear;
  end;
end;

procedure TMmdAccessoryObjectDragController.SetCatalog(
  ACatalog: TMmdAccessoryCatalog);
begin
  FCatalog := ACatalog;
end;

end.
