unit PmxMotionCatalogToolbar;

// モーション一覧の追加要求、複製、削除、上下移動と既存アイコンを接続する。

interface

uses
  System.Classes,
  System.ImageList,
  Vcl.Controls,
  Vcl.ImgList,
  ToolbarButtons,
  ToolbarIcon,
  PmxMotionCatalogStorage,
  PmxMotionCatalogListView;

type
  TPmxMotionCatalogToolbar = class(TToolbarButtons)
  private
    FAddButton: TToolbarIconItem;
    FCatalog: TPmxMotionCatalogStorage;
    FCopyButton: TToolbarIconItem;
    FDeleteButton: TToolbarIconItem;
    FDownButton: TToolbarIconItem;
    FImages: TImageList;
    FList: TPmxMotionCatalogListView;
    FOnAddMotion: TNotifyEvent;
    FUpButton: TToolbarIconItem;
    procedure ListSelectionChanged(Sender: TObject);
    procedure ReloadMotion(const MotionId: string; FallbackIndex: Integer = -1);
    procedure ShowError;
    procedure UpdateButtons;
  public
    // 一覧へ5操作アイコンを接続し、選択状態に応じて有効状態を更新する。
    constructor Create(AOwner: TComponent;
      AList: TPmxMotionCatalogListView); reintroduce;
    // 以下の操作はメニューとショートカットからも共通利用する。
    procedure AddMotion;
    procedure CopyMotion;
    procedure DeleteMotion;
    procedure DownMotion;
    procedure RefreshMotions;
    procedure RenameMotion;
    // 操作対象のPMX別カタログを切り替える。nilなら全操作を無効にする。
    procedure SetCatalog(ACatalog: TPmxMotionCatalogStorage);
    procedure UpMotion;
    property Catalog: TPmxMotionCatalogStorage read FCatalog;
    property ListView: TPmxMotionCatalogListView read FList;
    property OnAddMotion: TNotifyEvent read FOnAddMotion write FOnAddMotion;
  end;

implementation

uses
  Winapi.Windows,
  Vcl.Graphics,
  AviUtl2StyleColors,
  ConfirmDialogForm,
  PmxPoseCatalogToolbarIcons;

const
  ToolbarHeight = 24;
  ToolbarDownColor = TColor($001F1F1F);

constructor TPmxMotionCatalogToolbar.Create(AOwner: TComponent;
  AList: TPmxMotionCatalogListView);
begin
  inherited Create(AOwner);
  FList := AList;
  Height := ToolbarHeight;
  BevelOuter := bvNone;
  BevelKind := bkSoft;
  BevelWidth := 1;
  NormalColor := A2SCToolBarBackground;
  HoverColor := A2SCToolBarHot;
  DownColor := ToolbarDownColor;
  FImages := TImageList.Create(Self);
  BuildPmxPoseCatalogToolbarIcons(FImages, ToolbarHeight, clWhite);
  Images := FImages;
  FAddButton := AddIcon('VMDを追加', 0, AddMotion);
  FCopyButton := AddIcon('モーションを複製', 1, CopyMotion);
  FDeleteButton := AddIcon('モーションを削除', 2, DeleteMotion);
  FUpButton := AddIcon('上に移動', 3, UpMotion);
  FDownButton := AddIcon('下に移動', 4, DownMotion);
  FList.OnSelectionChanged := ListSelectionChanged;
  UpdateButtons;
end;

procedure TPmxMotionCatalogToolbar.AddMotion;
begin
  if Assigned(FCatalog) and Assigned(FOnAddMotion) then FOnAddMotion(Self);
end;

procedure TPmxMotionCatalogToolbar.CopyMotion;
var
  Index, NewIndex: Integer;
begin
  Index := FList.SelectedSourceIndex;
  if not Assigned(FCatalog) or (Index < 0) or (Index >= FCatalog.Count) then Exit;
  try
    NewIndex := FCatalog.Duplicate(Index);
    if NewIndex < 0 then ShowError
    else ReloadMotion(FCatalog[NewIndex].Id);
  except
    ShowError;
  end;
end;

procedure TPmxMotionCatalogToolbar.DeleteMotion;
var
  Dialog: TFormConfirmDialog;
  Index: Integer;
begin
  Index := FList.SelectedSourceIndex;
  if not Assigned(FCatalog) or (Index < 0) or (Index >= FCatalog.Count) then Exit;
  Dialog := TFormConfirmDialog.Create(FList);
  try
    if Dialog.Execute('選択したモーションを削除しますか？') <> mrOk then Exit;
  finally
    Dialog.Free;
  end;
  try
    if FCatalog.Remove(Index) then ReloadMotion('', Index) else ShowError;
  except
    ShowError;
  end;
end;

procedure TPmxMotionCatalogToolbar.DownMotion;
var
  Index, NewIndex: Integer;
begin
  Index := FList.SelectedSourceIndex;
  if not Assigned(FCatalog) or (Index < 0) or (Index >= FCatalog.Count - 1) then Exit;
  try
    NewIndex := FCatalog.Move(Index, 1);
    if NewIndex < 0 then ShowError else ReloadMotion(FCatalog[NewIndex].Id);
  except
    ShowError;
  end;
end;

procedure TPmxMotionCatalogToolbar.ListSelectionChanged(Sender: TObject);
begin
  UpdateButtons;
end;

procedure TPmxMotionCatalogToolbar.ReloadMotion(const MotionId: string;
  FallbackIndex: Integer);
begin
  FList.Reload;
  if MotionId <> '' then FList.SelectMotionId(MotionId);
  if (FList.ItemIndex < 0) and (FallbackIndex >= 0) then
  begin
    if FallbackIndex >= FList.DisplayCount then FallbackIndex := FList.DisplayCount - 1;
    FList.ItemIndex := FallbackIndex;
  end;
  UpdateButtons;
end;

procedure TPmxMotionCatalogToolbar.RefreshMotions;
var
  Index: Integer;
  MotionId: string;
begin
  if not Assigned(FCatalog) then Exit;
  Index := FList.SelectedSourceIndex;
  MotionId := '';
  if (Index >= 0) and (Index < FCatalog.Count) then MotionId := FCatalog[Index].Id;
  try
    if not FList.RefreshThumbnails or not FCatalog.LoadFromFile then ShowError
    else ReloadMotion(MotionId, Index);
  except
    ShowError;
  end;
end;

procedure TPmxMotionCatalogToolbar.RenameMotion;
begin
  if Assigned(FCatalog) and (FList.SelectedSourceIndex >= 0) and
    (FList.SelectedSourceIndex < FCatalog.Count) then FList.BeginEdit(FList.ItemIndex);
end;

procedure TPmxMotionCatalogToolbar.SetCatalog(ACatalog: TPmxMotionCatalogStorage);
begin
  FCatalog := ACatalog;
  UpdateButtons;
end;

procedure TPmxMotionCatalogToolbar.ShowError;
begin
  MessageBox(FList.Handle, 'モーション一覧を更新できませんでした。',
    'PMX モーション', MB_OK or MB_ICONERROR);
end;

procedure TPmxMotionCatalogToolbar.UpMotion;
var
  Index, NewIndex: Integer;
begin
  Index := FList.SelectedSourceIndex;
  if not Assigned(FCatalog) or (Index <= 0) or (Index >= FCatalog.Count) then Exit;
  try
    NewIndex := FCatalog.Move(Index, -1);
    if NewIndex < 0 then ShowError else ReloadMotion(FCatalog[NewIndex].Id);
  except
    ShowError;
  end;
end;

procedure TPmxMotionCatalogToolbar.UpdateButtons;
var
  Index: Integer;
  Selected: Boolean;
begin
  Index := FList.SelectedSourceIndex;
  Selected := Assigned(FCatalog) and (Index >= 0) and (Index < FCatalog.Count);
  FAddButton.Enabled := Assigned(FCatalog) and Assigned(FOnAddMotion);
  FCopyButton.Enabled := Selected;
  FDeleteButton.Enabled := Selected;
  FUpButton.Enabled := Selected and (Index > 0);
  FDownButton.Enabled := Selected and (Index < FCatalog.Count - 1);
end;

end.
