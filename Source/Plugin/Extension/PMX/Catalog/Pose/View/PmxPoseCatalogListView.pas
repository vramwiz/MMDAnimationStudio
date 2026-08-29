unit PmxPoseCatalogListView;
// 選択PMXのポーズを、全件または独自グループのPoseUID順で画像表示する。

interface
uses
  System.Classes, System.Generics.Collections, System.Types,
  Vcl.Controls, Vcl.ExtCtrls, Vcl.Graphics, ItemListView,
  PmxCatalogStorage, PmxPoseCatalogStorage, PmxPoseCatalogGroups,
  PmxCatalogThumbnailCache, PmxCatalogThumbnailRenderer;

type
  TPmxPoseCatalogListView = class(TCustomItemListView)
  private
    FDisplayIndices: TList<Integer>;
    FFailedIds: TStringList;
    FGroupIndex: Integer;
    FGroups: TPmxPoseCatalogGroups;
    FModel: TPmxCatalogItem;
    FPoseCatalog: TPmxPoseCatalogStorage;
    FThumbnailCache: TPmxCatalogThumbnailCache;
    FThumbnailQueue: TStringList;
    FThumbnailRenderer: TPmxCatalogThumbnailRenderer;
    FThumbnailTimer: TTimer;
    function FindDisplayIndex(const Id: string): Integer;
    function FindPoseIndex(const Id: string): Integer;
    function SourceIndex(DisplayIndex: Integer): Integer;
    function VariantKey(DisplayIndex: Integer): string;
    procedure QueueThumbnail(const Id: string);
    procedure RebuildDisplay(PreserveSelection: Boolean = True);
    procedure ThumbnailTimer(Sender: TObject);
  protected
    function GetItemCount: Integer; override;
    function GetItemText(Index: Integer): string; override;
    procedure SetItemText(Index: Integer; const Value: string); override;
    procedure DrawItemImage(Index: Integer; const Bounds: TRect;
      Target: TCanvas); override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // 追加・複製したPoseUIDを現在グループへ挿入して選択する。
    procedure AdoptPoseInCurrentGroup(const PoseId: string;
      InsertIndex: Integer = -1);
    // 選択項目を指定グループへ所属させる。-1は所属解除。
    procedure AssignSelectedToGroup(AGroupIndex: Integer);
    function DisplayName(Index: Integer): string;
    // 選択PoseUID群をグループメニュー用に列挙する。
    procedure GetSelectedPoseIds(Dest: TStrings);
    // 現在グループ内で選択ポーズを上下へ移動する。
    function MoveSelectedInGroup(Delta: Integer): Boolean;
    function RefreshThumbnails: Boolean;
    procedure Reload;
    // 選択表示項目に対応するカタログ上の位置を返す。
    function SelectedSourceIndex: Integer;
    procedure SelectPoseId(const PoseId: string);
    procedure SetData(AModel: TPmxCatalogItem;
      APoseCatalog: TPmxPoseCatalogStorage;
      AGroups: TPmxPoseCatalogGroups = nil);
    // -1は全ポーズ、それ以外は対応グループだけを表示する。
    procedure SetGroupIndex(const Value: Integer);
    procedure SetThumbnailServices(ACache: TPmxCatalogThumbnailCache;
      ARenderer: TPmxCatalogThumbnailRenderer);
    property GroupIndex: Integer read FGroupIndex;
    property Groups: TPmxPoseCatalogGroups read FGroups;
  end;
implementation

uses
  Winapi.Windows, System.Math, System.SysUtils, AviUtl2StyleColors;

constructor TPmxPoseCatalogListView.Create(AOwner: TComponent);
begin
  inherited;
  FGroupIndex := -1;
  FDisplayIndices := TList<Integer>.Create;
  Layout := illIcon;
  SelectionStyle := ilssRow;
  CaptionVisible := True;
  MultiSelect := True;
  ImageSize := ScaleValue(96);
  RowHeight := ImageSize + ScaleValue(28);
  FFailedIds := TStringList.Create;
  FFailedIds.CaseSensitive := False;
  FThumbnailQueue := TStringList.Create;
  FThumbnailQueue.CaseSensitive := False;
  FThumbnailQueue.Sorted := True;
  FThumbnailQueue.Duplicates := dupIgnore;
  FThumbnailTimer := TTimer.Create(Self);
  FThumbnailTimer.Enabled := False;
  FThumbnailTimer.Interval := 80;
  FThumbnailTimer.OnTimer := ThumbnailTimer;
end;

destructor TPmxPoseCatalogListView.Destroy;
begin
  FThumbnailTimer.Free;
  FThumbnailQueue.Free;
  FFailedIds.Free;
  FDisplayIndices.Free;
  inherited;
end;
function TPmxPoseCatalogListView.SourceIndex(DisplayIndex: Integer): Integer;
begin
  Result := -1;
  if (DisplayIndex >= 0) and (DisplayIndex < FDisplayIndices.Count) then
    Result := FDisplayIndices[DisplayIndex];
end;
function TPmxPoseCatalogListView.FindPoseIndex(const Id: string): Integer;
begin
  if Assigned(FPoseCatalog) then
    for Result := 0 to FPoseCatalog.Count - 1 do
      if SameText(FPoseCatalog[Result].Id, Id) then Exit;
  Result := -1;
end;
function TPmxPoseCatalogListView.FindDisplayIndex(const Id: string): Integer;
begin
  Result := FDisplayIndices.IndexOf(FindPoseIndex(Id));
end;
function TPmxPoseCatalogListView.GetItemCount: Integer;
begin
  Result := FDisplayIndices.Count;
end;
function TPmxPoseCatalogListView.GetItemText(Index: Integer): string;
begin
  Result := '';
  Index := SourceIndex(Index);
  if Assigned(FPoseCatalog) and (Index >= 0) and
    (Index < FPoseCatalog.Count) then Result := FPoseCatalog[Index].Name;
end;
procedure TPmxPoseCatalogListView.SetItemText(Index: Integer;
  const Value: string);
begin
  Index := SourceIndex(Index);
  if Assigned(FPoseCatalog) and FPoseCatalog.Rename(Index, Value) then Reload;
end;
function TPmxPoseCatalogListView.DisplayName(Index: Integer): string;
begin
  Result := GetItemText(Index);
end;
procedure TPmxPoseCatalogListView.RebuildDisplay(PreserveSelection: Boolean);
var
  I, Source: Integer;
  PoseId, SelectedId: string;
begin
  SelectedId := '';
  Source := SourceIndex(ItemIndex);
  if PreserveSelection and Assigned(FPoseCatalog) and (Source >= 0) and
    (Source < FPoseCatalog.Count) then SelectedId := FPoseCatalog[Source].Id;
  FDisplayIndices.Clear;
  if Assigned(FPoseCatalog) then
    if Assigned(FGroups) and (FGroupIndex >= 0) and
      (FGroupIndex < FGroups.Count) then
    begin
      for I := 0 to FGroups[FGroupIndex].PoseIds.Count - 1 do
      begin
        PoseId := FGroups[FGroupIndex].PoseIds[I];
        Source := FindPoseIndex(PoseId);
        if Source >= 0 then FDisplayIndices.Add(Source);
      end;
    end
    else
      for I := 0 to FPoseCatalog.Count - 1 do FDisplayIndices.Add(I);
  if SelectedId <> '' then ItemIndex := FindDisplayIndex(SelectedId)
  else if FDisplayIndices.Count > 0 then ItemIndex := 0
  else ItemIndex := -1;
  InvalidateList;
end;
procedure TPmxPoseCatalogListView.SetData(AModel: TPmxCatalogItem;
  APoseCatalog: TPmxPoseCatalogStorage; AGroups: TPmxPoseCatalogGroups);
begin
  FModel := AModel;
  FPoseCatalog := APoseCatalog;
  FGroups := AGroups;
  FGroupIndex := -1;
  Reload;
end;
procedure TPmxPoseCatalogListView.SetGroupIndex(const Value: Integer);
var
  NewValue: Integer;
begin
  NewValue := Value;
  if not Assigned(FGroups) or (NewValue < 0) or
    (NewValue >= FGroups.Count) then NewValue := -1;
  if FGroupIndex = NewValue then Exit;
  FGroupIndex := NewValue;
  RebuildDisplay(False);
end;
function TPmxPoseCatalogListView.SelectedSourceIndex: Integer;
begin
  Result := SourceIndex(ItemIndex);
end;
procedure TPmxPoseCatalogListView.SelectPoseId(const PoseId: string);
begin
  ItemIndex := FindDisplayIndex(PoseId);
end;
procedure TPmxPoseCatalogListView.GetSelectedPoseIds(Dest: TStrings);
var
  I, Source: Integer;
  Selection: TList<Integer>;
begin
  if not Assigned(Dest) then Exit;
  Dest.Clear;
  Selection := TList<Integer>.Create;
  try
    GetSelectedIndices(Selection);
    for I := 0 to Selection.Count - 1 do
    begin
      Source := SourceIndex(Selection[I]);
      if Assigned(FPoseCatalog) and (Source >= 0) and
        (Source < FPoseCatalog.Count) and
        (Dest.IndexOf(FPoseCatalog[Source].Id) < 0) then
        Dest.Add(FPoseCatalog[Source].Id);
    end;
  finally
    Selection.Free;
  end;
end;

procedure TPmxPoseCatalogListView.AssignSelectedToGroup(AGroupIndex: Integer);
var
  I: Integer;
  Ids: TStringList;
begin
  if not Assigned(FGroups) or (AGroupIndex < -1) or
    (AGroupIndex >= FGroups.Count) then Exit;
  Ids := TStringList.Create;
  try
    GetSelectedPoseIds(Ids);
    for I := 0 to Ids.Count - 1 do
      FGroups.AssignPoseToGroup(Ids[I], AGroupIndex);
    if Ids.Count > 0 then FGroups.SaveToFile;
    RebuildDisplay(True);
  finally
    Ids.Free;
  end;
end;

procedure TPmxPoseCatalogListView.AdoptPoseInCurrentGroup(
  const PoseId: string; InsertIndex: Integer);
begin
  if Assigned(FGroups) and (FGroupIndex >= 0) and
    (FGroupIndex < FGroups.Count) then
  begin
    FGroups.AssignPoseToGroup(PoseId, FGroupIndex, InsertIndex);
    FGroups.SaveToFile;
  end;
  RebuildDisplay(False);
  SelectPoseId(PoseId);
end;

function TPmxPoseCatalogListView.MoveSelectedInGroup(
  Delta: Integer): Boolean;
var
  NewIndex: Integer;
begin
  Result := False;
  if not Assigned(FGroups) or (FGroupIndex < 0) or
    (FGroupIndex >= FGroups.Count) then Exit;
  NewIndex := ItemIndex + Delta;
  if (ItemIndex < 0) or (NewIndex < 0) or
    (NewIndex >= FDisplayIndices.Count) then Exit;
  FGroups[FGroupIndex].ExchangePose(ItemIndex, NewIndex);
  if not FGroups.SaveToFile then
  begin
    FGroups[FGroupIndex].ExchangePose(NewIndex, ItemIndex);
    Exit;
  end;
  RebuildDisplay(False);
  ItemIndex := NewIndex;
  Result := True;
end;

procedure TPmxPoseCatalogListView.Reload;
begin
  FThumbnailTimer.Enabled := False;
  FThumbnailQueue.Clear;
  FFailedIds.Clear;
  RebuildDisplay(True);
end;

function TPmxPoseCatalogListView.RefreshThumbnails: Boolean;
begin
  Result := Assigned(FThumbnailCache) and FThumbnailCache.Clear;
  Reload;
end;

procedure TPmxPoseCatalogListView.SetThumbnailServices(
  ACache: TPmxCatalogThumbnailCache;
  ARenderer: TPmxCatalogThumbnailRenderer);
begin
  FThumbnailCache := ACache;
  FThumbnailRenderer := ARenderer;
  Reload;
end;

function TPmxPoseCatalogListView.VariantKey(DisplayIndex: Integer): string;
var
  Source: Integer;
begin
  Result := '';
  Source := SourceIndex(DisplayIndex);
  if Assigned(FPoseCatalog) and (Source >= 0) and
    (Source < FPoseCatalog.Count) then
    Result := FPoseCatalog[Source].Id + '|' + FPoseCatalog[Source].PoseData;
end;

procedure TPmxPoseCatalogListView.DrawItemImage(Index: Integer;
  const Bounds: TRect; Target: TCanvas);
var
  Bitmap: Vcl.Graphics.TBitmap;
  Source: Integer;
begin
  Target.Brush.Color := A2SCListViewAltBackground;
  Target.FillRect(Bounds);
  Source := SourceIndex(Index);
  if not Assigned(FModel) or not Assigned(FPoseCatalog) or (Source < 0) or
    (Source >= FPoseCatalog.Count) or not FileExists(FModel.SourcePath) then Exit;
  Bitmap := Vcl.Graphics.TBitmap.Create;
  try
    Bitmap.PixelFormat := pf32bit;
    Bitmap.SetSize(Max(1, Bounds.Width), Max(1, Bounds.Height));
    Bitmap.Canvas.Brush.Color := A2SCListViewAltBackground;
    Bitmap.Canvas.FillRect(Rect(0, 0, Bitmap.Width, Bitmap.Height));
    if not Assigned(FThumbnailCache) or
      not FThumbnailCache.LoadVariant(FModel.SourcePath, VariantKey(Index),
        Bitmap.Width, Bitmap.Height, Bitmap) then
      QueueThumbnail(FPoseCatalog[Source].Id);
    Target.StretchDraw(Bounds, Bitmap);
  finally
    Bitmap.Free;
  end;
end;

procedure TPmxPoseCatalogListView.QueueThumbnail(const Id: string);
begin
  if (Id = '') or (FFailedIds.IndexOf(Id) >= 0) or
    (FThumbnailQueue.IndexOf(Id) >= 0) then Exit;
  FThumbnailQueue.Add(Id);
  FThumbnailTimer.Enabled := True;
end;

procedure TPmxPoseCatalogListView.ThumbnailTimer(Sender: TObject);
var
  Bitmap: Vcl.Graphics.TBitmap;
  DisplayIndex, Source: Integer;
  PoseId: string;
  R: TRect;
begin
  FThumbnailTimer.Enabled := False;
  if (FThumbnailQueue.Count = 0) or not Assigned(FModel) or
    not Assigned(FPoseCatalog) or not Assigned(FThumbnailCache) or
    not Assigned(FThumbnailRenderer) then Exit;
  PoseId := FThumbnailQueue[0];
  FThumbnailQueue.Delete(0);
  Source := FindPoseIndex(PoseId);
  DisplayIndex := FindDisplayIndex(PoseId);
  if (Source >= 0) and (DisplayIndex >= 0) then
  begin
    R := ItemImageRect(DisplayIndex);
    Bitmap := Vcl.Graphics.TBitmap.Create;
    try
      if FThumbnailRenderer.RenderPmxPose(FModel.SourcePath,
        FPoseCatalog[Source].PoseData, Max(1, R.Width), Max(1, R.Height),
        Bitmap) then
      begin
        FThumbnailCache.SaveVariant(FModel.SourcePath,
          VariantKey(DisplayIndex), Bitmap.Width, Bitmap.Height, Bitmap);
        ReloadItem(DisplayIndex);
      end
      else if FFailedIds.IndexOf(PoseId) < 0 then FFailedIds.Add(PoseId);
    finally
      Bitmap.Free;
    end;
  end;
  FThumbnailTimer.Enabled := FThumbnailQueue.Count > 0;
end;

procedure TPmxPoseCatalogListView.KeyDown(var Key: Word; Shift: TShiftState);
var
  GroupNumber: Integer;
begin
  if not CaptionEditing and (Shift = []) and
    (((Key >= Ord('0')) and (Key <= Ord('9'))) or
     ((Key >= VK_NUMPAD0) and (Key <= VK_NUMPAD9))) then
  begin
    if Key >= VK_NUMPAD0 then GroupNumber := Key - VK_NUMPAD0
    else GroupNumber := Key - Ord('0');
    if GroupNumber = 0 then AssignSelectedToGroup(-1)
    else AssignSelectedToGroup(GroupNumber - 1);
    Key := 0;
    Exit;
  end;
  inherited;
end;

end.
