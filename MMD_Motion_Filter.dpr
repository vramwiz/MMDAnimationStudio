library MMD_Motion_Filter;

// MMDモーションレイヤーのAviUtl2 DLL境界。

{$ALIGN 8}

uses
  AviUtl2FilterTypes in 'Source\Lib\AviUtl2FilterTypes.pas',
  PluginFilterTable in 'Source\Lib\FilterTable\PluginFilterTable.pas',
  PmxModel in '..\AviUtl2PluginLib\MMD\Core\PmxModel.pas',
  PmxPoseTypes in '..\AviUtl2PluginLib\MMD\Core\PmxPoseTypes.pas',
  PmxPoseMath in '..\AviUtl2PluginLib\MMD\Core\PmxPoseMath.pas',
  PmxBoneSolver in '..\AviUtl2PluginLib\MMD\Core\PmxBoneSolver.pas',
  PmxMorph in '..\AviUtl2PluginLib\MMD\Core\PmxMorph.pas',
  PmxPose in '..\AviUtl2PluginLib\MMD\Core\PmxPose.pas',
  MmdMorphSettingCodec in
    '..\AviUtl2PluginLib\MMD\Common\IO\MmdMorphSettingCodec.pas',
  MmdMotionDocument in
    '..\AviUtl2PluginLib\MMD\Common\Motion\MmdMotionDocument.pas',
  MmdMotionDocumentCodec in
    '..\AviUtl2PluginLib\MMD\Common\Motion\MmdMotionDocumentCodec.pas',
  MmdMotionDocumentEvaluator in
    '..\AviUtl2PluginLib\MMD\Common\Motion\MmdMotionDocumentEvaluator.pas',
  MmdMotionSharedCodec in
    '..\AviUtl2PluginLib\MMD\IPC\Motion\MmdMotionSharedCodec.pas',
  MmdMotionSharedMemory in
    '..\AviUtl2PluginLib\MMD\IPC\Motion\MmdMotionSharedMemory.pas',
  MMD_Motion_Runtime in 'Source\Plugin\Motion\MMD_Motion_Runtime.pas',
  MMD_Motion_FilterPlugin in 'Source\Plugin\Motion\MMD_Motion_FilterPlugin.pas';

function InitializePlugin(Version: Cardinal): Byte; cdecl;
begin
  Result := 1;
end;

procedure UninitializePlugin; cdecl;
begin
end;

function GetFilterPluginTable: PFILTER_PLUGIN_TABLE; cdecl;
begin
  Result := GetMotionFilterTable;
end;

exports
  InitializePlugin name 'InitializePlugin',
  UninitializePlugin name 'UninitializePlugin',
  GetFilterPluginTable name 'GetFilterPluginTable';

begin
end.
