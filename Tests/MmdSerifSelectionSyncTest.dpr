program MmdSerifSelectionSyncTest;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  AviUtl2PluginCore,
  AviUtl2PluginTypes,
  MmdSerifAviUtlNames,
  MmdSerifAviUtlSelectionSync;

var
  Edit: TEditSection;
  Handle: TEditHandle;
  FocusObject, WaveObject: TObjectHandle;
  EffectIsSerif: Boolean;
  WaveLayer: Integer;
  UID: UTF8String;
  WaveFile: UTF8String;

function FakeCallEditSection(Func: TProcEditSection): LongBool; cdecl;
begin
  Func(@Edit);
  Result := True;
end;

function FakeGetFocusObject: TObjectHandle; cdecl;
begin
  Result := FocusObject;
end;

function FakeGetObjectLayerFrame(Obj: TObjectHandle): TObjectLayerFrame; cdecl;
begin
  Result.Layer := 5;
  Result.StartFrame := 120;
  Result.EndFrame := 180;
end;

function FakeFindObject(Layer, Frame: Integer): TObjectHandle; cdecl;
begin
  Result := nil;
  if (Layer = WaveLayer) and (Frame = 120) then Result := WaveObject;
end;

function FakeGetObjectItemValue(Obj: TObjectHandle;
  Effect, Item: PWideChar): PAnsiChar; cdecl;
begin
  Result := nil;
  if (Obj = FocusObject) and EffectIsSerif and
    (string(Effect) = MMD_SERIF_EFFECT_NAME) and
    (string(Item) = 'UID') then
    Result := PAnsiChar(UID)
  else if (Obj = WaveObject) and
    (string(Effect) = #$97F3#$58F0#$30D5#$30A1#$30A4#$30EB) and
    (string(Item) = #$30D5#$30A1#$30A4#$30EB) then
    Result := PAnsiChar(WaveFile);
end;

procedure CheckWave(ExpectedLayer: Integer);
var
  Selection: TMmdSerifSelection;
begin
  if not TryReadSelectedMmdSerif(Selection) then
    raise Exception.Create('MMD serif selection was not found');
  if (Selection.Layer <> 5) or (Selection.StartFrame <> 120) or
    (Selection.EndFrame <> 180) or (Selection.WaveLayer <> ExpectedLayer) or
    (Selection.UID <> 'serif-1') then
    raise Exception.Create('MMD serif selection values differ');
end;

var
  Selection: TMmdSerifSelection;
begin
  try
    FillChar(Edit, SizeOf(Edit), 0);
    FillChar(Handle, SizeOf(Handle), 0);
    FocusObject := TObjectHandle(NativeUInt(1));
    WaveObject := TObjectHandle(NativeUInt(2));
    UID := UTF8String('serif-1');
    WaveFile := UTF8String('voice.wav');
    EffectIsSerif := True;
    Edit.GetFocusObject := FakeGetFocusObject;
    Edit.GetObjectLayerFrame := FakeGetObjectLayerFrame;
    Edit.FindObject := FakeFindObject;
    Edit.GetObjectItemValue := FakeGetObjectItemValue;
    Handle.CallEditSection := FakeCallEditSection;
    EditHandle := @Handle;
    WaveLayer := 6;
    CheckWave(6);
    WaveLayer := 4;
    CheckWave(4);
    WaveLayer := -1;
    CheckWave(-1);
    EffectIsSerif := False;
    if TryReadSelectedMmdSerif(Selection) then
      raise Exception.Create('Unrelated object was identified as MMD serif');
    Writeln('MmdSerifSelectionSyncTest: PASS');
  except
    on E: Exception do
    begin
      Writeln(E.ClassName + ': ' + E.Message);
      ExitCode := 1;
    end;
  end;
end.
