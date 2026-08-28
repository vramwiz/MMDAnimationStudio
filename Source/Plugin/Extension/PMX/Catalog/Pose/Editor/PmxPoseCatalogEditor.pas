unit PmxPoseCatalogEditor;

// PMXカタログのポーズ要素を既存MMDポーズ編集GUIへ接続する。
// 共通GUIは編集だけを担当し、このユニットの外側の確定バーが保存／破棄を管理する。

interface

uses
  PmxCatalogStorage,
  PmxPoseCatalogStorage;

// 「保存して閉じる」で確定したときだけ、Itemへ版付き姿勢JSONを書き戻す。
function EditPmxPoseCatalogItem(Model: TPmxCatalogItem;
  Item: TPmxPoseCatalogItem): Boolean;

implementation

uses
  System.SysUtils,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.Forms,
  Vcl.StdCtrls,
  MmdPoseEditor,
  MmdPoseEditorTheme;

const
  EmptyPoseData = '{"version":1,"bones":[]}';

type
  TPmxPoseEditorForm = class(TStandardPoseEditorForm)
  private
    FCommitPanel: TPanel;
    FSaveButton: TMmdDarkButton;
    FCancelButton: TMmdDarkButton;
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
  public
    procedure ConfigureTransactionControls;
  end;

procedure TPmxPoseEditorForm.ConfigureTransactionControls;
begin
  // 共通GUI側のボタンは使用しない。編集GUIの構成変更から確定処理を分離する。
  FDialogButtonPanel.Visible := False;

  FCommitPanel := TPanel.Create(Self);
  FCommitPanel.Parent := Self;
  FCommitPanel.Align := alBottom;
  FCommitPanel.Height := 55;
  FCommitPanel.BevelOuter := bvNone;
  FCommitPanel.BevelKind := bkTile;
  FCommitPanel.BevelEdges := [beTop];
  FCommitPanel.ParentBackground := False;
  FCommitPanel.Color := MmdEditorPanel;
  FCommitPanel.Font.Color := MmdEditorText;

  FSaveButton := TMmdDarkButton.Create(Self);
  FSaveButton.Parent := FCommitPanel;
  FSaveButton.Caption := #$4FDD#$5B58#$3057#$3066#$9589#$3058#$308B;
  FSaveButton.ModalResult := mrOk;
  FSaveButton.Default := True;
  FSaveButton.SetBounds(FCommitPanel.ClientWidth - 271, 10, 135, 32);
  FSaveButton.Anchors := [akTop, akRight];

  FCancelButton := TMmdDarkButton.Create(Self);
  FCancelButton.Parent := FCommitPanel;
  FCancelButton.Caption := #$30AD#$30E3#$30F3#$30BB#$30EB;
  FCancelButton.ModalResult := mrCancel;
  FCancelButton.Cancel := True;
  FCancelButton.SetBounds(FCommitPanel.ClientWidth - 127, 10, 111, 32);
  FCancelButton.Anchors := [akTop, akRight];

  OnCloseQuery := FormCloseQuery;
end;

procedure TPmxPoseEditorForm.FormCloseQuery(Sender: TObject;
  var CanClose: Boolean);
begin
  // タイトルバーの×は保存操作ではない。ShowModalの戻り値を明示的に破棄へ寄せる。
  if ModalResult = mrNone then
    ModalResult := mrCancel;
  CanClose := True;
end;

function EditPmxPoseCatalogItem(Model: TPmxCatalogItem;
  Item: TPmxPoseCatalogItem): Boolean;
var
  CurrentPoseData: string;
  Form: TPmxPoseEditorForm;
begin
  Result := False;
  if not Assigned(Model) or not Assigned(Item) or
    not FileExists(Model.SourcePath) then
    Exit;
  CurrentPoseData := Item.PoseData;
  if CurrentPoseData = '' then
    CurrentPoseData := EmptyPoseData;
  Form := TPmxPoseEditorForm.CreateEditor(Model.SourcePath, CurrentPoseData,
    Format('MMD %s - %s', [#$30DD#$30FC#$30BA#$7DE8#$96C6, Item.Name]));
  try
    Form.ConfigureTransactionControls;
    if Form.ShowModal <> mrOk then
      Exit;
    Item.PoseData := Form.EncodeCurrentPose;
    Result := True;
  finally
    Form.Free;
  end;
end;

end.
