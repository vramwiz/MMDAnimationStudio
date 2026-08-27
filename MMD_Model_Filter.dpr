library MMD_Model_Filter;

// MMDモデル表示フィルターのAviUtl2 DLL境界。

{$ALIGN 8}

uses
  AviUtl2FilterTypes in 'Source\Lib\AviUtl2FilterTypes.pas',
  PmxModel in '..\AviUtl2PluginLib\MMD\Core\PmxModel.pas',
  PmxPoseTypes in '..\AviUtl2PluginLib\MMD\Core\PmxPoseTypes.pas',
  PmxPoseMath in '..\AviUtl2PluginLib\MMD\Core\PmxPoseMath.pas',
  PmxMorph in '..\AviUtl2PluginLib\MMD\Core\PmxMorph.pas',
  PmxBoneSolver in '..\AviUtl2PluginLib\MMD\Core\PmxBoneSolver.pas',
  PmxPose in '..\AviUtl2PluginLib\MMD\Core\PmxPose.pas',
  PmxPoseCodec in '..\AviUtl2PluginLib\MMD\IO\PmxPoseCodec.pas',
  MmdAiDiagnosticState in '..\AviUtl2PluginLib\MMD\AI\MmdAiDiagnosticState.pas',
  MmdAiDiagnosticProtocol in '..\AviUtl2PluginLib\MMD\AI\MmdAiDiagnosticProtocol.pas',
  MmdAiSchema in '..\AviUtl2PluginLib\MMD\AI\MmdAiSchema.pas',
  MmdAiProvider in '..\AviUtl2PluginLib\MMD\AI\MmdAiProvider.pas',
  MmdPoseSharedMemory in '..\AviUtl2PluginLib\MMD\IPC\MmdPoseSharedMemory.pas',
  PmxReader in '..\AviUtl2PluginLib\MMD\IO\PmxReader.pas',
  PmxBinaryStream in '..\AviUtl2PluginLib\MMD\IO\PmxBinaryStream.pas',
  PmxGeometryReader in '..\AviUtl2PluginLib\MMD\IO\PmxGeometryReader.pas',
  PmxMaterialReader in '..\AviUtl2PluginLib\MMD\IO\PmxMaterialReader.pas',
  PmxBoneReader in '..\AviUtl2PluginLib\MMD\IO\PmxBoneReader.pas',
  PmxMorphReader in '..\AviUtl2PluginLib\MMD\IO\PmxMorphReader.pas',
  PluginFilterTable in 'Source\Lib\FilterTable\PluginFilterTable.pas',
  MMD_Model_FilterPlugin in 'Source\Plugin\Model\MMD_Model_FilterPlugin.pas',
  MMD_Model_Context in 'Source\Plugin\Model\Context\MMD_Model_Context.pas',
  MMD_Model_PoseInput in 'Source\Plugin\Model\Input\MMD_Model_PoseInput.pas',
  MMD_Model_Renderer in 'Source\Plugin\Model\Render\MMD_Model_Renderer.pas',
  MMD_Model_MaterialSelection in 'Source\Plugin\Model\Render\MMD_Model_MaterialSelection.pas',
  MMD_Model_DiagnosticRenderer in 'Source\Plugin\Model\Render\MMD_Model_DiagnosticRenderer.pas',
  MMD_Model_StandardPoseButton in 'Source\Plugin\Model\Editor\MMD_Model_StandardPoseButton.pas',
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
  MmdMorphPreviewPanel in '..\AviUtl2PluginLib\MMD\Editor\MmdMorphPreviewPanel.pas',
  MmdPoseImageAutoFit in '..\AviUtl2PluginLib\MMD\Editor\MmdPoseImageAutoFit.pas',
  MmdPoseImageClipboard in '..\AviUtl2PluginLib\MMD\Editor\MmdPoseImageClipboard.pas',
  MmdPoseEditorLayout in '..\AviUtl2PluginLib\MMD\Editor\MmdPoseEditorLayout.pas',
  MmdPoseEditor in '..\AviUtl2PluginLib\MMD\Editor\MmdPoseEditor.pas';

function InitializePlugin(Version: Cardinal): Byte; cdecl;
begin
  Result := 1;
end;

procedure UninitializePlugin; cdecl;
begin
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
