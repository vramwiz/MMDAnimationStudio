program MmdSerifHostUiSmokeTest;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Classes,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.Forms,
  Vcl.Graphics,
  Vcl.StdCtrls,
  MmdSerifAviUtlAdapter in
    '..\Source\Plugin\Serif\AviUtl\MmdSerifAviUtlAdapter.pas',
  MmdSerifHost in
    '..\Source\Plugin\Serif\Host\MmdSerifHost.pas';

var
  HostForm: TForm;
  HostPanel: TPanel;
  SerifHost: TMmdSerifHost;
  MonitorFrame: TComponent;
  StartButton: TButton;

begin
  try
    Application.Initialize;
    HostForm := TForm.Create(nil);
    try
      HostPanel := TPanel.Create(HostForm);
      HostPanel.Parent := HostForm;
      HostPanel.Align := alClient;
      HostForm.Show;
      Application.ProcessMessages;

      SerifHost := TMmdSerifHost.Create(HostForm, HostPanel);
      try
        if Assigned(SerifHost.Frame) then
          raise Exception.Create('Serif frame was not created lazily');
        SerifHost.Show;
        Application.ProcessMessages;
        if not Assigned(SerifHost.Frame) or
           (SerifHost.Frame.Parent <> HostPanel) or
           (SerifHost.Frame.Align <> alClient) or
           not SerifHost.Frame.Visible then
          raise Exception.Create('Serif host bootstrap was not attached');
        if SerifHost.Frame.tbView.Visible or
           SerifHost.Frame.tbBoard.Visible then
          raise Exception.Create('MMD Serif display pages were not disabled');
        MonitorFrame := SerifHost.Frame.FindComponent('FrameSerifMonitor');
        if not Assigned(MonitorFrame) then
          raise Exception.Create('Serif monitor frame was not created');
        StartButton := MonitorFrame.FindComponent('btnStartStop') as TButton;
        if StartButton.ParentFont or (StartButton.Font.Height <> -13) then
          raise Exception.CreateFmt(
            'Serif start button font is not fixed to 13px: ParentFont=%s Height=%d',
            [BoolToStr(StartButton.ParentFont, True), StartButton.Font.Height]);
      finally
        SerifHost.Free;
      end;
    finally
      HostForm.Free;
    end;
    Writeln('MmdSerifHostUiSmokeTest: PASS');
  except
    on E: Exception do
    begin
      Writeln(E.ClassName + ': ' + E.Message);
      ExitCode := 1;
    end;
  end;
end.
