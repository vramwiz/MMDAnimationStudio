unit MmdFaceCatalogFrame;

// 表情ページの共通PMX選択と、選択モデル別のFaceUID一覧を構成する。

interface

uses
  System.Classes,
  Vcl.Controls, Vcl.ExtCtrls, Vcl.Forms,
  PmxCatalogStorage, PmxCatalogSelector,
  PmxFaceCatalogStorage, PmxFaceCatalogGroups,
  PmxFaceCatalogGroupBar, PmxFaceCatalogListView,
  PmxFaceCatalogContextMenu, PmxFaceCatalogToolbar,
  MmdFaceObjectDragController,
  PmxCatalogThumbnailCache, PmxCatalogThumbnailRenderer;

type
  TMmdFaceCatalogEditEvent = function(Sender: TObject;
    Model: TPmxCatalogItem; Item: TPmxFaceCatalogItem): Boolean of object;

  TFrameMmdFaceCatalog = class(TFrame)
  private
    FCatalog: TPmxCatalogStorage;
    FDivider: TSplitter;
    FFaceCatalog: TPmxFaceCatalogStorage;
    FFaceContextMenu: TPmxFaceCatalogContextMenu;
    FFaceDrag: TMmdFaceObjectDragController;
    FFaceGroupBar: TPmxFaceCatalogGroupBar;
    FFaceGroups: TPmxFaceCatalogGroups;
    FFaceListView: TPmxFaceCatalogListView;
    FFaceThumbnailCache: TPmxCatalogThumbnailCache;
    FFaceToolbar: TPmxFaceCatalogToolbar;
    FLayoutPPI: Integer;
    FModelThumbnailCache: TPmxCatalogThumbnailCache;
    FOnEditFace: TMmdFaceCatalogEditEvent;
    FOnPmxSelectionChanged: TNotifyEvent;
    FPmxSelector: TPmxCatalogSelector;
    FRightPanel: TPanel;
    FThumbnailRenderer: TPmxCatalogThumbnailRenderer;
    procedure ApplyDpiLayout;
    procedure FaceListDblClick(Sender: TObject);
    procedure PmxSelectionChanged(Sender: TObject);
  public
    // ポーズページと同じPMX選択、グループ、一覧操作UIを表情用に生成する。
    constructor Create(AOwner: TComponent); override;
    // D&D、一覧操作、保存領域、サムネイルサービスを所有順の逆で解放する。
    destructor Destroy; override;
    // PMX管理ページと同じモデルカタログをデータ元として設定する。
    procedure SetCatalog(ACatalog: TPmxCatalogStorage);
    // PmxUIDを選択し、対応する表情一覧を読み込む。
    procedure SelectPmxId(const PmxId: string);
    // 現在DPIとクライアント幅に合わせて左右ペインを再配置する。
    procedure Resize; override;
    // 表示時にPMXと表情カタログを最新状態へ読み直す。
    procedure Show; reintroduce;
    // 画面間同期とテストに必要な現在の表情Control・保存領域を公開する。
    property FaceCatalog: TPmxFaceCatalogStorage read FFaceCatalog;
    property FaceGroupBar: TPmxFaceCatalogGroupBar read FFaceGroupBar;
    property FaceGroups: TPmxFaceCatalogGroups read FFaceGroups;
    property FaceListView: TPmxFaceCatalogListView read FFaceListView;
    property FaceToolbar: TPmxFaceCatalogToolbar read FFaceToolbar;
    property PmxSelector: TPmxCatalogSelector read FPmxSelector;
    // PMX選択変更と表情編集要求を呼出側へ通知する。
    property OnPmxSelectionChanged: TNotifyEvent read FOnPmxSelectionChanged
      write FOnPmxSelectionChanged;
    property OnEditFace: TMmdFaceCatalogEditEvent read FOnEditFace
      write FOnEditFace;
  end;

implementation

uses
  Winapi.Windows,
  System.SysUtils,
  Vcl.Graphics,
  AppFolderUtils,
  PmxFaceCatalogEditor;

{$R *.dfm}

const
  PmxCaptionAreaHeight = 28;
  PmxDividerWidth = 3;
  PmxListPaneWidth = 105;
  PmxThumbnailSize = 64;

constructor TFrameMmdFaceCatalog.Create(AOwner: TComponent);
var
  PmxFolder: string;
begin
  inherited;
  Color := clBlack;
  ParentBackground := False;
  PmxFolder := GetAppFolder('PMX');
  FModelThumbnailCache := TPmxCatalogThumbnailCache.Create(
    PmxFolder + 'Cache\Model');
  FFaceThumbnailCache := TPmxCatalogThumbnailCache.Create(
    PmxFolder + 'Cache\Face');
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

  FRightPanel := TPanel.Create(Self);
  FRightPanel.Parent := Self;
  FRightPanel.Align := alClient;
  FRightPanel.BevelOuter := bvNone;
  FRightPanel.ParentBackground := False;
  FRightPanel.Color := Color;

  FFaceListView := TPmxFaceCatalogListView.Create(Self);
  FFaceListView.Parent := FRightPanel;
  FFaceListView.Align := alClient;
  FFaceListView.SetThumbnailServices(FFaceThumbnailCache,
    FThumbnailRenderer);
  FFaceListView.OnDblClick := FaceListDblClick;
  FFaceToolbar := TPmxFaceCatalogToolbar.Create(Self, FFaceListView);
  FFaceToolbar.Parent := FRightPanel;
  FFaceToolbar.Align := alTop;
  FFaceGroupBar := TPmxFaceCatalogGroupBar.Create(Self, FRightPanel,
    FFaceListView);
  FFaceGroupBar.Bar.Top := 0;
  FFaceToolbar.Top := FFaceGroupBar.Bar.Height;
  FFaceContextMenu := TPmxFaceCatalogContextMenu.Create(FFaceToolbar);
  FFaceDrag := TMmdFaceObjectDragController.Create(Self, FFaceListView);
  ApplyDpiLayout;
end;

procedure TFrameMmdFaceCatalog.FaceListDblClick(Sender: TObject);
var
  Face: TPmxFaceCatalogItem;
  Index: Integer;
  Model: TPmxCatalogItem;
  OldFaceData: string;
begin
  if not Assigned(FCatalog) or not Assigned(FFaceCatalog) then Exit;
  Index := FFaceListView.SelectedSourceIndex;
  Model := FPmxSelector.SelectedModel;
  if not Assigned(Model) or (Index < 0) or
    (Index >= FFaceCatalog.Count) then Exit;
  Face := FFaceCatalog[Index];
  OldFaceData := Face.FaceData;
  try
    if Assigned(FOnEditFace) then
    begin
      if not FOnEditFace(Self, Model, Face) then Exit;
    end
    else if not EditPmxFaceCatalogFace(Model, Face) then Exit;
    if not FFaceCatalog.SaveToFile then
    begin
      Face.FaceData := OldFaceData;
      raise EInOutError.Create(
        #$8868#$60C5#$30C7#$30FC#$30BF#$3092#$4FDD#$5B58#$3067#$304D +
        #$307E#$305B#$3093#$3067#$3057#$305F);
    end;
    FFaceListView.Reload;
  except
    on E: Exception do
    begin
      Face.FaceData := OldFaceData;
      MessageBox(Handle, PChar(E.Message),
        #$004D#$004D#$0044' '#$8868#$60C5#$7DE8#$96C6,
        MB_OK or MB_ICONERROR);
    end;
  end;
end;

destructor TFrameMmdFaceCatalog.Destroy;
begin
  FFaceDrag.Free;
  FFaceContextMenu.Free;
  FFaceGroupBar.Free;
  FFaceToolbar.Free;
  FFaceListView.Free;
  FreeAndNil(FFaceCatalog);
  FreeAndNil(FFaceGroups);
  FPmxSelector.Free;
  FThumbnailRenderer.Free;
  FFaceThumbnailCache.Free;
  FModelThumbnailCache.Free;
  inherited;
end;

procedure TFrameMmdFaceCatalog.ApplyDpiLayout;
var
  PPI, ThumbnailSize: Integer;
begin
  if not Assigned(FPmxSelector) or not Assigned(FFaceListView) then Exit;
  PPI := FPmxSelector.ListView.CurrentPPI;
  if (PPI <= 0) or (FLayoutPPI = PPI) then Exit;
  FLayoutPPI := PPI;
  FPmxSelector.Width := PmxListPaneWidth;
  FDivider.Width := PmxDividerWidth;
  ThumbnailSize := MulDiv(PmxThumbnailSize, PPI, 96);
  FPmxSelector.ListView.ImageSize := ThumbnailSize;
  FPmxSelector.ListView.RowHeight := ThumbnailSize +
    MulDiv(PmxCaptionAreaHeight, PPI, 96);
  FFaceListView.ImageSize := ThumbnailSize;
  FFaceListView.RowHeight := ThumbnailSize +
    MulDiv(PmxCaptionAreaHeight, PPI, 96);
end;

procedure TFrameMmdFaceCatalog.PmxSelectionChanged(Sender: TObject);
var
  Model: TPmxCatalogItem;
  ModelFolder: string;
begin
  FFaceDrag.SetData(nil, nil);
  FFaceToolbar.SetCatalog(nil);
  FFaceGroupBar.SetGroups(nil);
  FFaceListView.SetData(nil, nil, nil);
  FreeAndNil(FFaceGroups);
  FreeAndNil(FFaceCatalog);
  Model := FPmxSelector.SelectedModel;
  if Assigned(FCatalog) and Assigned(Model) then
  begin
    ModelFolder := FCatalog.ModelFolder(Model.Id);
    FFaceCatalog := TPmxFaceCatalogStorage.Create(ModelFolder,
      Model.Id, Model.DisplayName);
    FFaceCatalog.LoadOrCreateDefault;
    FFaceGroups := TPmxFaceCatalogGroups.Create(ModelFolder);
    FFaceGroups.LoadFromFile;
    if FFaceGroups.RemoveUnknownFaces(FFaceCatalog) then
      FFaceGroups.SaveToFile;
  end;
  FFaceListView.SetData(Model, FFaceCatalog, FFaceGroups);
  FFaceGroupBar.SetGroups(FFaceGroups);
  FFaceToolbar.SetCatalog(FFaceCatalog);
  FFaceDrag.SetData(Model, FFaceCatalog);
  if Assigned(FOnPmxSelectionChanged) then FOnPmxSelectionChanged(Self);
end;

procedure TFrameMmdFaceCatalog.Resize;
begin
  inherited;
  ApplyDpiLayout;
end;

procedure TFrameMmdFaceCatalog.SelectPmxId(const PmxId: string);
begin
  FPmxSelector.SelectPmxId(PmxId);
end;

procedure TFrameMmdFaceCatalog.SetCatalog(ACatalog: TPmxCatalogStorage);
begin
  if FCatalog = ACatalog then
  begin
    FPmxSelector.Reload;
    Exit;
  end;
  FCatalog := ACatalog;
  FPmxSelector.SetCatalog(FCatalog);
end;

procedure TFrameMmdFaceCatalog.Show;
begin
  ApplyDpiLayout;
  FPmxSelector.Reload;
  PmxSelectionChanged(FPmxSelector);
  inherited Show;
end;

end.

