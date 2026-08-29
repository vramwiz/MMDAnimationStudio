program MmdPoseEditorDpiTest;

{$APPTYPE CONSOLE}

uses
  Winapi.Messages,
  Winapi.Windows,
  System.SysUtils,
  System.Types,
  Vcl.ComCtrls,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Graphics,
  HorizontalTrackBarControl,
  MmdLipSyncSettingCodec,
  MmdModelSettingEditor,
  MmdPoseEditor,
  MmdPoseEditorLayout,
  MmdPoseEditorTheme,
  MmdPoseEditorButtonTheme,
  MmdPoseEditorListTheme;

type
  TDarkButtonProbe = class(TMmdDarkButton)
  public
    procedure DrawTo(ABitmap: TBitmap);
  end;
  TLayoutProbe = class(TMmdPoseEditorFormBase)
  public
    procedure CheckLayout(ExpectedPPI: Integer);
    procedure ScaleLayoutAndCheck(TargetPPI: Integer);
  end;

procedure TDarkButtonProbe.DrawTo(ABitmap: TBitmap);
begin
  PaintButton(ABitmap.Canvas);
end;

procedure CheckDarkButtonDrawing(OwnerForm: TForm);
var
  Bitmap: TBitmap;
  Button: TDarkButtonProbe;
begin
  Button := TDarkButtonProbe.Create(OwnerForm);
  Bitmap := TBitmap.Create;
  try
    Button.Parent := OwnerForm;
    Button.Caption := 'Dark';
    Button.SetBounds(0, 0, 80, 30);
    Bitmap.SetSize(Button.Width, Button.Height);
    Bitmap.Canvas.Brush.Color := clWhite;
    Bitmap.Canvas.FillRect(System.Types.Rect(0, 0, Bitmap.Width, Bitmap.Height));
    Button.DrawTo(Bitmap);
    if ColorToRGB(Bitmap.Canvas.Pixels[5, 5]) = ColorToRGB(clWhite) then
      raise Exception.Create('dark button remained white');
    OwnerForm.ModalResult := mrNone;
    Button.Default := True;
    Button.ModalResult := mrOk;
    Button.Perform(CM_DIALOGKEY, VK_RETURN, 0);
    if OwnerForm.ModalResult <> mrOk then
      raise Exception.Create('dark button lost default modal behavior');
    OwnerForm.ModalResult := mrNone;
  finally
    Bitmap.Free;
    Button.Free;
  end;
end;

type
  TEditorProbe = class(TStandardPoseEditorForm)
  public
    procedure CheckCommandBindings;
  end;

procedure TEditorProbe.CheckCommandBindings;
var
  DefaultDraw: Boolean;
begin
  if not Assigned(FUndoButton.OnClick) or not Assigned(FRedoButton.OnClick) or
    not Assigned(FResetBoneButton.OnClick) or
    not Assigned(FResetBranchButton.OnClick) or
    not Assigned(FResetAllButton.OnClick) or
    not Assigned(FSymmetryButton.OnClick) or
    not Assigned(FAutoFitButton.OnClick) then
    raise Exception.Create('toolbar command event is not connected');
  FSymmetryButton.Down := True;
  FSymmetryButton.OnClick(FSymmetryButton);
  if not FViewport.SymmetricEditing then
    raise Exception.Create('symmetry toolbar toggle did not reach the viewport');
  DefaultDraw := False;
  FCommandToolbar.OnCustomDraw(FCommandToolbar, System.Types.Rect(0, 0,
    FCommandToolbar.Width, FCommandToolbar.Height), DefaultDraw);
  if not DefaultDraw then
    raise Exception.Create('toolbar background suppressed button drawing');
end;

procedure TLayoutProbe.CheckLayout(ExpectedPPI: Integer);
var
  ExpectedIconSize, ExpectedMorphHeight: Integer;
begin
  ExpectedIconSize := MulDiv(20, ExpectedPPI, 96);
  ExpectedMorphHeight := MulDiv(245, ExpectedPPI, 96);
  if FMorphPreview.Height <> ExpectedMorphHeight then
    raise Exception.CreateFmt('morph height was not DPI-scaled: %d <> %d',
      [FMorphPreview.Height, ExpectedMorphHeight]);
  if (FCommandToolbar.ButtonCount <> 9) or
    (FCommandImages.Count <> 7) or (FCommandDisabledImages.Count <> 7) then
    raise Exception.Create('command toolbar items are incomplete');
  if (FCommandImages.Width <> ExpectedIconSize) or
    (FCommandImages.Height <> ExpectedIconSize) or
    (FCommandDisabledImages.Width <> ExpectedIconSize) or
    (FCommandDisabledImages.Height <> ExpectedIconSize) then
    raise Exception.CreateFmt('toolbar icons were not DPI-scaled: %d <> %d',
      [FCommandImages.Width, ExpectedIconSize]);
  if FAutoFitButton.Parent <> FCommandToolbar then
    raise Exception.Create('commands were not moved to the top toolbar');
  if FViewport.Width <> ClientWidth - FLeftPanel.Width then
    raise Exception.CreateFmt('viewport did not expand after editor removal: %d <> %d',
      [FViewport.Width, ClientWidth - FLeftPanel.Width]);
  if (Color <> MmdEditorBackground) or
    (FLeftPanel.Color <> MmdEditorBackground) or
    (FDialogButtonPanel.Color <> MmdEditorPanel) then
    raise Exception.Create('dark editor surfaces are incomplete');
  if Cardinal(ColorToRGB(MmdEditorSelection)) <> RGB(102, 102, 255) then
    raise Exception.Create('editor selection is not blue');
  if not (FBoneList is TMmdDarkListBox) then
    raise Exception.Create('bone list does not use dark owner drawing');
  if (FDialogButtonPanel.ControlCount <> 2) or
    not (FDialogButtonPanel.Controls[0] is TMmdDarkButton) or
    not (FDialogButtonPanel.Controls[1] is TMmdDarkButton) then
    raise Exception.Create('dialog buttons do not use dark owner drawing');
  if FSymmetryButton.Style <> tbsCheck then
    raise Exception.Create('symmetry command is not a toggle');
end;

procedure CheckModelSettingModes;
var
  Form: TMmdModelSettingEditorForm;
begin
  // モデル表示の「設定」はポーズ・表情だけを見せる。
  Form := TMmdModelSettingEditorForm.Create(nil);
  try
    Form.ConfigureSettingControls;
    if (Form.ModeToolbar.ButtonCount <> 2) or
      (Form.ModeToolbar.Images = nil) or
      (Form.ModeToolbar.Images.Count <> 2) then
      raise Exception.Create('model setting toolbar is not pose/expression only');
    if (Form.ModeToolbar.Buttons[0].Tag <> Ord(mspPose)) or
      (Form.ModeToolbar.Buttons[1].Tag <> Ord(mspExpression)) then
      raise Exception.Create('model setting toolbar is not pose then expression');
  finally
    Form.Free;
  end;
  // PMXカタログの初期状態編集は従来の全アイコンを維持する。
  Form := TMmdModelSettingEditorForm.Create(nil);
  try
    Form.ConfigureSettingControls(True);
    if (Form.ModeToolbar.ButtonCount <> 4) or
      (Form.ModeToolbar.Images = nil) or
      (Form.ModeToolbar.Images.Count <> 4) then
      raise Exception.Create('initial state toolbar does not have all modes');
    if (Form.EyeBlinkPanel = nil) or
      (Form.EyeBlinkPanel.MorphCombo = nil) then
      raise Exception.Create('eye blink combo is missing');
    if Form.EyeBlinkPanel.MorphCombo.Font.Height <> Form.Font.Height then
      raise Exception.Create('eye blink combo font does not match editor font');
    if (Form.EyeBlinkPanel.HeaderPanel.Caption <> #$76EE#$30D1#$30C1) or
      (Form.EyeBlinkPanel.IntervalEdit = nil) or
      (Form.EyeBlinkPanel.SpeedEdit = nil) or
      (Form.EyeBlinkPanel.OffsetEdit = nil) then
      raise Exception.Create('eye blink page layout is incomplete');
    if (Form.EyeBlinkPanel.HeaderPanel.Top >=
        Form.EyeBlinkPanel.MorphCombo.Top) or
      (Form.EyeBlinkPanel.MorphCombo.Top >=
        Form.EyeBlinkPanel.StageTrack.Top) or
      (Form.EyeBlinkPanel.StageTrack.Top >=
        Form.EyeBlinkPanel.IntervalEdit.Parent.Parent.Top) or
      (Form.EyeBlinkPanel.IntervalEdit.Parent.Top >=
        Form.EyeBlinkPanel.SpeedEdit.Parent.Top) or
      (Form.EyeBlinkPanel.SpeedEdit.Parent.Top >=
        Form.EyeBlinkPanel.OffsetEdit.Parent.Top) then
      raise Exception.CreateFmt(
        'eye blink controls are not in requested order: %d,%d,%d,%d / %d,%d,%d',
        [Form.EyeBlinkPanel.HeaderPanel.Top,
         Form.EyeBlinkPanel.MorphCombo.Top,
         Form.EyeBlinkPanel.StageTrack.Top,
         Form.EyeBlinkPanel.IntervalEdit.Parent.Parent.Top,
         Form.EyeBlinkPanel.IntervalEdit.Parent.Top,
         Form.EyeBlinkPanel.SpeedEdit.Parent.Top,
         Form.EyeBlinkPanel.OffsetEdit.Parent.Top]);
    if Form.EyeBlinkPanel.StageTrack.ClassType <>
      THorizontalTrackBarControl then
      raise Exception.Create('eye blink stage does not use shared trackbar');
    if (Form.LipSyncPanel = nil) or
      (Form.LipSyncPanel.HeaderPanel.Caption <> #$53E3#$30D1#$30AF) or
      (Form.LipSyncPanel.OpenCloseCombo = nil) then
      raise Exception.Create('lip sync page layout is incomplete');
    if Form.LipSyncPanel.OpenCloseCombo.Font.Height <> Form.Font.Height then
      raise Exception.Create('lip sync combo font does not match editor font');
    if (Form.LipSyncPanel.OpenCloseCombo.Parent.Top >=
        Form.LipSyncPanel.PhonemeCombo(mlpA).Parent.Top) or
      (Form.LipSyncPanel.PhonemeCombo(mlpA).Parent.Top >=
        Form.LipSyncPanel.PhonemeCombo(mlpN).Parent.Top) or
      (Form.LipSyncPanel.PhonemeCombo(mlpN).Parent.Top >=
        Form.LipSyncPanel.SpeedEdit.Parent.Top) or
      (Form.LipSyncPanel.SpeedEdit.Parent.Top >=
        Form.LipSyncPanel.StrengthEdit.Parent.Top) then
      raise Exception.Create('lip sync controls are not in requested order');
  finally
    Form.Free;
  end;
end;

procedure TLayoutProbe.ScaleLayoutAndCheck(TargetPPI: Integer);
var
  InitialFontHeight, InitialBoneListFontHeight,
    InitialMorphFontHeight, InitialToolbarFontHeight: Integer;
begin
  InitialFontHeight := Font.Height;
  InitialBoneListFontHeight := FBoneList.Font.Height;
  InitialMorphFontHeight := FMorphPreview.Font.Height;
  InitialToolbarFontHeight := FCommandToolbar.Font.Height;
  ScaleLayoutForPPI(TargetPPI);
  if Font.Height <> InitialFontHeight then
    raise Exception.CreateFmt('font was scaled twice: %d <> %d',
      [Font.Height, InitialFontHeight]);
  if FBoneList.Font.Height <> InitialBoneListFontHeight then
    raise Exception.CreateFmt('bone list font was scaled twice: %d <> %d',
      [FBoneList.Font.Height, InitialBoneListFontHeight]);
  if FMorphPreview.Font.Height <> InitialMorphFontHeight then
    raise Exception.CreateFmt('morph font was scaled twice: %d <> %d',
      [FMorphPreview.Font.Height, InitialMorphFontHeight]);
  if FCommandToolbar.Font.Height <> InitialToolbarFontHeight then
    raise Exception.CreateFmt('toolbar font was scaled twice: %d <> %d',
      [FCommandToolbar.Font.Height, InitialToolbarFontHeight]);
  CheckLayout(TargetPPI);
end;

var
  EditorForm: TEditorProbe;
  Form, ScaledForm: TLayoutProbe;

begin
  Application.Initialize;
  try
    Form := TLayoutProbe.CreateLayout('DPI layout test');
    try
      Form.CheckLayout(Screen.PixelsPerInch);
      CheckDarkButtonDrawing(Form);
    finally
      Form.Free;
    end;
    // GetDpiForWindowはテストプロセスの実DPIを返すため、200%の疑似検証は
    // Handle生成前の別フォームを明示的に192 DPIへ変換して寸法を確認する。
    ScaledForm := TLayoutProbe.CreateLayout('200% DPI layout test');
    try
      ScaledForm.ScaleLayoutAndCheck(192);
    finally
      ScaledForm.Free;
    end;
    EditorForm := TEditorProbe.Create(nil);
    try
      EditorForm.CheckCommandBindings;
    finally
      EditorForm.Free;
    end;
    CheckModelSettingModes;
    Writeln('MmdPoseEditorDpiTest: PASS (including 200%)');
  except
    on E: Exception do
    begin
      Writeln(E.ClassName + ': ' + E.Message);
      ExitCode := 1;
    end;
  end;
end.
