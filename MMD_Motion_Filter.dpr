library MMD_Motion_Filter;

// MMDモーションレイヤーのAviUtl2 DLL境界。

{$ALIGN 8}

uses
  AviUtl2FilterTypes in 'Source\Lib\AviUtl2FilterTypes.pas',
  PluginFilterTable in 'Source\Lib\FilterTable\PluginFilterTable.pas',
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
