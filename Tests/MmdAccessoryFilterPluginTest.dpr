program MmdAccessoryFilterPluginTest;

{$APPTYPE CONSOLE}
{$POINTERMATH ON}

uses
  Winapi.Windows,
  System.Classes,
  System.IOUtils,
  System.SysUtils,
  AviUtl2FilterTypes in 'Source\Lib\AviUtl2FilterTypes.pas',
  MmdAccessoryObjectDragAlias in
    'Source\Plugin\Extension\Accessory\Catalog\Drag\MmdAccessoryObjectDragAlias.pas';

type
  PFilterItemFile = ^TFILTER_ITEM_FILE;
  PFilterItemTrack = ^TFILTER_ITEM_TRACK;
  TGetFilterPluginTable = function: PFILTER_PLUGIN_TABLE; cdecl;
  TInitializePlugin = function(Version: Cardinal): Byte; cdecl;

var
  AnchorHeight, AnchorWidth, DrawCalls, DrawVertices: Integer;

procedure Check(Condition: Boolean; const Message_: string);
begin
  if not Condition then raise Exception.Create(Message_);
end;

function TestDrawPoly(VertexType: Integer; VertexList: Pointer;
  VertexNum: Integer; Resource: LPCWSTR): Byte; cdecl;
begin
  Inc(DrawCalls);
  Inc(DrawVertices, VertexNum);
  Result := 1;
end;

procedure TestSetDefaultAnchor(Width, Height: Integer); cdecl;
begin
  AnchorWidth := Width;
  AnchorHeight := Height;
end;

procedure TestSetImageData(Buffer: PPIXEL_RGBA;
  Width, Height: Integer); cdecl;
begin
end;

procedure WriteSampleObj(const FileName: string);
var
  Lines: TStringList;
  Encoding: TEncoding;
begin
  Lines := TStringList.Create;
  try
    Lines.Add('v -1 0 0');
    Lines.Add('v 1 0 0');
    Lines.Add('v 0 1 0');
    Lines.Add('f 1 2 3');
    Encoding := TUTF8Encoding.Create(False);
    try
      Lines.SaveToFile(FileName, Encoding);
    finally
      Encoding.Free;
    end;
  finally
    Lines.Free;
  end;
end;

procedure Run;
var
  AliasText, DllFileName, ObjFileName, Root: string;
  FileItem: PFilterItemFile;
  GetTable: TGetFilterPluginTable;
  Initialize: TInitializePlugin;
  Items: PPointer;
  Module: HMODULE;
  ScaleItem: PFilterItemTrack;
  Table: PFILTER_PLUGIN_TABLE;
  Video: TFILTER_PROC_VIDEO;
  ObjValue: UnicodeString;
begin
  Check(ParamCount >= 1, 'filter DLL path was not supplied');
  DllFileName := TPath.GetFullPath(ParamStr(1));
  Root := TPath.Combine(TPath.GetTempPath,
    'MmdAccessoryFilter-' + TPath.GetRandomFileName);
  ForceDirectories(Root);
  try
    ObjFileName := TPath.Combine(Root, 'sample.obj');
    WriteSampleObj(ObjFileName);
    Check(TryBuildMmdAccessoryObjectAlias(ObjFileName, AliasText),
      'accessory alias could not be built');
    Check(Pos('effect.name=' + #$30A2#$30AF#$30BB#$30B5#$30EA,
      AliasText) > 0, 'accessory effect was absent from alias');
    Check(Pos(#$30E2#$30C7#$30EB#$30D5#$30A1#$30A4#$30EB + '=' +
      ObjFileName, AliasText) > 0, 'model file was absent from alias');
    Check(Pos('effect.name=' + #$6A19#$6E96#$63CF#$753B,
      AliasText) > 0, 'standard drawing was absent from alias');

    Module := LoadLibrary(PChar(DllFileName));
    Check(Module <> 0, 'filter DLL could not be loaded');
    try
      Initialize := TInitializePlugin(Winapi.Windows.GetProcAddress(Module,
        'InitializePlugin'));
      GetTable := TGetFilterPluginTable(Winapi.Windows.GetProcAddress(Module,
        'GetFilterPluginTable'));
      Check(Assigned(Initialize) and Assigned(GetTable),
        'required exports were absent');
      Check(Initialize(1) = 1, 'InitializePlugin rejected the host');
      Table := GetTable;
      Check(Assigned(Table), 'filter table was nil');
      Check(string(Table^.Name) = #$30A2#$30AF#$30BB#$30B5#$30EA,
        'filter name mismatch');
      Check(string(Table^.Label_) = 'MMD', 'filter group mismatch');
      Items := PPointer(Table^.Items);
      FileItem := PFilterItemFile(Items^);
      Inc(Items);
      ScaleItem := PFilterItemTrack(Items^);
      Inc(Items);
      Check(string(FileItem^.ItemType) = 'file', 'first item was not file');
      Check(string(FileItem^.Name) =
        #$30E2#$30C7#$30EB#$30D5#$30A1#$30A4#$30EB,
        'model file item mismatch');
      Check(string(ScaleItem^.ItemType) = 'track',
        'second item was not track');
      Check(string(ScaleItem^.Name) = 'MMD' + #$500D#$7387,
        'scale item mismatch');
      Check(Items^ = nil, 'filter item table was not terminated');
      ObjValue := ObjFileName;
      FileItem^.Value := PWideChar(ObjValue);
      Video := Default(TFILTER_PROC_VIDEO);
      Video.DrawPoly := TestDrawPoly;
      Video.SetDefaultAnchor := TestSetDefaultAnchor;
      Video.SetImageData := TestSetImageData;
      DrawCalls := 0;
      DrawVertices := 0;
      AnchorWidth := 0;
      AnchorHeight := 0;
      Check(Table^.Func_Proc_Video(@Video) = 0,
        'OBJ callback did not complete');
      Check((DrawCalls = 1) and (DrawVertices = 3),
        'OBJ callback did not reuse model renderer');
      Check((AnchorWidth = 640) and (AnchorHeight = 640),
        'default anchor mismatch');
    finally
      FreeLibrary(Module);
    end;
  finally
    if TDirectory.Exists(Root) then TDirectory.Delete(Root, True);
  end;
end;

begin
  try
    Run;
    Writeln('MmdAccessoryFilterPluginTest: PASS');
  except
    on E: Exception do
    begin
      Writeln('MmdAccessoryFilterPluginTest: FAIL: ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
