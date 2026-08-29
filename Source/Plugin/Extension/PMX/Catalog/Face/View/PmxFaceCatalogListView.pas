unit PmxFaceCatalogListView;
// 選択PMXの表情を、全件または表情グループのFaceUID順で画像表示する。
interface

uses
  System.Classes, System.Generics.Collections, System.Types,
  Vcl.Controls, Vcl.ExtCtrls, Vcl.Graphics, ItemListView,
  PmxCatalogStorage, PmxFaceCatalogStorage, PmxFaceCatalogGroups,
  PmxCatalogThumbnailCache, PmxCatalogThumbnailRenderer;

type
  TPmxFaceCatalogListView = class(TCustomItemListView)
  private
    FDisplayIndices: TList<Integer>;
    FFailedIds: TStringList;
    FFaceCatalog: TPmxFaceCatalogStorage;
    FGroupIndex: Integer;
    FGroups: TPmxFaceCatalogGroups;
    FModel: TPmxCatalogItem;
    FThumbnailCache: TPmxCatalogThumbnailCache;
    FThumbnailQueue: TStringList;
    FThumbnailRenderer: TPmxCatalogThumbnailRenderer;
    FThumbnailTimer: TTimer;
    function FindDisplayIndex(const Id: string): Integer;
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
    // 表情一覧、選択状態、遅延サムネイルキューを初期化する。
    constructor Create(AOwner: TComponent); override;
    // タイマー、キュー、表示順一覧を停止・解放する。
    destructor Destroy; override;
    // 追加・複製したFaceUIDを現在グループへ挿入して選択する。
    procedure AdoptFaceInCurrentGroup(const FaceId: string;
      InsertIndex: Integer = -1);
    // 選択項目を指定グループへ所属させる。-1は所属解除。
    procedure AssignSelectedToGroup(AGroupIndex: Integer);
    // 選択FaceUID群をグループメニュー用に列挙する。
    procedure GetSelectedFaceIds(Dest: TStrings);
    // 現在グループ内で選択表情を上下へ移動する。
    function MoveSelectedInGroup(Delta: Integer): Boolean;
    // このモデルの表情サムネイルキャッシュを破棄し、一覧を再読込する。
    function RefreshThumbnails: Boolean;
    // 表示条件を維持して表情一覧と遅延サムネイル状態を再構築する。
    procedure Reload;
    // 現在選択行に対応する表情カタログ番号を返し、未選択では-1を返す。
    function SelectedSourceIndex: Integer;
    // 指定FaceUIDが現在の表示対象なら、その行を選択する。
    procedure SelectFaceId(const FaceId: string);
    // 選択PMX、表情カタログ、任意のグループ一覧を表示元として設定する。
    procedure SetData(AModel: TPmxCatalogItem;
      AFaceCatalog: TPmxFaceCatalogStorage;
      AGroups: TPmxFaceCatalogGroups = nil);
    // -1で全表情、それ以外で対応グループだけを表示する。
    procedure SetGroupIndex(const Value: Integer);
    // サムネイルの読込先キャッシュと未生成画像の描画サービスを接続する。
    procedure SetThumbnailServices(ACache: TPmxCatalogThumbnailCache;
      ARenderer: TPmxCatalogThumbnailRenderer);
    // 現在のグループ番号と保存領域を読取専用で公開する。
    property GroupIndex: Integer read FGroupIndex;
    property Groups: TPmxFaceCatalogGroups read FGroups;
  end;

implementation
uses
  Winapi.Windows, System.Math, System.SysUtils, AviUtl2StyleColors,
  PmxCatalogGroupShortcut, PmxFaceCatalogSelection;

constructor TPmxFaceCatalogListView.Create(AOwner: TComponent);
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

destructor TPmxFaceCatalogListView.Destroy;
begin
  FThumbnailTimer.Free;
  FThumbnailQueue.Free;
  FFailedIds.Free;
  FDisplayIndices.Free;
  inherited;
end;

function TPmxFaceCatalogListView.SourceIndex(DisplayIndex: Integer): Integer;
begin
  Result := -1;
  if (DisplayIndex >= 0) and (DisplayIndex < FDisplayIndices.Count) then
    Result := FDisplayIndices[DisplayIndex];
end;

function TPmxFaceCatalogListView.FindDisplayIndex(const Id: string): Integer;
begin
  Result := FDisplayIndices.IndexOf(
    FindPmxFaceCatalogIndex(FFaceCatalog, Id));
end;

function TPmxFaceCatalogListView.GetItemCount: Integer;
begin
  Result := FDisplayIndices.Count;
end;

function TPmxFaceCatalogListView.GetItemText(Index: Integer): string;
begin
  Result := '';
  Index := SourceIndex(Index);
  if Assigned(FFaceCatalog) and (Index >= 0) and
    (Index < FFaceCatalog.Count) then Result := FFaceCatalog[Index].Name;
end;

procedure TPmxFaceCatalogListView.SetItemText(Index: Integer;
  const Value: string);
begin
  Index := SourceIndex(Index);
  if Assigned(FFaceCatalog) and FFaceCatalog.Rename(Index, Value) then Reload;
end;

procedure TPmxFaceCatalogListView.RebuildDisplay(PreserveSelection: Boolean);
var
  SelectedId: string;
  Source: Integer;
begin
  SelectedId := '';
  Source := SourceIndex(ItemIndex);
  if PreserveSelection and Assigned(FFaceCatalog) and (Source >= 0) and
    (Source < FFaceCatalog.Count) then SelectedId := FFaceCatalog[Source].Id;
  BuildPmxFaceDisplayIndices(FFaceCatalog, FGroups, FGroupIndex,
    FDisplayIndices);
  if SelectedId <> '' then ItemIndex := FindDisplayIndex(SelectedId)
  else if FDisplayIndices.Count > 0 then ItemIndex := 0
  else ItemIndex := -1;
  InvalidateList;
end;

procedure TPmxFaceCatalogListView.SetData(AModel: TPmxCatalogItem;
  AFaceCatalog: TPmxFaceCatalogStorage; AGroups: TPmxFaceCatalogGroups);
begin
  FModel := AModel;
  FFaceCatalog := AFaceCatalog;
  FGroups := AGroups;
  FGroupIndex := -1;
  Reload;
end;

procedure TPmxFaceCatalogListView.SetGroupIndex(const Value: Integer);
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

function TPmxFaceCatalogListView.SelectedSourceIndex: Integer;
begin
  Result := SourceIndex(ItemIndex);
end;

procedure TPmxFaceCatalogListView.SelectFaceId(const FaceId: string);
begin
  ItemIndex := FindDisplayIndex(FaceId);
end;

procedure TPmxFaceCatalogListView.GetSelectedFaceIds(Dest: TStrings);
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
      if Assigned(FFaceCatalog) and (Source >= 0) and
        (Source < FFaceCatalog.Count) and
        (Dest.IndexOf(FFaceCatalog[Source].Id) < 0) then
        Dest.Add(FFaceCatalog[Source].Id);
    end;
  finally
    Selection.Free;
  end;
end;

procedure TPmxFaceCatalogListView.AssignSelectedToGroup(AGroupIndex: Integer);
var
  I: Integer;
  Ids: TStringList;
begin
  if not Assigned(FGroups) or (AGroupIndex < -1) or
    (AGroupIndex >= FGroups.Count) then Exit;
  Ids := TStringList.Create;
  try
    GetSelectedFaceIds(Ids);
    for I := 0 to Ids.Count - 1 do
      FGroups.AssignFaceToGroup(Ids[I], AGroupIndex);
    if Ids.Count > 0 then FGroups.SaveToFile;
    RebuildDisplay(True);
  finally
    Ids.Free;
  end;
end;

procedure TPmxFaceCatalogListView.AdoptFaceInCurrentGroup(
  const FaceId: string; InsertIndex: Integer);
begin
  if Assigned(FGroups) and (FGroupIndex >= 0) and
    (FGroupIndex < FGroups.Count) then
  begin
    FGroups.AssignFaceToGroup(FaceId, FGroupIndex, InsertIndex);
    FGroups.SaveToFile;
  end;
  RebuildDisplay(False);
  SelectFaceId(FaceId);
end;

function TPmxFaceCatalogListView.MoveSelectedInGroup(
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
  FGroups[FGroupIndex].ExchangeFace(ItemIndex, NewIndex);
  if not FGroups.SaveToFile then
  begin
    FGroups[FGroupIndex].ExchangeFace(NewIndex, ItemIndex);
    Exit;
  end;
  RebuildDisplay(False);
  ItemIndex := NewIndex;
  Result := True;
end;

procedure TPmxFaceCatalogListView.Reload;
begin
  FThumbnailTimer.Enabled := False;
  FThumbnailQueue.Clear;
  FFailedIds.Clear;
  RebuildDisplay(True);
end;

function TPmxFaceCatalogListView.RefreshThumbnails: Boolean;
begin
  Result := Assigned(FThumbnailCache) and FThumbnailCache.Clear;
  Reload;
end;

procedure TPmxFaceCatalogListView.SetThumbnailServices(
  ACache: TPmxCatalogThumbnailCache;
  ARenderer: TPmxCatalogThumbnailRenderer);
begin
  FThumbnailCache := ACache;
  FThumbnailRenderer := ARenderer;
  Reload;
end;

function TPmxFaceCatalogListView.VariantKey(DisplayIndex: Integer): string;
var
  Source: Integer;
begin
  Result := '';
  Source := SourceIndex(DisplayIndex);
  if Assigned(FFaceCatalog) and (Source >= 0) and
    (Source < FFaceCatalog.Count) then
    Result := FFaceCatalog[Source].Id + '|' + FFaceCatalog[Source].FaceData;
end;

procedure TPmxFaceCatalogListView.DrawItemImage(Index: Integer;
  const Bounds: TRect; Target: TCanvas);
var
  Bitmap: Vcl.Graphics.TBitmap;
  Source: Integer;
begin
  Target.Brush.Color := A2SCListViewAltBackground;
  Target.FillRect(Bounds);
  Source := SourceIndex(Index);
  if not Assigned(FModel) or not Assigned(FFaceCatalog) or (Source < 0) or
    (Source >= FFaceCatalog.Count) or not FileExists(FModel.SourcePath) then Exit;
  Bitmap := Vcl.Graphics.TBitmap.Create;
  try
    Bitmap.PixelFormat := pf32bit;
    Bitmap.SetSize(Max(1, Bounds.Width), Max(1, Bounds.Height));
    Bitmap.Canvas.Brush.Color := A2SCListViewAltBackground;
    Bitmap.Canvas.FillRect(Rect(0, 0, Bitmap.Width, Bitmap.Height));
    if not Assigned(FThumbnailCache) or
      not FThumbnailCache.LoadVariant(FModel.SourcePath, VariantKey(Index),
        Bitmap.Width, Bitmap.Height, Bitmap) then
      QueueThumbnail(FFaceCatalog[Source].Id);
    Target.StretchDraw(Bounds, Bitmap);
  finally
    Bitmap.Free;
  end;
end;

procedure TPmxFaceCatalogListView.QueueThumbnail(const Id: string);
begin
  if (Id = '') or (FFailedIds.IndexOf(Id) >= 0) or
    (FThumbnailQueue.IndexOf(Id) >= 0) then Exit;
  FThumbnailQueue.Add(Id);
  FThumbnailTimer.Enabled := True;
end;

procedure TPmxFaceCatalogListView.ThumbnailTimer(Sender: TObject);
var
  Bitmap: Vcl.Graphics.TBitmap;
  DisplayIndex, Source: Integer;
  FaceId: string;
  R: TRect;
begin
  FThumbnailTimer.Enabled := False;
  if (FThumbnailQueue.Count = 0) or not Assigned(FModel) or
    not Assigned(FFaceCatalog) or not Assigned(FThumbnailCache) or
    not Assigned(FThumbnailRenderer) then Exit;
  FaceId := FThumbnailQueue[0];
  FThumbnailQueue.Delete(0);
  Source := FindPmxFaceCatalogIndex(FFaceCatalog, FaceId);
  DisplayIndex := FindDisplayIndex(FaceId);
  if (Source >= 0) and (DisplayIndex >= 0) then
  begin
    R := ItemImageRect(DisplayIndex);
    Bitmap := Vcl.Graphics.TBitmap.Create;
    try
      if FThumbnailRenderer.RenderPmxFace(FModel.SourcePath,
        FFaceCatalog[Source].FaceData, Max(1, R.Width), Max(1, R.Height),
        Bitmap) then
      begin
        FThumbnailCache.SaveVariant(FModel.SourcePath,
          VariantKey(DisplayIndex), Bitmap.Width, Bitmap.Height, Bitmap);
        ReloadItem(DisplayIndex);
      end
      else if FFailedIds.IndexOf(FaceId) < 0 then FFailedIds.Add(FaceId);
    finally
      Bitmap.Free;
    end;
  end;
  FThumbnailTimer.Enabled := FThumbnailQueue.Count > 0;
end;

procedure TPmxFaceCatalogListView.KeyDown(var Key: Word; Shift: TShiftState);
var
  GroupIndex: Integer;
begin
  if not CaptionEditing and
    TryPmxCatalogGroupShortcut(Key, Shift, GroupIndex) then
  begin
    AssignSelectedToGroup(GroupIndex);
    Key := 0;
    Exit;
  end;
  inherited;
end;

end.

