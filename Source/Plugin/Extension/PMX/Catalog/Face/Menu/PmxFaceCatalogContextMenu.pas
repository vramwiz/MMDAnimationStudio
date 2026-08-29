unit PmxFaceCatalogContextMenu;

// 表情一覧の参考UI準拠メニューと、その有効状態を担当する。

interface

uses
  System.Classes,
  Vcl.Menus,
  ShortcutAction,
  PmxFaceCatalogToolbar;

type
  TPmxFaceCatalogContextMenu = class
  private
    FAddItem: TMenuItem;
    FCopyItem: TMenuItem;
    FDeleteItem: TMenuItem;
    FDownItem: TMenuItem;
    FGroupItem: TMenuItem;
    FPopup: TPopupMenu;
    FRefreshItem: TMenuItem;
    FRenameItem: TMenuItem;
    FShortcuts: TShortcutAction;
    FToolbar: TPmxFaceCatalogToolbar;
    FUpItem: TMenuItem;
    procedure AddItem(const Caption: string; ShortCut: TShortCut;
      Handler: TNotifyEvent; out Item: TMenuItem);
    procedure AddFace(Sender: TObject);
    procedure CopyFace(Sender: TObject);
    procedure DeleteFace(Sender: TObject);
    procedure DownFace(Sender: TObject);
    function CanExecuteShortcut: Boolean;
    procedure ListKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure GroupClick(Sender: TObject);
    procedure RebuildGroupMenu;
    procedure Popup(Sender: TObject);
    procedure Refresh(Sender: TObject);
    procedure RenameFace(Sender: TObject);
    procedure Separator;
    procedure UpFace(Sender: TObject);
  public
    // 右一覧へ操作メニューとAviUtl2内で有効な独自ショートカットを接続する。
    constructor Create(AToolbar: TPmxFaceCatalogToolbar);
    // 一覧からイベントとメニューを切り離し、ショートカット資源を解放する。
    destructor Destroy; override;
  end;

implementation

uses
  Winapi.Windows,
  System.SysUtils,
  Vcl.Controls,
  PmxFaceCatalogGroups;

constructor TPmxFaceCatalogContextMenu.Create(
  AToolbar: TPmxFaceCatalogToolbar);
begin
  inherited Create;
  FToolbar := AToolbar;
  FPopup := TPopupMenu.Create(nil);
  FPopup.OnPopup := Popup;
  AddItem('新規追加(&R)', 0, AddFace, FAddItem);
  AddItem('コピー(&S)', ShortCut(Ord('C'), [ssCtrl]), CopyFace, FCopyItem);
  AddItem('削除(&T)', ShortCut(VK_DELETE, []), DeleteFace, FDeleteItem);
  AddItem('名称変更(&V)', ShortCut(VK_F2, []), RenameFace, FRenameItem);
  FGroupItem := TMenuItem.Create(FPopup);
  FGroupItem.Caption := 'グループに登録';
  FPopup.Items.Add(FGroupItem);
  Separator;
  AddItem('上へ移動(&W)', ShortCut(VK_UP, [ssCtrl]), UpFace, FUpItem);
  AddItem('下へ移動(&X)', ShortCut(VK_DOWN, [ssCtrl]), DownFace, FDownItem);
  Separator;
  AddItem('最新の情報(&Z)', ShortCut(VK_F5, []), Refresh, FRefreshItem);
  FToolbar.ListView.PopupMenu := FPopup;
  FShortcuts := TShortcutAction.Create;
  FShortcuts.Add(Ord('C'), [ssCtrl], FToolbar.CopyFace);
  FShortcuts.Add(VK_DELETE, [], FToolbar.DeleteFace);
  FShortcuts.Add(VK_F2, [], FToolbar.RenameFace);
  FShortcuts.Add(VK_UP, [ssCtrl], FToolbar.UpFace);
  FShortcuts.Add(VK_DOWN, [ssCtrl], FToolbar.DownFace);
  FShortcuts.Add(VK_F5, [], FToolbar.RefreshFaces);
  FShortcuts.OnCanExecute := CanExecuteShortcut;
  FToolbar.ListView.OnKeyDown := ListKeyDown;
end;

destructor TPmxFaceCatalogContextMenu.Destroy;
begin
  if Assigned(FToolbar) and Assigned(FToolbar.ListView) then
    FToolbar.ListView.OnKeyDown := nil;
  FShortcuts.Free;
  if Assigned(FToolbar) and Assigned(FToolbar.ListView) and
    (FToolbar.ListView.PopupMenu = FPopup) then
    FToolbar.ListView.PopupMenu := nil;
  FPopup.Free;
  inherited;
end;

function TPmxFaceCatalogContextMenu.CanExecuteShortcut: Boolean;
begin
  Result := Assigned(FToolbar) and Assigned(FToolbar.ListView) and
    not FToolbar.ListView.CaptionEditing;
end;

procedure TPmxFaceCatalogContextMenu.AddItem(const Caption: string;
  ShortCut: TShortCut; Handler: TNotifyEvent; out Item: TMenuItem);
begin
  Item := TMenuItem.Create(FPopup);
  Item.Caption := Caption;
  Item.ShortCut := ShortCut;
  Item.OnClick := Handler;
  FPopup.Items.Add(Item);
end;

procedure TPmxFaceCatalogContextMenu.AddFace(Sender: TObject);
begin
  FToolbar.AddFace;
end;

procedure TPmxFaceCatalogContextMenu.CopyFace(Sender: TObject);
begin
  FToolbar.CopyFace;
end;

procedure TPmxFaceCatalogContextMenu.DeleteFace(Sender: TObject);
begin
  FToolbar.DeleteFace;
end;

procedure TPmxFaceCatalogContextMenu.DownFace(Sender: TObject);
begin
  FToolbar.DownFace;
end;

procedure TPmxFaceCatalogContextMenu.ListKeyDown(Sender: TObject;
  var Key: Word; Shift: TShiftState);
begin
  try
    FShortcuts.KeyDown(Key, Shift);
  except
    Key := 0;
  end;
end;

procedure TPmxFaceCatalogContextMenu.GroupClick(Sender: TObject);
begin
  if Sender is TMenuItem then
    FToolbar.ListView.AssignSelectedToGroup(TMenuItem(Sender).Tag);
end;

procedure TPmxFaceCatalogContextMenu.RebuildGroupMenu;
var
  AllAssigned: Boolean;
  Groups: TPmxFaceCatalogGroups;
  I, J: Integer;
  Ids: TStringList;
  Item: TMenuItem;
begin
  FGroupItem.Clear;
  Groups := FToolbar.ListView.Groups;
  FGroupItem.Visible := Assigned(Groups);
  FGroupItem.Enabled := Assigned(Groups) and
    (FToolbar.ListView.SelectedCount > 0);
  if not FGroupItem.Enabled then Exit;
  Ids := TStringList.Create;
  try
    FToolbar.ListView.GetSelectedFaceIds(Ids);
    for I := 0 to Groups.Count - 1 do
    begin
      Item := TMenuItem.Create(FGroupItem);
      if I < 9 then
        Item.Caption := Format('&%d: %s', [I + 1,
          StringReplace(Groups[I].Name, '&', '&&', [rfReplaceAll])])
      else
        Item.Caption := Format('%d: %s', [I + 1,
          StringReplace(Groups[I].Name, '&', '&&', [rfReplaceAll])]);
      Item.Tag := I;
      AllAssigned := Ids.Count > 0;
      for J := 0 to Ids.Count - 1 do
        if Groups[I].IndexOfFaceId(Ids[J]) < 0 then
        begin
          AllAssigned := False;
          Break;
        end;
      Item.Checked := AllAssigned;
      Item.OnClick := GroupClick;
      FGroupItem.Add(Item);
    end;
    if Groups.Count > 0 then
    begin
      Item := TMenuItem.Create(FGroupItem);
      Item.Caption := '-';
      FGroupItem.Add(Item);
    end;
    Item := TMenuItem.Create(FGroupItem);
    Item.Caption := '&0: 所属解除';
    Item.Tag := -1;
    Item.OnClick := GroupClick;
    FGroupItem.Add(Item);
  finally
    Ids.Free;
  end;
end;

procedure TPmxFaceCatalogContextMenu.Popup(Sender: TObject);
var
  CatalogCount: Integer;
  Index: Integer;
  Selected: Boolean;
begin
  CatalogCount := 0;
  if Assigned(FToolbar.Catalog) then CatalogCount := FToolbar.Catalog.Count;
  Index := FToolbar.ListView.SelectedSourceIndex;
  Selected := (Index >= 0) and (Index < CatalogCount);
  RebuildGroupMenu;
  FAddItem.Enabled := Assigned(FToolbar.Catalog);
  FCopyItem.Enabled := Selected;
  FDeleteItem.Enabled := Selected and not FToolbar.Catalog.IsInitial(Index);
  FRenameItem.Enabled := Selected;
  if FToolbar.ListView.GroupIndex >= 0 then
  begin
    FUpItem.Enabled := Selected and (FToolbar.ListView.ItemIndex > 0);
    FDownItem.Enabled := Selected and
      (FToolbar.ListView.ItemIndex < FToolbar.ListView.DisplayCount - 1);
  end
  else
  begin
    FUpItem.Enabled := Selected and (Index > 0);
    FDownItem.Enabled := Selected and (Index < CatalogCount - 1);
  end;
  FRefreshItem.Enabled := Assigned(FToolbar.Catalog);
end;

procedure TPmxFaceCatalogContextMenu.Refresh(Sender: TObject);
begin
  FToolbar.RefreshFaces;
end;

procedure TPmxFaceCatalogContextMenu.RenameFace(Sender: TObject);
begin
  FToolbar.RenameFace;
end;

procedure TPmxFaceCatalogContextMenu.Separator;
var
  Item: TMenuItem;
begin
  Item := TMenuItem.Create(FPopup);
  Item.Caption := '-';
  FPopup.Items.Add(Item);
end;

procedure TPmxFaceCatalogContextMenu.UpFace(Sender: TObject);
begin
  FToolbar.UpFace;
end;

end.


