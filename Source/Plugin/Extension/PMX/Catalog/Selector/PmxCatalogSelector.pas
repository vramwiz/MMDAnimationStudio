unit PmxCatalogSelector;

// 各機能ページで共用する、人物分類付きPMX選択ペインを提供する。

interface

uses
  System.Classes,
  Vcl.Controls,
  Vcl.ExtCtrls,
  PmxCatalogStorage,
  PmxCatalogCharacterFilter,
  PmxCatalogListView,
  PmxCatalogThumbnailCache,
  PmxCatalogThumbnailRenderer;

type
  TPmxCatalogSelector = class(TPanel)
  private
    FCatalog: TPmxCatalogStorage;
    FCharacterCombo: TPmxCatalogCharacterCombo;
    FListView: TPmxCatalogListView;
    FOnSelectionChanged: TNotifyEvent;
    FUpdating: Boolean;
    procedure CharacterChanged(Sender: TObject);
    procedure ListSelectionChanged(Sender: TObject);
    procedure NotifySelectionChanged;
  public
    // 人物分類とPMX画像一覧を持つ左ペインを生成する。
    constructor Create(AOwner: TComponent); override;
    // 現在のPmxUIDを維持しながら分類候補と一覧を再構築する。
    procedure Reload;
    // 一覧のデータ元を差し替え、選択可能な先頭PMXを選ぶ。
    procedure SetCatalog(ACatalog: TPmxCatalogStorage);
    // サムネイルのキャッシュと非表示描画面を一覧へ接続する。
    procedure SetThumbnailServices(ACache: TPmxCatalogThumbnailCache;
      ARenderer: TPmxCatalogThumbnailRenderer);
    // PmxUIDに対応する表示行を選択する。現在の分類外なら全人物へ戻す。
    procedure SelectPmxId(const PmxId: string);
    // 現在選択中のPMX項目を返す。未選択ならnilを返す。
    function SelectedModel: TPmxCatalogItem;
    // 現在選択中のPmxUIDを返す。未選択なら空文字を返す。
    function SelectedPmxId: string;
    property Catalog: TPmxCatalogStorage read FCatalog;
    property CharacterCombo: TPmxCatalogCharacterCombo read FCharacterCombo;
    property ListView: TPmxCatalogListView read FListView;
    property OnSelectionChanged: TNotifyEvent read FOnSelectionChanged
      write FOnSelectionChanged;
  end;

implementation

uses
  System.SysUtils;

constructor TPmxCatalogSelector.Create(AOwner: TComponent);
begin
  inherited;
  Align := alLeft;
  Width := 105;
  BevelOuter := bvNone;
  ParentBackground := False;

  FCharacterCombo := TPmxCatalogCharacterCombo.Create(Self);
  FCharacterCombo.Parent := Self;
  FCharacterCombo.Align := alTop;
  FCharacterCombo.OnChange := CharacterChanged;

  FListView := TPmxCatalogListView.Create(Self);
  FListView.Parent := Self;
  FListView.Align := alClient;
  FListView.OnSelectionChanged := ListSelectionChanged;
end;

procedure TPmxCatalogSelector.CharacterChanged(Sender: TObject);
begin
  if FUpdating then Exit;
  FUpdating := True;
  try
    FListView.SetCharacterFilter(FCharacterCombo.Text);
    if FListView.DisplayCount > 0 then
      FListView.ItemIndex := 0
    else
      FListView.ItemIndex := -1;
  finally
    FUpdating := False;
  end;
  NotifySelectionChanged;
end;

procedure TPmxCatalogSelector.ListSelectionChanged(Sender: TObject);
begin
  if not FUpdating then NotifySelectionChanged;
end;

procedure TPmxCatalogSelector.NotifySelectionChanged;
begin
  if Assigned(FOnSelectionChanged) then FOnSelectionChanged(Self);
end;

procedure TPmxCatalogSelector.Reload;
var
  CanSelect: Boolean;
  PmxId: string;
begin
  PmxId := SelectedPmxId;
  CanSelect := Assigned(Parent) and Parent.HandleAllocated;
  FUpdating := True;
  try
    if CanSelect then
    begin
      FCharacterCombo.Rebuild(FCatalog);
      FListView.SetCharacterFilter(FCharacterCombo.Text);
    end
    else
      FListView.SetCharacterFilter(PmxCatalogAllCharactersCaption);
    FListView.Reload;
  finally
    FUpdating := False;
  end;
  if not CanSelect then Exit;
  SelectPmxId(PmxId);
end;

function TPmxCatalogSelector.SelectedModel: TPmxCatalogItem;
var
  Index: Integer;
begin
  Result := nil;
  Index := FListView.SelectedSourceIndex;
  if Assigned(FCatalog) and (Index >= 0) and (Index < FCatalog.Count) then
    Result := FCatalog.Items[Index];
end;

function TPmxCatalogSelector.SelectedPmxId: string;
var
  Model: TPmxCatalogItem;
begin
  Model := SelectedModel;
  if Assigned(Model) then Result := Model.Id else Result := '';
end;

procedure TPmxCatalogSelector.SelectPmxId(const PmxId: string);
var
  DisplayIndex: Integer;
  Index: Integer;
  SourceIndex: Integer;
begin
  SourceIndex := -1;
  if Assigned(FCatalog) and (PmxId <> '') then
    for Index := 0 to FCatalog.Count - 1 do
      if SameText(FCatalog.Items[Index].Id, PmxId) then
      begin
        SourceIndex := Index;
        Break;
      end;

  DisplayIndex := FListView.DisplayIndexOfSource(SourceIndex);
  if (SourceIndex >= 0) and (DisplayIndex < 0) then
  begin
    FUpdating := True;
    try
      FCharacterCombo.ItemIndex :=
        FCharacterCombo.Items.IndexOf(PmxCatalogAllCharactersCaption);
      FListView.SetCharacterFilter(PmxCatalogAllCharactersCaption);
    finally
      FUpdating := False;
    end;
    DisplayIndex := FListView.DisplayIndexOfSource(SourceIndex);
  end;
  if (DisplayIndex < 0) and (FListView.DisplayCount > 0) then
    DisplayIndex := 0;

  if FListView.ItemIndex <> DisplayIndex then
  begin
    FUpdating := True;
    try
      FListView.ItemIndex := DisplayIndex;
    finally
      FUpdating := False;
    end;
    NotifySelectionChanged;
  end;
end;

procedure TPmxCatalogSelector.SetCatalog(ACatalog: TPmxCatalogStorage);
begin
  FCatalog := ACatalog;
  FListView.SetCatalog(FCatalog);
  Reload;
end;

procedure TPmxCatalogSelector.SetThumbnailServices(
  ACache: TPmxCatalogThumbnailCache; ARenderer: TPmxCatalogThumbnailRenderer);
begin
  FListView.SetThumbnailServices(ACache, ARenderer);
end;

end.
