program MmdTimelinePoseBindingTest;

{$APPTYPE CONSOLE}

uses
  System.Math,
  System.SysUtils,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.Forms,
  AviUtl2PluginCore,
  AviUtl2PluginTypes,
  MmdTimelinePoseBinding,
  MmdTimelinePoseComposite,
  MmdTimelinePosePageController,
  MmdMotionDocument,
  MmdMotionDocumentCodec,
  MmdProControllerInput,
  MmdSimpleControllerSolver,
  MmdSimpleControllerBones,
  MmdSimpleControllerView,
  MmdSimplePoseEditSession,
  PmxModel,
  PmxPose,
  PmxPoseCodec,
  PmxPoseMath,
  PmxReader;

var
  Edit: TEditSection;
  EditInfo: TEditInfo;
  Handle: TEditHandle;
  FocusObject: TObjectHandle;
  ModelObject: TObjectHandle;
  MotionObject: TObjectHandle;
  SelectedObject: TObjectHandle;
  ModelValue: UTF8String;
  ModelBaseValue: UTF8String;
  ModelYawValue: UTF8String;
  ModelPitchValue: UTF8String;
  MotionValue: UTF8String;
  MotionLayerValue: UTF8String;
  PoseLayerValue: UTF8String;
  PoseValue: UTF8String;
  ReadPoseOverride: UTF8String;
  UseReadPoseOverride: Boolean;
  RecreateHandlesOnWrite: Boolean;
  EscapeBackslashesOnWrite: Boolean;
  IsPoseEffect: Boolean;
  HidePoseRead: Boolean;
  WriteCount: Integer;
  AngleWriteCount: Integer;

function FakeCallEditSection(Func: TProcEditSection): LongBool; cdecl;
begin
  Func(@Edit);
  Result := True;
end;

function FakeGetFocusObject: TObjectHandle; cdecl;
begin
  Result := FocusObject;
end;

function FakeGetSelectedObjectNum: Integer; cdecl;
begin
  Result := Ord(SelectedObject <> nil);
end;

function FakeGetSelectedObject(Index: Integer): TObjectHandle; cdecl;
begin
  if Index = 0 then Result := SelectedObject else Result := nil;
end;

function FakeGetObjectLayerFrame(Obj: TObjectHandle): TObjectLayerFrame; cdecl;
begin
  if Obj = ModelObject then Result.Layer := 0
  else if Obj = MotionObject then Result.Layer := 1
  else Result.Layer := 2;
  Result.StartFrame := 10;
  Result.EndFrame := 80;
end;

function FakeFindObject(Layer, Frame: Integer): TObjectHandle; cdecl;
begin
  Result := nil;
  if (Layer = 0) and (Frame >= 10) and (Frame <= 80) then
    Result := ModelObject
  else if (Layer = 1) and (Frame >= 10) and (Frame <= 80) then
    Result := MotionObject
  else if (Layer = 2) and (Frame >= 10) and (Frame <= 80) then
    Result := SelectedObject;
end;

function FakeGetObjectItemValue(Obj: TObjectHandle;
  Effect, Item: PWideChar): PAnsiChar; cdecl;
begin
  Result := nil;
  if (Obj = ModelObject) and (string(Effect) = 'モデル表示') then
  begin
    if string(Item) = 'モデルファイル' then Result := PAnsiChar(ModelValue)
    else if string(Item) = 'ポーズ参照レイヤー' then
      Result := PAnsiChar(PoseLayerValue)
    else if string(Item) = 'モーション参照レイヤー' then
      Result := PAnsiChar(MotionLayerValue)
    else if string(Item) = 'ポーズ' then Result := PAnsiChar(ModelBaseValue);
    if string(Item) = 'モデル表示角度Y' then
      Result := PAnsiChar(ModelYawValue)
    else if string(Item) = 'モデル表示角度X' then
      Result := PAnsiChar(ModelPitchValue);
    Exit;
  end;
  if (Obj = MotionObject) and
    (string(Effect) = 'MMDモーション@MMD_Script') then
  begin
    if string(Item) = 'モデルファイル' then Result := PAnsiChar(ModelValue)
    else if string(Item) = 'モーションデータ' then
      Result := PAnsiChar(MotionValue);
    Exit;
  end;
  if HidePoseRead or not IsPoseEffect or (Obj <> SelectedObject) or
    (string(Effect) <> 'MMDポーズ@MMD_Script') then Exit;
  if string(Item) = 'モデルファイル' then Result := PAnsiChar(ModelValue)
  else if string(Item) = 'ポーズデータ' then
  begin
    if UseReadPoseOverride then Result := PAnsiChar(ReadPoseOverride)
    else Result := PAnsiChar(PoseValue);
  end;
end;

function FakeSetObjectItemValue(Obj: TObjectHandle;
  Effect, Item: PWideChar; Value: PAnsiChar): LongBool; cdecl;
begin
  if (Obj = ModelObject) and (string(Effect) = 'モデル表示') then
  begin
    Result := (string(Item) = 'モデル表示角度Y') or
      (string(Item) = 'モデル表示角度X');
    if Result then
    begin
      if string(Item) = 'モデル表示角度Y' then
        ModelYawValue := UTF8String(Value)
      else ModelPitchValue := UTF8String(Value);
      Inc(AngleWriteCount);
    end;
    Exit;
  end;
  Result := IsPoseEffect and (Obj = SelectedObject) and
    (string(Effect) = 'MMDポーズ@MMD_Script') and
    (string(Item) = 'ポーズデータ');
  if Result then
  begin
    PoseValue := UTF8String(Value);
    if EscapeBackslashesOnWrite then
      PoseValue := UTF8String(StringReplace(UTF8ToString(PoseValue),
        '\', '\\', [rfReplaceAll]));
    Inc(WriteCount);
    if RecreateHandlesOnWrite then
    begin
      SelectedObject := Pointer(NativeUInt(SelectedObject) + 1);
      FocusObject := SelectedObject;
      ModelObject := Pointer(NativeUInt(ModelObject) + 1);
    end;
  end;
end;

procedure Check(Condition: Boolean; const MessageText: string);
begin
  if not Condition then raise Exception.Create(MessageText);
end;

function UpperBodyRotationX(const PoseText, BoneName: string): Single;
var
  Index: Integer;
  Poses: TPmxNamedBonePoses;
begin
  if not TryDecodePoseData(PoseText, Poses) then
    raise Exception.Create('virtual stick wrote invalid pose JSON');
  for Index := 0 to High(Poses) do
    if Poses[Index].BoneName = BoneName then
      Exit(Poses[Index].Pose.Rotation.X);
  raise Exception.Create('virtual stick did not write upper-body rotation');
end;

function ReadCurrentPoseData: string;
var
  Snapshot: TMmdTimelinePoseSnapshot;
begin
  Check(TryReadSelectedMmdPose(Snapshot),
    'current pose could not be read');
  Result := Snapshot.PoseData;
end;

procedure RunTests(const ModelPath: string);
var
  Current, Updated: TMmdTimelinePoseSnapshot;
  FirstPose, NextPose: string;
  Form: TForm;
  Catalog: TPanel;
  Page: TMmdTimelinePosePageController;
  Pad: TMmdProPadState;
  FirstWrittenPose: string;
  WritesBeforeStick: Integer;
  BasePoses, CurrentPoses, RebuiltBase, RebuiltPoses: TPmxBonePoses;
  BodyIndex: Integer;
  Model: TPmxModel;
  Overlay: string;
  Session: TMmdSimplePoseEditSession;
  MotionDocument: TMmdMotionDocument;
  MotionKey: TMmdMotionBoneKey;
  MotionDataText: string;
  BodyName: string;
  EscapedPose: string;
  NamedPoses: TPmxNamedBonePoses;
  FirstRotationX, SecondRotationX, ThirdRotationX: Single;
  RootBefore, RootAfter, RootDecoded: TPmxQuaternion;
  HasRoot: Boolean;
  BaseYaw, BasePitch, CurrentYaw, CurrentPitch: Single;
  InputPoses: TPmxBonePoses;
  BeforeTransforms, AfterTransforms: TPmxBoneTransforms;
  Arm, Elbow, Wrist: Integer;
  Delta, ScreenRight: TPmxVector3;
begin
  Edit := Default(TEditSection);
  EditInfo := Default(TEditInfo);
  Edit.Info := @EditInfo;
  EditInfo.Frame := 20;
  EditInfo.LayerMax := 3;
  Edit.FindObject := FakeFindObject;
  Edit.GetFocusObject := FakeGetFocusObject;
  Edit.GetSelectedObjectNum := FakeGetSelectedObjectNum;
  Edit.GetSelectedObject := FakeGetSelectedObject;
  Edit.GetObjectLayerFrame := FakeGetObjectLayerFrame;
  Edit.GetObjectItemValue := FakeGetObjectItemValue;
  Edit.SetObjectItemValue := FakeSetObjectItemValue;
  Handle := Default(TEditHandle);
  Handle.CallEditSection := FakeCallEditSection;
  EditHandle := @Handle;
  try
    SelectedObject := Pointer(1);
    ModelObject := Pointer(100);
    MotionObject := Pointer(101);
    FocusObject := SelectedObject;
    IsPoseEffect := True;
    ModelValue := UTF8String('C:\model.pmx');
    ModelBaseValue := UTF8String('{"version":1,"bones":[]}');
    ModelYawValue := UTF8String('0');
    ModelPitchValue := UTF8String('0');
    PoseLayerValue := UTF8String('3');
    MotionLayerValue := UTF8String('2');
    MotionValue := UTF8String('');
    FirstPose := '{"version":1,"bones":[]}';
    NextPose := '{"version":1,"bones":[{"name":"センター",' +
      '"translation":[1,0,0],"rotation":[0,0,0,1]}]}';
    PoseValue := UTF8String(FirstPose);
    Check(TryReadSelectedMmdPose(Current), 'selected pose was not read');
    Check((Current.ObjectId = NativeUInt(SelectedObject)) and
      (Current.Layer = 2) and (Current.StartFrame = 10) and
      (Current.BaseModelObjectId = NativeUInt(ModelObject)) and
      (Current.ModelFile = 'C:\model.pmx') and
      (Current.PoseData = FirstPose), 'selected pose data is wrong');
    Check(TryWriteSelectedMmdPose(Current, NextPose, Updated),
      'matching pose was not written');
    Check((WriteCount = 1) and (Updated.PoseData = NextPose) and
      (UTF8ToString(PoseValue) = NextPose), 'pose write lost UTF-8 data');
    Check(not TryWriteSelectedMmdPose(Current, FirstPose, Updated),
      'stale pose write was accepted');
    Check(WriteCount = 1, 'stale pose write changed the object');
    SelectedObject := Pointer(2);
    FocusObject := SelectedObject;
    Check(not TryWriteSelectedMmdPose(Current, FirstPose, Updated),
      'write to a different selected object was accepted');
    Check(TryReadSelectedMmdPose(Current) and
      (Current.ObjectId = NativeUInt(SelectedObject)),
      'new selection was not read');
    IsPoseEffect := False;
    Check(not TryReadSelectedMmdPose(Current),
      'unrelated effect was treated as MMD pose');
    IsPoseEffect := True;
    FocusObject := Pointer(3);
    Check(TryReadSelectedMmdPose(Current) and
      (Current.ObjectId = NativeUInt(SelectedObject)),
      'single selected object fallback failed');
    Check(not TryWriteSelectedMmdPose(Current, '{broken', Updated),
      'invalid JSON was accepted');

    ModelValue := UTF8String(ModelPath);
    Model := GetCachedPmxModel(ModelPath);
    RootBefore := IdentityQuaternion;
    RootAfter := QuaternionFromEulerXYZ(0, 0.5, 0);
    Overlay := EncodePoseDataWithRoot(nil, RootAfter);
    Check(TryDecodePoseDataWithRoot(Overlay, NamedPoses,
      RootDecoded, HasRoot) and HasRoot and
      (Abs(RootDecoded.Y - RootAfter.Y) < 0.00001),
      'global pose rotation did not survive JSON roundtrip');
    Check(TryComposeTimelinePose(Model, '{"version":1,"bones":[]}',
      '', 0, Overlay, BasePoses, CurrentPoses, RootBefore,
      RootDecoded) and
      (Abs(RootDecoded.Y - RootAfter.Y) < 0.00001),
      'global pose rotation was not composed');
    Overlay := EncodeTimelinePoseOverlay(Model, BasePoses,
      CurrentPoses, RootBefore, RootDecoded);
    Check(Pos('rootRotation', Overlay) > 0,
      'global pose rotation was dropped by overlay encoding');
    Overlay := EncodePoseDataWithRootAndAngle(nil, RootAfter, True,
      45, 20, True);
    Check(TryComposeTimelinePose(Model, FirstPose, '', 0, Overlay,
      BasePoses, CurrentPoses, RootBefore, RootDecoded,
      BaseYaw, BasePitch, CurrentYaw, CurrentPitch) and
      (Abs(CurrentYaw - 45) < 0.0001) and
      (Abs(CurrentPitch - 20) < 0.0001),
      'relative angle was not composed from the pose object');
    Overlay := EncodeTimelinePoseOverlay(Model, BasePoses, CurrentPoses,
      RootBefore, RootDecoded, BaseYaw, BasePitch,
      CurrentYaw, CurrentPitch);
    Check((Pos('relativeAngles', Overlay) > 0) and
      (Pos('rootRotation', Overlay) > 0),
      'pose overlay discarded the relative angle');
    HandBones(Model, True, Arm, Elbow, Wrist);
    Check((Arm >= 0) and (Elbow >= 0) and (Wrist >= 0),
      'test PMX has no left-hand chain');
    InitializeBonePoses(Model, InputPoses);
    CalculateBoneTransforms(Model, InputPoses, BeforeTransforms);
    Session := TMmdSimplePoseEditSession.Create;
    try
      Check(Session.BeginEdit(Model, scLeftHand, InputPoses) and
        Session.ApplyViewStep(Model, scLeftHand, InputPoses,
          0.06, 0, 0, 0, 0, 0, Pi * 0.5, 0),
        'side-angle hand edit did not move');
      CalculateBoneTransforms(Model, InputPoses, AfterTransforms);
      Delta := SubtractVector(AfterTransforms[Wrist].Position,
        BeforeTransforms[Wrist].Position);
      ScreenRight := ScreenOffset(1, 0, Pi * 0.5, 0, 1);
      Check(DotVector(Delta, ScreenRight) > 0.001,
        'hand did not follow the displayed side view');
    finally
      Session.Free;
    end;
    InitializeBonePoses(Model, InputPoses);
    CalculateBoneTransforms(Model, InputPoses, BeforeTransforms);
    Session := TMmdSimplePoseEditSession.Create;
    try
      Check(Session.BeginEdit(Model, scLeftHand, InputPoses) and
        Session.ApplyViewStep(Model, scLeftHand, InputPoses,
          0.06, 0, 0, 0, 0, 0, 0, 0, RootAfter),
        'root-rotated hand edit did not move');
      CalculateBoneTransforms(Model, InputPoses, AfterTransforms);
      Delta := RotateVector(RootAfter,
        SubtractVector(AfterTransforms[Wrist].Position,
          BeforeTransforms[Wrist].Position));
      Check(Delta.X > 0.001,
        'hand did not follow the root-rotated screen direction');
    finally
      Session.Free;
    end;
    BodyIndex := UpperBone(Model);
    Check(BodyIndex >= 0, 'test PMX has no upper-body bone');
    BodyName := Model.Bones[BodyIndex].Name;
    ModelBaseValue := UTF8String('{"version":1,"bones":[' +
      '{"name":"' + BodyName + '","translation":[0,0,0],' +
      '"rotation":[0.247404,0,0,0.968912]}]}');
    Check(TryComposeTimelinePose(Model, UTF8ToString(ModelBaseValue),
      '', 0, FirstPose, BasePoses, CurrentPoses),
      'model standard pose was not composed');
    Check(Abs(CurrentPoses[BodyIndex].Rotation.X -
      BasePoses[BodyIndex].Rotation.X) < 0.00001,
      'empty Script pose changed the model standard pose');
    Session := TMmdSimplePoseEditSession.Create;
    try
      Check(Session.BeginEdit(Model, scUpperBody, CurrentPoses),
        'virtual upper-body stick edit did not start');
      Check(Session.ApplyViewStep(Model, scUpperBody, CurrentPoses,
        0, 0.07, 0, 0, 0, 0, 0, 0),
        'virtual upper-body stick edit did not move');
      Overlay := EncodeTimelinePoseOverlay(Model, BasePoses, CurrentPoses);
      Check(TryComposeTimelinePose(Model, UTF8ToString(ModelBaseValue),
        '', 0, Overlay, RebuiltBase, RebuiltPoses),
        'written Script pose could not be composed');
      Check(Abs(RebuiltPoses[BodyIndex].Rotation.X -
        CurrentPoses[BodyIndex].Rotation.X) < 0.00001,
        'Script roundtrip lost the virtual stick pose');
    finally
      Session.Free;
    end;
    MotionDocument := TMmdMotionDocument.Create;
    try
      MotionKey := Default(TMmdMotionBoneKey);
      MotionKey.Frame := 10;
      MotionKey.Rotation.X := 0.149438;
      MotionKey.Rotation.W := 0.988771;
      MotionKey.RotationCurve := LinearMmdBezierCurve;
      MotionDocument.BoneTracks.Add(
        TMmdMotionBoneTrack.Create(BodyName));
      MotionDocument.BoneTracks[0].Keys.Add(MotionKey);
      MotionDataText := EncodeMmdMotionDocument(MotionDocument);
      Check(TryComposeTimelinePose(Model, UTF8ToString(ModelBaseValue),
        MotionDataText, 10, FirstPose, BasePoses, CurrentPoses),
        'model motion base was not composed');
      Check(Abs(BasePoses[BodyIndex].Rotation.X - 0.149438) < 0.0001,
        'motion did not override the model standard pose');
      Check(EncodeTimelinePoseOverlay(Model, BasePoses,
        CurrentPoses) = FirstPose,
        'empty Script pose baked the motion into an override');
    finally
      MotionDocument.Free;
    end;
    MotionValue := UTF8String(MotionDataText);
    PoseValue := UTF8String(FirstPose);
    EscapeBackslashesOnWrite := True;
    SetLength(NamedPoses, 1);
    NamedPoses[0].BoneName := BodyName;
    NamedPoses[0].Pose := CurrentPoses[BodyIndex];
    EscapedPose := EncodePoseData(NamedPoses);
    PoseValue := UTF8String(StringReplace(EscapedPose, '\', '\\',
      [rfReplaceAll]));
    Check(TryReadSelectedMmdPose(Current) and
      (Current.PoseData = EscapedPose),
      'existing host-escaped pose was not normalized');
    Check(TryDecodePoseData(Current.PoseData, NamedPoses) and
      (Length(NamedPoses) = 1) and
      (NamedPoses[0].BoneName = BodyName),
      'existing host-escaped bone name was not restored');
    PoseValue := UTF8String(FirstPose);
    Check(TryReadSelectedMmdPose(Current) and
      (Current.MotionData = MotionDataText) and
      (Current.MotionFrame = 10),
      'selected pose did not read the referenced motion frame');
    FocusObject := SelectedObject;
    Form := TForm.CreateNew(nil);
    try
      Form.SetBounds(0, 0, 640, 480);
      Form.Show;
      Catalog := TPanel.Create(Form);
      Catalog.Parent := Form;
      Catalog.Align := alClient;
      Page := TMmdTimelinePosePageController.CreateForPage(Form,
        Form, Catalog);
      try
        Page.Activate;
        Check((Page.Editor <> nil) and Page.Editor.Bound and
          Page.Editor.Visible and not Catalog.Visible,
          'selected pose editor page was not shown');
        // 物理HIDを使わず、左スティック操作と250ms選択監視を交互に進める。
        Pad := Default(TMmdProPadState);
        Pad.POV := $FFFF;
        Page.Editor.ApplyControllerState(Pad, 1000);
        WritesBeforeStick := WriteCount;
        RecreateHandlesOnWrite := True;
        Pad.LeftY := 0.7;
        Page.Editor.ApplyControllerState(Pad, 1033);
        Page.Editor.ApplyControllerState(Pad, 1066);
        Check(WriteCount = WritesBeforeStick + 1,
          'virtual stick did not write the first pose');
        Check(Pos('\\u', UTF8ToString(PoseValue)) > 0,
          'fake host did not escape the stored JSON string');
        FirstWrittenPose := ReadCurrentPoseData;
        Check(Pos('\\u', FirstWrittenPose) = 0,
          'binding did not remove the host string escape');
        FirstRotationX := UpperBodyRotationX(FirstWrittenPose, BodyName);
        Check(FirstWrittenPose <> FirstPose,
          'virtual stick wrote the initial pose again');
        // 実ホストで書込直後の監視が旧値を返す場合も作業姿勢を捨てない。
        ReadPoseOverride := UTF8String(FirstPose);
        UseReadPoseOverride := True;
        Page.UpdateSelection;
        UseReadPoseOverride := False;
        Page.Editor.ApplyControllerState(Pad, 1099);
        Check((WriteCount = WritesBeforeStick + 2) and
          (ReadCurrentPoseData <> FirstWrittenPose),
          'selection poll reset the virtual stick edit');
        FirstWrittenPose := ReadCurrentPoseData;
        SecondRotationX := UpperBodyRotationX(FirstWrittenPose, BodyName);
        Page.Editor.ApplyControllerState(Pad, 1132);
        Check((WriteCount = WritesBeforeStick + 3) and
          (ReadCurrentPoseData <> FirstWrittenPose),
          'handle recreation stopped the next virtual stick input');
        ThirdRotationX := UpperBodyRotationX(ReadCurrentPoseData,
          BodyName);
        Check((Abs(SecondRotationX - 0.149438) >
          Abs(FirstRotationX - 0.149438)) and
          (Abs(ThirdRotationX - 0.149438) >
          Abs(SecondRotationX - 0.149438)),
          'virtual stick pose returned toward its initial state');
        HidePoseRead := True;
        Page.UpdateSelection;
        Check(Page.Editor.Bound and Page.Editor.Visible,
          'one transient read failure cleared the active pose edit');
        HidePoseRead := False;
        Page.UpdateSelection;
        Pad.LeftY := 0;
        Page.Editor.ApplyControllerState(Pad, 1165);
        Pad.RightX := 0.7;
        Page.Editor.ApplyControllerState(Pad, 1198);
        Check((Pos('relativeAngles', ReadCurrentPoseData) > 0) and
          (WriteCount = WritesBeforeStick + 4) and
          (AngleWriteCount = 0),
          'relative angle changed the model display object');
        Pad.RightX := 0;
        Page.Editor.ApplyControllerState(Pad, 1330);
        Check(WriteCount = WritesBeforeStick + 4,
          'neutral right stick repeated the angle write');
        RecreateHandlesOnWrite := False;
        IsPoseEffect := False;
        Page.UpdateSelection;
        Page.UpdateSelection;
        Check(Catalog.Visible and not Page.Editor.Visible,
          'catalog did not return after pose deselection');
      finally
        Page.Free;
      end;
    finally
      Form.Free;
    end;
  finally
    EditHandle := nil;
  end;
end;

begin
  try
    if ParamCount <> 1 then
      raise Exception.Create('PMX path is required');
    Application.Initialize;
    RunTests(ParamStr(1));
    Writeln('MmdTimelinePoseBindingTest: PASS');
  except
    on E: Exception do
    begin
      Writeln(E.ClassName + ': ' + E.Message);
      ExitCode := 1;
    end;
  end;
end.
