library MMDAnimationStudio;

uses
  Winapi.Windows,
  System.SysUtils,
  AppFolderUtils in '..\AviUtl2PluginLib\Lib\AppFolderUtils\AppFolderUtils.pas',
  MMDAnimationStudioExtension in 'Source\Plugin\Extension\MMDAnimationStudioExtension.pas',
  MMDAnimationStudioToolbarIcons in 'Source\Plugin\Extension\MMDAnimationStudioToolbarIcons.pas',
  MMDAnimationStudioFrame in 'Source\Plugin\Extension\MMDAnimationStudioFrame.pas' {FrameMMDAnimationStudio: TFrame},
  PmxCatalogFrame in 'Source\Plugin\Extension\PMX\Catalog\PmxCatalogFrame.pas' {FramePmxCatalog: TFrame},
  PmxCatalogStorage in 'Source\Plugin\Extension\PMX\Catalog\PmxCatalogStorage.pas',
  PmxCatalogListView in 'Source\Plugin\Extension\PMX\Catalog\View\PmxCatalogListView.pas',
  PmxPoseCatalogStorage in 'Source\Plugin\Extension\PMX\Catalog\Pose\PmxPoseCatalogStorage.pas',
  PmxPoseCatalogDataValidation in 'Source\Plugin\Extension\PMX\Catalog\Pose\Storage\PmxPoseCatalogDataValidation.pas',
  PmxPoseCatalogListView in 'Source\Plugin\Extension\PMX\Catalog\Pose\View\PmxPoseCatalogListView.pas',
  PmxPoseCatalogEditor in 'Source\Plugin\Extension\PMX\Catalog\Pose\Editor\PmxPoseCatalogEditor.pas',
  PmxPoseCatalogDragAlias in 'Source\Plugin\Extension\PMX\Catalog\Pose\Drag\PmxPoseCatalogDragAlias.pas',
  DragAgent in '..\AviUtl2PluginLib\Lib\DragAgent\DragAgent.pas',
  PmxCatalogThumbnailCache in 'Source\Plugin\Extension\PMX\Catalog\Thumbnail\PmxCatalogThumbnailCache.pas',
  PmxCatalogThumbnailRenderer in 'Source\Plugin\Extension\PMX\Catalog\Thumbnail\PmxCatalogThumbnailRenderer.pas',
  MmdVpdDirectory in '..\AviUtl2PluginLib\MMD\VPD\IO\MmdVpdDirectory.pas',
  HorizontalTrackBarRenderer in '..\AviUtl2PluginLib\Lib\HorizontalTrackBar\HorizontalTrackBarRenderer.pas',
  HorizontalTrackBarControl in '..\AviUtl2PluginLib\Lib\HorizontalTrackBar\HorizontalTrackBarControl.pas',
  VerticalScrollBarControl in '..\AviUtl2PluginLib\Lib\VerticalScrollBar\VerticalScrollBarControl.pas',
  MmdMorphSettingListRenderer in '..\AviUtl2PluginLib\MMD\Editor\Morph\MmdMorphSettingListRenderer.pas',
  MmdMorphSettingRows in '..\AviUtl2PluginLib\MMD\Editor\Morph\MmdMorphSettingRows.pas',
  MmdMorphSettingValue in '..\AviUtl2PluginLib\MMD\Editor\Morph\MmdMorphSettingValue.pas',
  MmdMorphSettingList in '..\AviUtl2PluginLib\MMD\Editor\Morph\MmdMorphSettingList.pas',
  MmdMorphPreviewPanel in '..\AviUtl2PluginLib\MMD\Editor\Morph\MmdMorphPreviewPanel.pas',
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
