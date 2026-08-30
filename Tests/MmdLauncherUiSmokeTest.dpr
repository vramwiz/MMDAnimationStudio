program MmdLauncherUiSmokeTest;

{$APPTYPE CONSOLE}

uses
  System.Classes,
  System.IOUtils,
  System.SysUtils,
  Winapi.CommCtrl,
  Winapi.Windows,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.Forms,
  Vcl.Graphics,
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
  DarkThemeColors in '..\..\AviUtl2PluginLib\Lib\DarkTheme\Core\DarkThemeColors.pas',
  DarkThemeMetrics in '..\..\AviUtl2PluginLib\Lib\DarkTheme\Core\DarkThemeMetrics.pas',
  DarkThemeDpiContext in '..\..\AviUtl2PluginLib\Lib\DarkTheme\Core\DarkThemeDpiContext.pas',
  DarkButton in '..\..\AviUtl2PluginLib\Lib\DarkTheme\VclControls\Basic\DarkButton.pas',
  DarkCheckListBox in '..\..\AviUtl2PluginLib\Lib\DarkTheme\VclControls\Selection\DarkCheckListBox.pas',
  DarkComboBox in '..\..\AviUtl2PluginLib\Lib\DarkTheme\VclControls\Input\DarkComboBox.pas',
  DarkEdit in '..\..\AviUtl2PluginLib\Lib\DarkTheme\VclControls\Input\DarkEdit.pas',
  DarkMemo in '..\..\AviUtl2PluginLib\Lib\DarkTheme\VclControls\Input\DarkMemo.pas',
  DarkLabel in '..\..\AviUtl2PluginLib\Lib\DarkTheme\VclControls\Basic\DarkLabel.pas',
  DarkListBox in '..\..\AviUtl2PluginLib\Lib\DarkTheme\VclControls\Selection\DarkListBox.pas',
  DarkTreeView in '..\..\AviUtl2PluginLib\Lib\DarkTheme\VclControls\Selection\DarkTreeView.pas',
  DarkPanel in '..\..\AviUtl2PluginLib\Lib\DarkTheme\VclControls\Basic\DarkPanel.pas',
  MmdPoseEditorListTheme in '..\..\AviUtl2PluginLib\MMD\Editor\Theme\MmdPoseEditorListTheme.pas',
  ConfirmDialogForm in '..\..\AviUtl2PluginLib\Lib\ConfirmDialog\ConfirmDialogForm.pas' {FormConfirmDialog},
  LauncherFrame in '..\..\AviUtl2PluginLib\Launcher\LauncherFrame.pas' {FrameLauncher: TFrame},
  LauncherListFrame in '..\..\AviUtl2PluginLib\Launcher\LauncherListFrame.pas' {FrameLauncherList: TFrame},
  LauncherListItems in '..\..\AviUtl2PluginLib\Launcher\LauncherListItems.pas',
  LauncherListTypes in '..\..\AviUtl2PluginLib\Launcher\LauncherListTypes.pas',
  LauncherListView in '..\..\AviUtl2PluginLib\Launcher\LauncherListView.pas',
  LauncherGlobalHotkeys in '..\..\AviUtl2PluginLib\Launcher\LauncherGlobalHotkeys.pas',
  LauncherRunningState in '..\..\AviUtl2PluginLib\Launcher\LauncherRunningState.pas',
  LauncherShellUtils in '..\..\AviUtl2PluginLib\Launcher\LauncherShellUtils.pas',
  LauncherWizardFrame in '..\..\AviUtl2PluginLib\Launcher\LauncherWizardFrame.pas' {FrameLauncherWizard: TFrame};

const
  LauncherWizardUiDpi = 126;

var
  ExecutableFile: string;
  DpiButton1: TDarkButton;
  DpiButton2: TDarkButton;
  DpiCheckList: TDarkCheckListBox;
  DpiContext: TDarkThemeDpiContext;
  DpiCombo: TDarkComboBox;
  DpiEdit: TDarkEdit;
  DpiLabel: TDarkLabel;
  DpiListBox: TDarkListBox;
  DpiMemo: TDarkMemo;
  DpiPanel: TDarkPanel;
  DpiTree: TDarkTreeView;
  ConfirmForm: TFormConfirmDialog;
  Frame: TFrameLauncher;
  HostForm: TForm;
  HostPanel: TPanel;
  FontPanel: TPanel;
  InheritedList: TMmdDarkListBox;
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

      DpiContext := TDarkThemeDpiContext.Create(HostForm);
      DpiButton1 := TDarkButton.Create(HostForm);
      DpiButton2 := TDarkButton.Create(HostForm);
      DpiButton1.Parent := HostPanel;
      DpiButton2.Parent := HostPanel;
      DpiCheckList := TDarkCheckListBox.Create(HostForm);
      DpiCheckList.Parent := HostPanel;
      DpiCombo := TDarkComboBox.Create(HostForm);
      DpiCombo.Parent := HostPanel;
      DpiEdit := TDarkEdit.Create(HostForm);
      DpiEdit.Parent := HostPanel;
      DpiMemo := TDarkMemo.Create(HostForm);
      DpiMemo.Parent := HostPanel;
      DpiPanel := TDarkPanel.Create(HostForm);
      DpiPanel.Parent := HostPanel;
      DpiLabel := TDarkLabel.Create(HostForm);
      DpiLabel.Parent := HostPanel;
      DpiListBox := TDarkListBox.Create(HostForm);
      DpiListBox.Parent := HostPanel;
      DpiTree := TDarkTreeView.Create(HostForm);
      DpiTree.Parent := HostPanel;
      DpiButton1.DpiContext := DpiContext;
      DpiButton2.DpiContext := DpiContext;
      DpiCheckList.DpiContext := DpiContext;
      DpiCombo.DpiContext := DpiContext;
      DpiEdit.DpiContext := DpiContext;
      DpiMemo.DpiContext := DpiContext;
      DpiMemo.DesignFontHeight := 11;
      DpiPanel.DpiContext := DpiContext;
      DpiPanel.DesignHeight := DarkThemeButtonHeight;
      DpiLabel.DpiContext := DpiContext;
      DpiListBox.DpiContext := DpiContext;
      DpiTree.DpiContext := DpiContext;
      DpiLabel.DesignHeight := 27;
      DpiContext.Dpi := 144;
      DpiCheckList.Items.Add('pose');
      DpiCheckList.Checked[0] := True;
      if (DpiCheckList.Font.Height <> -ScaleDarkThemeValue(12, 144)) or
        (DpiCheckList.ItemHeight <> ScaleDarkThemeValue(24, 144)) or
        not DpiCheckList.Checked[0] then
        raise Exception.Create('dark check list did not preserve metrics and state');
      DpiListBox.Items.Add('layer');
      if (DpiListBox.Font.Height <> -ScaleDarkThemeValue(12, 144)) or
        (DpiListBox.ItemHeight <> ScaleDarkThemeValue(24, 144)) or
        (DpiListBox.Color <> DarkThemeListBackground) then
        raise Exception.Create('dark list box did not apply shared metrics');
      DpiTree.Items.Add(nil, 'folder');
      if (DpiTree.Handle = 0) or
        (DpiTree.Font.Height <> -ScaleDarkThemeValue(12, 144)) or
        (DpiTree.Indent < ScaleDarkThemeValue(16, 144)) or
        (SendMessage(DpiTree.Handle, TVM_GETITEMHEIGHT, 0, 0) <>
          ScaleDarkThemeValue(20, 144)) or
        (DpiTree.Color <> DarkThemeTreeBackground) then
        raise Exception.CreateFmt(
          'dark tree view did not apply shared metrics (%d, %d, %d)',
          [DpiTree.Font.Height, DpiTree.Indent, DpiTree.Color]);
      DpiCombo.Items.Add('scene');
      DpiCombo.ItemIndex := 0;
      if (DpiCombo.Font.Height <> -ScaleDarkThemeValue(12, 144)) or
        (DpiCombo.ItemHeight <> ScaleDarkThemeValue(24, 144)) or
        (DpiCombo.Color <> DarkThemeComboBackground) then
        raise Exception.Create('dark combo did not apply shared metrics');
      if (DpiButton1.Height <> DpiButton2.Height) or
        (DpiButton1.Font.Height <> DpiButton2.Font.Height) or
        (DpiButton1.Height <> ScaleDarkThemeValue(DarkThemeButtonHeight, 144)) then
        raise Exception.Create('shared DPI context did not keep button metrics equal');
      if DpiPanel.Height <> ScaleDarkThemeValue(DarkThemeButtonHeight, 144) then
        raise Exception.Create('dark panel did not apply its design height');
      if (DpiLabel.Height <> ScaleDarkThemeValue(27, 144)) or
        (DpiLabel.Font.Height <> -ScaleDarkThemeValue(
          DarkThemeDefaultFontHeight, 144)) then
        raise Exception.Create('dark label did not apply shared DPI metrics');
      DpiLabel.Enabled := False;
      if DpiLabel.Font.Color <> DarkThemeTextDisabled then
        raise Exception.Create('dark label did not apply disabled text color');
      DpiEdit.Text := '12.5';
      if (DpiEdit.Height <> ScaleDarkThemeValue(30, 144)) or
        (DpiEdit.Font.Height <> -ScaleDarkThemeValue(
          DarkThemeDefaultFontHeight, 144)) or (DpiEdit.Text <> '12.5') then
        raise Exception.Create('dark edit did not apply shared DPI metrics');
      DpiEdit.Enabled := False;
      if (DpiEdit.Color <> DarkThemeEditDisabled) or
        (DpiEdit.Font.Color <> DarkThemeEditDisabledText) then
        raise Exception.Create('dark edit did not apply disabled colors');
      DpiEdit.Enabled := True;
      DpiMemo.Text := 'line 1' + sLineBreak + 'line 2';
      if (DpiMemo.Font.Height <> -ScaleDarkThemeValue(11, 144)) or
        (DpiMemo.Text <> 'line 1' + sLineBreak + 'line 2') then
        raise Exception.Create('dark memo did not apply shared DPI metrics');
      DpiMemo.Enabled := False;
      if (DpiMemo.Color <> DarkThemeEditDisabled) or
        (DpiMemo.Font.Color <> DarkThemeEditDisabledText) then
        raise Exception.Create('dark memo did not apply disabled colors');
      DpiMemo.Enabled := True;
      HostForm.Show;
      DpiEdit.SetFocus;
      Application.ProcessMessages;
      if not DpiEdit.Focused or
        (DpiEdit.Color <> DarkThemeEditBackgroundFocus) then
        raise Exception.Create('dark edit did not apply focus colors');
      DpiMemo.SetFocus;
      Application.ProcessMessages;
      if not DpiMemo.Focused or
        (DpiMemo.Color <> DarkThemeEditBackgroundFocus) then
        raise Exception.Create('dark memo did not apply focus colors');
      HostForm.Hide;

      FontPanel := TPanel.Create(HostForm);
      FontPanel.Parent := HostForm;
      FontPanel.ParentFont := False;
      FontPanel.Font.Height := -24;
      InheritedList := TMmdDarkListBox.Create(HostForm);
      InheritedList.Parent := FontPanel;
      if not InheritedList.ParentFont or (InheritedList.Font.Height <> -24) then
        raise Exception.Create('MMD list did not inherit the scaled form font');

      ConfirmForm := TFormConfirmDialog.Create(HostForm);
      try
        ConfirmForm.ApplyDpi(144);
        ThemedButtonCount := 0;
        for I := 0 to ConfirmForm.Panel1.ControlCount - 1 do
          if ConfirmForm.Panel1.Controls[I] is TDarkButton then
            Inc(ThemedButtonCount);
        if not (ConfirmForm.Panel1 is TDarkPanel) or
          not (ConfirmForm.PanelCaption is TDarkPanel) or
          (ConfirmForm.Panel1.Color <> DarkThemePanelBackground) or
          (ThemedButtonCount <> 2) then
          raise Exception.Create('confirm dialog did not use shared dark buttons');
      finally
        ConfirmForm.Free;
      end;

      Frame := TFrameLauncher.Create(HostForm);
      Frame.Parent := HostPanel;
      Frame.Align := alClient;
      Frame.Show;
      Application.ProcessMessages;

      Wizard := TFrameLauncherWizard.Create(HostForm);
      try
        Wizard.Parent := HostPanel;
        // AviUtl2の高DPI親へ埋め込まれた状態を再現する。登録画面は表示時に
        // 独自描画ランチャー一覧と同じ96 DPI座標へ戻らなければならない。
        Wizard.ScaleForPPI(192);
        Wizard.Show;
        Application.ProcessMessages;
        ThemedButtonCount := 0;
        for I := 0 to Wizard.Panel1.ControlCount - 1 do
          if Wizard.Panel1.Controls[I] is TDarkButton then
          begin
            Inc(ThemedButtonCount);
            if TDarkButton(Wizard.Panel1.Controls[I]).Font.Height <>
              -ScaleDarkThemeValue(DarkThemeDefaultFontHeight,
                LauncherWizardUiDpi) then
              raise Exception.Create('launcher wizard button font was scaled twice');
          end;
        if not (Wizard.Panel1 is TDarkPanel) or
          (Wizard.Panel1.Color <> DarkThemePanelBackground) or
          (Wizard.Panel1.Height <> ScaleDarkThemeValue(
            DarkThemeButtonHeight, LauncherWizardUiDpi)) or
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
