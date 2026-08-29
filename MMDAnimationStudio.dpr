library MMDAnimationStudio;

uses
  Winapi.Windows,
  System.SysUtils,
  AppFolderUtils in '..\AviUtl2PluginLib\Lib\AppFolderUtils\AppFolderUtils.pas',
  ShortcutAction in '..\AviUtl2PluginLib\Lib\ShortcutAction\ShortcutAction.pas',
  ConfirmDialogForm in '..\AviUtl2PluginLib\Lib\ConfirmDialog\ConfirmDialogForm.pas' {FormConfirmDialog},
  MMDAnimationStudioExtension in 'Source\Plugin\Extension\MMDAnimationStudioExtension.pas',
  MMDAnimationStudioToolbarIcons in 'Source\Plugin\Extension\MMDAnimationStudioToolbarIcons.pas',
  MMDAnimationStudioFrame in 'Source\Plugin\Extension\MMDAnimationStudioFrame.pas' {FrameMMDAnimationStudio: TFrame},
  PmxCatalogFrame in 'Source\Plugin\Extension\PMX\Catalog\PmxCatalogFrame.pas' {FramePmxCatalog: TFrame},
  PmxCatalogStorage in 'Source\Plugin\Extension\PMX\Catalog\PmxCatalogStorage.pas',
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
  MmdPoseCatalogFrame in 'Source\Plugin\Extension\Pose\Catalog\MmdPoseCatalogFrame.pas',
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
  MmdMorphSettingListRenderer in '..\AviUtl2PluginLib\MMD\Editor\Morph\MmdMorphSettingListRenderer.pas',
  MmdMorphSettingRows in '..\AviUtl2PluginLib\MMD\Editor\Morph\MmdMorphSettingRows.pas',
  MmdMorphSettingValue in '..\AviUtl2PluginLib\MMD\Editor\Morph\MmdMorphSettingValue.pas',
  MmdMorphSettingList in '..\AviUtl2PluginLib\MMD\Editor\Morph\MmdMorphSettingList.pas',
  MmdMorphPreviewPanel in '..\AviUtl2PluginLib\MMD\Editor\Morph\MmdMorphPreviewPanel.pas',
  MmdPoseEditorTheme in '..\AviUtl2PluginLib\MMD\Editor\MmdPoseEditorTheme.pas',
  MmdPoseEditorButtonTheme in '..\AviUtl2PluginLib\MMD\Editor\Theme\MmdPoseEditorButtonTheme.pas',
  MmdPoseEditorListTheme in '..\AviUtl2PluginLib\MMD\Editor\Theme\MmdPoseEditorListTheme.pas',
  MmdPoseEditorComboTheme in '..\AviUtl2PluginLib\MMD\Editor\Theme\MmdPoseEditorComboTheme.pas',
  MmdMorphSettingCodec in '..\AviUtl2PluginLib\MMD\Common\IO\MmdMorphSettingCodec.pas',
  MmdEyeBlinkSettingCodec in '..\AviUtl2PluginLib\MMD\Common\IO\MmdEyeBlinkSettingCodec.pas',
  MmdEyeBlinkSettingPanel in '..\AviUtl2PluginLib\MMD\Editor\Setting\MmdEyeBlinkSettingPanel.pas',
  MmdLipSyncSettingCodec in '..\AviUtl2PluginLib\MMD\Common\IO\MmdLipSyncSettingCodec.pas',
  MmdLipSyncSettingPanel in '..\AviUtl2PluginLib\MMD\Editor\Setting\MmdLipSyncSettingPanel.pas',
  MmdModelSettingEditorIcons in '..\AviUtl2PluginLib\MMD\Editor\Setting\MmdModelSettingEditorIcons.pas',
  MmdSettingPanelValue in '..\AviUtl2PluginLib\MMD\Editor\Setting\MmdSettingPanelValue.pas',
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
  except
    { DLL境界から例外を漏らさない。 }
  end;
end;

procedure RegisterPlugin(Host: PMMDHostAppTable); cdecl;
begin
  try
    SetAppFolderRoot('MMDAnimationStudio');
    EnsureMmdVpdDirectory;
    if Host = nil then
      Exit;

    Host^.SetPluginInformation(MMDPluginDisplayName);
    RegisterMMDAnimationStudioWindow(Host);
  except
    { DLL境界から例外を漏らさない。 }
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
