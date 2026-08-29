unit MmdVpdReuseForm;

// 共通VPDライブラリを分類・複数選択し、選択PMXで姿勢を確認する画面を担当する。

interface

uses
  System.Classes, Vcl.Forms,
  PmxCatalogItem, PmxPoseCatalogStorage;

// 閉じるまで選択を保持し、確定時に管理済みVPD原本パスを一括で返す。
function SelectReusableVpdPoses(AOwner: TComponent; Model: TPmxCatalogItem;
  PoseCatalog: TPmxPoseCatalogStorage; const VpdRoot: string;
  out SourceFiles: TArray<string>): Boolean;

implementation

uses
  Winapi.Windows, System.Generics.Collections, System.SysUtils,
  Vcl.Controls, Vcl.ExtCtrls, Vcl.Graphics, Vcl.StdCtrls,
  MmdD3DViewport, MmdVpdCatalog, MmdVpdCatalogItem,
  MmdPoseEditorTheme,
  MmdPoseEditorButtonTheme, MmdPoseEditorComboTheme,
  MmdPoseEditorListTheme,
  PmxModel, PmxPose, PmxPoseCodec, PmxReader;

type
  TMmdVpdReuseForm = class(TForm)
  private
    FCatalog: TMmdVpdCatalog;
    FCategory: TMmdDarkComboBox;
    FCheckList: TMmdDarkCheckListBox;
    FModel: TPmxModel;
    FPoseCatalog: TPmxPoseCatalogStorage;
    FSelectedIds: TDictionary<string, Boolean>;
    FStatus: TLabel;
    FUpdating: Boolean;
    FViewport: TMmdD3DViewport;
    procedure CategoryChanged(Sender: TObject);
    procedure CheckChanged(Sender: TObject);
    procedure FormClosing(Sender: TObject; var CanClose: Boolean);
    procedure FormShown(Sender: TObject);
    function IsAlreadyRegistered(Item: TMmdVpdCatalogItem): Boolean;
    procedure ListChanged(Sender: TObject);
    procedure RebuildCategories;
    procedure RebuildList;
    procedure ShowPreview(Item: TMmdVpdCatalogItem);
  public
    // 共通VPDの選択、プレビュー、登録済み表示を備えたモーダル画面を生成する。
    constructor CreateReuse(AOwner: TComponent; Model: TPmxCatalogItem;
      PoseCatalog: TPmxPoseCatalogStorage; const VpdRoot: string);
    // プレビュー用モデルと共通VPDカタログを破棄する。
    destructor Destroy; override;
    // 分類を切り替えても保持した選択を管理済みVPD原本パスとして返す。
    procedure GetSelectedFiles(out SourceFiles: TArray<string>);
  end;

constructor TMmdVpdReuseForm.CreateReuse(AOwner: TComponent;
  Model: TPmxCatalogItem; PoseCatalog: TPmxPoseCatalogStorage;
  const VpdRoot: string);
var
  Button: TMmdDarkButton;
  Footer, LeftPanel, PreviewPanel: TPanel;
begin
  inherited CreateNew(AOwner);
  Caption := #$767B#$9332#$6E08#$307F'VPD'#$304B#$3089#$30DD#$30FC#$30BA#$3092#$8FFD#$52A0;
  Position := poOwnerFormCenter;
  BorderStyle := bsSizeable;
  ClientWidth := 900;
  ClientHeight := 620;
  Constraints.MinWidth := 700;
  Constraints.MinHeight := 480;
  Color := MmdEditorBackground;
  Font.Name := 'Yu Gothic UI';
  Font.Size := 12;
  Font.Color := MmdEditorText;
  OnCloseQuery := FormClosing;
  OnShow := FormShown;
  FPoseCatalog := PoseCatalog;
  FSelectedIds := TDictionary<string, Boolean>.Create;
  FCatalog := TMmdVpdCatalog.Create(VpdRoot);
  FCatalog.LoadFromFile;
  if Assigned(Model) then
    try FModel := GetCachedPmxModel(Model.SourcePath); except FModel := nil; end;

  Footer := TPanel.Create(Self);
  Footer.Parent := Self;
  Footer.Align := alBottom;
  Footer.Height := 64;
  Footer.BevelOuter := bvNone;
  Footer.ParentBackground := False;
  Footer.Color := MmdEditorPanel;
  Button := TMmdDarkButton.Create(Self);
  Button.Parent := Footer;
  Button.ParentFont := True;
  Button.SetBounds(Footer.ClientWidth - 132, 12, 116, 40);
  Button.Anchors := [akTop, akRight];
  Button.Caption := #$9589#$3058#$308B;
  Button.ModalResult := mrOk;
  Button.Default := True;
  FStatus := TLabel.Create(Self);
  FStatus.Parent := Footer;
  FStatus.ParentFont := True;
  FStatus.SetBounds(16, 0, Footer.ClientWidth - 164, Footer.Height);
  FStatus.Anchors := [akLeft, akTop, akRight, akBottom];
  FStatus.AutoSize := False;
  FStatus.Font.Color := MmdEditorText;
  FStatus.Layout := tlCenter;

  LeftPanel := TPanel.Create(Self);
  LeftPanel.Parent := Self;
  LeftPanel.Align := alLeft;
  LeftPanel.Width := 340;
  LeftPanel.BevelOuter := bvNone;
  LeftPanel.Padding.SetBounds(14, 14, 10, 14);
  LeftPanel.Color := MmdEditorBackground;
  LeftPanel.ParentBackground := False;
  FCategory := TMmdDarkComboBox.Create(Self);
  FCategory.Parent := LeftPanel;
  FCategory.ParentFont := True;
  FCategory.Align := alTop;
  FCategory.ItemHeight := 28;
  FCategory.Height := 38;
  FCategory.OnChange := CategoryChanged;
  FCheckList := TMmdDarkCheckListBox.Create(Self);
  FCheckList.Parent := LeftPanel;
  FCheckList.ParentFont := True;
  FCheckList.ItemHeight := 34;
  FCheckList.Align := alClient;
  FCheckList.AlignWithMargins := True;
  FCheckList.Margins.SetBounds(0, 10, 0, 0);
  FCheckList.BorderStyle := bsNone;
  FCheckList.OnClick := ListChanged;
  FCheckList.OnClickCheck := CheckChanged;

  PreviewPanel := TPanel.Create(Self);
  PreviewPanel.Parent := Self;
  PreviewPanel.Align := alClient;
  PreviewPanel.BevelOuter := bvNone;
  PreviewPanel.Padding.SetBounds(10, 14, 14, 14);
  PreviewPanel.Color := MmdEditorBackground;
  PreviewPanel.ParentBackground := False;
  FViewport := TMmdD3DViewport.Create(Self);
  FViewport.Parent := PreviewPanel;
  FViewport.Align := alClient;
  FViewport.ReadOnly := True;
  FViewport.SetDisplayVisibility(True, False);
  FViewport.Hint := #$53F3#$30C9#$30E9#$30C3#$30B0': '#$56DE#$8EE2 +
    ' / '#$30DB#$30A4#$30FC#$30EB': '#$62E1#$5927#$7E2E#$5C0F +
    ' / '#$5DE6#$30C9#$30E9#$30C3#$30B0': '#$79FB#$52D5;
  RebuildCategories;
  RebuildList;
end;

destructor TMmdVpdReuseForm.Destroy;
begin
  FSelectedIds.Free;
  FCatalog.Free;
  inherited;
end;

procedure TMmdVpdReuseForm.RebuildCategories;
var
  I: Integer;
  Item: TMmdVpdCatalogItem;
begin
  FCategory.Items.BeginUpdate;
  try
    FCategory.Items.Clear;
    FCategory.Items.Add(#$3059#$3079#$3066);
    for I := 0 to FCatalog.Count - 1 do
    begin
      Item := FCatalog[I];
      if (Trim(Item.CategoryName) <> '') and
        (FCategory.Items.IndexOf(Item.CategoryName) < 0) then
        FCategory.Items.Add(Item.CategoryName);
    end;
    FCategory.ItemIndex := 0;
  finally
    FCategory.Items.EndUpdate;
  end;
end;

function TMmdVpdReuseForm.IsAlreadyRegistered(
  Item: TMmdVpdCatalogItem): Boolean;
begin
  Result := Assigned(FPoseCatalog) and
    (FPoseCatalog.IndexOfSourceVpdId(Item.Id) >= 0);
end;

procedure TMmdVpdReuseForm.RebuildList;
var
  I, ListIndex: Integer;
  Item: TMmdVpdCatalogItem;
  ShowItem: Boolean;
begin
  FUpdating := True;
  FCheckList.Items.BeginUpdate;
  try
    FCheckList.Items.Clear;
    for I := 0 to FCatalog.Count - 1 do
    begin
      Item := FCatalog[I];
      ShowItem := (FCategory.ItemIndex <= 0) or
        SameText(FCategory.Text, Item.CategoryName);
      if not ShowItem then Continue;
      ListIndex := FCheckList.Items.AddObject(Item.Name, Item);
      FCheckList.Checked[ListIndex] := FSelectedIds.ContainsKey(Item.Id);
      if IsAlreadyRegistered(Item) then
      begin
        FCheckList.Items[ListIndex] := Item.Name + ' '#$FF08#$767B#$9332 +
          #$6E08#$307F#$FF09;
      end;
    end;
  finally
    FCheckList.Items.EndUpdate;
    FUpdating := False;
  end;
  if FCheckList.Count > 0 then
  begin
    FCheckList.ItemIndex := 0;
    ListChanged(FCheckList);
  end
  else
    ShowPreview(nil);
end;

procedure TMmdVpdReuseForm.CategoryChanged(Sender: TObject);
begin
  RebuildList;
end;

procedure TMmdVpdReuseForm.CheckChanged(Sender: TObject);
var
  Item: TMmdVpdCatalogItem;
begin
  if FUpdating or (FCheckList.ItemIndex < 0) then Exit;
  Item := TMmdVpdCatalogItem(FCheckList.Items.Objects[FCheckList.ItemIndex]);
  if FCheckList.Checked[FCheckList.ItemIndex] then
    FSelectedIds.AddOrSetValue(Item.Id, True)
  else
    FSelectedIds.Remove(Item.Id);
  FStatus.Caption := Format('%d'#$4EF6#$3092#$8FFD#$52A0,
    [FSelectedIds.Count]);
end;

procedure TMmdVpdReuseForm.ListChanged(Sender: TObject);
begin
  if FCheckList.ItemIndex < 0 then ShowPreview(nil)
  else ShowPreview(TMmdVpdCatalogItem(
    FCheckList.Items.Objects[FCheckList.ItemIndex]));
end;

procedure TMmdVpdReuseForm.ShowPreview(Item: TMmdVpdCatalogItem);
var
  Named: TPmxNamedBonePoses;
  PoseData: string;
  Poses: TPmxBonePoses;
begin
  if not Assigned(Item) then
  begin
    FViewport.SetScene(nil, Poses, -1);
    FStatus.Caption := #$767B#$9332#$6E08#$307F'VPD'#$304C#$3042#$308A +
      #$307E#$305B#$3093;
    Exit;
  end;
  FStatus.Caption := Format('%s / '#$9078#$629E' %d'#$4EF6,
    [Item.CategoryName, FSelectedIds.Count]);
  if not Assigned(FModel) or not FCatalog.LoadPoseData(Item.Id, PoseData) or
    not TryDecodePoseData(PoseData, Named) then
  begin
    FViewport.SetScene(nil, Poses, -1);
    Exit;
  end;
  InitializeBonePoses(FModel, Poses);
  ApplyNamedBonePoses(FModel, Named, Poses);
  FViewport.SetScene(FModel, Poses, -1);
end;

procedure TMmdVpdReuseForm.FormClosing(Sender: TObject; var CanClose: Boolean);
begin
  if ModalResult = mrNone then ModalResult := mrOk;
  CanClose := True;
end;

procedure TMmdVpdReuseForm.FormShown(Sender: TObject);
begin
  ApplyMmdDarkTitleBar(Self);
  FViewport.SetDisplayVisibility(True, False);
end;

procedure TMmdVpdReuseForm.GetSelectedFiles(
  out SourceFiles: TArray<string>);
var
  I, Count: Integer;
begin
  SetLength(SourceFiles, FSelectedIds.Count);
  Count := 0;
  for I := 0 to FCatalog.Count - 1 do
    if FSelectedIds.ContainsKey(FCatalog[I].Id) then
    begin
      SourceFiles[Count] := FCatalog.SourceFileName(FCatalog[I].Id);
      Inc(Count);
    end;
  SetLength(SourceFiles, Count);
end;

function SelectReusableVpdPoses(AOwner: TComponent; Model: TPmxCatalogItem;
  PoseCatalog: TPmxPoseCatalogStorage; const VpdRoot: string;
  out SourceFiles: TArray<string>): Boolean;
var
  Form: TMmdVpdReuseForm;
begin
  SetLength(SourceFiles, 0);
  Result := False;
  if not Assigned(Model) or not Assigned(PoseCatalog) then Exit;
  Form := TMmdVpdReuseForm.CreateReuse(AOwner, Model, PoseCatalog, VpdRoot);
  try
    Result := Form.ShowModal = mrOk;
    if Result then Form.GetSelectedFiles(SourceFiles);
    Result := Result and (Length(SourceFiles) > 0);
  finally
    Form.Free;
  end;
end;

end.
