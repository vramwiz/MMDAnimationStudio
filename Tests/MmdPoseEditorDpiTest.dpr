program MmdPoseEditorDpiTest;

{$APPTYPE CONSOLE}

uses
  Winapi.Windows,
  System.SysUtils,
  Vcl.Forms,
  Vcl.Graphics,
  MmdPoseEditorLayout;

type
  TLayoutProbe = class(TMmdPoseEditorFormBase)
  public
    procedure CheckLayout(ExpectedPPI: Integer);
    procedure ScaleLayoutAndCheck(TargetPPI: Integer);
  end;

procedure TLayoutProbe.CheckLayout(ExpectedPPI: Integer);
var
  ExpectedEditWidth, ExpectedMorphHeight: Integer;
begin
  ExpectedEditWidth := MulDiv(120, ExpectedPPI, 96);
  ExpectedMorphHeight := MulDiv(245, ExpectedPPI, 96);
  if FEdits[0].Width <> ExpectedEditWidth then
    raise Exception.CreateFmt('edit width was not DPI-scaled: %d <> %d',
      [FEdits[0].Width, ExpectedEditWidth]);
  if FMorphPreview.Height <> ExpectedMorphHeight then
    raise Exception.CreateFmt('morph height was not DPI-scaled: %d <> %d',
      [FMorphPreview.Height, ExpectedMorphHeight]);
  Canvas.Font.Assign(FApplyButton.Font);
  if FApplyButton.Width <= Canvas.TextWidth(FApplyButton.Caption) then
    raise Exception.Create('apply button caption does not fit');
  Canvas.Font.Assign(FResetBranchButton.Font);
  if FResetBranchButton.Width <= Canvas.TextWidth(FResetBranchButton.Caption) then
    raise Exception.Create('branch reset caption does not fit');
  Canvas.Font.Assign(FAutoFitButton.Font);
  if FAutoFitButton.Width <= Canvas.TextWidth(FAutoFitButton.Caption) then
    raise Exception.Create('auto-fit button caption does not fit');
end;

procedure TLayoutProbe.ScaleLayoutAndCheck(TargetPPI: Integer);
var
  InitialFontHeight: Integer;
begin
  InitialFontHeight := Font.Height;
  ScaleLayoutForPPI(TargetPPI);
  if Font.Height <> InitialFontHeight then
    raise Exception.CreateFmt('font was scaled twice: %d <> %d',
      [Font.Height, InitialFontHeight]);
  CheckLayout(TargetPPI);
end;

var
  Form, ScaledForm: TLayoutProbe;

begin
  Application.Initialize;
  try
    Form := TLayoutProbe.CreateLayout('DPI layout test');
    try
      Form.CheckLayout(Screen.PixelsPerInch);
    finally
      Form.Free;
    end;
    // GetDpiForWindowはテストプロセスの実DPIを返すため、200%の疑似検証は
    // Handle生成前の別フォームを明示的に192 DPIへ変換して寸法を確認する。
    ScaledForm := TLayoutProbe.CreateLayout('200% DPI layout test');
    try
      ScaledForm.ScaleLayoutAndCheck(192);
      Writeln('MmdPoseEditorDpiTest: PASS (including 200%)');
    finally
      ScaledForm.Free;
    end;
  except
    on E: Exception do
    begin
      Writeln(E.ClassName + ': ' + E.Message);
      ExitCode := 1;
    end;
  end;
end.
