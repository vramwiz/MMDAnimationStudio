program MmdSerifModuleTest;

{$APPTYPE CONSOLE}
{$WARN IMPLICIT_STRING_CAST OFF}
{$WARN IMPLICIT_STRING_CAST_LOSS OFF}

uses
  Winapi.Windows,
  System.SysUtils,
  AviUtl2FilterTypes in '..\..\AviUtl2PluginLib\Lib\AviUtl2Filter\AviUtl2FilterTypes.pas',
  SharedMemoryBase in '..\..\AviUtl2PluginLib\Lib\SharedMemory\SharedMemoryBase.pas',
  KeyValueText in '..\..\AviUtl2PluginLib\Lib\KeyValue\KeyValueText.pas',
  SerifTalkSharedCodec in '..\..\AviUtl2PluginLib\Lib\SharedMemory\SerifTalkSharedCodec.pas',
  SerifSpeechSync in '..\..\AviUtl2PluginLib\Serif\Plugin\Module\SerifSpeechSync.pas',
  SerifSharedIndex in '..\..\AviUtl2PluginLib\Lib\SharedMemory\SerifSharedIndex.pas',
  SerifTalkSharedIndexPublisher in '..\..\AviUtl2PluginLib\Lib\SharedMemory\SerifTalkSharedIndexPublisher.pas',
  SerifTalkSharedMemory in '..\..\AviUtl2PluginLib\Lib\SharedMemory\SerifTalkSharedMemory.pas',
  SerifModulePublisher in '..\..\AviUtl2PluginLib\Serif\Plugin\Module\SerifModulePublisher.pas',
  MmdLipSyncSettingCodec in '..\..\AviUtl2PluginLib\MMD\Common\IO\MmdLipSyncSettingCodec.pas',
  MMD_Model_LipSyncProtocol in '..\Source\Plugin\Model\Input\LipSync\MMD_Model_LipSyncProtocol.pas',
  MMD_Model_LipSyncInput in '..\Source\Plugin\Model\Input\LipSync\MMD_Model_LipSyncInput.pas',
  PluginFilterSerifDrawReceiver in '..\..\AviUtl2PluginLib\Serif\Plugin\Draw\PluginFilterSerifDrawReceiver.pas',
  MmdSerifModuleTypes in '..\Source\Plugin\Serif\Module\MmdSerifModuleTypes.pas',
  MmdSerifModuleAdapter in '..\Source\Plugin\Serif\Module\MmdSerifModuleAdapter.pas',
  PmxModel in '..\..\AviUtl2PluginLib\MMD\Core\PmxModel.pas',
  PmxPoseTypes in '..\..\AviUtl2PluginLib\MMD\Core\PmxPoseTypes.pas',
  PmxPoseMath in '..\..\AviUtl2PluginLib\MMD\Core\PmxPoseMath.pas',
  PmxBoneSolver in '..\..\AviUtl2PluginLib\MMD\Core\PmxBoneSolver.pas',
  PmxMorph in '..\..\AviUtl2PluginLib\MMD\Core\PmxMorph.pas',
  PmxPose in '..\..\AviUtl2PluginLib\MMD\Core\PmxPose.pas',
  MmdMorphSettingCodec in
    '..\..\AviUtl2PluginLib\MMD\Common\IO\MmdMorphSettingCodec.pas',
  MmdMotionDocument in
    '..\..\AviUtl2PluginLib\MMD\Common\Motion\MmdMotionDocument.pas',
  MmdMotionDocumentCodec in
    '..\..\AviUtl2PluginLib\MMD\Common\Motion\MmdMotionDocumentCodec.pas',
  MmdMotionDocumentEvaluator in
    '..\..\AviUtl2PluginLib\MMD\Common\Motion\MmdMotionDocumentEvaluator.pas',
  MmdPoseSharedMemory in
    '..\..\AviUtl2PluginLib\MMD\IPC\MmdPoseSharedMemory.pas',
  MmdMotionSharedCodec in
    '..\..\AviUtl2PluginLib\MMD\IPC\Motion\MmdMotionSharedCodec.pas',
  MmdMotionSharedMemory in
    '..\..\AviUtl2PluginLib\MMD\IPC\Motion\MmdMotionSharedMemory.pas',
  MMD_Motion_Runtime in '..\Source\Plugin\Motion\MMD_Motion_Runtime.pas',
  MMD_Animation_ModulePlugin in
    '..\Source\Plugin\Serif\Module\MMD_Animation_ModulePlugin.pas',
  MMD_Serif_ModulePlugin in '..\Source\Plugin\Serif\Module\MMD_Serif_ModulePlugin.pas';

type
  TGetScriptModuleTable = function: PMMD_SCRIPT_MODULE_TABLE; cdecl;

const
  ModulePath = 'C:\ProgramData\aviutl2\Script\MMD\MMD_Module.mod2';

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

procedure TestPoseAndMotionModule;
const
  ModelFileName = 'C:\MMDAnimationModuleTest\model.pmx';
var
  Document: TMmdMotionDocument;
  Key: TMmdMotionMorphKey;
  MotionSnapshot: TMmdMotionSharedSnapshot;
  PoseSnapshot: TMmdPoseSharedSnapshot;
  Track: TMmdMotionMorphTrack;
begin
  IntParams[0] := 40;
  IntParams[1] := 321;
  StringParams[2] := UTF8String('pose-object');
  StringParams[3] := UTF8String(ModelFileName);
  StringParams[4] := UTF8String('{"version":1,"bones":[]}');
  MmdSetPose(@Param);
  Check(TryReadPoseSnapshot(40, HashModelPath(ModelFileName),
    PoseSnapshot), 'set_pose did not publish a snapshot');
  Check((PoseSnapshot.TimelineFrame = 321) and
    (PoseSnapshot.PoseData = '{"version":1,"bones":[]}'),
    'set_pose snapshot mismatch');

  Document := TMmdMotionDocument.Create;
  try
    Track := TMmdMotionMorphTrack.Create('smile');
    Key.Frame := 0;
    Key.Weight := 0.75;
    Track.Keys.Add(Key);
    Document.MorphTracks.Add(Track);
    IntParams[0] := 41;
    IntParams[2] := 654;
    DoubleParams[1] := 0;
    StringParams[3] := UTF8String('motion-object');
    StringParams[4] := UTF8String(ModelFileName);
    StringParams[5] := UTF8String(EncodeMmdMotionDocument(Document));
    MmdSetMotion(@Param);
  finally
    Document.Free;
  end;
  Check(TryReadMotionSnapshot(41, HashMotionModelPath(ModelFileName),
    MotionSnapshot), 'set_motion did not publish a snapshot');
  Check((MotionSnapshot.TimelineFrame = 654) and
    (Length(MotionSnapshot.Morphs) = 1) and
    (MotionSnapshot.Morphs[0].Name = 'smile') and
    (Abs(MotionSnapshot.Morphs[0].Weight - 0.75) < 0.0001),
    'set_motion snapshot mismatch');
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
    Inc(Func);
    Check((Func^.Name <> nil) and (string(Func^.Name) = 'set_pose') and
      Assigned(Func^.Func), 'set_pose function is missing');
    Inc(Func);
    Check((Func^.Name <> nil) and (string(Func^.Name) = 'set_motion') and
      Assigned(Func^.Func), 'set_motion function is missing');
  finally
    FreeLibrary(Module);
  end;
end;

begin
  try
    InitializeParam;
    TestDirectModuleAndLipSync;
    TestPoseAndMotionModule;
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
