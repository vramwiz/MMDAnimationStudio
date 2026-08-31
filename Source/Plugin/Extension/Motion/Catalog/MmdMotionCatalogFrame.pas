unit MmdMotionCatalogFrame;

// モーションページのPMX選択、PMX別一覧、VMD取込と静止サムネイルを構成する。

interface

uses
  System.Classes,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.Forms,
  DarkPanel,
  PmxCatalogStorage,
  PmxCatalogSelector,
  PmxMotionCatalogStorage,
  PmxMotionCatalogListView,
  PmxMotionCatalogToolbar,
  PmxMotionCatalogContextMenu,
  PmxCatalogThumbnailCache,
  PmxCatalogThumbnailRenderer,
  MmdMotionObjectDragController;

type
  TFrameMmdMotionCatalog = class(TFrame)
  private
    FCatalog: TPmxCatalogStorage;
    FContextMenu: TPmxMotionCatalogContextMenu;
    FDivider: TSplitter;
    FLayoutPPI: Integer;
    FModelThumbnailCache: TPmxCatalogThumbnailCache;
    FMotionCatalog: TPmxMotionCatalogStorage;
    FMotionDrag: TMmdMotionObjectDragController;
    FMotionListView: TPmxMotionCatalogListView;
    FMotionThumbnailCache: TPmxCatalogThumbnailCache;
    FMotionToolbar: TPmxMotionCatalogToolbar;
    FOnPmxSelectionChanged: TNotifyEvent;
    FPmxSelector: TPmxCatalogSelector;
    FRightPanel: TDarkPanel;
    FThumbnailRenderer: TPmxCatalogThumbnailRenderer;
    procedure AddMotion(Sender: TObject);
    procedure ApplyDpiLayout;
    procedure PmxSelectionChanged(Sender: TObject);
  public
    // 共通PMX選択とPMX別モーション一覧を持つページを生成する。
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // VMDまたはフォルダを共通保管し、選択PMX用モーションへ登録する。
    function ImportVmdFiles(const Files: TArray<string>;
      const VmdRoot: string = ''): Boolean;
    procedure Resize; override;
    // 他ページで選択されたPmxUIDへ一覧を同期する。
    procedure SelectPmxId(const PmxId: string);
    // 左側で参照する共有PMXカタログを切り替える。
    procedure SetCatalog(ACatalog: TPmxCatalogStorage);
    // PMXとモーション一覧を再読込してページを表示する。
    procedure Show; reintroduce;
    property MotionCatalog: TPmxMotionCatalogStorage read FMotionCatalog;
    property MotionListView: TPmxMotionCatalogListView read FMotionListView;
    property MotionToolbar: TPmxMotionCatalogToolbar read FMotionToolbar;
    property PmxSelector: TPmxCatalogSelector read FPmxSelector;
    property OnPmxSelectionChanged: TNotifyEvent read FOnPmxSelectionChanged
      write FOnPmxSelectionChanged;
  end;

implementation

uses
  Winapi.Windows,
  System.SysUtils,
  Vcl.Dialogs,
  Vcl.Graphics,
  AppFolderUtils,
  MmdVmdMotionImporter;

{$R *.dfm}

const
  PmxListPaneWidth = 105;
  PmxDividerWidth = 3;
  ThumbnailSize96 = 64;
  CaptionAreaHeight96 = 28;

constructor TFrameMmdMotionCatalog.Create(AOwner: TComponent);
var
  PmxFolder: string;
begin
  inherited;
  Color := clBlack;
  ParentBackground := False;
  PmxFolder := GetAppFolder('PMX');
  FModelThumbnailCache := TPmxCatalogThumbnailCache.Create(PmxFolder + 'Cache\Model');
  FMotionThumbnailCache := TPmxCatalogThumbnailCache.Create(PmxFolder + 'Cache\Motion');
  FThumbnailRenderer := TPmxCatalogThumbnailRenderer.Create(Self);
  FThumbnailRenderer.Parent := Self;
  FPmxSelector := TPmxCatalogSelector.Create(Self);
  FPmxSelector.Parent := Self;
  FPmxSelector.Color := Color;
  FPmxSelector.SetThumbnailServices(FModelThumbnailCache, FThumbnailRenderer);
  FPmxSelector.OnSelectionChanged := PmxSelectionChanged;
  FDivider := TSplitter.Create(Self);
  FDivider.Parent := Self;
  FDivider.Align := alLeft;
  FDivider.Width := PmxDividerWidth;
  FDivider.Beveled := True;
  FDivider.Left := FPmxSelector.Width;
  FRightPanel := TDarkPanel.Create(Self);
  FRightPanel.Parent := Self;
  FRightPanel.Align := alClient;
  FRightPanel.BevelOuter := bvNone;
  FRightPanel.ParentBackground := False;
  FRightPanel.Color := Color;
  FMotionListView := TPmxMotionCatalogListView.Create(Self);
  FMotionListView.Parent := FRightPanel;
  FMotionListView.Align := alClient;
  FMotionListView.SetVmdRoot(ExcludeTrailingPathDelimiter(GetAppFolder('VMD')));
  FMotionListView.SetThumbnailServices(FMotionThumbnailCache, FThumbnailRenderer);
  FMotionToolbar := TPmxMotionCatalogToolbar.Create(Self, FMotionListView);
  FMotionToolbar.Parent := FRightPanel;
  FMotionToolbar.Align := alTop;
  FMotionToolbar.OnAddMotion := AddMotion;
  FContextMenu := TPmxMotionCatalogContextMenu.Create(FMotionToolbar);
  FMotionDrag := TMmdMotionObjectDragController.Create(Self,
    FMotionListView);
  ApplyDpiLayout;
end;

destructor TFrameMmdMotionCatalog.Destroy;
begin
  FMotionDrag.Free;
  FContextMenu.Free;
  FMotionToolbar.Free;
  FMotionListView.Free;
  FreeAndNil(FMotionCatalog);
  FPmxSelector.Free;
  FThumbnailRenderer.Free;
  FMotionThumbnailCache.Free;
  FModelThumbnailCache.Free;
  inherited;
end;

procedure TFrameMmdMotionCatalog.ApplyDpiLayout;
var
  PPI, Size: Integer;
begin
  if not Assigned(FPmxSelector) or not Assigned(FMotionListView) then Exit;
  PPI := FPmxSelector.ListView.CurrentPPI;
  if (PPI <= 0) or (FLayoutPPI = PPI) then Exit;
  FLayoutPPI := PPI;
  FPmxSelector.Width := PmxListPaneWidth;
  FDivider.Width := PmxDividerWidth;
  Size := MulDiv(ThumbnailSize96, PPI, 96);
  FPmxSelector.ListView.ImageSize := Size;
  FPmxSelector.ListView.RowHeight := Size + MulDiv(CaptionAreaHeight96, PPI, 96);
  FMotionListView.ImageSize := Size;
  FMotionListView.RowHeight := Size + MulDiv(CaptionAreaHeight96, PPI, 96);
end;

procedure TFrameMmdMotionCatalog.PmxSelectionChanged(Sender: TObject);
var
  Model: TPmxCatalogItem;
begin
  FMotionToolbar.SetCatalog(nil);
  if Assigned(FMotionDrag) then FMotionDrag.SetData(nil, nil);
  FMotionListView.SetData(nil, nil);
  FreeAndNil(FMotionCatalog);
  Model := FPmxSelector.SelectedModel;
  if Assigned(FCatalog) and Assigned(Model) then
  begin
    FMotionCatalog := TPmxMotionCatalogStorage.Create(
      FCatalog.ModelFolder(Model.Id), Model.Id, Model.DisplayName);
    FMotionCatalog.LoadFromFile;
    EnsureMmdVmdMotionData(ExcludeTrailingPathDelimiter(GetAppFolder('VMD')),
      FMotionCatalog);
  end;
  FMotionListView.SetData(Model, FMotionCatalog);
  FMotionToolbar.SetCatalog(FMotionCatalog);
  if Assigned(FMotionDrag) then FMotionDrag.SetData(Model, FMotionCatalog);
  if Assigned(FOnPmxSelectionChanged) then FOnPmxSelectionChanged(Self);
end;

procedure TFrameMmdMotionCatalog.AddMotion(Sender: TObject);
var
  Dialog: TOpenDialog;
begin
  Dialog := TOpenDialog.Create(Self);
  try
    Dialog.Filter := 'VMDモーション (*.vmd)|*.vmd';
    Dialog.Options := Dialog.Options + [ofAllowMultiSelect, ofFileMustExist];
    if Dialog.Execute then ImportVmdFiles(Dialog.Files.ToStringArray);
  finally
    Dialog.Free;
  end;
end;

function TFrameMmdMotionCatalog.ImportVmdFiles(const Files: TArray<string>;
  const VmdRoot: string): Boolean;
var
  Summary: TMmdVmdImportSummary;
begin
  if Trim(VmdRoot) <> '' then FMotionListView.SetVmdRoot(VmdRoot);
  Result := ImportMmdVmdMotions(Files, VmdRoot, FMotionCatalog, Summary);
  if not Result then Exit;
  FMotionListView.Reload;
  FMotionListView.SelectMotionId(Summary.LastMotionId);
end;

procedure TFrameMmdMotionCatalog.Resize;
begin
  inherited;
  ApplyDpiLayout;
end;

procedure TFrameMmdMotionCatalog.SelectPmxId(const PmxId: string);
begin
  FPmxSelector.SelectPmxId(PmxId);
end;

procedure TFrameMmdMotionCatalog.SetCatalog(ACatalog: TPmxCatalogStorage);
begin
  if FCatalog = ACatalog then begin FPmxSelector.Reload; Exit; end;
  FCatalog := ACatalog;
  FPmxSelector.SetCatalog(FCatalog);
end;

procedure TFrameMmdMotionCatalog.Show;
begin
  ApplyDpiLayout;
  FPmxSelector.Reload;
  PmxSelectionChanged(FPmxSelector);
  inherited Show;
end;

end.
