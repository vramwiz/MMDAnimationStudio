unit PmxMotionCatalogContextMenu;

// モーション一覧の右クリック操作とショートカットをツールバー操作へ集約する。

interface

uses
  System.Classes,
  Vcl.Menus,
  ShortcutAction,
  PmxMotionCatalogToolbar;

type
  TPmxMotionCatalogContextMenu = class
  private
    FPopup: TPopupMenu;
    FShortcuts: TShortcutAction;
    FToolbar: TPmxMotionCatalogToolbar;
    procedure AddMotion(Sender: TObject);
    procedure CopyMotion(Sender: TObject);
    procedure DeleteMotion(Sender: TObject);
    procedure DownMotion(Sender: TObject);
    function CanExecuteShortcut: Boolean;
    procedure ListKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure Refresh(Sender: TObject);
    procedure RenameMotion(Sender: TObject);
    procedure UpMotion(Sender: TObject);
  public
    // 一覧へ右クリックメニューとキーボード操作を接続する。
    constructor Create(AToolbar: TPmxMotionCatalogToolbar);
    // 接続したメニュー、ショートカット、一覧イベントを解除する。
    destructor Destroy; override;
  end;

implementation

uses
  Winapi.Windows,
  Vcl.Controls;

procedure AddMenu(Popup: TPopupMenu; const Caption: string; Shortcut: TShortCut;
  Handler: TNotifyEvent);
var
  Item: TMenuItem;
begin
  Item := TMenuItem.Create(Popup);
  Item.Caption := Caption;
  Item.ShortCut := Shortcut;
  Item.OnClick := Handler;
  Popup.Items.Add(Item);
end;

constructor TPmxMotionCatalogContextMenu.Create(AToolbar: TPmxMotionCatalogToolbar);
begin
  inherited Create;
  FToolbar := AToolbar;
  FPopup := TPopupMenu.Create(nil);
  AddMenu(FPopup, 'VMDを追加(&R)...', 0, AddMotion);
  AddMenu(FPopup, 'コピー(&S)', ShortCut(Ord('C'), [ssCtrl]), CopyMotion);
  AddMenu(FPopup, '削除(&T)', ShortCut(VK_DELETE, []), DeleteMotion);
  AddMenu(FPopup, '名称変更(&V)', ShortCut(VK_F2, []), RenameMotion);
  AddMenu(FPopup, '-', 0, nil);
  AddMenu(FPopup, '上へ移動(&W)', ShortCut(VK_UP, [ssCtrl]), UpMotion);
  AddMenu(FPopup, '下へ移動(&X)', ShortCut(VK_DOWN, [ssCtrl]), DownMotion);
  AddMenu(FPopup, '-', 0, nil);
  AddMenu(FPopup, '最新の情報(&Z)', ShortCut(VK_F5, []), Refresh);
  FToolbar.ListView.PopupMenu := FPopup;
  FShortcuts := TShortcutAction.Create;
  FShortcuts.Add(Ord('C'), [ssCtrl], FToolbar.CopyMotion);
  FShortcuts.Add(VK_DELETE, [], FToolbar.DeleteMotion);
  FShortcuts.Add(VK_F2, [], FToolbar.RenameMotion);
  FShortcuts.Add(VK_UP, [ssCtrl], FToolbar.UpMotion);
  FShortcuts.Add(VK_DOWN, [ssCtrl], FToolbar.DownMotion);
  FShortcuts.Add(VK_F5, [], FToolbar.RefreshMotions);
  FShortcuts.OnCanExecute := CanExecuteShortcut;
  FToolbar.ListView.OnKeyDown := ListKeyDown;
end;

destructor TPmxMotionCatalogContextMenu.Destroy;
begin
  if Assigned(FToolbar) and Assigned(FToolbar.ListView) then
    FToolbar.ListView.OnKeyDown := nil;
  FShortcuts.Free;
  if Assigned(FToolbar) and Assigned(FToolbar.ListView) and
    (FToolbar.ListView.PopupMenu = FPopup) then FToolbar.ListView.PopupMenu := nil;
  FPopup.Free;
  inherited;
end;

function TPmxMotionCatalogContextMenu.CanExecuteShortcut: Boolean;
begin
  Result := Assigned(FToolbar) and Assigned(FToolbar.ListView) and
    not FToolbar.ListView.CaptionEditing;
end;

procedure TPmxMotionCatalogContextMenu.ListKeyDown(Sender: TObject;
  var Key: Word; Shift: TShiftState);
begin
  try
    FShortcuts.KeyDown(Key, Shift);
  except
    Key := 0;
  end;
end;

procedure TPmxMotionCatalogContextMenu.AddMotion(Sender: TObject);
begin
  FToolbar.AddMotion;
end;

procedure TPmxMotionCatalogContextMenu.CopyMotion(Sender: TObject);
begin
  FToolbar.CopyMotion;
end;

procedure TPmxMotionCatalogContextMenu.DeleteMotion(Sender: TObject);
begin
  FToolbar.DeleteMotion;
end;

procedure TPmxMotionCatalogContextMenu.DownMotion(Sender: TObject);
begin
  FToolbar.DownMotion;
end;

procedure TPmxMotionCatalogContextMenu.Refresh(Sender: TObject);
begin
  FToolbar.RefreshMotions;
end;

procedure TPmxMotionCatalogContextMenu.RenameMotion(Sender: TObject);
begin
  FToolbar.RenameMotion;
end;

procedure TPmxMotionCatalogContextMenu.UpMotion(Sender: TObject);
begin
  FToolbar.UpMotion;
end;

end.
