unit PmxPoseCatalogContextMenu;

// ポーズ一覧の参考UI準拠メニューと、その有効状態を担当する。

interface

uses
  System.Classes,
  Vcl.Menus,
  ShortcutAction,
  PmxPoseCatalogToolbar;

type
  TPmxPoseCatalogContextMenu = class
  private
    FAddItem: TMenuItem;
    FCopyItem: TMenuItem;
    FDeleteItem: TMenuItem;
    FDownItem: TMenuItem;
    FGroupItem: TMenuItem;
    FPopup: TPopupMenu;
    FRefreshItem: TMenuItem;
    FReuseItem: TMenuItem;
    FRenameItem: TMenuItem;
    FShortcuts: TShortcutAction;
    FToolbar: TPmxPoseCatalogToolbar;
    FUpItem: TMenuItem;
    FOnReuseVpd: TNotifyEvent;
    procedure AddItem(const Caption: string; ShortCut: TShortCut;
      Handler: TNotifyEvent; out Item: TMenuItem);
    procedure AddPose(Sender: TObject);
    procedure CopyPose(Sender: TObject);
    procedure DeletePose(Sender: TObject);
    procedure DownPose(Sender: TObject);
    function CanExecuteShortcut: Boolean;
    procedure ListKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure GroupClick(Sender: TObject);
    procedure RebuildGroupMenu;
    procedure Popup(Sender: TObject);
    procedure Refresh(Sender: TObject);
    procedure RenamePose(Sender: TObject);
    procedure ReuseVpd(Sender: TObject);
    procedure Separator;
    procedure UpPose(Sender: TObject);
  public
    // 右一覧へ操作メニューとAviUtl2内で有効な独自ショートカットを接続する。
    constructor Create(AToolbar: TPmxPoseCatalogToolbar);
    // 一覧からイベントとメニューを切り離し、ショートカット資源を解放する。
    destructor Destroy; override;
    property OnReuseVpd: TNotifyEvent read FOnReuseVpd write FOnReuseVpd;
  end;

implementation

uses
  Winapi.Windows,
  System.SysUtils,
  Vcl.Controls,
  PmxPoseCatalogGroups;

constructor TPmxPoseCatalogContextMenu.Create(
  AToolbar: TPmxPoseCatalogToolbar);
begin
  inherited Create;
  FToolbar := AToolbar;
  FPopup := TPopupMenu.Create(nil);
  FPopup.OnPopup := Popup;
  AddItem('新規追加(&R)', 0, AddPose, FAddItem);
  AddItem('コピー(&S)', ShortCut(Ord('C'), [ssCtrl]), CopyPose, FCopyItem);
  AddItem('登録済みVPDから追加...', 0, ReuseVpd, FReuseItem);
  AddItem('削除(&T)', ShortCut(VK_DELETE, []), DeletePose, FDeleteItem);
  AddItem('名称変更(&V)', ShortCut(VK_F2, []), RenamePose, FRenameItem);
  FGroupItem := TMenuItem.Create(FPopup);
  FGroupItem.Caption := 'グループに登録';
  FPopup.Items.Add(FGroupItem);
  Separator;
  AddItem('上へ移動(&W)', ShortCut(VK_UP, [ssCtrl]), UpPose, FUpItem);
  AddItem('下へ移動(&X)', ShortCut(VK_DOWN, [ssCtrl]), DownPose, FDownItem);
  Separator;
  AddItem('最新の情報(&Z)', ShortCut(VK_F5, []), Refresh, FRefreshItem);
  FToolbar.ListView.PopupMenu := FPopup;
  FShortcuts := TShortcutAction.Create;
  FShortcuts.Add(Ord('C'), [ssCtrl], FToolbar.CopyPose);
  FShortcuts.Add(VK_DELETE, [], FToolbar.DeletePose);
  FShortcuts.Add(VK_F2, [], FToolbar.RenamePose);
  FShortcuts.Add(VK_UP, [ssCtrl], FToolbar.UpPose);
  FShortcuts.Add(VK_DOWN, [ssCtrl], FToolbar.DownPose);
  FShortcuts.Add(VK_F5, [], FToolbar.RefreshPoses);
  FShortcuts.OnCanExecute := CanExecuteShortcut;
  FToolbar.ListView.OnKeyDown := ListKeyDown;
end;

destructor TPmxPoseCatalogContextMenu.Destroy;
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

function TPmxPoseCatalogContextMenu.CanExecuteShortcut: Boolean;
begin
  Result := Assigned(FToolbar) and Assigned(FToolbar.ListView) and
    not FToolbar.ListView.CaptionEditing;
end;

procedure TPmxPoseCatalogContextMenu.AddItem(const Caption: string;
  ShortCut: TShortCut; Handler: TNotifyEvent; out Item: TMenuItem);
begin
  Item := TMenuItem.Create(FPopup);
  Item.Caption := Caption;
  Item.ShortCut := ShortCut;
  Item.OnClick := Handler;
  FPopup.Items.Add(Item);
end;

procedure TPmxPoseCatalogContextMenu.AddPose(Sender: TObject);
begin
  FToolbar.AddPose;
end;

procedure TPmxPoseCatalogContextMenu.CopyPose(Sender: TObject);
begin
  FToolbar.CopyPose;
end;

procedure TPmxPoseCatalogContextMenu.DeletePose(Sender: TObject);
begin
  FToolbar.DeletePose;
end;

procedure TPmxPoseCatalogContextMenu.DownPose(Sender: TObject);
begin
  FToolbar.DownPose;
end;

procedure TPmxPoseCatalogContextMenu.ListKeyDown(Sender: TObject;
  var Key: Word; Shift: TShiftState);
begin
  try
    FShortcuts.KeyDown(Key, Shift);
  except
    Key := 0;
  end;
end;

procedure TPmxPoseCatalogContextMenu.GroupClick(Sender: TObject);
begin
  if Sender is TMenuItem then
    FToolbar.ListView.AssignSelectedToGroup(TMenuItem(Sender).Tag);
end;

procedure TPmxPoseCatalogContextMenu.RebuildGroupMenu;
var
  AllAssigned: Boolean;
  Groups: TPmxPoseCatalogGroups;
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
    FToolbar.ListView.GetSelectedPoseIds(Ids);
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
        if Groups[I].IndexOfPoseId(Ids[J]) < 0 then
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

procedure TPmxPoseCatalogContextMenu.Popup(Sender: TObject);
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
  FReuseItem.Enabled := Assigned(FToolbar.Catalog) and Assigned(FOnReuseVpd);
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

procedure TPmxPoseCatalogContextMenu.Refresh(Sender: TObject);
begin
  FToolbar.RefreshPoses;
end;

procedure TPmxPoseCatalogContextMenu.RenamePose(Sender: TObject);
begin
  FToolbar.RenamePose;
end;

procedure TPmxPoseCatalogContextMenu.ReuseVpd(Sender: TObject);
begin
  if Assigned(FOnReuseVpd) then FOnReuseVpd(Self);
end;

procedure TPmxPoseCatalogContextMenu.Separator;
var
  Item: TMenuItem;
begin
  Item := TMenuItem.Create(FPopup);
  Item.Caption := '-';
  FPopup.Items.Add(Item);
end;

procedure TPmxPoseCatalogContextMenu.UpPose(Sender: TObject);
begin
  FToolbar.UpPose;
end;

end.
