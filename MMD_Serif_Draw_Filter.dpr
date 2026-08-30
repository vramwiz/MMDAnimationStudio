library MMD_Serif_Draw_Filter;

{$ALIGN 8}

uses
  Winapi.Windows,
  TextRendererSkiaBootstrap in '..\AviUtl2PluginLib\Lib\TextRenderer\TextRendererSkiaBootstrap.pas',
  AviUtl2FilterTypes in '..\AviUtl2PluginLib\Lib\AviUtl2Filter\AviUtl2FilterTypes.pas',
  TextRendererTypes in '..\AviUtl2PluginLib\Lib\TextRenderer\TextRendererTypes.pas',
  TextRenderer in '..\AviUtl2PluginLib\Lib\TextRenderer\TextRenderer.pas',
  TextRendererSkiaRuntime in '..\AviUtl2PluginLib\Lib\TextRenderer\TextRendererSkiaRuntime.pas',
  TextRendererSkia in '..\AviUtl2PluginLib\Lib\TextRenderer\TextRendererSkia.pas',
  SharedMemoryBase in '..\AviUtl2PluginLib\Lib\SharedMemory\SharedMemoryBase.pas',
  SerifSharedIndex in '..\AviUtl2PluginLib\Lib\SharedMemory\SerifSharedIndex.pas',
  EmotionCategory in '..\AviUtl2PluginLib\Lib\Emotion\EmotionCategory.pas',
  ColorPickerColorMath in '..\AviUtl2PluginLib\Lib\ColorPicker\ColorPickerColorMath.pas',
  ColorPickerRGBEditFrame in '..\AviUtl2PluginLib\Lib\ColorPicker\ColorPickerRGBEditFrame.pas' {FrameColorPickerRGBEdit: TFrame},
  ColorPickerHueBar in '..\AviUtl2PluginLib\Lib\ColorPicker\ColorPickerHueBar.pas',
  ColorPickerSVArea in '..\AviUtl2PluginLib\Lib\ColorPicker\ColorPickerSVArea.pas',
  ColorPickerPick in '..\AviUtl2PluginLib\Lib\ColorPicker\ColorPickerPick.pas',
  ColorPickerDialogFrame in '..\AviUtl2PluginLib\Lib\ColorPicker\ColorPickerDialogFrame.pas' {FrameColorPickerDialog: TFrame},
  ColorPickerDialog in '..\AviUtl2PluginLib\Lib\ColorPicker\ColorPickerDialog.pas' {FormColorPickerDialog},
  HorizontalScrollBarControl in '..\AviUtl2PluginLib\Lib\HorizontalScrollBar\HorizontalScrollBarControl.pas',
  TransparencyTrackControl in '..\AviUtl2PluginLib\Lib\TransparencyTrack\TransparencyTrackControl.pas',
  FormattingToolbarButtons in '..\AviUtl2PluginLib\Lib\FormattingToolbar\FormattingToolbarButtons.pas',
  PluginFilterTable in '..\AviUtl2PluginLib\Lib\AviUtl2Filter\PluginFilterTable.pas',
  SerifDrawPluginProfile in '..\AviUtl2PluginLib\Serif\Plugin\Draw\SerifDrawPluginProfile.pas',
  MmdSerifDrawProfile in 'Source\Plugin\Serif\Draw\MmdSerifDrawProfile.pas',
  PluginFilterSerifDraw in '..\AviUtl2PluginLib\Serif\Plugin\Draw\PluginFilterSerifDraw.pas',
  PluginFilterSerifDrawDebugLog in '..\AviUtl2PluginLib\Serif\Plugin\Draw\PluginFilterSerifDrawDebugLog.pas',
  PluginFilterSerifDrawFrameCapture in '..\AviUtl2PluginLib\Serif\Plugin\Draw\PluginFilterSerifDrawFrameCapture.pas',
  PluginFilterSerifDrawGdiPlus in '..\AviUtl2PluginLib\Serif\Plugin\Draw\Display\PluginFilterSerifDrawGdiPlus.pas',
  PluginFilterSerifDrawReceiver in '..\AviUtl2PluginLib\Serif\Plugin\Draw\PluginFilterSerifDrawReceiver.pas',
  PluginFilterSerifDrawRoleNames in '..\AviUtl2PluginLib\Serif\Plugin\Draw\Display\PluginFilterSerifDrawRoleNames.pas',
  PluginFilterSerifDrawOverlap in '..\AviUtl2PluginLib\Serif\Plugin\Draw\Display\PluginFilterSerifDrawOverlap.pas',
  PluginFilterSerifDrawSettings in '..\AviUtl2PluginLib\Serif\Plugin\Draw\PluginFilterSerifDrawSettings.pas',
  PluginFilterSerifDrawSettingsTheme in '..\AviUtl2PluginLib\Serif\Plugin\Draw\Editor\PluginFilterSerifDrawSettingsTheme.pas',
  PluginFilterSerifDrawColorPicker in '..\AviUtl2PluginLib\Serif\Plugin\Draw\Editor\PluginFilterSerifDrawColorPicker.pas',
  PluginFilterSerifDrawPlacement in '..\AviUtl2PluginLib\Serif\Plugin\Draw\Display\PluginFilterSerifDrawPlacement.pas',
  PluginFilterSerifDrawPlacementPopup in '..\AviUtl2PluginLib\Serif\Plugin\Draw\Editor\PluginFilterSerifDrawPlacementPopup.pas',
  PluginFilterSerifDrawEditorModeControl in '..\AviUtl2PluginLib\Serif\Plugin\Draw\Editor\PluginFilterSerifDrawEditorModeControl.pas',
  PluginFilterSerifDrawAnimationItems in '..\AviUtl2PluginLib\Serif\Plugin\Draw\Animation\PluginFilterSerifDrawAnimationItems.pas',
  PluginFilterSerifDrawAnimationTypes in '..\AviUtl2PluginLib\Serif\Plugin\Draw\Animation\PluginFilterSerifDrawAnimationTypes.pas',
  PluginFilterSerifDrawAnimationEvaluator in '..\AviUtl2PluginLib\Serif\Plugin\Draw\Animation\PluginFilterSerifDrawAnimationEvaluator.pas',
  PluginFilterSerifDrawEmotionAnimation in '..\AviUtl2PluginLib\Serif\Plugin\Draw\Animation\PluginFilterSerifDrawEmotionAnimation.pas',
  PluginFilterSerifDrawAnimationController in '..\AviUtl2PluginLib\Serif\Plugin\Draw\Animation\PluginFilterSerifDrawAnimationController.pas',
  PluginFilterSerifDrawSyncHighlight in '..\AviUtl2PluginLib\Serif\Plugin\Draw\Animation\PluginFilterSerifDrawSyncHighlight.pas',
  PluginFilterSerifDrawSyncGeometry in '..\AviUtl2PluginLib\Serif\Plugin\Draw\Animation\PluginFilterSerifDrawSyncGeometry.pas',
  PluginFilterSerifDrawSyncBacking in '..\AviUtl2PluginLib\Serif\Plugin\Draw\Animation\PluginFilterSerifDrawSyncBacking.pas',
  PluginFilterSerifDrawFrameEditorBinding in '..\AviUtl2PluginLib\Serif\Plugin\Draw\Editor\PluginFilterSerifDrawFrameEditorBinding.pas',
  PluginFilterSerifDrawLegacyPalette in '..\AviUtl2PluginLib\Serif\Plugin\Draw\Editor\PluginFilterSerifDrawLegacyPalette.pas',
  PluginFilterSerifDrawFramePreview in '..\AviUtl2PluginLib\Serif\Plugin\Draw\Editor\PluginFilterSerifDrawFramePreview.pas',
  PluginFilterSerifDrawFramePreviewDrag in '..\AviUtl2PluginLib\Serif\Plugin\Draw\Editor\PluginFilterSerifDrawFramePreviewDrag.pas',
  PluginFilterSerifDrawFrameRaster in '..\AviUtl2PluginLib\Serif\Plugin\Draw\Display\PluginFilterSerifDrawFrameRaster.pas',
  PluginFilterSerifDrawTextPreviewDrag in '..\AviUtl2PluginLib\Serif\Plugin\Draw\Editor\PluginFilterSerifDrawTextPreviewDrag.pas',
  PluginFilterSerifDrawTextPreviewLayout in '..\AviUtl2PluginLib\Serif\Plugin\Draw\Editor\PluginFilterSerifDrawTextPreviewLayout.pas',
  PluginFilterSerifDrawTextPreviewHandles in '..\AviUtl2PluginLib\Serif\Plugin\Draw\Editor\PluginFilterSerifDrawTextPreviewHandles.pas',
  PluginFilterSerifDrawCommonFrameEditorFrame in '..\AviUtl2PluginLib\Serif\Plugin\Draw\Editor\PluginFilterSerifDrawCommonFrameEditorFrame.pas' {FrameSerifDrawCommonFrameEditor: TFrame},
  PluginFilterSerifDrawFrameEditorFrame in '..\AviUtl2PluginLib\Serif\Plugin\Draw\Editor\PluginFilterSerifDrawFrameEditorFrame.pas' {FrameSerifDrawFrameEditor: TFrame},
  PluginFilterSerifDrawTextEditorFrame in '..\AviUtl2PluginLib\Serif\Plugin\Draw\Editor\PluginFilterSerifDrawTextEditorFrame.pas' {FrameSerifDrawTextEditor: TFrame},
  PluginFilterSerifDrawSettingsForm in '..\AviUtl2PluginLib\Serif\Plugin\Draw\Editor\PluginFilterSerifDrawSettingsForm.pas' {FormSerifDrawSettings},
  PluginFilterSerifDrawSkia in '..\AviUtl2PluginLib\Serif\Plugin\Draw\Display\PluginFilterSerifDrawSkia.pas',
  PluginFilterSerifDrawSyncUnderline in '..\AviUtl2PluginLib\Serif\Plugin\Draw\Display\PluginFilterSerifDrawSyncUnderline.pas',
  PluginFilterSerifDrawSyncZoom in '..\AviUtl2PluginLib\Serif\Plugin\Draw\Display\PluginFilterSerifDrawSyncZoom.pas',
  PluginFilterSerifDrawSyncJump in '..\AviUtl2PluginLib\Serif\Plugin\Draw\Display\PluginFilterSerifDrawSyncJump.pas',
  PluginFilterSerifDrawSyncFront in '..\AviUtl2PluginLib\Serif\Plugin\Draw\Display\PluginFilterSerifDrawSyncFront.pas',
  PluginFilterSerifDrawSyncTextGlow in '..\AviUtl2PluginLib\Serif\Plugin\Draw\Display\PluginFilterSerifDrawSyncTextGlow.pas',
  PluginFilterSerifDrawTable in '..\AviUtl2PluginLib\Serif\Plugin\Draw\PluginFilterSerifDrawTable.pas';

function GetFilterPluginTable: PFILTER_PLUGIN_TABLE; cdecl;
begin
  RegisterMmdSerifDrawProfile;
  Result := GetTable;
end;

function InitializePlugin(Version: DWORD): Byte; cdecl;
begin
  RegisterMmdSerifDrawProfile;
  Result := Ord(InitializeSerifDrawPlugin);
end;

procedure UninitializePlugin; cdecl;
begin
  FinalizeSerifDrawPlugin;
end;

exports
  GetFilterPluginTable name 'GetFilterPluginTable',
  InitializePlugin name 'InitializePlugin',
  UninitializePlugin name 'UninitializePlugin';

begin
end.
