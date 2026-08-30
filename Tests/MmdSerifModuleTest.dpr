program MmdSerifModuleTest;

{$APPTYPE CONSOLE}
{$WARN IMPLICIT_STRING_CAST OFF}
{$WARN IMPLICIT_STRING_CAST_LOSS OFF}

uses
  Winapi.Windows,
  System.SysUtils,
  AviUtl2FilterTypes in '..\Source\Lib\AviUtl2FilterTypes.pas',
  SharedMemoryBase in '..\..\AviUtl2PluginLib\Lib\SharedMemory\SharedMemoryBase.pas',
  KeyValueText in '..\..\AviUtl2PluginLib\Lib\KeyValue\KeyValueText.pas',
  SerifTalkSharedCodec in '..\..\AviUtl2PluginLib\Lib\SharedMemory\SerifTalkSharedCodec.pas',
  SerifSharedIndex in '..\..\AviUtl2PluginLib\Lib\SharedMemory\SerifSharedIndex.pas',
  SerifTalkSharedIndexPublisher in '..\..\AviUtl2PluginLib\Lib\SharedMemory\SerifTalkSharedIndexPublisher.pas',
  SerifTalkSharedMemory in '..\..\AviUtl2PluginLib\Lib\SharedMemory\SerifTalkSharedMemory.pas',
  MmdLipSyncSettingCodec in '..\..\AviUtl2PluginLib\MMD\Common\IO\MmdLipSyncSettingCodec.pas',
  MMD_Model_LipSyncProtocol in '..\Source\Plugin\Model\Input\LipSync\MMD_Model_LipSyncProtocol.pas',
  MMD_Model_LipSyncInput in '..\Source\Plugin\Model\Input\LipSync\MMD_Model_LipSyncInput.pas',
  PluginFilterSerifDrawReceiver in '..\..\Syncroh2\Plugin_Filter\SerifDraw\PluginFilterSerifDrawReceiver.pas',
  MmdSerifModuleTypes in '..\Source\Plugin\Serif\Module\MmdSerifModuleTypes.pas',
  MmdSerifModuleAdapter in '..\Source\Plugin\Serif\Module\MmdSerifModuleAdapter.pas',
  MMD_Serif_ModulePlugin in '..\Source\Plugin\Serif\Module\MMD_Serif_ModulePlugin.pas';

type
  TGetScriptModuleTable = function: PMMD_SCRIPT_MODULE_TABLE; cdecl;

const
  ModulePath = 'C:\ProgramData\aviutl2\Script\MMD\MMD_Serif_Module.mod2';

var
  IntParams: array[0..11] of Integer;
  DoubleParams: array[0..11] of Double;
  StringParams: array[0..11] of UTF8String;
  Param: TMMD_SCRIPT_MODULE_PARAM;
  ReferencedObject: OBJECT_HANDLE;
  RequestedLayer: Integer;

procedure Check(const Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

function GetParamNum: Integer; cdecl;
begin
  Result := 12;
end;

function GetParamInt(Index: Integer): Integer; cdecl;
begin
  Result := IntParams[Index];
end;

function GetParamDouble(Index: Integer): Double; cdecl;
begin
  Result := DoubleParams[Index];
end;

function GetParamString(Index: Integer): PAnsiChar; cdecl;
begin
  Result := PAnsiChar(StringParams[Index]);
end;

function ReturnReferencedObject(Layer: Integer;
  Offset: Double): OBJECT_HANDLE; cdecl;
begin
  RequestedLayer := Layer;
  Result := ReferencedObject;
end;

procedure PrepareParams(Layer, CurrentFrame: Integer;
  const SourceObject, SerifText, Character, Aiueo, Lab: string);
begin
  FillChar(IntParams, SizeOf(IntParams), 0);
  FillChar(DoubleParams, SizeOf(DoubleParams), 0);
  IntParams[0] := 30;
  IntParams[1] := 5;
  IntParams[2] := Layer;
  IntParams[11] := CurrentFrame;
  DoubleParams[8] := 2.0;
  StringParams[3] := UTF8String(SerifText);
  StringParams[4] := UTF8String(Character);
  StringParams[5] := UTF8String('normal');
  StringParams[6] := UTF8String('none');
  StringParams[7] := UTF8String(Aiueo);
  StringParams[8] := UTF8String('2.0');
  StringParams[9] := UTF8String(Lab);
  StringParams[10] := UTF8String(SourceObject);
  StringParams[11] := UTF8String(IntToStr(CurrentFrame));
end;

procedure InitializeParam;
begin
  Param := Default(TMMD_SCRIPT_MODULE_PARAM);
  Param.GetParamNum := GetParamNum;
  Param.GetParamInt := GetParamInt;
  Param.GetParamDouble := GetParamDouble;
  Param.GetParamString := GetParamString;
end;

procedure CheckPublished(Layer, CurrentFrame: Integer;
  const SerifText, Character: string);
const
  IndexNames: array[0..1] of string = (
    SERIF_INDEX_SHARED_NAME, SERIF_HISTORY_SHARED_NAME);
var
  Header: TSerifIndexHeader;
  I: Integer;
  IndexName: string;
  IndexMemory: TSharedMemoryStringList;
  IndexRecord: TSerifIndexRecord;
  Receiver: TSerifDrawReceiver;
  SharedText: string;
  Snapshots: TArray<TSerifDrawSnapshot>;
begin
  Check(TryReadSerifTalkText(Layer, SharedText),
    'ShareTalk was not published');
  Check(GetKeyValueInt(SharedText, 'current_frame') = CurrentFrame,
    'current frame mismatch');
  Check(GetKeyValue(SharedText, 'serif') = SerifText,
    'Serif text mismatch');
  Check(GetKeyValue(SharedText, 'chara') = Character,
    'character mismatch');
  Check(GetKeyValue(SharedText, 'source_object') = StringParams[10],
    'source object mismatch');
  for IndexName in IndexNames do
  begin
    IndexMemory := TSharedMemoryStringList.Create(IndexName,
      SERIF_INDEX_MAX_RECORDS + 1, SERIF_INDEX_MAX_TEXT_LENGTH);
    try
      Check(TryDecodeSerifIndexHeader(IndexMemory.Strings[0], Header) and
        Header.Ready and (Header.CurrentFrame = CurrentFrame),
        'Serif index header mismatch: ' + IndexName);
      IndexRecord := Default(TSerifIndexRecord);
      for I := 1 to Header.Count do
        if TryDecodeSerifIndexRecord(IndexMemory.Strings[I], IndexRecord) and
          (IndexRecord.Layer = Layer) then
          Break;
      Check((IndexRecord.Layer = Layer) and
        (IndexRecord.Serif = SerifText),
        'Serif index record mismatch: ' + IndexName);
    finally
      IndexMemory.Free;
    end;
  end;
  Receiver := TSerifDrawReceiver.Create;
  try
    Snapshots := Receiver.ReadActive(CurrentFrame);
    for I := 0 to High(Snapshots) do
      if (Snapshots[I].Layer = Layer) and
        (Snapshots[I].Serif = SerifText) then
        Exit;
  finally
    Receiver.Free;
  end;
  Check(False, 'Syncroh2 SerifDraw did not accept MMD Serif');
end;

procedure TestDirectModuleAndLipSync;
var
  ModelObject: TOBJECT_INFO;
  Sample: TMmdLipSyncSample;
  SerifObject: TOBJECT_INFO;
  Video: TFILTER_PROC_VIDEO;
begin
  // Scriptのobj.idとSDKのPOBJECT_INFO.IDは別体系なので、異なる値でも
  // 参照レイヤーの実在と現在フレームが一致すれば受理する。
  PrepareParams(11, 105, '1', 'direct-serif', 'DirectChara', '',
    '0,10000000,a');
  MmdSerifSetText(@Param);
  CheckPublished(11, 105, 'direct-serif', 'DirectChara');

  FillChar(SerifObject, SizeOf(SerifObject), 0);
  SerifObject.ID := 1234;
  FillChar(ModelObject, SizeOf(ModelObject), 0);
  ModelObject.FrameS := 100;
  ModelObject.Frame := 5;
  FillChar(Video, SizeOf(Video), 0);
  Video.Object_ := @ModelObject;
  Video.GetImageObject := ReturnReferencedObject;
  ReferencedObject := @SerifObject;
  RequestedLayer := -1;
  Check(ReadReferencedMmdLipSyncSample(@Video, 11, 99, 0.1, Sample),
    'model lip-sync did not accept referenced MMD Serif');
  Check(RequestedLayer = 10, 'SDK reference layer mismatch');
  Check((Sample.Kind = mlskPhoneme) and (Sample.Phoneme = mlpA),
    'LAB phoneme mismatch');
end;

procedure TestBuiltModule;
var
  Func: PMMD_SCRIPT_MODULE_FUNCTION;
  GetTable: TGetScriptModuleTable;
  Module: HMODULE;
  Table: PMMD_SCRIPT_MODULE_TABLE;
begin
  Module := LoadLibrary(ModulePath);
  Check(Module <> 0, 'built MMD Serif module could not be loaded');
  try
    GetTable := TGetScriptModuleTable(
      GetProcAddress(Module, 'GetScriptModuleTable'));
    Check(Assigned(GetTable), 'GetScriptModuleTable export is missing');
    Table := GetTable;
    Check((Table <> nil) and (Table^.Functions <> nil),
      'script module table is invalid');
    Func := Table^.Functions;
    Check((Func^.Name <> nil) and (string(Func^.Name) = 'set_text') and
      Assigned(Func^.Func), 'set_text function is missing');
    PrepareParams(12, 206, '5678', 'dll-serif', 'DllChara', 'i', '');
    Func^.Func(@Param);
    CheckPublished(12, 206, 'dll-serif', 'DllChara');
  finally
    FreeLibrary(Module);
  end;
end;

begin
  try
    InitializeParam;
    TestDirectModuleAndLipSync;
    TestBuiltModule;
    Writeln('MmdSerifModuleTest: PASS');
  except
    on E: Exception do
    begin
      Writeln('MmdSerifModuleTest: FAIL: ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
