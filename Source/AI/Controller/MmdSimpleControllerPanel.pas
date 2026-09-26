unit MmdSimpleControllerPanel;

// 九つの人体操作対象を一覧表示し、選択を編集フォームへ通知する。

interface

uses
  System.Classes,
  Vcl.Controls,
  DarkPanel,
  DarkListBox,
  PmxModel,
  MmdSimpleControllerSolver;

type
  TMmdSimpleSelectionEvent = procedure(Sender: TObject;
    Controller: TMmdSimpleController) of object;

  TMmdSimpleControllerPanel = class(TDarkPanel)
  private
    FList: TDarkListBox;
    FOnSelectionChanged: TMmdSimpleSelectionEvent;
    function GetSelectedController: TMmdSimpleController;
    procedure SelectionChanged(Sender: TObject);
  public
    // 左ペイン全体を使う操作対象一覧を生成する。
    constructor Create(AOwner: TComponent); override;
    // 親フォームへの接続後に実DPIで一覧の行高を揃える。
    procedure ApplyLayout;
    // モデルで操作できる部位だけを一覧で選択可能にする。
    procedure SetModel(const Model: TPmxModel);
    // 指定部位へ選択を移し、変更通知を呼ぶ。
    procedure SelectController(Controller: TMmdSimpleController);
    // 十字キーの上下入力に従って部位選択を進める。
    procedure Navigate(POV: Cardinal);
    property OnSelectionChanged: TMmdSimpleSelectionEvent
      read FOnSelectionChanged write FOnSelectionChanged;
    property SelectedController: TMmdSimpleController read GetSelectedController;
  end;

implementation

constructor TMmdSimpleControllerPanel.Create(AOwner: TComponent);
begin
  inherited;
  Caption := '';
end;

procedure TMmdSimpleControllerPanel.ApplyLayout;
begin
  if FList = nil then
  begin
    FList := TDarkListBox.Create(Self);
    FList.Parent := Self;
    FList.Align := alClient;
    FList.DesignItemHeight := 34;
    FList.Items.Add('頭を向ける');
    FList.Items.Add('目を動かす');
    FList.Items.Add('上半身を傾ける');
    FList.Items.Add('腰を回す');
    FList.Items.Add('左手を動かす');
    FList.Items.Add('右手を動かす');
    FList.Items.Add('左足を動かす');
    FList.Items.Add('右足を動かす');
    FList.Items.Add('重心を動かす');
    FList.ItemIndex := Ord(scUpperBody);
    FList.OnClick := SelectionChanged;

  end;
  FList.ApplyDpi;
end;

procedure TMmdSimpleControllerPanel.SelectionChanged(Sender: TObject);
begin
  if FList.ItemIndex >= 0 then
  begin
    if Assigned(FOnSelectionChanged) then
      FOnSelectionChanged(Self, SelectedController);
  end;
end;

function TMmdSimpleControllerPanel.GetSelectedController: TMmdSimpleController;
begin
  Result := TMmdSimpleController(FList.ItemIndex);
end;

procedure TMmdSimpleControllerPanel.SelectController(
  Controller: TMmdSimpleController);
begin
  FList.ItemIndex := Ord(Controller);
  if Assigned(FOnSelectionChanged) then
    FOnSelectionChanged(Self, Controller);
end;

procedure TMmdSimpleControllerPanel.SetModel(const Model: TPmxModel);
const
  Names: array[TMmdSimpleController] of string = (
    '頭を向ける', '目を動かす', '上半身を傾ける', '腰を回す', '左手を動かす',
    '右手を動かす', '左足を動かす', '右足を動かす',
    '重心を動かす');
var
  Controller: TMmdSimpleController;
begin
  for Controller := Low(TMmdSimpleController) to High(TMmdSimpleController) do
    if CanUseSimpleController(Model, Controller) then
      FList.Items[Ord(Controller)] := Names[Controller]
    else
      FList.Items[Ord(Controller)] := Names[Controller] + ' (未対応)';
end;

procedure TMmdSimpleControllerPanel.Navigate(POV: Cardinal);
begin
  case POV of
    0: SelectController(TMmdSimpleController(
      (Ord(SelectedController) + Ord(High(TMmdSimpleController))) mod
      (Ord(High(TMmdSimpleController)) + 1)));
    18000: SelectController(TMmdSimpleController(
      (Ord(SelectedController) + 1) mod
      (Ord(High(TMmdSimpleController)) + 1)));
  end;
end;

end.
