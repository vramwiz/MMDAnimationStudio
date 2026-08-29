unit PmxPoseCatalogToolbar;

// ポーズ一覧上部の5操作と、その有効状態・選択維持を担当する。

interface

uses
  System.Classes,
  System.ImageList,
  Vcl.Controls,
  Vcl.ImgList,
  ToolbarButtons,
  ToolbarIcon,
  PmxPoseCatalogStorage,
  PmxPoseCatalogListView;

type
  TPmxPoseCatalogToolbar = class(TToolbarButtons)
  private
    FAddButton: TToolbarIconItem;
    FCatalog: TPmxPoseCatalogStorage;
    FCopyButton: TToolbarIconItem;
    FDeleteButton: TToolbarIconItem;
    FDownButton: TToolbarIconItem;
    FImages: TImageList;
    FList: TPmxPoseCatalogListView;
    FUpButton: TToolbarIconItem;
    procedure ListSelectionChanged(Sender: TObject);
    procedure ReloadPose(const PoseId: string; FallbackIndex: Integer = -1);
    procedure ShowError;
    procedure UpdateButtons;
  public
    // 指定ポーズ一覧へ5操作のアイコンと選択連動を接続する。
    constructor Create(AOwner: TComponent;
      AList: TPmxPoseCatalogListView); reintroduce;
    // 空姿勢を追加し、追加位置を選択する。
    procedure AddPose;
    // 選択ポーズを新しいPoseUIDで複製し、複製位置を選択する。
    procedure CopyPose;
    // 初期状態以外の選択ポーズを確認後に削除する。
    procedure DeletePose;
    // 選択ポーズを1つ下へ移動し、移動後の位置を選択する。
    procedure DownPose;
    // 保存JSONとサムネイルキャッシュを読み直して一覧を再構築する。
    procedure RefreshPoses;
    // 選択ポーズの一覧内名称編集を開始する。
    procedure RenamePose;
    // 操作対象のポーズカタログを差し替え、ボタン有効状態を更新する。
    procedure SetCatalog(ACatalog: TPmxPoseCatalogStorage);
    // 選択ポーズを1つ上へ移動し、移動後の位置を選択する。
    procedure UpPose;
    property Catalog: TPmxPoseCatalogStorage read FCatalog;
    property ListView: TPmxPoseCatalogListView read FList;
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

constructor TPmxPoseCatalogToolbar.Create(AOwner: TComponent;
  AList: TPmxPoseCatalogListView);
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
  FAddButton := AddIcon('ポーズを追加', 0, AddPose);
  FCopyButton := AddIcon('ポーズを複製', 1, CopyPose);
  FDeleteButton := AddIcon('ポーズを削除', 2, DeletePose);
  FUpButton := AddIcon('上に移動', 3, UpPose);
  FDownButton := AddIcon('下に移動', 4, DownPose);
  FList.OnSelectionChanged := ListSelectionChanged;
  UpdateButtons;
end;

procedure TPmxPoseCatalogToolbar.AddPose;
var
  Index: Integer;
  PoseId: string;
begin
  if not Assigned(FCatalog) then Exit;
  try
    Index := FCatalog.Add;
    if Index < 0 then
    begin
      ShowError;
      Exit;
    end;
    PoseId := FCatalog[Index].Id;
    FList.AdoptPoseInCurrentGroup(PoseId, FList.ItemIndex);
    UpdateButtons;
  except
    ShowError;
  end;
end;

procedure TPmxPoseCatalogToolbar.CopyPose;
var
  Index, NewIndex: Integer;
  PoseId: string;
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
    PoseId := FCatalog[NewIndex].Id;
    FList.AdoptPoseInCurrentGroup(PoseId, FList.ItemIndex + 1);
    UpdateButtons;
  except
    ShowError;
  end;
end;

procedure TPmxPoseCatalogToolbar.DeletePose;
var
  Dialog: TFormConfirmDialog;
  Index: Integer;
  PoseId: string;
begin
  Index := FList.SelectedSourceIndex;
  if not Assigned(FCatalog) or FCatalog.IsInitial(Index) then Exit;
  PoseId := FCatalog[Index].Id;
  Dialog := TFormConfirmDialog.Create(FList);
  try
    if Dialog.Execute('選択したポーズを削除しますか？') <> mrOk then Exit;
  finally
    Dialog.Free;
  end;
  try
    if FCatalog.Remove(Index) then
    begin
      if Assigned(FList.Groups) then
      begin
        FList.Groups.RemovePoseFromAll(PoseId);
        FList.Groups.SaveToFile;
      end;
      ReloadPose('', FList.ItemIndex);
    end
    else
      ShowError;
  except
    ShowError;
  end;
end;

procedure TPmxPoseCatalogToolbar.DownPose;
var
  Index, NewIndex: Integer;
  PoseId: string;
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
      PoseId := FCatalog[NewIndex].Id;
      ReloadPose(PoseId);
    end;
  except
    ShowError;
  end;
end;

procedure TPmxPoseCatalogToolbar.ListSelectionChanged(Sender: TObject);
begin
  UpdateButtons;
end;

procedure TPmxPoseCatalogToolbar.ReloadPose(const PoseId: string;
  FallbackIndex: Integer);
begin
  FList.Reload;
  if PoseId <> '' then FList.SelectPoseId(PoseId);
  if (FList.ItemIndex < 0) and (FallbackIndex >= 0) then
  begin
    if FallbackIndex >= FList.DisplayCount then
      FallbackIndex := FList.DisplayCount - 1;
    FList.ItemIndex := FallbackIndex;
  end;
  UpdateButtons;
end;

procedure TPmxPoseCatalogToolbar.RefreshPoses;
var
  CacheCleared: Boolean;
  Index, Source: Integer;
  PoseId: string;
begin
  Index := FList.ItemIndex;
  Source := FList.SelectedSourceIndex;
  PoseId := '';
  if Assigned(FCatalog) and (Source >= 0) and (Source < FCatalog.Count) then
    PoseId := FCatalog[Source].Id;
  if not Assigned(FCatalog) then Exit;
  try
    CacheCleared := FList.RefreshThumbnails;
    if not Assigned(FCatalog) or not FCatalog.LoadOrCreateDefault then
      ShowError
    else
    begin
      if Assigned(FList.Groups) and
        FList.Groups.RemoveUnknownPoses(FCatalog) then
        FList.Groups.SaveToFile;
      ReloadPose(PoseId, Index);
    end;
    if not CacheCleared then ShowError;
  except
    ShowError;
  end;
end;

procedure TPmxPoseCatalogToolbar.RenamePose;
begin
  if Assigned(FCatalog) and (FList.SelectedSourceIndex >= 0) and
    (FList.SelectedSourceIndex < FCatalog.Count) then
    FList.BeginEdit(FList.ItemIndex);
end;

procedure TPmxPoseCatalogToolbar.SetCatalog(ACatalog: TPmxPoseCatalogStorage);
begin
  FCatalog := ACatalog;
  UpdateButtons;
end;

procedure TPmxPoseCatalogToolbar.ShowError;
begin
  MessageBox(FList.Handle, 'ポーズ一覧を更新できませんでした。',
    'PMX ポーズ', MB_OK or MB_ICONERROR);
end;

procedure TPmxPoseCatalogToolbar.UpPose;
var
  Index, NewIndex: Integer;
  PoseId: string;
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
      PoseId := FCatalog[NewIndex].Id;
      ReloadPose(PoseId);
    end;
  except
    ShowError;
  end;
end;

procedure TPmxPoseCatalogToolbar.UpdateButtons;
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
