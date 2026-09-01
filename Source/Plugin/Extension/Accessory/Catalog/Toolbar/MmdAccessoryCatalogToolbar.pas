unit MmdAccessoryCatalogToolbar;

// アクセサリ一覧の追加、複製、削除、上下移動を共通操作として提供する。

interface

uses
  System.Classes,
  System.ImageList,
  Vcl.Controls,
  Vcl.ImgList,
  ToolbarButtons,
  ToolbarIcon,
  MmdAccessoryCatalog,
  MmdAccessoryCatalogListView;

type
  TMmdAccessoryCatalogToolbar = class(TToolbarButtons)
  private
    FAddButton: TToolbarIconItem;
    FCatalog: TMmdAccessoryCatalog;
    FCopyButton: TToolbarIconItem;
    FDeleteButton: TToolbarIconItem;
    FDownButton: TToolbarIconItem;
    FImages: TImageList;
    FList: TMmdAccessoryCatalogListView;
    FOnAddAccessory: TNotifyEvent;
    FOnChanged: TNotifyEvent;
    FUpButton: TToolbarIconItem;
    procedure ListSelectionChanged(Sender: TObject);
    procedure ReloadAccessory(const Id: string; FallbackIndex: Integer = -1);
    procedure ShowError;
    procedure UpdateButtons;
  public
    // 5操作アイコンを一覧に接続する。
    constructor Create(AOwner: TComponent;
      AList: TMmdAccessoryCatalogListView); reintroduce;
    // OnAddAccessoryを通知して、親画面のファイル選択またはD&D登録処理を呼び出す。
    procedure AddAccessory;
    // 選択項目を同じ原本を参照する別UIDとして複製し、その項目を選択する。
    procedure CopyAccessory;
    // 確認後に選択項目だけを削除し、共有原本は残す。
    procedure DeleteAccessory;
    // 選択項目を一覧の1つ下へ移動する。
    procedure DownAccessory;
    // サムネイルキャッシュを破棄し、表示中の項目を生成待ちへ戻す。
    procedure RefreshAccessories;
    // 選択項目の表示名を入力ダイアログで変更する。
    procedure RenameAccessory;
    // 操作対象カタログを切り替え、nil時は全操作を無効にする。
    procedure SetCatalog(ACatalog: TMmdAccessoryCatalog);
    // 選択項目を一覧の1つ上へ移動する。
    procedure UpAccessory;
    // 接続中の保存層・一覧と、登録／変更通知を親画面から設定・参照する。
    property Catalog: TMmdAccessoryCatalog read FCatalog;
    property ListView: TMmdAccessoryCatalogListView read FList;
    property OnAddAccessory: TNotifyEvent read FOnAddAccessory
      write FOnAddAccessory;
    property OnChanged: TNotifyEvent read FOnChanged write FOnChanged;
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

constructor TMmdAccessoryCatalogToolbar.Create(AOwner: TComponent;
  AList: TMmdAccessoryCatalogListView);
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
  FAddButton := AddIcon('ファイルを追加', 0, AddAccessory);
  FCopyButton := AddIcon('アクセサリを複製', 1, CopyAccessory);
  FDeleteButton := AddIcon('アクセサリを削除', 2, DeleteAccessory);
  FUpButton := AddIcon('上に移動', 3, UpAccessory);
  FDownButton := AddIcon('下に移動', 4, DownAccessory);
  FList.OnSelectionChanged := ListSelectionChanged;
  UpdateButtons;
end;

procedure TMmdAccessoryCatalogToolbar.AddAccessory;
begin
  if Assigned(FCatalog) and Assigned(FOnAddAccessory) then
    FOnAddAccessory(Self);
end;

procedure TMmdAccessoryCatalogToolbar.CopyAccessory;
var
  Index, NewIndex: Integer;
begin
  Index := FList.SelectedSourceIndex;
  if not Assigned(FCatalog) or (Index < 0) or (Index >= FCatalog.Count) then
    Exit;
  try
    NewIndex := FCatalog.Duplicate(Index);
    if NewIndex < 0 then ShowError
    else ReloadAccessory(FCatalog[NewIndex].Id);
  except
    ShowError;
  end;
end;

procedure TMmdAccessoryCatalogToolbar.DeleteAccessory;
var
  Dialog: TFormConfirmDialog;
  Index: Integer;
begin
  Index := FList.SelectedSourceIndex;
  if not Assigned(FCatalog) or (Index < 0) or (Index >= FCatalog.Count) then
    Exit;
  Dialog := TFormConfirmDialog.Create(FList);
  try
    if Dialog.Execute('選択したアクセサリを削除しますか？') <> mrOk then Exit;
  finally
    Dialog.Free;
  end;
  try
    if FCatalog.Remove(Index) then ReloadAccessory('', Index)
    else ShowError;
  except
    ShowError;
  end;
end;

procedure TMmdAccessoryCatalogToolbar.DownAccessory;
var
  Index, NewIndex: Integer;
begin
  Index := FList.SelectedSourceIndex;
  if not Assigned(FCatalog) or (Index < 0) or
    (Index >= FCatalog.Count - 1) then Exit;
  try
    NewIndex := FCatalog.Move(Index, 1);
    if NewIndex < 0 then ShowError
    else ReloadAccessory(FCatalog[NewIndex].Id);
  except
    ShowError;
  end;
end;

procedure TMmdAccessoryCatalogToolbar.ListSelectionChanged(Sender: TObject);
begin
  UpdateButtons;
end;

procedure TMmdAccessoryCatalogToolbar.RefreshAccessories;
var
  Id: string;
  Index: Integer;
begin
  if not Assigned(FCatalog) then Exit;
  Index := FList.SelectedSourceIndex;
  Id := '';
  if (Index >= 0) and (Index < FCatalog.Count) then Id := FCatalog[Index].Id;
  try
    if not FCatalog.LoadFromFile or not FList.RefreshThumbnails then ShowError
    else ReloadAccessory(Id, Index);
  except
    ShowError;
  end;
end;

procedure TMmdAccessoryCatalogToolbar.ReloadAccessory(const Id: string;
  FallbackIndex: Integer);
begin
  FList.Reload;
  if Id <> '' then FList.SelectItemId(Id);
  if (FList.ItemIndex < 0) and (FallbackIndex >= 0) then
  begin
    if FallbackIndex >= FList.DisplayCount then
      FallbackIndex := FList.DisplayCount - 1;
    FList.ItemIndex := FallbackIndex;
  end;
  UpdateButtons;
  if Assigned(FOnChanged) then FOnChanged(Self);
end;

procedure TMmdAccessoryCatalogToolbar.RenameAccessory;
begin
  if Assigned(FCatalog) and (FList.SelectedSourceIndex >= 0) and
    (FList.SelectedSourceIndex < FCatalog.Count) then
    FList.BeginEdit(FList.ItemIndex);
end;

procedure TMmdAccessoryCatalogToolbar.SetCatalog(
  ACatalog: TMmdAccessoryCatalog);
begin
  FCatalog := ACatalog;
  UpdateButtons;
end;

procedure TMmdAccessoryCatalogToolbar.ShowError;
begin
  MessageBox(FList.Handle, 'アクセサリ一覧を更新できませんでした。',
    'アクセサリ', MB_OK or MB_ICONERROR);
end;

procedure TMmdAccessoryCatalogToolbar.UpAccessory;
var
  Index, NewIndex: Integer;
begin
  Index := FList.SelectedSourceIndex;
  if not Assigned(FCatalog) or (Index <= 0) or (Index >= FCatalog.Count) then
    Exit;
  try
    NewIndex := FCatalog.Move(Index, -1);
    if NewIndex < 0 then ShowError
    else ReloadAccessory(FCatalog[NewIndex].Id);
  except
    ShowError;
  end;
end;

procedure TMmdAccessoryCatalogToolbar.UpdateButtons;
var
  Index: Integer;
  Selected: Boolean;
begin
  Index := FList.SelectedSourceIndex;
  Selected := Assigned(FCatalog) and (Index >= 0) and
    (Index < FCatalog.Count);
  FAddButton.Enabled := Assigned(FCatalog) and Assigned(FOnAddAccessory);
  FCopyButton.Enabled := Selected;
  FDeleteButton.Enabled := Selected;
  FUpButton.Enabled := Selected and (Index > 0);
  FDownButton.Enabled := Selected and (Index < FCatalog.Count - 1);
end;

end.
