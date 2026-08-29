unit PmxPoseCatalogGroupBar;

// ポーズグループの選択、新規作成、名称編集、削除、並び替えを担当する。

interface

uses
  System.Classes, System.Types,
  Vcl.Controls, Vcl.ExtCtrls, Vcl.Forms, Vcl.Menus, Vcl.StdCtrls,
  PmxPoseCatalogGroups, PmxPoseCatalogListView;

type
  TPmxPoseCatalogGroupBar = class(TComponent)
  private
    FBar: TPanel;
    FCombo: TComboBox;
    FEdit: TEdit;
    FEditingIndex: Integer;
    FEndingEdit: Boolean;
    FGroups: TPmxPoseCatalogGroups;
    FList: TPmxPoseCatalogListView;
    FMenuAdd: TMenuItem;
    FMenuDelete: TMenuItem;
    FMenuDown: TMenuItem;
    FMenuRename: TMenuItem;
    FMenuUp: TMenuItem;
    FPopup: TPopupMenu;
    procedure AddMenu(const Caption: string; Handler: TNotifyEvent;
      out Item: TMenuItem);
    procedure BeginEdit(AIndex: Integer);
    procedure ComboChange(Sender: TObject);
    procedure ComboDrawItem(Control: TWinControl; Index: Integer;
      Rect: TRect; State: TOwnerDrawState);
    procedure ComboKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure EditExit(Sender: TObject);
    procedure EditKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure EditKeyUp(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure EndEdit(Accept: Boolean; ReturnFocus: Boolean = True);
    procedure GroupAdd(Sender: TObject);
    procedure GroupDelete(Sender: TObject);
    procedure GroupDown(Sender: TObject);
    procedure GroupMove(Delta: Integer);
    procedure GroupRename(Sender: TObject);
    procedure GroupUp(Sender: TObject);
    procedure Popup(Sender: TObject);
  public
    constructor Create(AOwner: TComponent; AParent: TWinControl;
      AList: TPmxPoseCatalogListView); reintroduce;
    procedure Rebuild(const SelectedGroupId: string = '');
    procedure SetGroups(AGroups: TPmxPoseCatalogGroups);
    property Bar: TPanel read FBar;
    property Combo: TComboBox read FCombo;
    property Groups: TPmxPoseCatalogGroups read FGroups;
  end;

implementation

uses
  Winapi.Windows, System.SysUtils, Vcl.Graphics,
  AviUtl2StyleColors;

const
  GroupEditNew = -1;
  GroupEditNone = -2;

constructor TPmxPoseCatalogGroupBar.Create(AOwner: TComponent;
  AParent: TWinControl; AList: TPmxPoseCatalogListView);
var
  Separator: TMenuItem;
begin
  inherited Create(AOwner);
  FList := AList;
  FBar := TPanel.Create(Self);
  FBar.Parent := AParent;
  FBar.Align := alTop;
  FBar.Height := 21;
  FBar.BevelOuter := bvNone;
  FBar.ParentBackground := False;
  FBar.Color := A2SCToolBarBackground;
  FCombo := TComboBox.Create(Self);
  FCombo.Style := csOwnerDrawFixed;
  FCombo.Parent := FBar;
  FCombo.Align := alClient;
  FCombo.Color := A2SCComboBackground;
  FCombo.Font.Color := A2SCComboText;
  FCombo.Font.Height := -12;
  FCombo.OnDrawItem := ComboDrawItem;
  FCombo.OnChange := ComboChange;
  FCombo.OnKeyDown := ComboKeyDown;
  FPopup := TPopupMenu.Create(Self);
  FPopup.OnPopup := Popup;
  AddMenu(#$65B0#$898F#$30B0#$30EB#$30FC#$30D7,
    GroupAdd, FMenuAdd);
  AddMenu(#$540D#$79F0#$5909#$66F4 + #9 + 'F2',
    GroupRename, FMenuRename);
  AddMenu(#$30B0#$30EB#$30FC#$30D7#$524A#$9664,
    GroupDelete, FMenuDelete);
  Separator := TMenuItem.Create(FPopup);
  Separator.Caption := '-';
  FPopup.Items.Add(Separator);
  AddMenu(#$4E0A#$3078#$79FB#$52D5 + #9 + 'Ctrl+Up', GroupUp, FMenuUp);
  AddMenu(#$4E0B#$3078#$79FB#$52D5 + #9 + 'Ctrl+Down', GroupDown, FMenuDown);
  FCombo.PopupMenu := FPopup;
  FEditingIndex := GroupEditNone;
  FEdit := TEdit.Create(Self);
  FEdit.AutoSize := False;
  FEdit.BorderStyle := bsSingle;
  FEdit.Parent := FBar;
  FEdit.Visible := False;
  FEdit.Color := A2SCEditBackground;
  FEdit.Font.Color := A2SCEditText;
  FEdit.Font.Height := -12;
  FEdit.OnKeyDown := EditKeyDown;
  FEdit.OnKeyUp := EditKeyUp;
  FEdit.OnExit := EditExit;
end;

procedure TPmxPoseCatalogGroupBar.AddMenu(const Caption: string;
  Handler: TNotifyEvent; out Item: TMenuItem);
begin
  Item := TMenuItem.Create(FPopup);
  Item.Caption := Caption;
  Item.OnClick := Handler;
  FPopup.Items.Add(Item);
end;

procedure TPmxPoseCatalogGroupBar.SetGroups(AGroups: TPmxPoseCatalogGroups);
begin
  FGroups := AGroups;
  Rebuild;
end;

procedure TPmxPoseCatalogGroupBar.Rebuild(const SelectedGroupId: string);
var
  I, SelectedIndex: Integer;
  Id: string;
begin
  Id := SelectedGroupId;
  if (Id = '') and Assigned(FGroups) and (FCombo.ItemIndex > 0) and
    (FCombo.ItemIndex - 1 < FGroups.Count) then
    Id := FGroups[FCombo.ItemIndex - 1].Id;
  FCombo.Items.BeginUpdate;
  try
    FCombo.Items.Clear;
    FCombo.Items.Add(#$5168#$30DD#$30FC#$30BA);
    if Assigned(FGroups) then
      for I := 0 to FGroups.Count - 1 do
        FCombo.Items.Add(Format('%d: %s', [I + 1, FGroups[I].Name]));
  finally
    FCombo.Items.EndUpdate;
  end;
  SelectedIndex := 0;
  if Assigned(FGroups) and (Id <> '') then
  begin
    I := FGroups.IndexOfId(Id);
    if I >= 0 then SelectedIndex := I + 1;
  end;
  FCombo.ItemIndex := SelectedIndex;
  FList.SetGroupIndex(SelectedIndex - 1);
end;

procedure TPmxPoseCatalogGroupBar.BeginEdit(AIndex: Integer);
begin
  if not Assigned(FGroups) or (AIndex < GroupEditNew) or
    (AIndex >= FGroups.Count) then Exit;
  FEditingIndex := AIndex;
  if AIndex >= 0 then FEdit.Text := FGroups[AIndex].Name
  else FEdit.Text := '';
  FEdit.SetBounds(FCombo.Left, FCombo.Top, FCombo.Width, FCombo.Height);
  FEdit.Visible := True;
  FEdit.BringToFront;
  FEdit.SetFocus;
  FEdit.SelectAll;
end;

procedure TPmxPoseCatalogGroupBar.EndEdit(Accept, ReturnFocus: Boolean);
var
  ExistingIndex, EditingIndex: Integer;
  Group: TPmxPoseCatalogGroup;
  GroupId, Name: string;
begin
  if not FEdit.Visible or FEndingEdit or not Assigned(FGroups) then Exit;
  FEndingEdit := True;
  try
    EditingIndex := FEditingIndex;
    Name := Trim(FEdit.Text);
    if Accept and (Name <> '') then
    begin
      ExistingIndex := FGroups.IndexOfName(Name);
      if (ExistingIndex >= 0) and (ExistingIndex <> EditingIndex) then
      begin
        MessageBox(FBar.Handle,
          #$540C#$3058#$540D#$524D#$306E#$30B0#$30EB#$30FC#$30D7#$304C +
          #$5B58#$5728#$3057#$307E#$3059#$3002,
          #$30DD#$30FC#$30BA#$30B0#$30EB#$30FC#$30D7,
          MB_OK or MB_ICONINFORMATION);
        Exit;
      end;
      if EditingIndex >= 0 then
      begin
        GroupId := FGroups[EditingIndex].Id;
        FGroups[EditingIndex].Name := Name;
      end
      else
      begin
        Group := FGroups.Add(Name);
        if not Assigned(Group) then Exit;
        GroupId := Group.Id;
      end;
      FGroups.SaveToFile;
    end
    else
      GroupId := '';
    FEdit.Visible := False;
    FEditingIndex := GroupEditNone;
    Rebuild(GroupId);
    if ReturnFocus and FCombo.CanFocus then FCombo.SetFocus;
  finally
    FEndingEdit := False;
  end;
end;

procedure TPmxPoseCatalogGroupBar.GroupAdd(Sender: TObject);
begin
  BeginEdit(GroupEditNew);
end;

procedure TPmxPoseCatalogGroupBar.GroupRename(Sender: TObject);
begin
  BeginEdit(FCombo.ItemIndex - 1);
end;

procedure TPmxPoseCatalogGroupBar.GroupDelete(Sender: TObject);
var
  Index: Integer;
begin
  if not Assigned(FGroups) then Exit;
  Index := FCombo.ItemIndex - 1;
  if (Index < 0) or (Index >= FGroups.Count) then Exit;
  FGroups.Delete(Index);
  FGroups.SaveToFile;
  Rebuild;
end;

procedure TPmxPoseCatalogGroupBar.GroupMove(Delta: Integer);
var
  GroupId: string;
  Index, NewIndex: Integer;
begin
  if not Assigned(FGroups) then Exit;
  Index := FCombo.ItemIndex - 1;
  NewIndex := Index + Delta;
  if (Index < 0) or (Index >= FGroups.Count) or
    (NewIndex < 0) or (NewIndex >= FGroups.Count) then Exit;
  GroupId := FGroups[Index].Id;
  FGroups.Exchange(Index, NewIndex);
  FGroups.SaveToFile;
  Rebuild(GroupId);
end;

procedure TPmxPoseCatalogGroupBar.GroupUp(Sender: TObject);
begin
  GroupMove(-1);
end;

procedure TPmxPoseCatalogGroupBar.GroupDown(Sender: TObject);
begin
  GroupMove(1);
end;

procedure TPmxPoseCatalogGroupBar.Popup(Sender: TObject);
var
  Index: Integer;
begin
  Index := FCombo.ItemIndex - 1;
  FMenuAdd.Enabled := Assigned(FGroups);
  FMenuRename.Enabled := Assigned(FGroups) and (Index >= 0) and
    (Index < FGroups.Count);
  FMenuDelete.Enabled := FMenuRename.Enabled;
  FMenuUp.Enabled := FMenuRename.Enabled and (Index > 0);
  FMenuDown.Enabled := FMenuRename.Enabled and (Index + 1 < FGroups.Count);
end;

procedure TPmxPoseCatalogGroupBar.ComboChange(Sender: TObject);
begin
  FList.SetGroupIndex(FCombo.ItemIndex - 1);
end;

procedure TPmxPoseCatalogGroupBar.ComboDrawItem(Control: TWinControl;
  Index: Integer; Rect: TRect; State: TOwnerDrawState);
var
  Combo: TComboBox;
begin
  Combo := TComboBox(Control);
  if odSelected in State then Combo.Canvas.Brush.Color := A2SCListViewSelection
  else Combo.Canvas.Brush.Color := A2SCComboBackground;
  Combo.Canvas.Font.Color := A2SCComboText;
  Combo.Canvas.FillRect(Rect);
  if (Index >= 0) and (Index < Combo.Items.Count) then
    Combo.Canvas.TextRect(Rect, Rect.Left + 4,
      Rect.Top + (Rect.Height - Combo.Canvas.TextHeight(Combo.Items[Index])) div 2,
      Combo.Items[Index]);
end;

procedure TPmxPoseCatalogGroupBar.ComboKeyDown(Sender: TObject;
  var Key: Word; Shift: TShiftState);
begin
  if (Key = VK_F2) and (Shift = []) then
  begin
    GroupRename(Sender);
    Key := 0;
  end
  else if (ssCtrl in Shift) and ((Key = VK_UP) or (Key = VK_DOWN)) then
  begin
    if Key = VK_UP then GroupMove(-1) else GroupMove(1);
    Key := 0;
  end;
end;

procedure TPmxPoseCatalogGroupBar.EditKeyDown(Sender: TObject;
  var Key: Word; Shift: TShiftState);
begin
  if (Key = VK_ESCAPE) and (Shift = []) then
  begin
    Key := 0;
    EndEdit(False);
  end;
end;

procedure TPmxPoseCatalogGroupBar.EditKeyUp(Sender: TObject;
  var Key: Word; Shift: TShiftState);
begin
  if (Key = VK_RETURN) and (Shift = []) then
  begin
    Key := 0;
    EndEdit(True);
  end;
end;

procedure TPmxPoseCatalogGroupBar.EditExit(Sender: TObject);
begin
  EndEdit(True, False);
end;

end.
