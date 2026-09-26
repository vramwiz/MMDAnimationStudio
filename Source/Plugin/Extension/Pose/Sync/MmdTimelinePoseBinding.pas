unit MmdTimelinePoseBinding;

// 選択中のMMDポーズScriptオブジェクトと拡張画面の姿勢データを往復する。

interface

type
  TMmdTimelinePoseSnapshot = record
    ObjectId: NativeUInt;
    Layer: Integer;
    StartFrame: Integer;
    EndFrame: Integer;
    ModelFile: string;
    PoseData: string;
    BaseModelObjectId: NativeUInt;
    BaseModelLayer: Integer;
    BaseModelStartFrame: Integer;
    BaseModelEndFrame: Integer;
    StandardPoseData: string;
    MotionData: string;
    MotionFrame: Integer;
  end;

// 編集セクション内の選択対象と基準姿勢を取得する。対象外または未選択ならFalse。
function TryReadSelectedMmdPose(out Snapshot: TMmdTimelinePoseSnapshot): Boolean;
// 対象・位置・モデル・元の姿勢が一致するときだけScriptへ新姿勢を書き込み、更新後の情報を返す。
function TryWriteSelectedMmdPose(const Expected: TMmdTimelinePoseSnapshot;
  const NewPoseData: string; out Updated: TMmdTimelinePoseSnapshot): Boolean;

implementation

uses
  System.SysUtils,
  Winapi.Windows,
  AviUtl2PluginCore,
  AviUtl2PluginTypes,
  MmdTimelinePoseDebugLog,
  PmxPose,
  PmxPoseCodec;

const
  PoseEffect = 'MMD' + #$30DD#$30FC#$30BA + '@MMD_Script';
  MotionEffect = 'MMD' + #$30E2#$30FC#$30B7#$30E7#$30F3 + '@MMD_Script';
  ModelEffect = #$30E2#$30C7#$30EB#$8868#$793A;
  ModelItem = #$30E2#$30C7#$30EB#$30D5#$30A1#$30A4#$30EB;
  PoseItem = #$30DD#$30FC#$30BA#$30C7#$30FC#$30BF;
  StandardPoseItem = #$30DD#$30FC#$30BA;
  PoseLayerItem = #$30DD#$30FC#$30BA#$53C2#$7167#$30EC#$30A4#$30E4#$30FC;
  MotionLayerItem = #$30E2#$30FC#$30B7#$30E7#$30F3#$53C2#$7167#$30EC#$30A4#$30E4#$30FC;
  MotionItem = #$30E2#$30FC#$30B7#$30E7#$30F3#$30C7#$30FC#$30BF;

type
  TMmdPoseCallKind = (pckRead, pckWrite);
  PMmdPoseCall = ^TMmdPoseCall;
  TMmdPoseCall = record
    Kind: TMmdPoseCallKind;
    Expected: TMmdTimelinePoseSnapshot;
    Updated: TMmdTimelinePoseSnapshot;
    NewPoseData: UTF8String;
    Success: Boolean;
  end;

threadvar
  CurrentCall: PMmdPoseCall;

function ReadValue(Edit: PEditSection; Obj: TObjectHandle;
  const Effect, Item: string; out Value: string): Boolean;
var
  Raw: LPCSTR;
begin
  Raw := Edit^.GetObjectItemValue(Obj, PWideChar(Effect), PWideChar(Item));
  Result := Raw <> nil;
  if not Result then
  begin
    Value := '';
    Exit;
  end;
  Value := UTF8ToString(AnsiString(Raw));
  // AviUtl2のScript文字列項目はGet時にバックスラッシュが1段エスケープ
  // されている。JSONとして解釈する前に保存表現から戻す。
  if (Item = PoseItem) or (Item = StandardPoseItem) or
    (Item = MotionItem) then
    Value := StringReplace(Value, '\\', '\', [rfReplaceAll]);
end;

function ReadSnapshot(Edit: PEditSection; Obj: TObjectHandle;
  out Snapshot: TMmdTimelinePoseSnapshot): Boolean;
var
  Candidate, MotionObj: TObjectHandle;
  Layer, MotionLayer, PoseLayer: Integer;
  ModelFile, Value: string;
  Position: TObjectLayerFrame;
begin
  Snapshot := Default(TMmdTimelinePoseSnapshot);
  Result := (Obj <> nil) and
    ReadValue(Edit, Obj, PoseEffect, ModelItem, Snapshot.ModelFile) and
    ReadValue(Edit, Obj, PoseEffect, PoseItem, Snapshot.PoseData) and
    (Snapshot.ModelFile <> '');
  if not Result then Exit;
  Position := Edit^.GetObjectLayerFrame(Obj);
  Snapshot.ObjectId := NativeUInt(Obj);
  Snapshot.Layer := Position.Layer;
  Snapshot.StartFrame := Position.StartFrame;
  Snapshot.EndFrame := Position.EndFrame;
  if not Assigned(Edit^.FindObject) or (Edit^.Info = nil) then Exit;
  for Layer := 0 to Edit^.Info^.LayerMax do
  begin
    Candidate := Edit^.FindObject(Layer, Edit^.Info^.Frame);
    if (Candidate = nil) or
      not ReadValue(Edit, Candidate, ModelEffect, ModelItem, ModelFile) or
      not SameText(ModelFile, Snapshot.ModelFile) or
      not ReadValue(Edit, Candidate, ModelEffect, PoseLayerItem, Value) then Continue;
    PoseLayer := Round(StrToFloatDef(Value, 0));
    if PoseLayer <> Snapshot.Layer + 1 then Continue;
    Snapshot.BaseModelObjectId := NativeUInt(Candidate);
    Position := Edit^.GetObjectLayerFrame(Candidate);
    Snapshot.BaseModelLayer := Position.Layer;
    Snapshot.BaseModelStartFrame := Position.StartFrame;
    Snapshot.BaseModelEndFrame := Position.EndFrame;
    ReadValue(Edit, Candidate, ModelEffect, StandardPoseItem,
      Snapshot.StandardPoseData);
    if ReadValue(Edit, Candidate, ModelEffect, MotionLayerItem, Value) then
    begin
      MotionLayer := Round(StrToFloatDef(Value, 0)) - 1;
      if (MotionLayer >= 0) and (MotionLayer <= Edit^.Info^.LayerMax) then
      begin
        MotionObj := Edit^.FindObject(MotionLayer, Edit^.Info^.Frame);
        if (MotionObj <> nil) and
          ReadValue(Edit, MotionObj, MotionEffect, ModelItem, ModelFile) and
          SameText(ModelFile, Snapshot.ModelFile) and
          ReadValue(Edit, MotionObj, MotionEffect, MotionItem, Snapshot.MotionData) then
        begin
          Position := Edit^.GetObjectLayerFrame(MotionObj);
          Snapshot.MotionFrame := Edit^.Info^.Frame - Position.StartFrame;
        end;
      end;
    end;
    Break;
  end;
end;

function FindSelectedPose(Edit: PEditSection;
  out Snapshot: TMmdTimelinePoseSnapshot;
  out Obj: TObjectHandle): Boolean;
begin
  Obj := Edit^.GetFocusObject();
  Result := ReadSnapshot(Edit, Obj, Snapshot);
  if Result then Exit;
  if Edit^.GetSelectedObjectNum() <> 1 then Exit(False);
  Obj := Edit^.GetSelectedObject(0);
  Result := ReadSnapshot(Edit, Obj, Snapshot);
end;

procedure PoseEditCallCore(Edit: PEditSection);
var
  Actual, AfterWrite: TMmdTimelinePoseSnapshot;
  Obj, AfterObj: TObjectHandle;
{$IFDEF DEBUG}
  Requested: string;
  SetStart: UInt64;
{$ENDIF}
begin
  if (CurrentCall = nil) or (Edit = nil) or (Edit^.Info = nil) then
  begin
    {$IFDEF DEBUG}PoseDebugLog('sdk.invalid_context', '');{$ENDIF}
    Exit;
  end;
  if not FindSelectedPose(Edit, Actual, Obj) then
  begin
    {$IFDEF DEBUG}
    if CurrentCall^.Kind = pckWrite then
      PoseDebugLog('sdk.selection_missing', '');
    {$ENDIF}
    Exit;
  end;
  if CurrentCall^.Kind = pckRead then
  begin
    CurrentCall^.Updated := Actual;
    CurrentCall^.Success := True;
    Exit;
  end;
  // AviUtl2は項目更新時に同じタイムライン位置のハンドルを作り直すことがある。
  // 対象位置と更新前の値で照合し、ポインタの一致は要求しない。
  {$IFDEF DEBUG}
  PoseDebugLog('sdk.write_before',
    'obj=' + IntToHex(NativeUInt(Obj), 16) +
    ' expected_obj=' + IntToHex(CurrentCall^.Expected.ObjectId, 16) +
    ' layer=' + IntToStr(Actual.Layer) + '/' +
      IntToStr(CurrentCall^.Expected.Layer) +
    ' frame=' + IntToStr(Actual.StartFrame) + ':' +
      IntToStr(Actual.EndFrame) + '/' +
      IntToStr(CurrentCall^.Expected.StartFrame) + ':' +
      IntToStr(CurrentCall^.Expected.EndFrame) +
    ' model_equal=' + BoolToStr(Actual.ModelFile =
      CurrentCall^.Expected.ModelFile, True) +
    ' base_equal=' + BoolToStr(Actual.StandardPoseData =
      CurrentCall^.Expected.StandardPoseData, True) +
    ' motion_equal=' + BoolToStr(Actual.MotionData =
      CurrentCall^.Expected.MotionData, True) +
    ' motion_frame=' + IntToStr(Actual.MotionFrame) + '/' +
      IntToStr(CurrentCall^.Expected.MotionFrame) +
    ' pose_equal=' + BoolToStr(Actual.PoseData =
      CurrentCall^.Expected.PoseData, True));
  if Actual.PoseData <> CurrentCall^.Expected.PoseData then
    PoseDebugTextPair('sdk.guard_pose_mismatch',
      CurrentCall^.Expected.PoseData, Actual.PoseData);
  {$ENDIF}
  if (Actual.Layer <> CurrentCall^.Expected.Layer) or
    (Actual.StartFrame <> CurrentCall^.Expected.StartFrame) or
    (Actual.EndFrame <> CurrentCall^.Expected.EndFrame) or
    (Actual.ModelFile <> CurrentCall^.Expected.ModelFile) or
    (Actual.PoseData <> CurrentCall^.Expected.PoseData) or
    (Actual.StandardPoseData <> CurrentCall^.Expected.StandardPoseData) or
    (Actual.MotionData <> CurrentCall^.Expected.MotionData) or
    (Actual.MotionFrame <> CurrentCall^.Expected.MotionFrame) then
  begin
    {$IFDEF DEBUG}PoseDebugLog('sdk.write_rejected', 'snapshot_mismatch');{$ENDIF}
    Exit;
  end;
  {$IFDEF DEBUG}
  Requested := UTF8ToString(CurrentCall^.NewPoseData);
  {$ENDIF}
  if Actual.PoseData <> UTF8ToString(CurrentCall^.NewPoseData) then
  begin
    {$IFDEF DEBUG}
    SetStart := GetTickCount64;
    PoseDebugLog('sdk.set_begin',
      'utf8bytes=' + IntToStr(Length(CurrentCall^.NewPoseData)));
    {$ENDIF}
    if not Edit^.SetObjectItemValue(Obj, PWideChar(PoseEffect),
      PWideChar(PoseItem), PAnsiChar(CurrentCall^.NewPoseData)) then
    begin
      {$IFDEF DEBUG}
      PoseDebugLog('sdk.set_failed',
        'ms=' + UIntToStr(GetTickCount64 - SetStart));
      {$ENDIF}
      Exit;
    end;
    {$IFDEF DEBUG}
    PoseDebugLog('sdk.set_done',
      'ms=' + UIntToStr(GetTickCount64 - SetStart));
    {$ENDIF}
  end
  else
  begin
    {$IFDEF DEBUG}PoseDebugLog('sdk.set_skipped', 'same_pose_data');{$ENDIF}
  end;
  if FindSelectedPose(Edit, AfterWrite, AfterObj) and
    (AfterWrite.Layer = Actual.Layer) and
    (AfterWrite.StartFrame = Actual.StartFrame) and
    (AfterWrite.EndFrame = Actual.EndFrame) and
    (AfterWrite.ModelFile = Actual.ModelFile) then
  begin
    {$IFDEF DEBUG}
    PoseDebugLog('sdk.readback',
      'requested_equal=' + BoolToStr(Requested = AfterWrite.PoseData, True) +
      ' previous_equal=' + BoolToStr(AfterWrite.PoseData =
        Actual.PoseData, True));
    if Requested <> AfterWrite.PoseData then
      PoseDebugTextPair('sdk.readback_mismatch', Requested,
        AfterWrite.PoseData);
    PoseDebugLog('sdk.readback_vs_before',
      'equal=' + BoolToStr(AfterWrite.PoseData = Actual.PoseData, True) +
      ' obj=' + IntToHex(NativeUInt(AfterObj), 16));
    {$ENDIF}
  end
  else
  begin
    {$IFDEF DEBUG}PoseDebugLog('sdk.readback_missing', '');{$ENDIF}
    Exit;
  end;
  CurrentCall^.Updated := AfterWrite;
  CurrentCall^.Success := True;
end;

procedure PoseEditCall(Edit: PEditSection); cdecl;
begin
  try
    PoseEditCallCore(Edit);
  except
    on E: Exception do
    begin
      if CurrentCall <> nil then CurrentCall^.Success := False;
      {$IFDEF DEBUG}PoseDebugLog('sdk.exception', E.ClassName);{$ENDIF}
    end;
  end;
end;

function Invoke(var Call: TMmdPoseCall): Boolean;
var
  Previous: PMmdPoseCall;
{$IFDEF DEBUG}
  StartTick: UInt64;
{$ENDIF}
begin
  Result := False;
  if (EditHandle = nil) or not Assigned(EditHandle^.CallEditSection) then Exit;
  Previous := CurrentCall;
  CurrentCall := @Call;
  try
    {$IFDEF DEBUG}StartTick := GetTickCount64;{$ENDIF}
    EditHandle^.CallEditSection(@PoseEditCall);
    Result := Call.Success;
    {$IFDEF DEBUG}
    if GetTickCount64 - StartTick >= 50 then
      PoseDebugLog('sdk.call_slow',
        'kind=' + IntToStr(Ord(Call.Kind)) +
        ' ms=' + UIntToStr(GetTickCount64 - StartTick));
    {$ENDIF}
  finally
    CurrentCall := Previous;
  end;
end;

function TryReadSelectedMmdPose(
  out Snapshot: TMmdTimelinePoseSnapshot): Boolean;
var
  Call: TMmdPoseCall;
begin
  Call := Default(TMmdPoseCall);
  Call.Kind := pckRead;
  Result := Invoke(Call);
  Snapshot := Call.Updated;
end;

function TryWriteSelectedMmdPose(
  const Expected: TMmdTimelinePoseSnapshot; const NewPoseData: string;
  out Updated: TMmdTimelinePoseSnapshot): Boolean;
var
  Call: TMmdPoseCall;
  NamedPoses: TPmxNamedBonePoses;
begin
  Updated := Default(TMmdTimelinePoseSnapshot);
  Result := (Expected.ObjectId <> 0) and
    TryDecodePoseData(NewPoseData, NamedPoses);
  if not Result then
  begin
    {$IFDEF DEBUG}
    PoseDebugLog('write.invalid_request',
      'expected_obj=' + IntToHex(Expected.ObjectId, 16));
    PoseDebugText('write.invalid_json', NewPoseData);
    {$ENDIF}
    Exit;
  end;
  Call := Default(TMmdPoseCall);
  Call.Kind := pckWrite;
  Call.Expected := Expected;
  Call.NewPoseData := UTF8String(NewPoseData);
  Result := Invoke(Call);
  if Result then Updated := Call.Updated;
end;

end.
