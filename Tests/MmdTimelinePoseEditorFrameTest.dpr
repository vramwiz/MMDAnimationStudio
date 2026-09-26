program MmdTimelinePoseEditorFrameTest;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Types,
  Vcl.Controls,
  Vcl.ComCtrls,
  Vcl.Forms,
  Vcl.Graphics,
  Winapi.CommCtrl,
  Winapi.Windows,
  DarkLabel,
  MmdD3DViewport,
  MmdTimelinePoseBinding,
  MmdTimelinePoseEditorFrame;

var
  Form: TForm;
  Frame: TFrameMmdTimelinePoseEditor;
  Snapshot: TMmdTimelinePoseSnapshot;
  Index: Integer;
  Toolbar: TToolBar;
  ButtonRect: TRect;

begin
  Application.Initialize;
  try
    if ParamCount <> 1 then
      raise Exception.Create('PMX path is required');
    Form := TForm.CreateNew(nil);
    try
      Form.SetBounds(0, 0, 250, 480);
      // ホスト側が大きな文字を指定しても案内欄は編集画面の文字高を使う。
      Form.Font.Height := -36;
      Form.Show;
      Application.ProcessMessages;
      Frame := TFrameMmdTimelinePoseEditor.Create(Form);
      Frame.Parent := Form;
      Frame.Align := alClient;
      Frame.InitializeControls;
      Application.ProcessMessages;
      Toolbar := nil;
      for Index := 0 to Frame.ControlCount - 1 do
        if Frame.Controls[Index] is TToolBar then
          Toolbar := TToolBar(Frame.Controls[Index]);
      if Toolbar = nil then
        raise Exception.Create('pose editor command toolbar is missing');
      if Toolbar.Height < Toolbar.ButtonHeight then
        raise Exception.Create('pose editor command icons exceed toolbar height');
      if (Toolbar.Perform(TB_GETITEMRECT, 0, LPARAM(@ButtonRect)) <> 0) and
        (ButtonRect.Bottom > Toolbar.Height) then
        raise Exception.Create('pose editor command button exceeds toolbar bounds');
      Snapshot.ObjectId := 1;
      Snapshot.ModelFile := ParamStr(1);
      Snapshot.PoseData := '{"version":1,"bones":[]}';
      Frame.BindSnapshot(Snapshot);
      if not Frame.Bound then
        raise Exception.Create('pose editor did not bind the selected model');
      for Index := 0 to Frame.ComponentCount - 1 do
      begin
        if Frame.Components[Index] is TMmdD3DViewport then
          raise Exception.Create('pose editor created a preview viewport');
        if Frame.Components[Index] is TDarkLabel then
          if Abs(TDarkLabel(Frame.Components[Index]).Font.Height) >=
            Abs(Form.Font.Height) then
            raise Exception.Create('status text inherited the host font size');
      end;
      Frame.ClearTarget;
      if Frame.Bound then
        raise Exception.Create('pose editor retained the cleared target');
    finally
      Form.Free;
    end;
    Writeln('MmdTimelinePoseEditorFrameTest: PASS');
  except
    on E: Exception do
    begin
      Writeln(E.ClassName + ': ' + E.Message);
      ExitCode := 1;
    end;
  end;
end.
