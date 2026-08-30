library MMD_Model_Filter;

// MMDモデル表示フィルターのAviUtl2 DLL境界。

{$ALIGN 8}

uses
  System.SysUtils,
  AviUtl2FilterTypes in 'Source\Lib\AviUtl2FilterTypes.pas',
  PmxModel in '..\AviUtl2PluginLib\MMD\Core\PmxModel.pas',
  PmxPoseTypes in '..\AviUtl2PluginLib\MMD\Core\PmxPoseTypes.pas',
  PmxPoseMath in '..\AviUtl2PluginLib\MMD\Core\PmxPoseMath.pas',
  PmxMorph in '..\AviUtl2PluginLib\MMD\Core\PmxMorph.pas',
  PmxBoneSolver in '..\AviUtl2PluginLib\MMD\Core\PmxBoneSolver.pas',
  PmxPose in '..\AviUtl2PluginLib\MMD\Core\PmxPose.pas',
  PmxPoseCodec in '..\AviUtl2PluginLib\MMD\IO\PmxPoseCodec.pas',
  MmdMorphSettingCodec in '..\AviUtl2PluginLib\MMD\Common\IO\MmdMorphSettingCodec.pas',
  MmdAiDiagnosticState in '..\AviUtl2PluginLib\MMD\AI\MmdAiDiagnosticState.pas',
  MmdAiDiagnosticProtocol in '..\AviUtl2PluginLib\MMD\AI\MmdAiDiagnosticProtocol.pas',
  MmdAiSchema in '..\AviUtl2PluginLib\MMD\AI\MmdAiSchema.pas',
  MmdAiProvider in '..\AviUtl2PluginLib\MMD\AI\MmdAiProvider.pas',
  MmdPoseSharedMemory in '..\AviUtl2PluginLib\MMD\IPC\MmdPoseSharedMemory.pas',
  MmdFaceSharedMemory in '..\AviUtl2PluginLib\MMD\IPC\MmdFaceSharedMemory.pas',
  MmdPoseSharedTrace in '..\AviUtl2PluginLib\MMD\IPC\MmdPoseSharedTrace.pas',
  SharedMemoryBase in '..\AviUtl2PluginLib\Lib\SharedMemory\SharedMemoryBase.pas',
  SerifTalkSharedMemory in '..\AviUtl2PluginLib\Lib\SharedMemory\SerifTalkSharedMemory.pas',
  KeyValueText in '..\AviUtl2PluginLib\Lib\KeyValue\KeyValueText.pas',
  PmxReader in '..\AviUtl2PluginLib\MMD\IO\PmxReader.pas',
  PmxBinaryStream in '..\AviUtl2PluginLib\MMD\IO\PmxBinaryStream.pas',
  PmxGeometryReader in '..\AviUtl2PluginLib\MMD\IO\PmxGeometryReader.pas',
  PmxMaterialReader in '..\AviUtl2PluginLib\MMD\IO\PmxMaterialReader.pas',
  PmxBoneReader in '..\AviUtl2PluginLib\MMD\IO\PmxBoneReader.pas',
  PmxMorphReader in '..\AviUtl2PluginLib\MMD\IO\PmxMorphReader.pas',
  PluginFilterTable in 'Source\Lib\FilterTable\PluginFilterTable.pas',
  MMD_Model_FilterPlugin in 'Source\Plugin\Model\MMD_Model_FilterPlugin.pas',
  MMD_Model_DebugLog in 'Source\Plugin\Model\Diagnostics\MMD_Model_DebugLog.pas',
  MMD_Model_EyeBlink in 'Source\Plugin\Model\Runtime\EyeBlink\MMD_Model_EyeBlink.pas',
  MMD_Model_Context in 'Source\Plugin\Model\Context\MMD_Model_Context.pas',
  MMD_Model_LipSyncContext in 'Source\Plugin\Model\Context\LipSync\MMD_Model_LipSyncContext.pas',
  MMD_Model_PoseInput in 'Source\Plugin\Model\Input\Pose\MMD_Model_PoseInput.pas',
  MMD_Model_FaceInput in 'Source\Plugin\Model\Input\Face\MMD_Model_FaceInput.pas',
  MMD_Model_LipSyncProtocol in 'Source\Plugin\Model\Input\LipSync\MMD_Model_LipSyncProtocol.pas',
  MMD_Model_LipSyncInput in 'Source\Plugin\Model\Input\LipSync\MMD_Model_LipSyncInput.pas',
  MMD_Model_Renderer in 'Source\Plugin\Model\Render\MMD_Model_Renderer.pas',
  MMD_Model_MaterialSelection in 'Source\Plugin\Model\Render\MMD_Model_MaterialSelection.pas',
  MMD_Model_DiagnosticRenderer in 'Source\Plugin\Model\Render\MMD_Model_DiagnosticRenderer.pas',
  MMD_Model_SettingsButton in 'Source\Plugin\Model\Editor\MMD_Model_SettingsButton.pas',
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
  MmdModelSettingEditorIcons in '..\AviUtl2PluginLib\MMD\Editor\Setting\Toolbar\MmdModelSettingEditorIcons.pas',
  MmdModelSettingToolbarRenderer in '..\AviUtl2PluginLib\MMD\Editor\Setting\Toolbar\MmdModelSettingToolbarRenderer.pas',
  MmdSettingPanelValue in '..\AviUtl2PluginLib\MMD\Editor\Setting\Panel\MmdSettingPanelValue.pas',
  MmdEyeBlinkSettingCodec in '..\AviUtl2PluginLib\MMD\Common\IO\MmdEyeBlinkSettingCodec.pas',
  MmdEyeBlinkSettingPanel in '..\AviUtl2PluginLib\MMD\Editor\Setting\Panel\MmdEyeBlinkSettingPanel.pas',
  MmdLipSyncSettingCodec in '..\AviUtl2PluginLib\MMD\Common\IO\MmdLipSyncSettingCodec.pas',
  MmdLipSyncSettingPanel in '..\AviUtl2PluginLib\MMD\Editor\Setting\Panel\MmdLipSyncSettingPanel.pas',
  MmdModelSettingEditor in '..\AviUtl2PluginLib\MMD\Editor\Setting\MmdModelSettingEditor.pas',
  MmdModelSettingDialogs in '..\AviUtl2PluginLib\MMD\Editor\Setting\MmdModelSettingDialogs.pas',
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
  MmdPoseEditor in '..\AviUtl2PluginLib\MMD\Editor\MmdPoseEditor.pas';

function InitializePlugin(Version: Cardinal): Byte; cdecl;
begin
  TraceMmdPoseShared('MODEL', 'plugin_initialize', -1, -1, 0, 0, 0, 0,
    'version=' + UIntToStr(Version));
  Result := 1;
end;

procedure UninitializePlugin; cdecl;
begin
  TraceMmdPoseShared('MODEL', 'plugin_uninitialize', -1, -1, 0, 0, 0, 0);
end;

function GetFilterPluginTable: PFILTER_PLUGIN_TABLE; cdecl;
begin
  Result := GetModelFilterTable;
end;

exports
  InitializePlugin name 'InitializePlugin',
  UninitializePlugin name 'UninitializePlugin',
  GetFilterPluginTable name 'GetFilterPluginTable',
  MmdAiProviderGetVersion name 'MmdAiProviderGetVersion',
  MmdAiProviderInvoke name 'MmdAiProviderInvoke';

begin
end.
