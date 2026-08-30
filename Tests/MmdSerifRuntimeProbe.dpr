program MmdSerifRuntimeProbe;

{$APPTYPE CONSOLE}

uses
  Winapi.Windows,
  System.SysUtils,
  SharedMemoryBase in '..\..\AviUtl2PluginLib\Lib\SharedMemory\SharedMemoryBase.pas',
  SerifSharedIndex in '..\..\AviUtl2PluginLib\Lib\SharedMemory\SerifSharedIndex.pas',
  SerifTalkSharedMemory in '..\..\AviUtl2PluginLib\Lib\SharedMemory\SerifTalkSharedMemory.pas',
  PluginFilterSerifDrawReceiver in '..\..\AviUtl2PluginLib\Serif\Plugin\Draw\PluginFilterSerifDrawReceiver.pas';

var
  I: Integer;
  EndTick: UInt64;
  Frame: Integer;
  Receiver: TSerifDrawReceiver;
  Snapshots: TArray<TSerifDrawSnapshot>;
  Text: string;
begin
  for I := 0 to SERIF_TALK_MAX_LINES - 1 do
    if TryReadSerifTalkText(I, Text) then
      Writeln('layer=', I, ' ', Text);
  if ParamCount > 0 then
  begin
    Frame := StrToIntDef(ParamStr(1), -1);
    Receiver := TSerifDrawReceiver.Create;
    try
      if ParamCount > 1 then
      begin
        EndTick := GetTickCount64 + UInt64(StrToIntDef(ParamStr(2), 0));
        repeat
          Snapshots := Receiver.ReadActive(Frame);
          if Length(Snapshots) > 0 then
            Break;
          Sleep(10);
        until GetTickCount64 >= EndTick;
      end
      else
        Snapshots := Receiver.ReadActive(Frame);
      Writeln('active_count=', Length(Snapshots));
      for I := 0 to High(Snapshots) do
        Writeln('active_layer=', Snapshots[I].Layer,
          ' source=', Snapshots[I].SourceObjectID,
          ' serif_length=', Length(Snapshots[I].Serif));
    finally
      Receiver.Free;
    end;
  end;
end.
