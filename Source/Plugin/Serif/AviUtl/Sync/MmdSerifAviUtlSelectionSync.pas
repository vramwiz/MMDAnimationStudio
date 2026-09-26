unit MmdSerifAviUtlSelectionSync;

// 選択中のMMDセリフと隣接音声レイヤーをAviUtl2編集セクション内で読む。

interface

type
  TMmdSerifSelection = record
    ObjectId: NativeUInt;
    Layer: Integer;
    StartFrame: Integer;
    EndFrame: Integer;
    WaveLayer: Integer;
    UID: string;
  end;

// フォーカス中のMMDセリフを取得する。対象外・未選択ならFalse。
function TryReadSelectedMmdSerif(out Selection: TMmdSerifSelection): Boolean;

implementation

uses
  System.SysUtils,
  AviUtl2PluginCore,
  AviUtl2PluginTypes,
  MmdSerifAviUtlNames;

const
  AudioEffect = #$97F3#$58F0#$30D5#$30A1#$30A4#$30EB;
  AudioFileItem = #$30D5#$30A1#$30A4#$30EB;

type
  PMmdSerifSelectionCall = ^TMmdSerifSelectionCall;
  TMmdSerifSelectionCall = record
    Selection: TMmdSerifSelection;
    Found: Boolean;
  end;

threadvar
  CurrentCall: PMmdSerifSelectionCall;

procedure ReadSelection(Edit: PEditSection); cdecl;
var
  Obj, Wave: TObjectHandle;
  Position: TObjectLayerFrame;
  Raw: LPCSTR;
  Layer, Candidate: Integer;
begin
  try
  if (CurrentCall = nil) or (Edit = nil) or
    not Assigned(Edit^.GetFocusObject) or
    not Assigned(Edit^.GetObjectItemValue) or
    not Assigned(Edit^.GetObjectLayerFrame) then Exit;
  Obj := Edit^.GetFocusObject();
  if Obj = nil then Exit;
  // UID項目の存在でMMDセリフScriptを識別する。UID値は空でも配置で照合できる。
  Raw := Edit^.GetObjectItemValue(Obj, PWideChar(MMD_SERIF_EFFECT_NAME),
    PWideChar(MMD_SERIF_UID_ITEM));
  if Raw = nil then Exit;
  Position := Edit^.GetObjectLayerFrame(Obj);
  CurrentCall^.Selection.ObjectId := NativeUInt(Obj);
  CurrentCall^.Selection.Layer := Position.Layer;
  CurrentCall^.Selection.StartFrame := Position.StartFrame;
  CurrentCall^.Selection.EndFrame := Position.EndFrame;
  CurrentCall^.Selection.UID := UTF8ToString(AnsiString(Raw));
  CurrentCall^.Selection.WaveLayer := -1;
  if Assigned(Edit^.FindObject) then
    for Layer := 0 to 1 do
    begin
      if Layer = 0 then Candidate := Position.Layer + 1
      else Candidate := Position.Layer - 1;
      if Candidate < 0 then Continue;
      Wave := Edit^.FindObject(Candidate, Position.StartFrame);
      if (Wave <> nil) and
        (Edit^.GetObjectItemValue(Wave, PWideChar(AudioEffect),
          PWideChar(AudioFileItem)) <> nil) then
      begin
        CurrentCall^.Selection.WaveLayer := Candidate;
        Break;
      end;
    end;
  CurrentCall^.Found := True;
  except
    // AviUtl2のC ABIコールバックへDelphi例外を返さない。
    if CurrentCall <> nil then CurrentCall^.Found := False;
  end;
end;

function TryReadSelectedMmdSerif(out Selection: TMmdSerifSelection): Boolean;
var
  Call: TMmdSerifSelectionCall;
  Previous: PMmdSerifSelectionCall;
begin
  Selection := Default(TMmdSerifSelection);
  Result := False;
  if (EditHandle = nil) or not Assigned(EditHandle^.CallEditSection) then Exit;
  Call := Default(TMmdSerifSelectionCall);
  Previous := CurrentCall;
  CurrentCall := @Call;
  try
    if not EditHandle^.CallEditSection(@ReadSelection) then Exit;
  finally
    CurrentCall := Previous;
  end;
  Result := Call.Found;
  if Result then Selection := Call.Selection;
end;

end.
