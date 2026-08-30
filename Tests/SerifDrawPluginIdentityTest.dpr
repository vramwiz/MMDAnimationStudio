program SerifDrawPluginIdentityTest;

{$APPTYPE CONSOLE}

uses
  Winapi.Windows,
  System.SysUtils,
  AviUtl2FilterTypes in '..\..\AviUtl2PluginLib\Lib\AviUtl2Filter\AviUtl2FilterTypes.pas';

type
  TGetFilterPluginTable = function: PFILTER_PLUGIN_TABLE; cdecl;

procedure CheckPlugin(const FileName, ExpectedName,
  ExpectedGroup: string);
var
  GetTable: TGetFilterPluginTable;
  Module: HMODULE;
  Table: PFILTER_PLUGIN_TABLE;
begin
  Module := LoadLibrary(PChar(FileName));
  if Module = 0 then
    RaiseLastOSError;
  try
    GetTable := TGetFilterPluginTable(
      GetProcAddress(Module, 'GetFilterPluginTable'));
    if not Assigned(GetTable) then
      raise Exception.Create('GetFilterPluginTable is missing: ' + FileName);
    Table := GetTable;
    if (Table = nil) or (Table^.Name = nil) or (Table^.Label_ = nil) then
      raise Exception.Create('Plugin table is incomplete: ' + FileName);
    if string(Table^.Name) <> ExpectedName then
      raise Exception.CreateFmt('Name mismatch: expected="%s" actual="%s"',
        [ExpectedName, string(Table^.Name)]);
    if string(Table^.Label_) <> ExpectedGroup then
      raise Exception.CreateFmt('Group mismatch: expected="%s" actual="%s"',
        [ExpectedGroup, string(Table^.Label_)]);
  finally
    FreeLibrary(Module);
  end;
end;

begin
  try
    CheckPlugin(
      'C:\ProgramData\aviutl2\Plugin\Syncroh2\Syncroh2_Filter_SerifDraw.auf2',
      #$65B0#$65E7#$6717 + '2 ' + #$30BB#$30EA#$30D5#$8868#$793A,
      #$65B0#$65E7#$6717 + '2');
    CheckPlugin(
      'C:\ProgramData\aviutl2\Plugin\MMD\MMD_Serif_Draw_Filter.auf2',
      'MMD' + #$30BB#$30EA#$30D5#$8868#$793A,
      'MMD');
    Writeln('SerifDrawPluginIdentityTest: PASS');
  except
    on E: Exception do
    begin
      Writeln('SerifDrawPluginIdentityTest: FAIL: ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
