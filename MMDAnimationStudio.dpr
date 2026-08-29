library MMDAnimationStudio;

uses
  Winapi.Windows,
  System.SysUtils,
  AppFolderUtils in '..\AviUtl2PluginLib\Lib\AppFolderUtils\AppFolderUtils.pas',
  AviUtl2StyleColors in '..\AviUtl2PluginLib\Lib\Style\AviUtl2StyleColors.pas',
  AviUtl2PluginTypes in '..\Syncroh2\AviUtl\Plugin\AviUtl2PluginTypes.pas',
  AviUtl2PluginCore in '..\Syncroh2\AviUtl\Plugin\AviUtl2PluginCore.pas',
  AviUtl2AliasSelected in '..\Syncroh2\AviUtl\Plugin\Alias\AviUtl2AliasSelected.pas',
  AviUtl2TimeConvert in '..\Syncroh2\AviUtl\AviUtl2TimeConvert.pas',
  ShortcutAction in '..\AviUtl2PluginLib\Lib\ShortcutAction\ShortcutAction.pas',
  ConfirmDialogForm in '..\AviUtl2PluginLib\Lib\ConfirmDialog\ConfirmDialogForm.pas' {FormConfirmDialog},
  RTTIPersistent in '..\AviUtl2PluginLib\Lib\RTTIPersistent\RTTIPersistent.pas',
  RTTIPersistentIni in '..\AviUtl2PluginLib\Lib\RTTIPersistent\RTTIPersistentIni.pas',
  RTTIPersistentFrame in '..\AviUtl2PluginLib\Lib\RTTIPersistent\RTTIPersistentFrame.pas',
  SectionFileManager in '..\AviUtl2PluginLib\Lib\SectionFileManager\SectionFileManager.pas',
  ListViewEx in '..\AviUtl2PluginLib\Lib\ListViewEdit\ListViewEx.pas',
  ToolbarButtons in '..\AviUtl2PluginLib\Lib\ToolBar\ToolbarButtons.pas',
  ToolbarIcon in '..\AviUtl2PluginLib\Lib\ToolBar\ToolbarIcon.pas',
  WindowInfoList in '..\AviUtl2PluginLib\Lib\WindowInfoList\WindowInfoList.pas',
  ExplorerAviUtlBridge in '..\AviUtl2PluginLib\Explorer\AviUtl\ExplorerAviUtlBridge.pas',
  ExplorerAliasBuilder in '..\AviUtl2PluginLib\Explorer\AviUtl\ExplorerAliasBuilder.pas',
  ExplorerFrame in '..\AviUtl2PluginLib\Explorer\ExplorerFrame.pas' {FrameExplorer: TFrame},
  LauncherFrame in '..\AviUtl2PluginLib\Launcher\LauncherFrame.pas' {FrameLauncher: TFrame},
  LauncherListFrame in '..\AviUtl2PluginLib\Launcher\LauncherListFrame.pas' {FrameLauncherList: TFrame},
  LauncherListItems in '..\AviUtl2PluginLib\Launcher\LauncherListItems.pas',
  LauncherListTypes in '..\AviUtl2PluginLib\Launcher\LauncherListTypes.pas',
  LauncherListView in '..\AviUtl2PluginLib\Launcher\LauncherListView.pas',
  LauncherGlobalHotkeys in '..\AviUtl2PluginLib\Launcher\LauncherGlobalHotkeys.pas',
  LauncherRunningState in '..\AviUtl2PluginLib\Launcher\LauncherRunningState.pas',
  LauncherShellUtils in '..\AviUtl2PluginLib\Launcher\LauncherShellUtils.pas',
  LauncherWizardFrame in '..\AviUtl2PluginLib\Launcher\LauncherWizardFrame.pas' {FrameLauncherWizard: TFrame},
  MMDAnimationStudioExtension in 'Source\Plugin\Extension\MMDAnimationStudioExtension.pas',
  MMDAnimationStudioToolbarIcons in 'Source\Plugin\Extension\MMDAnimationStudioToolbarIcons.pas',
  MMDAnimationStudioFrame in 'Source\Plugin\Extension\MMDAnimationStudioFrame.pas' {FrameMMDAnimationStudio: TFrame},
  PmxCatalogFrame in 'Source\Plugin\Extension\PMX\Catalog\PmxCatalogFrame.pas' {FramePmxCatalog: TFrame},
  PmxCatalogStorage in 'Source\Plugin\Extension\PMX\Catalog\PmxCatalogStorage.pas',
  PmxCatalogGroupShortcut in 'Source\Plugin\Extension\PMX\Catalog\Group\PmxCatalogGroupShortcut.pas',
  PmxCatalogItem in 'Source\Plugin\Extension\PMX\Catalog\Storage\PmxCatalogItem.pas',
  PmxCatalogModelCodec in 'Source\Plugin\Extension\PMX\Catalog\Storage\PmxCatalogModelCodec.pas',
  PmxCatalogCharacterFilter in 'Source\Plugin\Extension\PMX\Catalog\Filter\PmxCatalogCharacterFilter.pas',
  PmxCatalogSelector in 'Source\Plugin\Extension\PMX\Catalog\Selector\PmxCatalogSelector.pas',
  PmxCatalogContextMenu in 'Source\Plugin\Extension\PMX\Catalog\Menu\PmxCatalogContextMenu.pas',
  PmxCatalogListView in 'Source\Plugin\Extension\PMX\Catalog\View\PmxCatalogListView.pas',
  PmxPoseCatalogStorage in 'Source\Plugin\Extension\PMX\Catalog\Pose\PmxPoseCatalogStorage.pas',
  PmxPoseCatalogDataValidation in 'Source\Plugin\Extension\PMX\Catalog\Pose\Storage\PmxPoseCatalogDataValidation.pas',
  PmxPoseCatalogItem in 'Source\Plugin\Extension\PMX\Catalog\Pose\Storage\PmxPoseCatalogItem.pas',
  PmxPoseCatalogIndexCodec in 'Source\Plugin\Extension\PMX\Catalog\Pose\Storage\PmxPoseCatalogIndexCodec.pas',
  PmxPoseCatalogItemCodec in 'Source\Plugin\Extension\PMX\Catalog\Pose\Storage\PmxPoseCatalogItemCodec.pas',
  PmxPoseCatalogListView in 'Source\Plugin\Extension\PMX\Catalog\Pose\View\PmxPoseCatalogListView.pas',
  PmxPoseCatalogToolbar in 'Source\Plugin\Extension\PMX\Catalog\Pose\Toolbar\PmxPoseCatalogToolbar.pas',
  PmxPoseCatalogToolbarIcons in 'Source\Plugin\Extension\PMX\Catalog\Pose\Toolbar\PmxPoseCatalogToolbarIcons.pas',
  PmxPoseCatalogContextMenu in 'Source\Plugin\Extension\PMX\Catalog\Pose\Menu\PmxPoseCatalogContextMenu.pas',
  PmxPoseCatalogGroups in 'Source\Plugin\Extension\PMX\Catalog\Pose\Group\PmxPoseCatalogGroups.pas',
  PmxPoseCatalogGroupBar in 'Source\Plugin\Extension\PMX\Catalog\Pose\Group\PmxPoseCatalogGroupBar.pas',
  PmxPoseCatalogEditor in 'Source\Plugin\Extension\PMX\Catalog\Pose\Editor\PmxPoseCatalogEditor.pas',
  PmxPoseCatalogDragAlias in 'Source\Plugin\Extension\PMX\Catalog\Pose\Drag\PmxPoseCatalogDragAlias.pas',
  PmxPoseCatalogDragController in 'Source\Plugin\Extension\PMX\Catalog\Pose\Drag\PmxPoseCatalogDragController.pas',
  PmxFaceCatalogItem in 'Source\Plugin\Extension\PMX\Catalog\Face\Storage\PmxFaceCatalogItem.pas',
  PmxFaceCatalogCodec in 'Source\Plugin\Extension\PMX\Catalog\Face\Storage\PmxFaceCatalogCodec.pas',
  PmxFaceCatalogStorage in 'Source\Plugin\Extension\PMX\Catalog\Face\PmxFaceCatalogStorage.pas',
  PmxFaceCatalogGroups in 'Source\Plugin\Extension\PMX\Catalog\Face\Group\PmxFaceCatalogGroups.pas',
  PmxFaceCatalogGroupBar in 'Source\Plugin\Extension\PMX\Catalog\Face\Group\PmxFaceCatalogGroupBar.pas',
  PmxFaceCatalogListView in 'Source\Plugin\Extension\PMX\Catalog\Face\View\PmxFaceCatalogListView.pas',
  PmxFaceCatalogSelection in 'Source\Plugin\Extension\PMX\Catalog\Face\View\PmxFaceCatalogSelection.pas',
  PmxFaceCatalogToolbarIcons in 'Source\Plugin\Extension\PMX\Catalog\Face\Toolbar\PmxFaceCatalogToolbarIcons.pas',
  PmxFaceCatalogToolbar in 'Source\Plugin\Extension\PMX\Catalog\Face\Toolbar\PmxFaceCatalogToolbar.pas',
  PmxFaceCatalogContextMenu in 'Source\Plugin\Extension\PMX\Catalog\Face\Menu\PmxFaceCatalogContextMenu.pas',
  PmxFaceCatalogEditor in 'Source\Plugin\Extension\PMX\Catalog\Face\Editor\PmxFaceCatalogEditor.pas',
  MmdPoseCatalogFrame in 'Source\Plugin\Extension\Pose\Catalog\MmdPoseCatalogFrame.pas',
  MmdFaceCatalogFrame in 'Source\Plugin\Extension\Face\Catalog\MmdFaceCatalogFrame.pas',
  MmdFaceObjectDragAlias in 'Source\Plugin\Extension\Face\Catalog\Drag\MmdFaceObjectDragAlias.pas',
  MmdFaceObjectDragController in 'Source\Plugin\Extension\Face\Catalog\Drag\MmdFaceObjectDragController.pas',
  MmdPoseObjectDragAlias in 'Source\Plugin\Extension\Pose\Catalog\Drag\MmdPoseObjectDragAlias.pas',
  MmdPoseObjectDragController in 'Source\Plugin\Extension\Pose\Catalog\Drag\MmdPoseObjectDragController.pas',
  MmdVpdCatalogItem in 'Source\Plugin\Extension\VPD\Catalog\MmdVpdCatalogItem.pas',
  MmdVpdCatalogCodec in 'Source\Plugin\Extension\VPD\Catalog\MmdVpdCatalogCodec.pas',
  MmdVpdCatalog in 'Source\Plugin\Extension\VPD\Catalog\MmdVpdCatalog.pas',
  MmdVpdPoseImporter in 'Source\Plugin\Extension\VPD\Import\MmdVpdPoseImporter.pas',
  MmdVpdReuseForm in 'Source\Plugin\Extension\VPD\Reuse\MmdVpdReuseForm.pas',
  DragAgent in '..\AviUtl2PluginLib\Lib\DragAgent\DragAgent.pas',
  PmxCatalogThumbnailCache in 'Source\Plugin\Extension\PMX\Catalog\Thumbnail\PmxCatalogThumbnailCache.pas',
  PmxCatalogThumbnailRenderer in 'Source\Plugin\Extension\PMX\Catalog\Thumbnail\PmxCatalogThumbnailRenderer.pas',
  MmdVpdDirectory in '..\AviUtl2PluginLib\MMD\VPD\IO\MmdVpdDirectory.pas',
  VpdPoseCodec in '..\AviUtl2PluginLib\MMD\VPD\IO\VpdPoseCodec.pas',
  HorizontalTrackBarRenderer in '..\AviUtl2PluginLib\Lib\HorizontalTrackBar\HorizontalTrackBarRenderer.pas',
  HorizontalTrackBarControl in '..\AviUtl2PluginLib\Lib\HorizontalTrackBar\HorizontalTrackBarControl.pas',
  VerticalScrollBarControl in '..\AviUtl2PluginLib\Lib\VerticalScrollBar\VerticalScrollBarControl.pas',
  MmdMorphSettingListRenderer in '..\AviUtl2PluginLib\MMD\Editor\Morph\List\MmdMorphSettingListRenderer.pas',
  MmdMorphSettingRows in '..\AviUtl2PluginLib\MMD\Editor\Morph\List\MmdMorphSettingRows.pas',
  MmdMorphSettingValue in '..\AviUtl2PluginLib\MMD\Editor\Morph\List\MmdMorphSettingValue.pas',
  MmdMorphSettingList in '..\AviUtl2PluginLib\MMD\Editor\Morph\List\MmdMorphSettingList.pas',
  MmdMorphPreviewPanel in '..\AviUtl2PluginLib\MMD\Editor\Morph\MmdMorphPreviewPanel.pas',
  MmdPoseEditorTheme in '..\AviUtl2PluginLib\MMD\Editor\MmdPoseEditorTheme.pas',
  MmdPoseEditorButtonTheme in '..\AviUtl2PluginLib\MMD\Editor\Theme\MmdPoseEditorButtonTheme.pas',
  MmdPoseEditorListTheme in '..\AviUtl2PluginLib\MMD\Editor\Theme\MmdPoseEditorListTheme.pas',
  MmdPoseEditorComboTheme in '..\AviUtl2PluginLib\MMD\Editor\Theme\MmdPoseEditorComboTheme.pas',
  MmdMorphSettingCodec in '..\AviUtl2PluginLib\MMD\Common\IO\MmdMorphSettingCodec.pas',
  MmdEyeBlinkSettingCodec in '..\AviUtl2PluginLib\MMD\Common\IO\MmdEyeBlinkSettingCodec.pas',
  MmdEyeBlinkSettingPanel in '..\AviUtl2PluginLib\MMD\Editor\Setting\Panel\MmdEyeBlinkSettingPanel.pas',
  MmdLipSyncSettingCodec in '..\AviUtl2PluginLib\MMD\Common\IO\MmdLipSyncSettingCodec.pas',
  MmdLipSyncSettingPanel in '..\AviUtl2PluginLib\MMD\Editor\Setting\Panel\MmdLipSyncSettingPanel.pas',
  MmdModelSettingEditorIcons in '..\AviUtl2PluginLib\MMD\Editor\Setting\Toolbar\MmdModelSettingEditorIcons.pas',
  MmdModelSettingToolbarRenderer in '..\AviUtl2PluginLib\MMD\Editor\Setting\Toolbar\MmdModelSettingToolbarRenderer.pas',
  MmdSettingPanelValue in '..\AviUtl2PluginLib\MMD\Editor\Setting\Panel\MmdSettingPanelValue.pas',
  MmdModelSettingEditor in '..\AviUtl2PluginLib\MMD\Editor\Setting\MmdModelSettingEditor.pas',
  MmdModelSettingDialogs in '..\AviUtl2PluginLib\MMD\Editor\Setting\MmdModelSettingDialogs.pas',
  MMDAnimationStudioForm in 'Source\Plugin\Extension\MMDAnimationStudioForm.pas' {FormMMDAnimationStudio};

{$R *.res}

function InitializePlugin(Version: DWORD): BOOL; cdecl;
begin
  try
    Result := True;
  except
    Result := False;
  end;
end;

procedure UninitializePlugin; cdecl;
begin
  try
    UnregisterMMDAnimationStudioWindow;
    ClearExplorerAviUtlBridge;
    EditHandle := nil;
  except
    ClearExplorerAviUtlBridge;
    EditHandle := nil;
  end;
end;

procedure RegisterPlugin(Host: PMMDHostAppTable); cdecl;
begin
  try
    SetAppFolderRoot('MMDAnimationStudio');
    EnsureMmdVpdDirectory;
    if Host = nil then
      Exit;

    if Assigned(Host^.CreateEditHandle) then
      EditHandle := Host^.CreateEditHandle;
    SetExplorerAviUtlBridge(AviUtl2Convert, AviUtl2GetSelectedAlias);
    Host^.SetPluginInformation(MMDPluginDisplayName);
    RegisterMMDAnimationStudioWindow(Host);
  except
    ClearExplorerAviUtlBridge;
    EditHandle := nil;
  end;
end;

procedure InitializeLogger(Logger: Pointer); cdecl;
begin
end;

exports
  InitializeLogger,
  InitializePlugin,
  UninitializePlugin,
  RegisterPlugin;

begin
end.
