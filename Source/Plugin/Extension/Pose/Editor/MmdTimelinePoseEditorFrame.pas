unit MmdTimelinePoseEditorFrame;

// 拡張ページにプレビューを持たず、選択中Scriptオブジェクトの姿勢を編集する。

interface

uses
  System.Classes,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.Forms,
  Vcl.StdCtrls,
  DarkLabel,
  DarkPanel,
  MmdPoseEditSession,
  MmdPoseEditorTools,
  MmdPoseHistory,
  MmdProControllerInput,
  MmdSimpleControllerPanel,
  MmdSimpleControllerSolver,
  MmdSimplePoseEditSession,
  MmdTimelinePoseBinding,
  MmdTimelinePoseComposite,
  MmdTimelinePoseControllerDriver,
  PmxModel,
  PmxPose;

type
  TFrameMmdTimelinePoseEditor = class(TFrame)
  private
    FBound: Boolean;
    FDriver: TMmdTimelinePoseControllerDriver;
    FEditSession: TMmdPoseEditSession;
    FInput: TMmdProControllerInput;
    FBasePoses: TPmxBonePoses;
    FBaseRootRotation: TPmxQuaternion;
    FBaseYaw, FBasePitch: Single;
    FModel: TPmxModel;
    FPoses: TPmxBonePoses;
    FRootRotation: TPmxQuaternion;
    FRelativeYaw, FRelativePitch: Single;
    FRelativeBeforeYaw, FRelativeBeforePitch: Single;
    FRelativeAnglePending: Boolean;
    FRelativeAwaitNeutral: Boolean;
    FRelativePreviousButtons: Cardinal;
    FRootBeforeRotation: TPmxQuaternion;
    FRootMode: Boolean;
    FRootPending: Boolean;
    FRootAwaitNeutral: Boolean;
    FRootLastTick: UInt64;
    FRootPreviousButtons: Cardinal;
    FRootButton: TButton;
    FSimplePanel: TMmdSimpleControllerPanel;
    FSimpleSession: TMmdSimplePoseEditSession;
    FSnapshot: TMmdTimelinePoseSnapshot;
    FStatusPanel: TDarkPanel;
    FStatusText: TDarkLabel;
    FTimer: TTimer;
    FTraceWriteCount: Integer;
{$IFDEF DEBUG}
    FLastAngleInputLogTick: UInt64;
    FLastAngleInputActive: Boolean;
{$ENDIF}
    FTools: TMmdPoseEditorTools;
    procedure GamepadTick(Sender: TObject);
    procedure RedoClick(Sender: TObject);
    procedure ResetAllClick(Sender: TObject);
    procedure RootModeClick(Sender: TObject);
    procedure CommitRootPending;
    procedure CancelRootPending;
    procedure CommitRelativeAnglePending;
    procedure CancelRelativeAnglePending;
    procedure ApplyRootControllerState(const State: TMmdProPadState;
      NowTick: UInt64);
    procedure UndoClick(Sender: TObject);
    procedure UpdateHistoryButtons;
    function WriteCurrentPose: Boolean;
    function WriteRelativeAngles(YawDegrees,
      PitchDegrees: Single): Boolean;
    function CurrentRootRotation: TPmxQuaternion;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // 親ページへ接続後にVCLコントロールを構築する。
    procedure InitializeControls;
    // 外部変更または別オブジェクトの選択時に、編集状態を読み直す。
    procedure BindSnapshot(const Snapshot: TMmdTimelinePoseSnapshot);
    // ページ非表示・選択解除時に入力デバイスと編集中状態を解放する。
    procedure ClearTarget;
    // HID入力と同じ処理へ仮想パッド状態を流す。同期を含む回帰検証にも使う。
    procedure ApplyControllerState(const State: TMmdProPadState;
      NowTick: UInt64);
    property Bound: Boolean read FBound;
    property RelativeAnglePending: Boolean read FRelativeAnglePending;
  end;

implementation

uses
  Winapi.Windows,
  System.IOUtils,
  System.SysUtils,
  Vcl.ComCtrls,
  Vcl.Graphics,
  System.Math,
  MmdSimpleControllerView,
  MmdTimelinePoseDebugLog,
  MmdTimelinePoseSyncTrace,
  MmdPoseEditorTheme,
  PmxReader,
  PmxPoseMath;

{$R *.dfm}

constructor TFrameMmdTimelinePoseEditor.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Color := MmdEditorBackground;
  ParentBackground := False;
  FEditSession := TMmdPoseEditSession.Create;
  FSimpleSession := TMmdSimplePoseEditSession.Create;
  FInput := TMmdProControllerInput.Create;
  FDriver := TMmdTimelinePoseControllerDriver.Create(WriteCurrentPose,
    UpdateHistoryButtons, WriteRelativeAngles, CurrentRootRotation);
  FRootRotation := IdentityQuaternion;
  FBaseRootRotation := IdentityQuaternion;
end;

procedure TFrameMmdTimelinePoseEditor.InitializeControls;
begin
  if FTools <> nil then Exit;
  FTools := TMmdPoseEditorTools.CreateForParents(Self, Self, Self,
    alClient, False);
  FTools.UpdateDpi(CurrentPPI);
  FTools.BoneList.Visible := False;
  FTools.MorphPreview.Visible := False;
  FTools.ResetBoneButton.Visible := False;
  FTools.ResetBranchButton.Visible := False;
  FTools.SymmetryButton.Visible := False;
  // 非表示ボタンが多い同期画面では自動サイズが操作バーを縮めるため、
  // アイコンとボタンを含む高さを現在のDPIで明示する。
  FTools.CommandToolbar.AutoSize := False;
  FTools.CommandToolbar.ButtonWidth := MulDiv(30, CurrentPPI, 96);
  FTools.CommandToolbar.ButtonHeight := MulDiv(30, CurrentPPI, 96);
  FTools.CommandToolbar.Height := MulDiv(32, CurrentPPI, 96);
  FTools.UndoButton.OnClick := UndoClick;
  FTools.RedoButton.OnClick := RedoClick;
  FTools.ResetAllButton.OnClick := ResetAllClick;

  FSimplePanel := TMmdSimpleControllerPanel.Create(Self);
  FSimplePanel.Parent := FTools.LeftPanel;
  FSimplePanel.Align := alClient;
  FSimplePanel.ApplyLayout;

  FStatusPanel := TDarkPanel.Create(Self);
  FStatusPanel.Parent := Self;
  FStatusPanel.Align := alBottom;
  FStatusPanel.Height := MulDiv(32, CurrentPPI, 96);
  FStatusPanel.BevelOuter := bvNone;
  FStatusPanel.Color := MmdEditorPanel;
  FStatusPanel.Padding.Left := MulDiv(6, CurrentPPI, 96);
  FStatusText := TDarkLabel.Create(Self);
  FStatusText.Parent := FStatusPanel;
  FStatusText.AutoSize := False;
  FStatusText.Align := alClient;
  FStatusText.Layout := tlCenter;
  FStatusText.ApplyDpi;
  FStatusText.ShowHint := True;
  FStatusText.Hint := '左スティック: 部位操作 / 十字キー上下: 部位選択 / A: 確定 / B: 取消 / Y: 初期化';
  FStatusText.Caption := 'MMDポーズオブジェクトを選択してください';

  FRootButton := TButton.Create(Self);
  FRootButton.Parent := FStatusPanel;
  FRootButton.ParentFont := False;
  FRootButton.Font.Height := FStatusText.Font.Height;
  FRootButton.Align := alRight;
  FRootButton.Width := MulDiv(132, CurrentPPI, 96);
  FRootButton.Caption := '全身回転: OFF';
  FRootButton.OnClick := RootModeClick;

  FTimer := TTimer.Create(Self);
  FTimer.Enabled := False;
  FTimer.Interval := 33;
  FTimer.OnTimer := GamepadTick;
  UpdateHistoryButtons;
end;

destructor TFrameMmdTimelinePoseEditor.Destroy;
begin
  if FTimer <> nil then FTimer.Enabled := False;
  FInput.Free;
  FDriver.Free;
  FSimpleSession.Free;
  FEditSession.Free;
  inherited;
end;

procedure TFrameMmdTimelinePoseEditor.ClearTarget;
begin
  {$IFDEF DEBUG}
  PoseDebugLog('editor.clear', 'bound=' + BoolToStr(FBound, True) +
    ' pending=' + BoolToStr(FDriver.Pending, True));
  {$ENDIF}
  if FBound then TracePoseSync('clear', FSnapshot,
    Default(TMmdTimelinePoseSnapshot));
  FTimer.Enabled := False;
  FInput.Disconnect;
  FSimpleSession.Cancel(FPoses);
  FDriver.Reset;
  FRootMode := False;
  FRootPending := False;
  FRootAwaitNeutral := True;
  FRootLastTick := 0;
  FRootPreviousButtons := 0;
  FRelativeAnglePending := False;
  FRelativeAwaitNeutral := True;
  FRelativePreviousButtons := 0;
  {$IFDEF DEBUG}
  FLastAngleInputActive := False;
  FLastAngleInputLogTick := 0;
  {$ENDIF}
  FRelativeYaw := 0;
  FRelativePitch := 0;
  FBaseYaw := 0;
  FBasePitch := 0;
  FRootRotation := IdentityQuaternion;
  FBaseRootRotation := IdentityQuaternion;
  if FRootButton <> nil then FRootButton.Caption := '全身回転: OFF';
  FBound := False;
  FModel := nil;
  FBasePoses := nil;
  FPoses := nil;
  FSnapshot := Default(TMmdTimelinePoseSnapshot);
  FStatusText.Caption := 'MMDポーズオブジェクトを選択してください';
  UpdateHistoryButtons;
end;

procedure TFrameMmdTimelinePoseEditor.BindSnapshot(
  const Snapshot: TMmdTimelinePoseSnapshot);
begin
  {$IFDEF DEBUG}
  if (not FBound) or (Snapshot.PoseData <> FSnapshot.PoseData) or
    (Snapshot.StandardPoseData <> FSnapshot.StandardPoseData) or
    (Snapshot.MotionData <> FSnapshot.MotionData) or
    (Snapshot.MotionFrame <> FSnapshot.MotionFrame) then
    PoseDebugLog('editor.bind_check',
      'bound=' + BoolToStr(FBound, True) +
      ' pending=' + BoolToStr(FDriver.Pending, True) +
      ' obj=' + IntToHex(Snapshot.ObjectId, 16) +
      ' pose_equal=' + BoolToStr(Snapshot.PoseData = FSnapshot.PoseData, True) +
      ' base_equal=' + BoolToStr(Snapshot.StandardPoseData =
        FSnapshot.StandardPoseData, True) +
      ' motion_equal=' + BoolToStr(Snapshot.MotionData =
        FSnapshot.MotionData, True) +
      ' motion_frame=' + IntToStr(Snapshot.MotionFrame) + '/' +
        IntToStr(FSnapshot.MotionFrame));
  {$ENDIF}
  if FBound and (Snapshot.Layer = FSnapshot.Layer) and
    (Snapshot.StartFrame = FSnapshot.StartFrame) and
    (Snapshot.EndFrame = FSnapshot.EndFrame) and
    (Snapshot.ModelFile = FSnapshot.ModelFile) and
    (FDriver.Pending or FRootPending or FRelativeAnglePending or
      ((Snapshot.StandardPoseData = FSnapshot.StandardPoseData) and
       (Snapshot.MotionData = FSnapshot.MotionData) and
       (Snapshot.MotionFrame = FSnapshot.MotionFrame) and
       (Snapshot.PoseData = FSnapshot.PoseData))) then
  begin
    FSnapshot.ObjectId := Snapshot.ObjectId;
    FSnapshot.BaseModelObjectId := Snapshot.BaseModelObjectId;
    Exit;
  end;
  if FBound then TracePoseSync('rebind', FSnapshot, Snapshot)
  else TracePoseSync('bind', FSnapshot, Snapshot);
  {$IFDEF DEBUG}
  PoseDebugLog('editor.rebind', 'pending=' + BoolToStr(FDriver.Pending, True));
  PoseDebugTextPair('editor.rebind_pose', FSnapshot.PoseData,
    Snapshot.PoseData);
  {$ENDIF}
  FTraceWriteCount := 0;
  FSimpleSession.Cancel(FPoses);
  FRootPending := False;
  FRootAwaitNeutral := True;
  FRootLastTick := 0;
  FRootPreviousButtons := 0;
  FRelativeAnglePending := False;
  FRelativeAwaitNeutral := True;
  FRelativePreviousButtons := 0;
  {$IFDEF DEBUG}
  FLastAngleInputActive := False;
  FLastAngleInputLogTick := 0;
  {$ENDIF}
  FDriver.Reset;
  FBound := False;
  FSnapshot := Snapshot;
  FTimer.Enabled := False;
  if not TFile.Exists(Snapshot.ModelFile) then
  begin
    FStatusText.Caption := 'PMXファイルが見つかりません';
    UpdateHistoryButtons;
    Exit;
  end;
  try
    FModel := GetCachedPmxModel(Snapshot.ModelFile);
    FEditSession.Load(FModel, Snapshot.PoseData, FPoses);
    if not TryComposeTimelinePose(FModel,
      Snapshot.StandardPoseData, Snapshot.MotionData,
      Snapshot.MotionFrame, Snapshot.PoseData,
      FBasePoses, FPoses, FBaseRootRotation, FRootRotation,
      FBaseYaw, FBasePitch, FRelativeYaw, FRelativePitch) then
      raise EArgumentException.Create('モデルとポーズの基準姿勢を復元できません');
    FSimplePanel.SetModel(FModel);
    FDriver.Configure(FModel, FSimplePanel, FSimpleSession, FEditSession,
      FStatusText);
    FDriver.SetViewAngles(FRelativeYaw, FRelativePitch);
    FBound := True;
    FStatusText.Caption := 'Pro: 接続待ち';
    FTimer.Enabled := True;
  except
    on E: Exception do
    begin
      FModel := nil;
      FStatusText.Caption := 'PMX読込失敗: ' + E.Message;
    end;
  end;
  UpdateHistoryButtons;
end;

function TFrameMmdTimelinePoseEditor.WriteRelativeAngles(
  YawDegrees, PitchDegrees: Single): Boolean;
begin
  if not FBound then Exit(False);
  if FRelativeAwaitNeutral then Exit(False);
  if (Abs(FRelativeYaw - YawDegrees) < 0.0001) and
     (Abs(FRelativePitch - PitchDegrees) < 0.0001) then Exit(True);
  if not FRelativeAnglePending then
  begin
    FDriver.CommitPending;
    CommitRootPending;
    FRelativeBeforeYaw := FRelativeYaw;
    FRelativeBeforePitch := FRelativePitch;
    FRelativeAnglePending := True;
  end;
  FRelativeYaw := YawDegrees;
  FRelativePitch := PitchDegrees;
  Result := WriteCurrentPose;
end;

function TFrameMmdTimelinePoseEditor.CurrentRootRotation: TPmxQuaternion;
begin
  Result := FRootRotation;
end;

procedure TFrameMmdTimelinePoseEditor.CommitRelativeAnglePending;
begin
  if not FRelativeAnglePending then Exit;
  FEditSession.History.RecordBeforeEdit(FPoses, FRootRotation,
    FRelativeBeforeYaw, FRelativeBeforePitch);
  FRelativeAnglePending := False;
  FRelativeAwaitNeutral := True;
  UpdateHistoryButtons;
end;

procedure TFrameMmdTimelinePoseEditor.CancelRelativeAnglePending;
begin
  if not FRelativeAnglePending then Exit;
  FRelativeYaw := FRelativeBeforeYaw;
  FRelativePitch := FRelativeBeforePitch;
  FRelativeAnglePending := False;
  FRelativeAwaitNeutral := True;
  FDriver.SetViewAngles(FRelativeYaw, FRelativePitch);
  WriteCurrentPose;
  UpdateHistoryButtons;
end;

procedure TFrameMmdTimelinePoseEditor.CommitRootPending;
begin
  if not FRootPending then Exit;
  FEditSession.History.RecordBeforeEdit(FPoses, FRootBeforeRotation,
    FRelativeYaw, FRelativePitch);
  FRootPending := False;
  FRootAwaitNeutral := True;
  UpdateHistoryButtons;
end;

procedure TFrameMmdTimelinePoseEditor.CancelRootPending;
begin
  if not FRootPending then Exit;
  FRootRotation := FRootBeforeRotation;
  FRootPending := False;
  FRootAwaitNeutral := True;
  WriteCurrentPose;
  UpdateHistoryButtons;
end;

procedure TFrameMmdTimelinePoseEditor.RootModeClick(Sender: TObject);
begin
  if not FBound then Exit;
  FDriver.CommitPending;
  CommitRelativeAnglePending;
  CommitRootPending;
  FRootMode := not FRootMode;
  FRootAwaitNeutral := True;
  FRootLastTick := 0;
  FRootPreviousButtons := 0;
  if FRootMode then
  begin
    FRootButton.Caption := '全身回転: ON';
    FStatusText.Caption := '左スティック: 全身回転 / A確定 / B取消 / Y初期化';
  end
  else
  begin
    FRootButton.Caption := '全身回転: OFF';
    FStatusText.Caption := 'Pro: 接続中';
  end;
end;

procedure TFrameMmdTimelinePoseEditor.ApplyRootControllerState(
  const State: TMmdProPadState; NowTick: UInt64);
var
  DeltaYaw, DeltaPitch, Factor, Rate: Single;
  Filtered: TMmdProPadState;
  PitchRotation, YawRotation: TPmxQuaternion;
begin
  // 右スティックの表示アングル更新は通常モードと共用する。
  Filtered := State;
  Filtered.LeftX := 0;
  Filtered.LeftY := 0;
  Filtered.POV := $FFFF;
  Filtered.Buttons := Filtered.Buttons and not
    ((Cardinal(1) shl (ProButtonA - 1)) or
     (Cardinal(1) shl (ProButtonB - 1)) or
     (Cardinal(1) shl (ProButtonY - 1)));
  FDriver.Apply(Filtered, NowTick, FPoses);
  if State.Down(ProButtonB) and
    ((FRootPreviousButtons and (Cardinal(1) shl (ProButtonB - 1))) = 0) then
    CancelRootPending
  else if State.Down(ProButtonA) and
    ((FRootPreviousButtons and (Cardinal(1) shl (ProButtonA - 1))) = 0) then
    CommitRootPending
  else if State.Down(ProButtonY) and
    ((FRootPreviousButtons and (Cardinal(1) shl (ProButtonY - 1))) = 0) then
  begin
    CommitRootPending;
    FEditSession.History.RecordBeforeEdit(FPoses, FRootRotation,
      FRelativeYaw, FRelativePitch);
    FRootRotation := FBaseRootRotation;
    WriteCurrentPose;
    UpdateHistoryButtons;
  end
  else if (Abs(State.LeftX) <= 0.005) and
    (Abs(State.LeftY) <= 0.005) then
    FRootAwaitNeutral := False
  else if not FRootAwaitNeutral then
  begin
    if FRootLastTick = 0 then Factor := 1
    else Factor := EnsureRange((NowTick - FRootLastTick) / 33.0, 0.5, 3.0);
    Rate := 0.04 * Factor;
    if State.Down(ProButtonL) then Rate := Rate * 0.2;
    DeltaYaw := State.LeftX * Rate;
    DeltaPitch := -State.LeftY * Rate;
    if not FRootPending then
    begin
      FRootBeforeRotation := FRootRotation;
      FRootPending := True;
    end;
    YawRotation := QuaternionFromAxisAngle(ScreenOffset(0, 1,
      FDriver.ViewYaw, FDriver.ViewPitch, 1), DeltaYaw);
    PitchRotation := QuaternionFromAxisAngle(ScreenOffset(1, 0,
      FDriver.ViewYaw, FDriver.ViewPitch, 1), DeltaPitch);
    FRootRotation := NormalizeQuaternion(MultiplyQuaternion(PitchRotation,
      MultiplyQuaternion(YawRotation, FRootRotation)));
    WriteCurrentPose;
    FStatusText.Caption := '全身回転中: A確定 / B取消';
  end;
  FRootLastTick := NowTick;
  FRootPreviousButtons := State.Buttons;
  if not FRootPending then
    FStatusText.Caption := '左スティック: 全身回転 / A確定 / B取消 / Y初期化';
end;

function TFrameMmdTimelinePoseEditor.WriteCurrentPose: Boolean;
var
  Actual: TMmdTimelinePoseSnapshot;
  Updated: TMmdTimelinePoseSnapshot;
  NewPoseData: string;
{$IFDEF DEBUG}
  PreviousTraceId: Integer;
{$ENDIF}
begin
  if not FBound then Exit(False);
  NewPoseData := EncodeTimelinePoseOverlay(FModel, FBasePoses, FPoses,
    FBaseRootRotation, FRootRotation, FBaseYaw, FBasePitch,
    FRelativeYaw, FRelativePitch);
  {$IFDEF DEBUG}
  PreviousTraceId := PoseTraceId;
  PoseTraceId := NextPoseTraceId;
  try
    PoseDebugLog('editor.write_start',
      'obj=' + IntToHex(FSnapshot.ObjectId, 16) +
      ' pending=' + BoolToStr(FDriver.Pending, True) +
      ' angle_pending=' + BoolToStr(FRelativeAnglePending, True) +
      ' controller=' + IntToStr(Ord(FDriver.Controller)) +
      ' yaw=' + FloatToStr(FRelativeYaw, TFormatSettings.Invariant) +
      ' pitch=' + FloatToStr(FRelativePitch,
        TFormatSettings.Invariant) +
      ' pose_changed=' + BoolToStr(NewPoseData <> FSnapshot.PoseData,
        True) + ' chars=' + IntToStr(Length(NewPoseData)));
  {$ENDIF}
  Result := TryWriteSelectedMmdPose(FSnapshot, NewPoseData, Updated);
  if Result then
  begin
    if FTraceWriteCount < 20 then
      TracePoseSync('write', FSnapshot, Updated);
    Inc(FTraceWriteCount);
    {$IFDEF DEBUG}
    PoseDebugLog('editor.write_ok',
      'obj=' + IntToHex(Updated.ObjectId, 16));
    {$ENDIF}
    FSnapshot := Updated;
  end
  else
  begin
    Actual := Default(TMmdTimelinePoseSnapshot);
    TryReadSelectedMmdPose(Actual);
    TracePoseSync('write_failed', FSnapshot, Actual);
    {$IFDEF DEBUG}
    PoseDebugLog('editor.write_failed',
      'actual_obj=' + IntToHex(Actual.ObjectId, 16));
    PoseDebugTextPair('editor.failed_pose', FSnapshot.PoseData,
      Actual.PoseData);
    {$ENDIF}
    FBound := False;
    FTimer.Enabled := False;
    FInput.Disconnect;
    FStatusText.Caption := '選択オブジェクトが変更されました';
  end;
  {$IFDEF DEBUG}
  finally
    PoseTraceId := PreviousTraceId;
  end;
  {$ENDIF}
end;

procedure TFrameMmdTimelinePoseEditor.UpdateHistoryButtons;
begin
  FTools.UndoButton.Enabled := FBound and FEditSession.History.CanUndo;
  FTools.RedoButton.Enabled := FBound and FEditSession.History.CanRedo;
  FTools.ResetAllButton.Enabled := FBound;
  if FRootButton <> nil then FRootButton.Enabled := FBound;
end;

procedure TFrameMmdTimelinePoseEditor.UndoClick(Sender: TObject);
var
  Restored: TPmxBonePoses;
  RestoredRoot: TPmxQuaternion;
  RestoredYaw, RestoredPitch: Single;
begin
  if not FBound then Exit;
  FDriver.CommitPending;
  CommitRelativeAnglePending;
  CommitRootPending;
  if FEditSession.History.Undo(FPoses, FRootRotation, FRelativeYaw,
    FRelativePitch, Restored, RestoredRoot, RestoredYaw,
    RestoredPitch) then
  begin
    FPoses := Restored;
    FRootRotation := RestoredRoot;
    FRelativeYaw := RestoredYaw;
    FRelativePitch := RestoredPitch;
    FDriver.SetViewAngles(FRelativeYaw, FRelativePitch);
    WriteCurrentPose;
  end;
  UpdateHistoryButtons;
end;

procedure TFrameMmdTimelinePoseEditor.RedoClick(Sender: TObject);
var
  Restored: TPmxBonePoses;
  RestoredRoot: TPmxQuaternion;
  RestoredYaw, RestoredPitch: Single;
begin
  if not FBound then Exit;
  FDriver.CommitPending;
  CommitRelativeAnglePending;
  CommitRootPending;
  if FEditSession.History.Redo(FPoses, FRootRotation, FRelativeYaw,
    FRelativePitch, Restored, RestoredRoot, RestoredYaw,
    RestoredPitch) then
  begin
    FPoses := Restored;
    FRootRotation := RestoredRoot;
    FRelativeYaw := RestoredYaw;
    FRelativePitch := RestoredPitch;
    FDriver.SetViewAngles(FRelativeYaw, FRelativePitch);
    WriteCurrentPose;
  end;
  UpdateHistoryButtons;
end;

procedure TFrameMmdTimelinePoseEditor.ResetAllClick(Sender: TObject);
begin
  if not FBound then Exit;
  FDriver.CommitPending;
  CommitRelativeAnglePending;
  CommitRootPending;
  FEditSession.History.RecordBeforeEdit(FPoses, FRootRotation,
    FRelativeYaw, FRelativePitch);
  FPoses := Copy(FBasePoses);
  FRootRotation := FBaseRootRotation;
  FRelativeYaw := FBaseYaw;
  FRelativePitch := FBasePitch;
  FDriver.SetViewAngles(FRelativeYaw, FRelativePitch);
  WriteCurrentPose;
  UpdateHistoryButtons;
end;

procedure TFrameMmdTimelinePoseEditor.GamepadTick(Sender: TObject);
var
  State: TMmdProPadState;
begin
  if not FBound or not Visible then Exit;
  FTimer.Enabled := False;
  try
    try
      if not FInput.Poll(State) then
      begin
        if not FInput.Connected then
        begin
          FStatusText.Caption := 'Pro: 接続待ち';
          FInput.ProbeConnection;
        end;
        FDriver.ResetInput;
        Exit;
      end;
      ApplyControllerState(State, GetTickCount64);
    except
      on E: Exception do
      begin
        {$IFDEF DEBUG}
        PoseDebugLog('editor.poll_exception', E.ClassName + ': ' + E.Message);
        {$ENDIF}
        FStatusText.Caption := '編集エラー: ' + E.Message;
      end;
    end;
  finally
    FTimer.Enabled := FBound;
  end;
end;

procedure TFrameMmdTimelinePoseEditor.ApplyControllerState(
  const State: TMmdProPadState; NowTick: UInt64);
{$IFDEF DEBUG}
var
  AngleActive: Boolean;
{$ENDIF}
begin
  if not FBound then Exit;
  {$IFDEF DEBUG}
  AngleActive := (Abs(State.RightX) > 0.005) or
    (Abs(State.RightY) > 0.005);
  if (AngleActive <> FLastAngleInputActive) or
    (AngleActive and (NowTick - FLastAngleInputLogTick >= 500)) then
  begin
    PoseDebugLog('editor.angle_input',
      'active=' + BoolToStr(AngleActive, True) +
      ' x=' + FloatToStr(State.RightX, TFormatSettings.Invariant) +
      ' y=' + FloatToStr(State.RightY, TFormatSettings.Invariant) +
      ' pending=' + BoolToStr(FRelativeAnglePending, True));
    FLastAngleInputLogTick := NowTick;
    FLastAngleInputActive := AngleActive;
  end;
  {$ENDIF}
  if (Abs(State.RightX) <= 0.005) and
    (Abs(State.RightY) <= 0.005) then
    FRelativeAwaitNeutral := False;
  if FRootMode then ApplyRootControllerState(State, NowTick)
  else FDriver.Apply(State, NowTick, FPoses);
  if State.Down(ProButtonB) and
    ((FRelativePreviousButtons and
      (Cardinal(1) shl (ProButtonB - 1))) = 0) then
    CancelRelativeAnglePending
  else if State.Down(ProButtonA) and
    ((FRelativePreviousButtons and
      (Cardinal(1) shl (ProButtonA - 1))) = 0) then
    CommitRelativeAnglePending;
  FRelativePreviousButtons := State.Buttons;
  if FRelativeAnglePending and not FRootPending then
    FStatusText.Caption := '相対アングル編集中: A確定 / B取消';
end;

end.
