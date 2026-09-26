unit MmdSimplePoseEditSession;

// 簡易部位操作の姿勢変更と確定履歴をD3Dプレビューから独立して管理する。

interface

uses
  MmdPoseHistory,
  MmdSimpleControllerSolver,
  PmxModel,
  PmxPose;

type
  TMmdSimplePoseEditSession = class
  private
    FBeforePoses: TPmxBonePoses;
    FChanged: Boolean;
    FEditing: Boolean;
  public
    // 操作前の姿勢を保持する。未対応部位は開始しない。
    function BeginEdit(Model: TPmxModel; Controller: TMmdSimpleController;
      const Poses: TPmxBonePoses): Boolean;
    // カメラ方向と入力増分から新しい姿勢を計算する。描画は呼出側が行う。
    function ApplyViewStep(Model: TPmxModel;
      Controller: TMmdSimpleController; var Poses: TPmxBonePoses;
      X, Y, Z, Twist, Bend, TipPitch, CameraYaw, CameraPitch: Single): Boolean; overload;
    // 表示後の全身回転を逆変換して、ボーン局所姿勢へ画面入力を適用する。
    function ApplyViewStep(Model: TPmxModel;
      Controller: TMmdSimpleController; var Poses: TPmxBonePoses;
      X, Y, Z, Twist, Bend, TipPitch, CameraYaw, CameraPitch: Single;
      const RootRotation: TPmxQuaternion): Boolean; overload;
    // 操作全体を1件のUndo履歴として確定する。
    function Commit(History: TMmdPoseHistory): Boolean; overload;
    // 全身回転も同じUndo項目へ保持して編集を確定する。
    function Commit(History: TMmdPoseHistory;
      const RootRotation: TPmxQuaternion): Boolean; overload;
    function Commit(History: TMmdPoseHistory;
      const RootRotation: TPmxQuaternion; RelativeYaw,
      RelativePitch: Single): Boolean; overload;
    // 操作前の姿勢を復元する。
    procedure Cancel(var Poses: TPmxBonePoses);
    // 選択部位を初期化し、1件のUndo履歴を記録する。
    function ResetController(Model: TPmxModel;
      Controller: TMmdSimpleController; var Poses: TPmxBonePoses;
      History: TMmdPoseHistory): Boolean; overload;
    // 全身回転を保持して部位初期化を記録する。
    function ResetController(Model: TPmxModel;
      Controller: TMmdSimpleController; var Poses: TPmxBonePoses;
      History: TMmdPoseHistory;
      const RootRotation: TPmxQuaternion): Boolean; overload;
    function ResetController(Model: TPmxModel;
      Controller: TMmdSimpleController; var Poses: TPmxBonePoses;
      History: TMmdPoseHistory; const RootRotation: TPmxQuaternion;
      RelativeYaw, RelativePitch: Single): Boolean; overload;
    property Editing: Boolean read FEditing;
  end;

implementation

uses
  PmxPoseMath;

function TMmdSimplePoseEditSession.BeginEdit(Model: TPmxModel;
  Controller: TMmdSimpleController; const Poses: TPmxBonePoses): Boolean;
begin
  FBeforePoses := Copy(Poses);
  FChanged := False;
  FEditing := CanUseSimpleController(Model, Controller);
  Result := FEditing;
  if not Result then FBeforePoses := nil;
end;

function TMmdSimplePoseEditSession.ApplyViewStep(Model: TPmxModel;
  Controller: TMmdSimpleController; var Poses: TPmxBonePoses;
  X, Y, Z, Twist, Bend, TipPitch, CameraYaw, CameraPitch: Single): Boolean;
begin
  Result := ApplyViewStep(Model, Controller, Poses, X, Y, Z, Twist,
    Bend, TipPitch, CameraYaw, CameraPitch, IdentityQuaternion);
end;

function TMmdSimplePoseEditSession.ApplyViewStep(Model: TPmxModel;
  Controller: TMmdSimpleController; var Poses: TPmxBonePoses;
  X, Y, Z, Twist, Bend, TipPitch, CameraYaw, CameraPitch: Single;
  const RootRotation: TPmxQuaternion): Boolean;
var
  NewPoses: TPmxBonePoses;
  WorldMove, WorldTurn: TPmxVector3;
begin
  Result := False;
  if not FEditing or (Model = nil) or
    ((Abs(X) + Abs(Y) + Abs(Z) + Abs(Twist) +
      Abs(Bend) + Abs(TipPitch)) < 0.000001) then Exit;
  WorldMove := Default(TPmxVector3);
  WorldTurn := Default(TPmxVector3);
  AccumulateSimpleControllerViewInput(Controller, X, Y, Z,
    CameraYaw, CameraPitch, WorldMove, WorldTurn);
  if Controller <> scEyes then
  begin
    WorldMove := RotateVector(InverseQuaternion(RootRotation), WorldMove);
    WorldTurn := RotateVector(InverseQuaternion(RootRotation), WorldTurn);
  end;
  // 現在姿勢への逐次適用により、可動端で入力を溜めない。
  Result := ApplySimpleControllerWorldWithExtras(Model, Poses,
    Controller, WorldMove, WorldTurn, Twist, Bend, TipPitch,
    CameraYaw, CameraPitch, RootRotation, NewPoses);
  if Result then
  begin
    Poses := NewPoses;
    FChanged := True;
  end;
end;

function TMmdSimplePoseEditSession.Commit(
  History: TMmdPoseHistory): Boolean;
begin
  Result := Commit(History, IdentityQuaternion);
end;

function TMmdSimplePoseEditSession.Commit(History: TMmdPoseHistory;
  const RootRotation: TPmxQuaternion): Boolean;
begin
  Result := Commit(History, RootRotation, 0, 0);
end;

function TMmdSimplePoseEditSession.Commit(History: TMmdPoseHistory;
  const RootRotation: TPmxQuaternion; RelativeYaw,
  RelativePitch: Single): Boolean;
begin
  Result := FEditing and FChanged;
  if Result and (History <> nil) then
    History.RecordBeforeEdit(FBeforePoses, RootRotation,
      RelativeYaw, RelativePitch);
  FEditing := False;
  FChanged := False;
  FBeforePoses := nil;
end;

procedure TMmdSimplePoseEditSession.Cancel(var Poses: TPmxBonePoses);
begin
  if FEditing then Poses := Copy(FBeforePoses);
  FEditing := False;
  FChanged := False;
  FBeforePoses := nil;
end;

function TMmdSimplePoseEditSession.ResetController(Model: TPmxModel;
  Controller: TMmdSimpleController; var Poses: TPmxBonePoses;
  History: TMmdPoseHistory): Boolean;
begin
  Result := ResetController(Model, Controller, Poses, History,
    IdentityQuaternion);
end;

function TMmdSimplePoseEditSession.ResetController(Model: TPmxModel;
  Controller: TMmdSimpleController; var Poses: TPmxBonePoses;
  History: TMmdPoseHistory;
  const RootRotation: TPmxQuaternion): Boolean;
begin
  Result := ResetController(Model, Controller, Poses, History,
    RootRotation, 0, 0);
end;

function TMmdSimplePoseEditSession.ResetController(Model: TPmxModel;
  Controller: TMmdSimpleController; var Poses: TPmxBonePoses;
  History: TMmdPoseHistory; const RootRotation: TPmxQuaternion;
  RelativeYaw, RelativePitch: Single): Boolean;
var
  BeforePoses, NewPoses: TPmxBonePoses;
begin
  BeforePoses := Copy(Poses);
  Result := (Model <> nil) and
    MmdSimpleControllerSolver.ResetSimpleController(Model, BeforePoses,
      Controller, NewPoses);
  if not Result then Exit;
  Poses := NewPoses;
  if History <> nil then History.RecordBeforeEdit(BeforePoses, RootRotation,
    RelativeYaw, RelativePitch);
end;

end.
