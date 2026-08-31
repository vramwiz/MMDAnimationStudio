library MMD_Serif_Module;

uses
  Winapi.Windows,
  AviUtl2FilterTypes in 'Source\Lib\AviUtl2FilterTypes.pas',
  MmdSerifModuleTypes in 'Source\Plugin\Serif\Module\MmdSerifModuleTypes.pas',
  MmdSerifModuleAdapter in 'Source\Plugin\Serif\Module\MmdSerifModuleAdapter.pas',
  MMD_Animation_ModulePlugin in 'Source\Plugin\Serif\Module\MMD_Animation_ModulePlugin.pas',
  MMD_Serif_ModulePlugin in 'Source\Plugin\Serif\Module\MMD_Serif_ModulePlugin.pas',
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
  MmdPoseSharedMemory in
    '..\AviUtl2PluginLib\MMD\IPC\MmdPoseSharedMemory.pas',
  MmdMotionSharedCodec in
    '..\AviUtl2PluginLib\MMD\IPC\Motion\MmdMotionSharedCodec.pas',
  MmdMotionSharedMemory in
    '..\AviUtl2PluginLib\MMD\IPC\Motion\MmdMotionSharedMemory.pas',
  MMD_Motion_Runtime in 'Source\Plugin\Motion\MMD_Motion_Runtime.pas',
  SerifModulePublisher in '..\AviUtl2PluginLib\Serif\Plugin\Module\SerifModulePublisher.pas',
  SharedMemoryBase in '..\AviUtl2PluginLib\Lib\SharedMemory\SharedMemoryBase.pas',
  KeyValueText in '..\AviUtl2PluginLib\Lib\KeyValue\KeyValueText.pas',
  SerifTalkSharedCodec in '..\AviUtl2PluginLib\Lib\SharedMemory\SerifTalkSharedCodec.pas',
  SerifSpeechSync in '..\AviUtl2PluginLib\Serif\Plugin\Module\SerifSpeechSync.pas',
  SerifSharedIndex in '..\AviUtl2PluginLib\Lib\SharedMemory\SerifSharedIndex.pas',
  SerifTalkSharedIndexPublisher in '..\AviUtl2PluginLib\Lib\SharedMemory\SerifTalkSharedIndexPublisher.pas',
  SerifTalkSharedMemory in '..\AviUtl2PluginLib\Lib\SharedMemory\SerifTalkSharedMemory.pas';

{$R *.res}

function InitializePlugin(Version: DWORD): BOOL; cdecl;
begin
  Result := True;
end;

procedure UninitializePlugin; cdecl;
begin
end;

function GetScriptModuleTable: PMMD_SCRIPT_MODULE_TABLE; cdecl;
begin
  Result := GetMmdSerifScriptModuleTable;
end;

exports
  InitializePlugin name 'InitializePlugin',
  UninitializePlugin name 'UninitializePlugin',
  GetScriptModuleTable name 'GetScriptModuleTable';

begin
end.
