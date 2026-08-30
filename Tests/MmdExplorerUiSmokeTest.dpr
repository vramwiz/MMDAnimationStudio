program MmdExplorerUiSmokeTest;

{$APPTYPE CONSOLE}

uses
  System.Classes,
  System.IOUtils,
  System.SysUtils,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.Forms,
  Vcl.Graphics,
  DarkPanel in '..\..\AviUtl2PluginLib\Lib\DarkTheme\VclControls\Basic\DarkPanel.pas',
  AppFolderUtils in '..\..\AviUtl2PluginLib\Lib\AppFolderUtils\AppFolderUtils.pas',
  AviUtl2StyleColors in '..\..\AviUtl2PluginLib\Lib\Style\AviUtl2StyleColors.pas',
  ExplorerAviUtlBridge in '..\..\AviUtl2PluginLib\Explorer\AviUtl\ExplorerAviUtlBridge.pas',
  ExplorerAliasBuilder in '..\..\AviUtl2PluginLib\Explorer\AviUtl\ExplorerAliasBuilder.pas',
  ExplorerHistFrame in '..\..\AviUtl2PluginLib\Explorer\Hist\ExplorerHistFrame.pas' {FrameExplorerHist: TFrame},
  ExplorerHistListBox in '..\..\AviUtl2PluginLib\Explorer\Hist\ExplorerHistListBox.pas',
  ExplorerListPicture in '..\..\AviUtl2PluginLib\Explorer\ListView\Picture\ExplorerListPicture.pas',
  AviUtl2Picture in '..\..\AviUtl2PluginLib\Explorer\AviUtl\AviUtl2Picture.pas',
  ExplorerFrame in '..\..\AviUtl2PluginLib\Explorer\ExplorerFrame.pas' {FrameExplorer: TFrame};

function TestFrameDuration: Double;
begin
  Result := 1 / 30;
end;

procedure TestSelectedAlias(List: TStringList);
begin
  List.Add('[0]');
end;

var
  AliasFile: string;
  AliasText: string;
  Frame: TFrameExplorer;
  HostForm: TForm;
  HostPanel: TPanel;
  HistoryFrame: TFrameExplorerHist;
  OriginalDirectory: string;
  Picture: TExplorerFilePicturelItem;
  SelectedAlias: TStringList;
  TestRoot: string;

begin
  TestRoot := TPath.Combine(TPath.GetTempPath,
    'MmdExplorer-' + TPath.GetRandomFileName);
  OriginalDirectory := GetCurrentDir;
  try
    TDirectory.CreateDirectory(TestRoot);
    SetCurrentDir(TestRoot);
    SetExplorerAviUtlBridge(TestFrameDuration, TestSelectedAlias);

    SelectedAlias := TStringList.Create;
    try
      ExplorerGetSelectedAlias(SelectedAlias);
      if (SelectedAlias.Count <> 1) or (SelectedAlias[0] <> '[0]') then
        raise Exception.Create('selected alias bridge failed');
    finally
      SelectedAlias.Free;
    end;

    Picture := TExplorerFilePicturelItem.Create;
    try
      Picture.FileName := TPath.Combine(TestRoot, 'sample.png');
      AliasFile := AviUtl2PictureDandD(Picture);
      if not TFile.Exists(AliasFile) then
        raise Exception.Create('picture alias was not generated');
      AliasText := TFile.ReadAllText(AliasFile, TEncoding.UTF8);
      if not AliasText.Contains('frame=0,90') or
        not AliasText.Contains('effect.name=' +
          #$753B#$50CF#$30D5#$30A1#$30A4#$30EB) then
        raise Exception.Create('picture alias format changed');
    finally
      Picture.Free;
    end;

    Application.Initialize;
    HostForm := TForm.Create(nil);
    try
      HistoryFrame := TFrameExplorerHist.Create(HostForm);
      try
        if HistoryFrame.ListBox.ParentFont or
          (HistoryFrame.ListBox.Font.Height <> -11) or
          (HistoryFrame.ListBox.ItemHeight <> 24) then
          raise Exception.Create('explorer history font metrics changed');
      finally
        HistoryFrame.Free;
      end;
      HostPanel := TPanel.Create(HostForm);
      HostPanel.Parent := HostForm;
      HostPanel.Align := alClient;
      Frame := TFrameExplorer.Create(HostForm);
      Frame.Parent := HostPanel;
      Frame.Align := alClient;
      Frame.Show;
      if not (Frame.PanelConfig is TDarkPanel) or
        not (Frame.PanelExplorer is TDarkPanel) or
        not (Frame.PanelTool is TDarkPanel) or
        not (Frame.PanelEdit is TDarkPanel) or
        not (Frame.PanelFavorite is TDarkPanel) or
        not (Frame.PanelTree is TDarkPanel) then
        raise Exception.Create('explorer containers are not dark panels');
      Frame.DropFile(TArray<string>.Create(TestRoot));
      Application.ProcessMessages;
      if not Frame.Visible or (Frame.Parent <> HostPanel) then
        raise Exception.Create('explorer frame was not attached');
    finally
      HostForm.Free;
    end;
    Writeln('explorer-shown');
  except
    on E: Exception do
    begin
      Writeln(E.ClassName + ': ' + E.Message);
      ExitCode := 1;
    end;
  end;
  ClearExplorerAviUtlBridge;
  SetCurrentDir(OriginalDirectory);
  if TDirectory.Exists(TestRoot) then
    TDirectory.Delete(TestRoot, True);
end.
