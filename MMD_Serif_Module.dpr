library MMD_Serif_Module;

uses
  Winapi.Windows,
  MmdSerifModuleTypes in 'Source\Plugin\Serif\Module\MmdSerifModuleTypes.pas',
  MmdSerifModuleAdapter in 'Source\Plugin\Serif\Module\MmdSerifModuleAdapter.pas',
  MMD_Serif_ModulePlugin in 'Source\Plugin\Serif\Module\MMD_Serif_ModulePlugin.pas',
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
