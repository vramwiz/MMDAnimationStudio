unit MmdAccessoryCatalogContextMenu;

// アクセサリ一覧の右クリックメニュとキーボード操作を接続する。

interface

uses
  System.Classes,
  Vcl.Menus,
  ShortcutAction,
  MmdAccessoryCatalogToolbar;

type
  TMmdAccessoryCatalogContextMenu = class
  private
    FPopup: TPopupMenu;
    FShortcuts: TShortcutAction;
    FToolbar: TMmdAccessoryCatalogToolbar;
    procedure AddAccessory(Sender: TObject);
    function CanExecuteShortcut: Boolean;
    procedure CopyAccessory(Sender: TObject);
    procedure DeleteAccessory(Sender: TObject);
    procedure DownAccessory(Sender: TObject);
    procedure ListKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure Refresh(Sender: TObject);
    procedure RenameAccessory(Sender: TObject);
    procedure UpAccessory(Sender: TObject);
  public
    // Toolbarの操作を右クリックメニューと一覧のショートカットへ接続する。
    constructor Create(AToolbar: TMmdAccessoryCatalogToolbar);
    // 一覧へ設定したメニューとキーイベントを解除してから所有部品を解放する。
    destructor Destroy; override;
  end;

implementation

uses
  Winapi.Windows,
  Vcl.Controls;

procedure AddMenu(Popup: TPopupMenu; const Caption: string;
  Shortcut: TShortCut; Handler: TNotifyEvent);
var
  Item: TMenuItem;
begin
  Item := TMenuItem.Create(Popup);
  Item.Caption := Caption;
  Item.ShortCut := Shortcut;
  Item.OnClick := Handler;
  Popup.Items.Add(Item);
end;

constructor TMmdAccessoryCatalogContextMenu.Create(
  AToolbar: TMmdAccessoryCatalogToolbar);
begin
  inherited Create;
  FToolbar := AToolbar;
  FPopup := TPopupMenu.Create(nil);
  AddMenu(FPopup, 'ファイルを追加(&R)...', 0, AddAccessory);
  AddMenu(FPopup, 'コピー(&S)', ShortCut(Ord('C'), [ssCtrl]),
    CopyAccessory);
  AddMenu(FPopup, '削除(&T)', ShortCut(VK_DELETE, []), DeleteAccessory);
  AddMenu(FPopup, '名称変更(&V)', ShortCut(VK_F2, []), RenameAccessory);
  AddMenu(FPopup, '-', 0, nil);
  AddMenu(FPopup, '上へ移動(&W)', ShortCut(VK_UP, [ssCtrl]), UpAccessory);
  AddMenu(FPopup, '下へ移動(&X)', ShortCut(VK_DOWN, [ssCtrl]),
    DownAccessory);
  AddMenu(FPopup, '-', 0, nil);
  AddMenu(FPopup, '最新の情報(&Z)', ShortCut(VK_F5, []), Refresh);
  FToolbar.ListView.PopupMenu := FPopup;
  FShortcuts := TShortcutAction.Create;
  FShortcuts.Add(Ord('C'), [ssCtrl], FToolbar.CopyAccessory);
  FShortcuts.Add(VK_DELETE, [], FToolbar.DeleteAccessory);
  FShortcuts.Add(VK_F2, [], FToolbar.RenameAccessory);
  FShortcuts.Add(VK_UP, [ssCtrl], FToolbar.UpAccessory);
  FShortcuts.Add(VK_DOWN, [ssCtrl], FToolbar.DownAccessory);
  FShortcuts.Add(VK_F5, [], FToolbar.RefreshAccessories);
  FShortcuts.OnCanExecute := CanExecuteShortcut;
  FToolbar.ListView.OnKeyDown := ListKeyDown;
end;

destructor TMmdAccessoryCatalogContextMenu.Destroy;
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

procedure TMmdAccessoryCatalogContextMenu.AddAccessory(Sender: TObject);
begin
  FToolbar.AddAccessory;
end;

function TMmdAccessoryCatalogContextMenu.CanExecuteShortcut: Boolean;
begin
  Result := Assigned(FToolbar) and Assigned(FToolbar.ListView) and
    not FToolbar.ListView.CaptionEditing;
end;

procedure TMmdAccessoryCatalogContextMenu.CopyAccessory(Sender: TObject);
begin
  FToolbar.CopyAccessory;
end;

procedure TMmdAccessoryCatalogContextMenu.DeleteAccessory(Sender: TObject);
begin
  FToolbar.DeleteAccessory;
end;

procedure TMmdAccessoryCatalogContextMenu.DownAccessory(Sender: TObject);
begin
  FToolbar.DownAccessory;
end;

procedure TMmdAccessoryCatalogContextMenu.ListKeyDown(Sender: TObject;
  var Key: Word; Shift: TShiftState);
begin
  try
    FShortcuts.KeyDown(Key, Shift);
  except
    Key := 0;
  end;
end;

procedure TMmdAccessoryCatalogContextMenu.Refresh(Sender: TObject);
begin
  FToolbar.RefreshAccessories;
end;

procedure TMmdAccessoryCatalogContextMenu.RenameAccessory(Sender: TObject);
begin
  FToolbar.RenameAccessory;
end;

procedure TMmdAccessoryCatalogContextMenu.UpAccessory(Sender: TObject);
begin
  FToolbar.UpAccessory;
end;

end.
