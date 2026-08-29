program MmdLauncherUiSmokeTest;

{$APPTYPE CONSOLE}

uses
  System.Classes,
  System.IOUtils,
  System.SysUtils,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.Forms,
  RTTIPersistent in '..\..\AviUtl2PluginLib\Lib\RTTIPersistent\RTTIPersistent.pas',
  RTTIPersistentIni in '..\..\AviUtl2PluginLib\Lib\RTTIPersistent\RTTIPersistentIni.pas',
  RTTIPersistentFrame in '..\..\AviUtl2PluginLib\Lib\RTTIPersistent\RTTIPersistentFrame.pas',
  SectionFileManager in '..\..\AviUtl2PluginLib\Lib\SectionFileManager\SectionFileManager.pas',
  ListViewEx in '..\..\AviUtl2PluginLib\Lib\ListViewEdit\ListViewEx.pas',
  ToolbarButtons in '..\..\AviUtl2PluginLib\Lib\ToolBar\ToolbarButtons.pas',
  ToolbarIcon in '..\..\AviUtl2PluginLib\Lib\ToolBar\ToolbarIcon.pas',
  ShortcutAction in '..\..\AviUtl2PluginLib\Lib\ShortcutAction\ShortcutAction.pas',
  WindowInfoList in '..\..\AviUtl2PluginLib\Lib\WindowInfoList\WindowInfoList.pas',
  AppFolderUtils in '..\..\AviUtl2PluginLib\Lib\AppFolderUtils\AppFolderUtils.pas',
  AviUtl2StyleColors in '..\..\AviUtl2PluginLib\Lib\Style\AviUtl2StyleColors.pas',
  SpeedButtonAviUtlStyle in '..\..\AviUtl2PluginLib\Lib\SpeedButtonAviUtlStyle\SpeedButtonAviUtlStyle.pas',
  LauncherFrame in '..\..\AviUtl2PluginLib\Launcher\LauncherFrame.pas' {FrameLauncher: TFrame},
  LauncherListFrame in '..\..\AviUtl2PluginLib\Launcher\LauncherListFrame.pas' {FrameLauncherList: TFrame},
  LauncherListItems in '..\..\AviUtl2PluginLib\Launcher\LauncherListItems.pas',
  LauncherListTypes in '..\..\AviUtl2PluginLib\Launcher\LauncherListTypes.pas',
  LauncherListView in '..\..\AviUtl2PluginLib\Launcher\LauncherListView.pas',
  LauncherGlobalHotkeys in '..\..\AviUtl2PluginLib\Launcher\LauncherGlobalHotkeys.pas',
  LauncherRunningState in '..\..\AviUtl2PluginLib\Launcher\LauncherRunningState.pas',
  LauncherShellUtils in '..\..\AviUtl2PluginLib\Launcher\LauncherShellUtils.pas',
  LauncherWizardFrame in '..\..\AviUtl2PluginLib\Launcher\LauncherWizardFrame.pas' {FrameLauncherWizard: TFrame};

var
  ExecutableFile: string;
  Frame: TFrameLauncher;
  HostForm: TForm;
  HostPanel: TPanel;
  I: Integer;
  OriginalDirectory: string;
  TestRoot: string;
  ThemedButtonCount: Integer;
  Wizard: TFrameLauncherWizard;

begin
  TestRoot := TPath.Combine(TPath.GetTempPath,
    'MmdLauncher-' + TPath.GetRandomFileName);
  OriginalDirectory := GetCurrentDir;
  try
    TDirectory.CreateDirectory(TestRoot);
    SetCurrentDir(TestRoot);
    ExecutableFile := TPath.Combine(TestRoot, 'SampleLauncher.exe');
    TFile.WriteAllBytes(ExecutableFile, TBytes.Create(0));

    Application.Initialize;
    HostForm := TForm.Create(nil);
    try
      HostPanel := TPanel.Create(HostForm);
      HostPanel.Parent := HostForm;
      HostPanel.Align := alClient;
      Frame := TFrameLauncher.Create(HostForm);
      Frame.Parent := HostPanel;
      Frame.Align := alClient;
      Frame.Show;
      Application.ProcessMessages;

      Wizard := TFrameLauncherWizard.Create(HostForm);
      try
        Wizard.Parent := HostPanel;
        ThemedButtonCount := 0;
        for I := 0 to Wizard.Panel1.ControlCount - 1 do
          if Wizard.Panel1.Controls[I] is TSpeedButtonAviUtlStyle then
            Inc(ThemedButtonCount);
        if (Wizard.Panel1.Color <> A2SCPanelBackground) or
          Wizard.btnOk.Visible or Wizard.btnCancel.Visible or
          (ThemedButtonCount <> 2) then
          raise Exception.Create('launcher wizard dark buttons were not applied');
      finally
        Wizard.Free;
      end;

      if not Frame.Visible or (Frame.Parent <> HostPanel) or
        not Assigned(Frame.FrameListView) then
        raise Exception.Create('launcher frame was not attached');
      if not Frame.DropFiles(TArray<string>.Create(ExecutableFile)) or
        (Frame.FrameListView.ListView.FileList.Count <> 1) then
        raise Exception.Create('launcher executable registration failed');
      if not TFile.Exists(TPath.Combine(TestRoot, 'LauncherList.ini')) then
        raise Exception.Create('launcher list was not saved');
    finally
      HostForm.Free;
    end;
    Writeln('launcher-shown');
  except
    on E: Exception do
    begin
      Writeln(E.ClassName + ': ' + E.Message);
      ExitCode := 1;
    end;
  end;
  SetCurrentDir(OriginalDirectory);
  if TDirectory.Exists(TestRoot) then
    TDirectory.Delete(TestRoot, True);
end.
