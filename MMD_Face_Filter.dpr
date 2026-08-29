library MMD_Face_Filter;

// MMD表情レイヤーのAviUtl2 DLL境界。

{$ALIGN 8}

uses
  AviUtl2FilterTypes in 'Source\Lib\AviUtl2FilterTypes.pas',
  MmdFaceSharedMemory in '..\AviUtl2PluginLib\MMD\IPC\MmdFaceSharedMemory.pas',
  PmxModel in '..\AviUtl2PluginLib\MMD\Core\PmxModel.pas',
  PmxPoseTypes in '..\AviUtl2PluginLib\MMD\Core\PmxPoseTypes.pas',
  PmxPoseMath in '..\AviUtl2PluginLib\MMD\Core\PmxPoseMath.pas',
  PmxMorph in '..\AviUtl2PluginLib\MMD\Core\PmxMorph.pas',
  PmxBoneSolver in '..\AviUtl2PluginLib\MMD\Core\PmxBoneSolver.pas',
  PmxPose in '..\AviUtl2PluginLib\MMD\Core\PmxPose.pas',
  PmxPoseCodec in '..\AviUtl2PluginLib\MMD\IO\PmxPoseCodec.pas',
  PmxReader in '..\AviUtl2PluginLib\MMD\IO\PmxReader.pas',
  PmxBinaryStream in '..\AviUtl2PluginLib\MMD\IO\PmxBinaryStream.pas',
  PmxGeometryReader in '..\AviUtl2PluginLib\MMD\IO\PmxGeometryReader.pas',
  PmxMaterialReader in '..\AviUtl2PluginLib\MMD\IO\PmxMaterialReader.pas',
  PmxBoneReader in '..\AviUtl2PluginLib\MMD\IO\PmxBoneReader.pas',
  PmxMorphReader in '..\AviUtl2PluginLib\MMD\IO\PmxMorphReader.pas',
  MmdMorphSettingCodec in '..\AviUtl2PluginLib\MMD\Common\IO\MmdMorphSettingCodec.pas',
  MmdEyeBlinkSettingCodec in '..\AviUtl2PluginLib\MMD\Common\IO\MmdEyeBlinkSettingCodec.pas',
  MmdLipSyncSettingCodec in '..\AviUtl2PluginLib\MMD\Common\IO\MmdLipSyncSettingCodec.pas',
  MmdD3DScene in '..\AviUtl2PluginLib\MMD\Editor\D3D\MmdD3DScene.pas',
  MmdD3DSelection in '..\AviUtl2PluginLib\MMD\Editor\D3D\MmdD3DSelection.pas',
  MmdD3DInteraction in '..\AviUtl2PluginLib\MMD\Editor\D3D\MmdD3DInteraction.pas',
  MmdD3DShapes in '..\AviUtl2PluginLib\MMD\Editor\D3D\MmdD3DShapes.pas',
  MmdD3DBuffers in '..\AviUtl2PluginLib\MMD\Editor\D3D\MmdD3DBuffers.pas',
  MmdD3DCapture in '..\AviUtl2PluginLib\MMD\Editor\D3D\MmdD3DCapture.pas',
  MmdD3DOverlay in '..\AviUtl2PluginLib\MMD\Editor\D3D\MmdD3DOverlay.pas',
  MmdD3DShaders in '..\AviUtl2PluginLib\MMD\Editor\D3D\MmdD3DShaders.pas',
  MmdD3DTextures in '..\AviUtl2PluginLib\MMD\Editor\D3D\MmdD3DTextures.pas',
  MmdD3DDevice in '..\AviUtl2PluginLib\MMD\Editor\D3D\MmdD3DDevice.pas',
  MmdD3DDeform in '..\AviUtl2PluginLib\MMD\Editor\D3D\MmdD3DDeform.pas',
  MmdD3DRenderer in '..\AviUtl2PluginLib\MMD\Editor\D3D\MmdD3DRenderer.pas',
  MmdPoseSymmetry in '..\AviUtl2PluginLib\MMD\Editor\MmdPoseSymmetry.pas',
  MmdD3DViewportSurface in '..\AviUtl2PluginLib\MMD\Editor\D3D\MmdD3DViewportSurface.pas',
  MmdD3DLiveDragTest in '..\AviUtl2PluginLib\MMD\Editor\D3D\Temporary\MmdD3DLiveDragTest.pas',
  MmdD3DViewport in '..\AviUtl2PluginLib\MMD\Editor\D3D\MmdD3DViewport.pas',
  MmdPoseHistory in '..\AviUtl2PluginLib\MMD\Editor\MmdPoseHistory.pas',
  MmdPoseEditOperations in '..\AviUtl2PluginLib\MMD\Editor\MmdPoseEditOperations.pas',
  MmdMorphSettingListRenderer in '..\AviUtl2PluginLib\MMD\Editor\Morph\List\MmdMorphSettingListRenderer.pas',
  MmdMorphSettingRows in '..\AviUtl2PluginLib\MMD\Editor\Morph\List\MmdMorphSettingRows.pas',
  MmdMorphSettingValue in '..\AviUtl2PluginLib\MMD\Editor\Morph\List\MmdMorphSettingValue.pas',
  MmdMorphSettingList in '..\AviUtl2PluginLib\MMD\Editor\Morph\List\MmdMorphSettingList.pas',
  MmdMorphPreviewPanel in '..\AviUtl2PluginLib\MMD\Editor\Morph\MmdMorphPreviewPanel.pas',
  MmdPoseImageAutoFit in '..\AviUtl2PluginLib\MMD\Editor\MmdPoseImageAutoFit.pas',
  MmdPoseImageClipboard in '..\AviUtl2PluginLib\MMD\Editor\MmdPoseImageClipboard.pas',
  HorizontalTrackBarRenderer in '..\AviUtl2PluginLib\Lib\HorizontalTrackBar\HorizontalTrackBarRenderer.pas',
  HorizontalTrackBarControl in '..\AviUtl2PluginLib\Lib\HorizontalTrackBar\HorizontalTrackBarControl.pas',
  VerticalScrollBarControl in '..\AviUtl2PluginLib\Lib\VerticalScrollBar\VerticalScrollBarControl.pas',
  MmdPoseEditorTheme in '..\AviUtl2PluginLib\MMD\Editor\MmdPoseEditorTheme.pas',
  MmdPoseEditorButtonTheme in '..\AviUtl2PluginLib\MMD\Editor\Theme\MmdPoseEditorButtonTheme.pas',
  MmdPoseEditorListTheme in '..\AviUtl2PluginLib\MMD\Editor\Theme\MmdPoseEditorListTheme.pas',
  MmdPoseEditorComboTheme in '..\AviUtl2PluginLib\MMD\Editor\Theme\MmdPoseEditorComboTheme.pas',
  MmdPoseEditorLayout in '..\AviUtl2PluginLib\MMD\Editor\MmdPoseEditorLayout.pas',
  MmdPoseEditorToolbarIcons in '..\AviUtl2PluginLib\MMD\Editor\MmdPoseEditorToolbarIcons.pas',
  MmdPoseEditor in '..\AviUtl2PluginLib\MMD\Editor\MmdPoseEditor.pas',
  MmdEyeBlinkSettingPanel in '..\AviUtl2PluginLib\MMD\Editor\Setting\Panel\MmdEyeBlinkSettingPanel.pas',
  MmdLipSyncSettingPanel in '..\AviUtl2PluginLib\MMD\Editor\Setting\Panel\MmdLipSyncSettingPanel.pas',
  MmdModelSettingEditorIcons in '..\AviUtl2PluginLib\MMD\Editor\Setting\Toolbar\MmdModelSettingEditorIcons.pas',
  MmdModelSettingToolbarRenderer in '..\AviUtl2PluginLib\MMD\Editor\Setting\Toolbar\MmdModelSettingToolbarRenderer.pas',
  MmdSettingPanelValue in '..\AviUtl2PluginLib\MMD\Editor\Setting\Panel\MmdSettingPanelValue.pas',
  MmdModelSettingEditor in '..\AviUtl2PluginLib\MMD\Editor\Setting\MmdModelSettingEditor.pas',
  MmdModelSettingDialogs in '..\AviUtl2PluginLib\MMD\Editor\Setting\MmdModelSettingDialogs.pas',
  PluginFilterTable in 'Source\Lib\FilterTable\PluginFilterTable.pas',
  MMD_Face_FilterPlugin in 'Source\Plugin\Face\MMD_Face_FilterPlugin.pas';

function InitializePlugin(Version: Cardinal): Byte; cdecl;
begin
  Result := 1;
end;

procedure UninitializePlugin; cdecl;
begin
end;

function GetFilterPluginTable: PFILTER_PLUGIN_TABLE; cdecl;
begin
  Result := GetFaceFilterTable;
end;

exports
  InitializePlugin name 'InitializePlugin',
  UninitializePlugin name 'UninitializePlugin',
  GetFilterPluginTable name 'GetFilterPluginTable';

begin
end.
