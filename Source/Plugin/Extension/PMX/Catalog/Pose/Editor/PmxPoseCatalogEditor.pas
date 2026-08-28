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
  Winapi.Windows,
  System.SysUtils,
  System.Math,
  System.Types,
  System.UITypes,
  Vcl.ComCtrls,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.Forms,
  Vcl.Graphics,
  Vcl.ImgList,
  Vcl.StdCtrls,
  Vcl.ToolWin,
  MmdPoseEditor,
  MmdPoseEditorTheme;

const
  EmptyPoseData = '{"version":1,"bones":[]}';

type
  TPmxModelSettingPage = (mspPose, mspExpression, mspEyeBlink, mspLipSync);

  TPmxPoseEditorForm = class(TStandardPoseEditorForm)
  private
    FCommitPanel: TPanel;
    FCurrentPage: TPmxModelSettingPage;
    FModeImages: TImageList;
    FModeButtons: array[TPmxModelSettingPage] of TToolButton;
    FModeToolbar: TToolBar;
    FSaveButton: TMmdDarkButton;
    procedure ModeButtonClick(Sender: TObject);
    procedure ModeToolbarCustomDraw(Sender: TToolBar; const ARect: TRect;
      var DefaultDraw: Boolean);
    procedure ModeToolbarCustomDrawButton(Sender: TToolBar;
      Button: TToolButton; State: TCustomDrawState; var DefaultDraw: Boolean);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure ShowSettingPage(Page: TPmxModelSettingPage);
  public
    procedure ConfigureTransactionControls;
  end;

const
  ModeToolbarBackground = MmdEditorPanel;
  ModeToolbarForeground = MmdEditorText;
  ModeToolbarHot = TColor($00B03C3C);
  ModeToolbarPressed = TColor($001F1F1F);
  ModeToolbarChecked = TColor($00FF6666);
  ModeIconMask = TColor($00FF00FF);
  ModePoseColor = TColor($0078CD4C);
  ModeExpressionColor = TColor($0046BEF0);
  ModeEyeColor = TColor($00FFAA50);
  ModeMouthColor = TColor($00AA69FF);

procedure DrawModeIcon(Canvas: TCanvas; Index, Size: Integer; Color: TColor);
var
  S: Integer;

  function P(Value: Integer): Integer;
  begin
    Result := MulDiv(Value, Size, 24);
  end;

begin
  S := Max(1, P(2));
  Canvas.Pen.Color := Color;
  Canvas.Pen.Width := S;
  Canvas.Pen.Style := psSolid;
  Canvas.Brush.Style := bsClear;
  case Index of
    0: // ポーズ
      begin
        Canvas.Ellipse(P(9), P(2), P(15), P(8));
        Canvas.MoveTo(P(12), P(8)); Canvas.LineTo(P(12), P(16));
        Canvas.MoveTo(P(12), P(10)); Canvas.LineTo(P(4), P(14));
        Canvas.MoveTo(P(12), P(10)); Canvas.LineTo(P(20), P(14));
        Canvas.MoveTo(P(12), P(16)); Canvas.LineTo(P(7), P(22));
        Canvas.MoveTo(P(12), P(16)); Canvas.LineTo(P(17), P(22));
      end;
    1: // 表情
      begin
        Canvas.Ellipse(P(3), P(3), P(21), P(21));
        Canvas.Ellipse(P(7), P(8), P(9), P(10));
        Canvas.Ellipse(P(15), P(8), P(17), P(10));
        Canvas.Arc(P(7), P(9), P(17), P(18), P(7), P(13), P(17), P(13));
      end;
    2: // 目パチ
      begin
        // 青い虹彩と黒目を囲む目。上側の3本線でまつ毛を表す。
        Canvas.Arc(P(2), P(6), P(22), P(19), P(2), P(12), P(22), P(12));
        Canvas.Arc(P(2), P(6), P(22), P(19), P(22), P(12), P(2), P(12));
        Canvas.Brush.Style := bsSolid;
        Canvas.Brush.Color := Color;
        Canvas.Ellipse(P(8), P(8), P(16), P(17));
        Canvas.Brush.Color := ModeToolbarBackground;
        Canvas.Ellipse(P(11), P(10), P(14), P(15));
        Canvas.Brush.Style := bsClear;
        Canvas.MoveTo(P(6), P(8)); Canvas.LineTo(P(4), P(4));
        Canvas.MoveTo(P(12), P(7)); Canvas.LineTo(P(12), P(2));
        Canvas.MoveTo(P(18), P(8)); Canvas.LineTo(P(20), P(4));
      end;
    3: // 口パク
      begin
        // 小さい表示でも上唇の2つの山が潰れない、塗りつぶした唇形。
        Canvas.Brush.Style := bsSolid;
        Canvas.Brush.Color := Color;
        Canvas.Polygon([Point(P(2), P(13)), Point(P(7), P(10)),
          Point(P(10), P(8)), Point(P(12), P(11)), Point(P(14), P(8)),
          Point(P(17), P(10)), Point(P(22), P(13)), Point(P(18), P(17)),
          Point(P(14), P(19)), Point(P(10), P(19)), Point(P(6), P(17))]);
        // 上下の唇を分ける線を暗色で入れ、口形として読めるようにする。
        Canvas.Pen.Color := ModeToolbarBackground;
        Canvas.Pen.Width := Max(1, P(1));
        Canvas.Polyline([Point(P(3), P(13)), Point(P(8), P(14)),
          Point(P(12), P(13)), Point(P(16), P(14)), Point(P(21), P(13))]);
        Canvas.Brush.Style := bsClear;
      end;
  end;
end;

procedure TPmxPoseEditorForm.ModeButtonClick(Sender: TObject);
begin
  if Sender is TToolButton then
    ShowSettingPage(TPmxModelSettingPage(TToolButton(Sender).Tag));
end;

procedure TPmxPoseEditorForm.ShowSettingPage(Page: TPmxModelSettingPage);
begin
  FCurrentPage := Page;
  FModeButtons[Page].Down := True;
  if Page = mspPose then
  begin
    FCommandToolbar.Visible := True;
    FBoneList.Visible := True;
    FMorphPreview.Visible := False;
    FViewport.ReadOnly := False;
    FViewport.SetDisplayVisibility(True, True);
    FViewport.ResetPreviewCamera;
    Exit;
  end;

  FCommandToolbar.Visible := False;
  FBoneList.Visible := False;
  FMorphPreview.Align := alClient;
  FMorphPreview.Visible := True;
  // 保存処理は未実装だが、GUI確認用のウェイト操作と一時プレビューは許可する。
  FMorphPreview.SetEditingEnabled(True);
  case Page of
    mspExpression:
      FMorphPreview.SetPageCaption(#$8868#$60C5#$30E2#$30FC#$30D5);
    mspEyeBlink:
      FMorphPreview.SetPageCaption(#$76EE#$30D1#$30C1#$30E2#$30FC#$30D5);
    mspLipSync:
      FMorphPreview.SetPageCaption(#$53E3#$30D1#$30AF#$30E2#$30FC#$30D5);
  end;
  FViewport.ReadOnly := True;
  FViewport.SetDisplayVisibility(True, False);
  if not FViewport.FocusPreviewBone(#$982D, 4.0) then
    FViewport.FocusPreviewBone(#$9996, 4.0);
end;

procedure BuildModeIcons(Images: TImageList; Size: Integer; Color: TColor);
var
  Bitmap: TBitmap;
  DrawColor: TColor;
  Index: Integer;
begin
  Images.Clear;
  Images.Width := Size;
  Images.Height := Size;
  Images.Masked := True;
  Images.BkColor := clNone;
  Bitmap := TBitmap.Create;
  try
    Bitmap.PixelFormat := pf24bit;
    Bitmap.SetSize(Size, Size);
    for Index := 0 to 3 do
    begin
      Bitmap.Canvas.Brush.Style := bsSolid;
      Bitmap.Canvas.Brush.Color := ModeIconMask;
      Bitmap.Canvas.FillRect(Rect(0, 0, Size, Size));
      case Index of
        0: DrawColor := ModePoseColor;
        1: DrawColor := ModeExpressionColor;
        2: DrawColor := ModeEyeColor;
        3: DrawColor := ModeMouthColor;
      else
        DrawColor := Color;
      end;
      DrawModeIcon(Bitmap.Canvas, Index, Size, DrawColor);
      Images.AddMasked(Bitmap, ModeIconMask);
    end;
  finally
    Bitmap.Free;
  end;
end;

procedure TPmxPoseEditorForm.ModeToolbarCustomDraw(Sender: TToolBar;
  const ARect: TRect; var DefaultDraw: Boolean);
begin
  Sender.Canvas.Brush.Color := ModeToolbarBackground;
  Sender.Canvas.FillRect(ARect);
  DefaultDraw := True;
end;

procedure TPmxPoseEditorForm.ModeToolbarCustomDrawButton(Sender: TToolBar;
  Button: TToolButton; State: TCustomDrawState; var DefaultDraw: Boolean);
var
  ButtonRect: TRect;
  Color: TColor;
begin
  ButtonRect := Button.BoundsRect;
  if cdsChecked in State then
    Color := ModeToolbarChecked
  else if cdsSelected in State then
    Color := ModeToolbarPressed
  else if cdsHot in State then
    Color := ModeToolbarHot
  else
    Color := ModeToolbarBackground;
  Sender.Canvas.Brush.Color := Color;
  Sender.Canvas.FillRect(ButtonRect);
  // 未実装項目も用途を色で判別できるよう、アイコン自体はカラー表示する。
  if (Button.ImageIndex >= 0) and (Button.ImageIndex < FModeImages.Count) then
    FModeImages.Draw(Sender.Canvas,
      ButtonRect.Left + (ButtonRect.Width - FModeImages.Width) div 2,
      ButtonRect.Top + (ButtonRect.Height - FModeImages.Height) div 2,
      Button.ImageIndex, True);
  DefaultDraw := False;
end;

procedure TPmxPoseEditorForm.ConfigureTransactionControls;
var
  Button: TToolButton;
  IconSize, PPI, ToolbarSize: Integer;

  function AddMode(const Caption, Hint: string; ImageIndex: Integer;
    Enabled, Down: Boolean): TToolButton;
  begin
    Result := TToolButton.Create(Self);
    Result.Parent := FModeToolbar;
    Result.Caption := Caption;
    Result.Hint := Hint;
    Result.ShowHint := True;
    Result.ImageIndex := ImageIndex;
    Result.Tag := ImageIndex;
    Result.Style := tbsCheck;
    Result.Grouped := True;
    Result.Enabled := Enabled;
    Result.Down := Down;
    Result.OnClick := ModeButtonClick;
    FModeButtons[TPmxModelSettingPage(ImageIndex)] := Result;
  end;

begin
  PPI := CurrentPPI;
  if PPI <= 0 then
    PPI := 96;
  ToolbarSize := MulDiv(30, PPI, 96);
  IconSize := MulDiv(20, PPI, 96);

  FModeImages := TImageList.Create(Self);
  BuildModeIcons(FModeImages, IconSize, ModeToolbarForeground);
  FModeToolbar := TToolBar.Create(Self);
  FModeToolbar.Parent := Self;
  FModeToolbar.Align := alTop;
  FModeToolbar.Height := ToolbarSize;
  FModeToolbar.ButtonWidth := ToolbarSize;
  FModeToolbar.ButtonHeight := ToolbarSize;
  FModeToolbar.Color := ModeToolbarBackground;
  FModeToolbar.Flat := True;
  FModeToolbar.ShowCaptions := False;
  FModeToolbar.ShowHint := True;
  FModeToolbar.Wrapable := False;
  FModeToolbar.Images := FModeImages;
  FModeToolbar.OnCustomDraw := ModeToolbarCustomDraw;
  FModeToolbar.OnCustomDrawButton := ModeToolbarCustomDrawButton;
  AddMode(#$53E3#$30D1#$30AF, #$53E3#$30D1#$30AF,
    3, True, False);
  AddMode(#$76EE#$30D1#$30C1, #$76EE#$30D1#$30C1, 2, True, False);
  AddMode(#$8868#$60C5, #$8868#$60C5, 1, True, False);
  Button := AddMode(#$30DD#$30FC#$30BA, #$30DD#$30FC#$30BA,
    0, True, True);
  Button.AllowAllUp := False;
  FModeToolbar.BringToFront;

  // ポーズページからモーフ欄を外し、他の3ページだけで共用する。
  FMorphPreview.Visible := False;
  ShowSettingPage(mspPose);

  // 共通GUI側の確定／キャンセルは使用しない。閉じた時点を確定とする。
  FDialogButtonPanel.Visible := False;

  FCommitPanel := TPanel.Create(Self);
  FCommitPanel.Parent := Self;
  FCommitPanel.Align := alBottom;
  FCommitPanel.Height := MulDiv(55, PPI, 96);
  FCommitPanel.BevelOuter := bvNone;
  FCommitPanel.BevelKind := bkTile;
  FCommitPanel.BevelEdges := [beTop];
  FCommitPanel.ParentBackground := False;
  FCommitPanel.Color := MmdEditorPanel;
  FCommitPanel.Font.Color := MmdEditorText;

  FSaveButton := TMmdDarkButton.Create(Self);
  FSaveButton.Parent := FCommitPanel;
  FSaveButton.Caption := #$9589#$3058#$308B;
  FSaveButton.ModalResult := mrOk;
  FSaveButton.Default := True;
  FSaveButton.SetBounds(FCommitPanel.ClientWidth - MulDiv(127, PPI, 96),
    MulDiv(10, PPI, 96), MulDiv(111, PPI, 96), MulDiv(32, PPI, 96));
  FSaveButton.Anchors := [akTop, akRight];

  OnCloseQuery := FormCloseQuery;
end;

procedure TPmxPoseEditorForm.FormCloseQuery(Sender: TObject;
  var CanClose: Boolean);
begin
  // このモデル設定画面は、閉じた時点のポーズを採用する。
  ModalResult := mrOk;
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
