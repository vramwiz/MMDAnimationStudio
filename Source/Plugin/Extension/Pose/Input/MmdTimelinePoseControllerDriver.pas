unit MmdTimelinePoseControllerDriver;

// Proコントローラーの入力を、選択中の部位編集と履歴操作へ変換する。

interface

uses
  DarkLabel,
  MmdPoseEditSession,
  MmdProControllerInput,
  MmdSimpleControllerPanel,
  MmdSimpleControllerSolver,
  MmdSimplePoseEditSession,
  PmxModel,
  PmxPose;

type
  TMmdPoseWriteEvent = function: Boolean of object;
  TMmdPoseHistoryEvent = procedure of object;
  TMmdPoseAngleWriteEvent = function(YawDegrees,
    PitchDegrees: Single): Boolean of object;
  TMmdRootRotationReadEvent = function: TPmxQuaternion of object;

  TMmdTimelinePoseControllerDriver = class
  private
    FController: TMmdSimpleController;
    FEditSession: TMmdPoseEditSession;
    FGamepadAwaitNeutral: Boolean;
    FLastTick: UInt64;
    FModel: TPmxModel;
    FOnHistoryChanged: TMmdPoseHistoryEvent;
    FOnWritePose: TMmdPoseWriteEvent;
    FOnWriteRelativeAngle: TMmdPoseAngleWriteEvent;
    FOnReadRootRotation: TMmdRootRotationReadEvent;
    FPanel: TMmdSimpleControllerPanel;
    FPending: Boolean;
    FPreviousButtons, FPreviousPOV: Cardinal;
    FSession: TMmdSimplePoseEditSession;
    FStatusText: TDarkLabel;
    FViewYaw, FViewPitch: Single;
    function ButtonPressed(const State: TMmdProPadState; ButtonNumber: Integer): Boolean;
  public
    // 編集画面の書き戻しと履歴表示処理を受け取る。
    constructor Create(AOnWritePose: TMmdPoseWriteEvent;
      AOnHistoryChanged: TMmdPoseHistoryEvent;
      AOnWriteRelativeAngle: TMmdPoseAngleWriteEvent;
      AOnReadRootRotation: TMmdRootRotationReadEvent);
    // モデルと入力先を接続する。再選択時には新しいモデルで呼び直す。
    procedure Configure(AModel: TPmxModel; APanel: TMmdSimpleControllerPanel;
      ASession: TMmdSimplePoseEditSession; AEditSession: TMmdPoseEditSession;
      AStatusText: TDarkLabel);
    // ポーズの相対アングルを入力方向の基準にする。値は度数。
    procedure SetViewAngles(YawDegrees, PitchDegrees: Single);
    // 別オブジェクトへ切り替える際に、前の入力状態を消す。
    procedure Reset;
    // HIDの読取失敗時に押下履歴と経過時間を消す。
    procedure ResetInput;
    // 保留中の編集を履歴へ確定し、スティックが中立に戻るまで次の編集を待つ。
    procedure CommitPending;
    // 保留中の編集を取り消し、取り消し後の姿勢をホストへ書き戻す。
    procedure CancelPending(var Poses: TPmxBonePoses);
    // パッド状態を部位選択と姿勢変化へ反映し、変更時にホストへ書き戻す。
    procedure Apply(const State: TMmdProPadState; NowTick: UInt64;
      var Poses: TPmxBonePoses);
    property Controller: TMmdSimpleController read FController;
    property Pending: Boolean read FPending;
    property ViewYaw: Single read FViewYaw;
    property ViewPitch: Single read FViewPitch;
  end;

implementation

uses
  System.Math,
  System.SysUtils,
  MmdTimelinePoseDebugLog;

constructor TMmdTimelinePoseControllerDriver.Create(
  AOnWritePose: TMmdPoseWriteEvent; AOnHistoryChanged: TMmdPoseHistoryEvent;
  AOnWriteRelativeAngle: TMmdPoseAngleWriteEvent;
  AOnReadRootRotation: TMmdRootRotationReadEvent);
begin
  inherited Create;
  FOnWritePose := AOnWritePose;
  FOnHistoryChanged := AOnHistoryChanged;
  FOnWriteRelativeAngle := AOnWriteRelativeAngle;
  FOnReadRootRotation := AOnReadRootRotation;
  Reset;
end;

procedure TMmdTimelinePoseControllerDriver.SetViewAngles(
  YawDegrees, PitchDegrees: Single);
begin
  FViewYaw := DegToRad(YawDegrees);
  FViewPitch := DegToRad(PitchDegrees);
end;

procedure TMmdTimelinePoseControllerDriver.Configure(AModel: TPmxModel;
  APanel: TMmdSimpleControllerPanel; ASession: TMmdSimplePoseEditSession;
  AEditSession: TMmdPoseEditSession; AStatusText: TDarkLabel);
begin
  FModel := AModel;
  FPanel := APanel;
  FSession := ASession;
  FEditSession := AEditSession;
  FStatusText := AStatusText;
end;

procedure TMmdTimelinePoseControllerDriver.Reset;
begin
  FPending := False;
  FController := Low(TMmdSimpleController);
  FGamepadAwaitNeutral := True;
  ResetInput;
end;

procedure TMmdTimelinePoseControllerDriver.ResetInput;
begin
  FLastTick := 0;
  FPreviousButtons := 0;
  FPreviousPOV := $FFFF;
end;

function TMmdTimelinePoseControllerDriver.ButtonPressed(
  const State: TMmdProPadState; ButtonNumber: Integer): Boolean;
begin
  Result := State.Down(ButtonNumber) and
    ((FPreviousButtons and (Cardinal(1) shl (ButtonNumber - 1))) = 0);
end;

procedure TMmdTimelinePoseControllerDriver.CommitPending;
begin
  if not FPending then Exit;
  FSession.Commit(FEditSession.History, FOnReadRootRotation(),
    RadToDeg(FViewYaw), RadToDeg(FViewPitch));
  FPending := False;
  FGamepadAwaitNeutral := True;
  FOnHistoryChanged;
end;

procedure TMmdTimelinePoseControllerDriver.CancelPending(
  var Poses: TPmxBonePoses);
begin
  if not FPending then Exit;
  FSession.Cancel(Poses);
  FPending := False;
  FGamepadAwaitNeutral := True;
  FOnWritePose;
  FOnHistoryChanged;
end;

procedure TMmdTimelinePoseControllerDriver.Apply(
  const State: TMmdProPadState; NowTick: UInt64; var Poses: TPmxBonePoses);
var
  Bend, Factor, Rate, TipPitch, Twist, X, Y, Z: Single;
  NewYaw, NewPitch: Single;
begin
  if FModel = nil then Exit;
  {$IFDEF DEBUG}
  if (Abs(State.LeftX) > 0.005) or (Abs(State.LeftY) > 0.005) or
    (State.Buttons <> FPreviousButtons) or (State.POV <> FPreviousPOV) then
    PoseDebugLog('editor.pad',
      'tick=' + UIntToStr(NowTick) +
      ' x=' + FloatToStr(State.LeftX, TFormatSettings.Invariant) +
      ' y=' + FloatToStr(State.LeftY, TFormatSettings.Invariant) +
      ' buttons=' + IntToHex(State.Buttons, 8) +
      ' pov=' + IntToStr(State.POV) +
      ' pending=' + BoolToStr(FPending, True) +
      ' neutral_wait=' + BoolToStr(FGamepadAwaitNeutral, True) +
      ' controller=' + IntToStr(Ord(FPanel.SelectedController)));
  {$ENDIF}
  if FLastTick = 0 then Factor := 1
  else Factor := EnsureRange((NowTick - FLastTick) / 33.0, 0.5, 3.0);
  FLastTick := NowTick;
  if not State.Down(ProButtonR) and
    ((Abs(State.RightX) > 0.005) or (Abs(State.RightY) > 0.005)) and
    Assigned(FOnWriteRelativeAngle) then
  begin
    NewYaw := FViewYaw + State.RightX * Factor * 0.05;
    if NewYaw > Pi then NewYaw := NewYaw - 2 * Pi;
    if NewYaw < -Pi then NewYaw := NewYaw + 2 * Pi;
    NewPitch := EnsureRange(FViewPitch - State.RightY * Factor * 0.05,
      DegToRad(-89), DegToRad(89));
    if FOnWriteRelativeAngle(RadToDeg(NewYaw), RadToDeg(NewPitch)) then
    begin
      FViewYaw := NewYaw;
      FViewPitch := NewPitch;
    end;
  end;
  if FPending then FStatusText.Caption := 'A確定 / B取消'
  else FStatusText.Caption := 'Pro: 接続中';
  if (State.POV <> FPreviousPOV) and
    ((State.POV = 0) or (State.POV = 18000)) then
  begin
    CommitPending;
    FPanel.Navigate(State.POV);
    FGamepadAwaitNeutral := True;
    FPreviousButtons := State.Buttons;
    FPreviousPOV := State.POV;
    Exit;
  end;
  if (State.POV <> FPreviousPOV) and
    ((State.POV = 9000) or (State.POV = 27000)) and
    (FPanel.SelectedController in [scLeftHand, scRightHand,
      scLeftFoot, scRightFoot]) and not FPending and
    not FSession.Editing then
  begin
    FController := FPanel.SelectedController;
    FPending := FSession.BeginEdit(FModel, FController, Poses);
  end;
  if FPending then
  begin
    if ButtonPressed(State, ProButtonB) then CancelPending(Poses)
    else if ButtonPressed(State, ProButtonA) then CommitPending
    else
    begin
      Rate := 0.10 * Factor;
      if State.Down(ProButtonL) then Rate := Rate * 0.2;
      X := 0; Y := 0; Z := 0; Twist := 0; Bend := 0; TipPitch := 0;
      if State.Down(ProButtonX) and (FController <> scEyes) then
      begin
        Twist := State.LeftX * Rate;
        if FController in [scLeftHand, scRightHand,
          scLeftFoot, scRightFoot] then TipPitch := State.LeftY * Rate;
      end
      else
      begin
        X := State.LeftX * Rate;
        if State.Down(ProButtonR) and (FController <> scEyes) then
          Z := State.LeftY * Rate
        else Y := State.LeftY * Rate;
      end;
      if ((State.POV = 9000) or (State.POV = 27000)) and
        (FController in [scLeftHand, scRightHand,
          scLeftFoot, scRightFoot]) then
      begin
        if State.POV = 9000 then Bend := Rate else Bend := -Rate;
        Bend := Bend * SimpleControllerBendViewSign(FModel, Poses,
          FController, FViewYaw, FViewPitch, FOnReadRootRotation());
      end;
      if FSession.ApplyViewStep(FModel, FController, Poses,
        X, Y, Z, Twist, Bend, TipPitch, FViewYaw, FViewPitch,
        FOnReadRootRotation()) then
      begin
        {$IFDEF DEBUG}
        PoseDebugLog('editor.step_applied',
          'x=' + FloatToStr(X, TFormatSettings.Invariant) +
          ' y=' + FloatToStr(Y, TFormatSettings.Invariant) +
          ' z=' + FloatToStr(Z, TFormatSettings.Invariant));
        {$ENDIF}
        FOnWritePose;
      end;
    end;
  end
  else
  begin
    if (Abs(State.LeftX) <= 0.005) and
      (Abs(State.LeftY) <= 0.005) then FGamepadAwaitNeutral := False;
    if ButtonPressed(State, ProButtonY) and
      FSession.ResetController(FModel, FPanel.SelectedController, Poses,
        FEditSession.History, FOnReadRootRotation(),
        RadToDeg(FViewYaw), RadToDeg(FViewPitch)) then
    begin
      FOnWritePose;
      FOnHistoryChanged;
    end;
    if not FGamepadAwaitNeutral and
      ((Abs(State.LeftX) > 0.005) or (Abs(State.LeftY) > 0.005)) then
    begin
      FController := FPanel.SelectedController;
      FPending := FSession.BeginEdit(FModel, FController, Poses);
    end;
  end;
  FPreviousButtons := State.Buttons;
  FPreviousPOV := State.POV;
end;

end.
