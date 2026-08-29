program MmdFaceFilterPluginTest;

{$APPTYPE CONSOLE}
{$POINTERMATH ON}

uses
  Winapi.Windows,
  System.SysUtils,
  AviUtl2FilterTypes in 'Source\Lib\AviUtl2FilterTypes.pas',
  MmdFaceSharedMemory in
    '..\AviUtl2PluginLib\MMD\IPC\MmdFaceSharedMemory.pas';

type
  PFilterItemFile = ^TFILTER_ITEM_FILE;
  PFilterItemString = ^TFILTER_ITEM_STRING;
  PFilterItemButton = ^TFILTER_ITEM_BUTTON;
  TGetFilterPluginTable = function: PFILTER_PLUGIN_TABLE; cdecl;
  TInitializePlugin = function(Version: Cardinal): Byte; cdecl;

var
  ImageHeight, ImageWidth: Integer;

procedure TestSetImageData(Buffer: PPIXEL_RGBA;
  Width, Height: Integer); cdecl;
begin
  ImageWidth := Width;
  ImageHeight := Height;
end;

procedure Check(Condition: Boolean; const Message_: string);
begin
  if not Condition then raise Exception.Create(Message_);
end;

procedure Run;
var
  ButtonItem: PFilterItemButton;
  FileItem: PFilterItemFile;
  GetTable: TGetFilterPluginTable;
  Initialize: TInitializePlugin;
  Items: PPointer;
  Module: HMODULE;
  ObjectInfo: TOBJECT_INFO;
  ReadBack: TMmdFaceSharedSnapshot;
  StringItem: PFilterItemString;
  Table: PFILTER_PLUGIN_TABLE;
  Video: TFILTER_PROC_VIDEO;
  FaceData, ModelFileName: UnicodeString;
begin
  Check(ParamCount >= 1, 'filter DLL path was not supplied');
  Module := LoadLibrary(PChar(ParamStr(1)));
  Check(Module <> 0, 'filter DLL could not be loaded');
  try
    Initialize := TInitializePlugin(Winapi.Windows.GetProcAddress(Module,
      'InitializePlugin'));
    GetTable := TGetFilterPluginTable(Winapi.Windows.GetProcAddress(Module,
      'GetFilterPluginTable'));
    Check(Assigned(Initialize), 'InitializePlugin export was not found');
    Check(Assigned(GetTable), 'GetFilterPluginTable export was not found');
    Check(Initialize(1) = 1, 'InitializePlugin rejected the host');
    Table := GetTable;
    Check(Assigned(Table), 'filter table was nil');
    Check(string(Table^.Name) = #$8868#$60C5, 'filter name mismatch');
    Check(string(Table^.Label_) = 'MMD', 'filter label mismatch');
    Check((Table^.Flag and FILTER_FLAG_VIDEO) <> 0, 'video flag was absent');
    Check((Table^.Flag and FILTER_FLAG_INPUT) <> 0, 'input flag was absent');
    Items := PPointer(Table^.Items);
    Check(Assigned(Items), 'filter item table was nil');
    FileItem := PFilterItemFile(Items^);
    Inc(Items);
    StringItem := PFilterItemString(Items^);
    Inc(Items);
    ButtonItem := PFilterItemButton(Items^);
    Inc(Items);
    Check(string(FileItem^.ItemType) = 'file', 'first item was not file');
    Check(string(FileItem^.Name) =
      #$30E2#$30C7#$30EB#$30D5#$30A1#$30A4#$30EB,
      'model file item name mismatch');
    Check(string(StringItem^.ItemType) = 'string',
      'second item was not string');
    Check(string(StringItem^.Name) = #$8868#$60C5,
      'face item name mismatch');
    Check(string(StringItem^.Value) = '{"version":1,"morphs":[]}',
      'face item default mismatch');
    Check(string(ButtonItem^.ItemType) = 'button',
      'third item was not button');
    Check(string(ButtonItem^.Name) = #$8A2D#$5B9A,
      'button item name mismatch');
    Check(Assigned(ButtonItem^.Callback), 'button callback was nil');
    Check(Items^ = nil, 'filter item table was not terminated');
    Check(Assigned(Table^.Func_Proc_Video), 'video callback was nil');
    ModelFileName := 'C:\model\filter-callback.pmx';
    FaceData := '{"version":1,"morphs":[' +
      '{"name":"smile","weight":0.6}]}';
    FileItem^.Value := PWideChar(ModelFileName);
    StringItem^.Value := PWideChar(FaceData);
    ObjectInfo := Default(TOBJECT_INFO);
    ObjectInfo.Layer := 927;
    ObjectInfo.ID := 701;
    ObjectInfo.EffectID := 801;
    ObjectInfo.FrameS := 100;
    ObjectInfo.Frame := 20;
    Video := Default(TFILTER_PROC_VIDEO);
    Video.Object_ := @ObjectInfo;
    Video.SetImageData := TestSetImageData;
    ImageWidth := 0;
    ImageHeight := 0;
    Check(Table^.Func_Proc_Video(@Video) = 1,
      'video callback result mismatch');
    Check((ImageWidth = 1) and (ImageHeight = 1),
      'video callback did not emit a transparent image');
    Check(TryReadFaceSnapshot(927, HashFaceModelPath(ModelFileName),
      ReadBack), 'video callback did not publish face data');
    Check((ReadBack.WriterObjectID = 701) and
      (ReadBack.WriterEffectID = 801), 'published writer mismatch');
    Check(ReadBack.TimelineFrame = 120, 'published frame mismatch');
    Check(ReadBack.FaceData = FaceData, 'published face data mismatch');
  finally
    FreeLibrary(Module);
  end;
end;

begin
  try
    Run;
    Writeln('MmdFaceFilterPluginTest: PASS');
  except
    on E: Exception do
    begin
      Writeln('MmdFaceFilterPluginTest: FAIL: ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
