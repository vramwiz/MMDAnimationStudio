unit PmxFaceCatalogToolbar;

// 表情一覧上部の5操作と、その有効状態・選択維持を担当する。

interface

uses
  System.Classes,
  System.ImageList,
  Vcl.Controls,
  Vcl.ImgList,
  ToolbarButtons,
  ToolbarIcon,
  PmxFaceCatalogStorage,
  PmxFaceCatalogListView;

type
  TPmxFaceCatalogToolbar = class(TToolbarButtons)
  private
    FAddButton: TToolbarIconItem;
    FCatalog: TPmxFaceCatalogStorage;
    FCopyButton: TToolbarIconItem;
    FDeleteButton: TToolbarIconItem;
    FDownButton: TToolbarIconItem;
    FImages: TImageList;
    FList: TPmxFaceCatalogListView;
    FUpButton: TToolbarIconItem;
    procedure ListSelectionChanged(Sender: TObject);
    procedure ReloadFace(const FaceId: string; FallbackIndex: Integer = -1);
    procedure ShowError;
    procedure UpdateButtons;
  public
    // 指定表情一覧へ5操作のアイコンと選択連動を接続する。
    constructor Create(AOwner: TComponent;
      AList: TPmxFaceCatalogListView); reintroduce;
    // 空表情を追加し、追加位置を選択する。
    procedure AddFace;
    // 選択表情を新しいFaceUIDで複製し、複製位置を選択する。
    procedure CopyFace;
    // 初期状態以外の選択表情を確認後に削除する。
    procedure DeleteFace;
    // 選択表情を1つ下へ移動し、移動後の位置を選択する。
    procedure DownFace;
    // 保存JSONとサムネイルキャッシュを読み直して一覧を再構築する。
    procedure RefreshFaces;
    // 選択表情の一覧内名称編集を開始する。
    procedure RenameFace;
    // 操作対象の表情カタログを差し替え、ボタン有効状態を更新する。
    procedure SetCatalog(ACatalog: TPmxFaceCatalogStorage);
    // 選択表情を1つ上へ移動し、移動後の位置を選択する。
    procedure UpFace;
    // 現在接続中の表情カタログと一覧Controlを読取専用で公開する。
    property Catalog: TPmxFaceCatalogStorage read FCatalog;
    property ListView: TPmxFaceCatalogListView read FList;
  end;

implementation

uses
  Winapi.Windows,
  Vcl.Graphics,
  AviUtl2StyleColors,
  ConfirmDialogForm,
  PmxFaceCatalogToolbarIcons;

const
  ToolbarHeight = 24;
  ToolbarDownColor = TColor($001F1F1F);

constructor TPmxFaceCatalogToolbar.Create(AOwner: TComponent;
  AList: TPmxFaceCatalogListView);
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
  BuildPmxFaceCatalogToolbarIcons(FImages, ToolbarHeight, clWhite);
  Images := FImages;
  FAddButton := AddIcon('表情を追加', 0, AddFace);
  FCopyButton := AddIcon('表情を複製', 1, CopyFace);
  FDeleteButton := AddIcon('表情を削除', 2, DeleteFace);
  FUpButton := AddIcon('上に移動', 3, UpFace);
  FDownButton := AddIcon('下に移動', 4, DownFace);
  FList.OnSelectionChanged := ListSelectionChanged;
  UpdateButtons;
end;

procedure TPmxFaceCatalogToolbar.AddFace;
var
  Index: Integer;
  FaceId: string;
begin
  if not Assigned(FCatalog) then Exit;
  try
    Index := FCatalog.Add;
    if Index < 0 then
    begin
      ShowError;
      Exit;
    end;
    FaceId := FCatalog[Index].Id;
    FList.AdoptFaceInCurrentGroup(FaceId, FList.ItemIndex);
    UpdateButtons;
  except
    ShowError;
  end;
end;

procedure TPmxFaceCatalogToolbar.CopyFace;
var
  Index, NewIndex: Integer;
  FaceId: string;
begin
  Index := FList.SelectedSourceIndex;
  if not Assigned(FCatalog) or (Index < 0) or
    (Index >= FCatalog.Count) then Exit;
  try
    NewIndex := FCatalog.Duplicate(Index);
    if NewIndex < 0 then
    begin
      ShowError;
      Exit;
    end;
    FaceId := FCatalog[NewIndex].Id;
    FList.AdoptFaceInCurrentGroup(FaceId, FList.ItemIndex + 1);
    UpdateButtons;
  except
    ShowError;
  end;
end;

procedure TPmxFaceCatalogToolbar.DeleteFace;
var
  Dialog: TFormConfirmDialog;
  Index: Integer;
  FaceId: string;
begin
  Index := FList.SelectedSourceIndex;
  if not Assigned(FCatalog) or FCatalog.IsInitial(Index) then Exit;
  FaceId := FCatalog[Index].Id;
  Dialog := TFormConfirmDialog.Create(FList);
  try
    if Dialog.Execute('選択した表情を削除しますか？') <> mrOk then Exit;
  finally
    Dialog.Free;
  end;
  try
    if FCatalog.Remove(Index) then
    begin
      if Assigned(FList.Groups) then
      begin
        FList.Groups.RemoveFaceFromAll(FaceId);
        FList.Groups.SaveToFile;
      end;
      ReloadFace('', FList.ItemIndex);
    end
    else
      ShowError;
  except
    ShowError;
  end;
end;

procedure TPmxFaceCatalogToolbar.DownFace;
var
  Index, NewIndex: Integer;
  FaceId: string;
begin
  if FList.GroupIndex >= 0 then
  begin
    FList.MoveSelectedInGroup(1);
    UpdateButtons;
    Exit;
  end;
  Index := FList.SelectedSourceIndex;
  if not Assigned(FCatalog) or (Index < 0) or
    (Index >= FCatalog.Count - 1) then Exit;
  try
    NewIndex := FCatalog.Move(Index, 1);
    if NewIndex < 0 then ShowError
    else
    begin
      FaceId := FCatalog[NewIndex].Id;
      ReloadFace(FaceId);
    end;
  except
    ShowError;
  end;
end;

procedure TPmxFaceCatalogToolbar.ListSelectionChanged(Sender: TObject);
begin
  UpdateButtons;
end;

procedure TPmxFaceCatalogToolbar.ReloadFace(const FaceId: string;
  FallbackIndex: Integer);
begin
  FList.Reload;
  if FaceId <> '' then FList.SelectFaceId(FaceId);
  if (FList.ItemIndex < 0) and (FallbackIndex >= 0) then
  begin
    if FallbackIndex >= FList.DisplayCount then
      FallbackIndex := FList.DisplayCount - 1;
    FList.ItemIndex := FallbackIndex;
  end;
  UpdateButtons;
end;

procedure TPmxFaceCatalogToolbar.RefreshFaces;
var
  CacheCleared: Boolean;
  Index, Source: Integer;
  FaceId: string;
begin
  Index := FList.ItemIndex;
  Source := FList.SelectedSourceIndex;
  FaceId := '';
  if Assigned(FCatalog) and (Source >= 0) and (Source < FCatalog.Count) then
    FaceId := FCatalog[Source].Id;
  if not Assigned(FCatalog) then Exit;
  try
    CacheCleared := FList.RefreshThumbnails;
    if not Assigned(FCatalog) or not FCatalog.LoadOrCreateDefault then
      ShowError
    else
    begin
      if Assigned(FList.Groups) and
        FList.Groups.RemoveUnknownFaces(FCatalog) then
        FList.Groups.SaveToFile;
      ReloadFace(FaceId, Index);
    end;
    if not CacheCleared then ShowError;
  except
    ShowError;
  end;
end;

procedure TPmxFaceCatalogToolbar.RenameFace;
begin
  if Assigned(FCatalog) and (FList.SelectedSourceIndex >= 0) and
    (FList.SelectedSourceIndex < FCatalog.Count) then
    FList.BeginEdit(FList.ItemIndex);
end;

procedure TPmxFaceCatalogToolbar.SetCatalog(ACatalog: TPmxFaceCatalogStorage);
begin
  FCatalog := ACatalog;
  UpdateButtons;
end;

procedure TPmxFaceCatalogToolbar.ShowError;
begin
  MessageBox(FList.Handle, '表情一覧を更新できませんでした。',
    'PMX 表情', MB_OK or MB_ICONERROR);
end;

procedure TPmxFaceCatalogToolbar.UpFace;
var
  Index, NewIndex: Integer;
  FaceId: string;
begin
  if FList.GroupIndex >= 0 then
  begin
    FList.MoveSelectedInGroup(-1);
    UpdateButtons;
    Exit;
  end;
  Index := FList.SelectedSourceIndex;
  if not Assigned(FCatalog) or (Index <= 0) or
    (Index >= FCatalog.Count) then Exit;
  try
    NewIndex := FCatalog.Move(Index, -1);
    if NewIndex < 0 then ShowError
    else
    begin
      FaceId := FCatalog[NewIndex].Id;
      ReloadFace(FaceId);
    end;
  except
    ShowError;
  end;
end;

procedure TPmxFaceCatalogToolbar.UpdateButtons;
var
  Index: Integer;
  Selected: Boolean;
begin
  Index := FList.SelectedSourceIndex;
  Selected := Assigned(FCatalog) and (Index >= 0) and
    (Index < FCatalog.Count);
  FAddButton.Enabled := Assigned(FCatalog);
  FCopyButton.Enabled := Selected;
  FDeleteButton.Enabled := Selected and not FCatalog.IsInitial(Index);
  if FList.GroupIndex >= 0 then
  begin
    FUpButton.Enabled := Selected and (FList.ItemIndex > 0);
    FDownButton.Enabled := Selected and
      (FList.ItemIndex < FList.DisplayCount - 1);
  end
  else
  begin
    FUpButton.Enabled := Selected and (Index > 0);
    FDownButton.Enabled := Selected and (Index < FCatalog.Count - 1);
  end;
end;

end.


